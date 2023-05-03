--
-- XXD_MSC_DEMANDS_CORRECTION_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:23 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_MSC_DEMANDS_CORRECTION_PKG"
AS
    /**********************************************************************************************
    * Package      : XXD_MSC_DEMANDS_CORRECTION_PKG
    * Design       : This package will be used to correct the discrepancies in msc_demands table
    *                in ASCP
    * Notes        :
    * Modification :
    -- ============================================================================================
    -- Date          Version#    Name                    Comments
    -- ============  =========   ======================  ==========================================
    -- 14-OCT-2021   1.0         Tejaswi Gangumalla       Initial Version
    -- 02-MAR-2022   1.1         Damodara Gupta           CCR0009839
    ***********************************************************************************************/
    gn_user_id           NUMBER := apps.fnd_global.user_id;
    gn_conc_request_id   NUMBER := apps.fnd_global.conc_request_id;
    gn_resp_appl_id      NUMBER := apps.fnd_global.resp_appl_id;
    gn_resp_id           NUMBER := apps.fnd_global.resp_id;
    gn_plan_id           NUMBER;

    PROCEDURE write_log (pv_msg IN VARCHAR2)
    IS
    BEGIN
        --Writing into Log file if the program is submitted from Front end application
        IF apps.fnd_global.user_id <> -1
        THEN
            fnd_file.put_line (fnd_file.LOG, pv_msg);
        ELSE
            DBMS_OUTPUT.put_line (pv_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            raise_application_error (
                -20020,
                'Error in Procedure write_log -> ' || SQLERRM);
    END write_log;

    PROCEDURE purge_stg
    IS
        ln_retention_days   NUMBER := 7;
    BEGIN
        BEGIN
            DELETE FROM
                xxdo.xxd_msc_demands_correct_stg_t
                  WHERE TRUNC (creation_date) <
                        TRUNC (SYSDATE - ln_retention_days);

            write_log ('Number of records deleted - ' || SQL%ROWCOUNT);
            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                write_log (
                       'Error while purging table xxd_msc_demands_correction_stg_t: '
                    || SQLERRM);
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('Error in purge_stg procedure: ' || SQLERRM);
    END purge_stg;

    PROCEDURE insert_into_stg (pn_organization_id   IN NUMBER,
                               pv_brand             IN VARCHAR2)
    IS
        CURSOR data_cur IS
            SELECT ooha.header_id, ooha.org_id, ooha.order_number,
                   ooha.order_type_id, oola.line_id, oola.ordered_item,
                   oola.override_atp_date_code, oola.schedule_ship_date, gn_plan_id plan_id,
                   'N' overall_status, 'N' reschedule_status, 'N' atp_override_upd_status,
                   gn_conc_request_id request_id, SYSDATE creation_date, gn_user_id created_by,
                   ROWNUM seq_number
              FROM oe_order_headers_all ooha, oe_order_lines_all oola, mtl_system_items_b msib
             WHERE     ooha.header_id = oola.header_id
                   AND msib.inventory_item_id = oola.inventory_item_id
                   AND oola.ship_from_org_id = msib.organization_id
                   AND msib.atp_flag = 'Y'
                   AND ooha.open_flag = 'Y'
                   AND oola.open_flag = 'Y'
                   AND oola.ordered_quantity > 0
                   AND oola.shipped_quantity IS NULL
                   AND oola.visible_demand_flag = 'Y'
                   AND oola.line_category_code = 'ORDER'
                   AND oola.ship_from_org_id NOT IN (132)
                   AND ooha.order_type_id NOT IN (1174, 1173, 1165,
                                                  1135, 1135, 1925)
                   AND oola.schedule_ship_date < TRUNC (SYSDATE) + 350
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.wsh_delivery_details
                             WHERE     organization_id =
                                       oola.ship_from_org_id
                                   AND source_code = 'OE'
                                   AND source_line_id = oola.line_id
                                   AND released_status IN ('S', 'Y', 'C'))
                   AND NOT EXISTS
                           (SELECT 1
                              FROM msc_demands@bt_ebs_to_ascp.us.oracle.com msc
                             WHERE     oola.line_id = msc.sales_order_line_id
                                   AND msc.organization_id =
                                       oola.ship_from_org_id
                                   AND msc.using_requirement_quantity > 0
                                   AND msc.plan_id = gn_plan_id)
                   -- Inventory Org
                   AND ((pn_organization_id IS NOT NULL AND oola.ship_from_org_id = pn_organization_id) OR (pn_organization_id IS NULL AND 1 = 1))
                   -- Brand
                   AND ((pv_brand IS NOT NULL AND ooha.attribute5 = pv_brand) OR (pv_brand IS NULL AND 1 = 1));

        TYPE msc_demands_tab_type
            IS TABLE OF xxdo.xxd_msc_demands_correct_stg_t%ROWTYPE
            INDEX BY BINARY_INTEGER;

        msc_demands_rec_type   msc_demands_tab_type;
    BEGIN
        OPEN data_cur;

        LOOP
            -- bulk fetch(read) operation
            FETCH data_cur BULK COLLECT INTO msc_demands_rec_type LIMIT 5000;

            EXIT WHEN msc_demands_rec_type.COUNT = 0;

            FORALL i IN INDICES OF msc_demands_rec_type SAVE EXCEPTIONS
                INSERT INTO xxdo.xxd_msc_demands_correct_stg_t
                     VALUES msc_demands_rec_type (i);

            COMMIT;
        END LOOP;

        CLOSE data_cur;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('Error in insert_into_stg procedure: ' || SQLERRM);
    END insert_into_stg;

    -- BEGIN CCR0009839

    PROCEDURE msg (pc_msg         VARCHAR2,
                   pn_log_level   NUMBER:= 9.99e125,
                   pc_origin      VARCHAR2:= 'Local Delegated Debug')
    IS
    BEGIN
        xxd_debug_tools_pkg.msg (pc_msg         => pc_msg,
                                 pn_log_level   => pn_log_level,
                                 pc_origin      => pc_origin);
    END msg;

    FUNCTION lock_order_line (pn_line_id NUMBER)
        RETURN oe_order_lines_all%ROWTYPE
    IS
        lr_order_line   oe_order_lines_all%ROWTYPE;
    BEGIN
        SELECT *
          INTO lr_order_line
          FROM oe_order_lines_all
         WHERE line_id = pn_line_id;

        RETURN lr_order_line;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END lock_order_line;

    PROCEDURE update_msc_records (pr_order_line IN oe_order_lines_all%ROWTYPE, xc_ret_stat OUT VARCHAR2)
    AS
        lc_order_number         VARCHAR2 (100);
        lc_ret_stat             VARCHAR2 (1);
        ln_count                NUMBER;
        ln_ord_count            NUMBER;
        ln_msc_refresh_number   NUMBER;
        ln_msc_atp_session_id   NUMBER;

        PROCEDURE call_msc_prc (
            pr_order_line           IN     oe_order_lines_all%ROWTYPE,
            pc_order_number         IN     VARCHAR2,
            pn_msc_refresh_number   IN     NUMBER,
            pn_msc_atp_session_id   IN     NUMBER,
            xc_ret_stat                OUT VARCHAR2)
        AS
            PRAGMA AUTONOMOUS_TRANSACTION;
        BEGIN
            xxd_atp_customization_pkg.update_msc_records@BT_EBS_TO_ASCP.US.ORACLE.COM ( -- Added the full DB name for CCR0009529
                pr_order_line           => pr_order_line,
                pc_order_number         => pc_order_number,
                pn_msc_refresh_number   => pn_msc_refresh_number,
                pn_msc_atp_session_id   => pn_msc_atp_session_id,
                xc_ret_stat             => xc_ret_stat);
            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                COMMIT;
                msg ('OTHER Exception in call_msc_prc:' || SQLERRM, 1);
                xc_ret_stat   := g_ret_sts_error;
        END call_msc_prc;
    BEGIN
        SELECT ooha.order_number || '.' || otta.name || '.ORDER ENTRY(' || pr_order_line.line_number || '.' || pr_order_line.shipment_number || ')'
          INTO lc_order_number
          FROM oe_order_headers_all ooha, oe_transaction_types_tl otta
         WHERE     ooha.header_id = pr_order_line.header_id
               AND otta.transaction_type_id = ooha.order_type_id
               AND otta.language = USERENV ('LANG');

        ln_msc_refresh_number   := mrp_ap_refresh_s.NEXTVAL;
        ln_msc_atp_session_id   := mrp_atp_schedule_temp_s.NEXTVAL;

        msg ('Calling ASCP update_msc_records API');
        call_msc_prc (pr_order_line           => pr_order_line,
                      pc_order_number         => lc_order_number,
                      pn_msc_refresh_number   => ln_msc_refresh_number,
                      pn_msc_atp_session_id   => ln_msc_atp_session_id,
                      xc_ret_stat             => lc_ret_stat);
        msg ('ASCP update_msc_records API Status: ' || lc_ret_stat);
        xc_ret_stat             := lc_ret_stat;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('OTHER Exception in update_msc_records:' || SQLERRM, 1);
            xc_ret_stat   := g_ret_sts_error;
    END update_msc_records;

    /****************************************************
 -- PROCEDURE updt_demand_order_qty_prc
 -- PURPOSE: This Procedure update the mismatch quantity in msc_demands table.
             Avoid quantity discrepancy in EBS and ASCP system order lines
 *****************************************************/

    PROCEDURE updt_demand_order_qty_prc (pn_organization_id   IN NUMBER,
                                         pv_brand             IN VARCHAR2)
    IS
        CURSOR order_demand_mismatch_cur IS
            SELECT ool.line_id, ool.ordered_quantity
              FROM apps.oe_order_lines_all ool, apps.oe_order_headers_all ooh, oe_transaction_types_tl ott
             WHERE     1 = 1
                   AND ott.language = 'US'
                   AND ooh.order_type_id = ott.transaction_type_id
                   AND ool.header_id = ooh.header_id
                   AND EXISTS
                           (SELECT NULL
                              FROM msc_demands@BT_EBS_TO_ASCP.US.ORACLE.COM d, apps.msc_plans@BT_EBS_TO_ASCP.US.ORACLE.COM pln
                             WHERE     d.plan_id = pln.plan_id
                                   AND pln.compile_designator = 'ATP'
                                   AND d.sales_order_line_id = ool.line_id
                                   AND d.organization_id =
                                       ool.ship_from_org_id
                                   AND d.using_requirement_quantity <> 0
                                   AND ool.ordered_quantity <>
                                       d.using_requirement_quantity
                                   AND d.schedule_ship_date IS NOT NULL)
                   -- Inventory Org
                   AND ((pn_organization_id IS NOT NULL AND ool.ship_from_org_id = pn_organization_id) OR (pn_organization_id IS NULL AND 1 = 1))
                   -- Brand
                   AND ((pv_brand IS NOT NULL AND ooh.attribute5 = pv_brand) OR (pv_brand IS NULL AND 1 = 1));

        ln_cnt          NUMBER := 0;
        lr_order_line   oe_order_lines_all%ROWTYPE;
        lv_ret_stat     VARCHAR2 (10);
    BEGIN
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            ('Procedure updt_demand_order_qty_mismatch Begins...' || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss')));

        -- dbms_output.put_line ('updt_demand_order_qty_mismatch Begins...'||TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));

        FOR i IN order_demand_mismatch_cur
        LOOP
            BEGIN
                                               /*UPDATE msc_demands@bt_ebs_to_ascp.us.oracle.com
  SET using_requirement_quantity = i.ordered_quantity
WHERE 1 = 1
  AND demand_id = i.demand_id
  AND sales_order_line_id = i.line_id
  AND organization_id = i.ship_from_org_id
  AND plan_id = i.plan_id
  AND schedule_ship_date IS NOT NULL
  AND using_requirement_quantity <> 0
  AND using_requirement_quantity <> i.ordered_quantity;*/

                lr_order_line   := lock_order_line (i.line_id);

                update_msc_records (pr_order_line   => lr_order_line,
                                    xc_ret_stat     => lv_ret_stat);

                IF lv_ret_stat = g_ret_sts_success
                THEN
                    ln_cnt   := ln_cnt + 1;
                ELSIF    lv_ret_stat = g_ret_sts_error
                      OR lv_ret_stat = g_ret_sts_unexp_error
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Exception Occurred in update_msc_records '
                        || lv_ret_stat);
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ROLLBACK;
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                        'Exception Occurred in Update Process ' || SQLERRM);
            -- dbms_output.put_line ('Exception Occurred while Update '||SQLERRM);
            END;
        END LOOP;

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            (ln_cnt || ' Lines Identified And Updated The Value To 0 Which Had A Non-Zero Quantity Even Though Lines Were Cancelled In EBS'));
        -- dbms_output.put_line (ln_cnt||' Lines Identified And Updated The Value To 0 Which Had A Non-Zero Quantity Even Though Lines Were Cancelled In EBS');

        COMMIT;

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            ('Procedure updt_demand_order_qty_mismatch Ends...' || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss')));
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Procedure updt_demand_order_qty_mismatch Failed' || SQLERRM);
            -- dbms_output.put_line ('Procedure updt_demand_order_qty_mismatch Failed'||SQLERRM);
            ROLLBACK;
    END updt_demand_order_qty_prc;

    -- END CCR0009839


    PROCEDURE main_proc (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, pn_organization_id IN NUMBER
                         , pv_brand IN VARCHAR2, pn_rec_per_batch IN VARCHAR2, pn_number_of_workers IN VARCHAR2)
    AS
        ln_rec_cnt           NUMBER := NULL;
        ln_max_rec_cnt       NUMBER := pn_rec_per_batch;
        ln_from_seq_num      NUMBER := NULL;
        ln_to_seq_num        NUMBER := 0;
        ln_child_cnt         NUMBER := NULL;
        ln_child_req         NUMBER := 0;
        ln_threads           NUMBER := pn_number_of_workers;
        ln_resched_req_id    NUMBER;
        ln_resched_count     NUMBER := 0;
        ln_unsch_sch_count   NUMBER := 0;
        ln_child_req_count   NUMBER := 0;
    BEGIN
        purge_stg ();

        BEGIN
            SELECT plan_id
              INTO gn_plan_id
              FROM msc_plans@bt_ebs_to_ascp.us.oracle.com
             WHERE compile_designator = 'ATP';
        EXCEPTION
            WHEN OTHERS
            THEN
                write_log ('Unable to derive Plan_ID: ' || SQLERRM);
                RETURN;
        END;

        insert_into_stg (pn_organization_id, pv_brand);
        write_log (
               'Insert into Staging Table Completion Time '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

        updt_demand_order_qty_prc (pn_organization_id, pv_brand); -- ADDED CCR0009839

        BEGIN
            SELECT COUNT (*)
              INTO ln_rec_cnt
              FROM xxdo.xxd_msc_demands_correct_stg_t
             WHERE     seq_number IS NOT NULL
                   AND request_id = gn_conc_request_id
                   AND overall_status = 'N';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_rec_cnt   := 0;
        END;

        IF ln_rec_cnt > 0
        THEN
            write_log ('Total Number of Records - ' || ln_rec_cnt);
            ln_child_cnt   := CEIL (ln_rec_cnt / ln_max_rec_cnt);

            FOR i IN 1 .. ln_child_cnt
            LOOP
                LOOP
                    SELECT COUNT (*)
                      INTO ln_child_req
                      FROM fnd_concurrent_programs fcp, fnd_concurrent_requests fc
                     WHERE     fcp.concurrent_program_name =
                               'XXD_MSC_DEMAND_CORREC_CHILD'
                           AND fc.concurrent_program_id =
                               fcp.concurrent_program_id
                           AND fc.parent_request_id =
                               fnd_global.conc_request_id
                           AND fc.phase_code IN ('R', 'P');

                    IF ln_child_req >= ln_threads
                    THEN
                        DBMS_LOCK.sleep (10);
                    ELSE
                        EXIT;
                    END IF;
                END LOOP;

                ln_from_seq_num   := ln_to_seq_num + 1;
                ln_to_seq_num     := ln_from_seq_num + ln_max_rec_cnt;
                ln_resched_req_id   :=
                    fnd_request.submit_request (
                        application   => 'XXDO',
                        program       => 'XXD_MSC_DEMAND_CORREC_CHILD',
                        description   =>
                            'Deckers MSC Demands Correction Child',
                        start_time    => SYSDATE,
                        sub_request   => FALSE,
                        argument1     => gn_conc_request_id,
                        argument2     => ln_from_seq_num,
                        argument3     => ln_to_seq_num);
                COMMIT;

                IF ln_resched_req_id = 0
                THEN
                    write_log (
                           'Rescheduling concurrent request failed to submit for seq number from: '
                        || ln_from_seq_num
                        || ' to: '
                        || ln_to_seq_num);
                    write_log (
                           'Timestamp: '
                        || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
                ELSE
                    write_log (
                           'Successfully Submitted the Rescheduling Concurrent Request for seq number from: '
                        || ln_from_seq_num
                        || ' to: '
                        || ln_to_seq_num
                        || ' and Request Id is '
                        || ln_resched_req_id);
                    write_log (
                           'Timestamp: '
                        || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
                END IF;

                EXIT WHEN ln_to_seq_num >= ln_rec_cnt;
            END LOOP;

            LOOP
                SELECT COUNT (*)
                  INTO ln_child_req_count
                  FROM fnd_concurrent_programs fcp, fnd_concurrent_requests fc
                 WHERE     fcp.concurrent_program_name =
                           'XXD_MSC_DEMAND_CORREC_CHILD'
                       AND fc.concurrent_program_id =
                           fcp.concurrent_program_id
                       AND fc.parent_request_id = fnd_global.conc_request_id
                       AND fc.phase_code IN ('R', 'P');

                IF ln_child_req_count <> 0
                THEN
                    DBMS_LOCK.sleep (30);
                ELSE
                    EXIT;
                END IF;
            END LOOP;

            BEGIN
                SELECT COUNT (*)
                  INTO ln_resched_count
                  FROM xxdo.xxd_msc_demands_correct_stg_t
                 WHERE     seq_number IS NOT NULL
                       AND request_id = gn_conc_request_id
                       AND overall_status = 'S'
                       AND NVL (reschedule_status, 'N') = 'N';
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_resched_count   := 0;
            END;

            BEGIN
                SELECT COUNT (*)
                  INTO ln_unsch_sch_count
                  FROM xxdo.xxd_msc_demands_correct_stg_t
                 WHERE     seq_number IS NOT NULL
                       AND request_id = gn_conc_request_id
                       AND overall_status = 'S'
                       AND NVL (reschedule_status, 'N') = 'Y';
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_unsch_sch_count   := 0;
            END;

            write_log ('Eligible lines count:' || ln_rec_cnt);
            write_log (
                'Lines processed in Rescheduling:' || ln_resched_count);
            write_log (
                   'Lines processed in unschedule and schedule:'
                || ln_unsch_sch_count);
        ELSE
            write_log ('No data found');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log (
                   'Exception in XXD_MSC_DEMANDS_CORRECTION_PKG.MAIN_PROC '
                || SQLERRM);
    END main_proc;

    PROCEDURE child_proc (errbuf               OUT VARCHAR2,
                          retcode              OUT VARCHAR2,
                          pn_request_id     IN     NUMBER,
                          pn_from_seq_num   IN     NUMBER,
                          pn_to_seq_num     IN     NUMBER)
    AS
        CURSOR valid_data_cur IS
            SELECT *
              FROM xxdo.xxd_msc_demands_correct_stg_t
             WHERE     overall_status IN ('N', 'E')
                   AND request_id = pn_request_id
                   AND seq_number BETWEEN pn_from_seq_num AND pn_to_seq_num;

        l_header_rec               oe_order_pub.header_rec_type;
        l_header_rec_out           oe_order_pub.header_rec_type;
        l_line_tbl                 oe_order_pub.line_tbl_type;
        l_line_rec                 oe_order_pub.line_rec_type;
        l_line_rec1                oe_order_pub.line_rec_type;
        l_action_request_tbl       oe_order_pub.request_tbl_type;
        l_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
        l_line_adj_tbl             oe_order_pub.line_adj_tbl_type;
        l_header_scr_tbl           oe_order_pub.header_scredit_tbl_type;
        l_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type;
        l_request_rec              oe_order_pub.request_rec_type;
        l_return_status            VARCHAR2 (1);
        l_return_status1           VARCHAR2 (1);
        l_msg_count                NUMBER;
        l_msg_data                 VARCHAR2 (4000);
        lc_error_message           VARCHAR2 (4000);
        x_return_status            VARCHAR2 (1);
        x_msg_count                NUMBER;
        x_msg_data                 VARCHAR2 (4000);
        x_header_val_rec           oe_order_pub.header_val_rec_type;
        x_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
        x_header_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type;
        x_header_price_att_tbl     oe_order_pub.header_price_att_tbl_type;
        x_header_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type;
        x_header_adj_assoc_tbl     oe_order_pub.header_adj_assoc_tbl_type;
        x_header_scredit_tbl       oe_order_pub.header_scredit_tbl_type;
        x_header_scredit_val_tbl   oe_order_pub.header_scredit_val_tbl_type;
        x_line_val_tbl             oe_order_pub.line_val_tbl_type;
        x_line_adj_tbl             oe_order_pub.line_adj_tbl_type;
        x_line_adj_val_tbl         oe_order_pub.line_adj_val_tbl_type;
        x_line_price_att_tbl       oe_order_pub.line_price_att_tbl_type;
        x_line_adj_att_tbl         oe_order_pub.line_adj_att_tbl_type;
        x_line_adj_assoc_tbl       oe_order_pub.line_adj_assoc_tbl_type;
        x_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type;
        x_line_tbl                 oe_order_pub.line_tbl_type;
        x_line_scredit_val_tbl     oe_order_pub.line_scredit_val_tbl_type;
        x_lot_serial_tbl           oe_order_pub.lot_serial_tbl_type;
        x_lot_serial_val_tbl       oe_order_pub.lot_serial_val_tbl_type;
        x_action_request_tbl       oe_order_pub.request_tbl_type;
        l_line_tbl_index           NUMBER;
        l_msg_index_out            NUMBER (10);
        ln_process_cnt             NUMBER := 0;
        ln_success_cnt             NUMBER := 0;
        ln_resp_id                 NUMBER := NULL;
        ln_resp_appl_id            NUMBER := NULL;
        lv_check_sucess            VARCHAR2 (2);
    BEGIN
        fnd_global.apps_initialize (user_id        => gn_user_id,
                                    resp_id        => gn_resp_id,
                                    resp_appl_id   => gn_resp_appl_id);
        mo_global.init ('ONT');

        FOR rec_headers IN valid_data_cur
        LOOP
            mo_global.set_org_context (rec_headers.org_id, NULL, 'ONT');
            l_line_tbl_index                          := 0;
            l_line_tbl.DELETE;
            oe_msg_pub.delete_msg;
            oe_msg_pub.initialize;
            lc_error_message                          := NULL;
            l_header_rec                              := oe_order_pub.g_miss_header_rec;
            l_header_rec.header_id                    := rec_headers.header_id;
            l_header_rec.operation                    := oe_globals.g_opr_update;
            l_line_tbl_index                          := l_line_tbl_index + 1;
            l_line_tbl (l_line_tbl_index)             := oe_order_pub.g_miss_line_rec;
            l_line_tbl (l_line_tbl_index).operation   :=
                oe_globals.g_opr_update;
            l_line_tbl (l_line_tbl_index).org_id      := rec_headers.org_id;
            l_line_tbl (l_line_tbl_index).header_id   :=
                rec_headers.header_id;
            l_line_tbl (l_line_tbl_index).line_id     := rec_headers.line_id;
            l_line_tbl (l_line_tbl_index).schedule_action_code   :=
                'RESCHEDULE';
            -- CALL TO PROCESS ORDER
            oe_order_pub.process_order (
                p_api_version_number       => 1.0,
                p_init_msg_list            => fnd_api.g_false,
                p_return_values            => fnd_api.g_false,
                p_action_commit            => fnd_api.g_false,
                x_return_status            => l_return_status,
                x_msg_count                => l_msg_count,
                x_msg_data                 => l_msg_data,
                p_header_rec               => l_header_rec,
                p_line_tbl                 => l_line_tbl,
                p_action_request_tbl       => l_action_request_tbl,
                x_header_rec               => l_header_rec_out,
                x_header_val_rec           => x_header_val_rec,
                x_header_adj_tbl           => x_header_adj_tbl,
                x_header_adj_val_tbl       => x_header_adj_val_tbl,
                x_header_price_att_tbl     => x_header_price_att_tbl,
                x_header_adj_att_tbl       => x_header_adj_att_tbl,
                x_header_adj_assoc_tbl     => x_header_adj_assoc_tbl,
                x_header_scredit_tbl       => x_header_scredit_tbl,
                x_header_scredit_val_tbl   => x_header_scredit_val_tbl,
                x_line_tbl                 => x_line_tbl,
                x_line_val_tbl             => x_line_val_tbl,
                x_line_adj_tbl             => x_line_adj_tbl,
                x_line_adj_val_tbl         => x_line_adj_val_tbl,
                x_line_price_att_tbl       => x_line_price_att_tbl,
                x_line_adj_att_tbl         => x_line_adj_att_tbl,
                x_line_adj_assoc_tbl       => x_line_adj_assoc_tbl,
                x_line_scredit_tbl         => x_line_scredit_tbl,
                x_line_scredit_val_tbl     => x_line_scredit_val_tbl,
                x_lot_serial_tbl           => x_lot_serial_tbl,
                x_lot_serial_val_tbl       => x_lot_serial_val_tbl,
                x_action_request_tbl       => l_action_request_tbl);
            ln_process_cnt                            :=
                ln_process_cnt + 1;

            IF l_return_status = 'S'
            THEN
                BEGIN
                    SELECT 'Y'
                      INTO lv_check_sucess
                      FROM msc_demands@bt_ebs_to_ascp.us.oracle.com msc
                     WHERE     msc.sales_order_line_id = rec_headers.line_id
                           AND msc.using_requirement_quantity > 0
                           AND msc.plan_id = rec_headers.plan_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_check_sucess   := 'N';
                END;

                IF NVL (lv_check_sucess, 'N') = 'Y'
                THEN
                    ln_success_cnt   := ln_success_cnt + 1;

                    BEGIN
                        UPDATE xxdo.xxd_msc_demands_correct_stg_t
                           SET overall_status = 'S', reschedule_status = NULL, atp_override_upd_status = NULL
                         WHERE     header_id = rec_headers.header_id
                               AND line_id = rec_headers.line_id
                               AND request_id = pn_request_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            write_log (
                                   'Error While Updating Staging Table : '
                                || SQLERRM);
                    END;

                    COMMIT;
                ELSE
                    -- Check the return status
                    FOR i IN 1 .. l_msg_count
                    LOOP
                        oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => l_msg_data
                                        , p_msg_index_out => l_msg_index_out);
                        lc_error_message   :=
                            SUBSTR (lc_error_message || l_msg_data, 1, 3000);
                    END LOOP;

                    write_log ('API Error Message - ' || lc_error_message);

                    BEGIN
                        UPDATE xxdo.xxd_msc_demands_correct_stg_t
                           SET overall_status = 'E', reschedule_status = NULL, atp_override_upd_status = NULL
                         WHERE     header_id = rec_headers.header_id
                               AND line_id = rec_headers.line_id
                               AND request_id = pn_request_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            write_log (
                                   'Error While Updating Staging Table : '
                                || SQLERRM);
                    END;

                    COMMIT;
                END IF;
            ELSE
                UPDATE xxdo.xxd_msc_demands_correct_stg_t
                   SET overall_status = 'E', reschedule_status = NULL, atp_override_upd_status = NULL
                 WHERE     header_id = rec_headers.header_id
                       AND line_id = rec_headers.line_id
                       AND request_id = pn_request_id;

                COMMIT;
            END IF;

            COMMIT;
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
            'Reschedule Processed Records: ' || ln_process_cnt);
        fnd_file.put_line (fnd_file.LOG,
                           'Reschedule Success Records: ' || ln_success_cnt);
        ln_process_cnt   := 0;
        ln_success_cnt   := 0;

        FOR rec_headers IN valid_data_cur
        LOOP
            mo_global.set_org_context (rec_headers.org_id, NULL, 'ONT');
            l_line_tbl_index                                       := 0;
            l_line_tbl.DELETE;
            oe_msg_pub.delete_msg;
            oe_msg_pub.initialize;
            lc_error_message                                       := NULL;
            l_header_rec                                           := oe_order_pub.g_miss_header_rec;
            l_header_rec.header_id                                 := rec_headers.header_id;
            l_header_rec.operation                                 := oe_globals.g_opr_update;
            l_line_tbl_index                                       := l_line_tbl_index + 1;
            l_line_tbl (l_line_tbl_index)                          := oe_order_pub.g_miss_line_rec;
            l_line_tbl (l_line_tbl_index).operation                :=
                oe_globals.g_opr_update;
            l_line_tbl (l_line_tbl_index).org_id                   := rec_headers.org_id;
            l_line_tbl (l_line_tbl_index).header_id                :=
                rec_headers.header_id;
            l_line_tbl (l_line_tbl_index).line_id                  := rec_headers.line_id;
            l_line_tbl (l_line_tbl_index).schedule_action_code     :=
                'UNSCHEDULE';
            -- CALL TO PROCESS ORDER
            oe_order_pub.process_order (
                p_api_version_number       => 1.0,
                p_init_msg_list            => fnd_api.g_false,
                p_return_values            => fnd_api.g_false,
                p_action_commit            => fnd_api.g_false,
                x_return_status            => l_return_status,
                x_msg_count                => l_msg_count,
                x_msg_data                 => l_msg_data,
                p_header_rec               => l_header_rec,
                p_line_tbl                 => l_line_tbl,
                p_action_request_tbl       => l_action_request_tbl,
                x_header_rec               => l_header_rec_out,
                x_header_val_rec           => x_header_val_rec,
                x_header_adj_tbl           => x_header_adj_tbl,
                x_header_adj_val_tbl       => x_header_adj_val_tbl,
                x_header_price_att_tbl     => x_header_price_att_tbl,
                x_header_adj_att_tbl       => x_header_adj_att_tbl,
                x_header_adj_assoc_tbl     => x_header_adj_assoc_tbl,
                x_header_scredit_tbl       => x_header_scredit_tbl,
                x_header_scredit_val_tbl   => x_header_scredit_val_tbl,
                x_line_tbl                 => x_line_tbl,
                x_line_val_tbl             => x_line_val_tbl,
                x_line_adj_tbl             => x_line_adj_tbl,
                x_line_adj_val_tbl         => x_line_adj_val_tbl,
                x_line_price_att_tbl       => x_line_price_att_tbl,
                x_line_adj_att_tbl         => x_line_adj_att_tbl,
                x_line_adj_assoc_tbl       => x_line_adj_assoc_tbl,
                x_line_scredit_tbl         => x_line_scredit_tbl,
                x_line_scredit_val_tbl     => x_line_scredit_val_tbl,
                x_lot_serial_tbl           => x_lot_serial_tbl,
                x_lot_serial_val_tbl       => x_lot_serial_val_tbl,
                x_action_request_tbl       => l_action_request_tbl);
            -- TO SCHEDULE
            oe_msg_pub.delete_msg;
            oe_msg_pub.initialize;
            lc_error_message                                       := NULL;
            l_line_tbl (l_line_tbl_index).schedule_action_code     :=
                'SCHEDULE';
            l_line_tbl (l_line_tbl_index).override_atp_date_code   := 'Y';
            l_line_tbl (l_line_tbl_index).schedule_ship_date       :=
                rec_headers.schedule_ship_date;
            -- CALL TO PROCESS ORDER
            oe_order_pub.process_order (
                p_api_version_number       => 1.0,
                p_init_msg_list            => fnd_api.g_false,
                p_return_values            => fnd_api.g_false,
                p_action_commit            => fnd_api.g_false,
                x_return_status            => l_return_status,
                x_msg_count                => l_msg_count,
                x_msg_data                 => l_msg_data,
                p_header_rec               => l_header_rec,
                p_line_tbl                 => l_line_tbl,
                p_action_request_tbl       => l_action_request_tbl,
                x_header_rec               => l_header_rec_out,
                x_header_val_rec           => x_header_val_rec,
                x_header_adj_tbl           => x_header_adj_tbl,
                x_header_adj_val_tbl       => x_header_adj_val_tbl,
                x_header_price_att_tbl     => x_header_price_att_tbl,
                x_header_adj_att_tbl       => x_header_adj_att_tbl,
                x_header_adj_assoc_tbl     => x_header_adj_assoc_tbl,
                x_header_scredit_tbl       => x_header_scredit_tbl,
                x_header_scredit_val_tbl   => x_header_scredit_val_tbl,
                x_line_tbl                 => x_line_tbl,
                x_line_val_tbl             => x_line_val_tbl,
                x_line_adj_tbl             => x_line_adj_tbl,
                x_line_adj_val_tbl         => x_line_adj_val_tbl,
                x_line_price_att_tbl       => x_line_price_att_tbl,
                x_line_adj_att_tbl         => x_line_adj_att_tbl,
                x_line_adj_assoc_tbl       => x_line_adj_assoc_tbl,
                x_line_scredit_tbl         => x_line_scredit_tbl,
                x_line_scredit_val_tbl     => x_line_scredit_val_tbl,
                x_lot_serial_tbl           => x_lot_serial_tbl,
                x_lot_serial_val_tbl       => x_lot_serial_val_tbl,
                x_action_request_tbl       => l_action_request_tbl);
            fnd_file.put_line (
                fnd_file.LOG,
                   'SCHEDULE2 for line id: '
                || rec_headers.line_id
                || '; Status: '
                || l_return_status);
            ln_process_cnt                                         :=
                ln_process_cnt + 1;

            IF l_return_status = 'S'
            THEN
                BEGIN
                    SELECT 'Y'
                      INTO lv_check_sucess
                      FROM msc_demands@bt_ebs_to_ascp.us.oracle.com msc
                     WHERE     msc.sales_order_line_id = rec_headers.line_id
                           AND msc.using_requirement_quantity > 0
                           AND msc.plan_id = rec_headers.plan_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_check_sucess   := 'N';
                END;

                IF NVL (lv_check_sucess, 'N') = 'Y'
                THEN
                    ln_success_cnt   := ln_success_cnt + 1;

                    BEGIN
                        UPDATE xxdo.xxd_msc_demands_correct_stg_t
                           SET overall_status = 'S', reschedule_status = 'Y', atp_override_upd_status = NULL
                         WHERE     header_id = rec_headers.header_id
                               AND line_id = rec_headers.line_id
                               AND request_id = pn_request_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            write_log (
                                   'Error While Updating Staging Table : '
                                || SQLERRM);
                    END;

                    COMMIT;
                ELSE
                    BEGIN
                        UPDATE xxdo.xxd_msc_demands_correct_stg_t
                           SET overall_status = 'E', reschedule_status = 'Y', atp_override_upd_status = NULL
                         WHERE     header_id = rec_headers.header_id
                               AND line_id = rec_headers.line_id
                               AND request_id = pn_request_id;

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            write_log (
                                   'Error While Updating Staging Table : '
                                || SQLERRM);
                    END;
                END IF;
            ELSE
                -- Check the return status
                FOR i IN 1 .. l_msg_count
                LOOP
                    oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => l_msg_data
                                    , p_msg_index_out => l_msg_index_out);
                    lc_error_message   :=
                        SUBSTR (lc_error_message || l_msg_data, 1, 3000);
                END LOOP;

                write_log ('API Error Message - ' || lc_error_message);

                BEGIN
                    UPDATE xxdo.xxd_msc_demands_correct_stg_t
                       SET overall_status   = 'E'
                     WHERE     header_id = rec_headers.header_id
                           AND line_id = rec_headers.line_id
                           AND request_id = pn_request_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        write_log (
                               'Error While Updating Staging Table : '
                            || SQLERRM);
                END;

                COMMIT;
            END IF;

            COMMIT;

            -- TO Remove ATP override
            IF    rec_headers.override_atp_date_code IS NULL
               OR rec_headers.override_atp_date_code <> 'Y'
            THEN
                oe_msg_pub.delete_msg;
                oe_msg_pub.initialize;
                lc_error_message   := NULL;
                l_line_tbl (l_line_tbl_index).override_atp_date_code   :=
                    NULL;
                -- CALL TO PROCESS ORDER
                oe_order_pub.process_order (
                    p_api_version_number       => 1.0,
                    p_init_msg_list            => fnd_api.g_false,
                    p_return_values            => fnd_api.g_false,
                    p_action_commit            => fnd_api.g_false,
                    x_return_status            => l_return_status,
                    x_msg_count                => l_msg_count,
                    x_msg_data                 => l_msg_data,
                    p_header_rec               => l_header_rec,
                    p_line_tbl                 => l_line_tbl,
                    p_action_request_tbl       => l_action_request_tbl,
                    x_header_rec               => l_header_rec_out,
                    x_header_val_rec           => x_header_val_rec,
                    x_header_adj_tbl           => x_header_adj_tbl,
                    x_header_adj_val_tbl       => x_header_adj_val_tbl,
                    x_header_price_att_tbl     => x_header_price_att_tbl,
                    x_header_adj_att_tbl       => x_header_adj_att_tbl,
                    x_header_adj_assoc_tbl     => x_header_adj_assoc_tbl,
                    x_header_scredit_tbl       => x_header_scredit_tbl,
                    x_header_scredit_val_tbl   => x_header_scredit_val_tbl,
                    x_line_tbl                 => x_line_tbl,
                    x_line_val_tbl             => x_line_val_tbl,
                    x_line_adj_tbl             => x_line_adj_tbl,
                    x_line_adj_val_tbl         => x_line_adj_val_tbl,
                    x_line_price_att_tbl       => x_line_price_att_tbl,
                    x_line_adj_att_tbl         => x_line_adj_att_tbl,
                    x_line_adj_assoc_tbl       => x_line_adj_assoc_tbl,
                    x_line_scredit_tbl         => x_line_scredit_tbl,
                    x_line_scredit_val_tbl     => x_line_scredit_val_tbl,
                    x_lot_serial_tbl           => x_lot_serial_tbl,
                    x_lot_serial_val_tbl       => x_lot_serial_val_tbl,
                    x_action_request_tbl       => l_action_request_tbl);
                fnd_file.put_line (
                    fnd_file.LOG,
                       'ATP Override for line id: '
                    || rec_headers.line_id
                    || '; Status: '
                    || l_return_status);

                IF l_return_status = 'S'
                THEN
                    BEGIN
                        SELECT 'Y'
                          INTO lv_check_sucess
                          FROM msc_demands@bt_ebs_to_ascp.us.oracle.com msc
                         WHERE     msc.sales_order_line_id =
                                   rec_headers.line_id
                               AND msc.using_requirement_quantity > 0
                               AND msc.plan_id = rec_headers.plan_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_check_sucess   := 'N';
                    END;

                    IF NVL (lv_check_sucess, 'N') = 'Y'
                    THEN
                        ln_success_cnt   := ln_success_cnt + 1;

                        BEGIN
                            UPDATE xxdo.xxd_msc_demands_correct_stg_t
                               SET overall_status = 'S', atp_override_upd_status = 'Y'
                             WHERE     header_id = rec_headers.header_id
                                   AND line_id = rec_headers.line_id
                                   AND request_id = pn_request_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                write_log (
                                       'Error While Updating Staging Table : '
                                    || SQLERRM);
                        END;

                        COMMIT;
                    ELSE
                        BEGIN
                            UPDATE xxdo.xxd_msc_demands_correct_stg_t
                               SET overall_status = 'E', atp_override_upd_status = 'E'
                             WHERE     header_id = rec_headers.header_id
                                   AND line_id = rec_headers.line_id
                                   AND request_id = pn_request_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                write_log (
                                       'Error While Updating Staging Table : '
                                    || SQLERRM);
                        END;

                        COMMIT;
                    END IF;
                ELSE
                    -- Check the return status
                    FOR i IN 1 .. l_msg_count
                    LOOP
                        oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => l_msg_data
                                        , p_msg_index_out => l_msg_index_out);
                        lc_error_message   :=
                            SUBSTR (lc_error_message || l_msg_data, 1, 3000);
                    END LOOP;

                    write_log ('API Error Message - ' || lc_error_message);

                    BEGIN
                        UPDATE xxdo.xxd_msc_demands_correct_stg_t
                           SET overall_status = 'E', atp_override_upd_status = 'E'
                         WHERE     header_id = rec_headers.header_id
                               AND line_id = rec_headers.line_id
                               AND request_id = pn_request_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            write_log (
                                   'Error While Updating Staging Table : '
                                || SQLERRM);
                    END;

                    COMMIT;
                END IF;

                COMMIT;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error in XXD_MSC_DEMANDS_CORRECTION_PKG.CHILD_PROC: '
                || SQLERRM);
    END child_proc;
END xxd_msc_demands_correction_pkg;
/
