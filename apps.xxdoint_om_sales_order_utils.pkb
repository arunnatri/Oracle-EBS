--
-- XXDOINT_OM_SALES_ORDER_UTILS  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:39 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOINT_OM_SALES_ORDER_UTILS"
AS
    /****************************************************************************
     * PACKAGE Name    : XXDOINT_OM_SALES_ORDER_UTILS
     *
     * Description       : The purpose of this package to capture the CDC
     *                     for Order and raise business for SOA.
     *
     * INPUT Parameters  :
     *
     * OUTPUT Parameters :
     *
     * DEVELOPMENT and MAINTENANCE HISTORY
     *
     * ======================================================================================
     * Date         Version#   Name                    Comments
     * ======================================================================================
    * 04-Apr-2016  1.0                                Initial Version
    * 13-Dec-2017  1.1        INFOSYS                 Return Invoice number is not updated in Hubsoft CCR0006454
    * 05-Jun-2019  1.2        Viswanathan Pandian     Updated for CCR0008050
    * 10-Oct-2020  1.3        Aravind Kannuri         Updated for CCR0008801
    * 23-Nov-2020  1.4        Aravind Kannuri         Updated for CCR0009028
    * 23-Dec-2020  1.5        Shivanshu Talwar        Updated for CCR0009053
    * 10-Jan-2021  1.6        Shivanshu Talwar        Updated for CCR0009093
    * 31-Mar-2021  1.7        Aravind Kannuri         Updated for CCR0009133
    * 16-Sep-2021  2.0        Shivanshu Talwar        Updated for CCR0009596
 * 11-Jul-2022  2.0        Shivanshu Talwar        Updated for CCR0010054
     ******************************************************************************************/
    g_pkg_name                  CONSTANT VARCHAR2 (40) := 'XXDOINT_OM_SALES_ORDER_UTILS';
    g_cdc_substription_name     CONSTANT VARCHAR2 (40)
                                             := 'XXDOINT_OM_SALESORDER_SUB' ;
    g_so_update_event           CONSTANT VARCHAR2 (40)
        := 'oracle.apps.xxdo.sales_order_update' ;
    g_so_ecomm_event            CONSTANT VARCHAR2 (45)
        := 'oracle.apps.xxdo.ecomm_sales_order_update' ;
    g_so_max_batch_rows         CONSTANT NUMBER := 250;
    g_so_batch_throttle         CONSTANT NUMBER := 60;
    g_so_batch_split_throttle   CONSTANT NUMBER := 3;
    gn_conc_request_id                   NUMBER
        := apps.fnd_global.conc_request_id;
    l_rundate                            DATE := NULL;
    ld_rundate                           DATE := NULL;
    ld_rundate2                          DATE := NULL;
    ld_rundate1                          VARCHAR2 (50);


    PROCEDURE msg (p_message IN VARCHAR2, p_debug_level IN NUMBER:= 10000)
    IS
    BEGIN
        apps.do_debug_tools.msg (p_msg           => p_message,
                                 p_debug_level   => p_debug_level);
        fnd_file.put_line (fnd_file.LOG, p_message);   -- Added for CCR0009596
    END;

    FUNCTION in_conc_request
        RETURN BOOLEAN
    IS
    BEGIN
        RETURN apps.fnd_global.conc_request_id != -1;
    END;


    FUNCTION Get_Last_Conc_Req_Run (pn_request_id IN NUMBER)
        RETURN DATE
    IS
        ld_last_start_date         DATE;
        ln_concurrent_program_id   NUMBER;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Get Last Conc Req Ren - Start');
        fnd_file.put_line (fnd_file.LOG, 'REQUEST ID:  ' || pn_request_id);

        --Get the Concurrent program for the current running request
        BEGIN
            SELECT concurrent_program_id
              INTO ln_concurrent_program_id
              FROM fnd_concurrent_requests
             WHERE request_id = pn_request_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            --No occurnace running just return NULL
            THEN
                fnd_file.put_line (fnd_file.LOG, 'No program found');
                RETURN NULL;
        END;

        fnd_file.put_line (fnd_file.LOG, 'CC REQ ID : ' || pn_request_id);

        BEGIN
            --Find the last occurance of this request
            SELECT NVL (MAX (actual_start_date), SYSDATE - 1)
              INTO ld_last_start_date
              FROM fnd_concurrent_requests
             WHERE     concurrent_program_id = ln_concurrent_program_id
                   AND STATUS_CODE = 'C' --Only count completed tasks to not limit data to any erroring out.
                   AND ARGUMENT1 = 'Y'
                   AND ARGUMENT2 IS NULL
                   AND ARGUMENT3 IS NULL
                   AND ARGUMENT4 IS NULL
                   AND ARGUMENT5 IS NULL
                   AND request_id != gn_conc_request_id; --Don't include the current active request
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                fnd_file.put_line (fnd_file.LOG, 'No prior occurance found');
                ld_last_start_date   :=
                    TRUNC (TO_DATE (SYSDATE - 1, 'YYYY/MM/DD HH24:MI:SS'));
        END;

        RETURN ld_last_start_date;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    PROCEDURE archive_batch (p_batch_id IN NUMBER, p_process_id IN NUMBER:= NULL, x_ret_stat OUT VARCHAR2
                             , x_error_messages OUT VARCHAR2)
    IS
        l_proc_name   VARCHAR2 (80) := g_pkg_name || '.purge_batch';
    BEGIN
        --   msg ('+' || l_proc_name); --commented as part of CCR0010054
        --   msg ('p_batch_id=' || p_batch_id); --commented as part of CCR0010054

        BEGIN
            SAVEPOINT before_so_archive;

            IF p_batch_id IS NULL
            THEN
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := 'A batch identifier was not specified.';
            ELSE
                --  msg (' ready to archive batch records.'); --commented as part of CCR0010054

                INSERT INTO xxdo.xxdoint_om_salesord_nc_arch (batch_id, header_id, batch_date
                                                              , proc_id)
                    SELECT batch_id, header_id, batch_date,
                           p_process_id
                      FROM xxdo.xxdoint_om_salesord_upd_batch
                     WHERE batch_id = p_batch_id;

                --    UPDATE xxdo.xxdoint_om_salesord_nc_arch set proc_id = p_process_id where batch_id = p_batch_id;

                --   msg ( ' archived ' || SQL%ROWCOUNT || ' record(s) from the sales order header batch table.'); --commented as part of CCR0010054
                x_ret_stat         := apps.fnd_api.g_ret_sts_success;
                x_error_messages   := NULL;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK TO before_so_archive;
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := SQLERRM;
                msg ('  EXCEPTION: ' || SQLERRM);
        END;

        msg ('-' || l_proc_name);
    END;

    PROCEDURE purge_batch (p_batch_id         IN     NUMBER,
                           x_ret_stat            OUT VARCHAR2,
                           x_error_messages      OUT VARCHAR2)
    IS
        l_proc_name   VARCHAR2 (80) := g_pkg_name || '.purge_batch';
    BEGIN
        --  msg ('+' || l_proc_name);  --commented as part of CCR0010054
        -- msg ('p_batch_id=' || p_batch_id); --commented as part of CCR0010054

        BEGIN
            SAVEPOINT before_so_purge;

            IF p_batch_id IS NULL
            THEN
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := 'A batch identifier was not specified.';
            ELSE
                --msg (' ready to delete batch records.');  --commented as part of CCR0010054

                BEGIN                                       --w.r.t CCR0006454
                    INSERT INTO xxdo.xxd_om_salesord_upd_bat_hist
                        (SELECT *
                           FROM xxdo.xxdoint_om_salesord_upd_batch
                          WHERE batch_id = p_batch_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;

                DELETE FROM xxdo.xxdoint_om_salesord_upd_batch
                      WHERE batch_id = p_batch_id;

                -- Start changes for V1.2 for CCR0008050
                /*BEGIN                                       --w.r.t CCR0006454
                    DELETE FROM xxdo.xxd_om_salesord_upd_bat_hist
                          WHERE batch_date <
                                  SYSDATE
                                - NVL (
                                      fnd_profile.VALUE (
                                          'XXD_CUST_BATCH_PURG_DAYS'),
                                      10);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;*/
                -- End changes for V1.2 for CCR0008050

                -- Start changes for CCR0009596


                x_ret_stat         := apps.fnd_api.g_ret_sts_success;
                x_error_messages   := NULL;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK TO before_so_purge;
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := SQLERRM;
                msg ('  EXCEPTION: ' || SQLERRM);
        END;
    --  msg ('-' || l_proc_name); --commented as part of CCR0010054
    END;

    PROCEDURE remove_batch (p_batch_id IN NUMBER, p_process_id IN NUMBER, x_ret_stat OUT VARCHAR2
                            , x_error_messages OUT VARCHAR2)
    IS
        l_proc_name      VARCHAR2 (80) := g_pkg_name || '.remove_batch';
        failed_archive   EXCEPTION;
        failed_purge     EXCEPTION;
    BEGIN
        --  msg ('+' || l_proc_name);  --commented as part of CCR0010054
        -- msg ('p_batch_id=' || p_batch_id);  --commented as part of CCR0010054

        BEGIN
            SAVEPOINT before_so_remove;

            IF p_batch_id IS NULL
            THEN
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := 'A batch identifier was not specified.';
            ELSE
                -- msg (' calling archive'); --commented as part of CCR0010054
                archive_batch (p_batch_id => p_batch_id, p_process_id => p_process_id, x_ret_stat => x_ret_stat
                               , x_error_messages => x_error_messages);

                IF NVL (x_ret_stat, apps.fnd_api.g_ret_sts_error) !=
                   apps.fnd_api.g_ret_sts_success
                THEN
                    RAISE failed_archive;
                END IF;

                purge_batch (p_batch_id         => p_batch_id,
                             x_ret_stat         => x_ret_stat,
                             x_error_messages   => x_error_messages);

                IF NVL (x_ret_stat, apps.fnd_api.g_ret_sts_error) !=
                   apps.fnd_api.g_ret_sts_success
                THEN
                    RAISE failed_purge;
                END IF;

                x_ret_stat         := apps.fnd_api.g_ret_sts_success;
                x_error_messages   := NULL;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK TO before_so_remove;
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := SQLERRM;
        --msg ('  EXCEPTION: ' || SQLERRM); --commented as part of CCR0010054
        END;

        msg ('-' || l_proc_name);
    END;

    PROCEDURE purge_old_batches (p_hours_old IN NUMBER, x_ret_stat OUT VARCHAR2, x_error_messages OUT VARCHAR2)
    IS
        l_proc_name   VARCHAR2 (80) := g_pkg_name || '.purge_old_batches';
    BEGIN
        msg ('+' || l_proc_name);
        msg ('p_hours_old=' || p_hours_old);

        BEGIN
            SAVEPOINT before_so_purge;

            IF p_hours_old IS NULL
            THEN
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := 'A time threshhold was not specified.';
            ELSE
                msg (' ready to delete batch records.');

                DELETE FROM xxdo.xxdoint_om_salesord_upd_batch
                      WHERE batch_date < SYSDATE - (p_hours_old / 24);

                --msg (' deleted ' || SQL%ROWCOUNT || ' record(s) from the sales order header batch table.'); --commented as part of CCR0010054
                x_ret_stat         := apps.fnd_api.g_ret_sts_success;
                x_error_messages   := NULL;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK TO before_so_purge;
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := SQLERRM;
                msg ('  EXCEPTION: ' || SQLERRM);
        END;

        msg ('-' || l_proc_name);
    END;

    PROCEDURE process_update_batch (
        p_raise_event       IN     VARCHAR2 := 'Y',
        p_ord_source_type   IN     VARCHAR2 := 'ALL', --Added as per CCR0009028
        x_batch_id             OUT NUMBER,
        x_ret_stat             OUT VARCHAR2,
        x_error_messages       OUT VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_proc_name                   VARCHAR2 (80) := g_pkg_name || '.process_update_batch';
        l_bus_event_result            VARCHAR2 (20);
        l_cnt                         NUMBER;
        l_tot_cnt                     NUMBER;
        l_batch_order_source          VARCHAR2 (200);
        l_batch_org_id                NUMBER;
        l_line_cnt                    NUMBER;
        l_max_batch_cnt               NUMBER;
        l_batch_throttle_time         NUMBER;
        l_split_batch_throttle_time   NUMBER;
        l_batch_list                  SYS.ODCINUMBERLIST;
        l_split_idx                   NUMBER;
        l_split                       NUMBER;
        x_new_batch_id                NUMBER;
        ln_source_id                  NUMBER;          -- Added for CCR0009596
        ln_porcess_batch_id           NUMBER;

        CURSOR c_batch_output (p_batch_id IN NUMBER)
        IS
              SELECT haou.NAME AS operating_unit_name, COUNT (1) AS order_count
                FROM xxdo.xxdoint_om_salesord_upd_batch upd_btch
                     INNER JOIN ont.oe_order_headers_all ooha
                         ON ooha.header_id = upd_btch.header_id
                     INNER JOIN hr.hr_all_organization_units haou
                         ON haou.organization_id = ooha.org_id
               WHERE upd_btch.batch_id = p_batch_id
            GROUP BY haou.NAME
            ORDER BY haou.NAME;

        CURSOR c_batch_groups IS
            SELECT lookup_code, meaning, attribute1,
                   attribute2, attribute3, attribute4,
                   attribute5
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXDO_SOA_OM_NC_BATCH_GROUP'
                   AND language = 'US'
                   AND enabled_flag = 'Y';
    BEGIN
        msg ('+' || l_proc_name);
        msg (' p_raise_event=' || p_raise_event);

        ln_porcess_batch_id   := xxdo.XXD_ONT_ORDER_INT_BATCH_S.NEXTVAL;

        BEGIN
            UPDATE xxd_ont_b2b_so_headers_t
               SET batch_id   = ln_porcess_batch_id
             WHERE batch_id IS NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                       'Updating xxd_ont_b2b_so_headers_t EXCEPTION: '
                    || SQLERRM);
                msg (
                       ' Updating xxd_ont_b2b_so_headers_t EXCEPTION: '
                    || SQLERRM);
        END;


        BEGIN
            UPDATE xxdo.xxd_ont_b2b_so_lines_t
               SET batch_id   = ln_porcess_batch_id
             WHERE batch_id IS NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                    'Updating xxd_ont_b2b_so_lines_t EXCEPTION: ' || SQLERRM);
                msg ('  EXCEPTION: ' || SQLERRM);
        END;

        BEGIN
            UPDATE xxdo.xxd_ont_b2b_so_delivery_t
               SET batch_id   = ln_porcess_batch_id
             WHERE batch_id IS NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                       'updating  xxd_ont_b2b_so_delivery_t EXCEPTION: '
                    || SQLERRM);
                msg ('  EXCEPTION: ' || SQLERRM);
        END;

        BEGIN
            UPDATE xxdo.xxd_ont_b2b_so_holds_t
               SET batch_id   = ln_porcess_batch_id
             WHERE batch_id IS NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                    'updating xxd_ont_b2b_so_holds_t EXCEPTION: ' || SQLERRM);
                msg ('  EXCEPTION: ' || SQLERRM);
        END;



        BEGIN
            x_ret_stat         := apps.fnd_api.g_ret_sts_success;
            x_error_messages   := NULL;

            BEGIN
                SELECT lookup_code, attribute1
                  INTO l_max_batch_cnt, l_split_batch_throttle_time
                  FROM fnd_lookup_values
                 WHERE     lookup_type = 'XXDO_SOA_OM_NC_BATCH_MAX_ROWS'
                       AND language = 'US'
                       AND enabled_flag = 'Y';
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_max_batch_cnt   := g_so_max_batch_rows;
                    l_split_batch_throttle_time   :=
                        g_so_batch_split_throttle;
                    msg ('  EXCEPTION: ' || SQLERRM);
            END;

            BEGIN
                SELECT lookup_code
                  INTO l_batch_throttle_time
                  FROM fnd_lookup_values
                 WHERE     lookup_type = 'XXDO_SOA_OM_NC_BATCH_WAIT_TIME'
                       AND language = 'US'
                       AND enabled_flag = 'Y';
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_batch_throttle_time   := g_so_batch_throttle;
                    msg ('  EXCEPTION: ' || SQLERRM);
            END;

            msg ('Max Row: ' || l_max_batch_cnt);
            -- Start changes for CCR0009596
            /*DBMS_CDC_SUBSCRIBE.extend_window (
                subscription_name   => g_cdc_substription_name);
            msg ('  extended CDC window');*/
            -- End changes for CCR0009596
            msg ('  beginning inserts.');

            FOR c_batch_group IN c_batch_groups
            LOOP
                l_tot_cnt              := 0;
                l_batch_order_source   :=
                    SUBSTR (c_batch_group.meaning,
                            1,
                            INSTR (c_batch_group.meaning, ';') - 1);
                l_batch_org_id         :=
                    SUBSTR (c_batch_group.meaning,
                            INSTR (c_batch_group.meaning, ';', -1) + 1);

                IF c_batch_group.attribute3 IS NOT NULL
                THEN
                    l_max_batch_cnt   := c_batch_group.attribute3;
                    msg (
                           'Overriding max order records for batch  '
                        || l_batch_order_source
                        || ':'
                        || l_batch_org_id
                        || 'to '
                        || c_batch_group.attribute3
                        || ' recs');
                END IF;

                IF c_batch_group.attribute4 IS NOT NULL
                THEN
                    l_batch_throttle_time   := c_batch_group.attribute4;
                    msg (
                           'Overriding wait time for batch  '
                        || l_batch_order_source
                        || ':'
                        || l_batch_org_id
                        || 'to '
                        || c_batch_group.attribute4
                        || ' secs');
                END IF;

                IF c_batch_group.attribute5 IS NOT NULL
                THEN
                    l_split_batch_throttle_time   := c_batch_group.attribute5;
                    msg (
                           'Overriding split wait time for batch  '
                        || l_batch_order_source
                        || ':'
                        || l_batch_org_id
                        || 'to '
                        || c_batch_group.attribute5
                        || ' secs');
                END IF;


                SELECT xxdo.xxdoint_om_salesord_upd_btch_s.NEXTVAL
                  INTO x_batch_id
                  FROM DUAL;

                msg (
                       '  obtained batch_id '
                    || x_batch_id
                    || ' for '
                    || c_batch_group.lookup_code);

                -- Start changes for CCR0009596
                /*
                -- Sales Order Headers --
                INSERT INTO xxdo.xxdoint_om_salesord_upd_batch (batch_id,
                                                                header_id)
                    SELECT DISTINCT x_batch_id, alpha.header_id
                      FROM (  SELECT cscn$, header_id
                                FROM apps.so_xxdoint_oe_order_headers_v
                            GROUP BY cscn$, header_id
                              HAVING    DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             TO_CHAR (
                                                                 sold_to_org_id),
                                                             ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             TO_CHAR (
                                                                 order_source_id),
                                                             ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             TO_CHAR (
                                                                 price_list_id),
                                                             ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             TO_CHAR (
                                                                 payment_term_id),
                                                             ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             TO_CHAR (
                                                                 order_type_id),
                                                             ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             TO_CHAR (
                                                                 deliver_to_org_id),
                                                             ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             TO_CHAR (
                                                                 ship_to_org_id),
                                                             ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             TO_CHAR (
                                                                 invoice_to_org_id),
                                                             ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             TO_CHAR (org_id),
                                                             ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             TO_CHAR (
                                                                 salesrep_id),
                                                             ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (attribute5,
                                                              ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             TO_CHAR (
                                                                 order_number),
                                                             ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (cust_po_number,
                                                              ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             orig_sys_document_ref,
                                                             ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             shipping_method_code,
                                                             ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             shipping_instructions,
                                                             ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             packing_instructions,
                                                             ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             transactional_curr_code,
                                                             ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (open_flag, ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             TO_CHAR (
                                                                 ordered_date),
                                                             ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (attribute9,
                                                              ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (attribute6,
                                                              ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (attribute7,
                                                              ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             TO_CHAR (
                                                                 request_date),
                                                             ' '))) >
                                        1) alpha,
                           ont.oe_order_headers_all  oh,
                           ont.oe_order_sources      os
                     WHERE     alpha.header_id = oh.header_id
                           AND oh.order_source_id = os.order_source_id
                           AND os.name = l_batch_order_source
                           AND oh.org_id = NVL (l_batch_org_id, oh.org_id)
                           AND NOT EXISTS
                                   (SELECT NULL
                                      FROM xxdo.xxdoint_om_salesord_upd_batch
                                           btch
                                     WHERE     btch.batch_id = x_batch_id
                                           AND btch.header_id =
                                               alpha.header_id);*/

                -- Derive Order Source ID w.r.t 2.0
                SELECT order_source_id
                  INTO ln_source_id
                  FROM oe_order_sources
                 WHERE name = l_batch_order_source;

                -- SO Headers --w.r.t 2.0
                INSERT INTO xxdo.xxdoint_om_salesord_upd_batch (batch_id,
                                                                header_id)
                    SELECT DISTINCT x_batch_id, ooha.header_id
                      FROM oe_order_headers_all ooha, xxd_ont_b2b_so_headers_t xobh
                     WHERE     ooha.order_source_id = ln_source_id
                           AND xobh.header_id = ooha.header_id
                           AND xobh.batch_id = ln_porcess_batch_id
                           AND NOT EXISTS
                                   (SELECT 1
                                      FROM oe_transaction_types_tl ot, fnd_lookup_values_vl flv
                                     WHERE     ot.name = flv.meaning
                                           AND flv.lookup_type =
                                               'XXD_B2B_EXCL_ORDER_TYPE'
                                           AND ot.transaction_type_id =
                                               ooha.order_type_id
                                           AND ot.language = 'US'
                                           AND SYSDATE BETWEEN NVL (
                                                                   flv.start_date_active,
                                                                   SYSDATE)
                                                           AND NVL (
                                                                   flv.end_date_active,
                                                                     SYSDATE
                                                                   + 1)
                                           AND flv.enabled_flag = 'Y')
                           AND NOT EXISTS
                                   (SELECT 1
                                      FROM xxdo.xxdoint_om_salesord_upd_batch bat
                                     WHERE     bat.batch_id = x_batch_id
                                           AND bat.header_id = ooha.header_id);

                -- End changes for CCR0009596

                l_cnt                  := SQL%ROWCOUNT;
                l_tot_cnt              := l_cnt;
                msg (
                       '  inserted '
                    || l_cnt
                    || ' record(s) into the batch table for changes to OE_ORDER_HEADERS_ALL.');

                -- Start changes for CCR0009596
                /*
                -- Delivery Details --
                INSERT INTO xxdo.xxdoint_om_salesord_upd_batch (batch_id,
                                                                header_id)
                    SELECT DISTINCT x_batch_id, source_header_id
                      FROM (  SELECT cscn$, source_header_id
                                FROM apps.so_xxdoint_wsh_delivery_det_v
                               WHERE source_code = 'OE'
                            GROUP BY cscn$, source_header_id
                              HAVING    DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             released_status,
                                                             ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             tracking_number,
                                                             ' '))) >
                                        1) alpha,
                           ont.oe_order_headers_all  oh,
                           ont.oe_order_sources      os
                     WHERE     alpha.source_header_id = oh.header_id
                           AND oh.order_source_id = os.order_source_id
                           AND os.name = l_batch_order_source
                           AND oh.org_id = NVL (l_batch_org_id, oh.org_id)
                           AND NOT EXISTS
                                   (SELECT NULL
                                      FROM xxdo.xxdoint_om_salesord_upd_batch
                                           btch
                                     WHERE     btch.batch_id = x_batch_id
                                           AND btch.header_id =
                                               alpha.source_header_id);*/
                -- Deliveries
                INSERT INTO xxdo.xxdoint_om_salesord_upd_batch (batch_id,
                                                                header_id)
                    SELECT DISTINCT x_batch_id, ooha.header_id
                      FROM oe_order_headers_all ooha, xxd_ont_b2b_so_delivery_t xobd
                     WHERE     ooha.order_source_id = ln_source_id
                           AND xobd.source_header_id = ooha.header_id
                           AND xobd.batch_id = ln_porcess_batch_id
                           AND NOT EXISTS
                                   (SELECT 1
                                      FROM oe_transaction_types_tl ot, fnd_lookup_values_vl flv
                                     WHERE     ot.name = flv.meaning
                                           AND flv.lookup_type =
                                               'XXD_B2B_EXCL_ORDER_TYPE'
                                           AND ot.transaction_type_id =
                                               ooha.order_type_id
                                           AND ot.language = 'US'
                                           AND SYSDATE BETWEEN NVL (
                                                                   flv.start_date_active,
                                                                   SYSDATE)
                                                           AND NVL (
                                                                   flv.end_date_active,
                                                                     SYSDATE
                                                                   + 1)
                                           AND flv.enabled_flag = 'Y')
                           AND NOT EXISTS
                                   (SELECT 1
                                      FROM xxdo.xxdoint_om_salesord_upd_batch bat
                                     WHERE     bat.batch_id = x_batch_id
                                           AND bat.header_id = ooha.header_id);

                -- End changes for CCR0009596

                l_cnt                  := SQL%ROWCOUNT;
                l_tot_cnt              := l_tot_cnt + l_cnt;
                msg (
                       '  inserted '
                    || l_cnt
                    || ' record(s) into the batch table for changes to WSH_DELIVERY_DETAILS.');

                -- Start changes for CCR0009596
                /*
                -- Sales Order Lines --
                INSERT INTO xxdo.xxdoint_om_salesord_upd_batch (batch_id,
                                                                header_id)
                    SELECT DISTINCT x_batch_id, alpha.header_id
                      FROM (  SELECT cscn$, header_id
                                FROM apps.so_xxdoint_oe_order_lines_v
                            GROUP BY cscn$, header_id
                              HAVING    DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             orig_sys_line_ref,
                                                             ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             TO_CHAR (
                                                                 ship_from_org_id),
                                                             ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             TO_CHAR (
                                                                 inventory_item_id),
                                                             ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             order_quantity_uom,
                                                             ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             TO_CHAR (
                                                                 ordered_quantity),
                                                             ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             TO_CHAR (
                                                                 shipped_quantity),
                                                             ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             TO_CHAR (
                                                                 cancelled_quantity),
                                                             ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             TO_CHAR (
                                                                 unit_list_price),
                                                             ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             TO_CHAR (
                                                                 unit_selling_price),
                                                             ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             TO_CHAR (
                                                                 tax_value),
                                                             ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             TO_CHAR (
                                                                 request_date),
                                                             ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             TO_CHAR (
                                                                 schedule_ship_date),
                                                             ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (attribute1,
                                                              ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             TO_CHAR (
                                                                 actual_shipment_date),
                                                             ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (open_flag, ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             flow_status_code,
                                                             ' '))) >
                                        1
                                     OR DECODE (
                                            MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (
                                                DISTINCT NVL (
                                                             line_category_code,
                                                             ' '))) >
                                        1) alpha,
                           ont.oe_order_headers_all  oh,
                           ont.oe_order_sources      os
                     WHERE     alpha.header_id = oh.header_id
                           AND oh.order_source_id = os.order_source_id
                           AND os.name = l_batch_order_source
                           AND oh.org_id = NVL (l_batch_org_id, oh.org_id)
                           AND NOT EXISTS
                                   (SELECT NULL
                                      FROM xxdo.xxdoint_om_salesord_upd_batch
                                           btch
                                     WHERE     btch.batch_id = x_batch_id
                                           AND btch.header_id =
                                               alpha.header_id);*/
                -- SO Lines
                INSERT INTO xxdo.xxdoint_om_salesord_upd_batch (batch_id,
                                                                header_id)
                    SELECT DISTINCT x_batch_id, ooha.header_id
                      FROM oe_order_headers_all ooha, xxd_ont_b2b_so_lines_t xobl
                     WHERE     ooha.order_source_id = ln_source_id
                           AND xobl.header_id = ooha.header_id
                           AND xobl.batch_id = ln_porcess_batch_id
                           AND NOT EXISTS
                                   (SELECT 1
                                      FROM oe_transaction_types_tl ot, fnd_lookup_values_vl flv
                                     WHERE     ot.name = flv.meaning
                                           AND flv.lookup_type =
                                               'XXD_B2B_EXCL_ORDER_TYPE'
                                           AND ot.transaction_type_id =
                                               ooha.order_type_id
                                           AND ot.language = 'US'
                                           AND SYSDATE BETWEEN NVL (
                                                                   flv.start_date_active,
                                                                   SYSDATE)
                                                           AND NVL (
                                                                   flv.end_date_active,
                                                                     SYSDATE
                                                                   + 1)
                                           AND flv.enabled_flag = 'Y')
                           AND NOT EXISTS
                                   (SELECT 1
                                      FROM xxdo.xxdoint_om_salesord_upd_batch bat
                                     WHERE     bat.batch_id = x_batch_id
                                           AND bat.header_id = ooha.header_id);

                -- End changes for CCR0009596

                l_cnt                  := SQL%ROWCOUNT;
                l_tot_cnt              := l_tot_cnt + l_cnt;
                msg (
                       '  inserted '
                    || l_cnt
                    || ' record(s) into the batch table for changes to OE_ORDER_LINES_ALL.');

                -- Start changes for CCR0009596
                /*
                -- Sales Order Holds --
                INSERT INTO xxdo.xxdoint_om_salesord_upd_batch (batch_id,
                                                                header_id)
                    SELECT DISTINCT x_batch_id, alpha.header_id
                      FROM (  SELECT cscn$, header_id
                                FROM apps.so_xxdoint_oe_order_holds_v
                            GROUP BY cscn$, header_id
                              HAVING DECODE (
                                         MAX (operation$),
                                         'I ', 2,
                                         'D ', 2,
                                         COUNT (
                                             DISTINCT NVL (released_flag,
                                                           ' '))) >
                                     1) alpha,
                           ont.oe_order_headers_all  oh,
                           ont.oe_order_sources      os
                     WHERE     alpha.header_id = oh.header_id
                           AND oh.order_source_id = os.order_source_id
                           AND os.name = l_batch_order_source
                           AND oh.org_id = NVL (l_batch_org_id, oh.org_id)
                           AND NOT EXISTS
                                   (SELECT NULL
                                      FROM xxdo.xxdoint_om_salesord_upd_batch
                                           btch
                                     WHERE     btch.batch_id = x_batch_id
                                           AND btch.header_id =
                                               alpha.header_id);*/

                -- SO Holds
                INSERT INTO xxdo.xxdoint_om_salesord_upd_batch (batch_id,
                                                                header_id)
                    SELECT DISTINCT x_batch_id, ooha.header_id
                      FROM oe_order_headers_all ooha, xxd_ont_b2b_so_holds_t xoboh
                     WHERE     ooha.order_source_id = ln_source_id
                           AND xoboh.header_id = ooha.header_id
                           AND xoboh.batch_id = ln_porcess_batch_id
                           AND NOT EXISTS
                                   (SELECT 1
                                      FROM oe_transaction_types_tl ot, fnd_lookup_values_vl flv
                                     WHERE     ot.name = flv.meaning
                                           AND flv.lookup_type =
                                               'XXD_B2B_EXCL_ORDER_TYPE'
                                           AND ot.transaction_type_id =
                                               ooha.order_type_id
                                           AND ot.language = 'US'
                                           AND SYSDATE BETWEEN NVL (
                                                                   flv.start_date_active,
                                                                   SYSDATE)
                                                           AND NVL (
                                                                   flv.end_date_active,
                                                                     SYSDATE
                                                                   + 1)
                                           AND flv.enabled_flag = 'Y')
                           AND NOT EXISTS
                                   (SELECT 1
                                      FROM xxdo.xxdoint_om_salesord_upd_batch bat
                                     WHERE     bat.batch_id = x_batch_id
                                           AND bat.header_id = ooha.header_id);

                -- End changes for CCR0009596

                l_cnt                  := SQL%ROWCOUNT;
                l_tot_cnt              := l_tot_cnt + l_cnt;
                msg (
                       '  inserted '
                    || l_cnt
                    || ' record(s) into the batch table for changes to OE_ORDER_HOLDS_ALL.');
                COMMIT;

                BEGIN                                --Start W.r.t version 1.1
                    l_rundate   := Get_Last_Conc_Req_Run (gn_conc_request_id);
                    ld_rundate1   :=
                        TO_CHAR (l_rundate, 'DD-MON-YYYY HH24:MI:SS');



                    --Return Invoice number--CCR0006454
                    INSERT INTO xxdo.xxdoint_om_salesord_upd_batch (
                                    batch_id,
                                    header_id)
                        SELECT DISTINCT x_batch_id, header_id
                          FROM ra_customer_trx_all rct, ra_cust_trx_types_all rctt, oe_order_headers_all oh,
                               oe_order_sources oos
                         WHERE     rctt.TYPE = 'CM'
                               AND rctt.cust_trx_type_id =
                                   rct.cust_trx_type_id
                               AND oos.order_source_id = oh.order_source_id
                               AND rctt.org_id = rct.org_id
                               AND oos.name = l_batch_order_source
                               AND oos.name IN
                                       ('Hubsoft - Wholesale', 'Hubsoft - Distributor', 'Hubsoft - Wholesale - B2B')
                               --Commented as per CCR0008801
                               /*AND rct.INTERFACE_HEADER_ATTRIBUTE1 =
                                   TO_CHAR (oh.order_number) */
                               --START Added for CCR0008801 for performance
                               AND rct.interface_header_attribute1 =
                                   oh.order_number
                               AND rct.interface_header_context =
                                   'ORDER ENTRY'
                               --END Added for CCR0008801
                               AND rct.creation_date >=
                                   TO_DATE (ld_rundate1,
                                            'DD-MON-YYYY HH24:MI:SS')
                               AND NOT EXISTS
                                       (SELECT 1
                                          FROM xxdo.xxdoint_om_salesord_upd_batch bat
                                         WHERE     bat.batch_id = x_batch_id
                                               AND bat.header_id =
                                                   oh.header_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;                                   --End W.r.t version 1.1

                -- Start changes for CCR0009596
                -- Once inserted records into the batch table, staging table data can be deleted
                /*
                DELETE xxd_ont_b2b_so_headers_t xobh
                 WHERE EXISTS
                           (SELECT 1
                              FROM xxdo.xxdoint_om_salesord_upd_batch bat
                             WHERE bat.header_id = xobh.header_id);

                DELETE xxd_ont_b2b_so_delivery_t xobd
                 WHERE EXISTS
                           (SELECT 1
                              FROM xxdo.xxdoint_om_salesord_upd_batch bat
                             WHERE bat.header_id = xobd.source_header_id);

                DELETE xxd_ont_b2b_so_lines_t xobl
                 WHERE EXISTS
                           (SELECT 1
                              FROM xxdo.xxdoint_om_salesord_upd_batch bat
                             WHERE bat.header_id = xobl.header_id);

                DELETE xxd_ont_b2b_so_holds_t xoboh
                 WHERE EXISTS
                           (SELECT 1
                              FROM xxdo.xxdoint_om_salesord_upd_batch bat
                             WHERE bat.header_id = xoboh.header_id);

                COMMIT;
    */

                -- End changes for CCR0009596
                IF l_tot_cnt > l_max_batch_cnt
                THEN
                    --SPLIT
                    l_split            := FLOOR (l_tot_cnt / l_max_batch_cnt);
                    l_split_idx        := 1;
                    l_batch_list       := SYS.ODCINUMBERLIST ();
                    l_batch_list.EXTEND (l_split + 1);
                    l_batch_list (1)   := x_batch_id;

                    WHILE l_split > 0
                    LOOP
                        msg ('Splitting' || l_batch_list (l_split_idx));

                        SELECT xxdo.xxdoint_om_salesord_upd_btch_s.NEXTVAL
                          INTO x_new_batch_id
                          FROM DUAL;

                        UPDATE xxdo.xxdoint_om_salesord_upd_batch
                           SET BATCH_ID   = x_new_batch_id
                         WHERE     BATCH_ID = l_batch_list (l_split_idx)
                               AND header_id NOT IN
                                       (SELECT DISTINCT header_id
                                          FROM xxdo.xxdoint_om_salesord_upd_batch btch
                                         WHERE     btch.batch_id =
                                                   l_batch_list (l_split_idx)
                                               AND ROWNUM <= l_max_batch_cnt);

                        l_split_idx                  := l_split_idx + 1;
                        l_split                      := l_split - 1;
                        l_batch_list (l_split_idx)   := x_new_batch_id;
                        COMMIT;
                    END LOOP;
                ELSE
                    l_batch_list       := SYS.ODCINUMBERLIST ();
                    l_batch_list.EXTEND;
                    l_batch_list (1)   := x_batch_id;
                    msg ('Not Splitting ' || x_batch_id);
                END IF;

                FOR batch_idx IN 1 .. l_batch_list.COUNT
                LOOP
                    IF l_tot_cnt = 0
                    THEN
                        msg (
                            '  no sales order changes were found.  skipping business event.');
                        l_bus_event_result   := 'Not Needed';
                    ELSIF     NVL (p_raise_event, 'Y') = 'Y'
                          AND NVL (c_batch_group.attribute1, 'N') = 'N'
                          AND NVL (c_batch_group.attribute2, 'N') = 'Y'
                    THEN
                        msg ('  raising business event.');
                        raise_business_event (
                            p_batch_id         => l_batch_list (batch_idx),
                            p_batch_name       => g_so_ecomm_event,
                            x_ret_stat         => x_ret_stat,
                            x_error_messages   => x_error_messages);

                        IF NVL (x_ret_stat, apps.fnd_api.g_ret_sts_error) !=
                           apps.fnd_api.g_ret_sts_success
                        THEN
                            l_bus_event_result   := 'Failed';
                        ELSE
                            l_bus_event_result   := 'Raised';
                        END IF;
                    ELSIF     NVL (p_raise_event, 'Y') = 'Y'
                          AND NVL (c_batch_group.attribute1, 'N') = 'Y'
                          AND NVL (c_batch_group.attribute2, 'N') = 'N'
                    THEN
                        msg ('  raising business event.');
                        raise_business_event (
                            p_batch_id         => l_batch_list (batch_idx),
                            p_batch_name       => g_so_update_event,
                            x_ret_stat         => x_ret_stat,
                            x_error_messages   => x_error_messages);

                        IF NVL (x_ret_stat, apps.fnd_api.g_ret_sts_error) !=
                           apps.fnd_api.g_ret_sts_success
                        THEN
                            l_bus_event_result   := 'Failed';
                        ELSE
                            l_bus_event_result   := 'Raised';
                        END IF;
                    ELSIF     NVL (p_raise_event, 'Y') = 'Y'
                          AND NVL (c_batch_group.attribute1, 'N') = 'Y'
                          AND NVL (c_batch_group.attribute2, 'N') = 'Y'
                    THEN
                        msg ('  raising business event.');
                        raise_business_event (
                            p_batch_id         => l_batch_list (batch_idx),
                            p_batch_name       => g_so_update_event,
                            x_ret_stat         => x_ret_stat,
                            x_error_messages   => x_error_messages);

                        IF NVL (x_ret_stat, apps.fnd_api.g_ret_sts_error) !=
                           apps.fnd_api.g_ret_sts_success
                        THEN
                            l_bus_event_result   := 'Failed';
                        ELSE
                            l_bus_event_result   := 'Raised';
                        END IF;

                        msg ('  raising business event.');
                        raise_business_event (
                            p_batch_id         => l_batch_list (batch_idx),
                            p_batch_name       => g_so_ecomm_event,
                            x_ret_stat         => x_ret_stat,
                            x_error_messages   => x_error_messages);

                        IF NVL (x_ret_stat, apps.fnd_api.g_ret_sts_error) !=
                           apps.fnd_api.g_ret_sts_success
                        THEN
                            l_bus_event_result   := 'Failed';
                        ELSE
                            l_bus_event_result   := 'Raised';
                        END IF;
                    ELSE
                        l_bus_event_result   := 'Skipped';
                    END IF;

                    COMMIT;
                    msg (
                           'Batch Split End: '
                        || l_batch_list (batch_idx)
                        || ' '
                        || TO_CHAR (SYSDATE, 'yyyy-mm-dd hh24.mi.ss')
                        || ' waiting '
                        || l_split_batch_throttle_time
                        || ' secs');

                    IF in_conc_request
                    THEN
                        IF batch_idx > 1
                        THEN
                            apps.fnd_file.put_line (apps.fnd_file.output,
                                                    ' ');
                            apps.fnd_file.put_line (apps.fnd_file.output,
                                                    ' ');
                        END IF;

                        apps.fnd_file.put_line (
                            apps.fnd_file.output,
                            'Batch ID: ' || l_batch_list (batch_idx));
                        apps.fnd_file.put_line (
                            apps.fnd_file.output,
                            'Business Event: ' || l_bus_event_result);
                        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
                        apps.fnd_file.put_line (
                            apps.fnd_file.output,
                               RPAD ('Operating Unit', 25, ' ')
                            || LPAD ('Orders', 10, ' '));
                        apps.fnd_file.put_line (apps.fnd_file.output,
                                                RPAD ('=', 35, '='));

                        FOR c_output
                            IN c_batch_output (l_batch_list (batch_idx))
                        LOOP
                            apps.fnd_file.put_line (
                                apps.fnd_file.output,
                                   RPAD (c_output.operating_unit_name,
                                         25,
                                         ' ')
                                || RPAD (c_output.order_count, 10, ' '));
                        END LOOP;
                    END IF;

                    IF NVL (l_split_batch_throttle_time, 0) > 0
                    THEN
                        DBMS_LOCK.sleep (l_split_batch_throttle_time);
                    END IF;
                END LOOP;

                msg (
                       'End: '
                    || TO_CHAR (SYSDATE, 'yyyy-mm-dd hh24.mi.ss')
                    || ' waiting '
                    || l_batch_throttle_time
                    || ' secs');

                IF NVL (l_batch_throttle_time, 0) > 0
                THEN
                    DBMS_LOCK.sleep (l_batch_throttle_time);
                END IF;
            END LOOP;
        -- Start changes for CCR0009596
        /*msg ('  purged CDC window');
        DBMS_CDC_SUBSCRIBE.purge_window (
            subscription_name   => g_cdc_substription_name);*/
        -- End changes for CCR0009596
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK;
                x_batch_id         := NULL;
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := SQLERRM;
                msg ('  EXCEPTION: ' || SQLERRM);
        END;

        msg (
               'x_batch_id='
            || x_batch_id
            || ', x_ret_stat='
            || x_ret_stat
            || ', x_error_messages='
            || x_error_messages);
        msg ('-' || l_proc_name);
    -- Start changes for CCR0009596
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_stat         := apps.fnd_api.g_ret_sts_error;
            x_error_messages   := SQLERRM;
            msg ('  EXCEPTION: ' || SQLERRM);
    -- End changes for CCR0009596
    END;

    PROCEDURE raise_business_event (p_batch_id IN NUMBER, p_batch_name IN VARCHAR2, x_ret_stat OUT VARCHAR2
                                    , x_error_messages OUT VARCHAR2)
    IS
        l_proc_name   VARCHAR2 (80) := g_pkg_name || '.raise_business_event';
    BEGIN
        msg ('+' || l_proc_name);
        msg ('p_batch_id=' || p_batch_id);

        BEGIN
            apps.wf_event.RAISE (p_event_name => p_batch_name, p_event_key => TO_CHAR (p_batch_id), p_event_data => NULL
                                 , p_parameters => NULL);
            x_ret_stat         := apps.fnd_api.g_ret_sts_success;
            x_error_messages   := NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := SQLERRM;
                msg ('  EXCEPTION: ' || SQLERRM);
        END;

        msg (
               'x_ret_stat='
            || x_ret_stat
            || ', x_error_messages='
            || x_error_messages);
        msg ('-' || l_proc_name);
    END;

    PROCEDURE process_update_batch_conc (
        psqlstat               OUT VARCHAR2,
        perrproc               OUT VARCHAR2,
        p_raise_event       IN     VARCHAR2 := 'Y',
        p_debug_level       IN     NUMBER := NULL,
        p_ord_source_type   IN     VARCHAR2 := 'ALL' --Added as per CCR0009028
                                                    )
    IS
        l_proc_name   VARCHAR2 (80)
                          := g_pkg_name || '.process_update_batch_conc';
        l_batch_id    NUMBER;
        l_ret         VARCHAR2 (1);
        l_err         VARCHAR2 (2000);
    BEGIN
        IF p_debug_level IS NOT NULL
        THEN
            apps.do_debug_tools.enable_conc_log (p_debug_level);
        ELSIF NVL (
                  TO_NUMBER (
                      apps.fnd_profile.VALUE ('XXDOINT_SO_DEBUG_LEVEL')),
                  0) >
              0
        THEN
            apps.do_debug_tools.enable_conc_log (
                TO_NUMBER (apps.fnd_profile.VALUE ('XXDOINT_SO_DEBUG_LEVEL')));
        END IF;

        msg ('+' || l_proc_name);
        msg (
               'p_raise_event='
            || p_raise_event
            || ', p_debug_level='
            || p_debug_level);
        process_update_batch (p_raise_event => p_raise_event, p_ord_source_type => p_ord_source_type, --Added as per CCR0009028
                                                                                                      x_batch_id => l_batch_id
                              , x_ret_stat => l_ret, x_error_messages => l_err);

        IF NVL (l_ret, apps.fnd_api.g_ret_sts_error) =
           apps.fnd_api.g_ret_sts_success
        THEN
            perrproc   := 0;
            psqlstat   := NULL;
        ELSE
            perrproc   := 2;
            psqlstat   := l_err;
        END IF;

        msg ('-' || l_proc_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('EXCEPTION: ' || SQLERRM);
            perrproc   := 2;
            psqlstat   := SQLERRM;
    END;

    PROCEDURE reprocess_batch_conc (psqlstat OUT VARCHAR2, perrproc OUT VARCHAR2, p_hours_old IN NUMBER
                                    , p_debug_level IN NUMBER:= NULL)
    IS
        l_proc_name   VARCHAR2 (80) := g_pkg_name || '.reprocess_batch_conc';
        l_ret         VARCHAR2 (1);
        l_err         VARCHAR2 (2000);
        l_ret_txt     VARCHAR2 (10);

        CURSOR c_batches IS
              SELECT batch_id, COUNT (1) AS order_count
                FROM xxdo.xxdoint_om_salesord_upd_batch upd_btch
               WHERE batch_date < SYSDATE - (p_hours_old / 24)
            GROUP BY batch_id
            ORDER BY batch_id;
    BEGIN
        IF p_debug_level IS NOT NULL
        THEN
            apps.do_debug_tools.enable_conc_log (p_debug_level);
        ELSIF NVL (
                  TO_NUMBER (
                      apps.fnd_profile.VALUE ('XXDOINT_SO_DEBUG_LEVEL')),
                  0) >
              0
        THEN
            apps.do_debug_tools.enable_conc_log (
                TO_NUMBER (apps.fnd_profile.VALUE ('XXDOINT_SO_DEBUG_LEVEL')));
        END IF;

        msg ('+' || l_proc_name);
        msg (
               'p_hours_old='
            || p_hours_old
            || ', p_debug_level='
            || p_debug_level);
        perrproc   := 0;
        psqlstat   := NULL;
        apps.fnd_file.put_line (apps.fnd_file.output,
                                'Hours Back: ' || p_hours_old);
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('Batch ID', 15, ' ')
            || LPAD ('Orders', 10, ' ')
            || RPAD ('Messages', 200, ' '));
        apps.fnd_file.put_line (apps.fnd_file.output, RPAD ('=', 225, '='));

        FOR c_batch IN c_batches
        LOOP
            raise_business_event (p_batch_id => c_batch.batch_id, p_batch_name => g_so_update_event, x_ret_stat => l_ret
                                  , x_error_messages => l_err);

            IF NVL (l_ret, apps.fnd_api.g_ret_sts_error) !=
               apps.fnd_api.g_ret_sts_success
            THEN
                l_ret_txt   := 'Error';
                perrproc    := 1;
                psqlstat    := 'At least one batch failed to process.';
            ELSE
                l_ret_txt   := 'Success';
            END IF;

            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   RPAD (c_batch.batch_id, 15, ' ')
                || RPAD (c_batch.order_count, 10, ' ')
                || RPAD (l_err, 200, ' '));
        END LOOP;

        msg ('-' || l_proc_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('EXCEPTION: ' || SQLERRM);
            perrproc   := 2;
            psqlstat   := SQLERRM;
    END;

    --START Added for CCR0008801
    --Functions used for Full and NC Views
    FUNCTION get_season_code (p_org_id IN NUMBER, p_header_id IN NUMBER, p_brand IN VARCHAR2, p_ord_type_name IN VARCHAR2, p_ord_source_name IN VARCHAR2, p_request_date IN DATE
                              , orig_sys_document_ref IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_season_code    VARCHAR2 (100);
        ld_request_date   DATE;
    BEGIN
        --Fetch Order Line Request Date for validation
        BEGIN
            SELECT CASE
                       WHEN (SELECT COUNT (1)
                               FROM apps.oe_order_lines_all oola
                              WHERE     oola.header_id = p_header_id
                                    AND oola.org_id = p_org_id
                                    AND flow_status_code <> 'CANCELLED') >
                            0
                       THEN
                           (SELECT MIN (request_date)
                              FROM apps.oe_order_lines_all oola
                             WHERE     oola.header_id = p_header_id
                                   AND oola.org_id = p_org_id
                                   AND oola.flow_status_code <> 'CANCELLED')
                       ELSE
                           (SELECT MIN (request_date)
                              FROM apps.oe_order_lines_all oola
                             WHERE     oola.header_id = p_header_id
                                   AND oola.org_id = p_org_id
                                   AND oola.flow_status_code = 'CANCELLED')
                   END
              INTO ld_request_date
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                ld_request_date   := p_request_date;
        END;

        --To Validate Order Source (B2B or Non-B2B)
        IF     UPPER (p_ord_source_name) LIKE '%HUB%'
           AND orig_sys_document_ref NOT LIKE 'OE_ORDER_HEADERS_ALL%' -- B2B orders Check  --w.r.t 1.5
        THEN
            lv_season_code   := NULL;
        ELSE                                                  --Non B2B Orders
            IF UPPER (p_ord_type_name) LIKE '%CLOSE%OUT%'
            THEN
                BEGIN
                    --Get Season code for 'CLOSEOUT' Orders
                    SELECT DISTINCT description
                      INTO lv_season_code
                      FROM fnd_lookup_values_vl flv
                     WHERE     lookup_type = 'XXD_B2B_SEASON_MAP'
                           AND NVL (flv.enabled_flag, 'N') = 'Y'
                           AND ld_request_date BETWEEN TRUNC (
                                                           NVL (
                                                               flv.start_date_active,
                                                               SYSDATE - 1))
                                                   AND TRUNC (
                                                           NVL (
                                                               flv.end_date_active,
                                                               SYSDATE + 1))
                           AND TO_NUMBER (attribute1) = p_org_id
                           AND attribute2 = p_brand
                           AND attribute3 = 'CLOSEOUT';
                EXCEPTION
                    WHEN TOO_MANY_ROWS
                    THEN
                        BEGIN                        --Added as per CCR0009028
                            --Get latest Season based on request date, if exists multiple
                            SELECT DISTINCT description
                              INTO lv_season_code
                              FROM fnd_lookup_values_vl flv
                             WHERE     lookup_type = 'XXD_B2B_SEASON_MAP'
                                   AND NVL (flv.enabled_flag, 'N') = 'Y'
                                   AND flv.start_date_active =
                                       (SELECT MAX (flv.start_date_active)
                                          FROM fnd_lookup_values_vl flv
                                         WHERE     lookup_type =
                                                   'XXD_B2B_SEASON_MAP'
                                               AND NVL (flv.enabled_flag,
                                                        'N') =
                                                   'Y'
                                               AND ld_request_date BETWEEN TRUNC (
                                                                               NVL (
                                                                                   flv.start_date_active,
                                                                                     SYSDATE
                                                                                   - 1))
                                                                       AND TRUNC (
                                                                               NVL (
                                                                                   flv.end_date_active,
                                                                                     SYSDATE
                                                                                   + 1))
                                               AND TO_NUMBER (attribute1) =
                                                   p_org_id
                                               AND attribute2 = p_brand
                                               AND attribute3 = 'CLOSEOUT')
                                   AND TO_NUMBER (attribute1) = p_org_id
                                   AND attribute2 = p_brand
                                   AND attribute3 = 'CLOSEOUT'
                                   AND ROWNUM = 1;
                        --Start Added as per CCR0009028
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                SELECT    CASE
                                              WHEN TO_NUMBER (
                                                       TO_CHAR (
                                                           ld_request_date,
                                                           'MM')) <=
                                                   6
                                              THEN
                                                  'S'
                                              ELSE
                                                  'F'
                                          END
                                       || TO_CHAR (ld_request_date, 'YY')
                                  INTO lv_season_code
                                  FROM DUAL;
                        END;
                    --End Added as per CCR0009028
                    WHEN OTHERS
                    THEN
                        SELECT    CASE
                                      WHEN TO_NUMBER (
                                               TO_CHAR (ld_request_date,
                                                        'MM')) <=
                                           6
                                      THEN
                                          'S'
                                      ELSE
                                          'F'
                                  END
                               || TO_CHAR (ld_request_date, 'YY')
                          INTO lv_season_code
                          FROM DUAL;
                END;
            ELSIF UPPER (p_ord_type_name) LIKE '%BULK%'
            THEN
                BEGIN
                    --Get Season code for 'BULK' Orders
                    SELECT DISTINCT description
                      INTO lv_season_code
                      FROM fnd_lookup_values_vl flv
                     WHERE     lookup_type = 'XXD_B2B_SEASON_MAP'
                           AND NVL (flv.enabled_flag, 'N') = 'Y'
                           AND ld_request_date BETWEEN TRUNC (
                                                           NVL (
                                                               flv.start_date_active,
                                                               SYSDATE - 1))
                                                   AND TRUNC (
                                                           NVL (
                                                               flv.end_date_active,
                                                               SYSDATE + 1))
                           AND TO_NUMBER (attribute1) = p_org_id
                           AND attribute2 = p_brand
                           AND attribute3 = 'BULK';
                EXCEPTION
                    WHEN TOO_MANY_ROWS
                    THEN
                        BEGIN                        --Added as per CCR0009028
                            --Get latest Season code based on request date, if exists multiple
                            SELECT DISTINCT description
                              INTO lv_season_code
                              FROM fnd_lookup_values_vl flv
                             WHERE     lookup_type = 'XXD_B2B_SEASON_MAP'
                                   AND NVL (flv.enabled_flag, 'N') = 'Y'
                                   AND flv.start_date_active =
                                       (SELECT MAX (flv.start_date_active)
                                          FROM fnd_lookup_values_vl flv
                                         WHERE     lookup_type =
                                                   'XXD_B2B_SEASON_MAP'
                                               AND NVL (flv.enabled_flag,
                                                        'N') =
                                                   'Y'
                                               AND ld_request_date BETWEEN TRUNC (
                                                                               NVL (
                                                                                   flv.start_date_active,
                                                                                     SYSDATE
                                                                                   - 1))
                                                                       AND TRUNC (
                                                                               NVL (
                                                                                   flv.end_date_active,
                                                                                     SYSDATE
                                                                                   + 1))
                                               AND TO_NUMBER (attribute1) =
                                                   p_org_id
                                               AND attribute2 = p_brand
                                               AND attribute3 = 'BULK')
                                   AND TO_NUMBER (attribute1) = p_org_id
                                   AND attribute2 = p_brand
                                   AND attribute3 = 'BULK'
                                   AND ROWNUM = 1;
                        --Start Added as per CCR0009028
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                SELECT    CASE
                                              WHEN TO_NUMBER (
                                                       TO_CHAR (
                                                           ld_request_date,
                                                           'MM')) <=
                                                   6
                                              THEN
                                                  'S'
                                              ELSE
                                                  'F'
                                          END
                                       || TO_CHAR (ld_request_date, 'YY')
                                  INTO lv_season_code
                                  FROM DUAL;
                        END;
                    --End Added as per CCR0009028
                    WHEN OTHERS
                    THEN
                        SELECT    CASE
                                      WHEN TO_NUMBER (
                                               TO_CHAR (ld_request_date,
                                                        'MM')) <=
                                           6
                                      THEN
                                          'S'
                                      ELSE
                                          'F'
                                  END
                               || TO_CHAR (ld_request_date, 'YY')
                          INTO lv_season_code
                          FROM DUAL;
                END;
            ELSE
                BEGIN
                    --Get Season code for Other Order Types
                    SELECT DISTINCT description
                      INTO lv_season_code
                      FROM fnd_lookup_values_vl flv
                     WHERE     lookup_type = 'XXD_B2B_SEASON_MAP'
                           AND NVL (flv.enabled_flag, 'N') = 'Y'
                           AND ld_request_date BETWEEN TRUNC (
                                                           NVL (
                                                               flv.start_date_active,
                                                               SYSDATE - 1))
                                                   AND TRUNC (
                                                           NVL (
                                                               flv.end_date_active,
                                                               SYSDATE + 1))
                           AND TO_NUMBER (attribute1) = p_org_id
                           AND attribute2 = p_brand
                           AND attribute3 IS NULL;
                EXCEPTION
                    WHEN TOO_MANY_ROWS
                    THEN
                        BEGIN                        --Added as per CCR0009028
                            --Get latest Season code based on request date, if exists multiple
                            SELECT DISTINCT description
                              INTO lv_season_code
                              FROM fnd_lookup_values_vl flv
                             WHERE     lookup_type = 'XXD_B2B_SEASON_MAP'
                                   AND NVL (flv.enabled_flag, 'N') = 'Y'
                                   AND flv.start_date_active =
                                       (SELECT MAX (flv.start_date_active)
                                          FROM fnd_lookup_values_vl flv
                                         WHERE     lookup_type =
                                                   'XXD_B2B_SEASON_MAP'
                                               AND NVL (flv.enabled_flag,
                                                        'N') =
                                                   'Y'
                                               AND ld_request_date BETWEEN TRUNC (
                                                                               NVL (
                                                                                   flv.start_date_active,
                                                                                     SYSDATE
                                                                                   - 1))
                                                                       AND TRUNC (
                                                                               NVL (
                                                                                   flv.end_date_active,
                                                                                     SYSDATE
                                                                                   + 1))
                                               AND TO_NUMBER (attribute1) =
                                                   p_org_id
                                               AND attribute2 = p_brand
                                               AND attribute3 IS NULL)
                                   AND TO_NUMBER (attribute1) = p_org_id
                                   AND attribute2 = p_brand
                                   AND attribute3 IS NULL
                                   AND ROWNUM = 1;
                        --Start Added as per CCR0009028
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                SELECT    CASE
                                              WHEN TO_NUMBER (
                                                       TO_CHAR (
                                                           ld_request_date,
                                                           'MM')) <=
                                                   6
                                              THEN
                                                  'S'
                                              ELSE
                                                  'F'
                                          END
                                       || TO_CHAR (ld_request_date, 'YY')
                                  INTO lv_season_code
                                  FROM DUAL;
                        END;
                    --End Added as per CCR0009028
                    WHEN OTHERS
                    THEN
                        SELECT    CASE
                                      WHEN TO_NUMBER (
                                               TO_CHAR (ld_request_date,
                                                        'MM')) <=
                                           6
                                      THEN
                                          'S'
                                      ELSE
                                          'F'
                                  END
                               || TO_CHAR (ld_request_date, 'YY')
                          INTO lv_season_code
                          FROM DUAL;
                END;
            END IF;
        END IF;                                            -- B2B Orders Check

        RETURN lv_season_code;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_hs_price_list (p_org_id IN NUMBER, p_header_id IN NUMBER, p_brand IN VARCHAR2, p_type IN VARCHAR2, p_ord_source_id IN NUMBER, p_ebs_pricelist_id IN NUMBER
                                , p_ebs_pricelist IN VARCHAR2, p_request_date IN DATE, orig_sys_document_ref IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_hs_price_list      VARCHAR2 (100);
        lv_hs_price_list_id   VARCHAR2 (100);
        ln_hs_ord_exists      NUMBER := 0;
        ld_request_date       DATE;
    BEGIN
        --To Validate Request Date
        BEGIN
            SELECT CASE
                       WHEN (SELECT COUNT (1)
                               FROM apps.oe_order_lines_all oola
                              WHERE     oola.header_id = p_header_id
                                    AND oola.org_id = p_org_id
                                    AND flow_status_code <> 'CANCELLED') >
                            0
                       THEN
                           (SELECT MIN (request_date)
                              FROM apps.oe_order_lines_all oola
                             WHERE     oola.header_id = p_header_id
                                   AND oola.org_id = p_org_id
                                   AND oola.flow_status_code <> 'CANCELLED')
                       ELSE
                           (SELECT MIN (request_date)
                              FROM apps.oe_order_lines_all oola
                             WHERE     oola.header_id = p_header_id
                                   AND oola.org_id = p_org_id
                                   AND oola.flow_status_code = 'CANCELLED')
                   END
              INTO ld_request_date
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                ld_request_date   := p_request_date;
        END;

        --To Validate Order Source (B2B or Non-B2B)
        BEGIN
            SELECT COUNT (1)
              INTO ln_hs_ord_exists
              FROM oe_order_sources oos, oe_order_headers_all ooha
             WHERE     oos.order_source_id = p_ord_source_id
                   AND oos.ORDER_SOURCE_ID = ooha.ORDER_SOURCE_ID
                   AND header_id = p_header_id
                   AND ORIG_SYS_DOCUMENT_REF NOT LIKE 'OE_ORDER_HEADERS_ALL%' --w.r.t 1.5
                   AND UPPER (name) LIKE '%HUB%';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_hs_ord_exists   := 0;
        END;

        IF NVL (ln_hs_ord_exists, 0) > 0                   -- B2B orders Check
        THEN
            lv_hs_price_list      := NULL;
            lv_hs_price_list_id   := NULL;
        ELSE
            BEGIN
                --Get Hubsoft Pricelist from lookup
                SELECT DISTINCT attribute2, attribute6
                  INTO lv_hs_price_list, lv_hs_price_list_id
                  FROM fnd_lookup_values_vl flv
                 WHERE     lookup_type = 'XXD_HUBSOFT_PRICELIST_MAP'
                       AND NVL (flv.enabled_flag, 'N') = 'Y'
                       AND ld_request_date BETWEEN TRUNC (
                                                       NVL (
                                                           flv.start_date_active,
                                                           SYSDATE - 1))
                                               AND TRUNC (
                                                       NVL (
                                                           flv.end_date_active,
                                                           SYSDATE + 1))
                       AND TO_NUMBER (attribute1) = p_ebs_pricelist_id
                       AND TO_NUMBER (attribute5) = p_org_id
                       AND attribute3 = p_brand;
            EXCEPTION
                WHEN TOO_MANY_ROWS
                THEN
                    --Get latest Hubsoft Pricelist based on request date, if exists multiple
                    BEGIN
                        SELECT DISTINCT attribute2, attribute6
                          INTO lv_hs_price_list, lv_hs_price_list_id
                          FROM fnd_lookup_values_vl flv
                         WHERE     lookup_type = 'XXD_HUBSOFT_PRICELIST_MAP'
                               AND NVL (flv.enabled_flag, 'N') = 'Y'
                               AND flv.start_date_active =
                                   (SELECT MAX (flv.start_date_active)
                                      FROM fnd_lookup_values_vl flv
                                     WHERE     lookup_type =
                                               'XXD_HUBSOFT_PRICELIST_MAP'
                                           AND NVL (flv.enabled_flag, 'N') =
                                               'Y'
                                           AND ld_request_date BETWEEN TRUNC (
                                                                           NVL (
                                                                               flv.start_date_active,
                                                                                 SYSDATE
                                                                               - 1))
                                                                   AND TRUNC (
                                                                           NVL (
                                                                               flv.end_date_active,
                                                                                 SYSDATE
                                                                               + 1))
                                           AND TO_NUMBER (attribute1) =
                                               p_ebs_pricelist_id
                                           AND TO_NUMBER (attribute5) =
                                               p_org_id
                                           AND attribute3 = p_brand)
                               AND TO_NUMBER (attribute1) =
                                   p_ebs_pricelist_id
                               AND TO_NUMBER (attribute5) = p_org_id
                               AND attribute3 = p_brand;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_hs_price_list      := p_ebs_pricelist;
                            lv_hs_price_list_id   := 'Pricelist'; --p_ebs_pricelist_id;
                    END;
                WHEN OTHERS
                THEN
                    lv_hs_price_list      := p_ebs_pricelist;
                    lv_hs_price_list_id   := 'Pricelist'; --p_ebs_pricelist_id;
            END;
        END IF;

        IF p_type = 'HS_PRICE_LIST_NAME'
        THEN
            RETURN lv_hs_price_list;
        ELSIF p_type = 'HS_PRICE_LIST_ID'
        THEN
            RETURN lv_hs_price_list_id;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    --END Added for CCR0008801

    FUNCTION get_hold_information (    --Start w.r.t. Version 1.6 (CCR0009093)
                                   p_org_id      IN NUMBER,
                                   p_header_id   IN NUMBER,
                                   p_hold_info   IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_hs_hold_type   VARCHAR2 (300);
        lv_hs_held_by     VARCHAR2 (300);
        lv_hs_hold_date   VARCHAR2 (300);
        ld_request_date   DATE;
    BEGIN
        IF p_hold_info = 'HOLD_TYPE'
        THEN
            BEGIN
                SELECT LISTAGG (NAME, ',') WITHIN GROUP (ORDER BY creation_Date, name) "HOLD_INFO"
                  INTO lv_hs_hold_type
                  FROM (  SELECT ohd.name, oha.creation_Date
                            FROM ont.oe_order_holds_all oha, ont.oe_hold_sources_all ohsa, ont.oe_hold_definitions ohd
                           WHERE     1 = 1
                                 AND p_header_id = oha.header_id
                                 AND oha.line_id IS NULL
                                 AND oha.hold_source_id = ohsa.hold_source_id
                                 AND ohsa.hold_id = ohd.hold_id
                                 AND oha.RELEASED_FLAG = 'N'
                        ORDER BY oha.creation_Date)
                 WHERE ROWNUM < 5;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    BEGIN
                        SELECT LISTAGG (NAME, ',') WITHIN GROUP (ORDER BY creation_Date, name) "HOLD_INFO"
                          INTO lv_hs_hold_type
                          FROM (  SELECT DISTINCT ohd.name, TRUNC (oha.creation_Date) creation_Date
                                    FROM ont.oe_order_holds_all oha, ont.oe_hold_sources_all ohsa, ont.oe_hold_definitions ohd,
                                         ont.oe_order_lines_all oola
                                   WHERE     1 = 1
                                         AND p_header_id = oha.header_id
                                         AND oha.line_id IS NOT NULL
                                         AND oola.line_id = oha.line_id
                                         AND oha.hold_source_id =
                                             ohsa.hold_source_id
                                         AND ohsa.hold_id = ohd.hold_id
                                         AND oha.RELEASED_FLAG = 'N'
                                ORDER BY TRUNC (oha.creation_Date))
                         WHERE ROWNUM < 5;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_hs_hold_type   := NULL;
                    END;
                WHEN OTHERS
                THEN
                    lv_hs_hold_type   := NULL;
            END;
        ELSIF p_hold_info = 'HOLD_CREATED_BY'
        THEN
            BEGIN
                SELECT LISTAGG (user_name, ',') WITHIN GROUP (ORDER BY creation_Date, user_name) "HOLD_CREATED_BY"
                  INTO lv_hs_held_by
                  FROM (  SELECT fu.user_name, oha.creation_Date
                            FROM ont.oe_order_holds_all oha, ont.oe_hold_sources_all ohsa, ont.oe_hold_definitions ohd,
                                 applsys.fnd_user fu
                           WHERE     1 = 1
                                 AND p_header_id = oha.header_id
                                 AND oha.line_id IS NULL
                                 AND oha.hold_source_id = ohsa.hold_source_id
                                 AND ohsa.hold_id = ohd.hold_id
                                 AND oha.created_by = fu.user_id
                                 AND oha.RELEASED_FLAG = 'N'
                        ORDER BY oha.creation_Date)
                 WHERE ROWNUM < 5;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    BEGIN
                        SELECT LISTAGG (user_name, ',') WITHIN GROUP (ORDER BY creation_Date, user_name) "HOLD_CREATED_BY"
                          INTO lv_hs_held_by
                          FROM (  SELECT DISTINCT fu.user_name, TRUNC (oha.creation_Date) creation_Date
                                    FROM ont.oe_order_holds_all oha, ont.oe_hold_sources_all ohsa, ont.oe_hold_definitions ohd,
                                         ont.oe_order_lines_all oola, applsys.fnd_user fu
                                   WHERE     p_header_id = oola.header_id
                                         AND p_header_id = oha.header_id
                                         AND oha.line_id IS NOT NULL
                                         AND oola.line_id =
                                             NVL (oha.line_id, oola.line_id)
                                         AND oha.hold_source_id =
                                             ohsa.hold_source_id
                                         AND ohsa.hold_id = ohd.hold_id
                                         AND oha.created_by = fu.user_id
                                         AND oha.RELEASED_FLAG = 'N'
                                ORDER BY TRUNC (oha.creation_Date))
                         WHERE ROWNUM < 5;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_hs_held_by   := NULL;
                    END;
                WHEN OTHERS
                THEN
                    lv_hs_held_by   := NULL;
            END;
        ELSIF p_hold_info = 'HOLD_CREATION_DATE'
        THEN
            BEGIN
                SELECT LISTAGG (TO_CHAR (TO_DATE (creation_Date, 'DD-MON-YY'), 'MM/DD/YYYY'), ',') WITHIN GROUP (ORDER BY creation_Date, name) "HOLD_CREATION_DATE"
                  INTO lv_hs_hold_date
                  FROM (  SELECT ohd.name, TRUNC (oha.creation_Date) creation_Date
                            FROM ont.oe_order_holds_all oha, ont.oe_hold_sources_all ohsa, ont.oe_hold_definitions ohd
                           WHERE     1 = 1
                                 AND p_header_id = oha.header_id
                                 AND oha.line_id IS NULL
                                 AND oha.hold_source_id = ohsa.hold_source_id
                                 AND ohsa.hold_id = ohd.hold_id
                                 AND oha.RELEASED_FLAG = 'N'
                        ORDER BY TRUNC (oha.creation_Date))
                 WHERE ROWNUM < 5;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    BEGIN
                        SELECT LISTAGG (TO_CHAR (TO_DATE (creation_Date, 'DD-MON-YY'), 'MM/DD/YYYY'), ',') WITHIN GROUP (ORDER BY creation_Date, name) "HOLD_CREATION_DATE"
                          INTO lv_hs_hold_date
                          FROM (  SELECT DISTINCT ohd.name, TRUNC (oha.creation_Date) creation_Date
                                    FROM ont.oe_order_holds_all oha, ont.oe_hold_sources_all ohsa, ont.oe_hold_definitions ohd,
                                         ont.oe_order_lines_all oola
                                   WHERE     1 = 1
                                         AND p_header_id = oha.header_id
                                         AND oha.line_id IS NOT NULL
                                         AND oola.line_id = oha.line_id
                                         AND oha.hold_source_id =
                                             ohsa.hold_source_id
                                         AND ohsa.hold_id = ohd.hold_id
                                         AND oha.RELEASED_FLAG = 'N'
                                ORDER BY TRUNC (oha.creation_Date))
                         WHERE ROWNUM < 5;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_hs_hold_date   := NULL;
                    END;
                WHEN OTHERS
                THEN
                    lv_hs_hold_date   := NULL;
            END;
        END IF;


        IF lv_hs_hold_type IS NULL
        THEN
            IF p_hold_info = 'HOLD_TYPE'
            THEN
                BEGIN
                    SELECT LISTAGG (NAME, ',') WITHIN GROUP (ORDER BY creation_Date, name) "HOLD_INFO"
                      INTO lv_hs_hold_type
                      FROM (  SELECT ohd.name, oha.creation_Date
                                FROM ont.oe_order_holds_all oha, ont.oe_hold_sources_all ohsa, ont.oe_hold_definitions ohd,
                                     ont.oe_order_lines_all oola
                               WHERE     1 = 1
                                     AND p_header_id = oha.header_id
                                     AND oha.line_id IS NOT NULL
                                     AND oola.line_id = oha.line_id
                                     AND oha.hold_source_id =
                                         ohsa.hold_source_id
                                     AND ohsa.hold_id = ohd.hold_id
                                     AND oha.RELEASED_FLAG = 'N'
                            ORDER BY oha.creation_Date)
                     WHERE ROWNUM < 5;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_hs_hold_type   := NULL;
                END;
            END IF;
        END IF;

        IF lv_hs_held_by IS NULL
        THEN
            IF p_hold_info = 'HOLD_CREATED_BY'
            THEN
                BEGIN
                    SELECT LISTAGG (user_name, ',') WITHIN GROUP (ORDER BY creation_Date, user_name) "HOLD_CREATED_BY"
                      INTO lv_hs_held_by
                      FROM (  SELECT fu.user_name, oha.creation_Date
                                FROM ont.oe_order_holds_all oha, ont.oe_hold_sources_all ohsa, ont.oe_hold_definitions ohd,
                                     ont.oe_order_lines_all oola, applsys.fnd_user fu
                               WHERE     p_header_id = oola.header_id
                                     AND p_header_id = oha.header_id
                                     AND oha.line_id IS NOT NULL
                                     AND oola.line_id =
                                         NVL (oha.line_id, oola.line_id)
                                     AND oha.hold_source_id =
                                         ohsa.hold_source_id
                                     AND ohsa.hold_id = ohd.hold_id
                                     AND oha.created_by = fu.user_id
                                     AND oha.RELEASED_FLAG = 'N'
                            ORDER BY oha.creation_Date)
                     WHERE ROWNUM < 5;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_hs_held_by   := NULL;
                END;
            END IF;
        END IF;

        IF lv_hs_hold_date IS NULL
        THEN
            IF p_hold_info = 'HOLD_CREATION_DATE'
            THEN
                BEGIN
                    SELECT LISTAGG (TO_CHAR (TO_DATE (creation_Date, 'DD-MON-YY'), 'MM/DD/YYYY'), ',') WITHIN GROUP (ORDER BY creation_Date, name) "HOLD_CREATION_DATE"
                      INTO lv_hs_hold_date
                      FROM (  SELECT ohd.name, TRUNC (oha.creation_Date) creation_Date
                                FROM ont.oe_order_holds_all oha, ont.oe_hold_sources_all ohsa, ont.oe_hold_definitions ohd,
                                     ont.oe_order_lines_all oola
                               WHERE     1 = 1
                                     AND p_header_id = oha.header_id
                                     AND oha.line_id IS NOT NULL
                                     AND oola.line_id = oha.line_id
                                     AND oha.hold_source_id =
                                         ohsa.hold_source_id
                                     AND ohsa.hold_id = ohd.hold_id
                                     AND oha.RELEASED_FLAG = 'N'
                            ORDER BY TRUNC (oha.creation_Date))
                     WHERE ROWNUM < 5;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_hs_hold_date   := NULL;
                END;
            END IF;
        END IF;

        IF p_hold_info = 'HOLD_TYPE'
        THEN
            RETURN lv_hs_hold_type;
        ELSIF p_hold_info = 'HOLD_CREATED_BY'
        THEN
            RETURN lv_hs_held_by;
        ELSIF p_hold_info = 'HOLD_CREATION_DATE'
        THEN
            RETURN lv_hs_hold_date;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;                                           --end as part of CCR0009093
END xxdoint_om_sales_order_utils;
/


GRANT EXECUTE ON APPS.XXDOINT_OM_SALES_ORDER_UTILS TO SOA_INT
/

GRANT EXECUTE ON APPS.XXDOINT_OM_SALES_ORDER_UTILS TO XXDO
/
