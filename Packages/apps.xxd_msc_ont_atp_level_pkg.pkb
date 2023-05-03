--
-- XXD_MSC_ONT_ATP_LEVEL_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:22 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_MSC_ONT_ATP_LEVEL_PKG"
AS
    PROCEDURE LOG (pv_msgtxt_in IN VARCHAR2)
    IS
    BEGIN
        IF fnd_global.conc_login_id = -1
        THEN
            --         fnd_file.put_line (fnd_file.LOG, pv_msgtxt_in);
            --raise_application_error (-30001, pv_msgtxt_in);
            --rk_debug (substr (pv_msgtxt_in,1,500));
            DBMS_OUTPUT.put_line (pv_msgtxt_in);
        --log (pv_msgtxt_in);
        ELSE
            fnd_file.put_line (fnd_file.LOG, pv_msgtxt_in);
        --raise_application_error (-30001, pv_msgtxt_in);
        --         rk_debug (SUBSTR (pv_msgtxt_in, 1, 500));
        END IF;
    END LOG;

    -- +---------------------------------------------+
    -- | Procedure to print messages or notes in the |
    -- | OUTPUT file of the concurrent program       |
    -- +---------------------------------------------+

    PROCEDURE output (pv_msgtxt_in IN VARCHAR2)
    IS
    BEGIN
        IF fnd_global.conc_login_id = -1
        THEN
            LOG (pv_msgtxt_in);
        ELSE
            fnd_file.put_line (fnd_file.output, pv_msgtxt_in);
        --rk_debug (substr (pv_msgtxt_in,1,500));
        END IF;
    END output;


    PROCEDURE XXD_UPDATE_ERROR_LOG (p_session_id NUMBER, p_order_header_id NUMBER, p_action_type VARCHAR2
                                    , p_error_message VARCHAR2)
    IS
    BEGIN
        INSERT INTO XXDO.XXD_ATP_LEVEL_API_ERROR_T
             VALUES (p_session_id, p_order_header_id, p_action_type,
                     p_error_message, SYSDATE);

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END XXD_UPDATE_ERROR_LOG;


    FUNCTION get_org_id (pn_order_header_id NUMBER)
        RETURN NUMBER
    IS
        ln_org_id   NUMBER;
    BEGIN
        ln_org_id   := NULL;

        SELECT org_id
          INTO ln_org_id
          FROM oe_order_headers_all
         WHERE header_id = pn_order_header_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_org_id   := fnd_profile.VALUE ('ORG_ID');
    END;


    PROCEDURE prc_insert_atp_level_header (pn_session_id IN NUMBER, xn_status OUT NUMBER, xv_message OUT VARCHAR2)
    AS
        l_index                 NUMBER (10) := 0;
        dml_errors              EXCEPTION;
        PRAGMA EXCEPTION_INIT (dml_errors, -24381);
        lv_err_msg              VARCHAR2 (1000);
        lv_status               NUMBER := 0; -- if it return 1 then it is successful or if it return 2 then it is error
        lv_message              VARCHAR2 (2000) := 'No Error';
        ln_session_id           NUMBER := pn_session_id;

        CURSOR cur_sel_mrp_atp_tbl (pn_session_id NUMBER)
        IS
              SELECT xciv.style_number Style, xciv.style_desc, xciv.color_code color,
                     mast.session_id session_id, mast.demand_class, SUM (NVL (mast.exception15, 0)) total_atp
                FROM xxd_common_items_v xciv,
                     (  SELECT inventory_item_id, MIN (exception15) exception15, session_id,
                               source_organization_id, inventory_item_name, status_flag,
                               demand_class
                          FROM mrp_atp_schedule_temp
                         WHERE session_id = pn_session_id
                      GROUP BY inventory_item_id, session_id, source_organization_id,
                               inventory_item_name, status_flag, demand_class)
                     mast
               WHERE     mast.inventory_item_name IS NOT NULL
                     AND mast.session_id = pn_session_id
                     AND xciv.inventory_item_id = mast.inventory_item_id
                     AND xciv.organization_id = mast.source_organization_id
                     AND status_flag = 1
                     AND REGEXP_SUBSTR (inventory_item_name, '[^-]+', 1,
                                        1) = xciv.style_number
                     AND REGEXP_SUBSTR (inventory_item_name, '[^-]+', 1,
                                        2) = xciv.color_code
            GROUP BY mast.session_id, xciv.style_number, xciv.style_desc,
                     xciv.color_code, mast.demand_class
            ORDER BY style, color;


        CURSOR cur_update_seq_mrp_temp_tbl IS
            SELECT *
              FROM XXDO.XXD_MSC_ATP_LEVEL_HEADERS_GT
             WHERE session_id = pn_session_id;

        TYPE t_sel_mrp_atp_tbl_typ IS TABLE OF cur_sel_mrp_atp_tbl%ROWTYPE;

        t_sel_mrp_atp_tbl_tab   t_sel_mrp_atp_tbl_typ;
    BEGIN
        EXECUTE IMMEDIATE('TRUNCATE TABLE XXDO.XXD_MSC_ATP_LEVEL_HEADERS_GT');

        OPEN cur_sel_mrp_atp_tbl (ln_session_id);

        LOOP
            FETCH cur_sel_mrp_atp_tbl
                BULK COLLECT INTO t_sel_mrp_atp_tbl_tab
                LIMIT 500;

            LOG (
                   '1'
                || 'ln_session_id'
                || ln_session_id
                || ' abc '
                || t_sel_mrp_atp_tbl_tab.COUNT);

            BEGIN
                FORALL l_index IN 1 .. t_sel_mrp_atp_tbl_tab.COUNT
                  SAVE EXCEPTIONS
                    INSERT INTO XXDO.XXD_MSC_ATP_LEVEL_HEADERS_GT (
                                    XXD_SEQ_NUM,
                                    XXD_BRAND,
                                    xxd_style,
                                    XXD_STYLE_desc,
                                    xxd_color,
                                    demand_class,
                                    xxd_total_atp,
                                    session_id)
                             VALUES (
                                        XXDO.XXD_MSC_ATP_LEVEL_HEADERS_S.NEXTVAL,
                                        NULL,
                                        t_sel_mrp_atp_tbl_tab (l_index).style,
                                        t_sel_mrp_atp_tbl_tab (l_index).style_desc,
                                        t_sel_mrp_atp_tbl_tab (l_index).color,
                                        t_sel_mrp_atp_tbl_tab (l_index).demand_class,
                                        t_sel_mrp_atp_tbl_tab (l_index).total_atp,
                                        t_sel_mrp_atp_tbl_tab (l_index).session_id);
            EXCEPTION
                WHEN dml_errors
                THEN
                    FOR l_error_index IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                    LOOP
                        lv_err_msg   :=
                               'Error while Inserting XXD_MSC_MASS_UPDATE_TBL Table : '
                            || SQLCODE
                            || ' ---> '
                            || SQLERRM;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error while updating XXD_MSC_MASS_UPDATE_TBL Table : '
                            || t_sel_mrp_atp_tbl_tab (
                                   SQL%BULK_EXCEPTIONS (l_error_index).ERROR_INDEX).style
                            || ' -- '
                            || t_sel_mrp_atp_tbl_tab (
                                   SQL%BULK_EXCEPTIONS (l_error_index).ERROR_INDEX).color
                            || ' -- '
                            || SQLERRM
                            || '-----> '
                            || SQLCODE);

                        LOG ('Exception1' || SQLERRM);

                        lv_status    := 3;
                        lv_message   := lv_err_msg;
                    END LOOP;
                WHEN OTHERS
                THEN
                    lv_err_msg   :=
                           'Error Others while inserting into XXD_MSC_MASS_UPDATE_TBL table'
                        || SQLERRM;

                    FOR l_error_index IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                    LOOP
                        lv_err_msg   :=
                               'When Others exception: Error while inserting XXD_MSC_MASS_UPDATE_TBL Table : '
                            || SQLCODE
                            || ' ---> '
                            || SQLERRM;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'When others exception Error while inserting XXD_MSC_MASS_UPDATE_TBL Table : '
                            || t_sel_mrp_atp_tbl_tab (
                                   SQL%BULK_EXCEPTIONS (l_error_index).ERROR_INDEX).style
                            || ' -- '
                            || t_sel_mrp_atp_tbl_tab (
                                   SQL%BULK_EXCEPTIONS (l_error_index).ERROR_INDEX).color
                            || ' -- '
                            || SQLERRM
                            || '-----> '
                            || SQLCODE);
                        LOG ('Exception2');
                        lv_status    := 4;
                        lv_message   := lv_err_msg;
                    END LOOP;
            END;

            --COMMIT;

            EXIT WHEN cur_sel_mrp_atp_tbl%NOTFOUND;
        END LOOP;

        xn_status    := lv_status;
        xv_message   := lv_message;

        COMMIT;

        --LOG ('2');

        BEGIN
            FOR rec_update_seq_mrp_temp_tbl IN cur_update_seq_mrp_temp_tbl
            LOOP
                --using exception13 as the foreign key of XXD_SEQ_NUM at the header tbl
                UPDATE mrp_atp_schedule_temp
                   SET exception13 = rec_update_seq_mrp_temp_tbl.xxd_seq_num
                 -- Code change by BT Technology Team on 18-Nov to perf testing
                 --             WHERE     inventory_item_name LIKE
                 --                             ''
                 --                          || rec_update_seq_mrp_temp_tbl.XXD_STYLE
                 --                          || '-'
                 --                          || rec_update_seq_mrp_temp_tbl.XXD_COLOR
                 --                          || '-%'
                 WHERE     INSTR (
                               INVENTORY_ITEM_NAME,
                                  rec_update_seq_mrp_temp_tbl.xxd_style
                               || '-'
                               || rec_update_seq_mrp_temp_tbl.xxd_color) >
                           0
                       AND demand_class =
                           rec_update_seq_mrp_temp_tbl.demand_class
                       AND session_id =
                           rec_update_seq_mrp_temp_tbl.session_id;
            END LOOP;

            --LOG ('4');
            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                LOG ('Exception4');
                LOG (
                       'Exception Occured @XXD_MSC_ONT_ATP_LEVEL_PKG.insert_atp_level_header during updating back to MRP_ATP_SCHEDULE_TEMP Table'
                    || SQLERRM);

                lv_status    := 1;
                lv_message   :=
                       'Exception Occured @XXD_MSC_ONT_ATP_LEVEL_PKG.insert_atp_level_header during updating back to MRP_ATP_SCHEDULE_TEMP Table'
                    || SQLERRM;

                xn_status    := lv_status;
                xv_message   := lv_message;
        END;
    END;


    --procedure to update the xxd_mrp_atp_level_headers with new negative qty after clicking the back button

    PROCEDURE proc_update_xxd_headers (pn_session_id NUMBER, xn_status OUT NUMBER, xv_message OUT VARCHAR2)
    AS
        lv_status    NUMBER;
        lv_message   VARCHAR2 (3000);

        CURSOR cur_sel_mrp_atp_tbl (pn_session_id NUMBER)
        IS
              SELECT xciv.style_number Style, xciv.style_desc, xciv.color_code color,
                     mast.session_id session_id, mast.demand_class, SUM (NVL (mast.exception15, 0)) total_atp
                FROM xxd_common_items_v xciv,
                     (  SELECT inventory_item_id, MIN (exception15) exception15, session_id,
                               source_organization_id, inventory_item_name, status_flag,
                               demand_class
                          FROM mrp_atp_schedule_temp
                         WHERE session_id = pn_session_id
                      GROUP BY inventory_item_id, session_id, source_organization_id,
                               inventory_item_name, status_flag, demand_class)
                     mast
               WHERE     mast.inventory_item_name IS NOT NULL
                     AND mast.session_id = pn_session_id
                     AND xciv.inventory_item_id = mast.inventory_item_id
                     AND xciv.organization_id = mast.source_organization_id
                     AND status_flag = 1
                     --                  AND SUBSTR (inventory_item_name,
                     --                              1,
                     --                                INSTR (inventory_item_name,
                     --                                       '-',
                     --                                       1,
                     --                                       1)
                     --                              - 1) = xciv.style_number
                     --                  AND SUBSTR (SUBSTR (inventory_item_name,
                     --                                        INSTR (inventory_item_name,
                     --                                               '-',
                     --                                               1,
                     --                                               1)
                     --                                      + 1),
                     --                              1,
                     --                                INSTR (SUBSTR (inventory_item_name,
                     --                                                 INSTR (inventory_item_name,
                     --                                                        '-',
                     --                                                        1,
                     --                                                        1)
                     --                                               + 1),
                     --                                       '-',
                     --                                       1)
                     --                              - 1) = xciv.color_code
                     AND REGEXP_SUBSTR (inventory_item_name, '[^-]+', 1,
                                        1) = xciv.style_number
                     AND REGEXP_SUBSTR (inventory_item_name, '[^-]+', 1,
                                        2) = xciv.color_code
            GROUP BY mast.session_id, xciv.style_number, xciv.style_desc,
                     xciv.color_code, mast.demand_class
            ORDER BY style, color;
    BEGIN
        FOR rec_update_hdr_tbl IN cur_sel_mrp_atp_tbl (pn_session_id)
        LOOP
            --using exception13 as the foreign key of XXD_SEQ_NUM at the header tbl
            UPDATE XXD_MSC_ATP_LEVEL_HEADERS_GT
               SET xxd_total_atp   = rec_update_hdr_tbl.total_atp
             WHERE     xxd_style LIKE rec_update_hdr_tbl.Style
                   AND xxd_color = rec_update_hdr_tbl.COLOR
                   AND demand_class = rec_update_hdr_tbl.demand_class
                   AND session_id = rec_update_hdr_tbl.session_id;
        END LOOP;

        LOG ('4');
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            LOG ('Exception4');
            LOG (
                   'Exception Occured @XXD_MSC_ONT_ATP_LEVEL_PKG.proc_update_xxd_headers during updating back to XXD_MSC_ATP_LEVEL_HEADERS_GT Table'
                || SQLERRM);

            lv_status    := 1;
            lv_message   :=
                   'Exception Occured @XXD_MSC_ONT_ATP_LEVEL_PKG.proc_update_xxd_headers during updating back to XXD_MSC_ATP_LEVEL_HEADERS_GT Table'
                || SQLERRM;

            xn_status    := lv_status;
            xv_message   := lv_message;
    END;

    ------------------------------------------------------------------------------
    -- Procedure to call the report : "Deckers ATP Levelling New Sales Order Line Report"
    -- Start of the Changes by NRK on 16Dec
    PROCEDURE proc_new_sales_oe_line_report (pn_session_id       NUMBER,
                                             xn_request_id   OUT NUMBER)
    AS
        lc_error_msg         VARCHAR2 (2000);
        l_tbl_message_list   error_handler.error_tbl_type;
        ln_msg_index         NUMBER;
        ln_error_count       NUMBER := 0;
        lc_error_message     LONG;
        lc_status            VARCHAR2 (3000);
        lc_dev_phase         VARCHAR2 (200);
        lc_dev_status        VARCHAR2 (200);
        lb_wait              BOOLEAN;
        lc_phase             VARCHAR2 (100);
        lc_message           VARCHAR2 (100);
        ln_msg_index_out     NUMBER;
        ln_err_count         NUMBER;
        ln_count             NUMBER := 0;
        ln_request_id1       NUMBER;
        l_req_id             NUMBER;
        ln_user_id           NUMBER := FND_GLOBAL.USER_ID;
        ln_resp_id           NUMBER := FND_GLOBAL.RESP_ID;
        ln_appl_id           NUMBER := FND_GLOBAL.RESP_APPL_ID;
        l_layout_status      BOOLEAN;
    BEGIN
        fnd_global.apps_initialize (ln_user_id, ln_resp_id, ln_appl_id);
        l_layout_status   :=
            apps.fnd_request.add_layout (
                template_appl_name   => 'XXDO',
                template_code        => 'XXDOATPSOLR',
                template_language    => 'en',
                template_territory   => 'US',
                output_format        => 'EXCEL');
        LOG ('Calling Deckers ATP Levelling New Sales Order Line Report');
        ln_request_id1   :=
            apps.fnd_request.submit_request ('XXDO', 'XXDOATPSOLR', '',
                                             SYSDATE, FALSE, pn_session_id);
        LOG ('v_request_id := ' || ln_request_id1);

        IF ln_request_id1 > 0
        THEN
            l_req_id   := ln_request_id1;
            COMMIT;
        ELSE
            ROLLBACK;
        END IF;



        IF l_req_id > 0
        THEN
            lc_dev_phase    := NULL;
            lc_dev_status   := NULL;
        /*lb_wait :=
           fnd_concurrent.wait_for_request (request_id   => l_req_id --ln_concurrent_request_id
                                                                    ,
                                            interval     => 1,
                                            max_wait     => 1,
                                            phase        => lc_phase,
                                            status       => lc_status,
                                            dev_phase    => lc_dev_phase,
                                            dev_status   => lc_dev_status,
                                            MESSAGE      => lc_message);*/
        --                                    IF (   (UPPER (lc_dev_phase) = 'COMPLETE')
        --                                        OR (UPPER (lc_phase) = 'COMPLETED'))
        --                                    THEN
        --                                       EXIT;
        --                                    END IF;

        END IF;

        xn_request_id   := l_req_id;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            --x_retcode := 2;
            --x_errbuff := x_errbuff || SQLERRM;
            LOG (
                   'Calling WAIT FOR REQUEST Deckers ATP Levelling New Sales Order Line Report'
                || SQLERRM);
        WHEN OTHERS
        THEN
            --                              x_retcode := 2;
            --                              x_errbuff := x_errbuff || SQLERRM;
            LOG (
                   'Calling WAIT FOR REQUEST Deckers ATP Levelling New Sales Order Line Report error'
                || SQLERRM);
    END proc_new_sales_oe_line_report;

    -- End of the Changes by NRK on 16Dec
    ------------------------------------------------------------------------------

    --Procedure to call the report
    PROCEDURE proc_call_reschdl_report (pn_session_id       NUMBER,
                                        xn_request_id   OUT NUMBER)
    AS
        lc_error_msg         VARCHAR2 (2000);
        l_tbl_message_list   error_handler.error_tbl_type;
        ln_msg_index         NUMBER;
        ln_error_count       NUMBER := 0;
        lc_error_message     LONG;
        lc_status            VARCHAR2 (3000);
        lc_dev_phase         VARCHAR2 (200);
        lc_dev_status        VARCHAR2 (200);
        lb_wait              BOOLEAN;
        lc_phase             VARCHAR2 (100);
        lc_message           VARCHAR2 (100);
        ln_msg_index_out     NUMBER;
        ln_err_count         NUMBER;
        ln_count             NUMBER := 0;
        ln_request_id1       NUMBER;
        l_req_id             NUMBER;
        ln_user_id           NUMBER := FND_GLOBAL.USER_ID;
        ln_resp_id           NUMBER := FND_GLOBAL.RESP_ID;
        ln_appl_id           NUMBER := FND_GLOBAL.RESP_APPL_ID;
        l_layout_status      BOOLEAN;
    BEGIN
        fnd_global.apps_initialize (ln_user_id, ln_resp_id, ln_appl_id);
        l_layout_status   :=
            apps.fnd_request.add_layout (
                template_appl_name   => 'XXDO',
                template_code        => 'XXDOONTRES_NEW',
                template_language    => 'en',
                template_territory   => 'US',
                output_format        => 'EXCEL');
        LOG ('Calling Deckers Order Re-Scheduling Report New');
        ln_request_id1   :=
            apps.fnd_request.submit_request ('XXDO', 'XXDOONTRES_NEW', '',
                                             SYSDATE, FALSE, pn_session_id);
        LOG ('v_request_id := ' || ln_request_id1);

        IF ln_request_id1 > 0
        THEN
            l_req_id   := ln_request_id1;
            COMMIT;
        ELSE
            ROLLBACK;
        END IF;



        IF l_req_id > 0
        THEN
            lc_dev_phase    := NULL;
            lc_dev_status   := NULL;
            lb_wait         :=
                fnd_concurrent.wait_for_request (
                    request_id   => l_req_id        --ln_concurrent_request_id
                                            ,
                    interval     => 1,
                    max_wait     => 1,
                    phase        => lc_phase,
                    status       => lc_status,
                    dev_phase    => lc_dev_phase,
                    dev_status   => lc_dev_status,
                    MESSAGE      => lc_message);
        --                                    IF (   (UPPER (lc_dev_phase) = 'COMPLETE')
        --                                        OR (UPPER (lc_phase) = 'COMPLETED'))
        --                                    THEN
        --                                       EXIT;
        --                                    END IF;

        END IF;

        xn_request_id   := l_req_id;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            --x_retcode := 2;
            --x_errbuff := x_errbuff || SQLERRM;
            LOG (
                   'Calling WAIT FOR REQUEST Deckers Order Re-Scheduling Report New error'
                || SQLERRM);
        WHEN OTHERS
        THEN
            --                              x_retcode := 2;
            --                              x_errbuff := x_errbuff || SQLERRM;
            LOG (
                   'Calling WAIT FOR REQUEST Deckers Order Re-Scheduling Report New error'
                || SQLERRM);
    END;


    PROCEDURE proc_call_exception_report (pn_session_id NUMBER, pn_no_of_days NUMBER DEFAULT 1, xn_request_id OUT NUMBER)
    AS
        lc_error_msg         VARCHAR2 (2000);
        l_tbl_message_list   error_handler.error_tbl_type;
        ln_msg_index         NUMBER;
        ln_error_count       NUMBER := 0;
        lc_error_message     LONG;
        lc_status            VARCHAR2 (3000);
        lc_dev_phase         VARCHAR2 (200);
        lc_dev_status        VARCHAR2 (200);
        lb_wait              BOOLEAN;
        lc_phase             VARCHAR2 (100);
        lc_message           VARCHAR2 (100);
        ln_msg_index_out     NUMBER;
        ln_err_count         NUMBER;
        ln_count             NUMBER := 0;
        ln_request_id1       NUMBER;
        l_req_id             NUMBER;
        ln_user_id           NUMBER := FND_GLOBAL.USER_ID;
        ln_resp_id           NUMBER := FND_GLOBAL.RESP_ID;
        ln_appl_id           NUMBER := FND_GLOBAL.RESP_APPL_ID;
        l_layout_status      BOOLEAN;
        ln_no_of_days        NUMBER := NVL (pn_no_of_days, 1);
    BEGIN
        fnd_global.apps_initialize (ln_user_id, ln_resp_id, ln_appl_id);
        l_layout_status   :=
            apps.fnd_request.add_layout (
                template_appl_name   => 'XXDO',
                template_code        => 'XXDOATPEXCP',
                template_language    => 'en',
                template_territory   => 'US',
                output_format        => 'EXCEL');
        LOG ('Calling Deckers Order Re-Scheduling Report New');
        ln_request_id1   :=
            apps.fnd_request.submit_request ('XXDO', 'XXDOATPEXCP', '',
                                             SYSDATE, FALSE, pn_session_id,
                                             ln_no_of_days);
        LOG ('v_request_id := ' || ln_request_id1);

        IF ln_request_id1 > 0
        THEN
            l_req_id   := ln_request_id1;
            COMMIT;
        ELSE
            ROLLBACK;
        END IF;



        IF l_req_id > 0
        THEN
            lc_dev_phase    := NULL;
            lc_dev_status   := NULL;
            lb_wait         :=
                fnd_concurrent.wait_for_request (
                    request_id   => l_req_id        --ln_concurrent_request_id
                                            ,
                    interval     => 1,
                    max_wait     => 1,
                    phase        => lc_phase,
                    status       => lc_status,
                    dev_phase    => lc_dev_phase,
                    dev_status   => lc_dev_status,
                    MESSAGE      => lc_message);
        --                                    IF (   (UPPER (lc_dev_phase) = 'COMPLETE')
        --                                        OR (UPPER (lc_phase) = 'COMPLETED'))
        --                                    THEN
        --                                       EXIT;
        --                                    END IF;

        END IF;

        xn_request_id   := l_req_id;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            --x_retcode := 2;
            --x_errbuff := x_errbuff || SQLERRM;
            LOG (
                   'Calling WAIT FOR REQUEST Deckers Order Exception Report New error'
                || SQLERRM);
        WHEN OTHERS
        THEN
            --                              x_retcode := 2;
            --                              x_errbuff := x_errbuff || SQLERRM;
            LOG (
                   'Calling WAIT FOR REQUEST Deckers Order Exception Report New error'
                || SQLERRM);
    END;


    /*   --------------------------------------------------------------------------------------
       PROCEDURE insert_xxd_msc_temp_proc (p_session_id NUMBER)
       IS
          CURSOR cur_dist_items (cp_session_id NUMBER)
          IS
             SELECT DISTINCT inventory_item_id, source_organization_id
               FROM mrp_atp_schedule_temp
              WHERE session_id = cp_session_id;

          lv_ascp_item_id   NUMBER;
       BEGIN
          FOR rec_item IN cur_dist_items (p_session_id)
          LOOP
             SELECT DISTINCT inventory_item_id
               INTO lv_ascp_item_id
               FROM msc_system_items@bt_ebs_to_ascp
              WHERE     sr_inventory_item_id = rec_item.inventory_item_id
                    AND organization_id = rec_item.source_organization_id;

             INSERT INTO xxd_msc_alloc_demands_gt
                SELECT mad.*
                  FROM msc_alloc_demands@bt_ebs_to_ascp mad
                 WHERE     mad.inventory_item_id = lv_ascp_item_id
                       AND mad.organization_id = rec_item.source_organization_id;

             INSERT INTO xxd_msc_alloc_supplies_gt
                SELECT mas.*
                  FROM msc_alloc_supplies@bt_ebs_to_ascp mas
                 WHERE     mas.inventory_item_id = lv_ascp_item_id
                       AND mas.organization_id = rec_item.source_organization_id;
          END LOOP;

          COMMIT;
       EXCEPTION
          WHEN OTHERS
          THEN
             log ('Error occurred : ' || SQLERRM || SQLCODE);
       END insert_xxd_msc_temp_proc;

       */


    --Start changes by BT Technology on 06 Nov 15

    PROCEDURE proc_update_latest_accpbl_date (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, pn_session_id NUMBER, pn_user_id NUMBER, pn_resp_id NUMBER, pn_resp_appl_id NUMBER
                                              , pn_org_id NUMBER     --      ,
                                                                -- Start modification by BT Technology Team on 11/29/2015
                                                                --      x_msg_data           OUT        VARCHAR2)
                                                                -- End modification by BT Technology Team on 11/29/2015
                                                                )
    AS
        v_api_version_number           NUMBER := 1;
        v_return_status                VARCHAR2 (2000);
        v_msg_count                    NUMBER := 0;
        v_msg_data                     VARCHAR2 (30000);


        -- IN Variables --
        v_header_rec                   oe_order_pub.header_rec_type;
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
        ln_user_id                     NUMBER;
        ln_resp_id                     NUMBER;
        ln_resp_appl_id                NUMBER;
        ln_org_id                      NUMBER;
        ln_success_count               NUMBER := 0;
        ln_error_count                 NUMBER := 0;
        lc_msg                         VARCHAR2 (2000);
        LC_NEXT_MSG                    VARCHAR2 (2000);

        CURSOR cur_update_sel_oe_hdr IS
              SELECT DISTINCT order_header_id, order_number
                FROM mrp_atp_schedule_temp
               WHERE     session_id = pn_session_id
                     --                  AND atp_level_type = 1                          --for cancel
                     AND status_flag = 2
                     AND scheduled_ship_date IS NOT NULL
                     AND NVL (scheduled_ship_date,
                              (latest_acceptable_date - 1)) >=
                         latest_acceptable_date
            --AND exception12 not in (7,8) -- atp_level_type in std Mrp_atp_schedule_temp table
            ORDER BY order_header_id;


        CURSOR cur_update_lt_accp_dt (pn_oe_header_id NUMBER)
        IS
              SELECT DISTINCT order_header_id header_id, order_line_id line_id, scheduled_ship_date latest_acceptable_date
                FROM mrp_atp_schedule_temp
               WHERE     session_id = pn_session_id
                     --                  AND atp_level_type = 1                          --for cancel
                     AND status_flag = 2
                     AND scheduled_ship_date IS NOT NULL
                     AND NVL (scheduled_ship_date,
                              (latest_acceptable_date - 1)) >=
                         latest_acceptable_date
                     --AND exception12 not in (7,8) -- atp_level_type in std Mrp_atp_schedule_temp table
                     AND order_header_id = pn_oe_header_id
            ORDER BY order_header_id;
    BEGIN
        BEGIN
            --v_line_tbl                     := oe_order_pub.g_miss_line_rec;

            --log ('Total record count for cancellation'||xxd_v_line_tbl.count);

            ln_success_count   := 0;
            ln_error_count     := 0;

            --         x_retcode := 0;
            FOR rec_update_sel_oe_hdr IN cur_update_sel_oe_hdr
            LOOP
                v_xxd_updt_lad_Tbl.delete;
                v_msg_data        := NULL;

                x_retcode         := 0;

                  SELECT DISTINCT order_header_id header_id, order_line_id line_id, scheduled_ship_date
                    BULK COLLECT INTO v_xxd_updt_lad_Tbl
                    FROM mrp_atp_schedule_temp
                   WHERE     session_id = pn_session_id
                         --                  AND atp_level_type = 1                          --for cancel
                         AND status_flag = 2
                         AND scheduled_ship_date IS NOT NULL
                         AND NVL (scheduled_ship_date,
                                  (latest_acceptable_date - 1)) >=
                             latest_acceptable_date
                         AND order_header_id =
                             rec_update_sel_oe_hdr.order_header_id
                -- AND exception12 not in (7,8) -- atp_level_type in std Mrp_atp_schedule_temp table
                ORDER BY order_header_id;

                --           open cur_update_lt_accp_dt(rec_update_sel_oe_hdr.order_header_id);
                --
                --           LOOP
                --            fetch cur_update_lt_accp_dt bulk collect into v_xxd_updt_lad_Tbl LIMIT 500;
                --            LOG ('709_retcode  before apps initialize' || x_retcode);
                --            LOG (
                --                  pn_session_id
                --               || ','
                --               || pn_user_id
                --               || ','
                --               || pn_resp_id
                --               || ','
                --               || pn_resp_appl_id
                --               || ','
                --               || pn_org_id);

                LOG (
                    'Order Number :- ' || rec_update_sel_oe_hdr.order_number);

                LOG (
                       'Total record count for updating Latest Acceptable Date - '
                    || v_xxd_updt_lad_Tbl.COUNT);
                --            LOG (
                --                  pn_session_id
                --               || ','
                --               || ln_user_id
                --               || ','
                --               || ln_resp_id
                --               || ','
                --               || ln_resp_appl_id
                --               || ','
                --               || ln_org_id);

                ln_user_id        := pn_user_id; --fnd_profile.value('USER_ID');
                ln_resp_id        := pn_resp_id; --fnd_profile.value('RESP_ID');
                ln_resp_appl_id   := pn_resp_appl_id; --fnd_profile.value('RESP_APPL_ID');
                ln_org_id         := pn_org_id;

                -- Start modification by BT Technology Team on 08-Dec-15
                BEGIN
                    ln_org_id   := NULL;

                    SELECT org_id
                      INTO ln_org_id
                      FROM oe_order_headers_all
                     WHERE header_id = rec_update_sel_oe_hdr.order_header_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_org_id   := pn_org_id;
                END;

                -- End modification by BT Technology Team on 08-Dec-15

                --            LOG ('713_retcode  before apps initialize' || x_retcode);

                --            LOG (
                --                  pn_session_id
                --               || ','
                --               || ln_user_id
                --               || ','
                --               || ln_resp_id
                --               || ','
                --               || ln_resp_appl_id
                --               || ','
                --               || ln_org_id);

                --            LOG ('After intialization Of the Parameters');
                --
                --            fnd_global.apps_initialize (user_id        => pn_user_id,
                --                                        resp_id        => pn_resp_id,
                --                                        resp_appl_id   => pn_resp_appl_id);
                --
                --            log('1');
                --
                --            mo_global.init ('ONT');
                --            log('2');
                --            mo_global.set_policy_context ('S', ln_org_id);
                --            log('3');
                --            oe_msg_pub.initialize;
                --            log('4');
                --            oe_debug_pub.initialize;
                --            log('5');
                --
                --            log('6');
                --            LOG ('1x_retcode  before apps initialize' || x_retcode);
                v_line_tbl.delete;
                v_action_request_tbl.delete;

                FOR i IN 1 .. v_xxd_updt_lad_Tbl.COUNT
                LOOP
                    v_action_request_tbl (i)                :=
                        oe_order_pub.g_miss_request_rec;

                    -- update the latest acceptable date
                    v_line_tbl (i)                          := oe_order_pub.g_miss_line_rec;
                    v_line_tbl (i).operation                := OE_GLOBALS.G_OPR_UPDATE;
                    v_line_tbl (i).header_id                :=
                        v_xxd_updt_lad_Tbl (i).header_id;
                    v_line_tbl (i).line_id                  :=
                        v_xxd_updt_lad_Tbl (i).line_id;
                    v_line_tbl (i).latest_acceptable_date   :=
                        -- Start modification by BT Technology Team on 08-Dec-15
                        --                  v_xxd_updt_lad_Tbl (i).latest_acceptable_date;
                         v_xxd_updt_lad_Tbl (i).latest_acceptable_date + 1;
                    v_line_tbl (i).org_id                   := ln_org_id;
                -- End modification by BT Technology Team on 08-Dec-15


                --               LOG (
                --                     '** Ram 746 - 1x_retcode  before apps initialize'
                --                  || x_retcode);
                END LOOP;

                --EXIT when cur_update_lt_accp_dt%NOTFOUND;

                --END LOOP;



                --            LOG ('Starting of API');
                --            LOG ('756_retcode  before apps initialize' || x_retcode);

                -- Calling the API to cancel a line from an Existing Order --

                OE_ORDER_PUB.PROCESS_ORDER (
                    -- Start modification by BT Technology Team on 08-Dec-15
                    p_org_id                   => ln_org_id,
                    -- End modification by BT Technology Team on 08-Dec-15
                    p_api_version_number       => v_api_version_number,
                    p_header_rec               => v_header_rec,
                    p_line_tbl                 => v_line_tbl,
                    p_action_request_tbl       => v_action_request_tbl,
                    p_line_adj_tbl             => v_line_adj_tbl -- OUT variables
                                                                ,
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

                --x_msg_data := v_msg_data;

                --            LOG ('Completion of API');
                --            LOG ('795_retcode  before apps initialize' || x_retcode);


                IF v_return_status = fnd_api.g_ret_sts_success
                THEN
                    COMMIT;
                    ln_success_count   := ln_success_count + 1;
                    x_retcode          := 0;
                    --               LOG ('803_retcode  before apps initialize' || x_retcode);
                    LOG (
                        'Latest Acceptable Date has been successfully updated.');
                --x_msg_data :=
                --'Latest Acceptable Date has been successfully updated.';
                ELSE
                    ln_error_count   := ln_error_count + 1;
                    LOG (
                           'Error While updating Latest Acceptable Date - '
                        || v_msg_data);
                    v_msg_data       :=
                           'Error While updating Latest Acceptable Date - '
                        || v_msg_data;
                    LOG (
                           'Error while updating LAD for Order number - '
                        || rec_update_sel_oe_hdr.order_number
                        || '- Msg - '
                        || v_msg_data);
                    ROLLBACK;
                    x_retcode        := 1;

                    --i:= 0;
                    -- Start of ExceptionHandling 09Dec15
                    XXD_UPDATE_ERROR_LOG (pn_session_id, rec_update_sel_oe_hdr.order_header_id, 'proc_update_latest_accpbl_date'
                                          , v_msg_data);

                    -- End of Exception Handling 09Dec15
                    FOR i IN 1 .. v_msg_count
                    LOOP
                        lc_msg       := NULL;
                        oe_msg_pub.get (p_msg_index => i, p_encoded => FND_API.G_FALSE, p_data => lc_msg
                                        , p_msg_index_out => LC_NEXT_MSG);
                        v_msg_data   := v_msg_data || lc_msg;
                    END LOOP;

                    LOG (v_msg_data);
                    -- Start of ExceptionHandling 10Dec15
                    XXD_UPDATE_ERROR_LOG (pn_session_id, rec_update_sel_oe_hdr.order_header_id, 'proc_update_latest_accpbl_date'
                                          , v_msg_data);
                -- End of Exception Handling 10Dec15

                END IF;
            --            LOG ('11x_retcode  before apps initialize' || x_retcode);
            --            v_msg_data := substr(
            --                  rec_update_sel_oe_hdr.order_header_id
            --               || ' Status --> '
            --               || substr(v_msg_data,1,1000)
            --               || CHR (9),1,1000);
            --v_msg_data := v_msg_data ||chr(10);
            --LOG ('Message --> ' || v_msg_data);
            --            LOG ('834_retcode  before apps initialize' || x_retcode);
            END LOOP;

            BEGIN
                UPDATE mrp_atp_schedule_temp a
                   SET latest_acceptable_date   =
                           (SELECT scheduled_ship_date + 1
                              FROM mrp_atp_schedule_temp b
                             WHERE     scheduled_ship_date IS NOT NULL
                                   AND NVL (scheduled_ship_date,
                                            (latest_acceptable_date - 1)) >=
                                       latest_acceptable_date
                                   AND status_flag = 2
                                   AND a.order_line_id = b.order_line_id
                                   AND session_id = pn_session_id
                                   AND a.sequence_number = b.sequence_number --AND exception12 not in (7,8) -- atp_level_type in std Mrp_atp_schedule_temp table
                                                                            )
                 WHERE     session_id = pn_session_id
                       AND status_flag = 1
                       AND EXISTS
                               (SELECT 1
                                  FROM mrp_atp_schedule_temp b
                                 WHERE     status_flag = 2
                                       AND a.order_line_id = b.order_line_id
                                       AND scheduled_ship_date IS NOT NULL
                                       AND NVL (scheduled_ship_date,
                                                (latest_acceptable_date - 1)) >=
                                           latest_acceptable_date
                                       AND session_id = pn_session_id
                                       AND a.sequence_number =
                                           b.sequence_number --AND exception12 not in (7,8) -- atp_level_type in std Mrp_atp_schedule_temp table
                                                            );

                COMMIT;
            --AND exception12 not in (7,8);
            --and status_flag=1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_retcode   := 1;
                    LOG (
                           'Exception 1x_retcode  before apps initialize'
                        || x_retcode);
                    LOG (
                           'Error Encountered while updating mrp_atp_schedule_temp'
                        || SQLERRM);
                    XXD_UPDATE_ERROR_LOG (pn_session_id, 1111, 'proc_update_latest_accpbl_date_2'
                                          , SQLERRM);
            END;

            --         LOG ('869_retcode  before apps initialize' || x_retcode);

            --         x_msg_data := 'x_msg_data';
            --               'Total no of Records Successfully Updated'
            --            || to_char(ln_success_count)
            --            || 'Total no of Records which are in Error Status'
            --            || to_char(ln_error_count);

            x_errbuf           :=
                   'Total no of Records Successfully Updated - '
                || TO_CHAR (ln_success_count)
                || '        '
                || 'Total no of Records which are in Error Status - '
                || TO_CHAR (ln_error_count);
        --         LOG ('875_retcode  before apps initialize' || x_retcode);
        EXCEPTION
            WHEN OTHERS
            THEN
                x_retcode   := 1;
                LOG (
                       'Exception2 1x_retcode  before apps initialize'
                    || x_retcode);
                LOG (
                       'Error Encountered @XXD_MSC_ONT_ATP_LEVEL_PKG.PROC_UPDATE_LATEST_ACCPBL_DATE '
                    || SQLERRM);
                XXD_UPDATE_ERROR_LOG (pn_session_id, 1111, 'proc_update_latest_accpbl_date_3'
                                      , SQLERRM);
        END;
    END proc_update_latest_accpbl_date;


    --------------------------------------------------------------------------------------
    -- End Changes by BT Technology on 06 Nov 15


    PROCEDURE proc_cancel_order_lines (
        x_errbuf             OUT NOCOPY VARCHAR2,
        x_retcode            OUT NOCOPY NUMBER,
        pn_session_id                   NUMBER,
        pn_user_id                      NUMBER,
        pn_resp_id                      NUMBER,
        pn_resp_appl_id                 NUMBER,
        pn_org_id                       NUMBER,
        x_msg_data           OUT        VARCHAR2)
    AS
        v_api_version_number           NUMBER := 1;
        v_return_status                VARCHAR2 (2000);
        v_msg_count                    NUMBER;
        v_msg_data                     VARCHAR2 (2000);

        -- IN Variables --
        v_header_rec                   oe_order_pub.header_rec_type;
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
        ln_user_id                     NUMBER;
        ln_resp_id                     NUMBER;
        ln_resp_appl_id                NUMBER;
        ln_org_id                      NUMBER;
        ln_success_count               NUMBER := 0;
        ln_error_count                 NUMBER := 0;
        vmsgdata                       VARCHAR2 (20000);
        lc_msg                         VARCHAR2 (20000);
        LC_NEXT_MSG                    VARCHAR2 (2000);

        CURSOR cur_cancel_sel_oe_hdr IS
              SELECT DISTINCT order_header_id
                FROM xxd_mrp_atp_schedule_temp
               WHERE     session_id = pn_session_id
                     AND atp_level_type = 1                       --for cancel
                     AND status_flag = 1
            ORDER BY order_header_id;


        CURSOR cur_update_sel_oe_hdr IS
              SELECT DISTINCT order_header_id
                FROM xxd_mrp_atp_schedule_temp
               WHERE     session_id = pn_session_id
                     AND atp_level_type = 4                       --for update
                     AND status_flag = 1
            ORDER BY order_header_id;
    BEGIN
        --v_line_tbl                     := oe_order_pub.g_miss_line_rec;

        --log ('Total record count for cancellation'||xxd_v_line_tbl.count);
        xxd_v_cancel_line_tbl.delete;
        xxd_v_update_line_tbl.delete;

        FOR rec_cancel_sel_oe_hdr IN cur_cancel_sel_oe_hdr
        LOOP
            xxd_v_cancel_line_tbl.delete;

              SELECT order_header_id, order_line_id, quantity_ordered,
                     'Y', 'ADM-0080'
                BULK COLLECT INTO xxd_v_cancel_line_tbl
                FROM xxd_mrp_atp_schedule_temp
               WHERE     session_id = pn_session_id
                     AND order_header_id =
                         rec_cancel_sel_oe_hdr.order_header_id
                     AND atp_level_type IN (1, 4)      --for cancel and update
                     AND status_flag = 1
            ORDER BY order_header_id;



            LOG (
                   'Total record count for cancellation'
                || xxd_v_cancel_line_tbl.COUNT);

            ln_user_id        := pn_user_id;   --fnd_profile.value('USER_ID');
            ln_resp_id        := pn_resp_id;   --fnd_profile.value('RESP_ID');
            ln_resp_appl_id   := pn_resp_appl_id; --fnd_profile.value('RESP_APPL_ID');
            ln_org_id         := pn_org_id;



            -- Start modification by BT Technology Team on 08-Dec-15
            BEGIN
                ln_org_id   := NULL;

                SELECT org_id
                  INTO ln_org_id
                  FROM oe_order_headers_all
                 WHERE header_id = rec_cancel_sel_oe_hdr.order_header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_org_id   := pn_org_id;
            END;

            --Start changes on BT Technology Team on 18 Dec 15
            --ln_org_id := NULL;
            --ln_org_id := get_org_id(rec_cancel_sel_oe_hdr.order_header_id);
            --End changes on BT Technology Team on 18 Dec 15


            fnd_global.apps_initialize (user_id        => ln_user_id,
                                        resp_id        => ln_resp_id,
                                        resp_appl_id   => ln_resp_appl_id);
            mo_global.init ('ONT');
            mo_global.set_policy_context ('S', ln_org_id);
            oe_msg_pub.initialize;
            oe_debug_pub.initialize;

            v_line_tbl.delete;
            v_action_request_tbl.delete;

            FOR i IN 1 .. xxd_v_cancel_line_tbl.COUNT
            LOOP
                v_action_request_tbl (i)          := oe_order_pub.g_miss_request_rec;

                -- Cancel a Line Record --
                v_line_tbl (i)                    := oe_order_pub.g_miss_line_rec;
                v_line_tbl (i).operation          := OE_GLOBALS.G_OPR_UPDATE;
                v_line_tbl (i).header_id          :=
                    xxd_v_cancel_line_tbl (i).header_id;
                v_line_tbl (i).line_id            :=
                    xxd_v_cancel_line_tbl (i).line_id;
                v_line_tbl (i).ordered_quantity   :=
                    xxd_v_cancel_line_tbl (i).ordered_quantity;
                v_line_tbl (i).cancelled_flag     :=
                    xxd_v_cancel_line_tbl (i).cancelled_flag;
                v_line_tbl (i).change_reason      :=
                    xxd_v_cancel_line_tbl (i).change_reason;
                v_line_tbl (i).org_id             := ln_org_id;
            END LOOP;



            LOG ('Starting of API');

            -- Calling the API to cancel a line from an Existing Order --

            OE_ORDER_PUB.PROCESS_ORDER (
                -- Start modification by BT Technology Team on 18-Dec-15
                p_org_id                   => ln_org_id,
                -- End modification by BT Technology Team on 18-Dec-15
                p_api_version_number       => v_api_version_number,
                p_header_rec               => v_header_rec,
                p_line_tbl                 => v_line_tbl,
                p_action_request_tbl       => v_action_request_tbl,
                p_line_adj_tbl             => v_line_adj_tbl  -- OUT variables
                                                            ,
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

            -- x_msg_data := v_msg_data;

            LOG ('Completion of API');


            IF v_return_status = fnd_api.g_ret_sts_success
            THEN
                COMMIT;
                ln_success_count   := ln_success_count + 1;
                x_retcode          := 1;
                LOG ('Line Cancelation in Existing Order is Success ');
            --x_msg_data := 'Line Cancelation in Existing Order is Success ';
            ELSE
                ln_error_count   := ln_error_count + 1;
                LOG (
                       'Line Cancelation in Existing Order failed:'
                    || v_msg_data);
                -- x_msg_data :=
                -- 'Line Cancelation in Existing Order Order failed '
                --|| v_msg_data;
                ROLLBACK;
                x_retcode        := 2;

                FOR i IN 1 .. v_msg_count
                LOOP
                    v_msg_data   :=
                        oe_msg_pub.get (p_msg_index => i, p_encoded => 'F');
                    LOG (i || ') ' || v_msg_data);
                END LOOP;


                -- Start of ExceptionHandling 09Dec15
                XXD_UPDATE_ERROR_LOG (pn_session_id, rec_cancel_sel_oe_hdr.order_header_id, 'proc_cancel_order_lines1'
                                      , v_msg_data);

                -- End of Exception Handling 09Dec15
                lc_msg           := NULL;

                FOR i IN 1 .. v_msg_count
                LOOP
                    oe_msg_pub.get (p_msg_index => i, p_encoded => FND_API.G_FALSE, p_data => lc_msg
                                    , p_msg_index_out => LC_NEXT_MSG);
                    v_msg_data   := v_msg_data || lc_msg;
                END LOOP;

                LOG (v_msg_data);

                -- Start of ExceptionHandling 10Dec15
                XXD_UPDATE_ERROR_LOG (pn_session_id, rec_cancel_sel_oe_hdr.order_header_id, 'proc_cancel_order_lines1'
                                      , v_msg_data);
            -- End of Exception Handling 10Dec15
            END IF;
        END LOOP;

        IF xxd_v_cancel_line_tbl.COUNT <> 0
        THEN
            vmsgdata   :=
                   'Total No of records that are successfully cancelled - '
                || ln_success_count
                || '     Total No. of records went into Error while cancelling - '
                || ln_error_count;
        END IF;

        ln_success_count   := 0;
        ln_error_count     := 0;

        --partial cancellation

        FOR rec_update_sel_oe_hdr IN cur_update_sel_oe_hdr
        LOOP
            xxd_v_update_line_tbl.delete;

              SELECT order_header_id, order_line_id, quantity_ordered,
                     --'Y',
                     'ADM-0080'
                BULK COLLECT INTO xxd_v_update_line_tbl
                FROM xxd_mrp_atp_schedule_temp
               WHERE     session_id = pn_session_id
                     AND order_header_id =
                         rec_update_sel_oe_hdr.order_header_id
                     AND atp_level_type IN (1, 4)      --for cancel and update
                     AND status_flag = 1
            ORDER BY order_header_id;


            LOG (
                'Total record count for update' || xxd_v_update_line_tbl.COUNT);

            ln_user_id        := pn_user_id;   --fnd_profile.value('USER_ID');
            ln_resp_id        := pn_resp_id;   --fnd_profile.value('RESP_ID');
            ln_resp_appl_id   := pn_resp_appl_id; --fnd_profile.value('RESP_APPL_ID');
            ln_org_id         := pn_org_id;

            --Start changes on BT Technology Team on 18 Dec 15
            BEGIN
                ln_org_id   := NULL;

                SELECT org_id
                  INTO ln_org_id
                  FROM oe_order_headers_all
                 WHERE header_id = rec_update_sel_oe_hdr.order_header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_org_id   := pn_org_id;
            END;

            --End changes on BT Technology Team on 18 Dec 15

            fnd_global.apps_initialize (user_id        => ln_user_id,
                                        resp_id        => ln_resp_id,
                                        resp_appl_id   => ln_resp_appl_id);
            mo_global.init ('ONT');
            mo_global.set_policy_context ('S', ln_org_id);
            oe_msg_pub.initialize;
            oe_debug_pub.initialize;


            v_line_tbl.delete;
            v_action_request_tbl.delete;

            FOR i IN 1 .. xxd_v_update_line_tbl.COUNT
            LOOP
                v_action_request_tbl (i)          := oe_order_pub.g_miss_request_rec;

                -- Cancel a Line Record --
                v_line_tbl (i)                    := oe_order_pub.g_miss_line_rec;
                v_line_tbl (i).operation          := OE_GLOBALS.G_OPR_UPDATE;
                v_line_tbl (i).header_id          :=
                    xxd_v_update_line_tbl (i).header_id;
                v_line_tbl (i).line_id            :=
                    xxd_v_update_line_tbl (i).line_id;
                v_line_tbl (i).ordered_quantity   :=
                    xxd_v_update_line_tbl (i).ordered_quantity;
                --            v_line_tbl (i).cancelled_flag :=
                --               xxd_v_update_line_tbl (i).cancelled_flag;
                v_line_tbl (i).change_reason      :=
                    xxd_v_update_line_tbl (i).change_reason;
                v_line_tbl (i).org_id             := ln_org_id;
            END LOOP;



            LOG ('Starting of API');

            -- Calling the API to cancel a line from an Existing Order --

            OE_ORDER_PUB.PROCESS_ORDER (
                -- Start modification by BT Technology Team on 18-Dec-15
                p_org_id                   => ln_org_id,
                -- End modification by BT Technology Team on 18-Dec-15
                p_api_version_number       => v_api_version_number,
                p_header_rec               => v_header_rec,
                p_line_tbl                 => v_line_tbl,
                p_action_request_tbl       => v_action_request_tbl,
                p_line_adj_tbl             => v_line_adj_tbl  -- OUT variables
                                                            ,
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

            -- x_msg_data := v_msg_data;

            LOG ('Completion of API');


            IF v_return_status = fnd_api.g_ret_sts_success
            THEN
                COMMIT;
                ln_success_count   := ln_success_count + 1;
                x_retcode          := 1;
                LOG ('Line updation in Existing Order is Success ');
            --x_msg_data := 'Line updation in Existing Order is Success ';
            ELSE
                ln_error_count   := ln_error_count + 1;
                LOG ('Line updation in Existing Order failed:' || v_msg_data);
                --x_msg_data :=
                --  'Line updation in Existing Order Order failed ' || v_msg_data;
                ROLLBACK;
                x_retcode        := 2;

                FOR i IN 1 .. v_msg_count
                LOOP
                    v_msg_data   :=
                        oe_msg_pub.get (p_msg_index => i, p_encoded => 'F');
                    LOG (i || ') ' || v_msg_data);
                END LOOP;

                -- Start of ExceptionHandling 09Dec15
                XXD_UPDATE_ERROR_LOG (pn_session_id, rec_update_sel_oe_hdr.order_header_id, 'proc_cancel_order_lines2'
                                      , v_msg_data);

                -- End of Exception Handling 09Dec15
                lc_msg           := NULL;

                FOR i IN 1 .. v_msg_count
                LOOP
                    oe_msg_pub.get (p_msg_index => i, p_encoded => FND_API.G_FALSE, p_data => lc_msg
                                    , p_msg_index_out => LC_NEXT_MSG);
                    v_msg_data   := v_msg_data || lc_msg;
                END LOOP;

                LOG (v_msg_data);

                -- Start of ExceptionHandling 10Dec15
                XXD_UPDATE_ERROR_LOG (pn_session_id, rec_update_sel_oe_hdr.order_header_id, 'proc_cancel_order_lines2'
                                      , v_msg_data);
            -- End of Exception Handling 10Dec15

            END IF;
        END LOOP;

        IF xxd_v_update_line_tbl.COUNT <> 0
        THEN
            vmsgdata   :=
                   vmsgdata
                || '      Total No of records that are successfully Updated - '
                || ln_success_count
                || '     Total No. of records went into Error while Updating - '
                || ln_error_count;
        END IF;

        x_msg_data         := vmsgdata;
        x_errbuf           := vmsgdata;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_retcode   := 2;
            LOG (
                   'Error Encountered @XXD_MSC_ONT_ATP_LEVEL_PKG.PROC_CANCEL_OE_LINES '
                || SQLERRM);
    END PROC_CANCEL_Order_LINES;

    --------------------------------------------------------------------------------------


    PROCEDURE proc_unschedule_order_lines (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, pn_session_id NUMBER, pn_user_id NUMBER, pn_resp_id NUMBER, pn_resp_appl_id NUMBER
                                           , pn_org_id NUMBER, x_msg_data OUT VARCHAR2, x_err_msg OUT VARCHAR2)
    IS
        v_order_header_rec          oe_order_pub.header_rec_type;
        v_order_hdr_slcrtab         oe_order_pub.header_scredit_tbl_type;
        v_order_line_tab            oe_order_pub.line_tbl_type;
        v_order_header_val_rec      oe_order_pub.header_val_rec_type;
        v_order_header_adj_tbl      oe_order_pub.header_adj_tbl_type;
        v_order_hdr_adj_val_tbl     oe_order_pub.header_adj_val_tbl_type;
        v_order_hdr_pri_att_tbl     oe_order_pub.header_price_att_tbl_type;
        v_order_hdr_adj_att_tbl     oe_order_pub.header_adj_att_tbl_type;
        v_order_hdr_adj_asc_tbl     oe_order_pub.header_adj_assoc_tbl_type;
        v_order_hdr_scr_val_tbl     oe_order_pub.header_scredit_val_tbl_type;
        v_order_line_val_tbl        oe_order_pub.line_val_tbl_type;
        v_order_line_adj_tbl        oe_order_pub.line_adj_tbl_type;
        v_order_line_adj_val_tbl    oe_order_pub.line_adj_val_tbl_type;
        v_order_line_pri_att_tbl    oe_order_pub.line_price_att_tbl_type;
        v_order_line_adj_att_tbl    oe_order_pub.line_adj_att_tbl_type;
        v_order_line_adj_asc_tbl    oe_order_pub.line_adj_assoc_tbl_type;
        v_order_line_scredit_tbl    oe_order_pub.line_scredit_tbl_type;
        v_order_line_scr_val_tbl    oe_order_pub.line_scredit_val_tbl_type;
        v_order_lot_serial_tbl      oe_order_pub.lot_serial_tbl_type;
        v_order_lot_serl_val_tbl    oe_order_pub.lot_serial_val_tbl_type;
        v_order_request_tbl         oe_order_pub.request_tbl_type;
        lr_order_header_rec         oe_order_pub.header_rec_type;
        lr_order_hdr_slcrtab        oe_order_pub.header_scredit_tbl_type;
        lr_order_line_tab           oe_order_pub.line_tbl_type;
        lr_order_line_tab1          oe_order_pub.line_tbl_type;
        lr_line_rec_type            oe_order_pub.line_rec_type;
        lr_order_header_val_rec     oe_order_pub.header_val_rec_type;
        lr_order_header_adj_tbl     oe_order_pub.header_adj_tbl_type;
        lr_order_hdr_adj_val_tbl    oe_order_pub.header_adj_val_tbl_type;
        lr_order_hdr_pri_att_tbl    oe_order_pub.header_price_att_tbl_type;
        lr_order_hdr_adj_att_tbl    oe_order_pub.header_adj_att_tbl_type;
        lr_order_hdr_adj_asc_tbl    oe_order_pub.header_adj_assoc_tbl_type;
        lr_order_hdr_scr_val_tbl    oe_order_pub.header_scredit_val_tbl_type;
        lr_order_line_val_tbl       oe_order_pub.line_val_tbl_type;
        lr_order_line_adj_tbl       oe_order_pub.line_adj_tbl_type;
        lr_order_line_adj_val_tbl   oe_order_pub.line_adj_val_tbl_type;
        lr_order_line_pri_att_tbl   oe_order_pub.line_price_att_tbl_type;
        lr_order_line_adj_att_tbl   oe_order_pub.line_adj_att_tbl_type;
        lr_order_line_adj_asc_tbl   oe_order_pub.line_adj_assoc_tbl_type;
        lr_order_line_scredit_tbl   oe_order_pub.line_scredit_tbl_type;
        lr_order_line_scr_val_tbl   oe_order_pub.line_scredit_val_tbl_type;
        lr_order_lot_serial_tbl     oe_order_pub.lot_serial_tbl_type;
        lr_order_lot_serl_val_tbl   oe_order_pub.lot_serial_val_tbl_type;
        lr_order_request_tbl        oe_order_pub.request_tbl_type;
        vreturnstatus               VARCHAR2 (30);
        vmsgcount                   NUMBER;
        vmsgdata                    VARCHAR2 (5000);
        l_count                     NUMBER;
        i                           NUMBER;
        ln_user_id                  NUMBER;
        ln_resp_id                  NUMBER;
        ln_resp_appl_id             NUMBER;
        ln_org_id                   NUMBER;
        ln_success_count            NUMBER;
        ln_error_count              NUMBER;
        v_msg_data                  VARCHAR2 (7000);
        lc_msg                      VARCHAR2 (2000);
        LC_NEXT_MSG                 VARCHAR2 (2000);

        CURSOR cur_sel_oe_hdr IS
              SELECT DISTINCT order_header_id
                FROM xxd_mrp_atp_schedule_temp
               WHERE     session_id = pn_session_id
                     AND atp_level_type = 3                       --unschedule
                     AND status_flag = 1
            ORDER BY order_header_id;
    BEGIN
        LOG (
            'Total record count for Unscheduling' || xxd_v_cancel_line_tbl.COUNT);

        ln_user_id         := pn_user_id;      --fnd_profile.value('USER_ID');
        ln_resp_id         := pn_resp_id;      --fnd_profile.value('RESP_ID');
        ln_resp_appl_id    := pn_resp_appl_id; --fnd_profile.value('RESP_APPL_ID');
        ln_org_id          := pn_org_id;



        vreturnstatus      := NULL;
        vmsgcount          := 0;
        vmsgdata           := NULL;
        ln_success_count   := 0;
        ln_error_count     := 0;

        FOR rec_sel_oe_hdr IN cur_sel_oe_hdr
        LOOP
            xxd_v_unschdl_line_tbl.delete;

            SELECT order_header_id, order_line_id, scheduled_ship_date,
                   requested_ship_date, 'UNSCHEDULE' schedule_type
              BULK COLLECT INTO xxd_v_unschdl_line_tbl
              FROM xxd_mrp_atp_schedule_temp
             WHERE     session_id = pn_session_id
                   AND order_header_id = rec_sel_oe_hdr.order_header_id
                   AND atp_level_type = 3                     --for unschedule
                   AND status_flag = 1;

            --Start changes on BT Technology Team on 18 Dec 15
            BEGIN
                ln_org_id   := NULL;

                SELECT org_id
                  INTO ln_org_id
                  FROM oe_order_headers_all
                 WHERE header_id = rec_sel_oe_hdr.order_header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_org_id   := pn_org_id;
            END;

            --End changes on BT Technology Team on 18 Dec 15

            v_order_line_tab.delete;

            --Start changes on BT Technology Team on 18 Dec 15
            --ln_org_id := NULL;
            --ln_org_id := get_org_id(rec_sel_oe_hdr.order_header_id);
            --End changes on BT Technology Team on 18 Dec 15

            fnd_global.apps_initialize (user_id        => ln_user_id,
                                        resp_id        => ln_resp_id,
                                        resp_appl_id   => ln_resp_appl_id);
            mo_global.init ('ONT');
            mo_global.set_policy_context ('S', ln_org_id);
            oe_msg_pub.initialize;
            oe_debug_pub.initialize;

            FOR i IN 1 .. xxd_v_unschdl_line_tbl.COUNT
            LOOP
                v_order_line_tab (i)                        :=
                    oe_line_util.query_row (
                        xxd_v_unschdl_line_tbl (i).line_id);
                v_order_line_tab (i).operation              := oe_globals.g_opr_update;
                v_order_line_tab (i).line_id                :=
                    xxd_v_unschdl_line_tbl (i).line_id;
                --v_order_line_tab (i).request_date := p_scheddate;
                v_order_line_tab (i).request_date           :=
                    xxd_v_unschdl_line_tbl (i).requested_ship_date;
                --v_order_line_tab (i).schedule_action_code := 'SCHEDULE';
                v_order_line_tab (i).schedule_action_code   :=
                    xxd_v_unschdl_line_tbl (i).schedule_type;
                v_order_line_tab (i).org_id                 := ln_org_id;
            END LOOP;

            IF v_order_line_tab.COUNT > 0
            THEN
                oe_order_pub.process_order (
                    -- Start modification by BT Technology Team on 18-Dec-15
                    p_org_id                   => ln_org_id,
                    -- End modification by BT Technology Team on 18-Dec-15
                    p_api_version_number       => 1.0,
                    --p_org_id                   => ln_org_id,
                    p_init_msg_list            => fnd_api.g_true,
                    p_return_values            => fnd_api.g_true,
                    p_action_commit            => fnd_api.g_true,
                    p_header_rec               => v_order_header_rec,
                    p_header_val_rec           => v_order_header_val_rec,
                    p_header_scredit_tbl       => v_order_hdr_slcrtab,
                    p_line_tbl                 => v_order_line_tab,
                    p_line_price_att_tbl       => v_order_line_pri_att_tbl,
                    p_action_request_tbl       => v_order_request_tbl,
                    x_return_status            => vreturnstatus,
                    x_msg_count                => vmsgcount,
                    x_msg_data                 => v_msg_data,
                    x_header_rec               => lr_order_header_rec,
                    x_header_val_rec           => lr_order_header_val_rec,
                    x_header_adj_tbl           => lr_order_header_adj_tbl,
                    x_header_adj_val_tbl       => lr_order_hdr_adj_val_tbl,
                    x_header_price_att_tbl     => lr_order_hdr_pri_att_tbl,
                    x_header_adj_att_tbl       => lr_order_hdr_adj_att_tbl,
                    x_header_adj_assoc_tbl     => lr_order_hdr_adj_asc_tbl,
                    x_header_scredit_tbl       => lr_order_hdr_slcrtab,
                    x_header_scredit_val_tbl   => lr_order_hdr_scr_val_tbl,
                    x_line_tbl                 => lr_order_line_tab,
                    x_line_val_tbl             => lr_order_line_val_tbl,
                    x_line_adj_tbl             => lr_order_line_adj_tbl,
                    x_line_adj_val_tbl         => lr_order_line_adj_val_tbl,
                    x_line_price_att_tbl       => lr_order_line_pri_att_tbl,
                    x_line_adj_att_tbl         => lr_order_line_adj_att_tbl,
                    x_line_adj_assoc_tbl       => lr_order_line_adj_asc_tbl,
                    x_line_scredit_tbl         => lr_order_line_scredit_tbl,
                    x_line_scredit_val_tbl     => lr_order_line_scr_val_tbl,
                    x_lot_serial_tbl           => lr_order_lot_serial_tbl,
                    x_lot_serial_val_tbl       => lr_order_lot_serl_val_tbl,
                    x_action_request_tbl       => lr_order_request_tbl);
                LOG ('Completion of API');

                IF vreturnstatus = fnd_api.g_ret_sts_success
                THEN
                    --x_err_msg := 'Unscheduling lines are successful.';
                    ln_success_count   := ln_success_count + 1;
                    x_retcode          := 1;
                    --x_err_code := 'S';
                    COMMIT;
                ELSE
                    ROLLBACK;
                    -- x_err_code := 'E';
                    ln_error_count   := ln_error_count + 1;
                    x_retcode        := 2;
                    --x_err_msg := 'Error while unscheduling line - ';


                    --               FOR j IN 1 .. vmsgcount
                    --               LOOP
                    --                  v_msg_data :=
                    --                     oe_msg_pub.get (p_msg_index => j, p_encoded => 'F');
                    --                  x_err_msg := x_err_msg || v_msg_data;
                    --               END LOOP;


                    -- Start of ExceptionHandling 09Dec15
                    XXD_UPDATE_ERROR_LOG (pn_session_id, rec_sel_oe_hdr.order_header_id, 'proc_unschedule_order_lines'
                                          , v_msg_data);

                    -- End of Exception Handling 09Dec15

                    FOR i IN 1 .. vmsgcount
                    LOOP
                        lc_msg       := NULL;
                        oe_msg_pub.get (p_msg_index => i, p_encoded => FND_API.G_FALSE, p_data => lc_msg
                                        , p_msg_index_out => LC_NEXT_MSG);
                        v_msg_data   := v_msg_data || lc_msg;
                    END LOOP;

                    LOG (v_msg_data);

                    -- Start of ExceptionHandling 10Dec15
                    XXD_UPDATE_ERROR_LOG (pn_session_id, rec_sel_oe_hdr.order_header_id, 'proc_unschedule_order_lines'
                                          , v_msg_data);
                -- End of Exception Handling 10Dec15

                END IF;
            ELSE
                x_err_msg   :=
                    'There are no eligible order lines to unschedule.';
            END IF;
        END LOOP;

        IF xxd_v_unschdl_line_tbl.COUNT <> 0
        THEN
            vmsgdata   :=
                   'Total No of records that are successfully Unscheduled - '
                || ln_success_count
                || '     Total No. of records went into Error while Unscheduling - '
                || ln_error_count;
        END IF;

        x_msg_data         := vmsgdata;
        x_errbuf           := vmsgdata;
        x_err_msg          := vmsgdata;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_retcode   := 1;
            --x_err_code := 'E';
            x_err_msg   := SQLERRM;
            LOG ('Exception in scheduling the orders' || x_err_msg);
    END proc_unschedule_order_lines;

    --Added this logic on 15 Dec 2015 after inclusive of Override ATP Logic
    PROCEDURE PROC_DELETE_SPLIT_LINES (pn_session_id NUMBER)
    IS
        vmsgdata   VARCHAR2 (4000);
    BEGIN
        DELETE FROM
            mrp_atp_schedule_temp
              WHERE     session_id = pn_session_id
                    AND NVL (exception12, 99999) IN (6, 7, 8)
                    AND exception9 IS NOT NULL;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            vmsgdata   :=
                'Error while deleting the duplicate records' || SQLERRM;
            XXD_UPDATE_ERROR_LOG (pn_session_id, 22222, 'PROC_DELETE_SPLIT_LINES'
                                  , vmsgdata);
    END;

    --End of this logic on 15 Dec 2015 after inclusive of Override ATP Logic

    --Procedure to unschedule the split lines --Added by BT Technology Team on 15 Dec 15

    PROCEDURE proc_unschedule_split_oe_lines (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, pn_session_id NUMBER, pn_user_id NUMBER, pn_resp_id NUMBER, pn_resp_appl_id NUMBER
                                              , pn_org_id NUMBER, x_msg_data OUT VARCHAR2, x_err_msg OUT VARCHAR2)
    IS
        v_order_header_rec             oe_order_pub.header_rec_type;
        v_order_hdr_slcrtab            oe_order_pub.header_scredit_tbl_type;
        v_order_line_tab               oe_order_pub.line_tbl_type;
        v_order_header_val_rec         oe_order_pub.header_val_rec_type;
        v_order_header_adj_tbl         oe_order_pub.header_adj_tbl_type;
        v_order_hdr_adj_val_tbl        oe_order_pub.header_adj_val_tbl_type;
        v_order_hdr_pri_att_tbl        oe_order_pub.header_price_att_tbl_type;
        v_order_hdr_adj_att_tbl        oe_order_pub.header_adj_att_tbl_type;
        v_order_hdr_adj_asc_tbl        oe_order_pub.header_adj_assoc_tbl_type;
        v_order_hdr_scr_val_tbl        oe_order_pub.header_scredit_val_tbl_type;
        v_order_line_val_tbl           oe_order_pub.line_val_tbl_type;
        v_order_line_adj_tbl           oe_order_pub.line_adj_tbl_type;
        v_order_line_adj_val_tbl       oe_order_pub.line_adj_val_tbl_type;
        v_order_line_pri_att_tbl       oe_order_pub.line_price_att_tbl_type;
        v_order_line_adj_att_tbl       oe_order_pub.line_adj_att_tbl_type;
        v_order_line_adj_asc_tbl       oe_order_pub.line_adj_assoc_tbl_type;
        v_order_line_scredit_tbl       oe_order_pub.line_scredit_tbl_type;
        v_order_line_scr_val_tbl       oe_order_pub.line_scredit_val_tbl_type;
        v_order_lot_serial_tbl         oe_order_pub.lot_serial_tbl_type;
        v_order_lot_serl_val_tbl       oe_order_pub.lot_serial_val_tbl_type;
        v_order_request_tbl            oe_order_pub.request_tbl_type;
        lr_order_header_rec            oe_order_pub.header_rec_type;
        lr_order_hdr_slcrtab           oe_order_pub.header_scredit_tbl_type;
        lr_order_line_tab              oe_order_pub.line_tbl_type;
        lr_order_line_tab1             oe_order_pub.line_tbl_type;
        lr_line_rec_type               oe_order_pub.line_rec_type;
        lr_order_header_val_rec        oe_order_pub.header_val_rec_type;
        lr_order_header_adj_tbl        oe_order_pub.header_adj_tbl_type;
        lr_order_hdr_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type;
        lr_order_hdr_pri_att_tbl       oe_order_pub.header_price_att_tbl_type;
        lr_order_hdr_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type;
        lr_order_hdr_adj_asc_tbl       oe_order_pub.header_adj_assoc_tbl_type;
        lr_order_hdr_scr_val_tbl       oe_order_pub.header_scredit_val_tbl_type;
        lr_order_line_val_tbl          oe_order_pub.line_val_tbl_type;
        lr_order_line_adj_tbl          oe_order_pub.line_adj_tbl_type;
        lr_order_line_adj_val_tbl      oe_order_pub.line_adj_val_tbl_type;
        lr_order_line_pri_att_tbl      oe_order_pub.line_price_att_tbl_type;
        lr_order_line_adj_att_tbl      oe_order_pub.line_adj_att_tbl_type;
        lr_order_line_adj_asc_tbl      oe_order_pub.line_adj_assoc_tbl_type;
        lr_order_line_scredit_tbl      oe_order_pub.line_scredit_tbl_type;
        lr_order_line_scr_val_tbl      oe_order_pub.line_scredit_val_tbl_type;
        lr_order_lot_serial_tbl        oe_order_pub.lot_serial_tbl_type;
        lr_order_lot_serl_val_tbl      oe_order_pub.lot_serial_val_tbl_type;
        lr_order_request_tbl           oe_order_pub.request_tbl_type;
        vreturnstatus                  VARCHAR2 (30);
        vmsgcount                      NUMBER;
        vmsgdata                       VARCHAR2 (5000);
        l_count                        NUMBER;
        i                              NUMBER;
        ln_user_id                     NUMBER;
        ln_resp_id                     NUMBER;
        ln_resp_appl_id                NUMBER;
        ln_org_id                      NUMBER;
        ln_success_cnt                 NUMBER := 0;
        ln_error_cnt                   NUMBER := 0;

        -- for cancellation
        v_api_version_number           NUMBER := 1;
        v_return_status                VARCHAR2 (2000);
        v_msg_count                    NUMBER;
        v_msg_data                     VARCHAR2 (5000);

        -- IN Variables --
        v_header_rec                   oe_order_pub.header_rec_type;
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
        lc_msg                         VARCHAR2 (2000);
        LC_NEXT_MSG                    VARCHAR2 (2000);

        CURSOR cur_unschdl_sel_oe_hdr IS
              SELECT DISTINCT order_header_id
                FROM xxd_mrp_atp_schedule_temp
               WHERE     session_id = pn_session_id
                     AND atp_level_type = 6                            --Split
                     AND status_flag = 1
            ORDER BY order_header_id;
    BEGIN
        --      LOG (
        --         'Total record count for Unscheduling' || xxd_v_cancel_line_tbl.COUNT);

        ln_user_id        := pn_user_id;       --fnd_profile.value('USER_ID');
        ln_resp_id        := pn_resp_id;       --fnd_profile.value('RESP_ID');
        ln_resp_appl_id   := pn_resp_appl_id; --fnd_profile.value('RESP_APPL_ID');
        ln_org_id         := pn_org_id;

        --      fnd_global.apps_initialize (user_id        => ln_user_id,
        --                                  resp_id        => ln_resp_id,
        --                                  resp_appl_id   => ln_resp_appl_id);
        --      mo_global.init ('ONT');
        --      mo_global.set_policy_context ('S', ln_org_id);
        --      oe_msg_pub.initialize;
        --      oe_debug_pub.initialize;
        vreturnstatus     := NULL;
        vmsgcount         := 0;
        vmsgdata          := NULL;
        xxd_v_cancel_line_tbl.delete;
        xxd_v_unschdl_line_tbl.delete;
        ln_success_cnt    := 0;
        ln_error_cnt      := 0;



        FOR rec_unschdl_sel_oe_hdr IN cur_unschdl_sel_oe_hdr
        LOOP
            -- for unschedule
            xxd_v_unschdl_line_tbl.delete;

            SELECT header_id, line_id, schedule_ship_date,
                   REQUEST_DATE, 'UNSCHEDULE' schedule_type
              BULK COLLECT INTO xxd_v_unschdl_line_tbl
              FROM OE_ORDER_LINES_ALL ool
             WHERE     split_from_line_id IS NOT NULL
                   AND EXISTS
                           (SELECT 1
                              FROM xxd_mrp_atp_schedule_temp mast
                             WHERE     atp_level_type = 6             -- Split
                                   AND header_id =
                                       rec_unschdl_sel_oe_hdr.order_header_id
                                   AND mast.session_id = pn_session_id
                                   AND mast.order_line_id =
                                       ool.split_from_line_id
                                   AND mast.ORIG_OE_LINE_REF IS NOT NULL)
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxd_mrp_atp_schedule_temp mast
                             WHERE     mast.session_id = pn_session_id --                     and mast.order_line_id = ool.split_from_line_id
                                   AND mast.order_line_id = ool.line_id);


            --Start changes on BT Technology Team on 18 Dec 15
            BEGIN
                ln_org_id   := NULL;

                SELECT org_id
                  INTO ln_org_id
                  FROM oe_order_headers_all
                 WHERE header_id = rec_unschdl_sel_oe_hdr.order_header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_org_id   := pn_org_id;
            END;

            --End changes on BT Technology Team on 18 Dec 15

            fnd_global.apps_initialize (user_id        => ln_user_id,
                                        resp_id        => ln_resp_id,
                                        resp_appl_id   => ln_resp_appl_id);
            mo_global.init ('ONT');
            mo_global.set_policy_context ('S', ln_org_id);
            oe_msg_pub.initialize;
            oe_debug_pub.initialize;

            -- unschedule
            v_order_line_tab.delete;

            FOR i IN 1 .. xxd_v_unschdl_line_tbl.COUNT
            LOOP
                v_order_line_tab (i)                        :=
                    oe_line_util.query_row (
                        xxd_v_unschdl_line_tbl (i).line_id);
                v_order_line_tab (i).operation              := oe_globals.g_opr_update;
                v_order_line_tab (i).line_id                :=
                    xxd_v_unschdl_line_tbl (i).line_id;
                --v_order_line_tab (i).request_date := p_scheddate;
                v_order_line_tab (i).request_date           :=
                    xxd_v_unschdl_line_tbl (i).requested_ship_date;
                --v_order_line_tab (i).schedule_action_code := 'SCHEDULE';
                v_order_line_tab (i).schedule_action_code   :=
                    xxd_v_unschdl_line_tbl (i).schedule_type;
                v_line_tbl (i).org_id                       := ln_org_id;
            END LOOP;

            --


            IF v_order_line_tab.COUNT > 0
            THEN
                oe_order_pub.process_order (
                    -- Start modification by BT Technology Team on 18-Dec-15
                    p_org_id                   => ln_org_id,
                    -- End modification by BT Technology Team on 18-Dec-15
                    p_api_version_number       => 1.0,
                    --p_org_id                   => ln_org_id,
                    p_init_msg_list            => fnd_api.g_true,
                    p_return_values            => fnd_api.g_true,
                    p_action_commit            => fnd_api.g_true,
                    p_header_rec               => v_order_header_rec,
                    p_header_val_rec           => v_order_header_val_rec,
                    p_header_scredit_tbl       => v_order_hdr_slcrtab,
                    p_line_tbl                 => v_order_line_tab,
                    p_line_price_att_tbl       => v_order_line_pri_att_tbl,
                    p_action_request_tbl       => v_order_request_tbl,
                    x_return_status            => vreturnstatus,
                    x_msg_count                => vmsgcount,
                    x_msg_data                 => vmsgdata,
                    x_header_rec               => lr_order_header_rec,
                    x_header_val_rec           => lr_order_header_val_rec,
                    x_header_adj_tbl           => lr_order_header_adj_tbl,
                    x_header_adj_val_tbl       => lr_order_hdr_adj_val_tbl,
                    x_header_price_att_tbl     => lr_order_hdr_pri_att_tbl,
                    x_header_adj_att_tbl       => lr_order_hdr_adj_att_tbl,
                    x_header_adj_assoc_tbl     => lr_order_hdr_adj_asc_tbl,
                    x_header_scredit_tbl       => lr_order_hdr_slcrtab,
                    x_header_scredit_val_tbl   => lr_order_hdr_scr_val_tbl,
                    x_line_tbl                 => lr_order_line_tab,
                    x_line_val_tbl             => lr_order_line_val_tbl,
                    x_line_adj_tbl             => lr_order_line_adj_tbl,
                    x_line_adj_val_tbl         => lr_order_line_adj_val_tbl,
                    x_line_price_att_tbl       => lr_order_line_pri_att_tbl,
                    x_line_adj_att_tbl         => lr_order_line_adj_att_tbl,
                    x_line_adj_assoc_tbl       => lr_order_line_adj_asc_tbl,
                    x_line_scredit_tbl         => lr_order_line_scredit_tbl,
                    x_line_scredit_val_tbl     => lr_order_line_scr_val_tbl,
                    x_lot_serial_tbl           => lr_order_lot_serial_tbl,
                    x_lot_serial_val_tbl       => lr_order_lot_serl_val_tbl,
                    x_action_request_tbl       => lr_order_request_tbl);
                LOG ('Completion of API');

                IF vreturnstatus = fnd_api.g_ret_sts_success
                THEN
                    --x_err_msg := 'Unscheduling lines are successful.';
                    ln_success_cnt   := ln_success_cnt + 1;
                    x_retcode        := 1;
                    --x_err_code := 'S';
                    COMMIT;
                ELSE
                    ROLLBACK;
                    -- x_err_code := 'E';
                    ln_error_cnt   := ln_error_cnt + 1;
                    x_retcode      := 2;

                    --x_err_msg := 'Error while unscheduling line - ';


                    --               FOR j IN 1 .. vmsgcount
                    --               LOOP
                    --                  vmsgdata := vmsgdata ||
                    --                     oe_msg_pub.get (p_msg_index => j, p_encoded => 'F');
                    --                  --x_err_msg := x_err_msg || vmsgdata;
                    --               END LOOP;



                    -- End of Exception Handling 09Dec15

                    FOR i IN 1 .. v_msg_count
                    LOOP
                        lc_msg       := NULL;
                        oe_msg_pub.get (p_msg_index => i, p_encoded => FND_API.G_FALSE, p_data => lc_msg
                                        , p_msg_index_out => LC_NEXT_MSG);
                        v_msg_data   := v_msg_data || lc_msg;
                    END LOOP;

                    LOG (v_msg_data);

                    -- Start of ExceptionHandling 10Dec15
                    XXD_UPDATE_ERROR_LOG (pn_session_id, rec_unschdl_sel_oe_hdr.order_header_id, 'proc_unschedule_split_oe_lines'
                                          , v_msg_data);
                -- End of Exception Handling 10Dec15

                END IF;
            ELSE
                x_retcode   := 1;
                v_msg_data   :=
                       'There are no eligible order lines to unschedule.'
                    || vmsgdata;
            END IF;

            v_msg_data   := v_msg_data || CHR (9) || vmsgdata;
        --END LOOP;
        END LOOP;

        --Added this logic on 15 Dec 2015 after inclusive of Override ATP Logic
        PROC_DELETE_SPLIT_LINES (pn_session_id);
        --END this logic on 15 Dec 2015 after inclusive of Override ATP Logic

        x_msg_data        := vmsgdata;
        x_errbuf          := vmsgdata;
        x_err_msg         := vmsgdata;
    EXCEPTION
        WHEN OTHERS
        THEN
            XXD_UPDATE_ERROR_LOG (pn_session_id, 123456, 'proc_unschedule_split_oe_lines'
                                  , SQLERRM);
            x_retcode   := 1;
            --x_err_code := 'E';
            x_err_msg   := SQLERRM;
            LOG ('Exception in scheduling the orders' || x_err_msg);
    END proc_unschedule_split_oe_lines;


    PROCEDURE proc_call_cancel_order_lines (x_errbuff OUT VARCHAR2, x_retcode OUT NUMBER, pn_session_id NUMBER, pn_user_id NUMBER, pn_resp_id NUMBER, pn_resp_appl_id NUMBER
                                            , pn_org_id NUMBER, x_msg_data OUT VARCHAR2, x_err_msg OUT VARCHAR2)
    AS
        TYPE request_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_req_id           request_table;

        ln_error_count     NUMBER := 0;
        lc_error_message   LONG;
        lc_dev_phase       VARCHAR2 (200);
        lc_dev_status      VARCHAR2 (200);
        lb_wait            BOOLEAN;
        lc_phase           VARCHAR2 (100);
        lc_message         VARCHAR2 (100);
        lc_status          VARCHAR2 (1);
        ln_request_id      NUMBER;
        ln_request_id1     NUMBER;
        ln_request_id2     NUMBER;
    BEGIN
        LOG ('Calling Process Order Cancellation ');
        ln_request_id1   :=
            apps.fnd_request.submit_request ('ONT',
                                             'XXD_OE_CANCEL_CP',
                                             '',
                                             '',
                                             FALSE,
                                             'PRINT',
                                             pn_session_id,
                                             pn_user_id,
                                             pn_resp_id,
                                             pn_resp_appl_id,
                                             pn_org_id,
                                             x_msg_data);

        LOG ('v_request_id := ' || ln_request_id1);

        IF ln_request_id1 > 0
        THEN
            l_req_id (1)   := ln_request_id1;
            COMMIT;
        ELSE
            ROLLBACK;
        END IF;


        LOG ('Calling WAIT FOR REQUEST Order Cancellation ');

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
        WHEN NO_DATA_FOUND
        THEN
            x_retcode   := 2;
            x_errbuff   := x_errbuff || SQLERRM;
            LOG (
                   'No data found error @proc_call_cancel_order_lines '
                || SQLERRM);
        WHEN OTHERS
        THEN
            x_retcode   := 2;
            x_errbuff   := x_errbuff || SQLERRM;
            LOG ('Other Error @proc_call_cancel_order_lines' || SQLERRM);
    END;



    PROCEDURE proc_call_updt_lad_order_lines (x_errbuff         OUT VARCHAR2,
                                              x_retcode         OUT NUMBER,
                                              pn_session_id         NUMBER,
                                              pn_user_id            NUMBER,
                                              pn_resp_id            NUMBER,
                                              pn_resp_appl_id       NUMBER,
                                              pn_org_id             NUMBER,
                                              x_msg_data        OUT VARCHAR2,
                                              x_err_msg         OUT VARCHAR2,
                                              x_return_status   OUT VARCHAR2,
                                              xn_request_id     OUT NUMBER)
    AS
        TYPE request_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_req_id           request_table;

        ln_error_count     NUMBER := 0;
        lc_error_message   LONG;
        lc_dev_phase       VARCHAR2 (200);
        lc_dev_status      VARCHAR2 (200);
        lb_wait            BOOLEAN;
        lc_phase           VARCHAR2 (100);
        lc_message         VARCHAR2 (100);
        lc_status          VARCHAR2 (100);
        ln_request_id      NUMBER;
        ln_request_id1     NUMBER;
        ln_request_id2     NUMBER;
        v_msg_data         VARCHAR2 (2000);
    --x_retcode          NUMBER := 0;

    BEGIN
        LOG ('Calling Process Order for Update LAD ');
        --      ln_request_id1 :=
        --         apps.fnd_request.submit_request (
        --            application   => 'XXDO',
        --            program       => 'XXD_OE_UPDATE_LAD_CP',
        --            start_time    => SYSDATE,
        --            sub_request   => NULL,
        --            --FALSE,
        --            --'PRINT',
        --            argument1     => pn_session_id,
        --            argument2     => pn_user_id,
        --            argument3     => pn_resp_id,
        --            argument4     => pn_resp_appl_id,
        --            argument5     => pn_org_id,
        ----            argument6     =>
        --            v_msg_data);

        --      LOG ('x_retcode  before apps initialize' || x_retcode);


        fnd_global.apps_initialize (user_id        => pn_user_id,
                                    resp_id        => pn_resp_id,
                                    resp_appl_id   => pn_resp_appl_id);

        --      LOG ('1');

        mo_global.init ('ONT');
        --            log('2');
        mo_global.set_policy_context ('S', pn_org_id);
        --      LOG ('3');
        oe_msg_pub.initialize;
        --      LOG ('4');
        oe_debug_pub.initialize;
        --      LOG ('5');

        --      LOG ('6');
        ln_request_id1   :=
            apps.fnd_request.submit_request ('XXDO', 'XXD_OE_UPDATE_LAD_CP', '', '', FALSE, pn_session_id, pn_user_id, pn_resp_id, pn_resp_appl_id
                                             , pn_org_id -- Start modification by BT Technology Team on 11/29/2015
                                                        --                                          ,
                                                        --                                          v_msg_data
                                                        -- End modification by BT Technology Team on 11/29/2015
                                                        );
        LOG ('v_request_id := ' || ln_request_id1);

        LOG ('x_retcode ' || x_retcode);

        IF ln_request_id1 > 0
        THEN
            l_req_id (1)   := ln_request_id1;
            --         xn_request_id := ln_request_id1;
            --x_msg_data := v_msg_data;
            COMMIT;
        --x_retcode := 0;
        ELSE
            ROLLBACK;
        --x_retcode := 1;
        --x_msg_data := 'Error while submitting the concurrent Program.';
        END IF;


        LOG ('Calling WAIT FOR REQUEST Update LAD ');
        LOG ('x_retcode ' || x_retcode);

        FOR rec IN l_req_id.FIRST .. l_req_id.LAST
        LOOP
            IF l_req_id (rec) > 0
            THEN
                LOOP
                    lc_dev_phase      := NULL;
                    lc_dev_status     := NULL;
                    lb_wait           :=
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
                    LOG (
                           lc_status
                        || '-'
                        || lc_dev_phase
                        || '-'
                        || lc_dev_status
                        || '-'
                        || lc_message);
                    x_err_msg         := lc_phase;
                    x_return_status   := lc_status;
                    xn_request_id     := ln_request_id1;

                    IF ((UPPER (lc_dev_phase) = 'COMPLETE') OR (UPPER (lc_phase) = 'COMPLETED'))
                    THEN
                        EXIT;
                    END IF;
                END LOOP;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_retcode   := 1;
            LOG (' Exception No data found x_retcode ' || x_retcode);
            x_errbuff   := x_errbuff || SQLERRM;
            LOG (
                   'No data found error @proc_call_updt_lad_order_lines '
                || SQLERRM);
            x_msg_data   :=
                'Error while calling the update LAD Program' || SQLERRM;
        WHEN OTHERS
        THEN
            x_retcode   := 1;
            LOG ('Exception Others x_retcode ' || x_retcode);
            x_errbuff   := x_errbuff || SQLERRM;
            x_msg_data   :=
                'Error while calling the update LAD Program' || SQLERRM;
            LOG ('Other Error @proc_call_updt_lad_order_lines' || SQLERRM);
    END proc_call_updt_lad_order_lines;


    PROCEDURE proc_call_unschdl_order_lines (x_errbuff OUT VARCHAR2, x_retcode OUT NUMBER, pn_session_id NUMBER, pn_user_id NUMBER, pn_resp_id NUMBER, pn_resp_appl_id NUMBER
                                             , pn_org_id NUMBER, x_msg_data OUT VARCHAR2, x_err_msg OUT VARCHAR2)
    AS
        TYPE request_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_req_id           request_table;

        ln_error_count     NUMBER := 0;
        lc_error_message   LONG;
        lc_dev_phase       VARCHAR2 (200);
        lc_dev_status      VARCHAR2 (200);
        lb_wait            BOOLEAN;
        lc_phase           VARCHAR2 (100);
        lc_message         VARCHAR2 (100);
        lc_status          VARCHAR2 (1);
        ln_request_id      NUMBER;
        ln_request_id1     NUMBER;
        ln_request_id2     NUMBER;
    BEGIN
        LOG ('Calling Process Order Cancellation ');
        ln_request_id1   :=
            apps.fnd_request.submit_request ('ONT', 'XXD_OE_UNSCHDULE_CP', '', '', FALSE, 'PRINT', pn_session_id, pn_user_id, pn_resp_id, pn_resp_appl_id, pn_org_id, x_msg_data
                                             , x_err_msg);
        LOG ('v_request_id := ' || ln_request_id1);

        IF ln_request_id1 > 0
        THEN
            l_req_id (1)   := ln_request_id1;
            COMMIT;
        ELSE
            ROLLBACK;
        END IF;


        LOG ('Calling WAIT FOR REQUEST Order Cancellation ');

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
        WHEN NO_DATA_FOUND
        THEN
            x_retcode   := 2;
            x_errbuff   := x_errbuff || SQLERRM;
            LOG (
                   'No data found error @proc_call_cancel_order_lines '
                || SQLERRM);
        WHEN OTHERS
        THEN
            x_retcode   := 2;
            x_errbuff   := x_errbuff || SQLERRM;
            LOG ('Other Error @proc_call_cancel_order_lines' || SQLERRM);
    END;



    ------------------------------------------------------------------------
    -- Added by NRK -- START of Changes
    ------------------------------------------------------------------------
    PROCEDURE proc_split_order_lines (pn_session_id NUMBER, pn_user_id NUMBER, pn_resp_id NUMBER, pn_resp_appl_id NUMBER, pn_org_id NUMBER, x_msg_data OUT VARCHAR2
                                      , x_err_msg OUT VARCHAR2)
    IS
        l_header_rec                   oe_order_pub.header_rec_type;
        l_line_tbl                     oe_order_pub.line_tbl_type;
        l_action_request_tbl           oe_order_pub.request_tbl_type;
        l_header_adj_tbl               oe_order_pub.header_adj_tbl_type;
        l_line_adj_tbl                 oe_order_pub.line_adj_tbl_type;
        l_header_scr_tbl               oe_order_pub.header_scredit_tbl_type;
        l_line_scredit_tbl             oe_order_pub.line_scredit_tbl_type;
        l_request_rec                  oe_order_pub.request_rec_type;
        l_return_status                VARCHAR2 (1000);
        l_msg_count                    NUMBER;
        l_msg_data                     VARCHAR2 (1000);
        p_api_version_number           NUMBER := 1.0;
        p_init_msg_list                VARCHAR2 (10) := fnd_api.g_false;
        p_return_values                VARCHAR2 (10) := fnd_api.g_false;
        p_action_commit                VARCHAR2 (10) := fnd_api.g_false;
        x_return_status                VARCHAR2 (1);
        x_msg_count                    NUMBER;
        p_header_rec                   oe_order_pub.header_rec_type
                                           := oe_order_pub.g_miss_header_rec;
        x_header_rec                   oe_order_pub.header_rec_type
                                           := oe_order_pub.g_miss_header_rec;
        p_old_header_rec               oe_order_pub.header_rec_type
                                           := oe_order_pub.g_miss_header_rec;
        p_header_val_rec               oe_order_pub.header_val_rec_type
                                           := oe_order_pub.g_miss_header_val_rec;
        p_old_header_val_rec           oe_order_pub.header_val_rec_type
                                           := oe_order_pub.g_miss_header_val_rec;
        p_header_adj_tbl               oe_order_pub.header_adj_tbl_type
                                           := oe_order_pub.g_miss_header_adj_tbl;
        p_old_header_adj_tbl           oe_order_pub.header_adj_tbl_type
                                           := oe_order_pub.g_miss_header_adj_tbl;
        p_header_adj_val_tbl           oe_order_pub.header_adj_val_tbl_type
                                           := oe_order_pub.g_miss_header_adj_val_tbl;
        p_old_header_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type
            := oe_order_pub.g_miss_header_adj_val_tbl;
        p_header_price_att_tbl         oe_order_pub.header_price_att_tbl_type
            := oe_order_pub.g_miss_header_price_att_tbl;
        p_old_header_price_att_tbl     oe_order_pub.header_price_att_tbl_type
            := oe_order_pub.g_miss_header_price_att_tbl;
        p_header_adj_att_tbl           oe_order_pub.header_adj_att_tbl_type
            := oe_order_pub.g_miss_header_adj_att_tbl;
        p_old_header_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type
            := oe_order_pub.g_miss_header_adj_att_tbl;
        p_header_adj_assoc_tbl         oe_order_pub.header_adj_assoc_tbl_type
            := oe_order_pub.g_miss_header_adj_assoc_tbl;
        p_old_header_adj_assoc_tbl     oe_order_pub.header_adj_assoc_tbl_type
            := oe_order_pub.g_miss_header_adj_assoc_tbl;
        p_header_scredit_tbl           oe_order_pub.header_scredit_tbl_type
            := oe_order_pub.g_miss_header_scredit_tbl;
        p_old_header_scredit_tbl       oe_order_pub.header_scredit_tbl_type
            := oe_order_pub.g_miss_header_scredit_tbl;
        p_header_scredit_val_tbl       oe_order_pub.header_scredit_val_tbl_type
            := oe_order_pub.g_miss_header_scredit_val_tbl;
        p_old_header_scredit_val_tbl   oe_order_pub.header_scredit_val_tbl_type
            := oe_order_pub.g_miss_header_scredit_val_tbl;
        x_line_tbl                     oe_order_pub.line_tbl_type
                                           := oe_order_pub.g_miss_line_tbl;
        p_old_line_tbl                 oe_order_pub.line_tbl_type
                                           := oe_order_pub.g_miss_line_tbl;
        p_line_val_tbl                 oe_order_pub.line_val_tbl_type
            := oe_order_pub.g_miss_line_val_tbl;
        p_old_line_val_tbl             oe_order_pub.line_val_tbl_type
            := oe_order_pub.g_miss_line_val_tbl;
        p_line_adj_tbl                 oe_order_pub.line_adj_tbl_type
            := oe_order_pub.g_miss_line_adj_tbl;
        p_old_line_adj_tbl             oe_order_pub.line_adj_tbl_type
            := oe_order_pub.g_miss_line_adj_tbl;
        p_line_adj_val_tbl             oe_order_pub.line_adj_val_tbl_type
            := oe_order_pub.g_miss_line_adj_val_tbl;
        p_old_line_adj_val_tbl         oe_order_pub.line_adj_val_tbl_type
            := oe_order_pub.g_miss_line_adj_val_tbl;
        p_line_price_att_tbl           oe_order_pub.line_price_att_tbl_type
            := oe_order_pub.g_miss_line_price_att_tbl;
        p_old_line_price_att_tbl       oe_order_pub.line_price_att_tbl_type
            := oe_order_pub.g_miss_line_price_att_tbl;
        p_line_adj_att_tbl             oe_order_pub.line_adj_att_tbl_type
            := oe_order_pub.g_miss_line_adj_att_tbl;
        p_old_line_adj_att_tbl         oe_order_pub.line_adj_att_tbl_type
            := oe_order_pub.g_miss_line_adj_att_tbl;
        p_line_adj_assoc_tbl           oe_order_pub.line_adj_assoc_tbl_type
            := oe_order_pub.g_miss_line_adj_assoc_tbl;
        p_old_line_adj_assoc_tbl       oe_order_pub.line_adj_assoc_tbl_type
            := oe_order_pub.g_miss_line_adj_assoc_tbl;
        p_line_scredit_tbl             oe_order_pub.line_scredit_tbl_type
            := oe_order_pub.g_miss_line_scredit_tbl;
        p_old_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type
            := oe_order_pub.g_miss_line_scredit_tbl;
        p_line_scredit_val_tbl         oe_order_pub.line_scredit_val_tbl_type
            := oe_order_pub.g_miss_line_scredit_val_tbl;
        p_old_line_scredit_val_tbl     oe_order_pub.line_scredit_val_tbl_type
            := oe_order_pub.g_miss_line_scredit_val_tbl;
        p_lot_serial_tbl               oe_order_pub.lot_serial_tbl_type
            := oe_order_pub.g_miss_lot_serial_tbl;
        p_old_lot_serial_tbl           oe_order_pub.lot_serial_tbl_type
            := oe_order_pub.g_miss_lot_serial_tbl;
        p_lot_serial_val_tbl           oe_order_pub.lot_serial_val_tbl_type
            := oe_order_pub.g_miss_lot_serial_val_tbl;
        p_old_lot_serial_val_tbl       oe_order_pub.lot_serial_val_tbl_type
            := oe_order_pub.g_miss_lot_serial_val_tbl;
        p_action_request_tbl           oe_order_pub.request_tbl_type
                                           := oe_order_pub.g_miss_request_tbl;
        x_header_val_rec               oe_order_pub.header_val_rec_type;
        x_header_adj_tbl               oe_order_pub.header_adj_tbl_type;
        x_header_adj_val_tbl           oe_order_pub.header_adj_val_tbl_type;
        x_header_price_att_tbl         oe_order_pub.header_price_att_tbl_type;
        x_header_adj_att_tbl           oe_order_pub.header_adj_att_tbl_type;
        x_header_adj_assoc_tbl         oe_order_pub.header_adj_assoc_tbl_type;
        x_header_scredit_tbl           oe_order_pub.header_scredit_tbl_type;
        x_header_scredit_val_tbl       oe_order_pub.header_scredit_val_tbl_type;
        x_line_val_tbl                 oe_order_pub.line_val_tbl_type;
        x_line_adj_tbl                 oe_order_pub.line_adj_tbl_type;
        x_line_adj_val_tbl             oe_order_pub.line_adj_val_tbl_type;
        x_line_price_att_tbl           oe_order_pub.line_price_att_tbl_type;
        x_line_adj_att_tbl             oe_order_pub.line_adj_att_tbl_type;
        x_line_adj_assoc_tbl           oe_order_pub.line_adj_assoc_tbl_type;
        x_line_scredit_tbl             oe_order_pub.line_scredit_tbl_type;
        x_line_scredit_val_tbl         oe_order_pub.line_scredit_val_tbl_type;
        x_lot_serial_tbl               oe_order_pub.lot_serial_tbl_type;
        x_lot_serial_val_tbl           oe_order_pub.lot_serial_val_tbl_type;
        x_action_request_tbl           oe_order_pub.request_tbl_type;
        x_debug_file                   VARCHAR2 (100);
        l_msg_index_out                NUMBER (10);
        l_line_tbl_index               NUMBER;
        ln_user_id                     NUMBER;
        ln_resp_id                     NUMBER;
        ln_resp_appl_id                NUMBER;
        ln_org_id                      NUMBER;
        ln_derived_org_id              NUMBER;
        ln_success_count               NUMBER := 0;
        ln_error_count                 NUMBER := 0;
        lc_msg                         VARCHAR2 (2000);
        LC_NEXT_MSG                    VARCHAR2 (2000);



        -- Declare UNDEMAND ORDER LOGIC
        x_atp_rec                      MRP_ATP_PUB.atp_rec_typ;
        x_atp_rec_out                  MRP_ATP_PUB.atp_rec_typ;
        x_atp_supply_demand            MRP_ATP_PUB.ATP_Supply_Demand_Typ;
        x_atp_period                   MRP_ATP_PUB.ATP_Period_Typ;
        x_atp_details                  MRP_ATP_PUB.ATP_Details_Typ;
        char_1_null                    VARCHAR2 (2000) := NULL;
        char_30_null                   VARCHAR2 (30) := NULL;
        number_null                    NUMBER := NULL;
        date_null                      DATE := NULL;
        l_session_id                   NUMBER := pn_session_id;

        --End Declare UNDEMAND ORDER LOGIC



        CURSOR cur_oe_line_dtls IS
              SELECT DISTINCT order_header_id, order_line_id, session_id
                FROM xxd_mrp_atp_schedule_temp
               WHERE     session_id = pn_session_id
                     AND atp_level_type = 6                           -- Split
                     AND status_flag = 1
            ORDER BY order_header_id;
    /* cursor cur_oe_split_lines (pn_session_id      NUMBER,
                                pn_order_header_id NUMBER,
                                pn_order_line_id   NUMBER)
     IS
          SELECT order_header_id,
                order_line_id,
                scheduled_ship_date,
                requested_ship_date,
                'SPLIT' schedule_type,
                ORIG_OE_LINE_REF split_from_oe_line,
                NVL (new_quantity, quantity_ordered) new_quantity,
                inventory_item_id inventory_item_id
           --BULK COLLECT INTO xxd_v_split_line_Tbl
           FROM xxd_mrp_atp_schedule_temp
          WHERE     session_id = pn_session_id
                AND order_header_id = pn_order_header_id
                AND order_line_id = pn_order_line_id
                AND atp_level_type = 6                          -- For Split
                AND status_flag = 1
         UNION
         SELECT order_header_id,
                order_line_id,
                scheduled_ship_date,
                requested_ship_date,
                'SPLIT' schedule_type,
                ORIG_OE_LINE_REF split_from_oe_line,
                (orignal_quantity - NVL (new_quantity, quantity_ordered)) new_quantity,
                inventory_item_id inventory_item_id
           --BULK COLLECT INTO xxd_v_split_line_Tbl
           FROM xxd_mrp_atp_schedule_temp
          WHERE     session_id = pn_session_id
                AND order_header_id = pn_order_header_id
                AND order_line_id = pn_order_line_id
                AND atp_level_type in (7,8)                         -- For Split
                AND status_flag = 1
       ORDER BY ORIG_OE_LINE_REF DESC;*/
    BEGIN
        LOG (
            'Total record count for Splitting' || xxd_v_split_line_Tbl.COUNT);

        ln_user_id         := pn_user_id;      --fnd_profile.value('USER_ID');
        ln_resp_id         := pn_resp_id;      --fnd_profile.value('RESP_ID');
        ln_resp_appl_id    := pn_resp_appl_id; --fnd_profile.value('RESP_APPL_ID');
        ln_org_id          := pn_org_id;
        ln_success_count   := 0;
        ln_error_count     := 0;

        LOG (
               ln_user_id
            || ','
            || ln_resp_id
            || ','
            || ln_resp_appl_id
            || ','
            || ln_org_id);

        FOR rec_oe_line_dtls IN cur_oe_line_dtls
        LOOP
            xxd_v_split_line_Tbl.delete;

              SELECT order_header_id, order_line_id, scheduled_ship_date,
                     requested_ship_date, schedule_type, split_from_oe_line,
                     new_quantity, inventory_item_id, sequence_number,
                     atp_level_type
                BULK COLLECT INTO xxd_v_split_line_Tbl
                FROM (SELECT order_header_id, order_line_id, scheduled_ship_date,
                             requested_ship_date, 'SPLIT' schedule_type, ORIG_OE_LINE_REF split_from_oe_line,
                             NVL (new_quantity, quantity_ordered) new_quantity, inventory_item_id inventory_item_id, sequence_number,
                             atp_level_type
                        --BULK COLLECT INTO xxd_v_split_line_Tbl
                        FROM xxd_mrp_atp_schedule_temp
                       WHERE     session_id = pn_session_id
                             AND order_header_id =
                                 rec_oe_line_dtls.order_header_id
                             AND order_line_id = rec_oe_line_dtls.order_line_id
                             AND atp_level_type = 6               -- For Split
                             AND status_flag = 1
                      UNION
                      SELECT mast1.order_header_id, mast1.order_line_id, mast1.scheduled_ship_date,
                             mast1.requested_ship_date, 'SPLIT' schedule_type, mast1.ORIG_OE_LINE_REF split_from_oe_line,
                             (mast1.original_qty - NVL (mast2.new_quantity, mast2.quantity_ordered)) new_quantity, mast1.inventory_item_id inventory_item_id, mast1.sequence_number,
                             mast1.atp_level_type
                        FROM xxd_mrp_atp_schedule_temp mast1, xxd_mrp_atp_schedule_temp mast2
                       WHERE     mast1.session_id = pn_session_id
                             AND mast1.order_header_id =
                                 rec_oe_line_dtls.order_header_id
                             AND mast1.order_line_id =
                                 rec_oe_line_dtls.order_line_id
                             AND mast1.atp_level_type IN (7, 8)   -- For Split
                             AND mast2.atp_level_type = 6
                             AND mast1.order_header_id = mast2.order_header_id
                             AND mast1.order_line_id = mast2.order_line_id
                             AND mast1.session_id = mast2.session_id
                             AND mast1.inventory_item_id =
                                 mast2.inventory_item_id
                             AND mast1.status_flag = 1)
            ORDER BY order_line_id, sequence_number;

            --End Changes by BT Technology team on 12 dec 15
            l_line_tbl.delete;

            FOR i IN 1 .. xxd_v_split_line_Tbl.COUNT
            LOOP
                l_line_tbl_index   := i;

                IF xxd_v_split_line_Tbl (l_line_tbl_index).split_from_oe_line
                       IS NULL                                -- Original Line
                THEN
                    BEGIN
                        SELECT org_id
                          INTO ln_derived_org_id
                          FROM oe_order_lines_all
                         WHERE     header_id =
                                   xxd_v_split_line_Tbl (l_line_tbl_index).order_header_id
                               AND line_id =
                                   xxd_v_split_line_Tbl (l_line_tbl_index).order_line_id;
                    END;

                    -- Start of ExceptionHandling 09Dec15
                    XXD_UPDATE_ERROR_LOG (
                        pn_session_id,
                        rec_oe_line_dtls.order_header_id,
                        'proc_split_order_lines',
                           'IF - l_line_tbl_index - '
                        || l_line_tbl_index
                        || xxd_v_split_line_Tbl (l_line_tbl_index).order_line_id
                        || '*qty - *'
                        || xxd_v_split_line_Tbl (l_line_tbl_index).new_quantity
                        || '*seq*'
                        || xxd_v_split_line_Tbl (l_line_tbl_index).sequence_number);
                    -- End of Exception Handling 09Dec15

                    l_header_rec                              := OE_ORDER_PUB.G_MISS_HEADER_REC;
                    l_header_rec.header_id                    :=
                        xxd_v_split_line_Tbl (l_line_tbl_index).order_header_id; -- header_id of the order
                    l_header_rec.operation                    := OE_GLOBALS.G_OPR_UPDATE;
                    l_line_tbl (l_line_tbl_index)             :=
                        OE_ORDER_PUB.G_MISS_LINE_REC;
                    l_line_tbl (l_line_tbl_index).operation   :=
                        OE_GLOBALS.G_OPR_UPDATE;
                    l_line_tbl (l_line_tbl_index).split_by    := ln_user_id; -- user_id
                    l_line_tbl (l_line_tbl_index).split_action_code   :=
                        xxd_v_split_line_Tbl (l_line_tbl_index).schedule_type;
                    l_line_tbl (l_line_tbl_index).request_date   :=
                        xxd_v_split_line_Tbl (l_line_tbl_index).requested_ship_date;
                    l_line_tbl (l_line_tbl_index).override_atp_date_code   :=
                        'Y';
                    --               l_line_tbl (l_line_tbl_index).schedule_ship_date := --NULL;
                    --                  xxd_v_split_line_Tbl (l_line_tbl_index).scheduled_ship_date;
                    l_line_tbl (l_line_tbl_index).header_id   :=
                        xxd_v_split_line_Tbl (l_line_tbl_index).order_header_id; -- header_id of the order
                    l_line_tbl (l_line_tbl_index).request_date   :=
                        xxd_v_split_line_Tbl (l_line_tbl_index).requested_ship_date;
                    l_line_tbl (l_line_tbl_index).line_id     :=
                        xxd_v_split_line_Tbl (l_line_tbl_index).order_line_id; -- line_id of the order line
                    l_line_tbl (l_line_tbl_index).ordered_quantity   :=
                        xxd_v_split_line_Tbl (l_line_tbl_index).new_quantity; -- new ordered quantity
                    l_line_tbl (l_line_tbl_index).change_reason   :=
                        'MISC';                          -- change reason code
                ELSE                                                --New Line
                    l_line_tbl_index                          := i;

                    -- Start of ExceptionHandling 09Dec15
                    XXD_UPDATE_ERROR_LOG (
                        pn_session_id,
                        rec_oe_line_dtls.order_header_id,
                        'proc_split_order_lines',
                           'Else - l_line_tbl_index - '
                        || l_line_tbl_index
                        || xxd_v_split_line_Tbl (l_line_tbl_index).order_line_id
                        || '*qty - *'
                        || xxd_v_split_line_Tbl (l_line_tbl_index).new_quantity
                        || '*seq*'
                        || xxd_v_split_line_Tbl (l_line_tbl_index).sequence_number);
                    -- End of Exception Handling 09Dec15

                    l_line_tbl (l_line_tbl_index)             :=
                        OE_ORDER_PUB.G_MISS_LINE_REC;

                    l_line_tbl (l_line_tbl_index).operation   :=
                        OE_GLOBALS.G_OPR_CREATE;
                    l_line_tbl (l_line_tbl_index).split_by    := ln_user_id; -- user_id
                    l_line_tbl (l_line_tbl_index).split_action_code   :=
                        xxd_v_split_line_Tbl (l_line_tbl_index).schedule_type;
                    l_line_tbl (l_line_tbl_index).override_atp_date_code   :=
                        'Y';
                    --               l_line_tbl (l_line_tbl_index).schedule_ship_date := -- NULL;
                    --                  xxd_v_split_line_Tbl (l_line_tbl_index).scheduled_ship_date;
                    l_line_tbl (l_line_tbl_index).split_from_line_id   :=
                        xxd_v_split_line_Tbl (l_line_tbl_index).split_from_oe_line; -- line_id of  original line
                    l_line_tbl (l_line_tbl_index).inventory_item_id   :=
                        xxd_v_split_line_Tbl (l_line_tbl_index).inventory_item_id; -- inventory item id
                    l_line_tbl (l_line_tbl_index).ordered_quantity   :=
                        xxd_v_split_line_Tbl (l_line_tbl_index).new_quantity; -- ordered quantity
                END IF;
            END LOOP;


            -- Initializing the Environment
            fnd_global.apps_initialize (user_id        => ln_user_id,
                                        resp_id        => ln_resp_id,
                                        resp_appl_id   => ln_resp_appl_id);
            mo_global.init ('ONT');
            mo_global.Set_org_context (ln_derived_org_id, NULL, 'ONT');
            fnd_global.Set_nls_context ('AMERICAN');
            mo_global.set_policy_context ('S', ln_derived_org_id);
            oe_msg_pub.initialize;
            oe_debug_pub.initialize;

            -- CALL TO PROCESS ORDER
            oe_order_pub.Process_order (
                p_api_version_number       => 1.0,
                p_init_msg_list            => fnd_api.g_false,
                p_return_values            => fnd_api.g_false,
                p_action_commit            => fnd_api.g_false,
                x_return_status            => l_return_status,
                x_msg_count                => l_msg_count,
                x_msg_data                 => l_msg_data,
                p_header_rec               => l_header_rec,
                p_line_tbl                 => l_line_tbl,
                p_action_request_tbl       => l_action_request_tbl -- OUT PARAMETERS
                                                                  ,
                x_header_rec               => x_header_rec,
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
                x_action_request_tbl       => x_action_request_tbl);

            LOG ('1 St Line Id: ' || x_line_tbl (1).line_id);
            LOG ('2 Nd Line Id: ' || x_line_tbl (2).line_id);

            FOR i IN 1 .. l_msg_count
            LOOP
                oe_msg_pub.Get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => l_msg_data
                                , p_msg_index_out => l_msg_index_out);

                LOG ('message is: ' || l_msg_data);
                LOG ('message index is: ' || l_msg_index_out);
            END LOOP;

            -- Check the return status
            IF l_return_status = fnd_api.g_ret_sts_success
            THEN
                LOG ('Splitting the Order Lines is Success');
                ln_success_count   := ln_success_count + 1;



                --x_err_msg := 'Splitting the Order Lines is Success';

                COMMIT;
            ELSE
                ln_error_count   := ln_error_count + 1;
                LOG ('Splitting the Order Lines has Failed');
                --x_err_msg :=
                --   'Splitting the Order Lines has Failed. Reason : '
                --|| l_msg_data;

                ROLLBACK;

                -- Start of ExceptionHandling 09Dec15
                XXD_UPDATE_ERROR_LOG (pn_session_id, rec_oe_line_dtls.order_header_id, 'proc_split_order_lines'
                                      , l_msg_data);
            -- End of Exception Handling 09Dec15

            END IF;
        END LOOP;

        --Added this logic on 15 Dec 2015 after inclusive of Override ATP Logic
        PROC_DELETE_SPLIT_LINES (pn_session_id);
        --END this logic on 15 Dec 2015 after inclusive of Override ATP Logic
        x_err_msg          :=
               'Total No. of Records that were successfully Split - '
            || ln_success_count
            || '    Total No. of Records that went into erro while Splitting - '
            || ln_error_count;
        x_msg_data         := x_err_msg;
    EXCEPTION
        WHEN OTHERS
        THEN
            --x_err_code := 'E';
            x_err_msg   := SQLERRM;
            LOG ('Exception in Splitting the orders' || x_err_msg);
    END proc_split_order_lines;

    ------------------------------------------------------------------------
    -- Added by NRK -- END of Changes
    ------------------------------------------------------------------------
    --Start of Changes by NRK - 19 Nov 2015
    --------------------------------------------------------------------------------------------------------------


    PROCEDURE proc_unschdl_cancl_split_lines (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, pn_session_id NUMBER, pn_user_id NUMBER, pn_resp_id NUMBER, pn_resp_appl_id NUMBER
                                              , pn_org_id NUMBER, x_msg_data OUT VARCHAR2, x_err_msg OUT VARCHAR2)
    IS
        v_order_header_rec             oe_order_pub.header_rec_type;
        v_order_hdr_slcrtab            oe_order_pub.header_scredit_tbl_type;
        v_order_line_tab               oe_order_pub.line_tbl_type;
        v_order_header_val_rec         oe_order_pub.header_val_rec_type;
        v_order_header_adj_tbl         oe_order_pub.header_adj_tbl_type;
        v_order_hdr_adj_val_tbl        oe_order_pub.header_adj_val_tbl_type;
        v_order_hdr_pri_att_tbl        oe_order_pub.header_price_att_tbl_type;
        v_order_hdr_adj_att_tbl        oe_order_pub.header_adj_att_tbl_type;
        v_order_hdr_adj_asc_tbl        oe_order_pub.header_adj_assoc_tbl_type;
        v_order_hdr_scr_val_tbl        oe_order_pub.header_scredit_val_tbl_type;
        v_order_line_val_tbl           oe_order_pub.line_val_tbl_type;
        v_order_line_adj_tbl           oe_order_pub.line_adj_tbl_type;
        v_order_line_adj_val_tbl       oe_order_pub.line_adj_val_tbl_type;
        v_order_line_pri_att_tbl       oe_order_pub.line_price_att_tbl_type;
        v_order_line_adj_att_tbl       oe_order_pub.line_adj_att_tbl_type;
        v_order_line_adj_asc_tbl       oe_order_pub.line_adj_assoc_tbl_type;
        v_order_line_scredit_tbl       oe_order_pub.line_scredit_tbl_type;
        v_order_line_scr_val_tbl       oe_order_pub.line_scredit_val_tbl_type;
        v_order_lot_serial_tbl         oe_order_pub.lot_serial_tbl_type;
        v_order_lot_serl_val_tbl       oe_order_pub.lot_serial_val_tbl_type;
        v_order_request_tbl            oe_order_pub.request_tbl_type;
        lr_order_header_rec            oe_order_pub.header_rec_type;
        lr_order_hdr_slcrtab           oe_order_pub.header_scredit_tbl_type;
        lr_order_line_tab              oe_order_pub.line_tbl_type;
        lr_order_line_tab1             oe_order_pub.line_tbl_type;
        lr_line_rec_type               oe_order_pub.line_rec_type;
        lr_order_header_val_rec        oe_order_pub.header_val_rec_type;
        lr_order_header_adj_tbl        oe_order_pub.header_adj_tbl_type;
        lr_order_hdr_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type;
        lr_order_hdr_pri_att_tbl       oe_order_pub.header_price_att_tbl_type;
        lr_order_hdr_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type;
        lr_order_hdr_adj_asc_tbl       oe_order_pub.header_adj_assoc_tbl_type;
        lr_order_hdr_scr_val_tbl       oe_order_pub.header_scredit_val_tbl_type;
        lr_order_line_val_tbl          oe_order_pub.line_val_tbl_type;
        lr_order_line_adj_tbl          oe_order_pub.line_adj_tbl_type;
        lr_order_line_adj_val_tbl      oe_order_pub.line_adj_val_tbl_type;
        lr_order_line_pri_att_tbl      oe_order_pub.line_price_att_tbl_type;
        lr_order_line_adj_att_tbl      oe_order_pub.line_adj_att_tbl_type;
        lr_order_line_adj_asc_tbl      oe_order_pub.line_adj_assoc_tbl_type;
        lr_order_line_scredit_tbl      oe_order_pub.line_scredit_tbl_type;
        lr_order_line_scr_val_tbl      oe_order_pub.line_scredit_val_tbl_type;
        lr_order_lot_serial_tbl        oe_order_pub.lot_serial_tbl_type;
        lr_order_lot_serl_val_tbl      oe_order_pub.lot_serial_val_tbl_type;
        lr_order_request_tbl           oe_order_pub.request_tbl_type;
        vreturnstatus                  VARCHAR2 (30);
        vmsgcount                      NUMBER;
        vmsgdata                       VARCHAR2 (5000);
        l_count                        NUMBER;
        i                              NUMBER;
        ln_user_id                     NUMBER;
        ln_resp_id                     NUMBER;
        ln_resp_appl_id                NUMBER;
        ln_org_id                      NUMBER;
        ln_success_cnt                 NUMBER := 0;
        ln_error_cnt                   NUMBER := 0;

        -- for cancellation
        v_api_version_number           NUMBER := 1;
        v_return_status                VARCHAR2 (2000);
        v_msg_count                    NUMBER;
        v_msg_data                     VARCHAR2 (5000);

        -- IN Variables --
        v_header_rec                   oe_order_pub.header_rec_type;
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
        lc_msg                         VARCHAR2 (2000);
        LC_NEXT_MSG                    VARCHAR2 (2000);

        CURSOR cur_unschdl_sel_oe_hdr IS
              SELECT DISTINCT order_header_id
                FROM xxd_mrp_atp_schedule_temp
               WHERE     session_id = pn_session_id
                     AND atp_level_type = 8       --split & unschedule + Split
                     AND status_flag = 1
            ORDER BY order_header_id;

        CURSOR cur_cancel_sel_oe_hdr IS
              SELECT DISTINCT order_header_id
                FROM xxd_mrp_atp_schedule_temp
               WHERE     session_id = pn_session_id
                     AND atp_level_type = 7                   --split & cancel
                     AND status_flag = 1
            ORDER BY order_header_id;
    BEGIN
        --      LOG (
        --         'Total record count for Unscheduling' || xxd_v_cancel_line_tbl.COUNT);

        ln_user_id        := pn_user_id;       --fnd_profile.value('USER_ID');
        ln_resp_id        := pn_resp_id;       --fnd_profile.value('RESP_ID');
        ln_resp_appl_id   := pn_resp_appl_id; --fnd_profile.value('RESP_APPL_ID');
        ln_org_id         := pn_org_id;



        --      fnd_global.apps_initialize (user_id        => ln_user_id,
        --                                  resp_id        => ln_resp_id,
        --                                  resp_appl_id   => ln_resp_appl_id);
        --      mo_global.init ('ONT');
        --      mo_global.set_policy_context ('S', ln_org_id);
        --      oe_msg_pub.initialize;
        --      oe_debug_pub.initialize;
        vreturnstatus     := NULL;
        vmsgcount         := 0;
        vmsgdata          := NULL;
        xxd_v_cancel_line_tbl.delete;
        xxd_v_unschdl_line_tbl.delete;
        ln_success_cnt    := 0;
        ln_error_cnt      := 0;


        -- Updating back the lines with Override_atp_date_code = 'N'
        /*BEGIN
        XXD_MSC_ONT_ATP_LEVEL_PKG.XXD_UPDATE_ERROR_LOG (
              pn_session_id,                           --remove the pkg name NRK
              226651,
              'AM Debug2',
              v_msg_data);
           UPDATE oe_order_lines_all ool
           SET override_atp_date_code = 'N'
         WHERE  flow_status_code NOT IN ('CANCELLED', 'CLOSED')
               AND source_type_code = 'INTERNAL'
               AND split_from_line_id IS NOT NULL
                  AND EXISTS
                         (SELECT 1
                            FROM xxd_mrp_atp_schedule_temp mast
                           WHERE     atp_level_type IN (6,7, 8) -- Split & Unschedule + Split + SPlit & Cancel-- added '6' on 15 Dec 2015 for unscheduling the split line
                                 AND mast.session_id = pn_session_id
                                 AND mast.order_line_id =
                                        ool.split_from_line_id
                                 AND mast.ORIG_OE_LINE_REF IS NOT NULL)
                  AND NOT EXISTS
                             (SELECT 1
                                FROM xxd_mrp_atp_schedule_temp mast
                               WHERE     mast.session_id = pn_session_id --                     and mast.order_line_id = ool.split_from_line_id
                                     AND mast.order_line_id = ool.line_id);

            EXCEPTION WHEN OTHERS THEN
            XXD_UPDATE_ERROR_LOG (pn_session_id,
                                       55555,
                                       'proc_unschdl_cancl_split_lines1',
                                       'Error while updating the override ATP Flag'||SQLERRM);
            END;
  */
        FOR rec_unschdl_sel_oe_hdr IN cur_unschdl_sel_oe_hdr
        LOOP
            -- for unschedule
            xxd_v_unschdl_line_tbl.delete;

            SELECT header_id, line_id, schedule_ship_date,
                   REQUEST_DATE, 'UNSCHEDULE' schedule_type
              BULK COLLECT INTO xxd_v_unschdl_line_tbl
              FROM OE_ORDER_LINES_ALL ool
             WHERE     split_from_line_id IS NOT NULL
                   AND EXISTS
                           (SELECT 1
                              FROM xxd_mrp_atp_schedule_temp mast
                             WHERE     atp_level_type = 8 -- Split & Unschedule
                                   AND header_id =
                                       rec_unschdl_sel_oe_hdr.order_header_id
                                   AND mast.session_id = pn_session_id
                                   AND mast.order_line_id =
                                       ool.split_from_line_id
                                   AND mast.ORIG_OE_LINE_REF IS NOT NULL)
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxd_mrp_atp_schedule_temp mast
                             WHERE     mast.session_id = pn_session_id --                     and mast.order_line_id = ool.split_from_line_id
                                   AND mast.order_line_id = ool.line_id);


            --Start changes on BT Technology Team on 18 Dec 15
            BEGIN
                ln_org_id   := NULL;

                SELECT org_id
                  INTO ln_org_id
                  FROM oe_order_headers_all
                 WHERE header_id = rec_unschdl_sel_oe_hdr.order_header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_org_id   := pn_org_id;
            END;

            --End changes on BT Technology Team on 18 Dec 15

            fnd_global.apps_initialize (user_id        => ln_user_id,
                                        resp_id        => ln_resp_id,
                                        resp_appl_id   => ln_resp_appl_id);
            mo_global.init ('ONT');
            mo_global.set_policy_context ('S', ln_org_id);
            oe_msg_pub.initialize;
            oe_debug_pub.initialize;

            -- unschedule
            v_order_line_tab.delete;

            FOR i IN 1 .. xxd_v_unschdl_line_tbl.COUNT
            LOOP
                v_order_line_tab (i)                        :=
                    oe_line_util.query_row (
                        xxd_v_unschdl_line_tbl (i).line_id);
                v_order_line_tab (i).operation              := oe_globals.g_opr_update;
                v_order_line_tab (i).line_id                :=
                    xxd_v_unschdl_line_tbl (i).line_id;
                --v_order_line_tab (i).request_date := p_scheddate;
                v_order_line_tab (i).request_date           :=
                    xxd_v_unschdl_line_tbl (i).requested_ship_date;
                --v_order_line_tab (i).schedule_action_code := 'SCHEDULE';
                v_order_line_tab (i).schedule_action_code   :=
                    xxd_v_unschdl_line_tbl (i).schedule_type;
                v_line_tbl (i).org_id                       := ln_org_id;
            END LOOP;

            --


            IF v_order_line_tab.COUNT > 0
            THEN
                oe_order_pub.process_order (
                    -- Start modification by BT Technology Team on 18-Dec-15
                    p_org_id                   => ln_org_id,
                    -- End modification by BT Technology Team on 18-Dec-15
                    p_api_version_number       => 1.0,
                    --p_org_id                   => ln_org_id,
                    p_init_msg_list            => fnd_api.g_true,
                    p_return_values            => fnd_api.g_true,
                    p_action_commit            => fnd_api.g_true,
                    p_header_rec               => v_order_header_rec,
                    p_header_val_rec           => v_order_header_val_rec,
                    p_header_scredit_tbl       => v_order_hdr_slcrtab,
                    p_line_tbl                 => v_order_line_tab,
                    p_line_price_att_tbl       => v_order_line_pri_att_tbl,
                    p_action_request_tbl       => v_order_request_tbl,
                    x_return_status            => vreturnstatus,
                    x_msg_count                => vmsgcount,
                    x_msg_data                 => vmsgdata,
                    x_header_rec               => lr_order_header_rec,
                    x_header_val_rec           => lr_order_header_val_rec,
                    x_header_adj_tbl           => lr_order_header_adj_tbl,
                    x_header_adj_val_tbl       => lr_order_hdr_adj_val_tbl,
                    x_header_price_att_tbl     => lr_order_hdr_pri_att_tbl,
                    x_header_adj_att_tbl       => lr_order_hdr_adj_att_tbl,
                    x_header_adj_assoc_tbl     => lr_order_hdr_adj_asc_tbl,
                    x_header_scredit_tbl       => lr_order_hdr_slcrtab,
                    x_header_scredit_val_tbl   => lr_order_hdr_scr_val_tbl,
                    x_line_tbl                 => lr_order_line_tab,
                    x_line_val_tbl             => lr_order_line_val_tbl,
                    x_line_adj_tbl             => lr_order_line_adj_tbl,
                    x_line_adj_val_tbl         => lr_order_line_adj_val_tbl,
                    x_line_price_att_tbl       => lr_order_line_pri_att_tbl,
                    x_line_adj_att_tbl         => lr_order_line_adj_att_tbl,
                    x_line_adj_assoc_tbl       => lr_order_line_adj_asc_tbl,
                    x_line_scredit_tbl         => lr_order_line_scredit_tbl,
                    x_line_scredit_val_tbl     => lr_order_line_scr_val_tbl,
                    x_lot_serial_tbl           => lr_order_lot_serial_tbl,
                    x_lot_serial_val_tbl       => lr_order_lot_serl_val_tbl,
                    x_action_request_tbl       => lr_order_request_tbl);
                LOG ('Completion of API');

                IF vreturnstatus = fnd_api.g_ret_sts_success
                THEN
                    --x_err_msg := 'Unscheduling lines are successful.';
                    ln_success_cnt   := ln_success_cnt + 1;
                    x_retcode        := 1;
                    --x_err_code := 'S';
                    COMMIT;
                ELSE
                    ROLLBACK;
                    -- x_err_code := 'E';
                    ln_error_cnt   := ln_error_cnt + 1;
                    x_retcode      := 2;

                    --x_err_msg := 'Error while unscheduling line - ';


                    --               FOR j IN 1 .. vmsgcount
                    --               LOOP
                    --                  vmsgdata := vmsgdata ||
                    --                     oe_msg_pub.get (p_msg_index => j, p_encoded => 'F');
                    --                  --x_err_msg := x_err_msg || vmsgdata;
                    --               END LOOP;



                    -- End of Exception Handling 09Dec15

                    FOR i IN 1 .. v_msg_count
                    LOOP
                        lc_msg       := NULL;
                        oe_msg_pub.get (p_msg_index => i, p_encoded => FND_API.G_FALSE, p_data => lc_msg
                                        , p_msg_index_out => LC_NEXT_MSG);
                        v_msg_data   := v_msg_data || lc_msg;
                    END LOOP;

                    LOG (v_msg_data);

                    -- Start of ExceptionHandling 10Dec15
                    XXD_UPDATE_ERROR_LOG (pn_session_id, rec_unschdl_sel_oe_hdr.order_header_id, 'proc_unschdl_cancl_split_lines1'
                                          , v_msg_data);
                -- End of Exception Handling 10Dec15

                END IF;
            ELSE
                x_retcode   := 1;
                v_msg_data   :=
                       'There are no eligible order lines to unschedule.'
                    || vmsgdata;
            END IF;

            v_msg_data   := v_msg_data || CHR (9) || vmsgdata;
        --END LOOP;
        END LOOP;

        vmsgcount         := 0;
        vmsgdata          := NULL;

        IF xxd_v_unschdl_line_tbl.COUNT != 0
        THEN
            v_msg_data   :=
                   'Total No of records Successfully Unscheduled '
                || ln_success_cnt
                || '     Total No of records which went into error while unscheduling '
                || ln_error_cnt;                                  --||chr(10);
        END IF;



        ln_success_cnt    := 0;
        ln_error_cnt      := 0;



        FOR rec_cancel_sel_oe_hdr IN cur_cancel_sel_oe_hdr
        LOOP
            -- for Cancel
            xxd_v_cancel_line_tbl.delete;

            SELECT header_id, line_id, 0 ORDERED_QUANTITY, --Quantity should be zero for cancellation
                   'Y', 'ADM-0080'
              BULK COLLECT INTO xxd_v_cancel_line_tbl
              FROM OE_ORDER_LINES_ALL ool
             WHERE     split_from_line_id IS NOT NULL
                   AND EXISTS
                           (SELECT 1
                              FROM xxd_mrp_atp_schedule_temp mast
                             WHERE     atp_level_type = 7    -- Split & Cancel
                                   AND header_id =
                                       rec_cancel_sel_oe_hdr.order_header_id
                                   AND mast.session_id = pn_session_id
                                   AND mast.order_line_id =
                                       ool.split_from_line_id
                                   AND mast.ORIG_OE_LINE_REF IS NOT NULL)
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxd_mrp_atp_schedule_temp mast
                             WHERE     mast.session_id = pn_session_id --                     and mast.order_line_id = ool.split_from_line_id
                                   AND mast.order_line_id = ool.line_id);

            --Start changes on BT Technology Team on 18 Dec 15
            BEGIN
                ln_org_id   := NULL;

                SELECT org_id
                  INTO ln_org_id
                  FROM oe_order_headers_all
                 WHERE header_id = rec_cancel_sel_oe_hdr.order_header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_org_id   := pn_org_id;
            END;

            --End changes on BT Technology Team on 18 Dec 15

            fnd_global.apps_initialize (user_id        => ln_user_id,
                                        resp_id        => ln_resp_id,
                                        resp_appl_id   => ln_resp_appl_id);
            mo_global.init ('ONT');
            mo_global.set_policy_context ('S', ln_org_id);
            oe_msg_pub.initialize;
            oe_debug_pub.initialize;
            v_action_request_tbl.delete;
            v_line_tbl.delete;

            FOR i IN 1 .. xxd_v_cancel_line_tbl.COUNT
            LOOP
                v_action_request_tbl (i)          := oe_order_pub.g_miss_request_rec;

                -- Cancel a Line Record --
                v_line_tbl (i)                    := oe_order_pub.g_miss_line_rec;
                v_line_tbl (i).operation          := OE_GLOBALS.G_OPR_UPDATE;
                v_line_tbl (i).header_id          :=
                    xxd_v_cancel_line_tbl (i).header_id;
                v_line_tbl (i).line_id            :=
                    xxd_v_cancel_line_tbl (i).line_id;
                v_line_tbl (i).ordered_quantity   :=
                    xxd_v_cancel_line_tbl (i).ordered_quantity;
                v_line_tbl (i).cancelled_flag     :=
                    xxd_v_cancel_line_tbl (i).cancelled_flag;
                v_line_tbl (i).change_reason      :=
                    xxd_v_cancel_line_tbl (i).change_reason;
                v_line_tbl (i).org_id             := ln_org_id;
            END LOOP;

            XXD_MSC_ONT_ATP_LEVEL_PKG.XXD_UPDATE_ERROR_LOG (pn_session_id, --remove the pkg name NRK
                                                                           226651, 'AM Debug5'
                                                            , v_msg_data);

            LOG ('Starting of Cancellation API');

            -- Calling the API to cancel a line from an Existing Order --

            OE_ORDER_PUB.PROCESS_ORDER (
                -- Start modification by BT Technology Team on 18-Dec-15
                p_org_id                   => ln_org_id,
                -- End modification by BT Technology Team on 18-Dec-15
                p_api_version_number       => v_api_version_number,
                p_header_rec               => v_header_rec,
                p_line_tbl                 => v_line_tbl,
                p_action_request_tbl       => v_action_request_tbl,
                p_line_adj_tbl             => v_line_adj_tbl  -- OUT variables
                                                            ,
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
                x_msg_data                 => vmsgdata);



            --x_msg_data := v_msg_data;

            LOG ('Completion of API');


            IF v_return_status = fnd_api.g_ret_sts_success
            THEN
                COMMIT;
                x_retcode        := 1;
                ln_success_cnt   := ln_success_cnt + 1;
                LOG ('Line Cancelation in Existing Order is Success ');
            --            x_msg_data := 'Line Cancelation in Existing Order is Success ';
            ELSE
                LOG (
                    'Line Cancelation in Existing Order failed:' || vmsgdata);
                --x_msg_data :=
                --    'Line Cancelation in Existing Order Order failed '
                -- || vmsgdata;
                ROLLBACK;
                x_retcode      := 2;
                ln_error_cnt   := ln_error_cnt + 1;

                -- Start of ExceptionHandling 09Dec15
                XXD_UPDATE_ERROR_LOG (pn_session_id, rec_cancel_sel_oe_hdr.order_header_id, 'proc_unschdl_cancl_split_lines2'
                                      , v_msg_data);

                -- End of Exception Handling 09Dec15

                FOR i IN 1 .. v_msg_count
                LOOP
                    vmsgdata   :=
                        oe_msg_pub.get (p_msg_index => i, p_encoded => 'F');
                    LOG (i || ') ' || vmsgdata);
                END LOOP;

                -- Start of ExceptionHandling 10Dec15
                XXD_UPDATE_ERROR_LOG (pn_session_id, rec_cancel_sel_oe_hdr.order_header_id, 'proc_unschdl_cancl_split_lines2'
                                      , v_msg_data);
            -- End of Exception Handling 10Dec15
            END IF;
        --      v_msg_data := v_msg_data || chr(9)||vmsgdata;

        END LOOP;

        IF xxd_v_cancel_line_tbl.COUNT != 0
        THEN
            v_msg_data   :=
                   v_msg_data
                || '      Total No of records Successfully Cancelled '
                || ln_success_cnt
                || '     Total No of records which went into error while Cancelling '
                || ln_error_cnt;                                  --||chr(10);
        END IF;

        x_msg_data        := v_msg_data;
        x_err_msg         := v_msg_data;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_retcode   := 1;
            --x_err_code := 'E';
            x_err_msg   := SQLERRM;
            XXD_MSC_ONT_ATP_LEVEL_PKG.XXD_UPDATE_ERROR_LOG (pn_session_id, --remove the pkg name NRK
                                                                           226651, 'AM Debug6'
                                                            , v_msg_data);
            output (
                'Exception in Unscheduling the Splitted orders' || x_err_msg);
            x_msg_data   :=
                'Error while Unscheduling / cancelling the order lines';
    END proc_unschdl_cancl_split_lines;



    PROCEDURE proc_set_override_atp_to_n (pn_session_id NUMBER)
    IS
    BEGIN
        UPDATE oe_order_lines_all ool
           SET override_atp_date_code   = 'N'
         WHERE     override_atp_date_code = 'Y'
               AND flow_status_code NOT IN ('CANCELLED', 'CLOSED')
               AND source_type_code = 'INTERNAL'
               AND EXISTS
                       (SELECT 1
                          FROM mrp_atp_schedule_temp mast
                         WHERE     session_id = pn_session_id
                               AND mast.order_header_id = ool.header_id
                               AND mast.order_line_id = ool.line_id); --   AND last_update_date < '12-SEP-2015'

        COMMIT;                                     -- Added by NRK on 18Dec15
    EXCEPTION
        WHEN OTHERS
        THEN
            XXD_UPDATE_ERROR_LOG (
                pn_session_id,
                333333,
                'proc_set_override_atp_to_n',
                'Error while updating the seeded table ' || SQLERRM);
    END;

    PROCEDURE proc_set_override_atp_to_y (pn_session_id NUMBER)
    IS
    BEGIN
        UPDATE oe_order_lines_all ool
           SET override_atp_date_code   = 'Y'
         WHERE     flow_status_code NOT IN ('CANCELLED', 'CLOSED')
               AND source_type_code = 'INTERNAL'
               AND EXISTS
                       (SELECT 1
                          FROM mrp_atp_schedule_temp mast
                         WHERE     session_id = pn_session_id
                               AND mast.order_header_id = ool.header_id
                               AND mast.order_line_id = ool.line_id); --   AND last_update_date < '12-SEP-2015'

        COMMIT;                                     -- Added by NRK on 18Dec15
    EXCEPTION
        WHEN OTHERS
        THEN
            XXD_UPDATE_ERROR_LOG (
                pn_session_id,
                44444,
                'proc_set_override_atp_to_y',
                'Error while updating the seeded table ' || SQLERRM);
    END;



    PROCEDURE proc_schdl_duplicate_lines (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, pn_session_id NUMBER, pn_user_id NUMBER, pn_resp_id NUMBER, pn_resp_appl_id NUMBER
                                          , pn_org_id NUMBER)
    IS
        v_order_header_rec             oe_order_pub.header_rec_type;
        v_header_rec_out               oe_order_pub.header_rec_type;
        v_header_adj_tbl_out           oe_order_pub.header_adj_tbl_type;
        v_header_scredit_tbl_out       oe_order_pub.header_scredit_tbl_type;
        v_header_adj_val_tbl_out       oe_order_pub.header_adj_val_tbl_type;
        v_header_price_att_tbl_out     oe_order_pub.header_price_att_tbl_type;
        v_header_adj_assoc_tbl_out     oe_order_pub.header_adj_assoc_tbl_type;
        v_header_adj_att_tbl_out       oe_order_pub.header_adj_att_tbl_type;
        v_order_hdr_slcrtab            oe_order_pub.header_scredit_tbl_type;
        v_header_val_rec_out           oe_order_pub.header_val_rec_type;
        v_line_adj_tbl                 oe_order_pub.line_adj_tbl_type;
        v_order_line_tab               oe_order_pub.line_tbl_type;
        v_order_header_val_rec         oe_order_pub.header_val_rec_type;
        v_order_header_adj_tbl         oe_order_pub.header_adj_tbl_type;
        v_order_hdr_adj_val_tbl        oe_order_pub.header_adj_val_tbl_type;
        v_order_hdr_pri_att_tbl        oe_order_pub.header_price_att_tbl_type;
        v_order_hdr_adj_att_tbl        oe_order_pub.header_adj_att_tbl_type;
        v_order_hdr_adj_asc_tbl        oe_order_pub.header_adj_assoc_tbl_type;
        v_order_hdr_scr_val_tbl        oe_order_pub.header_scredit_val_tbl_type;
        v_order_line_val_tbl           oe_order_pub.line_val_tbl_type;
        v_order_line_adj_tbl           oe_order_pub.line_adj_tbl_type;
        v_order_line_adj_val_tbl       oe_order_pub.line_adj_val_tbl_type;
        v_order_line_pri_att_tbl       oe_order_pub.line_price_att_tbl_type;
        v_order_line_adj_att_tbl       oe_order_pub.line_adj_att_tbl_type;
        v_order_line_adj_asc_tbl       oe_order_pub.line_adj_assoc_tbl_type;
        v_order_line_scredit_tbl       oe_order_pub.line_scredit_tbl_type;
        v_order_line_scr_val_tbl       oe_order_pub.line_scredit_val_tbl_type;
        v_order_lot_serial_tbl         oe_order_pub.lot_serial_tbl_type;
        v_order_lot_serl_val_tbl       oe_order_pub.lot_serial_val_tbl_type;
        v_order_request_tbl            oe_order_pub.request_tbl_type;
        lr_order_header_rec            oe_order_pub.header_rec_type;
        lr_order_hdr_slcrtab           oe_order_pub.header_scredit_tbl_type;
        lr_order_line_tab              oe_order_pub.line_tbl_type;
        lr_order_line_tab1             oe_order_pub.line_tbl_type;
        lr_line_rec_type               oe_order_pub.line_rec_type;
        lr_order_header_val_rec        oe_order_pub.header_val_rec_type;
        lr_order_header_adj_tbl        oe_order_pub.header_adj_tbl_type;
        lr_order_hdr_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type;
        lr_order_hdr_pri_att_tbl       oe_order_pub.header_price_att_tbl_type;
        lr_order_hdr_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type;
        lr_order_hdr_adj_asc_tbl       oe_order_pub.header_adj_assoc_tbl_type;
        lr_order_hdr_scr_val_tbl       oe_order_pub.header_scredit_val_tbl_type;
        lr_order_line_val_tbl          oe_order_pub.line_val_tbl_type;
        lr_order_line_adj_tbl          oe_order_pub.line_adj_tbl_type;
        lr_order_line_adj_val_tbl      oe_order_pub.line_adj_val_tbl_type;
        lr_order_line_pri_att_tbl      oe_order_pub.line_price_att_tbl_type;
        lr_order_line_adj_att_tbl      oe_order_pub.line_adj_att_tbl_type;
        lr_order_line_adj_asc_tbl      oe_order_pub.line_adj_assoc_tbl_type;
        lr_order_line_scredit_tbl      oe_order_pub.line_scredit_tbl_type;
        lr_order_line_scr_val_tbl      oe_order_pub.line_scredit_val_tbl_type;
        lr_order_lot_serial_tbl        oe_order_pub.lot_serial_tbl_type;
        lr_order_lot_serl_val_tbl      oe_order_pub.lot_serial_val_tbl_type;
        lr_order_request_tbl           oe_order_pub.request_tbl_type;
        --
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
        --
        vreturnstatus                  VARCHAR2 (30);
        vmsgcount                      NUMBER;
        vmsgdata                       VARCHAR2 (5000);
        l_count                        NUMBER;
        i                              NUMBER;
        ln_user_id                     NUMBER;
        ln_resp_id                     NUMBER;
        ln_resp_appl_id                NUMBER;
        ln_org_id                      NUMBER;
        ln_success_count               NUMBER;
        ln_error_count                 NUMBER;
        v_msg_data                     VARCHAR2 (7000);
        lc_msg                         VARCHAR2 (2000);
        LC_NEXT_MSG                    VARCHAR2 (2000);
        ln_success_cnt                 NUMBER := 0;
        ln_error_cnt                   NUMBER := 0;
        v_msg_count                    NUMBER;
        v_api_version_number           NUMBER := 1;


        --ITF related Declarations
        fence_date                     DATE;
        rule_name                      VARCHAR2 (1000);
        ln_plan_id                     NUMBER;
        ld_plan_run_date               VARCHAR2 (20) := NULL;
        ln_infinte_days                NUMBER;

        -- Cursor to Identify the Plain Split Lines
        CURSOR cur_oe_line_dtls IS
              SELECT DISTINCT order_header_id, order_line_id, session_id
                FROM xxd_mrp_atp_schedule_temp
               WHERE     session_id = pn_session_id
                     AND atp_level_type = 6                           -- Split
                     AND status_flag = 1
            ORDER BY order_header_id;


        -- Cursor to Identify the DUPLICATE(NEW LINES) from Plain Split LINES
        CURSOR cur_dup_line_dtls (cp_order_header_id NUMBER)
        IS
            SELECT header_id, line_id, inventory_item_id,
                   ship_from_org_id, schedule_ship_date, REQUEST_DATE,
                   'SCHEDULE' schedule_type
              FROM OE_ORDER_LINES_ALL ool
             WHERE     split_from_line_id IS NOT NULL
                   AND cp_order_header_id = ool.header_id
                   AND EXISTS
                           (SELECT 1
                              FROM xxd_mrp_atp_schedule_temp mast
                             WHERE     atp_level_type = 6       -- Plain split
                                   AND header_id = cp_order_header_id
                                   AND mast.session_id = pn_session_id
                                   AND mast.order_line_id =
                                       ool.split_from_line_id
                                   AND mast.ORIG_OE_LINE_REF IS NOT NULL)
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxd_mrp_atp_schedule_temp mast
                             WHERE     mast.session_id = pn_session_id
                                   AND mast.order_line_id = ool.line_id);



        rec_cur_dup_line_dtls          cur_dup_line_dtls%ROWTYPE;
    BEGIN
        ln_user_id         := pn_user_id;      --fnd_profile.value('USER_ID');
        ln_resp_id         := pn_resp_id;      --fnd_profile.value('RESP_ID');
        ln_resp_appl_id    := pn_resp_appl_id; --fnd_profile.value('RESP_APPL_ID');
        ln_org_id          := pn_org_id;
        ln_success_count   := 0;
        ln_error_count     := 0;

        --      fnd_global.apps_initialize (user_id        => ln_user_id,
        --                                  resp_id        => ln_resp_id,
        --                                  resp_appl_id   => ln_resp_appl_id);
        --      mo_global.init ('ONT');
        --      mo_global.set_policy_context ('S', ln_org_id);
        --      oe_msg_pub.initialize;
        --      oe_debug_pub.initialize;

        FOR rec_oe_line_dtls IN cur_oe_line_dtls
        LOOP
            xxd_v_schdl_line_tbl.delete;

            OPEN cur_dup_line_dtls (rec_oe_line_dtls.order_header_id);

            FETCH cur_dup_line_dtls BULK COLLECT INTO xxd_v_schdl_line_tbl;

            CLOSE cur_dup_line_dtls;

            -- Plan Run Date and Plan ID
            BEGIN
                SELECT plan_id, TO_CHAR (PLAN_COMPLETION_DATE, 'DD-MON-YYYY')
                  INTO ln_plan_id, ld_plan_run_date
                  FROM msc_plans@bt_ebs_to_ascp mp, msc_designators@bt_ebs_to_ascp md
                 WHERE     mp.compile_designator = md.designator
                       AND md.inventory_atp_flag = 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    DBMS_OUTPUT.put_line (
                        'Unable to find PlanId/Plan RunDate ' || SQLERRM);
            END;



            ---------------------------------------------------------------------------------
            --This is to update the LAD to Infinite Time Fence ( LAD = SYSDATE + 500)
            v_order_line_tab.delete;
            v_msg_data       := NULL;
            ln_success_cnt   := 0;
            x_retcode        := 1;
            vreturnstatus    := NULL;
            vmsgcount        := 0;
            vmsgdata         := NULL;

            --Start changes on BT Technology Team on 18 Dec 15
            BEGIN
                ln_org_id   := NULL;

                SELECT org_id
                  INTO ln_org_id
                  FROM oe_order_headers_all
                 WHERE header_id = rec_oe_line_dtls.order_header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_org_id   := pn_org_id;
            END;

            --End changes on BT Technology Team on 18 Dec 15

            fnd_global.apps_initialize (user_id        => ln_user_id,
                                        resp_id        => ln_resp_id,
                                        resp_appl_id   => ln_resp_appl_id);
            mo_global.init ('ONT');
            mo_global.set_policy_context ('S', ln_org_id);
            oe_msg_pub.initialize;
            oe_debug_pub.initialize;

            FOR i IN 1 .. xxd_v_schdl_line_tbl.COUNT
            LOOP
                v_order_line_tab (i)             :=
                    oe_line_util.query_row (xxd_v_schdl_line_tbl (i).line_id);
                v_order_line_tab (i).operation   := oe_globals.g_opr_update;
                v_order_line_tab (i).line_id     :=
                    xxd_v_schdl_line_tbl (i).line_id;
                v_order_line_tab (i).org_id      := ln_org_id;
                v_order_line_tab (i).latest_acceptable_date   :=
                    TRUNC (SYSDATE) + 500;
            END LOOP;

            IF v_order_line_tab.COUNT > 0
            THEN
                oe_order_pub.process_order (
                    -- Start modification by BT Technology Team on 18-Dec-15
                    p_org_id                   => ln_org_id,
                    -- End modification by BT Technology Team on 18-Dec-15
                    p_api_version_number       => v_api_version_number,
                    --p_org_id                   => ln_org_id,
                    p_init_msg_list            => fnd_api.g_true,
                    p_return_values            => fnd_api.g_true,
                    p_action_commit            => fnd_api.g_true,
                    p_header_rec               => v_order_header_rec,
                    p_header_val_rec           => v_order_header_val_rec,
                    p_header_scredit_tbl       => v_order_hdr_slcrtab,
                    p_line_tbl                 => v_order_line_tab,
                    p_line_price_att_tbl       => v_order_line_pri_att_tbl,
                    p_action_request_tbl       => v_order_request_tbl,
                    x_return_status            => vreturnstatus,
                    x_msg_count                => vmsgcount,
                    x_msg_data                 => vmsgdata,
                    x_header_rec               => lr_order_header_rec,
                    x_header_val_rec           => lr_order_header_val_rec,
                    x_header_adj_tbl           => lr_order_header_adj_tbl,
                    x_header_adj_val_tbl       => lr_order_hdr_adj_val_tbl,
                    x_header_price_att_tbl     => lr_order_hdr_pri_att_tbl,
                    x_header_adj_att_tbl       => lr_order_hdr_adj_att_tbl,
                    x_header_adj_assoc_tbl     => lr_order_hdr_adj_asc_tbl,
                    x_header_scredit_tbl       => lr_order_hdr_slcrtab,
                    x_header_scredit_val_tbl   => lr_order_hdr_scr_val_tbl,
                    x_line_tbl                 => lr_order_line_tab,
                    x_line_val_tbl             => lr_order_line_val_tbl,
                    x_line_adj_tbl             => lr_order_line_adj_tbl,
                    x_line_adj_val_tbl         => lr_order_line_adj_val_tbl,
                    x_line_price_att_tbl       => lr_order_line_pri_att_tbl,
                    x_line_adj_att_tbl         => lr_order_line_adj_att_tbl,
                    x_line_adj_assoc_tbl       => lr_order_line_adj_asc_tbl,
                    x_line_scredit_tbl         => lr_order_line_scredit_tbl,
                    x_line_scredit_val_tbl     => lr_order_line_scr_val_tbl,
                    x_lot_serial_tbl           => lr_order_lot_serial_tbl,
                    x_lot_serial_val_tbl       => lr_order_lot_serl_val_tbl,
                    x_action_request_tbl       => lr_order_request_tbl);

                IF vreturnstatus = fnd_api.g_ret_sts_success
                THEN
                    ln_success_cnt   := ln_success_cnt + 1;
                    x_retcode        := 1;
                    COMMIT;
                ELSE
                    ROLLBACK;
                    ln_error_cnt   := ln_error_cnt + 1;
                    x_retcode      := 2;

                    FOR i IN 1 .. vmsgcount
                    LOOP
                        lc_msg       := NULL;
                        oe_msg_pub.get (p_msg_index => i, p_encoded => FND_API.G_FALSE, p_data => lc_msg
                                        , p_msg_index_out => LC_NEXT_MSG);

                        v_msg_data   := v_msg_data || lc_msg;
                    END LOOP;

                    -- Start of ExceptionHandling 10Dec15
                    XXD_MSC_ONT_ATP_LEVEL_PKG.XXD_UPDATE_ERROR_LOG (
                        pn_session_id,               --remove the pkg name NRK
                        rec_oe_line_dtls.order_header_id,
                        'proc_schdl_duplicate_lines Update LAD',
                        v_msg_data);
                -- End of Exception Handling 10Dec15

                END IF;
            ELSE
                x_retcode   := 1;
                v_msg_data   :=
                       'There are no eligible order lines to Schedule/Update LAD'
                    || vmsgdata;
                XXD_MSC_ONT_ATP_LEVEL_PKG.XXD_UPDATE_ERROR_LOG (pn_session_id, --remove the pkg name NRK
                                                                               rec_oe_line_dtls.order_header_id, 'proc_schdl_duplicate_lines'
                                                                , v_msg_data);
            END IF;


            ---------------------------------------------------------------------------------
            --This is to update the Schedule the Order Duplicated Lines with LAD as Infinite Time Fence.
            -- Schedule the Orders
            v_order_line_tab.delete;

            FOR i IN 1 .. xxd_v_schdl_line_tbl.COUNT
            LOOP
                v_order_line_tab (i)                        :=
                    oe_line_util.query_row (xxd_v_schdl_line_tbl (i).line_id);
                v_order_line_tab (i).operation              := oe_globals.g_opr_update;
                v_order_line_tab (i).line_id                :=
                    xxd_v_schdl_line_tbl (i).line_id;
                v_order_line_tab (i).request_date           :=
                    xxd_v_schdl_line_tbl (i).request_date;
                v_order_line_tab (i).schedule_action_code   :=
                    xxd_v_schdl_line_tbl (i).schedule_type;
                v_order_line_tab (i).org_id                 := ln_org_id;
            END LOOP;

            IF v_order_line_tab.COUNT > 0
            THEN
                oe_order_pub.process_order (
                    -- Start modification by BT Technology Team on 18-Dec-15
                    p_org_id                   => ln_org_id,
                    -- End modification by BT Technology Team on 18-Dec-15
                    p_api_version_number       => v_api_version_number,
                    --p_org_id                   => ln_org_id,
                    p_init_msg_list            => fnd_api.g_true,
                    p_return_values            => fnd_api.g_true,
                    p_action_commit            => fnd_api.g_true,
                    p_header_rec               => v_order_header_rec,
                    p_header_val_rec           => v_order_header_val_rec,
                    p_header_scredit_tbl       => v_order_hdr_slcrtab,
                    p_line_tbl                 => v_order_line_tab,
                    p_line_price_att_tbl       => v_order_line_pri_att_tbl,
                    p_action_request_tbl       => v_order_request_tbl,
                    x_return_status            => vreturnstatus,
                    x_msg_count                => vmsgcount,
                    x_msg_data                 => vmsgdata,
                    x_header_rec               => lr_order_header_rec,
                    x_header_val_rec           => lr_order_header_val_rec,
                    x_header_adj_tbl           => lr_order_header_adj_tbl,
                    x_header_adj_val_tbl       => lr_order_hdr_adj_val_tbl,
                    x_header_price_att_tbl     => lr_order_hdr_pri_att_tbl,
                    x_header_adj_att_tbl       => lr_order_hdr_adj_att_tbl,
                    x_header_adj_assoc_tbl     => lr_order_hdr_adj_asc_tbl,
                    x_header_scredit_tbl       => lr_order_hdr_slcrtab,
                    x_header_scredit_val_tbl   => lr_order_hdr_scr_val_tbl,
                    x_line_tbl                 => lr_order_line_tab,
                    x_line_val_tbl             => lr_order_line_val_tbl,
                    x_line_adj_tbl             => lr_order_line_adj_tbl,
                    x_line_adj_val_tbl         => lr_order_line_adj_val_tbl,
                    x_line_price_att_tbl       => lr_order_line_pri_att_tbl,
                    x_line_adj_att_tbl         => lr_order_line_adj_att_tbl,
                    x_line_adj_assoc_tbl       => lr_order_line_adj_asc_tbl,
                    x_line_scredit_tbl         => lr_order_line_scredit_tbl,
                    x_line_scredit_val_tbl     => lr_order_line_scr_val_tbl,
                    x_lot_serial_tbl           => lr_order_lot_serial_tbl,
                    x_lot_serial_val_tbl       => lr_order_lot_serl_val_tbl,
                    x_action_request_tbl       => lr_order_request_tbl);

                IF vreturnstatus = fnd_api.g_ret_sts_success
                THEN
                    --x_err_msg := 'Scheduling lines are successful.';
                    ln_success_cnt   := ln_success_cnt + 1;
                    x_retcode        := 1;
                    COMMIT;
                ELSE
                    ROLLBACK;
                    ln_error_cnt   := ln_error_cnt + 1;
                    x_retcode      := 2;

                    FOR i IN 1 .. vmsgcount
                    LOOP
                        lc_msg       := NULL;
                        oe_msg_pub.get (p_msg_index => i, p_encoded => FND_API.G_FALSE, p_data => lc_msg
                                        , p_msg_index_out => LC_NEXT_MSG);

                        v_msg_data   := v_msg_data || lc_msg;
                    END LOOP;

                    -- Start of ExceptionHandling 10Dec15
                    XXD_MSC_ONT_ATP_LEVEL_PKG.XXD_UPDATE_ERROR_LOG (
                        pn_session_id,               --remove the pkg name NRK
                        rec_oe_line_dtls.order_header_id,
                        'proc_schdl_duplicate_lines',
                        v_msg_data);
                -- End of Exception Handling 10Dec15

                END IF;
            ELSE
                x_retcode   := 1;
                v_msg_data   :=
                       'There are no eligible order lines to Schedule.'
                    || vmsgdata;
                XXD_MSC_ONT_ATP_LEVEL_PKG.XXD_UPDATE_ERROR_LOG (pn_session_id, --remove the pkg name NRK
                                                                               rec_oe_line_dtls.order_header_id, 'proc_schdl_duplicate_lines'
                                                                , v_msg_data);
            END IF;
        END LOOP;

        ------------------------------------------------------------------------
        --This is to update the LAD as SSD+1 Logic

        IF cur_dup_line_dtls%ISOPEN
        THEN
            CLOSE cur_dup_line_dtls;
        END IF;

        FOR rec_oe_line_dtls IN cur_oe_line_dtls
        LOOP
            xxd_v_schdl_line_tbl.delete;

            OPEN cur_dup_line_dtls (rec_oe_line_dtls.order_header_id);

            FETCH cur_dup_line_dtls BULK COLLECT INTO xxd_v_schdl_line_tbl;

            CLOSE cur_dup_line_dtls;

            v_order_line_tab.delete;
            v_order_request_tbl.delete;
            v_msg_count     := NULL;
            v_msg_count     := NULL;
            vreturnstatus   := NULL;


            --Start changes on BT Technology Team on 18 Dec 15
            BEGIN
                ln_org_id   := NULL;

                SELECT org_id
                  INTO ln_org_id
                  FROM oe_order_headers_all
                 WHERE header_id = rec_oe_line_dtls.order_header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_org_id   := pn_org_id;
            END;

            --End changes on BT Technology Team on 18 Dec 15

            fnd_global.apps_initialize (user_id        => ln_user_id,
                                        resp_id        => ln_resp_id,
                                        resp_appl_id   => ln_resp_appl_id);
            mo_global.init ('ONT');
            mo_global.set_policy_context ('S', ln_org_id);
            oe_msg_pub.initialize;
            oe_debug_pub.initialize;

            FOR i IN 1 .. xxd_v_schdl_line_tbl.COUNT
            LOOP
                v_order_request_tbl (i)                       := oe_order_pub.g_miss_request_rec;

                -- update the latest acceptable date
                v_order_line_tab (i)                          := oe_order_pub.g_miss_line_rec;
                v_order_line_tab (i).operation                := OE_GLOBALS.G_OPR_UPDATE;
                v_order_line_tab (i).header_id                :=
                    xxd_v_schdl_line_tbl (i).header_id;
                v_order_line_tab (i).line_id                  :=
                    xxd_v_schdl_line_tbl (i).line_id;
                v_order_line_tab (i).latest_acceptable_date   :=
                    xxd_v_schdl_line_tbl (i).schedule_ship_date + 1;
                v_order_line_tab (i).org_id                   := ln_org_id;
            END LOOP;


            OE_ORDER_PUB.PROCESS_ORDER (
                -- Start modification by BT Technology Team on 18-Dec-15
                p_org_id                   => ln_org_id,
                -- End modification by BT Technology Team on 18-Dec-15
                p_api_version_number       => v_api_version_number,
                p_header_rec               => v_order_header_rec,
                p_line_tbl                 => v_order_line_tab,
                p_action_request_tbl       => v_order_request_tbl,
                p_line_adj_tbl             => v_line_adj_tbl  -- OUT variables
                                                            ,
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
                x_return_status            => vreturnstatus,
                x_msg_count                => v_msg_count,
                x_msg_data                 => v_msg_data);

            IF vreturnstatus = fnd_api.g_ret_sts_success
            THEN
                COMMIT;
                ln_success_count   := ln_success_count + 1;
                x_retcode          := 0;
            --'Latest Acceptable Date has been successfully updated..!!!';

            ELSE
                ln_error_count   := ln_error_count + 1;
                ROLLBACK;
                x_retcode        := 1;

                FOR i IN 1 .. v_msg_count
                LOOP
                    v_msg_data   :=
                        oe_msg_pub.get (p_msg_index => i, p_encoded => 'F');
                END LOOP;

                XXD_MSC_ONT_ATP_LEVEL_PKG.XXD_UPDATE_ERROR_LOG (pn_session_id, --remove the pkg name NRK
                                                                               rec_oe_line_dtls.order_header_id, 'proc_schdl_duplicate_lines Updating LAD'
                                                                , v_msg_data);
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            v_msg_data   := SQLERRM || SQLCODE;

            IF cur_dup_line_dtls%ISOPEN
            THEN
                CLOSE cur_dup_line_dtls;
            END IF;

            XXD_MSC_ONT_ATP_LEVEL_PKG.XXD_UPDATE_ERROR_LOG (pn_session_id, --remove the pkg name NRK
                                                                           '99999', 'proc_schdl_duplicate_lines Others' || SQLERRM || SQLCODE
                                                            , v_msg_data);
    END proc_schdl_duplicate_lines;

    FUNCTION from_details_temp (P_SESSION_ID NUMBER, P_ORDER_LINE_ID NUMBER)
        RETURN NUMBER
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;

        CURSOR cur_poh (cp_session_id     NUMBER,
                        cp_pegging_id     NUMBER,
                        cp_atp_run_date   DATE)
        IS
              SELECT supply_demand_date, net_qty, SUM (net_qty) OVER (ORDER BY supply_demand_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) poh
                FROM (SELECT cp_atp_run_date supply_demand_date, SUM (period_quantity) net_qty
                        FROM mrp_atp_details_temp
                       WHERE     session_id = cp_session_id
                             AND record_type = 1
                             AND pegging_id = cp_pegging_id
                             AND period_start_date <= cp_atp_run_date
                      UNION
                        SELECT TRUNC (period_start_date) supply_demand_date, SUM (period_quantity) net_qty
                          FROM mrp_atp_details_temp
                         WHERE     session_id = cp_session_id
                               AND record_type = 1
                               AND pegging_id = cp_pegging_id
                               AND TRUNC (period_start_date) > cp_atp_run_date
                      GROUP BY TRUNC (period_start_date))
            ORDER BY supply_demand_date;

        ld_plan_run_date         DATE := NULL;
        ln_pegging_id            NUMBER := NULL;
        ln_min_poh               NUMBER := NULL;
        ld_scheduled_ship_date   DATE;
        ld_temp_date             DATE;
    BEGIN
        BEGIN
            SELECT TRUNC (PLAN_COMPLETION_DATE)
              INTO ld_plan_run_date
              FROM msc_plans@bt_ebs_to_ascp mp, msc_designators@bt_ebs_to_ascp md
             WHERE     mp.compile_designator = md.designator
                   AND md.inventory_atp_flag = 1;

            LOG (' ld_plan_run_date : ' || ld_plan_run_date);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                LOG ('No Inventory ATP Plan has found' || SQLERRM || SQLCODE);
        END;

        BEGIN
            SELECT DISTINCT pegging_id
              INTO ln_pegging_id
              FROM mrp_atp_details_temp
             WHERE     order_line_id = P_ORDER_LINE_ID
                   AND record_type = 1
                   AND session_id = P_SESSION_ID;

            LOG (' ln_pegging_id : ' || ln_pegging_id);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                LOG (
                       'No Pegging_ID found Order_line_id '
                    || P_ORDER_LINE_ID
                    || ',Error : '
                    || SQLERRM
                    || SQLCODE);
        END;

        BEGIN
            SELECT TRUNC (scheduled_ship_date)
              INTO ld_scheduled_ship_date
              FROM mrp_atp_schedule_temp
             WHERE     session_id = p_session_id
                   AND order_line_id = p_order_line_id
                   AND status_flag = 2;

            LOG (' ld_scheduled_ship_date : ' || ld_scheduled_ship_date);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                LOG (
                       'No Schedule_ship Date found Order_line_id '
                    || P_ORDER_LINE_ID
                    || ',Error : '
                    || SQLERRM
                    || SQLCODE);
        END;

        FOR rec_atp
            IN cur_poh (p_session_id, ln_pegging_id, ld_plan_run_date)
        LOOP
            INSERT INTO xxd_cal_neg_atp_gt
                 VALUES (p_session_id, rec_atp.supply_demand_date, rec_atp.net_qty
                         , rec_atp.poh, NULL);
        END LOOP;

        IF ld_scheduled_ship_date <= ld_plan_run_date
        THEN
            ld_temp_date   := ld_plan_run_date;
        ELSE
            ld_temp_date   := ld_scheduled_ship_date;
        END IF;

        LOG ('ld_temp_date ' || ld_temp_date);

        BEGIN
              SELECT MIN (poh)
                INTO ln_min_poh
                FROM xxd_cal_neg_atp_gt
               WHERE     session_id = p_session_id
                     AND TRUNC (supply_demand_date) >= ld_temp_date
            ORDER BY supply_demand_date;
        END;

        LOG (' ld_temp_date : ' || ld_temp_date);
        LOG (' ln_min_poh   : ' || ln_min_poh);
        LOG (' p_session_id : ' || p_session_id);

        --INSERT INTO xxd_test123   SELECT * FROM xxd_cal_neg_atp_gt;                    -- for debugging

        DELETE FROM xxd_cal_neg_atp_gt
              WHERE session_id = p_session_id;

        COMMIT;

        RETURN ln_min_poh;
    EXCEPTION
        WHEN OTHERS
        THEN
            LOG ('In Exception ' || SQLERRM || SQLCODE);
            ROLLBACK;
            RETURN NULL;
    END from_details_temp;

    --------------------------------------------------------------------------------------------------------------
    PROCEDURE update_atp_temp_screen3 (p_session_id IN NUMBER)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        UPDATE mrp_atp_schedule_temp mast
           SET mast.exception15 = from_details_temp (mast.session_id, mast.order_line_id)
         WHERE session_id = p_session_id AND status_flag = 2;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            LOG (
                   'In Exception while updating mrp_atp_schedule_temp Table'
                || SQLERRM
                || SQLCODE);
            ROLLBACK;
    END update_atp_temp_screen3;
--------------------------------------------------------------------------------------------------------------
-- End of Changes by NRK -- 19 Nov 2015
--------------------------------------------------------------------------------------------------------------
END XXD_MSC_ONT_ATP_LEVEL_PKG;
/
