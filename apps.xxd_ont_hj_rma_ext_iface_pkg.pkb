--
-- XXD_ONT_HJ_RMA_EXT_IFACE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:38 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_HJ_RMA_EXT_IFACE_PKG"
/****************************************************************************************
* Package      : XXD_ONT_HJ_RMA_EXT_IFACE_PKG
* Design       : This package will be used EBS to HJ RMA extraction
* Notes        :
* Modification :
-- ======================================================================================
-- Date         Version#   Name                    Comments
-- ======================================================================================
-- 10-April-2020  1.0       Gjensen           Initial Version
-- 26-Oct-2020    1.1       Aravind Kannuri   Changes as per CCR0008949
-- 15-April-2021  1.2       Suraj Valluri      US6
-- 20-Feb-2023    1.3       Jayarajan A K     US1 to US6 Org Move changes
******************************************************************************************/
IS
    --Global Variables Declaration
    c_num_debug                    NUMBER := 0;
    c_dte_sysdate                  DATE := SYSDATE;
    g_num_user_id                  NUMBER := fnd_global.user_id;
    g_num_resp_id                  NUMBER := fnd_global.resp_id;
    g_num_resp_appl_id             NUMBER := fnd_global.resp_appl_id;
    g_num_login_id                 NUMBER := fnd_global.login_id;
    g_num_request_id               NUMBER := fnd_global.conc_request_id;
    g_num_prog_appl_id             NUMBER := fnd_global.prog_appl_id;
    g_num_session_id               NUMBER := fnd_global.session_id;
    g_dt_current_date              DATE := SYSDATE;
    g_num_rec_count                NUMBER := 0;
    gc_new_status         CONSTANT VARCHAR2 (15) := 'NEW';
    gc_inprocess_status   CONSTANT VARCHAR2 (15) := 'INPROCESS';
    gc_processed_status   CONSTANT VARCHAR2 (15) := 'PROCESSED';
    gc_error_status       CONSTANT VARCHAR2 (15) := 'ERROR';
    gc_obsolete_status    CONSTANT VARCHAR2 (15) := 'OBSOLETE';
    gc_warning_status     CONSTANT VARCHAR2 (15) := 'WARNING';
    gc_package_name       CONSTANT VARCHAR2 (30)
                                       := 'XXD_ONT_HJ_RMA_EXT_IFACE_PKG' ;
    gc_program_name       CONSTANT VARCHAR2 (120) := 'EBS_HJ_RMA_INT';
    gc_period_char        CONSTANT VARCHAR2 (1) := '.';
    gc_soa_user           CONSTANT NUMBER := -999;
    gn_inv_org_id                  NUMBER := NULL;

    /*********************************************************************************
 Procedure/Function Name  :  msg
 Description              :  This procedure displays log messages based on debug
                             mode parameter
 *********************************************************************************/
    PROCEDURE msg (in_chr_message VARCHAR2)
    IS
    BEGIN
        IF c_num_debug = 1
        THEN
            fnd_file.put_line (fnd_file.LOG, in_chr_message);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Unexpected Error: ' || SQLERRM);
    END;

    --Procedure to write debug messages into Interface errors table
    PROCEDURE debug_prc (pv_application IN VARCHAR2, pv_debug_text IN VARCHAR2, pv_debug_message IN VARCHAR2, pn_created_by IN NUMBER, pn_session_id IN NUMBER, pn_debug_id IN NUMBER
                         , pn_request_id IN NUMBER)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        lv_proc_name   VARCHAR2 (30) := 'DEBUG_PRC';
        lv_err_msg     VARCHAR2 (2000) := NULL;
    BEGIN
        INSERT INTO custom.do_debug (debug_text, creation_date, created_by,
                                     session_id, debug_id, request_id,
                                     application_id, call_stack)
             VALUES (pv_debug_text                                --debug_text
                                  , SYSDATE                    --creation_Date
                                           , NVL (pn_created_by, -1) --created_by
                                                                    ,
                     NVL (pn_session_id, USERENV ('SESSIONID'))   --session_id
                                                               , NVL (pn_debug_id, -1) --debug_id
                                                                                      , NVL (pn_request_id, g_num_request_id) --request_id
                     , pv_application                         --application_id
                                     , pv_debug_message           --call_stack
                                                       );

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_err_msg   :=
                   'Error while purging the debug messages in '
                || gc_package_name
                || '.'
                || lv_proc_name;
            lv_err_msg   :=
                SUBSTR (lv_err_msg || '. Error is : ' || SQLERRM, 1, 2000);

            IF g_num_resp_id <> -1
            THEN
                msg (lv_err_msg);        --Print the error message to log file
            END IF;
    END debug_prc;

    /**********************************************************************************
 Procedure/Function Name  :  GET_LAST_RUN_TIME
 Description              :  This function looks for warehouse and sales channel
                             combination and return the last run date/time.
 **********************************************************************************/
    FUNCTION get_last_run_time (pn_warehouse_id    IN NUMBER,
                                pv_sales_channel   IN VARCHAR2)
        RETURN DATE
    IS
        --Local Variables Declaration
        l_func_name        VARCHAR2 (30) := 'GET_LAST_RUN_TIME';
        l_err_msg          VARCHAR2 (2000) := NULL;
        ld_last_run_date   DATE := NULL;
    BEGIN
        SELECT TO_DATE (flv.attribute3, 'RRRR/MM/DD HH24:MI:SS') last_run_date
          INTO ld_last_run_date
          FROM fnd_lookup_values flv
         WHERE     1 = 1
               AND flv.lookup_type = 'XXD_ONT_HJ_RMA_EXT_RUN_LKP'
               AND flv.LANGUAGE = USERENV ('LANG')
               AND flv.enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE)
                               AND NVL (flv.end_date_active, SYSDATE + 1)
               AND TO_NUMBER (flv.attribute1) = pn_warehouse_id
               AND flv.attribute2 = pv_sales_channel;

        RETURN ld_last_run_date;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_err_msg   :=
                SUBSTR (
                       'Exception in '
                    || l_func_name
                    || '. Error is: '
                    || SQLERRM,
                    1,
                    2000);
            msg (l_err_msg);
            RETURN NULL;
    END get_last_run_time;

    FUNCTION get_active_orders_count (pn_request_id      IN NUMBER,
                                      pv_sales_channel   IN VARCHAR2)
        RETURN NUMBER
    IS
        --Local Variables Declaration
        l_func_name       VARCHAR2 (30) := 'GET_ACTIVE_ORDERS_COUNT';
        l_err_msg         VARCHAR2 (2000) := NULL;
        ln_orders_count   NUMBER := 0;
    BEGIN
        SELECT COUNT (*)
          INTO ln_orders_count
          FROM xxdo.xxd_ont_rma_intf_hdr_stg_t stg
         WHERE     1 = 1
               AND stg.batch_number IS NULL
               AND stg.sales_channel_code = pv_sales_channel
               AND stg.process_status = gc_new_status
               AND stg.request_id = pn_request_id;

        RETURN ln_orders_count;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_err_msg   :=
                SUBSTR (
                       'Exception@'
                    || l_func_name
                    || '. Returning ZERO for active orders count. Error is: '
                    || SQLERRM,
                    1,
                    2000);
            msg (l_err_msg);
            RETURN 0;
    END get_active_orders_count;

    FUNCTION get_orders_per_batch (pv_sales_channel IN VARCHAR2)
        RETURN NUMBER
    IS
        --Local Variables Declaration
        l_func_name           VARCHAR2 (30) := 'GET_ORDERS_PER_BATCH';
        l_err_msg             VARCHAR2 (2000) := NULL;
        ln_orders_per_batch   NUMBER := 0;
    BEGIN
        SELECT TO_NUMBER (flv.attribute2) orders_per_batch
          INTO ln_orders_per_batch
          FROM fnd_lookup_values_vl flv
         WHERE     1 = 1
               AND flv.lookup_type = 'XXD_ONT_HJ_RMA_EXT_BATCH_LKP'
               AND flv.enabled_flag = 'Y'
               AND flv.attribute1 = pv_sales_channel          ---Sales Channel
               AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE)
                               AND NVL (flv.end_date_active, SYSDATE + 1);

        fnd_file.put_line (fnd_file.LOG,
                           'get_orders_per_batch' || ln_orders_per_batch);
        RETURN ln_orders_per_batch;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_err_msg   :=
                SUBSTR (
                       'Exception@'
                    || l_func_name
                    || '. Returning 100 for orders per batch for '
                    || pv_sales_channel
                    || ' Channel. Error is: '
                    || SQLERRM,
                    1,
                    2000);
            msg (l_err_msg);
            fnd_file.put_line (fnd_file.LOG, l_err_msg);
            RETURN 100; --In case of any issue, Return 100 for order per batch
    END get_orders_per_batch;

    FUNCTION get_lines_per_batch (pv_sales_channel IN VARCHAR2)
        RETURN NUMBER
    IS
        --Local Variables Declaration
        l_func_name          VARCHAR2 (30) := 'GET_LINES_PER_BATCH';
        l_err_msg            VARCHAR2 (2000) := NULL;
        ln_lines_per_batch   NUMBER := 0;
    BEGIN
        SELECT TO_NUMBER (flv.attribute3) lines_per_batch
          INTO ln_lines_per_batch
          FROM fnd_lookup_values_vl flv
         WHERE     1 = 1
               AND flv.lookup_type = 'XXD_ONT_HJ_RMA_EXT_BATCH_LKP'
               AND flv.enabled_flag = 'Y'
               AND flv.attribute1 = pv_sales_channel          ---Sales Channel
               AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE)
                               AND NVL (flv.end_date_active, SYSDATE + 1);

        fnd_file.put_line (fnd_file.LOG,
                           'get_lines_per_batch' || ln_lines_per_batch);
        RETURN ln_lines_per_batch;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_err_msg   :=
                SUBSTR (
                       'Exception@'
                    || l_func_name
                    || '. Returning 1000 for Lines per batch. Error is: '
                    || SQLERRM,
                    1,
                    2000);
            msg (l_err_msg);
            fnd_file.put_line (fnd_file.LOG, l_err_msg);
            RETURN 1000;                    --In case of any issue Return 1000
    END get_lines_per_batch;

    PROCEDURE proc_upd_batch_num_child (pn_request_id IN NUMBER, pv_sales_channel IN VARCHAR2, x_update_status OUT NUMBER
                                        , x_error_message OUT VARCHAR2)
    IS
        --Local Variables Declaration
        l_proc_name   VARCHAR2 (30) := 'PROC_UPD_BATCH_NUM_CHILD';
        l_error_msg   VARCHAR2 (2000) := NULL;

        --Cursor to get Batch Number, Order Number for the request ID, Order type(Sales Channel) with process status as NEW
        CURSOR batch_num_cur IS
            SELECT DISTINCT rih.batch_number, rih.order_number, rih.request_id,
                            rih.process_status
              FROM xxdo.xxd_ont_rma_intf_hdr_stg_t rih
             WHERE     1 = 1
                   AND rih.request_id = pn_request_id
                   AND rih.sales_channel_code = pv_sales_channel
                   AND rih.process_status = gc_new_status
                   AND rih.batch_number IS NOT NULL;
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
               'Start of Updating batch number in all staging tables based on pick int header table batch number'
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

        FOR batch_num_rec IN batch_num_cur
        LOOP
            UPDATE xxdo.xxd_ont_rma_intf_ln_stg_t
               SET batch_number = batch_num_rec.batch_number, last_update_date = SYSDATE, last_updated_by = g_num_user_id,
                   last_update_login = g_num_login_id
             WHERE     1 = 1
                   AND process_status = batch_num_rec.process_status
                   AND request_id = batch_num_rec.request_id
                   AND order_number = batch_num_rec.order_number;

            UPDATE xxdo.xxd_ont_rma_intf_cmt_hdr_stg_t
               SET batch_number = batch_num_rec.batch_number, last_update_date = SYSDATE, last_updated_by = g_num_user_id,
                   last_update_login = g_num_login_id
             WHERE     1 = 1
                   AND process_status = batch_num_rec.process_status
                   AND request_id = batch_num_rec.request_id
                   AND order_number = batch_num_rec.order_number;

            UPDATE xxdo.xxd_ont_rma_intf_cmt_ln_stg_t
               SET batch_number = batch_num_rec.batch_number, last_update_date = SYSDATE, last_updated_by = g_num_user_id,
                   last_update_login = g_num_login_id
             WHERE     1 = 1
                   AND process_status = batch_num_rec.process_status
                   AND request_id = batch_num_rec.request_id
                   AND order_number = batch_num_rec.order_number;
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
               'End of Updating batch number in all staging tables based on pick int header table batch number'
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

        x_update_status   := g_success;
        x_error_message   := NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_error_msg       :=
                SUBSTR (
                    'Error @proc_upd_batch_num_child. Error is: ' || SQLERRM,
                    1,
                    2000);
            fnd_file.put_line (fnd_file.LOG, l_error_msg);
            x_update_status   := g_error;
            x_error_message   := l_error_msg;
            ROLLBACK;
            msg (l_error_msg);
    END proc_upd_batch_num_child;

    PROCEDURE proc_upd_batch_leftover (pn_request_id      IN     NUMBER,
                                       pv_sales_channel   IN     VARCHAR2,
                                       pn_no_of_orders    IN     NUMBER,
                                       x_update_status       OUT NUMBER,
                                       x_error_message       OUT VARCHAR2)
    IS
        --Local Variables Declaration
        l_proc_name        VARCHAR2 (30) := 'PROC_UPD_BATCH_LEFTOVER';
        l_err_msg          VARCHAR2 (2000) := NULL;
        ln_valid_rec_cnt   NUMBER := 0;
        ln_mod_count       NUMBER := 0;
        ln_batch_number    NUMBER := 0;
        ln_no_of_orders    NUMBER := 0;

        TYPE hdr_batch_id_t IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        ln_hdr_batch_id    hdr_batch_id_t;

        TYPE request_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;
    BEGIN
        msg (
            'Calling Procedure which assign a child process for each order ');

        SELECT COUNT (DISTINCT header_id)
          INTO ln_valid_rec_cnt
          FROM xxdo.xxd_ont_rma_intf_hdr_stg_t
         WHERE     1 = 1
               AND batch_number IS NULL
               AND process_status = gc_new_status
               AND request_id = pn_request_id
               AND sales_channel_code = pv_sales_channel
               AND source_type = 'ORDER';

        --Loop for all orders that are not updated with batch number
        FOR i IN 1 .. pn_no_of_orders
        LOOP
            BEGIN
                SELECT xxdo.xxd_ont_hj_rma_batch_no_s.NEXTVAL
                  INTO ln_hdr_batch_id (i)
                  FROM DUAL;
            --msg('ln_hdr_batch_id(i) := ' || ln_hdr_batch_id(i));
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_hdr_batch_id (i + 1)   := ln_hdr_batch_id (i) + 1;
            END;

            msg (' ln_valid_rec_cnt := ' || ln_valid_rec_cnt);
            msg (
                   ' Ceil( ln_valid_rec_cnt/pn_no_of_orders) := '
                || CEIL (ln_valid_rec_cnt / pn_no_of_orders));

            UPDATE xxdo.xxd_ont_rma_intf_hdr_stg_t rih
               SET batch_number   = ln_hdr_batch_id (i)
             WHERE     1 = 1
                   AND rih.header_id IN
                           (SELECT header_id
                              FROM (  SELECT DISTINCT rih_1.header_id
                                        FROM xxdo.xxd_ont_rma_intf_hdr_stg_t rih_1
                                       WHERE     1 = 1
                                             AND rih_1.batch_number IS NULL
                                             AND rih_1.process_status =
                                                 gc_new_status
                                             AND rih_1.request_id =
                                                 pn_request_id
                                             AND rih_1.sales_channel_code =
                                                 pv_sales_channel
                                             AND rih_1.source_type = 'ORDER'
                                    ORDER BY 1)
                             WHERE     1 = 1
                                   AND ROWNUM <=
                                       CEIL (
                                           ln_valid_rec_cnt / pn_no_of_orders))
                   AND rih.batch_number IS NULL
                   AND rih.process_status = gc_new_status
                   AND rih.request_id = pn_request_id
                   AND rih.sales_channel_code = pv_sales_channel;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            l_err_msg   :=
                SUBSTR (
                       'Exception while updating batch number for each order for '
                    || pv_sales_channel
                    || ' Channel in '
                    || l_proc_name
                    || ' Error is: '
                    || SQLERRM,
                    1,
                    2000);
            msg (l_err_msg);
    END proc_upd_batch_leftover;


    PROCEDURE proc_update_batch (pn_request_id IN NUMBER, pv_sales_channel IN VARCHAR2, x_update_status OUT NUMBER
                                 , x_error_message OUT VARCHAR2)
    IS
        --Local Variables Declaration
        l_proc_name           VARCHAR2 (30) := 'PROC_UPDATE_BATCH';
        l_err_msg             VARCHAR2 (2000) := NULL;
        ln_orders_count       NUMBER := 0;
        ln_lines_count        NUMBER := 0;
        ln_count              NUMBER := 0;
        ln_mod_count          NUMBER := 0;
        ln_batch_number       NUMBER := 0;
        ln_orders_per_batch   NUMBER := 0;
        ln_lines_per_batch    NUMBER := 0;
        l_update_status       NUMBER := g_success;
        l_error_message       VARCHAR2 (2000) := NULL;
        l_upd_sts_leftover    NUMBER := g_success;
        --Added for change 2.3
        l_err_msg_leftover    VARCHAR2 (2000) := NULL;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Call Procedure proc_update_batch.');
        ln_orders_per_batch   := get_orders_per_batch (pv_sales_channel);
        fnd_file.put_line (fnd_file.LOG,
                           'Orders per batch count: ' || ln_orders_per_batch);
        --Get count of orders for this sales channel for the request id
        ln_orders_count       :=
            get_active_orders_count (pn_request_id, pv_sales_channel);
        fnd_file.put_line (fnd_file.LOG,
                           'Orders count : ' || ln_orders_count);


        --Get lines per batch for the sales channel
        ln_lines_per_batch    := get_lines_per_batch (pv_sales_channel);
        ln_mod_count          := CEIL (ln_orders_count / ln_orders_per_batch);

        fnd_file.put_line (fnd_file.LOG,
                           'lines per batch count : ' || ln_lines_per_batch);

        FOR j IN 1 .. ln_mod_count
        LOOP
            BEGIN
                --Getting batch number from sequence
                ln_batch_number   := xxdo.xxd_ont_hj_rma_batch_no_s.NEXTVAL;

                --Updating the RMA int Header staging table batch number for a group of orders where count of all lines is less than or equal to lines per batch(ln_no_of_lines)
                UPDATE xxdo.xxd_ont_rma_intf_hdr_stg_t pih
                   SET pih.batch_number   = ln_batch_number
                 WHERE     1 = 1
                       AND header_id IN
                               (SELECT header_id
                                  FROM (  SELECT header_id, SUM (COUNT (1)) OVER (ORDER BY COUNT (1), header_id) cntt, --Get the cumulative sum of RMA orders
                                                                                                                       DENSE_RANK () OVER (ORDER BY COUNT (1), header_id) ranking
                                            --Get the ranking for the lines
                                            FROM xxdo.xxd_ont_rma_intf_ln_stg_t pil
                                           WHERE     1 = 1
                                                 --AND pil.batch_number IS NULL
                                                 AND pil.process_status =
                                                     gc_new_status
                                                 AND pil.request_id =
                                                     pn_request_id
                                                 ---Get the RMAs for the order type passed as parameter
                                                 AND pil.header_id IN
                                                         (SELECT header_id
                                                            FROM xxdo.xxd_ont_rma_intf_hdr_stg_t
                                                           WHERE     1 = 1
                                                                 AND batch_number
                                                                         IS NULL
                                                                 AND sales_channel_code =
                                                                     pv_sales_channel
                                                                 AND process_status =
                                                                     gc_new_status
                                                                 AND request_id =
                                                                     pn_request_id)
                                        GROUP BY pil.header_id
                                        ORDER BY 2)
                                 WHERE     1 = 1
                                       AND cntt <= ln_lines_per_batch
                                       AND ranking <= ln_orders_per_batch)
                       AND pih.process_status = gc_new_status
                       AND pih.batch_number IS NULL
                       AND pih.request_id = pn_request_id
                       AND pih.sales_channel_code = pv_sales_channel;

                ln_count          := SQL%ROWCOUNT;
                l_err_msg         :=
                    SUBSTR (
                           'Completed updating Batch Number in XXD_ONT_RMA_INTF_HDR_STG_T table for '
                        || pv_sales_channel
                        || ' Channel. Number of orders updated = '
                        || ln_count,
                        1,
                        2000);
                msg (l_err_msg);
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_err_msg   :=
                        SUBSTR (
                               'Error in Updating the batch number in RMA header table for order type/ sales channel '
                            || pv_sales_channel
                            || '. Error is '
                            || SQLERRM,
                            1,
                            2000);
                    msg (l_err_msg);
            END;
        END LOOP;

        ln_count              := 0;

        --Get the count distinct RMAs where line count is greater than lines_per_batch(ln_no_of_lines)
        --Getting the count of remaining orders where the batch_number is not updated.
        BEGIN
            SELECT COUNT (DISTINCT header_id)
              INTO ln_count
              FROM xxdo.xxd_ont_rma_intf_hdr_stg_t
             WHERE     1 = 1
                   AND batch_number IS NULL
                   AND process_status = gc_new_status
                   AND request_id = pn_request_id
                   AND sales_channel_code = pv_sales_channel;
        END;

        --If there are orders where line count is greater than lines per batch then call proc_upd_batch_leftover procedure
        IF ln_count > 0
        THEN
            proc_upd_batch_leftover (pn_request_id      => pn_request_id,
                                     pv_sales_channel   => pv_sales_channel,
                                     pn_no_of_orders    => ln_count,
                                     x_update_status    => l_upd_sts_leftover,
                                     x_error_message    => l_err_msg_leftover);
        END IF;

        --Now call the procedure to update the batch number in all the staging tables
        proc_upd_batch_num_child (pn_request_id => pn_request_id, pv_sales_channel => pv_sales_channel, x_update_status => l_update_status
                                  , x_error_message => l_error_message);

        IF l_update_status <> g_success OR l_upd_sts_leftover <> g_success
        THEN
            x_update_status   := g_warning;
            x_error_message   := NVL (l_err_msg_leftover, l_error_message);
            ROLLBACK;
        ELSE
            l_err_msg   :=
                SUBSTR (
                       'Completed updating Batch Number in all the RMA interface tables for order type/ sales channel = '
                    || pv_sales_channel,
                    1,
                    2000);
            msg (l_err_msg);
            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;

            l_error_message   :=
                SUBSTR ('Error@proc_update_batch. Error is:' || SQLERRM,
                        1,
                        2000);
            msg (l_error_message);
            x_update_status   := g_warning;
            x_error_message   := l_error_message;
    END;


    /**********************************************************************************
    Procedure/Function Name  :  SET_LAST_RUN_TIME
    Description              :  This Procedure looks for warehouse and sales channel
                                combination and updates the last run date/time.
    **********************************************************************************/
    PROCEDURE set_last_run_time (pn_warehouse_id IN NUMBER, pv_sales_channel IN VARCHAR2, pd_last_run_date IN DATE)
    IS
        --Local Variables Declaration
        l_proc_name   VARCHAR2 (30) := 'SET_LAST_RUN_TIME';
        l_err_msg     VARCHAR2 (2000) := NULL;

        CURSOR upd_lkp_cur IS
            SELECT flv.*
              FROM apps.fnd_lookup_values flv
             WHERE     1 = 1
                   AND flv.lookup_type = 'XXD_ONT_HJ_RMA_EXT_RUN_LKP'
                   AND flv.LANGUAGE = USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE)
                                   AND NVL (flv.end_date_active, SYSDATE + 1)
                   AND TO_NUMBER (flv.attribute1) = pn_warehouse_id
                   AND flv.attribute2 = pv_sales_channel;
    BEGIN
        FOR upd_lkp_rec IN upd_lkp_cur
        LOOP
            fnd_lookup_values_pkg.update_row (
                x_lookup_type           => upd_lkp_rec.lookup_type,
                x_security_group_id     => upd_lkp_rec.security_group_id,
                x_view_application_id   => upd_lkp_rec.view_application_id,
                x_lookup_code           => upd_lkp_rec.lookup_code,
                x_tag                   => upd_lkp_rec.tag,
                x_attribute_category    => upd_lkp_rec.attribute_category,
                x_attribute1            => upd_lkp_rec.attribute1,
                x_attribute2            => upd_lkp_rec.attribute2,
                x_attribute3            =>
                    TO_CHAR (pd_last_run_date, 'RRRR/MM/DD HH24:MI:SS'),
                x_attribute4            => upd_lkp_rec.attribute4,
                x_enabled_flag          => upd_lkp_rec.enabled_flag,
                x_start_date_active     => upd_lkp_rec.start_date_active,
                x_end_date_active       => upd_lkp_rec.end_date_active,
                x_territory_code        => upd_lkp_rec.territory_code,
                x_attribute5            => upd_lkp_rec.attribute5,
                x_attribute6            => upd_lkp_rec.attribute6,
                x_attribute7            => upd_lkp_rec.attribute7,
                x_attribute8            => upd_lkp_rec.attribute8,
                x_attribute9            => upd_lkp_rec.attribute9,
                x_attribute10           => upd_lkp_rec.attribute10,
                x_attribute11           => upd_lkp_rec.attribute11,
                x_attribute12           => upd_lkp_rec.attribute12,
                x_attribute13           => upd_lkp_rec.attribute13,
                x_attribute14           => upd_lkp_rec.attribute14,
                x_attribute15           => upd_lkp_rec.attribute15,
                x_meaning               => upd_lkp_rec.meaning,
                x_description           => upd_lkp_rec.description,
                x_last_update_date      => SYSDATE,
                x_last_updated_by       => g_num_user_id,
                x_last_update_login     => g_num_login_id);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Updated LAST_RUN_DATE for warehouse ID = '
                || upd_lkp_rec.attribute1
                || ' , Sales Channel = '
                || upd_lkp_rec.attribute2
                || ' to '
                || TO_CHAR (pd_last_run_date, 'RRRR/MM/DD HH24:MI:SS'));
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_err_msg   :=
                SUBSTR (
                       'Exception in '
                    || l_proc_name
                    || ' while updating last run date. Error is: '
                    || SQLERRM,
                    1,
                    2000);
            fnd_file.put_line (fnd_file.LOG, l_err_msg);
            msg (l_err_msg);
    END set_last_run_time;

    /*
 ***********************************************************************************
 Procedure/Function Name  :  extract_RMA_stage_data
 Description              :  This procedure extracts RMA details into staging tables
 ***********************************************************************************/
    PROCEDURE extract_rma_stage_data (p_organization_id IN NUMBER, p_rma_num IN NUMBER, p_sales_channel IN VARCHAR2, p_last_run_date IN DATE, p_re_extract IN VARCHAR2, p_retcode OUT NUMBER
                                      , p_error_buf OUT VARCHAR2)
    IS
        CURSOR c_rma_hdr IS
            SELECT DISTINCT ooha.header_id, ooha.order_number
              FROM oe_order_headers_all ooha, oe_order_lines_all oola, --Added as per CCR0008949
                                                                       oe_transaction_types_all ott,
                   oe_transaction_types_tl ottl, fnd_lookup_values flv
             WHERE     1 = 1
                   AND ooha.header_id = oola.header_id --Added as per CCR0008949
                   AND ooha.org_id = oola.org_id     --Added as per CCR0008949
                   AND EXISTS
                           (SELECT NULL
                              FROM rcv_transactions rt, oe_order_lines_all oola
                             WHERE     rt.oe_order_line_id = oola.line_id
                                   AND ooha.header_id = oola.header_id
                                   AND oola.line_category_code = 'RETURN'
                                   AND oola.shipment_number = 1
                                   AND (p_re_extract = 'Y' OR (rt.creation_date >= p_last_run_date AND p_re_extract = 'N')))
                   AND (p_re_extract = 'N' OR (ooha.order_number = p_rma_num AND p_re_extract = 'Y'))
                   --AND ooha.ship_from_org_id = p_organization_id   --Commented as per CCR0008949
                   AND oola.ship_from_org_id = p_organization_id --Added as per CCR0008949
                   AND ooha.sales_channel_code = 'E-COMMERCE'
                   AND ooha.order_type_id = ott.transaction_type_id
                   AND ottl.LANGUAGE = 'US'
                   AND ooha.order_type_id = ott.transaction_type_id
                   AND ott.transaction_type_id = ottl.transaction_type_id
                   AND SYSDATE BETWEEN NVL (ott.start_date_active,
                                            SYSDATE - 1)
                                   AND NVL (ott.end_date_active, SYSDATE + 1)
                   AND ott.order_category_code IN ('RETURN', 'MIXED')
                   AND ottl.NAME = flv.meaning
                   AND flv.lookup_type = 'XXDO_WTF_AUTORECEIPT_TYPES'
                   AND flv.LANGUAGE = 'US'
                   AND flv.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (flv.start_date_active,
                                            SYSDATE - 1)
                                   AND NVL (flv.end_date_active, SYSDATE + 1)
                   AND p_sales_channel = 'ECOMM'
            UNION ALL
            SELECT DISTINCT ooha.header_id, ooha.order_number
              FROM oe_order_headers_all ooha, oe_order_lines_all oola --Added as per CCR0008949
             WHERE     1 = 1
                   AND ooha.header_id = oola.header_id --Added as per CCR0008949
                   AND ooha.org_id = oola.org_id     --Added as per CCR0008949
                   AND ooha.sales_channel_code != 'E-COMMERCE'
                   --AND ooha.ship_from_org_id = p_organization_id   --Commented as per CCR0008949
                   AND oola.ship_from_org_id = p_organization_id --Added as per CCR0008949
                   AND ooha.order_category_code IN ('MIXED', 'RETURN')
                   AND (p_re_extract = 'N' OR (ooha.order_number = p_rma_num AND p_re_extract = 'Y'))
                   AND EXISTS
                           (SELECT NULL
                              FROM oe_order_lines_all oola
                             WHERE     oola.flow_status_code =
                                       'AWAITING_RETURN'
                                   AND oola.line_category_code = 'RETURN'
                                   AND oola.shipment_number = 1
                                   AND oola.header_id = ooha.header_id
                                   AND (p_re_extract = 'Y' OR (oola.last_update_date >= p_last_run_date AND p_re_extract = 'N')))
                   AND p_sales_channel = 'OTHER';

        CURSOR c_rma_lines (n_header_id NUMBER)
        IS
            SELECT mp.organization_code
                       warehouse_code,
                   oola.line_id,
                   oola.line_number,
                   msi.concatenated_segments
                       item_number,
                   oola.ordered_quantity
                       qty,
                   oola.order_quantity_uom
                       order_uom,
                   oola.return_reason_code
                       reason_code,
                   al.meaning
                       reason_description,
                   (SELECT order_number
                      FROM oe_order_headers_all ooh1
                     WHERE ooh1.header_id = oola.reference_header_id)
                       ref_sales_order_number,
                   (SELECT SUBSTR (oola.cust_po_number, 1, 30)
                      FROM oe_order_headers_all ooh1
                     WHERE ooh1.header_id = oola.reference_header_id)
                       ref_cust_po_number,
                   oola.latest_acceptable_date
                       latest_accept_date,
                   oola.packing_instructions
                       line_packing_instructions,
                   oola.shipping_instructions
                       line_shipping_instructions
              FROM oe_order_lines_all oola, mtl_parameters mp, mtl_system_items_kfv msi,
                   ar_lookups al
             WHERE     1 = 1
                   AND header_id = n_header_id
                   AND oola.ship_from_org_id = mp.organization_id
                   AND msi.organization_id = mp.organization_id
                   AND oola.ship_from_org_id = p_organization_id        --v1.3
                   AND msi.inventory_item_id = oola.inventory_item_id
                   AND oola.shipment_number = 1 --Dont extract any split or HJ created lines
                   AND al.lookup_type = 'CREDIT_MEMO_REASON'
                   AND al.lookup_code = oola.return_reason_code;


        l_num_comment_count        NUMBER;
        l_num_stg_header_id        NUMBER;
        l_num_stg_line_id          NUMBER;
        l_num_stg_hdr_cmt_id       NUMBER;
        l_num_stg_line_cmt_id      NUMBER;
        l_chr_auto_receipt         VARCHAR2 (1);
        l_num_serial_count         NUMBER := 0;
        l_return_source            VARCHAR2 (100);

        p_source                   VARCHAR2 (10) := 'EBS';
        p_dest                     VARCHAR2 (10) := 'WMS';

        lv_company                 VARCHAR2 (240);
        lv_warehouse_code          VARCHAR2 (10);
        lv_order_type              VARCHAR2 (50);
        ln_order_number            NUMBER;
        lv_brand_code              VARCHAR2 (15);
        lv_customer_code           VARCHAR2 (30);
        lv_customer_name           VARCHAR2 (240);
        ld_rma_date                DATE;
        lv_packing_instructions    VARCHAR2 (2000);
        lv_shipping_instructions   VARCHAR2 (2000);
        lv_comments1               VARCHAR2 (240);
        lv_comments2               VARCHAR2 (240);
        lv_auto_receipt_flag       VARCHAR2 (1);
        ln_header_id               NUMBER;
        lv_cust_po_number          VARCHAR2 (100);
        ln_count                   NUMBER;
        ln_process                 NUMBER;

        --Start changes v1.3
        lv_wh_code                 VARCHAR2 (10);
        --End changes v1.3

        exc_rma_process            EXCEPTION;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Extracting RMA detail');

        --Start changes v1.3
        SELECT organization_code
          INTO lv_wh_code
          FROM mtl_parameters
         WHERE organization_id = p_organization_id;

        --End changes v1.3

        FOR c_rma_header_rec IN c_rma_hdr
        LOOP
            ln_process   := 1;

            /* --Start Commented as per CCR0008949
            IF p_re_extract = 'Y'
            THEN
               --Check if RMA is in staging table
               SELECT COUNT (*)
                 INTO ln_count
                 FROM XXD_ONT_RMA_INTF_HDR_STG_T
                WHERE order_number = c_rma_header_rec.order_number;

               IF ln_count = 0
               THEN
                  fnd_file.put_line (
                     fnd_file.LOG,
                        'Re-extract option enabled and RMA # '
                     || c_rma_header_rec.order_number
                     || ' not in staging table');
                  ln_process := 0;
               END IF;
            END IF;
      */
            --End Commented as per CCR0008949

            --Check for holds
            SELECT COUNT (*)
              INTO ln_count
              FROM oe_order_holds_all oohs
             WHERE     oohs.released_flag = 'N'
                   AND oohs.line_id IS NULL
                   AND oohs.header_id = c_rma_header_rec.header_id;

            IF ln_count > 0
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'RMA # '
                    || c_rma_header_rec.order_number
                    || ' is on hold');
                ln_process   := 0;
            END IF;



            IF ln_process = 1
            THEN
                --Start new header
                SAVEPOINT rma_header;

                --Get header record data
                SELECT hou.NAME company,
                       mp.organization_code warehouse_code,
                       ooha.order_number,
                       ottl.NAME order_type,
                       ooha.attribute5 brand_code,
                       hca.account_number customer_code,
                       hpa.party_name customer_name,
                       ooha.ordered_date rma_date,
                       ooha.packing_instructions,
                       ooha.shipping_instructions,
                       ooha.attribute6 comments1,
                       ooha.attribute7 comments2,
                       CASE ooha.sales_channel_code
                           WHEN 'E-COMMERCE' THEN 'Y'
                           ELSE 'N'
                       END auto_receipt_flag,
                       header_id,
                       cust_po_number
                  INTO lv_company, lv_warehouse_code, ln_order_number, lv_order_type,
                                 lv_brand_code, lv_customer_code, lv_customer_name,
                                 ld_rma_date, lv_packing_instructions, lv_shipping_instructions,
                                 lv_comments1, lv_comments2, lv_auto_receipt_flag,
                                 ln_header_id, lv_cust_po_number
                  FROM oe_order_headers_all ooha, oe_transaction_types_all ott, mtl_parameters mp,
                       hr_operating_units hou, oe_transaction_types_tl ottl, hz_cust_accounts hca,
                       hz_cust_site_uses_all hsu, hz_cust_acct_sites_all hcs, hz_parties hpa
                 WHERE     1 = 1
                       AND ott.transaction_type_id = ooha.order_type_id
                       AND ott.order_category_code IN ('RETURN', 'MIXED')
                       AND ottl.transaction_type_id = ott.transaction_type_id
                       AND ottl.LANGUAGE = USERENV ('LANG')
                       AND hsu.site_use_id = ooha.invoice_to_org_id
                       AND hcs.cust_acct_site_id = hsu.cust_acct_site_id
                       AND hca.cust_account_id = hcs.cust_account_id
                       AND hca.party_id = hpa.party_id
                       AND hou.organization_id = ooha.org_id
                       AND mp.organization_id = ooha.ship_from_org_id
                       AND ooha.header_id = c_rma_header_rec.header_id;

                BEGIN
                    fnd_file.put_line (fnd_file.LOG,
                                       'Warehouse:' || lv_warehouse_code);
                    fnd_file.put_line (fnd_file.LOG,
                                       'RMA number:' || ln_order_number);

                    BEGIN
                        UPDATE XXD_ONT_RMA_INTF_HDR_STG_T
                           SET process_status = 'OBSOLETE', last_update_date = SYSDATE, last_updated_by = g_num_user_id,
                               last_update_login = g_num_login_id
                         WHERE     order_number = ln_order_number
                               --Start changes v1.3
                               --AND warehouse_code = lv_warehouse_code
                               AND warehouse_code = lv_wh_code
                               --End changes v1.3
                               AND process_status <> 'OBSOLETE';

                        UPDATE XXD_ONT_RMA_INTF_LN_STG_T
                           SET process_status = 'OBSOLETE', last_update_date = SYSDATE, last_updated_by = g_num_user_id,
                               last_update_login = g_num_login_id
                         WHERE     order_number = ln_order_number
                               --Start changes v1.3
                               --AND warehouse_code = lv_warehouse_code
                               AND warehouse_code = lv_wh_code
                               --End changes v1.3
                               AND process_status <> 'OBSOLETE';

                        UPDATE XXD_ONT_RMA_INTF_CMT_HDR_STG_T
                           SET process_status = 'OBSOLETE', last_update_date = SYSDATE, last_updated_by = g_num_user_id,
                               last_update_login = g_num_login_id
                         WHERE     order_number = ln_order_number
                               --Start changes v1.3
                               --AND warehouse_code = lv_warehouse_code
                               AND warehouse_code = lv_wh_code
                               --End changes v1.3
                               AND process_status <> 'OBSOLETE';

                        UPDATE XXD_ONT_RMA_INTF_CMT_LN_STG_T
                           SET process_status = 'OBSOLETE', last_update_date = SYSDATE, last_updated_by = g_num_user_id,
                               last_update_login = g_num_login_id
                         WHERE     order_number = ln_order_number
                               --Start changes v1.3
                               --AND warehouse_code = lv_warehouse_code
                               AND warehouse_code = lv_wh_code
                               --End changes v1.3
                               AND process_status <> 'OBSOLETE';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            p_retcode   := 2;
                            p_error_buf   :=
                                   'Error occured setting obsolete status '
                                || SQLERRM;
                            fnd_file.put_line (fnd_file.LOG, p_error_buf);

                            RAISE exc_rma_process;
                    END;

                    fnd_file.put_line (fnd_file.LOG,
                                       'Updated obsolete status');


                    msg ('Inserting new header record');

                    SELECT XXD_ONT_RMA_INTF_HDR_STG_S.NEXTVAL
                      INTO l_num_stg_header_id
                      FROM DUAL;

                    --Insert into RMA header + comments
                    BEGIN
                        INSERT INTO XXD_ONT_RMA_INTF_HDR_STG_T (
                                        header_id,
                                        company,
                                        warehouse_code,
                                        order_number,
                                        order_type,
                                        brand_code,
                                        customer_code,
                                        customer_name,
                                        status,
                                        order_date,
                                        process_status,
                                        request_id,
                                        creation_date,
                                        created_by,
                                        last_update_date,
                                        last_updated_by,
                                        last_update_login,
                                        source_type,
                                        SOURCE,
                                        destination,
                                        auto_receipt_flag,
                                        return_source,
                                        sales_channel_code)
                             VALUES (l_num_stg_header_id, SUBSTR (lv_company, 1, 50), /*TRIM_DATA*/
                                                                                      --SUBSTR (lv_warehouse_code, 1, 10), /*TRIM_DATA*/  --commented as part of v1.3 changes
                                                                                      SUBSTR (lv_wh_code, 1, 10), --v1.3
                                                                                                                  SUBSTR (ln_order_number, 1, 30), /*TRIM_DATA*/
                                                                                                                                                   SUBSTR (lv_order_type, 1, 50), /*TRIM_DATA*/
                                                                                                                                                                                  SUBSTR (lv_brand_code, 1, 100), /*TRIM_DATA*/
                                                                                                                                                                                                                  SUBSTR (lv_customer_code, 1, 30), /*TRIM_DATA*/
                                                                                                                                                                                                                                                    SUBSTR (lv_customer_name, 1, 50), /*TRIM_DATA*/
                                                                                                                                                                                                                                                                                      'O', ld_rma_date, 'NEW', g_num_request_id, SYSDATE, g_num_user_id, SYSDATE, g_num_user_id, g_num_login_id, 'RETURN', p_source, p_dest, DECODE (lv_auto_receipt_flag, 'Y', 1, 0)
                                     , l_return_source, p_sales_channel);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            p_retcode   := 2;
                            p_error_buf   :=
                                   'Error occured for RMA header insert '
                                || SQLERRM;
                            fnd_file.put_line (fnd_file.LOG, p_error_buf);

                            RAISE exc_rma_process;
                    END;

                    l_num_comment_count   := 0;

                    IF lv_shipping_instructions IS NOT NULL
                    THEN
                        msg ('Inserting header shipping instructions');

                        BEGIN
                            l_num_comment_count   := l_num_comment_count + 10;

                            SELECT XXD_ONT_RMA_INTF_CMT_HDR_STG_S.NEXTVAL
                              INTO l_num_stg_hdr_cmt_id
                              FROM DUAL;

                            INSERT INTO XXD_ONT_RMA_INTF_CMT_HDR_STG_T (
                                            header_id,
                                            comment_id,
                                            warehouse_code,
                                            order_number,
                                            comment_type,
                                            comment_sequence,
                                            comment_text,
                                            process_status,
                                            request_id,
                                            creation_date,
                                            created_by,
                                            last_update_date,
                                            last_updated_by,
                                            last_update_login,
                                            source_type,
                                            SOURCE,
                                            destination)
                                 VALUES (l_num_stg_header_id, l_num_stg_hdr_cmt_id, --SUBSTR (lv_warehouse_code, 1, 10),  /*TRIM_DATA*/  --commented as part of v1.3 changes
                                                                                    SUBSTR (lv_wh_code, 1, 10), --v1.3
                                                                                                                SUBSTR (ln_order_number, 1, 30), /*TRIM_DATA*/
                                                                                                                                                 'SHIPPING', l_num_comment_count, SUBSTR (lv_shipping_instructions, 1, 2000), /*TRIM_DATA*/
                                                                                                                                                                                                                              'NEW', g_num_request_id, SYSDATE, g_num_user_id, SYSDATE, g_num_user_id, g_num_login_id, 'RETURN'
                                         , p_source, p_dest);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                p_retcode   := 2;
                                p_error_buf   :=
                                       'Error occured for RMA header shipping instruction insert '
                                    || SQLERRM;
                                fnd_file.put_line (fnd_file.LOG, p_error_buf);

                                RAISE exc_rma_process;
                        END;
                    END IF;

                    IF lv_packing_instructions IS NOT NULL
                    THEN
                        msg ('Inserting header packing instructions');

                        BEGIN
                            l_num_comment_count   := l_num_comment_count + 10;

                            SELECT XXD_ONT_RMA_INTF_CMT_HDR_STG_S.NEXTVAL
                              INTO l_num_stg_hdr_cmt_id
                              FROM DUAL;

                            INSERT INTO XXD_ONT_RMA_INTF_CMT_HDR_STG_T (
                                            header_id,
                                            comment_id,
                                            warehouse_code,
                                            order_number,
                                            comment_type,
                                            comment_sequence,
                                            comment_text,
                                            process_status,
                                            request_id,
                                            creation_date,
                                            created_by,
                                            last_update_date,
                                            last_updated_by,
                                            last_update_login,
                                            source_type,
                                            SOURCE,
                                            destination)
                                 VALUES (l_num_stg_header_id, l_num_stg_hdr_cmt_id, --SUBSTR (lv_warehouse_code, 1, 10),  /*TRIM_DATA*/  --commented as part of v1.3 changes
                                                                                    SUBSTR (lv_wh_code, 1, 10), --v1.3
                                                                                                                SUBSTR (ln_order_number, 1, 30), /*TRIM_DATA*/
                                                                                                                                                 'PACKING', l_num_comment_count, SUBSTR (lv_packing_instructions, 1, 2000), /*TRIM_DATA*/
                                                                                                                                                                                                                            'NEW', g_num_request_id, SYSDATE, g_num_user_id, SYSDATE, g_num_user_id, g_num_login_id, 'RETURN'
                                         , p_source, p_dest);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                p_retcode   := 2;
                                p_error_buf   :=
                                       'Error occured for RMA header packing instruction insert '
                                    || SQLERRM;
                                fnd_file.put_line (fnd_file.LOG, p_error_buf);

                                RAISE exc_rma_process;
                        END;
                    END IF;

                    IF lv_comments1 IS NOT NULL
                    THEN
                        msg ('Inserting header comments1');

                        BEGIN
                            l_num_comment_count   := l_num_comment_count + 10;

                            SELECT XXD_ONT_RMA_INTF_CMT_HDR_STG_S.NEXTVAL
                              INTO l_num_stg_hdr_cmt_id
                              FROM DUAL;

                            INSERT INTO XXD_ONT_RMA_INTF_CMT_HDR_STG_T (
                                            header_id,
                                            comment_id,
                                            warehouse_code,
                                            order_number,
                                            comment_type,
                                            comment_sequence,
                                            comment_text,
                                            process_status,
                                            request_id,
                                            creation_date,
                                            created_by,
                                            last_update_date,
                                            last_updated_by,
                                            last_update_login,
                                            source_type,
                                            SOURCE,
                                            destination)
                                 VALUES (l_num_stg_header_id, l_num_stg_hdr_cmt_id, --SUBSTR (lv_warehouse_code, 1, 10),  /*TRIM_DATA*/  --commented as part of v1.3 changes
                                                                                    SUBSTR (lv_wh_code, 1, 10), --v1.3
                                                                                                                SUBSTR (ln_order_number, 1, 30), /*TRIM_DATA*/
                                                                                                                                                 'COMMENTS1', l_num_comment_count, SUBSTR (lv_comments1, 1, 2000), /*TRIM_DATA*/
                                                                                                                                                                                                                   'NEW', g_num_request_id, SYSDATE, g_num_user_id, SYSDATE, g_num_user_id, g_num_login_id, 'RETURN'
                                         , p_source, p_dest);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                p_retcode   := 2;
                                p_error_buf   :=
                                       'Error occured for RMA header comments1 insert '
                                    || SQLERRM;
                                fnd_file.put_line (fnd_file.LOG, p_error_buf);

                                RAISE exc_rma_process;
                        END;
                    END IF;

                    IF lv_comments2 IS NOT NULL
                    THEN
                        msg ('Inserting header comments2');

                        BEGIN
                            l_num_comment_count   := l_num_comment_count + 10;

                            SELECT XXD_ONT_RMA_INTF_CMT_HDR_STG_S.NEXTVAL
                              INTO l_num_stg_hdr_cmt_id
                              FROM DUAL;

                            INSERT INTO XXD_ONT_RMA_INTF_CMT_HDR_STG_T (
                                            header_id,
                                            comment_id,
                                            warehouse_code,
                                            order_number,
                                            comment_type,
                                            comment_sequence,
                                            comment_text,
                                            process_status,
                                            request_id,
                                            creation_date,
                                            created_by,
                                            last_update_date,
                                            last_updated_by,
                                            last_update_login,
                                            source_type,
                                            SOURCE,
                                            destination)
                                 VALUES (l_num_stg_header_id, l_num_stg_hdr_cmt_id, --SUBSTR (lv_warehouse_code, 1, 10),  /*TRIM_DATA*/  --commented as part of v1.3 changes
                                                                                    SUBSTR (lv_wh_code, 1, 10), --v1.3
                                                                                                                SUBSTR (ln_order_number, 1, 30), /*TRIM_DATA*/
                                                                                                                                                 'COMMENTS2', l_num_comment_count, SUBSTR (lv_comments2, 1, 2000), /*TRIM_DATA*/
                                                                                                                                                                                                                   'NEW', g_num_request_id, SYSDATE, g_num_user_id, SYSDATE, g_num_user_id, g_num_login_id, 'RETURN'
                                         , p_source, p_dest);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                p_retcode   := 2;
                                p_error_buf   :=
                                       'Error occured for RMA header comments2 insert '
                                    || SQLERRM;
                                fnd_file.put_line (fnd_file.LOG, p_error_buf);

                                RAISE exc_rma_process;
                        END;
                    END IF;

                    /* end of header processing */

                    FOR c_rma_line_rec
                        IN c_rma_lines (c_rma_header_rec.header_id)
                    LOOP
                        msg ('Warehouse: ' || lv_warehouse_code);
                        msg ('RMA Number: ' || ln_order_number);
                        msg ('Line ID: ' || c_rma_line_rec.line_id);

                        BEGIN
                            SELECT attribute_value
                              INTO l_return_source
                              FROM xxdo.xxdoec_order_attribute
                             WHERE     attribute_type = 'RETURN_SOURCE'
                                   AND order_header_id =
                                       c_rma_header_rec.header_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_return_source   := NULL;
                        END;                --Insert into RMA lines + comments


                        SELECT XXDO.XXD_ONT_RMA_INTF_LN_STG_S.NEXTVAL
                          INTO l_num_stg_line_id
                          FROM DUAL;

                        BEGIN
                            INSERT INTO XXD_ONT_RMA_INTF_LN_STG_T (
                                            header_id,
                                            line_id,
                                            warehouse_code,
                                            order_number,
                                            line_number,
                                            item_number,
                                            qty,
                                            order_uom,
                                            reason_code,
                                            reason_description,
                                            sales_order_number,
                                            cust_po_number,
                                            latest_ship_date,
                                            process_status,
                                            request_id,
                                            creation_date,
                                            created_by,
                                            last_update_date,
                                            last_updated_by,
                                            last_update_login,
                                            source_type,
                                            SOURCE,
                                            destination)
                                 VALUES (l_num_stg_header_id, l_num_stg_line_id, SUBSTR (c_rma_line_rec.warehouse_code, 1, 10), /*TRIM_DATA*/
                                                                                                                                SUBSTR (ln_order_number, 1, 30), /*TRIM_DATA*/
                                                                                                                                                                 c_rma_line_rec.line_id, SUBSTR (c_rma_line_rec.item_number, 1, 400), /*TRIM_DATA*/
                                                                                                                                                                                                                                      SUBSTR (c_rma_line_rec.qty, 1, 30), /*TRIM_DATA*/
                                                                                                                                                                                                                                                                          SUBSTR (c_rma_line_rec.order_uom, 1, 50), /*TRIM_DATA*/
                                                                                                                                                                                                                                                                                                                    SUBSTR (c_rma_line_rec.reason_code, 1, 50), /*TRIM_DATA*/
                                                                                                                                                                                                                                                                                                                                                                SUBSTR (c_rma_line_rec.reason_description, 1, 250), /*TRIM_DATA*/
                                                                                                                                                                                                                                                                                                                                                                                                                    SUBSTR (c_rma_line_rec.ref_sales_order_number, 1, 20), /*TRIM_DATA*/
                                                                                                                                                                                                                                                                                                                                                                                                                                                                           SUBSTR (NVL (c_rma_line_rec.ref_cust_po_number, lv_cust_po_number), 1, 30), /*TRIM_DATA*/
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       --If line has reference to SO. then send PO # of SO,  otherwise send PO# of RMA
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       c_rma_line_rec.latest_accept_date, 'NEW', g_num_request_id, SYSDATE, g_num_user_id, SYSDATE, g_num_user_id, g_num_login_id, 'RETURN'
                                         , p_source, p_dest);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                p_retcode   := 2;
                                p_error_buf   :=
                                       'Error occured for RMA line insert '
                                    || SQLERRM;
                                fnd_file.put_line (fnd_file.LOG, p_error_buf);

                                RAISE exc_rma_process;
                        END;

                        l_num_comment_count   := 0;

                        IF c_rma_line_rec.line_shipping_instructions
                               IS NOT NULL
                        THEN
                            BEGIN
                                l_num_comment_count   :=
                                    l_num_comment_count + 10;

                                SELECT XXD_ONT_RMA_INTF_CMT_LN_STG_S.NEXTVAL
                                  INTO l_num_stg_line_cmt_id
                                  FROM DUAL;

                                INSERT INTO XXD_ONT_RMA_INTF_CMT_LN_STG_T (
                                                line_id,
                                                comment_id,
                                                warehouse_code,
                                                order_number,
                                                line_number,
                                                comment_type,
                                                comment_sequence,
                                                comment_text,
                                                process_status,
                                                request_id,
                                                creation_date,
                                                created_by,
                                                last_update_date,
                                                last_updated_by,
                                                last_update_login,
                                                source_type,
                                                SOURCE,
                                                destination)
                                     VALUES (l_num_stg_line_id, l_num_stg_line_cmt_id, SUBSTR (c_rma_line_rec.warehouse_code, 1, 10), /*TRIM_DATA*/
                                                                                                                                      SUBSTR (ln_order_number, 1, 30), /*TRIM_DATA*/
                                                                                                                                                                       c_rma_line_rec.line_id, 'SHIPPING', l_num_comment_count, SUBSTR (c_rma_line_rec.line_shipping_instructions, 1, 4000), /*TRIM_DATA*/
                                                                                                                                                                                                                                                                                             'NEW', g_num_request_id, SYSDATE, g_num_user_id, SYSDATE, g_num_user_id, g_num_login_id
                                             , 'RETURN', p_source, p_dest);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    p_retcode   := 2;
                                    p_error_buf   :=
                                           'Error occured for RMA line shipping instruction insert '
                                        || SQLERRM;
                                    fnd_file.put_line (fnd_file.LOG,
                                                       p_error_buf);

                                    RAISE exc_rma_process;
                            END;
                        END IF;

                        IF c_rma_line_rec.line_packing_instructions
                               IS NOT NULL
                        THEN
                            BEGIN
                                l_num_comment_count   :=
                                    l_num_comment_count + 10;

                                SELECT XXD_ONT_RMA_INTF_CMT_LN_STG_S.NEXTVAL
                                  INTO l_num_stg_line_cmt_id
                                  FROM DUAL;

                                INSERT INTO XXD_ONT_RMA_INTF_CMT_LN_STG_T (
                                                line_id,
                                                comment_id,
                                                warehouse_code,
                                                order_number,
                                                line_number,
                                                comment_type,
                                                comment_sequence,
                                                comment_text,
                                                process_status,
                                                request_id,
                                                creation_date,
                                                created_by,
                                                last_update_date,
                                                last_updated_by,
                                                last_update_login,
                                                source_type,
                                                SOURCE,
                                                destination)
                                     VALUES (l_num_stg_line_id, l_num_stg_line_cmt_id, SUBSTR (c_rma_line_rec.warehouse_code, 1, 10), /*TRIM_DATA*/
                                                                                                                                      SUBSTR (ln_order_number, 1, 30), /*TRIM_DATA*/
                                                                                                                                                                       c_rma_line_rec.line_id, 'PACKING', l_num_comment_count, SUBSTR (c_rma_line_rec.line_packing_instructions, 1, 4000), /*TRIM_DATA*/
                                                                                                                                                                                                                                                                                           'NEW', g_num_request_id, SYSDATE, g_num_user_id, SYSDATE, g_num_user_id, g_num_login_id
                                             , 'RETURN', p_source, p_dest);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    p_retcode   := 2;
                                    p_error_buf   :=
                                           'Error occured for RMA line packing instruction insert '
                                        || SQLERRM;
                                    fnd_file.put_line (fnd_file.LOG,
                                                       p_error_buf);

                                    RAISE exc_rma_process;
                            END;
                        END IF;
                    END LOOP;

                    --Commit RMA record
                    COMMIT;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'commmit records for warehouse, order number: '
                        || lv_warehouse_code
                        || '  '
                        || ln_order_number);
                EXCEPTION
                    WHEN exc_rma_process
                    THEN
                        --Error occurred while extracting an RMA
                        --rollback specific RMA and continue loop
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'rollback records for warehouse, order number: '
                            || lv_warehouse_code
                            || '  '
                            || ln_order_number
                            || ' Error : '
                            || p_error_buf);
                        ROLLBACK TO rma_header;
                    WHEN OTHERS
                    THEN
                        --Other error rollback specific RMA and exit process altogether
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'rollback records for warehouse, order number: '
                            || lv_warehouse_code
                            || '  '
                            || ln_order_number
                            || ' Exiting process with error :'
                            || SQLERRM);
                        ROLLBACK;
                        --exit procedure altogether
                        RETURN;
                END;
            END IF;
        END LOOP;

        ---catch all commit;
        COMMIT;
        p_error_buf   := '';
        p_retcode     := 0;

        fnd_file.put_line (fnd_file.LOG, 'RMA detail extraction completed');
    EXCEPTION
        WHEN OTHERS
        THEN
            p_error_buf   := 'Unexpected error: ' || SQLERRM;
            ROLLBACK;
            p_retcode     := 2;
            fnd_file.put_line (fnd_file.LOG, p_error_buf);
    END;



    PROCEDURE rma_extract_main (errbuf OUT VARCHAR2, retcode OUT NUMBER, p_organization_id IN NUMBER, p_rma_number IN NUMBER, p_sales_channel IN VARCHAR2, p_re_extract IN VARCHAR2:= 'N'
                                , p_debug_mode IN VARCHAR2:= 'N')
    IS
        l_chr_instance          VARCHAR2 (20) := NULL;
        l_dte_last_run_time     DATE;
        l_dte_next_run_time     DATE;
        l_num_conc_prog_id      NUMBER := fnd_global.conc_program_id;
        l_chr_err_buf           VARCHAR (500);
        l_chr_ret_code          NUMBER;
        lv_request_id           NUMBER;
        lv_print_msg            VARCHAR (500);
        l_chr_status            VARCHAR (5) := NULL;
        l_num_rec_count         NUMBER := 0;
        l_upd_batch_sts         NUMBER := 0;
        l_upd_batch_err_msg     VARCHAR2 (2000) := NULL;
        l_upd_batch_sts_e       NUMBER := 0;            --Added for change 2.3
        l_upd_batch_err_msg_e   VARCHAR2 (2000) := NULL; --Added for change 2.3
        lv_error_msg            VARCHAR2 (2000) := NULL; --Added for change 2.5
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
               'RMA Extract Main program started for RMA outbound interface:'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

        /*set the debug value - global variable. This controls the complete log throughout the program */
        IF p_debug_mode = 'Y'
        THEN
            c_num_debug   := 1;
        ELSE
            c_num_debug   := 0;
        END IF;

        /* Print the input parameters */
        fnd_file.put_line (fnd_file.LOG, 'Input Parameters');
        fnd_file.put_line (fnd_file.LOG,
                           'Organization        : ' || p_organization_id);
        fnd_file.put_line (fnd_file.LOG, 'RMA         : ' || p_rma_number);

        fnd_file.put_line (fnd_file.LOG,
                           'Sales Channel       : ' || p_sales_channel); --Added for change 2.0
        fnd_file.put_line (fnd_file.LOG,
                           'Re-extract(Y/N)          : ' || p_re_extract);
        fnd_file.put_line (fnd_file.LOG,
                           'Debug(Y/N)          : ' || p_debug_mode);

        /*Get last run details for this concurrent program */
        -- Get the interface setup
        BEGIN
            l_dte_last_run_time   :=
                get_last_run_time (pn_warehouse_id    => p_organization_id,
                                   pv_sales_channel   => p_sales_channel);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Last run time : '
                || TO_CHAR (l_dte_last_run_time, 'DD-Mon-RRRR HH24:MI:SS'));
        EXCEPTION
            WHEN OTHERS
            THEN
                errbuf   :=
                    'Unexpected error while fetching last run: ' || SQLERRM;
                fnd_file.put_line (fnd_file.LOG, errbuf);
        END;

        l_dte_next_run_time   := SYSDATE;

        IF l_dte_last_run_time IS NULL
        THEN
            l_dte_last_run_time   := SYSDATE - 90;
            fnd_file.put_line (
                fnd_file.LOG,
                'Last run is set to : ' || l_dte_last_run_time);
        END IF;

        fnd_file.put_line (
            fnd_file.LOG,
               'Return Extraction procedure invoked at :'
            || TO_CHAR (SYSDATE, 'DD-Mon-RRRR HH24:MI:SS'));

        /* Invoke RMA extraction process */
        extract_rma_stage_data (p_organization_id => p_organization_id, p_rma_num => p_rma_number, p_sales_channel => p_sales_channel --Added for change 2.0
                                                                                                                                     , p_last_run_date => l_dte_last_run_time, p_re_extract => p_re_extract, p_retcode => l_chr_ret_code
                                , p_error_buf => l_chr_err_buf);


        IF l_chr_ret_code = 1
        THEN
            --retcode := 1; --Commented for change 2.0
            --retcode := 'WARNING'; --Commented for change 2.0
            retcode   := l_chr_ret_code;                --Added for change 2.0
            errbuf    := l_chr_err_buf;                 --Added for change 2.0
        END IF;

        fnd_file.put_line (
            fnd_file.LOG,
               'RMA Extraction procedure Completed at :'
            || TO_CHAR (SYSDATE, 'DD-Mon-RRRR HH24:MI:SS'));
        fnd_file.put_line (
            fnd_file.LOG,
               'Batching procedure started at :'
            || TO_CHAR (SYSDATE, 'DD-Mon-RRRR HH24:MI:SS'));

        --Calling procedure to do Batching by Order type(Sales Channel)--START
        FOR i
            IN (  SELECT sales_channel_code
                    FROM xxdo.xxd_ont_rma_intf_hdr_stg_t
                   WHERE     1 = 1
                         AND request_id = g_num_request_id
                         AND process_status = gc_new_status
                GROUP BY sales_channel_code
                ORDER BY sales_channel_code)
        LOOP
            proc_update_batch (pn_request_id => g_num_request_id, pv_sales_channel => p_sales_channel, x_update_status => l_upd_batch_sts
                               , x_error_message => l_upd_batch_err_msg);
            NULL;
        END LOOP;

        IF l_upd_batch_sts <> g_success
        THEN
            retcode   := l_upd_batch_sts;
            errbuf    := l_upd_batch_err_msg;
        END IF;

        --START  handle the exceptions where batch number updates failed previously and still the status is NEW
        IF p_sales_channel IS NOT NULL
        THEN
            FOR j
                IN (  SELECT sales_channel_code, request_id
                        FROM xxdo.xxd_ont_rma_intf_hdr_stg_t
                       WHERE     1 = 1
                             AND request_id <> g_num_request_id
                             AND process_status = gc_new_status
                             AND batch_number IS NULL
                             AND sales_channel_code = p_sales_channel
                    GROUP BY sales_channel_code, request_id
                    ORDER BY sales_channel_code, request_id)
            LOOP
                proc_update_batch (pn_request_id => j.request_id, pv_sales_channel => j.sales_channel_code, x_update_status => l_upd_batch_sts_e
                                   , x_error_message => l_upd_batch_err_msg_e);
                NULL;
            END LOOP;
        END IF;

        IF l_upd_batch_sts <> g_success
        THEN
            retcode   := l_upd_batch_sts_e;
            errbuf    := l_upd_batch_err_msg_e;
        END IF;

        --END  handle the exceptions where batch number updates failed and still the status is NEW

        --Calling procedure to do Batching --END
        fnd_file.put_line (
            fnd_file.LOG,
               'Batching procedure Completed at :'
            || TO_CHAR (SYSDATE, 'DD-Mon-RRRR HH24:MI:SS'));

        /* update the last run details if the program is not run with specific inputs */
        IF (p_rma_number IS NULL --AND p_organization IS NULL --Commented for change 2.0 --Not Required(There is no chance of Org being NULL as it is mandatory parameter)
                                --Added for change 2.0 --Do not update last update date if the program is run in Regenerate XML Mode
                                )
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Updating the last run to : ' || l_dte_next_run_time);

            BEGIN
                set_last_run_time (pn_warehouse_id    => p_organization_id,
                                   pv_sales_channel   => p_sales_channel,
                                   pd_last_run_date   => l_dte_next_run_time);
            EXCEPTION
                WHEN OTHERS
                THEN
                    errbuf   :=
                           'Unexpected error while updating the next run time : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, errbuf);
            END;
        END IF;

        fnd_file.put_line (
            fnd_file.LOG,
               'RMA Main program Completed for RMA outbound interface:'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
    EXCEPTION
        WHEN OTHERS
        THEN
            --msg('Error occured in Main extract at step ' || lv_print_msg || '-' || SQLERRM);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error occured in Main rma_extract_main procedure at step '
                || lv_print_msg
                || '-'
                || SQLERRM);
            retcode   := g_error;
            errbuf    := SQLERRM;
    END;

    --This procedure is called by SOA process to update process status of RMAs for batch number

    PROCEDURE upd_batch_process_sts (p_batch_number IN NUMBER, p_from_status IN VARCHAR2, p_to_status IN VARCHAR2
                                     , p_error_message IN VARCHAR2, x_update_status OUT VARCHAR2, x_error_message OUT VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        --Local Variables Declaration
        l_error_msg   VARCHAR2 (2000);
    BEGIN
        UPDATE xxdo.xxd_ont_rma_intf_hdr_stg_t
           SET process_status = p_to_status, error_message = p_error_message, last_update_date = SYSDATE,
               last_updated_by = g_num_user_id, last_update_login = g_num_login_id
         WHERE     1 = 1
               AND process_status = p_from_status
               AND batch_number = p_batch_number;

        UPDATE xxdo.xxd_ont_rma_intf_ln_stg_t
           SET process_status = p_to_status, error_message = p_error_message, last_update_date = SYSDATE,
               last_updated_by = g_num_user_id, last_update_login = g_num_login_id
         WHERE     1 = 1
               AND process_status = p_from_status
               AND batch_number = p_batch_number;

        UPDATE xxdo.xxd_ont_rma_intf_cmt_hdr_stg_t
           SET process_status = p_to_status, error_message = p_error_message, last_update_date = SYSDATE,
               last_updated_by = g_num_user_id, last_update_login = g_num_login_id
         WHERE     1 = 1
               AND process_status = p_from_status
               AND batch_number = p_batch_number;

        UPDATE xxdo.xxd_ont_rma_intf_cmt_ln_stg_t
           SET process_status = p_to_status, error_message = p_error_message, last_update_date = SYSDATE,
               last_updated_by = g_num_user_id, last_update_login = g_num_login_id
         WHERE     1 = 1
               AND process_status = p_from_status
               AND batch_number = p_batch_number;


        COMMIT;
        x_update_status   := g_ret_success;
        x_error_message   := NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_error_msg       :=
                SUBSTR (
                       'Error in UPD_BATCH_PROCESS_STS for batch number '
                    || p_batch_number
                    || ' from status:'
                    || p_from_status
                    || ' to '
                    || p_to_status
                    || '. Error is:'
                    || SQLERRM,
                    1,
                    2000);
            x_update_status   := g_ret_error;
            x_error_message   := l_error_msg;
            ROLLBACK;
    END upd_batch_process_sts;


    PROCEDURE rma_extract_soa_obj_type (
        p_org_code        IN     VARCHAR2,                               --1.2
        x_batch_num_tbl      OUT xxd_ont_hj_rma_batch_tbl_typ)
    IS
        l_proc_name          VARCHAR2 (30) := 'RMA_EXTRACT_SOA_OBJ_TYPE';
        l_err_msg            VARCHAR2 (2000) := NULL;
        l_batch_num_tbl      xxd_ont_hj_rma_batch_tbl_typ;
        l_update_status      VARCHAR2 (1) := 'S';
        l_error_message      VARCHAR2 (2000) := NULL;
        ln_created_by        NUMBER := -1;
        ln_reprocess_hours   NUMBER := 3;

        --TODO Get this from lookup
        -- gn_reprocess_hours := lookup

        --Cursor to identify the records in inprocess in last X hours
        CURSOR inprc_cur IS
              SELECT DISTINCT stg.request_id, stg.batch_number, stg.process_status,
                              stg.warehouse_code
                FROM xxdo.xxd_ont_rma_intf_hdr_stg_t stg
               WHERE     1 = 1
                     AND stg.process_status = gc_inprocess_status
                     AND stg.batch_number IS NOT NULL
                     AND stg.last_update_date <
                         (SYSDATE - NVL (ln_reprocess_hours, 3) / 24) --more than last gn_reprocess_hours or 3 hours
                     AND warehouse_code = p_org_code                     --1.2
            ORDER BY stg.request_id, stg.batch_number;
    BEGIN
        BEGIN
            SELECT user_id
              INTO ln_created_by
              FROM dba_users
             WHERE username = 'SOA_INT';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_created_by   := -1;
        END;

        --Identify the records stuck in INPROCESS status and update the status from INPROCESS to NEW
        FOR inprc_rec IN inprc_cur
        LOOP
            l_err_msg         := NULL;
            l_update_status   := 'S';
            l_error_message   := NULL;
            upd_batch_process_sts (
                p_batch_number    => inprc_rec.batch_number,
                p_from_status     => inprc_rec.process_status,
                p_to_status       => gc_new_status,
                p_error_message   => NULL,
                x_update_status   => l_update_status,
                x_error_message   => l_error_message);

            IF l_update_status <> 'S'
            THEN
                l_err_msg   :=
                    SUBSTR (
                           'SOA_CALL. In INPRC_CUR cursor loop. Error updating process status from '
                        || gc_inprocess_status
                        || ' to '
                        || gc_new_status
                        || ' for Batch Number:'
                        || inprc_rec.batch_number
                        || ' for warehouse:'
                        || inprc_rec.warehouse_code
                        || gc_period_char
                        || 'Error is:'
                        || l_error_message,
                        1,
                        2000);
                --Write the error message into debug table
                debug_prc (pv_application => 'EBS_HJ_RMA_SOA_CALL', pv_debug_text => l_err_msg, pv_debug_message => NULL, pn_created_by => ln_created_by, pn_session_id => USERENV ('SESSION_ID'), pn_debug_id => -1
                           , pn_request_id => -1);
            END IF;
        END LOOP;


        --Get the new records and assign to the out parameter
        BEGIN
            SELECT yy.*
              BULK COLLECT INTO x_batch_num_tbl
              FROM (SELECT xxd_ont_hj_rma_batch_obj_typ (xx.request_id, xx.batch_number, xx.process_status)
                      FROM (  SELECT DISTINCT stg.request_id, stg.batch_number, stg.process_status
                                FROM xxdo.xxd_ont_rma_intf_hdr_stg_t stg
                               WHERE     1 = 1
                                     AND stg.process_status = gc_new_status
                                     AND stg.batch_number IS NOT NULL
                                     AND stg.warehouse_code = p_org_code
                            ORDER BY stg.request_id, stg.batch_number) xx) yy;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_err_msg   :=
                    SUBSTR (
                           'SOA_CALL - Exception in query to get batch numbers and assign them to x_batch_num_tbl table type Out Variable in '
                        || gc_package_name
                        || '.'
                        || l_proc_name
                        || '. Error is: '
                        || SQLERRM,
                        1,
                        2000);
                --Write the error message into debug table
                debug_prc (pv_application => 'EBS_HJ_RMA_SOA_CALL', pv_debug_text => l_err_msg, pv_debug_message => NULL, pn_created_by => ln_created_by, pn_session_id => USERENV ('SESSION_ID'), pn_debug_id => -1
                           , pn_request_id => -1);
        END;

        --If there are records with NEW status and inserted into the x_batch_num_tbl table type
        --then update process for the batch numbers from NEW to INPROCESS
        IF x_batch_num_tbl.COUNT > 0
        THEN
            FOR i IN 1 .. x_batch_num_tbl.COUNT
            LOOP
                l_err_msg         := NULL;
                l_update_status   := 'S';
                l_error_message   := NULL;
                --Update the process status of the batch numbers from NEW to INPROCESS
                upd_batch_process_sts (
                    p_batch_number    => x_batch_num_tbl (i).batch_number,
                    p_from_status     => x_batch_num_tbl (i).process_status,
                    p_to_status       => gc_inprocess_status,
                    p_error_message   => NULL,
                    x_update_status   => l_update_status,
                    x_error_message   => l_error_message);

                IF l_update_status <> 'S'
                THEN
                    l_err_msg   :=
                        SUBSTR (
                               'SOA_CALL. In x_batch_num_tbl loop. Error updating process status from '
                            || gc_new_status
                            || ' to '
                            || gc_inprocess_status
                            || ' for Batch Number:'
                            || x_batch_num_tbl (i).batch_number
                            || ' for Warehouse:'
                            || p_org_code
                            || gc_period_char
                            || 'Error is:'
                            || l_error_message,
                            1,
                            2000);

                    --Write the error message into debug table
                    debug_prc (pv_application => 'EBS_HJ_RMA_SOA_CALL', pv_debug_text => l_err_msg, pv_debug_message => NULL, pn_created_by => ln_created_by, pn_session_id => USERENV ('SESSION_ID'), pn_debug_id => -1
                               , pn_request_id => -1);
                ELSE
                    --If the process status is updated successfully for the batch number, then assign INPROCESS status to process status which is sent to SOA
                    x_batch_num_tbl (i).process_status   :=
                        gc_inprocess_status;
                END IF;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_err_msg   :=
                SUBSTR (
                       'SOA_CALL - Main Exception@'
                    || l_proc_name
                    || '. Error is: '
                    || SQLERRM,
                    1,
                    2000);

            --Write the error message into debug table
            debug_prc (pv_application => 'EBS_HJ_RMA_SOA_CALL', pv_debug_text => l_err_msg, pv_debug_message => NULL, pn_created_by => ln_created_by, pn_session_id => USERENV ('SESSION_ID'), pn_debug_id => -1
                       , pn_request_id => -1);
    END;

    PROCEDURE purge_log_data (p_num_purge_log_days IN NUMBER)
    IS
        l_dte_sysdate   DATE := SYSDATE;
    BEGIN
        msg (
               'In EBS to HJ integration Log tables purge program(PURGE_LOG_DATA) - START. Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        fnd_file.put_line (fnd_file.LOG, 'Parameters.');
        fnd_file.put_line (fnd_file.LOG, '----------------------');
        fnd_file.put_line (fnd_file.LOG,
                           'Purge Days:' || p_num_purge_log_days);
        fnd_file.put_line (fnd_file.LOG, '----------------------');
        fnd_file.put_line (
            fnd_file.LOG,
            'Purging ' || p_num_purge_log_days || ' days old records...');

        /*RMA header interface*/
        BEGIN
            DELETE FROM xxdo.xxd_ont_rma_intf_hdr_log_t
                  WHERE creation_date < l_dte_sysdate - p_num_purge_log_days;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                       'Error happened while purging shipment headers Log data: '
                    || SQLERRM);
        END;

        /*RMA line interface*/
        BEGIN
            DELETE FROM xxdo.xxd_ont_rma_intf_ln_log_t
                  WHERE creation_date < l_dte_sysdate - p_num_purge_log_days;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                       'Error happened while purging RMA Line Log Data '
                    || SQLERRM);
        END;

        /*RMA comment header interface*/
        BEGIN
            DELETE FROM xxdo.xxd_ont_rma_intf_cmt_hdr_log_t
                  WHERE creation_date < l_dte_sysdate - p_num_purge_log_days;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                       'Error happened while purging RMA Comment Header Log Data '
                    || SQLERRM);
        END;

        /*RMA comment line interface*/
        BEGIN
            DELETE FROM xxdo.xxd_ont_rma_intf_cmt_ln_log_t
                  WHERE creation_date < l_dte_sysdate - p_num_purge_log_days;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                       'Error happened while purging RMA Comment Line Log Data '
                    || SQLERRM);
        END;

        msg (
               'In EBS to HJ integration Log tables purge program(PURGE_LOG_DATA) - END. Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexepected error while purging the Log table records'
                || SQLERRM);
    END purge_log_data;


    PROCEDURE purge_stg_data (p_num_purge_days IN NUMBER)
    IS
        l_dte_sysdate   DATE := SYSDATE;
    BEGIN
        msg (
               'In EBS to HJ integration Staging tables purge program(PURGE_STG_DATA) - START. Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        fnd_file.put_line (fnd_file.LOG, 'Parameters.');
        fnd_file.put_line (fnd_file.LOG, '----------------------');
        fnd_file.put_line (fnd_file.LOG, 'Purge Days:' || p_num_purge_days);
        fnd_file.put_line (fnd_file.LOG, '----------------------');
        fnd_file.put_line (
            fnd_file.LOG,
            'Purging ' || p_num_purge_days || ' days old records...');

        /*RMA header interface*/
        BEGIN
            DELETE FROM
                xxdo.xxd_ont_rma_intf_hdr_stg_t
                  WHERE     process_status = gc_obsolete_status
                        AND creation_date < l_dte_sysdate - p_num_purge_days;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                       'Error happened while purging shipment headers data: '
                    || SQLERRM);
        END;

        /*RMA line interface*/
        BEGIN
            DELETE FROM
                xxdo.xxd_ont_rma_intf_ln_stg_t
                  WHERE     process_status = gc_obsolete_status
                        AND creation_date < l_dte_sysdate - p_num_purge_days;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                    'Error happened while purging RMA Line Data ' || SQLERRM);
        END;

        /*RMA comment header interface*/
        BEGIN
            DELETE FROM
                xxdo.xxd_ont_rma_intf_cmt_hdr_stg_t
                  WHERE     process_status = gc_obsolete_status
                        AND creation_date < l_dte_sysdate - p_num_purge_days;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                       'Error happened while purging RMA Comment Header Data '
                    || SQLERRM);
        END;

        /*RMA comment line interface*/
        BEGIN
            DELETE FROM
                xxdo.xxd_ont_rma_intf_cmt_ln_stg_t
                  WHERE     process_status = gc_obsolete_status
                        AND creation_date < l_dte_sysdate - p_num_purge_days;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                       'Error happened while purging RMA Comment Line Data '
                    || SQLERRM);
        END;


        msg (
               'In EBS to HJ integration Staging tables purge program(PURGE_STG_DATA) - END. Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexepected error while purging the records' || SQLERRM);
    END purge_stg_data;

    PROCEDURE archive_stg_data (p_num_days IN NUMBER)
    IS
        l_dte_sysdate   DATE := SYSDATE;
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            'EBS to HJ integration tables archive program started.');


        /*RMA header interface*/
        BEGIN
            INSERT INTO xxdo.xxd_ont_rma_intf_hdr_log_t (warehouse_code,
                                                         order_number,
                                                         order_type,
                                                         company,
                                                         brand_code,
                                                         customer_code,
                                                         customer_name,
                                                         status,
                                                         order_date,
                                                         process_status,
                                                         error_message,
                                                         sales_channel_code,
                                                         request_id,
                                                         creation_date,
                                                         created_by,
                                                         last_update_date,
                                                         last_updated_by,
                                                         last_update_login,
                                                         source_type,
                                                         attribute1,
                                                         attribute2,
                                                         attribute3,
                                                         attribute4,
                                                         attribute5,
                                                         attribute6,
                                                         attribute7,
                                                         attribute8,
                                                         attribute9,
                                                         attribute10,
                                                         attribute11,
                                                         attribute12,
                                                         attribute13,
                                                         attribute14,
                                                         attribute15,
                                                         attribute16,
                                                         attribute17,
                                                         attribute18,
                                                         attribute19,
                                                         attribute20,
                                                         source,
                                                         destination,
                                                         header_id,
                                                         auto_receipt_flag,
                                                         return_source,
                                                         batch_number)
                SELECT warehouse_code, order_number, order_type,
                       company, brand_code, customer_code,
                       customer_name, status, order_date,
                       process_status, error_message, sales_channel_code,
                       request_id, creation_date, created_by,
                       last_update_date, last_updated_by, last_update_login,
                       source_type, attribute1, attribute2,
                       attribute3, attribute4, attribute5,
                       attribute6, attribute7, attribute8,
                       attribute9, attribute10, attribute11,
                       attribute12, attribute13, attribute14,
                       attribute15, attribute16, attribute17,
                       attribute18, attribute19, attribute20,
                       source, destination, header_id,
                       auto_receipt_flag, return_source, batch_number
                  FROM xxdo.xxd_ont_rma_intf_hdr_stg_t
                 WHERE     process_status = gc_processed_status
                       AND creation_date < l_dte_sysdate - p_num_days;

            DELETE FROM
                xxdo.xxd_ont_rma_intf_hdr_stg_t
                  WHERE     process_status = gc_processed_status
                        AND creation_date < l_dte_sysdate - p_num_days;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                       'Error happened while archiving shipment headers data: '
                    || SQLERRM);
        END;

        /*RMA line interface*/
        BEGIN
            INSERT INTO xxdo.xxd_ont_rma_intf_ln_log_t (warehouse_code,
                                                        order_number,
                                                        line_number,
                                                        item_number,
                                                        qty,
                                                        order_uom,
                                                        reason_code,
                                                        reason_description,
                                                        latest_ship_date,
                                                        sales_order_number,
                                                        cust_po_number,
                                                        process_status,
                                                        error_message,
                                                        request_id,
                                                        creation_date,
                                                        created_by,
                                                        last_update_date,
                                                        last_updated_by,
                                                        last_update_login,
                                                        source_type,
                                                        attribute1,
                                                        attribute2,
                                                        attribute3,
                                                        attribute4,
                                                        attribute5,
                                                        attribute6,
                                                        attribute7,
                                                        attribute8,
                                                        attribute9,
                                                        attribute10,
                                                        attribute11,
                                                        attribute12,
                                                        attribute13,
                                                        attribute14,
                                                        attribute15,
                                                        attribute16,
                                                        attribute17,
                                                        attribute18,
                                                        attribute19,
                                                        attribute20,
                                                        source,
                                                        destination,
                                                        header_id,
                                                        line_id,
                                                        batch_number)
                SELECT warehouse_code, order_number, line_number,
                       item_number, qty, order_uom,
                       reason_code, reason_description, latest_ship_date,
                       sales_order_number, cust_po_number, process_status,
                       error_message, request_id, creation_date,
                       created_by, last_update_date, last_updated_by,
                       last_update_login, source_type, attribute1,
                       attribute2, attribute3, attribute4,
                       attribute5, attribute6, attribute7,
                       attribute8, attribute9, attribute10,
                       attribute11, attribute12, attribute13,
                       attribute14, attribute15, attribute16,
                       attribute17, attribute18, attribute19,
                       attribute20, source, destination,
                       header_id, line_id, batch_number
                  FROM xxdo.xxd_ont_rma_intf_ln_stg_t
                 WHERE     process_status = gc_processed_status
                       AND creation_date < l_dte_sysdate - p_num_days;

            DELETE FROM
                xxdo.xxd_ont_rma_intf_ln_stg_t
                  WHERE     process_status = gc_processed_status
                        AND creation_date < l_dte_sysdate - p_num_days;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                       'Error happened while archiving RMA Line Data '
                    || SQLERRM);
        END;

        /*RMA comment header interface*/
        BEGIN
            INSERT INTO xxdo.xxd_ont_rma_intf_cmt_hdr_log_t (
                            warehouse_code,
                            order_number,
                            comment_type,
                            comment_sequence,
                            comment_text,
                            process_status,
                            error_message,
                            request_id,
                            creation_date,
                            created_by,
                            last_update_date,
                            last_updated_by,
                            last_update_login,
                            source_type,
                            attribute1,
                            attribute2,
                            attribute3,
                            attribute4,
                            attribute5,
                            attribute6,
                            attribute7,
                            attribute8,
                            attribute9,
                            attribute10,
                            attribute11,
                            attribute12,
                            attribute13,
                            attribute14,
                            attribute15,
                            attribute16,
                            attribute17,
                            attribute18,
                            attribute19,
                            attribute20,
                            source,
                            destination,
                            header_id,
                            comment_id,
                            batch_number)
                SELECT warehouse_code, order_number, comment_type,
                       comment_sequence, comment_text, process_status,
                       error_message, request_id, creation_date,
                       created_by, last_update_date, last_updated_by,
                       last_update_login, source_type, attribute1,
                       attribute2, attribute3, attribute4,
                       attribute5, attribute6, attribute7,
                       attribute8, attribute9, attribute10,
                       attribute11, attribute12, attribute13,
                       attribute14, attribute15, attribute16,
                       attribute17, attribute18, attribute19,
                       attribute20, source, destination,
                       header_id, comment_id, batch_number
                  FROM xxdo.xxd_ont_rma_intf_cmt_hdr_stg_t
                 WHERE     process_status = gc_processed_status
                       AND creation_date < l_dte_sysdate - p_num_days;

            DELETE FROM
                xxdo.xxd_ont_rma_intf_cmt_hdr_stg_t
                  WHERE     process_status = gc_processed_status
                        AND creation_date < l_dte_sysdate - p_num_days;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                       'Error happened while archiving RMA Comment Header Data '
                    || SQLERRM);
        END;

        /*RMA comment line interface*/
        BEGIN
            INSERT INTO xxdo.xxd_ont_rma_intf_cmt_ln_log_t (warehouse_code, order_number, line_number, comment_type, comment_sequence, comment_text, process_status, error_message, request_id, creation_date, created_by, last_update_date, last_updated_by, last_update_login, source_type, attribute1, attribute2, attribute3, attribute4, attribute5, attribute6, attribute7, attribute8, attribute9, attribute10, attribute11, attribute12, attribute13, attribute14, attribute15, attribute16, attribute17, attribute18, attribute19, attribute20, source, destination, line_id, comment_id
                                                            , batch_number)
                SELECT warehouse_code, order_number, line_number,
                       comment_type, comment_sequence, comment_text,
                       process_status, error_message, request_id,
                       creation_date, created_by, last_update_date,
                       last_updated_by, last_update_login, source_type,
                       attribute1, attribute2, attribute3,
                       attribute4, attribute5, attribute6,
                       attribute7, attribute8, attribute9,
                       attribute10, attribute11, attribute12,
                       attribute13, attribute14, attribute15,
                       attribute16, attribute17, attribute18,
                       attribute19, attribute20, source,
                       destination, line_id, comment_id,
                       batch_number
                  FROM xxdo.xxd_ont_rma_intf_cmt_ln_stg_t
                 WHERE     process_status = gc_processed_status
                       AND creation_date < l_dte_sysdate - p_num_days;

            DELETE FROM
                xxdo.xxd_ont_rma_intf_cmt_ln_stg_t
                  WHERE     process_status = gc_processed_status
                        AND creation_date < l_dte_sysdate - p_num_days;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                       'Error happened while archiving RMA Comment Line Data '
                    || SQLERRM);
        END;

        fnd_file.put_line (
            fnd_file.LOG,
            'EBS to HJ integration tables purge program completed');
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexepected error while purging the records' || SQLERRM);
    END archive_stg_data;

    PROCEDURE purge_rma_data (errbuf OUT VARCHAR2, retcode OUT NUMBER, p_num_archive_days IN NUMBER
                              , p_num_purge_days IN NUMBER)
    IS
        l_dte_sysdate   DATE := SYSDATE;
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'EBS to HJ RMA Extract purge program started.');
        errbuf    := NULL;
        retcode   := '0';
        fnd_file.put_line (fnd_file.LOG, 'Parameters.');
        fnd_file.put_line (fnd_file.LOG, '----------------------');
        fnd_file.put_line (
            fnd_file.LOG,
            'Purge Staging table Obselete Data Days:' || p_num_archive_days);
        fnd_file.put_line (
            fnd_file.LOG,
            'Purge log table processed Data Days:' || p_num_purge_days);
        fnd_file.put_line (fnd_file.LOG, '----------------------');
        fnd_file.put_line (
            fnd_file.LOG,
            'Purging ' || p_num_archive_days || ' days old records...');

        IF p_num_archive_days IS NOT NULL
        THEN
            msg (
                   'Calling purge_stg_data procedure - START. Timestamp: '
                || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
            purge_stg_data (p_num_archive_days);
            msg (
                   'Calling purge_stg_data procedure - END. Timestamp: '
                || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
            msg (
                   'Calling archive_stg_data procedure - START. Timestamp: '
                || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
            archive_stg_data (p_num_archive_days);
            msg (
                   'Calling archive_stg_data procedure - END. Timestamp: '
                || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        END IF;

        IF p_num_purge_days IS NOT NULL
        THEN
            msg (
                   'Calling purge_log_data procedure - START. Timestamp: '
                || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
            purge_log_data (p_num_purge_days);
            msg (
                   'Calling purge_log_data procedure - END. Timestamp: '
                || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        END IF;

        fnd_file.put_line (
            fnd_file.LOG,
            'EBS to HJ integration tables purge program completed');
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            retcode   := '1';
            errbuf    := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexepected error while purging the records' || SQLERRM);
    END;
END;
/


--
-- XXD_ONT_HJ_RMA_EXT_IFACE_PKG  (Synonym) 
--
CREATE OR REPLACE SYNONYM SOA_INT.XXD_ONT_HJ_RMA_EXT_IFACE_PKG FOR APPS.XXD_ONT_HJ_RMA_EXT_IFACE_PKG
/


GRANT EXECUTE, DEBUG ON APPS.XXD_ONT_HJ_RMA_EXT_IFACE_PKG TO SOA_INT
/
