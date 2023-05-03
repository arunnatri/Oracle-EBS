--
-- XXD_ONT_MOVE_ORG_WH_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:35 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_MOVE_ORG_WH_PKG"
AS
    /*******************************************************************************************
       File Name : APPS.XXD_ONT_MOVE_ORG_WH_PKG

       Created On   : 09-Mar-2017

       Created By   : Arun N Murthy

       Purpose      : This program will be used to update warehouse on the orders
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 09-Mar-2018  1.0        Arun Murthy            Initial Version
    -- 01-Jul-2019  1.1        Viswanathan Pandian    Updated for Macau project CCR0007979
    -- 14-Feb-2022  1.2        Jayarajan A K          Updated for US Inv Org Move CCR0009841
    ******************************************************************************************/
    gn_request_id          NUMBER := fnd_global.conc_request_id;
    gn_parent_request_id   NUMBER;
    gn_order_src_id        NUMBER := 0;
    gn_user_id             NUMBER := fnd_global.user_id;
    gn_login_id            NUMBER := fnd_global.login_id;
    gc_debug_flag          VARCHAR2 (15) := 'N';
    gc_new_status          VARCHAR2 (3) := 'N';
    gc_error_status        VARCHAR2 (3) := 'E';
    gc_code_pointer        VARCHAR2 (2000);
    gn_org_id              NUMBER := fnd_global.org_id;
    gn_application_id      NUMBER := fnd_global.resp_appl_id;
    gn_responsibility_id   NUMBER := fnd_global.resp_id;
    --Start changes v1.2
    gc_division_flag       VARCHAR2 (1) := 'N';
    gc_deptmnt_flag        VARCHAR2 (1) := 'N';
    gc_class_flag          VARCHAR2 (1) := 'N';
    gc_subclass_flag       VARCHAR2 (1) := 'N';

    --End changes v1.2

    PROCEDURE LOG (pv_debug VARCHAR2, pv_msgtxt_in IN VARCHAR2)
    IS
    BEGIN
        IF pv_debug = 'Y' OR pv_debug = 'Yes'
        THEN
            IF fnd_global.conc_login_id = -1
            THEN
                DBMS_OUTPUT.put_line (pv_msgtxt_in);
            ELSE
                fnd_file.put_line (fnd_file.LOG, pv_msgtxt_in);
            END IF;
        END IF;
    END;

    PROCEDURE xxd_initialize_proc
    AS
    BEGIN
        fnd_global.apps_initialize (user_id        => gn_user_id,
                                    resp_id        => gn_responsibility_id,
                                    resp_appl_id   => gn_application_id);
        mo_global.init ('ONT');
        mo_global.set_policy_context ('S', gn_org_id);
        oe_msg_pub.initialize;
        oe_debug_pub.initialize;
        LOG (
            gc_debug_flag,
               gn_user_id
            || ' - '
            || gn_responsibility_id
            || ' - '
            || gn_application_id
            || ' - '
            || gn_org_id);
    END xxd_initialize_proc;

    PROCEDURE proc_assign_int_source_id
    IS
    BEGIN
        SELECT order_source_id
          INTO gn_order_src_id
          FROM oe_order_sources
         WHERE 1 = 1 AND name = 'Internal';
    EXCEPTION
        WHEN OTHERS
        THEN
            LOG (gc_debug_flag,
                 'Error While getting Order Source ID' || SQLERRM);
    END;

    FUNCTION get_active_lines_count
        RETURN NUMBER
    IS
        ln_lines_count   NUMBER := 0;
    BEGIN
        SELECT COUNT (*)
          INTO ln_lines_count
          FROM xxd_ont_mv_org_lines_stg_t
         WHERE     1 = 1
               AND batch_number IS NULL
               AND record_status = gc_new_status;

        RETURN ln_lines_count;
    EXCEPTION
        WHEN OTHERS
        THEN
            LOG (gc_debug_flag,
                 'Error @get_active_lines_count - ' || SQLERRM);
            RETURN 0;
    END get_active_lines_count;

    FUNCTION get_no_of_process
        RETURN NUMBER
    IS
        ln_lines_count     NUMBER := 0;
        ln_no_of_process   NUMBER := 0;
    BEGIN
        ln_lines_count   := get_active_lines_count;

        SELECT lookup_code
          INTO ln_no_of_process
          FROM fnd_lookup_values_vl
         WHERE     1 = 1
               AND lookup_type = 'XXD_ONT_NUMBER_OF_PROCESSES'
               AND enabled_flag = 'Y'
               AND SYSDATE BETWEEN start_date_active
                               AND NVL (end_date_active, SYSDATE + 1)
               AND ln_lines_count BETWEEN TO_NUMBER (meaning)
                                      AND TO_NUMBER (
                                              NVL (tag, 9999999999999999));

        RETURN ln_no_of_process;
    EXCEPTION
        WHEN OTHERS
        THEN
            LOG (gc_debug_flag,
                 'Error @get_active_lines_count - ' || SQLERRM);
            RETURN 1;
    END;

    PROCEDURE proc_old_update_process (pn_parent_request_id   NUMBER,
                                       p_no_of_process        NUMBER)
    IS
        ln_valid_rec_cnt   NUMBER := 0;
        ln_mod_count       NUMBER := 0;
        ln_batch_number    NUMBER := 0;
        ln_no_of_process   NUMBER := 0;

        TYPE hdr_batch_id_t IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        ln_hdr_batch_id    hdr_batch_id_t;

        TYPE request_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;
    BEGIN
        LOG (
            gc_debug_flag,
            'Calling Procedure which assign a child process for each order ');

        SELECT COUNT (DISTINCT header_id)
          INTO ln_valid_rec_cnt
          FROM xxdo.xxd_ont_mv_org_lines_stg_t
         WHERE batch_number IS NULL AND record_status = gc_new_status;

        FOR i IN 1 .. p_no_of_process
        LOOP
            BEGIN
                SELECT xxd_ont_mv_org_lines_stg_s.NEXTVAL
                  INTO ln_hdr_batch_id (i)
                  FROM DUAL;

                LOG (gc_debug_flag,
                     'ln_hdr_batch_id(i) := ' || ln_hdr_batch_id (i));
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_hdr_batch_id (i + 1)   := ln_hdr_batch_id (i) + 1;
            END;

            LOG (gc_debug_flag, ' ln_valid_rec_cnt := ' || ln_valid_rec_cnt);
            LOG (
                gc_debug_flag,
                   'ceil( ln_valid_rec_cnt/p_no_of_process) := '
                || CEIL (ln_valid_rec_cnt / p_no_of_process));

            UPDATE xxdo.xxd_ont_mv_org_lines_stg_t
               SET batch_number = ln_hdr_batch_id (i), request_id = pn_parent_request_id
             WHERE     batch_number IS NULL
                   AND header_id IN
                           (SELECT header_id
                              FROM (  SELECT DISTINCT header_id
                                        FROM xxdo.xxd_ont_mv_org_lines_stg_t
                                       WHERE 1 = 1 AND batch_number IS NULL
                                    ORDER BY 1)
                             WHERE     1 = 1
                                   AND ROWNUM <=
                                       CEIL (
                                           ln_valid_rec_cnt / p_no_of_process))
                   AND record_status = gc_new_status;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            LOG (gc_debug_flag, 'Error @get_no_of_process - ' || SQLERRM);
    END proc_old_update_process;

    PROCEDURE proc_update_batch (pn_parent_request_id   NUMBER,
                                 pn_no_of_process       NUMBER)
    IS
        ln_lines_count     NUMBER := 0;
        ln_count           NUMBER := 0;
        ln_mod_count       NUMBER := 0;
        ln_batch_number    NUMBER := 0;
        ln_no_of_process   NUMBER := 0;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Call Procedure proc_update_batch.');
        ln_lines_count   := get_active_lines_count;

        IF pn_no_of_process IS NULL
        THEN
            ln_no_of_process   := get_no_of_process;
        ELSE
            ln_no_of_process   := pn_no_of_process;
        END IF;

        ln_mod_count     := CEIL (ln_lines_count / ln_no_of_process);

        FOR i IN 1 .. ln_no_of_process
        LOOP
            BEGIN
                ln_batch_number   := xxd_ont_mv_org_lines_stg_s.NEXTVAL;

                UPDATE xxd_ont_mv_org_lines_stg_t
                   SET batch_number = ln_batch_number, request_id = pn_parent_request_id
                 WHERE     1 = 1
                       AND header_id IN
                               (SELECT header_id
                                  FROM (  SELECT header_id, SUM (COUNT (1)) OVER (ORDER BY COUNT (1), header_id) cntt
                                            FROM xxdo.xxd_ont_mv_org_lines_stg_t
                                           WHERE     1 = 1
                                                 AND batch_number IS NULL
                                                 AND record_status =
                                                     gc_new_status
                                        GROUP BY header_id
                                        ORDER BY 2)
                                 WHERE 1 = 1 AND cntt <= ln_mod_count)
                       AND record_status = gc_new_status
                       AND batch_number IS NULL;

                ln_count          := SQL%ROWCOUNT;
                LOG (
                    gc_debug_flag,
                       'completed updating Batch id in  XXD_ONT_MV_ORG_LINES_STG_T'
                    || ln_count);
            EXCEPTION
                WHEN OTHERS
                THEN
                    LOG (
                        gc_debug_flag,
                           'Error @get_no_of_process-Update portion - '
                        || SQLERRM);
            END;
        END LOOP;

        COMMIT;
        ln_count         := 0;

        BEGIN
            SELECT COUNT (DISTINCT header_id)
              INTO ln_count
              FROM xxd_ont_mv_org_lines_stg_t
             WHERE     1 = 1
                   AND batch_number IS NULL
                   AND record_status = gc_new_status;
        END;

        IF ln_count > 0
        THEN
            proc_old_update_process (pn_parent_request_id, ln_count);
        END IF;

        LOG (gc_debug_flag,
             'completed updating Batch id in  XXD_ONT_MV_ORG_LINES_STG_T');
    EXCEPTION
        WHEN OTHERS
        THEN
            LOG (gc_debug_flag, 'Error @get_no_of_process - ' || SQLERRM);
    END;

    PROCEDURE proc_extract_data (pv_as_of_date IN VARCHAR2, pn_from_shp_frm_org_id IN NUMBER, pv_schdl_status IN VARCHAR2
                                 , pn_from_ord_no IN NUMBER, pv_brand IN VARCHAR2, pn_org_id IN NUMBER)
    IS
    BEGIN
        proc_assign_int_source_id;
        LOG (
            gc_debug_flag,
               'Start Insert at '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

        INSERT INTO xxdo.xxd_ont_mv_org_lines_stg_t (request_id, order_number, header_id, org_id, cust_po_number, creation_date, record_status, last_updated_by, last_update_date, line_number, ordered_item, inventory_item_id, ordered_quantity, request_date, schedule_ship_date, latest_acceptable_date, cancel_date, demand_class_code
                                                     , ship_from, line_id)
              SELECT gn_request_id, h.order_number, h.header_id,
                     h.org_id, h.cust_po_number, SYSDATE,
                     'N', gn_user_id, SYSDATE,
                     l.line_number || '.' || l.shipment_number, l.ordered_item, l.inventory_item_id,
                     l.ordered_quantity, l.request_date, l.schedule_ship_date,
                     l.latest_acceptable_date, l.attribute1 cancel_date, l.demand_class_code,
                     l.ship_from_org_id, l.line_id
                FROM apps.oe_order_headers_all h, apps.oe_order_lines_all l, --Start changes v1.2
                                                                             mtl_item_categories mic,
                     mtl_categories_b mcb
               --End changes v1.2
               WHERE     h.header_id = l.header_id
                     AND h.open_flag = 'Y'
                     AND l.open_flag = 'Y'
                     AND h.attribute5 = NVL (pv_brand, h.attribute5)
                     AND h.org_id = NVL (pn_org_id, h.org_id)
                     AND h.order_source_id != gn_order_src_id
                     AND l.ship_from_org_id = pn_from_shp_frm_org_id
                     AND ((pn_from_ord_no IS NOT NULL AND h.order_number = pn_from_ord_no) OR (pn_from_ord_no IS NULL AND 1 = 1))
                     AND ((pv_schdl_status = 'SCHEDULE' AND l.schedule_ship_date IS NOT NULL) OR (pv_schdl_status = 'UNSCHEDULE' AND l.schedule_ship_date IS NULL))
                     AND TRUNC (l.request_date) >=
                         TO_DATE (pv_as_of_date, 'YYYY/MM/DD HH24:mi:ss')
                     AND NOT EXISTS
                             (SELECT 1
                                FROM mtl_reservations
                               WHERE     organization_id = l.ship_from_org_id
                                     AND demand_source_line_id = l.line_id)
                     -- Start changes for V1.1 for CCR0007979
                     AND EXISTS
                             (SELECT 1
                                FROM fnd_lookup_values flv
                               WHERE     flv.enabled_flag = 'Y'
                                     AND flv.language = USERENV ('LANG')
                                     AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                     NVL (
                                                                         flv.start_date_active,
                                                                         SYSDATE))
                                                             AND TRUNC (
                                                                     NVL (
                                                                         flv.end_date_active,
                                                                         SYSDATE))
                                     AND TO_NUMBER (flv.lookup_code) =
                                         h.order_type_id
                                     AND flv.lookup_type =
                                         'XXD_ONT_MOVE_ORG_WH_ORDER_TYPE')
                     -- End changes for V1.1 for CCR0007979
                     --Start changes v1.2
                     AND l.inventory_item_id = mic.inventory_item_id
                     AND l.ship_from_org_id = mic.organization_id
                     AND mic.category_set_id = 1
                     AND mic.category_id = mcb.category_id
                     AND (   (    gc_division_flag = 'Y'
                              AND EXISTS
                                      (SELECT 1
                                         FROM fnd_lookup_values flv
                                        WHERE     flv.enabled_flag = 'Y'
                                              AND flv.language =
                                                  USERENV ('LANG')
                                              AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                              NVL (
                                                                                  flv.start_date_active,
                                                                                  SYSDATE))
                                                                      AND TRUNC (
                                                                              NVL (
                                                                                  flv.end_date_active,
                                                                                  SYSDATE))
                                              AND flv.lookup_type =
                                                  'XXD_ONT_MOVE_ORG_WH_DIVISION'
                                              AND flv.lookup_code =
                                                  mcb.segment2))
                          OR (gc_division_flag = 'N'))
                     AND (   (    gc_deptmnt_flag = 'Y'
                              AND EXISTS
                                      (SELECT 1
                                         FROM fnd_lookup_values flv
                                        WHERE     flv.enabled_flag = 'Y'
                                              AND flv.language =
                                                  USERENV ('LANG')
                                              AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                              NVL (
                                                                                  flv.start_date_active,
                                                                                  SYSDATE))
                                                                      AND TRUNC (
                                                                              NVL (
                                                                                  flv.end_date_active,
                                                                                  SYSDATE))
                                              AND flv.lookup_type =
                                                  'XXD_ONT_MOVE_ORG_WH_DEPARTMENT'
                                              AND flv.lookup_code =
                                                  mcb.segment3))
                          OR (gc_deptmnt_flag = 'N'))
                     AND (   (    gc_class_flag = 'Y'
                              AND EXISTS
                                      (SELECT 1
                                         FROM fnd_lookup_values flv
                                        WHERE     flv.enabled_flag = 'Y'
                                              AND flv.language =
                                                  USERENV ('LANG')
                                              AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                              NVL (
                                                                                  flv.start_date_active,
                                                                                  SYSDATE))
                                                                      AND TRUNC (
                                                                              NVL (
                                                                                  flv.end_date_active,
                                                                                  SYSDATE))
                                              AND flv.lookup_type =
                                                  'XXD_ONT_MOVE_ORG_WH_CLASS'
                                              AND flv.lookup_code =
                                                  mcb.segment4))
                          OR (gc_class_flag = 'N'))
                     AND (   (    gc_subclass_flag = 'Y'
                              AND EXISTS
                                      (SELECT 1
                                         FROM fnd_lookup_values flv
                                        WHERE     flv.enabled_flag = 'Y'
                                              AND flv.language =
                                                  USERENV ('LANG')
                                              AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                              NVL (
                                                                                  flv.start_date_active,
                                                                                  SYSDATE))
                                                                      AND TRUNC (
                                                                              NVL (
                                                                                  flv.end_date_active,
                                                                                  SYSDATE))
                                              AND flv.lookup_type =
                                                  'XXD_ONT_MOVE_ORG_WH_SUBCLASS'
                                              AND flv.lookup_code =
                                                  mcb.segment5))
                          OR (gc_subclass_flag = 'N'))
                     --End changes v1.2
                     AND NOT EXISTS
                             (SELECT 1
                                FROM fnd_lookup_values flv
                               WHERE     1 = 1
                                     AND lookup_type = 'XXD_PROMO_MODIFIER'
                                     AND description = 'FLOW_STATUS_CODE'
                                     --Start changes v1.2
                                     /*AND oe_line_status_pub.get_line_status (
                                           l.line_id,
                                           l.flow_status_code) =
                                         flv.meaning*/
                                     AND flv.lookup_code = l.flow_status_code
                                     --End changes v1.2
                                     AND flv.enabled_flag = 'Y'
                                     AND flv.language = USERENV ('LANG')
                                     AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                     NVL (
                                                                         flv.start_date_active,
                                                                         SYSDATE))
                                                             AND TRUNC (
                                                                     NVL (
                                                                         flv.end_date_active,
                                                                         SYSDATE)))
            ORDER BY h.order_number, l.line_id;

        LOG (
            gc_debug_flag,
               'End Insert at '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            LOG (gc_debug_flag, 'Error @proc_extract_data - ' || SQLERRM);
    END;

    PROCEDURE proc_update_records (pn_header_id NUMBER, pn_batch_number NUMBER, pv_status VARCHAR2
                                   , pv_error_message VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        UPDATE xxdo.xxd_ont_mv_org_lines_stg_t
           SET record_status = pv_status, error_message = pv_error_message
         WHERE     1 = 1
               AND header_id = pn_header_id
               AND batch_number = pn_batch_number;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            LOG (gc_debug_flag,
                 'Error @proc_update_error_records - ' || SQLERRM);
    END;

    PROCEDURE proc_call_child_prgm (pn_parent_request_id       NUMBER,
                                    pn_to_shp_frm_org_id       NUMBER,
                                    pv_schdl_status            VARCHAR2,
                                    x_retcode              OUT VARCHAR2,
                                    x_errbuf               OUT VARCHAR2)
    IS
        ln_cntr             NUMBER := 0;
        ln_request_id       NUMBER;

        l_phase             VARCHAR2 (30);
        l_status            VARCHAR2 (30);
        l_dev_phase         VARCHAR2 (30);
        l_dev_status        VARCHAR2 (30);
        l_message           VARCHAR2 (1000);
        l_instance          VARCHAR2 (1000);
        l_batch_nos         VARCHAR2 (1000);
        l_sub_requests      fnd_concurrent.requests_tab_type;
        l_errored_rec_cnt   NUMBER;
        lc_phase            VARCHAR2 (200);
        lc_status           VARCHAR2 (200);
        lc_dev_phase        VARCHAR2 (200);
        lc_dev_status       VARCHAR2 (200);
        lc_message          VARCHAR2 (200);
        ln_ret_code         NUMBER;
        lc_err_buff         VARCHAR2 (1000);
        lb_wait             BOOLEAN;

        CURSOR cur_sel IS
            SELECT DISTINCT batch_number
              FROM xxdo.xxd_ont_mv_org_lines_stg_t
             WHERE     1 = 1
                   AND record_status = gc_new_status
                   AND request_id = pn_parent_request_id;

        TYPE request_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_req_id            request_table;
    BEGIN
        FOR rec_sel IN cur_sel
        LOOP
            BEGIN
                LOG (
                    gc_debug_flag,
                    'Calling Worker process for batch id  := ' || rec_sel.batch_number);
                ln_request_id   :=
                    apps.fnd_request.submit_request (
                        'XXDO',
                        'XXD_ONT_MV_ORG_CHILD_CP',
                        '',
                        '',
                        FALSE,
                        gc_debug_flag,
                        rec_sel.batch_number,
                        pn_to_shp_frm_org_id,
                        pv_schdl_status);
                LOG (gc_debug_flag, 'v_request_id := ' || ln_request_id);

                IF ln_request_id > 0
                THEN
                    l_req_id (rec_sel.batch_number)   := ln_request_id;
                    COMMIT;
                ELSE
                    ROLLBACK;
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    x_retcode   := 2;
                    x_errbuf    := x_errbuf || SQLERRM;
                    LOG (
                        gc_debug_flag,
                           'Calling WAIT FOR REQUEST XXD_AR_OPNINV_CHILD_CONV error'
                        || SQLERRM);
                WHEN OTHERS
                THEN
                    x_retcode   := 2;
                    x_errbuf    := x_errbuf || SQLERRM;
                    LOG (
                        gc_debug_flag,
                           'Calling WAIT FOR REQUEST XXD_AR_OPNINV_CHILD_CONV error'
                        || SQLERRM);
            END;
        END LOOP;

        LOG (gc_debug_flag, 'Calling XXD_AR_OPNINV_CHILD_CONV in batch ');
        LOG (gc_debug_flag,
             'Calling WAIT FOR REQUEST XXD_AR_OPNINV_CHILD_CONV to complete');

        FOR rec IN l_req_id.FIRST .. l_req_id.LAST
        LOOP
            IF l_req_id (rec) > 0
            THEN
                LOOP
                    lc_dev_phase    := NULL;
                    lc_dev_status   := NULL;
                    lb_wait         :=
                        fnd_concurrent.wait_for_request (
                            request_id   => l_req_id (rec) --ln_concurrent_request_id
                                                          ,
                            interval     => 1,
                            max_wait     => 1,
                            phase        => lc_phase,
                            status       => lc_status,
                            dev_phase    => lc_dev_phase,
                            dev_status   => lc_dev_status,
                            MESSAGE      => lc_message);

                    IF ((UPPER (lc_dev_phase) = 'COMPLETE') OR (UPPER (lc_phase) = 'COMPLETED'))
                    THEN
                        EXIT;
                    END IF;
                END LOOP;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            LOG (gc_debug_flag, 'Error @calling child program - ' || SQLERRM);
    END;

    PROCEDURE proc_process_order (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, pv_debug VARCHAR2
                                  , pn_hdr_batch_id NUMBER, pn_to_shp_frm_org_id IN NUMBER, pv_schdl_status IN VARCHAR2)
    IS
        v_api_version_number           NUMBER := 1;
        v_return_status                VARCHAR2 (2000);
        v_msg_count                    NUMBER;
        v_msg_data                     VARCHAR2 (2000);

        -- IN Variables --
        v_header_rec                   oe_order_pub.header_rec_type;
        test_line                      oe_order_pub.line_rec_type;
        v_line_tbl                     oe_order_pub.line_tbl_type;
        v_action_request_tbl           oe_order_pub.request_tbl_type;
        v_line_adj_tbl                 oe_order_pub.line_adj_tbl_type;

        -- OUT Variables --
        v_header_rec_out               oe_order_pub.header_rec_type;
        v_header_val_rec_out           oe_order_pub.header_val_rec_type;
        v_header_adj_tbl_out           oe_order_pub.header_adj_tbl_type;
        v_header_adj_val_tbl_out       oe_order_pub.header_adj_val_tbl_type;
        v_header_price_att_tbl_out     oe_order_pub.header_price_att_tbl_type;
        v_header_adj_att_tbl_out       oe_order_pub.header_adj_att_tbl_type;
        v_header_adj_assoc_tbl_out     oe_order_pub.header_adj_assoc_tbl_type;
        v_header_scredit_tbl_out       oe_order_pub.header_scredit_tbl_type;
        v_header_scredit_val_tbl_out   oe_order_pub.header_scredit_val_tbl_type;
        v_line_tbl_out                 oe_order_pub.line_tbl_type;
        v_line_val_tbl_out             oe_order_pub.line_val_tbl_type;
        v_line_adj_tbl_out             oe_order_pub.line_adj_tbl_type;
        v_line_adj_val_tbl_out         oe_order_pub.line_adj_val_tbl_type;
        v_line_price_att_tbl_out       oe_order_pub.line_price_att_tbl_type;
        v_line_adj_att_tbl_out         oe_order_pub.line_adj_att_tbl_type;
        v_line_adj_assoc_tbl_out       oe_order_pub.line_adj_assoc_tbl_type;
        v_line_scredit_tbl_out         oe_order_pub.line_scredit_tbl_type;
        v_line_scredit_val_tbl_out     oe_order_pub.line_scredit_val_tbl_type;
        v_lot_serial_tbl_out           oe_order_pub.lot_serial_tbl_type;
        v_lot_serial_val_tbl_out       oe_order_pub.lot_serial_val_tbl_type;
        v_action_request_tbl_out       oe_order_pub.request_tbl_type;

        v_msg_index                    NUMBER;
        v_data                         VARCHAR2 (2000);
        v_loop_count                   NUMBER;
        v_debug_file                   VARCHAR2 (200);
        b_return_status                VARCHAR2 (200);
        b_msg_count                    NUMBER;
        b_msg_data                     VARCHAR2 (2000);
        i                              NUMBER := 0;
        j                              NUMBER := 0;
        lx_retcode                     NUMBER := 0;
        lx_errbuf                      VARCHAR2 (32767);

        CURSOR header_cur IS
            SELECT DISTINCT order_number onum, header_id order_id, org_id,
                            batch_number
              FROM xxdo.xxd_ont_mv_org_lines_stg_t stg
             WHERE     1 = 1
                   AND NVL (batch_number, 0) = pn_hdr_batch_id
                   AND record_status = gc_new_status;

        CURSOR line_cur (pn_header_id NUMBER)
        IS
            SELECT DISTINCT stg.line_id
              FROM xxdo.xxd_ont_mv_org_lines_stg_t stg
             WHERE     1 = 1
                   AND stg.header_id = pn_header_id
                   AND NVL (batch_number, 0) = pn_hdr_batch_id
                   AND record_status = gc_new_status;
    BEGIN
        DBMS_OUTPUT.put_line ('Start OF THE PROGRAM');

        ROLLBACK;
        xxd_initialize_proc;

        FOR header_rec IN header_cur
        LOOP
            i                               := i + 1;
            j                               := 0;
            oe_msg_pub.initialize;
            oe_debug_pub.initialize;
            mo_global.init ('ONT');
            mo_global.set_org_context (header_rec.org_id, NULL, 'ONT');
            LOG (gc_debug_flag, 'Order id' || header_rec.order_id);

            v_header_rec                    := oe_order_pub.g_miss_header_rec;
            v_header_rec.operation          := oe_globals.g_opr_update;
            v_header_rec.header_id          := header_rec.order_id;
            -- Start changes for V1.1 for CCR0007979
            v_header_rec.ship_from_org_id   := pn_to_shp_frm_org_id;
            -- End changes for V1.1 for CCR0007979
            v_action_request_tbl (i)        :=
                oe_order_pub.g_miss_request_rec;
            v_line_tbl.delete ();

            FOR line_rec IN line_cur (header_rec.order_id)
            LOOP
                j                                     := j + 1;

                v_line_tbl (j)                        := oe_order_pub.g_miss_line_rec;
                v_line_tbl (j).header_id              := header_rec.order_id;
                v_line_tbl (j).line_id                := line_rec.line_id;
                v_line_tbl (j).operation              := oe_globals.g_opr_update;
                v_line_tbl (j).ship_from_org_id       := pn_to_shp_frm_org_id;
                v_line_tbl (j).schedule_action_code   := pv_schdl_status;
            END LOOP;

            oe_order_pub.process_order (
                p_api_version_number       => v_api_version_number,
                p_header_rec               => v_header_rec,
                p_line_tbl                 => v_line_tbl,
                p_action_request_tbl       => v_action_request_tbl,
                p_line_adj_tbl             => v_line_adj_tbl,
                x_header_rec               => v_header_rec_out,
                x_header_val_rec           => v_header_val_rec_out,
                x_header_adj_tbl           => v_header_adj_tbl_out,
                x_header_adj_val_tbl       => v_header_adj_val_tbl_out,
                x_header_price_att_tbl     => v_header_price_att_tbl_out,
                x_header_adj_att_tbl       => v_header_adj_att_tbl_out,
                x_header_adj_assoc_tbl     => v_header_adj_assoc_tbl_out,
                x_header_scredit_tbl       => v_header_scredit_tbl_out,
                x_header_scredit_val_tbl   => v_header_scredit_val_tbl_out,
                x_line_tbl                 => v_line_tbl_out,
                x_line_val_tbl             => v_line_val_tbl_out,
                x_line_adj_tbl             => v_line_adj_tbl_out,
                x_line_adj_val_tbl         => v_line_adj_val_tbl_out,
                x_line_price_att_tbl       => v_line_price_att_tbl_out,
                x_line_adj_att_tbl         => v_line_adj_att_tbl_out,
                x_line_adj_assoc_tbl       => v_line_adj_assoc_tbl_out,
                x_line_scredit_tbl         => v_line_scredit_tbl_out,
                x_line_scredit_val_tbl     => v_line_scredit_val_tbl_out,
                x_lot_serial_tbl           => v_lot_serial_tbl_out,
                x_lot_serial_val_tbl       => v_lot_serial_val_tbl_out,
                x_action_request_tbl       => v_action_request_tbl_out,
                x_return_status            => v_return_status,
                x_msg_count                => v_msg_count,
                x_msg_data                 => v_msg_data);

            IF v_return_status = fnd_api.g_ret_sts_success
            THEN
                COMMIT;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Update Success for order header id : '
                    || v_header_rec_out.header_id
                    || ' '
                    || 'of order number:'
                    || header_rec.onum);
                proc_update_records (header_rec.order_id, header_rec.batch_number, 'P'
                                     , NULL);
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Update Failed for order header id : '
                    || v_header_rec_out.header_id
                    || ' '
                    || 'of order number:'
                    || header_rec.onum);
                --Start changes v1.2
                fnd_file.put_line (fnd_file.LOG,
                                   'v_msg_count: ' || v_msg_count);
                --fnd_file.put_line (fnd_file.LOG, 'Reason is:' || v_msg_data);
                --End changes v1.2

                ROLLBACK;

                FOR i IN 1 .. v_msg_count
                LOOP
                    v_msg_data   :=
                        SUBSTR (
                            v_msg_data || '; ' || oe_msg_pub.get (p_msg_index => i, p_encoded => 'F'),
                            1,
                            2000);                                      --v1.2
                    fnd_file.put_line (
                        fnd_file.LOG,
                        i || ') ' || oe_msg_pub.get (p_msg_index => i, p_encoded => 'F')); --v.12
                END LOOP;

                proc_update_records (header_rec.order_id, header_rec.batch_number, 'E'
                                     , v_msg_data);

                lx_errbuf    :=
                    SUBSTR (
                           lx_errbuf
                        || CHR (10)
                        || ' Header_id '
                        || header_rec.order_id
                        || ' - '
                        || v_msg_data,
                        1,
                        32767);
                lx_retcode   := lx_retcode + 1;
            --fnd_file.put_line (fnd_file.LOG, 'v_msg_data  : ' || v_msg_data); --v1.2
            END IF;
        END LOOP;

        IF lx_retcode > 0
        THEN
            --Start changes v1.2
            --x_errbuf := lx_errbuf;
            x_errbuf    :=
                'One or more orders failed to update. Please check log for more details';
            --End changes v1.2
            x_retcode   := 2;
        ELSE
            x_retcode   := 0;
            x_errbuf    := 'Program Completed successfully';
        END IF;

        fnd_file.put_line (fnd_file.LOG, 'END OF THE PROGRAM');
    EXCEPTION
        WHEN OTHERS
        THEN
            x_errbuf    :=
                   'Program errored out @proc_process_order WHEN OTHERS EXCEPTION'
                || SQLERRM;
            x_retcode   := 2;
    END proc_process_order;

    PROCEDURE load_main (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, pv_brand IN VARCHAR2, pn_org_id IN NUMBER, pv_as_of_date IN VARCHAR2, pn_from_shp_frm_org_id IN NUMBER, pn_to_shp_frm_org_id IN NUMBER, pv_schdl_status IN VARCHAR2, pn_from_ord_no IN NUMBER, p_no_of_process IN NUMBER, pv_reprocess IN VARCHAR2, p_debug_flag IN VARCHAR2, p_division_flag IN VARCHAR2, --Start changes v1.2
                                                                                                                                                                                                                                                                                                                                                                                               p_deptmnt_flag IN VARCHAR2, p_class_flag IN VARCHAR2
                         , p_subclass_flag IN VARCHAR2)     --End changes v1.2
    IS
        l_err_msg                VARCHAR2 (4000);
        l_err_code               NUMBER;
        l_interface_rec_cnt      NUMBER;
        l_request_id             NUMBER;
        l_succ_interfc_rec_cnt   NUMBER := 0;
        l_warning_cnt            NUMBER := 0;
        l_error_cnt              NUMBER := 0;
        l_return                 BOOLEAN;
        l_low_batch_limit        NUMBER;
        l_high_batch_limit       NUMBER;
        l_phase                  VARCHAR2 (30);
        l_status                 VARCHAR2 (30);
        l_dev_phase              VARCHAR2 (30);
        l_dev_status             VARCHAR2 (30);
        l_message                VARCHAR2 (1000);
        l_instance               VARCHAR2 (1000);
        l_batch_nos              VARCHAR2 (1000);
        l_sub_requests           fnd_concurrent.requests_tab_type;
        l_errored_rec_cnt        NUMBER;
        l_validated_rec_cnt      NUMBER;
        v_request_id             NUMBER;
        g_debug                  VARCHAR2 (10);
        g_process_level          VARCHAR2 (50);
        l_count                  NUMBER;
        ln_org_id                NUMBER;
        ln_parent_request_id     NUMBER := fnd_global.conc_request_id;
        ln_valid_rec_cnt         NUMBER;
        ln_request_id            NUMBER := 0;
        lc_phase                 VARCHAR2 (200);
        lc_status                VARCHAR2 (200);
        lc_dev_phase             VARCHAR2 (200);
        lc_dev_status            VARCHAR2 (200);
        lc_message               VARCHAR2 (200);
        ln_ret_code              NUMBER;
        lc_err_buff              VARCHAR2 (1000);
        ln_count                 NUMBER;
        ln_cntr                  NUMBER := 0;
        lb_wait                  BOOLEAN;
        lx_return_mesg           VARCHAR2 (2000);

        TYPE hdr_batch_id_t IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        ln_hdr_batch_id          hdr_batch_id_t;

        TYPE request_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_req_id                 request_table;
    BEGIN
        gc_debug_flag      := NVL (p_debug_flag, 'N');
        --Start changes v1.2
        gc_division_flag   := NVL (p_division_flag, 'N');
        gc_deptmnt_flag    := NVL (p_deptmnt_flag, 'N');
        gc_class_flag      := NVL (p_class_flag, 'N');
        gc_subclass_flag   := NVL (p_subclass_flag, 'N');
        --End changes v1.2
        proc_extract_data (pv_as_of_date, pn_from_shp_frm_org_id, pv_schdl_status
                           , pn_from_ord_no, pv_brand, pn_org_id);

        proc_update_batch (ln_parent_request_id, p_no_of_process);

        proc_call_child_prgm (ln_parent_request_id, pn_to_shp_frm_org_id, pv_schdl_status
                              , x_retcode, x_errbuf);
        x_retcode          := 0;
        x_errbuf           := NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            gc_code_pointer   := 'Caught Exception' || SQLERRM;
            fnd_file.put_line (fnd_file.LOG, gc_code_pointer);
            x_retcode         := 2;
            x_errbuf          := 'Error @load_main program';
    END load_main;
END xxd_ont_move_org_wh_pkg;
/
