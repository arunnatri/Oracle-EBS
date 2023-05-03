--
-- XXD_ONT_DS_UPD_MS_EVENT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:45 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_DS_UPD_MS_EVENT_PKG"
AS
    /********************************************************************************************
      * Package         : XXD_ONT_DS_UPD_MS_EVENT_PKG
      * Description     : Package Body is for Direct Ship Mile Stone Event Updates in batch mode
      * Notes           : WEBADI
      * Modification    :
      *-----------------------------------------------------------------------------------------
      * Date         Version#      Name                       Description
      *-----------------------------------------------------------------------------------------
      * 15-NOV-2022  1.0           Aravind Kannuri            Initial Version for CCR0010296
      *
      ******************************************************************************************/

    -- =====================================================
    -- This procedure prints the Debug Messages in LOG FILE
    -- =====================================================
    PROCEDURE write_log (pv_msg IN VARCHAR2)
    AS
        lv_msg   VARCHAR2 (4000) := pv_msg;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, lv_msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Others Exception in write_log : ' || SQLERRM);
    END write_log;

    -- =====================================================
    -- This procedure prints the Debug Messages in OUT FILE
    -- =====================================================
    PROCEDURE write_out (pv_msg IN VARCHAR2)
    AS
        lv_msg   VARCHAR2 (4000) := pv_msg;
    BEGIN
        fnd_file.put_line (fnd_file.output, lv_msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.output,
                'Others Exception in write_output : ' || SQLERRM);
    END write_out;

    -- =====================================================
    -- This procedure inserts into xxd_wms_email_output_t
    -- =====================================================
    PROCEDURE insert_into_email_table (p_data IN xxd_wms_email_output_type)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        FORALL i IN p_data.FIRST .. p_data.LAST
            INSERT INTO xxdo.xxd_wms_email_output_t (
                            source,
                            request_id,
                            inv_org_code,
                            container_number,
                            order_number,
                            cust_po_number,
                            delivery_id,
                            old_triggering_event_name,
                            new_triggering_event_name,
                            status,
                            created_by,
                            creation_date,
                            last_update_date,
                            last_updated_by,
                            last_update_login)
                     VALUES ('WEBADI',
                             p_data (i).request_id,
                             p_data (i).inv_org_code,
                             p_data (i).container_number,
                             p_data (i).order_number,
                             p_data (i).cust_po_number,
                             p_data (i).delivery_id,
                             p_data (i).old_triggering_event_name,
                             p_data (i).new_triggering_event_name,
                             p_data (i).status,
                             p_data (i).created_by,
                             p_data (i).creation_date,
                             p_data (i).last_update_date,
                             p_data (i).last_updated_by,
                             p_data (i).last_update_login);

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END insert_into_email_table;

    -- =====================================================
    -- This Procedure to Generate and Update Seq_ID
    -- =====================================================
    FUNCTION update_stg_seq_id
        RETURN NUMBER
    IS
        ln_seq_id   NUMBER := 0;
    BEGIN
        BEGIN
            ln_seq_id   := xxdo.xxd_ont_ds_upd_ms_event_s.NEXTVAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_seq_id   := -99;
        END;

        BEGIN
            UPDATE xxdo.xxd_wms_email_output_t
               SET seq_id   = ln_seq_id
             WHERE     source = 'WEBADI'
                   AND NVL (status, 'N') IN ('N', 'S', 'E')
                   AND request_id = gn_request_id;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_seq_id   := -99;
        END;

        RETURN ln_seq_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_seq_id   := -99;
            RETURN ln_seq_id;
    END update_stg_seq_id;


    -- =====================================================
    -- This function to get email receipients
    -- =====================================================
    FUNCTION email_recipients (p_request_id NUMBER, p_called_from VARCHAR2)
        RETURN apps.do_mail_utils.tbl_recips
    IS
        lv_def_mail_recips   apps.do_mail_utils.tbl_recips;
        lv_appl_inst_name    VARCHAR2 (25) := NULL;

        CURSOR recipients_cur IS
            SELECT DISTINCT b.email_address email_id
              FROM wsh_grants_v a, fnd_user b
             WHERE     1 = 1
                   -- AND organization_code = 'USX'
                   AND role_name = 'Upgrade Role'
                   AND a.user_name = b.user_name
                   AND SYSDATE BETWEEN a.start_date
                                   AND NVL (a.end_date, SYSDATE + 1)
                   AND email_address IS NOT NULL
                   AND 'EVENTUPDATE' = p_called_from
                   AND EXISTS
                           (SELECT 1
                              FROM xxdo.xxd_wms_email_output_t c, apps.wsh_new_deliveries d
                             WHERE     c.request_id = p_request_id
                                   AND c.delivery_id = d.delivery_id
                                   AND a.organization_id = d.organization_id);
    BEGIN
        lv_def_mail_recips.delete;

        SELECT applications_system_name
          INTO lv_appl_inst_name
          FROM apps.fnd_product_groups;

        IF lv_appl_inst_name IN ('EBSPROD')
        THEN
            FOR recipients_rec IN recipients_cur
            LOOP
                lv_def_mail_recips (lv_def_mail_recips.COUNT + 1)   :=
                    recipients_rec.email_id;
            END LOOP;
        ELSE
            lv_def_mail_recips (lv_def_mail_recips.COUNT + 1)   :=
                'BTAppsNotification@deckers.com';
        END IF;

        RETURN lv_def_mail_recips;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_def_mail_recips (lv_def_mail_recips.COUNT + 1)   :=
                'Batch.OM@deckers.com';
            RETURN lv_def_mail_recips;
    END email_recipients;

    -- =====================================================
    -- This procedure sends email of output file
    -- =====================================================
    PROCEDURE email_output (p_request_id NUMBER)
    IS
        CURSOR report_cur IS
            SELECT container_number, order_number, cust_po_number,
                   delivery_id, old_triggering_event_name, new_triggering_event_name,
                   creation_date, fnd_global.user_name user_name
              FROM xxdo.xxd_wms_email_output_t
             WHERE request_id = p_request_id AND source = 'WEBADI';

        lv_def_mail_recips   apps.do_mail_utils.tbl_recips;
        lv_appl_inst_name    VARCHAR2 (25) := NULL;
        -- lv_email_lkp_type    VARCHAR2 (50) := 'XXD_NEG_ATP_RESCHEDULE_EMAIL';
        lv_inv_org_code      VARCHAR2 (3) := NULL;
        ln_ret_val           NUMBER := 0;
        lv_out_line          VARCHAR2 (1000);
        ln_counter           NUMBER := 0;
        ln_rec_cnt           NUMBER := 0;

        ex_no_sender         EXCEPTION;
        ex_no_recips         EXCEPTION;
    BEGIN
        --Getting the email recipients and assigning them to a table type variable
        lv_def_mail_recips   :=
            email_recipients (p_request_id, 'EVENTUPDATE');

        IF lv_def_mail_recips.COUNT < 1
        THEN
            RAISE ex_no_recips;
        ELSE
            --Getting the instance name
            BEGIN
                SELECT applications_system_name
                  INTO lv_appl_inst_name
                  FROM apps.fnd_product_groups;
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_log (
                        'Unable to fetch the File server name in email_output procedure');
            END;

            --CCR0009753
            apps.do_mail_utils.send_mail_header (fnd_profile.VALUE ('DO_DEF_ALERT_SENDER'), lv_def_mail_recips, 'Deckers Batch Update Milestone Event WebADI ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24MISS') || ' from ' || lv_appl_inst_name || ' instance'
                                                 , ln_ret_val);
            apps.do_mail_utils.send_mail_line (
                'Content-Type: multipart/mixed; boundary=boundarystring',
                ln_ret_val);
            apps.do_mail_utils.send_mail_line ('--boundarystring',
                                               ln_ret_val);
            apps.do_mail_utils.send_mail_line ('Content-Type: text/plain',
                                               ln_ret_val);
            apps.do_mail_utils.send_mail_line ('', ln_ret_val);

            apps.do_mail_utils.send_mail_line ('', ln_ret_val);


            apps.do_mail_utils.send_mail_line ('', ln_ret_val);
            apps.do_mail_utils.send_mail_line (
                'See attachment for report details.',
                ln_ret_val);
            apps.do_mail_utils.send_mail_line ('', ln_ret_val);
            apps.do_mail_utils.send_mail_line ('--boundarystring',
                                               ln_ret_val);
            apps.do_mail_utils.send_mail_line ('Content-Type: text/xls',
                                               ln_ret_val);
            apps.do_mail_utils.send_mail_line (
                   'Content-Disposition: attachment; filename="Deckers Batch Update Milestone Event WebADI Report output '
                || TO_CHAR (SYSDATE, 'MM-DD-YYYY HH24MISS')
                || '.xls"',
                ln_ret_val);
            apps.do_mail_utils.send_mail_line ('', ln_ret_val);

            apps.do_mail_utils.send_mail_line (
                   'Container Number'
                || CHR (9)
                || 'Order Number'
                || CHR (9)
                || 'Cust PO Number'
                || CHR (9)
                || 'Delivery'
                || CHR (9)
                || 'Triggering Event Old value'
                || CHR (9)
                || 'Triggering Event New value'
                || CHR (9)
                || 'Program Ran By'
                || CHR (9)
                || 'Program Run date/time',
                ln_ret_val);

            FOR report_rec IN report_cur
            LOOP
                lv_out_line   := NULL;
                lv_out_line   :=
                       report_rec.container_number
                    || CHR (9)
                    || report_rec.order_number
                    || CHR (9)
                    || report_rec.cust_po_number
                    || CHR (9)
                    || report_rec.delivery_id
                    || CHR (9)
                    || report_rec.old_triggering_event_name
                    || CHR (9)
                    || report_rec.new_triggering_event_name
                    || CHR (9)
                    || report_rec.user_name
                    || CHR (9)
                    || TO_CHAR (report_rec.creation_date,
                                'DD-MON-YYYY HH24:MI:SS AM')
                    || CHR (9);

                apps.do_mail_utils.send_mail_line (lv_out_line, ln_ret_val);
                ln_counter    := ln_counter + 1;
            END LOOP;

            write_log ('Final ln_ret_val : ' || ln_ret_val);

            apps.do_mail_utils.send_mail_close (ln_ret_val);
        END IF;
    EXCEPTION
        WHEN ex_no_sender
        THEN
            apps.do_mail_utils.send_mail_close (ln_ret_val);         --Be Safe
            write_log (
                'ex_no_sender : There is no sender configured. Check the profile value DO: Default Alert Sender');
        WHEN ex_no_recips
        THEN
            apps.do_mail_utils.send_mail_close (ln_ret_val);         --Be Safe
            write_log (
                'ex_no_recips : There are no recipients configured to receive the email. Check lookup for email id');
        WHEN OTHERS
        THEN
            apps.do_mail_utils.send_mail_close (ln_ret_val);         --Be Safe
            write_log ('Error in Procedure email_ouput -> ' || SQLERRM);
    END email_output;

    -- =====================================================
    -- This procedure inserts and Update New Mile stone
    -- =====================================================
    PROCEDURE insert_update_batch (p_org_code IN VARCHAR2, p_container_number IN VARCHAR2, p_order_number IN NUMBER
                                   , p_mile_stone_event IN VARCHAR2, x_return_status OUT VARCHAR2, x_error_msg OUT VARCHAR2)
    IS
        lv_error_msg        VARCHAR2 (4000) := NULL;
        lv_error_code       VARCHAR2 (4000) := NULL;
        ln_error_num        NUMBER;
        l_delimiter         VARCHAR2 (1) := '~';
        l_flag              VARCHAR2 (1) := 'N';
        l_index             NUMBER := 0;
        ln_request_id       NUMBER := gn_request_id;

        CURSOR get_deliveries IS                                    -- for US7
            SELECT delivery_data.container_number, delivery_data.order_number, delivery_data.cust_po_number,
                   delivery_data.old_triggering_event_name, delivery_data.delivery_id, new_triggering_event_name,
                   line_data, delivery_data.created_by, delivery_data.creation_date,
                   delivery_data.last_update_date, delivery_data.last_updated_by
              FROM (                                                 --for US7
                    SELECT wnd.attribute9 container_number, ooha.order_number, cust_po_number,
                           wnd.attribute7 old_triggering_event_name, wnd.delivery_id, p_mile_stone_event new_triggering_event_name,
                           fnd_global.user_id created_by, SYSDATE creation_date, SYSDATE last_update_date,
                           fnd_global.user_id last_updated_by, (wnd.attribute9 || l_delimiter || ooha.order_number || l_delimiter || cust_po_number || l_delimiter || wnd.delivery_id || l_delimiter || wnd.attribute7 || l_delimiter || p_mile_stone_event || l_delimiter || fnd_global.user_name || l_delimiter || SYSDATE) line_data
                      FROM apps.oe_order_headers_all ooha, apps.wsh_new_deliveries wnd, apps.org_organization_definitions ood
                     WHERE     ooha.header_id = wnd.source_header_id
                           AND ooha.sold_to_org_id = wnd.customer_id
                           AND wnd.organization_id = ood.organization_id
                           AND ood.organization_code = p_org_code        --USX
                           AND wnd.attribute9 = p_container_number
                           AND order_number =
                               NVL (p_order_number, order_number)
                           AND ooha.open_flag = 'Y'
                           AND wnd.status_code = 'OP'
                           AND (   ooha.order_type_id =
                                   (SELECT transaction_type_id
                                      FROM apps.oe_transaction_types_tl ottl
                                     WHERE     ottl.name =
                                               'Direct Ship OriginHub-US'
                                           AND ottl.language =
                                               USERENV ('LANG'))
                                OR ooha.ship_from_org_id IN
                                       (SELECT organization_id
                                          FROM fnd_lookup_values A, MTL_PARAMETERS b
                                         WHERE     1 = 1
                                               AND lookup_type =
                                                   'XXD_ODC_ORG_CODE_LKP'
                                               AND enabled_flag = 'Y'
                                               AND a.lookup_code =
                                                   b.organization_code
                                               AND language =
                                                   USERENV ('LANG')
                                               AND SYSDATE BETWEEN start_date_active
                                                               AND NVL (
                                                                       end_date_active,
                                                                         SYSDATE
                                                                       + 1)))
                    UNION
                    -- for USX
                    SELECT ship.container_ref container_number, ooha.order_number, cust_po_number,
                           wnd.attribute7 old_triggering_event_name, wnd.delivery_id, p_mile_stone_event new_triggering_event_name,
                           fnd_global.user_id created_by, SYSDATE creation_date, SYSDATE last_update_date,
                           fnd_global.user_id last_updated_by, (ship.container_ref || l_delimiter || ooha.order_number || l_delimiter || cust_po_number || l_delimiter || wnd.delivery_id || l_delimiter || wnd.attribute7 || l_delimiter || p_mile_stone_event || l_delimiter || fnd_global.user_name || l_delimiter || SYSDATE) line_data
                      FROM apps.oe_order_headers_all ooha,
                           apps.wsh_new_deliveries wnd,
                           apps.org_organization_definitions ood,
                           (SELECT DISTINCT s.asn_reference_no, s.vessel_name, s.etd,
                                            s.bill_of_lading, c.container_ref, i.atr_number
                              FROM custom.do_shipments s, custom.do_containers c, custom.do_items i
                             WHERE     s.shipment_id = c.shipment_id
                                   AND c.container_id = i.container_id) ship
                     WHERE     ooha.header_id = wnd.source_header_id
                           AND ooha.sold_to_org_id = wnd.customer_id
                           AND wnd.organization_id = ood.organization_id
                           AND ood.organization_code = p_org_code        --USX
                           AND wnd.attribute8 = ship.atr_number
                           AND ooha.open_flag = 'Y'
                           AND wnd.status_code = 'OP'
                           AND ship.container_ref = p_container_number
                           AND order_number =
                               NVL (p_order_number, order_number)
                           AND (ooha.order_type_id =
                                (SELECT transaction_type_id
                                   FROM apps.oe_transaction_types_tl ottl
                                  WHERE     ottl.name = 'Direct Ship - US'
                                        AND ottl.language = USERENV ('LANG'))))
                   delivery_data,
                   apps.wsh_new_deliveries wnd1
             WHERE     1 = 1
                   AND wnd1.delivery_id = delivery_data.delivery_id
                   AND wnd1.status_code = 'OP';

        TYPE xxd_delivery_typ IS TABLE OF get_deliveries%ROWTYPE;

        TYPE type_email_data IS TABLE OF xxdo.xxd_wms_email_output_t%ROWTYPE;

        v_type_email_data   xxd_wms_email_output_type
                                := xxd_wms_email_output_type ();

        v_ins_type          xxd_delivery_typ := xxd_delivery_typ ();
        v_ins_type_1        xxd_delivery_typ := xxd_delivery_typ ();


        l_header            VARCHAR2 (1000)
            := 'Container Number~Order Number~Cust PO Number~Delivery~Triggering Event Old value~Triggering Event New value~Program Ran By~Program Run date/time';
        l_data              VARCHAR2 (4000) := NULL;
    BEGIN
        -- Either of the parameter is mandatory for the query
        IF p_org_code IS NOT NULL AND p_container_number IS NOT NULL
        THEN
            write_out (l_header);

            OPEN get_deliveries;

            LOOP
                FETCH get_deliveries BULK COLLECT INTO v_ins_type LIMIT 1000;


                IF (v_ins_type.COUNT > 0)
                THEN
                    l_flag   := 'Y';

                    BEGIN
                        FORALL i IN v_ins_type.FIRST .. v_ins_type.LAST
                          SAVE EXCEPTIONS
                            UPDATE wsh_new_deliveries
                               SET attribute7 = v_ins_type (i).new_triggering_event_name, last_update_date = SYSDATE, last_updated_by = fnd_global.user_id
                             WHERE delivery_id = v_ins_type (i).delivery_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                            LOOP
                                ln_error_num   :=
                                    SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                                lv_error_code   :=
                                    SQLERRM (
                                          -1
                                        * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                                lv_error_msg   :=
                                    SUBSTR (
                                        (lv_error_msg || ' Error While updating deliveries' || v_ins_type (ln_error_num).delivery_id || lv_error_code || ' #'),
                                        1,
                                        4000);
                                write_log (
                                       ln_error_num
                                    || lv_error_code
                                    || lv_error_msg);
                            END LOOP;
                    END;
                ELSE
                    l_flag   := 'N';
                    lv_error_msg   :=
                        'Cursor query not fetched data for Input parameter- Org and Container.';
                    write_log (
                        'Cursor query not fetched for Input parameter- Org and Container.');
                END IF;

                IF (v_ins_type.COUNT > 0)
                THEN
                    FOR i IN v_ins_type.FIRST .. v_ins_type.LAST
                    LOOP
                        l_index                                        := l_index + 1;

                        v_type_email_data (l_index).container_number   :=
                            v_ins_type (i).container_number;
                        v_type_email_data (l_index).order_number       :=
                            v_ins_type (i).order_number;
                        v_type_email_data (l_index).delivery_id        :=
                            v_ins_type (i).delivery_id;
                        v_type_email_data (l_index).cust_po_number     :=
                            v_ins_type (i).cust_po_number;
                        v_type_email_data (l_index).old_triggering_event_name   :=
                            v_ins_type (i).old_triggering_event_name;
                        v_type_email_data (l_index).new_triggering_event_name   :=
                            v_ins_type (i).new_triggering_event_name;
                        v_type_email_data (l_index).created_by         :=
                            v_ins_type (i).created_by;
                        v_type_email_data (l_index).request_id         :=
                            ln_request_id;
                        v_type_email_data (l_index).creation_date      :=
                            v_ins_type (i).creation_date;
                        v_type_email_data (l_index).last_update_date   :=
                            v_ins_type (i).last_update_date;
                        v_type_email_data (l_index).last_updated_by    :=
                            v_ins_type (i).last_updated_by;
                        v_type_email_data (l_index).inv_org_code       :=
                            p_org_code;
                        v_type_email_data (l_index).source             :=
                            'WEBADI';
                        v_type_email_data (l_index).status             := 'N';

                        write_out (v_ins_type (i).line_data);
                    END LOOP;

                    insert_into_email_table (v_type_email_data);
                END IF;

                EXIT WHEN get_deliveries%NOTFOUND;
            END LOOP;

            CLOSE get_deliveries;
        ELSE
            lv_error_msg   := 'Mandatory Parameters Validation Failure.';
            write_log ('Mandatory Parameters Validation Failure.');
        END IF;

        IF l_flag = 'N'  -- L_FLAG = 'N' means no record fetehed in the cursor
        THEN
            lv_error_msg      :=
                '***No Deliveries Identified for UPDATE\INSERT***';
            write_log ('***No Deliveries Identified for UPDATE\INSERT***');
            x_return_status   := 'E';
            x_error_msg       := lv_error_msg;
        END IF;
    -- email_output (ln_request_id);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_status   := 'E';
            x_error_msg       :=
                'EXP - Others in insert_update_batch :' || lv_error_msg;
    END insert_update_batch;

    --Upload Procedure called by WebADI - MAIN
    PROCEDURE batch_upload (p_inv_org_code IN VARCHAR2, p_container_number IN VARCHAR2, p_order_number IN NUMBER DEFAULT NULL, p_mile_stone_event IN VARCHAR2, p_attribute_num1 IN NUMBER DEFAULT NULL, p_attribute_num2 IN NUMBER DEFAULT NULL, p_attribute_chr1 IN VARCHAR2 DEFAULT NULL, p_attribute_chr2 IN VARCHAR2 DEFAULT NULL, p_attribute_date1 IN DATE DEFAULT NULL
                            , p_attribute_date2 IN DATE DEFAULT NULL)
    IS
        lv_opr_mode           VARCHAR2 (30) := 'UPDATE';
        lv_source             VARCHAR2 (50) := 'WEBADI';
        lv_container_num      VARCHAR2 (250) := NULL;
        ln_inv_org_exists     NUMBER := 0;
        lv_resp_sufix         VARCHAR2 (50) := NULL;

        lv_error_message      VARCHAR2 (4000) := NULL;
        lv_upload_status      VARCHAR2 (1) := 'N';
        lv_return_status      VARCHAR2 (1) := NULL;
        lv_errbuf             VARCHAR2 (4000) := NULL;
        lv_ret_code           NUMBER := 0;
        le_webadi_exception   EXCEPTION;
        ld_new_exp_rcpt_dt    DATE := NULL;
        lx_asn_upd_sts        VARCHAR2 (1) := NULL;
        lx_asn_upd_msg        VARCHAR2 (2000) := NULL;
    BEGIN
        -- WEBADI Validations Start

        --Validate Mandatory parameters
        IF ((p_inv_org_code IS NULL) OR (p_container_number IS NULL) OR (p_mile_stone_event IS NULL))
        THEN
            lv_error_message   :=
                'Inventory Organization or Container Number or New Milestone Event is missing. All these are MANDATORY. ';
            lv_upload_status   := gv_ret_error;
            RAISE le_webadi_exception;
        END IF;

        --Validate Inventory Organization
        IF p_inv_org_code IS NOT NULL
        THEN
            BEGIN
                SELECT COUNT (fvl.flex_value)
                  INTO ln_inv_org_exists
                  FROM fnd_flex_values_vl fvl, fnd_flex_value_sets fvs
                 WHERE     fvl.flex_value_set_id = fvs.flex_value_set_id
                       AND fvl.enabled_flag = 'Y'
                       AND fvl.flex_value = p_inv_org_code
                       AND NVL (fvl.start_date_active, TRUNC (SYSDATE)) <=
                           TRUNC (SYSDATE)
                       AND NVL (fvl.end_date_active, TRUNC (SYSDATE)) >=
                           TRUNC (SYSDATE)
                       AND flex_value_set_name = 'XXD_ONT_DS_ORG_CODE_VS';
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_inv_org_exists   := -1;
            END;
        END IF;

        IF NVL (ln_inv_org_exists, 0) <= 0
        THEN
            lv_error_message   :=
                   lv_error_message
                || ' '
                || p_inv_org_code
                || ' -Inventory Organization is not defined in Valueset.';
            lv_upload_status   := gv_ret_error;
        END IF;

        IF lv_upload_status = gv_ret_error OR lv_error_message IS NOT NULL
        THEN
            RAISE le_webadi_exception;
        END IF;

        --Loading WebADI data
        IF lv_upload_status <> gv_ret_error AND lv_error_message IS NULL
        THEN
            BEGIN
                --Calling batch upload procedure
                insert_update_batch (
                    p_org_code           => p_inv_org_code,
                    p_container_number   => p_container_number,
                    p_order_number       => p_order_number,
                    p_mile_stone_event   => p_mile_stone_event,
                    x_return_status      => lv_return_status,
                    x_error_msg          => lv_error_message);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_return_status   := gv_ret_error;
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || ' - Error inserting\updating into staging table: ',
                            1,
                            2000);
                    RAISE le_webadi_exception;
            END;
        END IF;

        IF lv_return_status <> gv_ret_success
        THEN
            --Update Stagging table with Status 'E'
            UPDATE xxdo.xxd_wms_email_output_t
               SET status = 'E', error_message = lv_error_message
             WHERE     1 = 1
                   AND request_id = gn_request_id
                   AND inv_org_code = p_inv_org_code
                   AND container_number = p_container_number
                   AND new_triggering_event_name = p_mile_stone_event;

            COMMIT;
        ELSE
            --Update Stagging table with Status 'S'
            UPDATE xxdo.xxd_wms_email_output_t
               SET status   = 'S'
             WHERE     1 = 1
                   AND request_id = gn_request_id
                   AND inv_org_code = p_inv_org_code
                   AND container_number = p_container_number
                   AND new_triggering_event_name = p_mile_stone_event;

            COMMIT;
        END IF;

        IF lv_return_status <> gv_ret_success
        THEN
            lv_error_message   :=
                SUBSTR (
                       'NEW- Milestone Event Update failure- '
                    || lv_error_message,
                    1,
                    2000);
            RAISE le_webadi_exception;
        END IF;

        write_log (
               'NEW- Milestone Event Update Status => '
            || lv_return_status
            || ' and Message => '
            || lv_error_message);
    EXCEPTION
        WHEN le_webadi_exception
        THEN
            lv_error_message   := SUBSTR (lv_error_message, 1, 2000);
            fnd_message.set_name ('XXDO', 'XXD_ONT_DS_UPD_MS_EVENT_MSG'); --Using an existing Message as this is Just a place holder
            fnd_message.set_token ('ERROR_MESSAGE', lv_error_message);
            lv_error_message   := fnd_message.get ();
            raise_application_error (-20000, lv_error_message);
        WHEN OTHERS
        THEN
            lv_error_message   :=
                SUBSTR (lv_error_message || '.' || SQLERRM, 1, 2000);
            fnd_message.set_name ('XXDO', 'XXD_ONT_DS_UPD_MS_EVENT_MSG'); --Using an existing Message as this is Just a place holder
            fnd_message.set_token ('ERROR_MESSAGE', lv_error_message);
            lv_error_message   := fnd_message.get ();
            raise_application_error (-20000, lv_error_message);
    END batch_upload;

    --Procedure called by concurrent program
    PROCEDURE import_pro (pv_errbuf OUT VARCHAR2, pv_retcode OUT NUMBER)
    IS
        CURSOR c_ms_event_dtls IS
            SELECT container_number, inv_org_code, order_number,
                   cust_po_number, delivery_id, old_triggering_event_name,
                   new_triggering_event_name, creation_date, fnd_global.user_name user_name
              FROM xxdo.xxd_wms_email_output_t stg
             WHERE     request_id = gn_request_id
                   AND NVL (status, 'N') = 'N'
                   AND source = 'WEBADI';

        --Variables Declaration
        ln_seq_id                NUMBER := 0;
        ln_new_rec_cnt           NUMBER := 0;
        lv_error_message         VARCHAR2 (2000);
        lv_return_status         VARCHAR2 (1) := NULL;
        lv_pro_error_msg         VARCHAR2 (2000);
        le_pro_error_exception   EXCEPTION;
    BEGIN
        --Initialization
        write_log ('Procedure import_pro starts ');
        mo_global.init ('WMS');                                          --BNE

        --Updating staging table with request_id
        BEGIN
            UPDATE xxdo.xxd_wms_email_output_t
               SET request_id   = gn_request_id
             WHERE     status IN ('N', 'S', 'E')
                   AND source = 'WEBADI'
                   AND created_by = gn_user_id
                   AND TRUNC (creation_date) = TRUNC (SYSDATE)
                   AND request_id = -1;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_return_status   := gv_ret_error;
                lv_error_message   :=
                    SUBSTR (
                           'Error while Updation of Request_Id in Staging :'
                        || SQLERRM,
                        1,
                        2000);

                write_log ('lv_error_message :' || lv_error_message);
                pv_retcode         := gn_error;                           --2;
                pv_errbuf          := lv_error_message;
                RAISE;
        END;

        BEGIN
            SELECT COUNT (*)
              INTO ln_new_rec_cnt
              FROM xxdo.xxd_wms_email_output_t
             WHERE 1 = 1 AND source = 'WEBADI' AND request_id = gn_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_new_rec_cnt   := 0;
        END;

        write_log (
            'NEW Milestone Update Records Count => ' || ln_new_rec_cnt);

        IF NVL (ln_new_rec_cnt, 0) = 0
        THEN
            lv_pro_error_msg   := 'No NEW Milestone records to process ';
            write_log ('No NEW Milestone records to process ');
        --RAISE le_pro_error_exception;
        END IF;

        IF NVL (ln_new_rec_cnt, 0) > 0
        THEN
            --Calling Function to update Batch Seq_Id
            ln_seq_id   := update_stg_seq_id;
            write_log (
                   'Request_ID => '
                || gn_request_id
                || ' and Batch Seq_Id => '
                || ln_seq_id);

            IF (NVL (ln_seq_id, 0) > 0)
            THEN
                lv_pro_error_msg   :=
                       lv_pro_error_msg
                    || ' NEW: Batch Seq_ID generated => '
                    || ln_seq_id;

                --Updating staging table with Batch Seq_ID
                BEGIN
                    UPDATE xxdo.xxd_wms_email_output_t
                       SET seq_id   = ln_seq_id
                     WHERE     source = 'WEBADI'
                           AND created_by = gn_user_id
                           AND TRUNC (creation_date) = TRUNC (SYSDATE)
                           AND seq_id IS NULL
                           AND request_id = gn_request_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_return_status   := gv_ret_error;
                        lv_error_message   :=
                            SUBSTR (
                                   'Error while Updation of Seq_Id in Staging :'
                                || SQLERRM,
                                1,
                                2000);

                        write_log ('lv_error_message :' || lv_error_message);
                        pv_retcode         := gn_error;                   --2;
                        pv_errbuf          := lv_error_message;
                        RAISE;
                END;
            ELSE
                lv_pro_error_msg   :=
                       lv_pro_error_msg
                    || ' NEW: Batch Seq_ID generation failure => '
                    || ln_seq_id;
            END IF;

            --Calling Email procedure to send Outfile by Email
            email_output (gn_request_id);
        END IF;

        write_log ('Procedure import_pro end ');
        pv_errbuf    := NULL;
        pv_retcode   := gn_success;
    EXCEPTION
        WHEN le_pro_error_exception
        THEN
            COMMIT;
            raise_application_error (-20000, lv_pro_error_msg);
        WHEN OTHERS
        THEN
            COMMIT;
            lv_pro_error_msg   :=
                SUBSTR (lv_pro_error_msg || SQLERRM, 1, 2000);
            fnd_file.put_line (fnd_file.LOG, lv_pro_error_msg);
            pv_retcode   := gn_error;                                     --2;
            RAISE;
    END import_pro;
END XXD_ONT_DS_UPD_MS_EVENT_PKG;
/
