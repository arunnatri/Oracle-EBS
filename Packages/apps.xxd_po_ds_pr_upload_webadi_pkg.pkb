--
-- XXD_PO_DS_PR_UPLOAD_WEBADI_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:52 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PO_DS_PR_UPLOAD_WEBADI_PKG"
IS
    /****************************************************************************************
    * Package      : XXD_PO_DS_PR_UPLOAD_WEBADI_PKG
    * Design       : Package is used to create Purchase Requisitions.
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 19-JUL-2021  1.0        Tejaswi Gangumalla     Initial Version
    ******************************************************************************************/
    gn_user_id                  CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id                 CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id                   CONSTANT NUMBER := fnd_profile.VALUE ('ORG_ID');
    gn_resp_id                  CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id             CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_request_id               CONSTANT NUMBER := fnd_global.conc_request_id;
    gv_mo_profile_option_name   CONSTANT VARCHAR2 (240)
                                             := 'MO: Security Profile' ;
    gv_responsibility_name      CONSTANT VARCHAR2 (240)
        := 'Deckers Purchasing User - Global' ;

    --Main Procedure called by WebADI
    PROCEDURE upload_proc (pv_org_code VARCHAR2, pv_order_number VARCHAR2, pv_attribute1 NUMBER DEFAULT NULL, pv_attribute2 NUMBER DEFAULT NULL, pv_attribute3 VARCHAR2 DEFAULT NULL, pv_attribute4 VARCHAR2 DEFAULT NULL, pv_attribute5 VARCHAR2 DEFAULT NULL, pv_attribute6 VARCHAR2 DEFAULT NULL, pv_attribute7 VARCHAR2 DEFAULT NULL
                           , pv_attribute8 VARCHAR2 DEFAULT NULL, pv_attribute9 VARCHAR2 DEFAULT NULL, pv_attribute10 VARCHAR2 DEFAULT NULL)
    IS
        lv_error_message         VARCHAR2 (4000) := NULL;
        le_webadi_exception      EXCEPTION;
        ln_header_id             NUMBER;
        ln_org_id                NUMBER;
        ln_count                 NUMBER;
        ln_pr_exist              NUMBER;
        ln_operating_unit_id     NUMBER;
        v_x_error_msg_count      NUMBER;
        v_x_hold_result_out      VARCHAR2 (1);
        v_x_hold_return_status   VARCHAR2 (1);
        v_x_error_msg            VARCHAR2 (150);
    BEGIN
        IF pv_org_code IS NULL OR pv_order_number IS NULL
        THEN
            lv_error_message   :=
                'Direct Ship Org,Sales Order Number are Mandatory. One or more mandatory columns are missing. ';
            RAISE le_webadi_exception;
        END IF;

        BEGIN
            SELECT organization_id, operating_unit
              INTO ln_org_id, ln_operating_unit_id
              FROM org_organization_definitions
             WHERE organization_code = pv_org_code;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lv_error_message   :=
                       lv_error_message
                    || 'Invalid Organization Code: '
                    || pv_org_code
                    || '. ';
            WHEN OTHERS
            THEN
                lv_error_message   :=
                    SUBSTR (
                           lv_error_message
                        || 'Error While Validating Organization Code: '
                        || pv_org_code
                        || ' '
                        || SQLERRM
                        || '. ',
                        1,
                        2000);
        END;

        BEGIN
            SELECT header_id
              INTO ln_header_id
              FROM oe_order_headers_all ooh
             WHERE     order_number = pv_order_number
                   AND flow_status_code = 'BOOKED'
                   AND EXISTS
                           (SELECT 1
                              FROM oe_order_lines_all ool
                             WHERE     ool.header_id = ooh.header_id
                                   AND ship_from_org_id = ln_org_id);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lv_error_message   :=
                       lv_error_message
                    || 'Invalid Sales Order: '
                    || pv_order_number
                    || '. ';
            WHEN OTHERS
            THEN
                lv_error_message   :=
                    SUBSTR (
                           lv_error_message
                        || 'Error While Validating Sales Order: '
                        || pv_order_number
                        || ' '
                        || SQLERRM
                        || '. ',
                        1,
                        2000);
        END;

        BEGIN
            SELECT COUNT (*)
              INTO ln_pr_exist
              FROM po_requisition_headers_all
             WHERE interface_source_line_id IN
                       (SELECT line_id
                          FROM oe_order_lines_all
                         WHERE header_id = ln_header_id);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_message   :=
                    SUBSTR (
                           lv_error_message
                        || 'Error While Validating Requisition Already Exits: '
                        || SQLERRM
                        || '. ',
                        1,
                        2000);
        END;

        IF ln_pr_exist > 0
        THEN
            lv_error_message   :=
                SUBSTR (
                       lv_error_message
                    || 'Requisition already exists for the sales order'
                    || '.',
                    1,
                    2000);
        ELSE
            BEGIN
                SELECT COUNT (*)
                  INTO ln_pr_exist
                  FROM oe_order_lines_all ool
                 WHERE     header_id = ln_header_id
                       AND EXISTS
                               (SELECT 1
                                  FROM po_requisitions_interface_all
                                 WHERE     interface_source_line_id =
                                           ool.line_id
                                       AND process_flag IS NULL);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || 'Error While Validating Requisition Already Exits In Interface: '
                            || SQLERRM
                            || '. ',
                            1,
                            2000);
            END;

            IF ln_pr_exist > 0
            THEN
                lv_error_message   :=
                    SUBSTR (
                           lv_error_message
                        || 'Requisition already exists for the sales order In Interface'
                        || '.',
                        1,
                        2000);
            END IF;
        END IF;

        BEGIN
            SELECT COUNT (*)
              INTO ln_count
              FROM (  SELECT COUNT (*)
                        FROM oe_order_lines_all
                       WHERE     header_id = ln_header_id
                             AND NVL (cancelled_flag, 'N') = 'N'
                    GROUP BY inventory_item_id
                      HAVING COUNT (*) > 1);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_message   :=
                    SUBSTR (
                           lv_error_message
                        || 'Error While Validating Multiple Items in Sales Order: '
                        || SQLERRM
                        || '. ',
                        1,
                        2000);
        END;

        IF ln_count > 0
        THEN
            lv_error_message   :=
                SUBSTR (
                       lv_error_message
                    || 'Sales Order has one or more lines with same Item'
                    || '.',
                    1,
                    2000);
        END IF;

        FOR i IN (SELECT *
                    FROM oe_order_lines_all
                   WHERE header_id = ln_header_id)
        LOOP
            BEGIN
                oe_holds_pub.check_holds (
                    p_api_version     => 1.0,
                    p_line_id         => TO_NUMBER (i.line_id),
                    p_wf_item         => 'OEOL',
                    p_wf_activity     => 'CREATE_SUPPLY',
                    x_result_out      => v_x_hold_result_out,
                    ---if t hold
                    x_return_status   => v_x_hold_return_status,
                    x_msg_count       => v_x_error_msg_count,
                    x_msg_data        => v_x_error_msg);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || 'Exception While Checking Sales Order Hold: '
                            || SQLERRM
                            || '.',
                            1,
                            2000);
            END;

            IF (v_x_hold_result_out = fnd_api.g_true)
            THEN
                lv_error_message   :=
                    SUBSTR (
                        lv_error_message || 'Sales Order is on hold' || '.',
                        1,
                        2000);
                EXIT;
            END IF;
        END LOOP;

        IF lv_error_message IS NULL
        THEN
            BEGIN
                INSERT INTO xxd_po_ds_pr_upd_t (organization_code,
                                                order_number,
                                                org_id,
                                                organization_id,
                                                autocreate_pr_request_id,
                                                interface_batch_id,
                                                requisition_number,
                                                request_id,
                                                status,
                                                error_message,
                                                created_by,
                                                creation_date,
                                                last_updated_by,
                                                last_update_date)
                     VALUES (pv_org_code, pv_order_number, ln_operating_unit_id, ln_org_id, NULL, NULL, NULL, gn_request_id, 'N', NULL, gn_user_id, SYSDATE
                             , gn_user_id, SYSDATE);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || 'Exception While Inserting Into Staging Table: '
                            || SQLERRM
                            || '.',
                            1,
                            2000);
            END;
        ELSE
            RAISE le_webadi_exception;
        END IF;
    EXCEPTION
        WHEN le_webadi_exception
        THEN
            lv_error_message   := SUBSTR (lv_error_message, 1, 2000);
            fnd_message.set_name ('XXDO', 'XXD_PR_UPLOAD_WEBADI_MSG');
            fnd_message.set_token ('ERROR_MESSAGE', lv_error_message);
            lv_error_message   := fnd_message.get ();
            raise_application_error (-20000, lv_error_message);
        WHEN OTHERS
        THEN
            lv_error_message   :=
                SUBSTR (lv_error_message || '.' || SQLERRM, 1, 2000);
            fnd_message.set_name ('XXDO', 'XXD_PR_UPLOAD_WEBADI_MSG');
            fnd_message.set_token ('ERROR_MESSAGE', lv_error_message);
            lv_error_message   := fnd_message.get ();
            raise_application_error (-20000, lv_error_message);
    END upload_proc;

    PROCEDURE submit_autocreate_pr
    IS
        CURSOR org_id_cur IS
            SELECT DISTINCT org_id
              FROM xxdo.xxd_po_ds_pr_upd_t
             WHERE request_id = gn_request_id AND status = 'N';

        CURSOR order_data_cur (cn_org_id NUMBER)
        IS
            SELECT *
              FROM xxdo.xxd_po_ds_pr_upd_t
             WHERE     request_id = gn_request_id
                   AND status = 'N'
                   AND org_id = cn_org_id;

        ln_resp_id        NUMBER;
        ln_resp_appl_id   NUMBER;
        ln_request_id     NUMBER;
        ln_count          NUMBER := 0;
        ln_max_count      NUMBER := 10;
    BEGIN
        FOR org_id_rec IN org_id_cur
        LOOP
            BEGIN
                SELECT frv.responsibility_id, frv.application_id resp_application_id
                  INTO ln_resp_id, ln_resp_appl_id
                  FROM apps.fnd_profile_options_vl fpo, apps.fnd_profile_option_values fpov, apps.fnd_responsibility_vl frv
                 WHERE     fpo.user_profile_option_name =
                           gv_mo_profile_option_name
                       AND fpo.profile_option_id = fpov.profile_option_id
                       AND fpov.level_value = frv.responsibility_id
                       AND frv.responsibility_name = gv_responsibility_name
                       AND fpov.profile_option_value IN
                               (SELECT security_profile_id
                                  FROM apps.per_security_organizations
                                 WHERE organization_id = org_id_rec.org_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_resp_id   := NULL;
            END;

            IF ln_resp_id IS NOT NULL
            THEN
                --do intialize and purchssing setup
                apps.fnd_global.apps_initialize (gn_user_id,
                                                 ln_resp_id,
                                                 ln_resp_appl_id);
                mo_global.init ('PO');
                mo_global.set_policy_context ('S', org_id_rec.org_id);
                fnd_request.set_org_id (org_id_rec.org_id);
            END IF;

            FOR order_data_rec IN order_data_cur (org_id_rec.org_id)
            LOOP
                LOOP
                    BEGIN
                        SELECT COUNT (*)
                          INTO ln_count
                          FROM fnd_concurrent_requests
                         WHERE     request_id IN
                                       (SELECT autocreate_pr_request_id
                                          FROM xxdo.xxd_po_ds_pr_upd_t
                                         WHERE     status = 'N'
                                               AND request_id = gn_request_id)
                               AND phase_code IN ('R', 'P');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_count   := 0;
                    END;

                    IF ln_count >= ln_max_count
                    THEN
                        DBMS_LOCK.sleep (3);
                    ELSE
                        EXIT;
                    END IF;
                END LOOP;

                ln_request_id   :=
                    apps.fnd_request.submit_request (
                        application   => 'BOM',
                        program       => 'CTOACREQ',
                        argument1     => order_data_rec.order_number,
                        argument2     => '',
                        argument3     => '',
                        argument4     => '',
                        --order_data_rec.organization_id,
                        argument5     => '',
                        --order_data_rec.organization_id,
                        argument6     => '');
                COMMIT;

                IF ln_request_id IS NOT NULL
                THEN
                    BEGIN
                        UPDATE xxdo.xxd_po_ds_pr_upd_t
                           SET autocreate_pr_request_id   = ln_request_id
                         WHERE     order_number = order_data_rec.order_number
                               AND status = 'N'
                               AND request_id = gn_request_id;

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Error While updating staging table with autocreate_pr_request_id');
                    END;
                END IF;
            END LOOP;
        END LOOP;

        LOOP
            BEGIN
                SELECT COUNT (*)
                  INTO ln_count
                  FROM fnd_concurrent_requests
                 WHERE     request_id IN
                               (SELECT autocreate_pr_request_id
                                  FROM xxdo.xxd_po_ds_pr_upd_t
                                 WHERE     status = 'N'
                                       AND request_id = gn_request_id)
                       AND phase_code IN ('R', 'P');
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_count   := 0;
            END;

            IF ln_count >= 1
            THEN
                DBMS_LOCK.sleep (5);
            ELSE
                EXIT;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Error in submit_autocreate_pr procedure');
    END submit_autocreate_pr;

    PROCEDURE batch_interface_records
    IS
        ln_max_req        NUMBER := 10;
        ln_tot_count      NUMBER;
        ln_req            NUMBER;
        ln_min_batch_id   NUMBER;
        ln_from_seq_num   NUMBER := 0;
        ln_to_seq_num     NUMBER := 0;
        ln_minbatch_id    NUMBER;
    BEGIN
        BEGIN
            UPDATE xxdo.xxd_po_ds_pr_upd_t stg1
               SET interface_batch_id   =
                       (SELECT pri.batch_id
                          FROM po_requisitions_interface_all pri, xxdo.xxd_po_ds_pr_upd_t stg, oe_order_headers_all ooh,
                               oe_order_lines_all ool
                         WHERE     stg.order_number = ooh.order_number
                               AND ooh.header_id = ool.header_id
                               AND ool.line_id = pri.interface_source_line_id
                               AND stg1.order_number = stg.order_number
                               AND stg.request_id = gn_request_id
                               AND stg.status = 'N'
                               AND ROWNUM = 1),
                   seq_num   = ROWNUM
             WHERE request_id = gn_request_id AND status = 'N';

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                UPDATE xxdo.xxd_po_ds_pr_upd_t stg1
                   SET status = 'E', error_message = 'Error While updating interface batch_id'
                 WHERE request_id = gn_request_id AND status = 'N';

                COMMIT;
                RETURN;
        END;

        BEGIN
            UPDATE xxdo.xxd_po_ds_pr_upd_t stg1
               SET status = 'E', error_message = 'AutoCreate Purchase Requisitions Not Successfull'
             WHERE     request_id = gn_request_id
                   AND status = 'N'
                   AND interface_batch_id IS NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                UPDATE xxdo.xxd_po_ds_pr_upd_t stg1
                   SET status = 'E', error_message = 'Error While updating interface batch_id'
                 WHERE     request_id = gn_request_id
                       AND status = 'N'
                       AND interface_batch_id IS NULL;

                COMMIT;
        END;

        BEGIN
            SELECT COUNT (*)
              INTO ln_tot_count
              FROM xxdo.xxd_po_ds_pr_upd_t t
             WHERE request_id = gn_request_id AND status = 'N';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_tot_count   := 0;
        END;

        ln_req   := CEIL (ln_tot_count / ln_max_req);

        FOR i IN 1 .. ln_req
        LOOP
            ln_from_seq_num   := ln_to_seq_num + 1;
            ln_to_seq_num     := ln_from_seq_num + (ln_max_req - 1);

            BEGIN
                SELECT MIN (interface_batch_id)
                  INTO ln_minbatch_id
                  FROM xxdo.xxd_po_ds_pr_upd_t stg1
                 WHERE     request_id = gn_request_id
                       AND status = 'N'
                       AND seq_num BETWEEN ln_from_seq_num AND ln_to_seq_num;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_minbatch_id   := 9999;
            END;

            BEGIN
                UPDATE po_requisitions_interface_all
                   SET group_code = batch_id, batch_id = ln_minbatch_id
                 WHERE batch_id IN
                           (SELECT interface_batch_id
                              FROM xxdo.xxd_po_ds_pr_upd_t stg1
                             WHERE     request_id = gn_request_id
                                   AND status = 'N'
                                   AND seq_num BETWEEN ln_from_seq_num
                                                   AND ln_to_seq_num);

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    UPDATE xxdo.xxd_po_ds_pr_upd_t
                       SET status = 'E', error_message = 'Error While batching interface records'
                     WHERE     request_id = gn_request_id
                           AND status = 'N'
                           AND seq_num BETWEEN ln_from_seq_num
                                           AND ln_to_seq_num;

                    COMMIT;
            END;

            BEGIN
                UPDATE xxdo.xxd_po_ds_pr_upd_t
                   SET interface_batch_id   = ln_minbatch_id
                 WHERE     request_id = gn_request_id
                       AND status = 'N'
                       AND seq_num BETWEEN ln_from_seq_num AND ln_to_seq_num;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    UPDATE xxdo.xxd_po_ds_pr_upd_t
                       SET status = 'E', error_message = 'Error While batching interface records'
                     WHERE     request_id = gn_request_id
                           AND status = 'N'
                           AND seq_num BETWEEN ln_from_seq_num
                                           AND ln_to_seq_num;

                    COMMIT;
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Error While Batching Interface records');
    END batch_interface_records;

    PROCEDURE run_req_import
    AS
        ln_request_id     NUMBER;
        ln_req_id         NUMBER;
        l_req_status      BOOLEAN;
        x_ret_stat        VARCHAR2 (1);
        x_error_text      VARCHAR2 (20000);
        lv_phase          VARCHAR2 (80);
        lv_status         VARCHAR2 (80);
        lv_dev_phase      VARCHAR2 (80);
        lv_dev_status     VARCHAR2 (80);
        lv_message        VARCHAR2 (255);
        ln_app_id         NUMBER;
        ln_cnt            NUMBER;
        ln_resp_id        NUMBER;
        ln_resp_appl_id   NUMBER;
        ln_user_id        NUMBER;
        lv_error_flag     VARCHAR2 (50);
        lv_error_msg      VARCHAR2 (4000);

        CURSOR c_batch_id IS
            SELECT DISTINCT interface_batch_id, org_id
              FROM xxdo.xxd_po_ds_pr_upd_t t
             WHERE request_id = gn_request_id AND status = 'N';

        ln_org_id         NUMBER := 0;
    BEGIN
        FOR i IN c_batch_id
        LOOP
            BEGIN
                SELECT frv.responsibility_id, frv.application_id resp_application_id
                  INTO ln_resp_id, ln_resp_appl_id
                  FROM apps.fnd_profile_options_vl fpo, apps.fnd_profile_option_values fpov, apps.fnd_responsibility_vl frv
                 WHERE     fpo.user_profile_option_name =
                           gv_mo_profile_option_name
                       AND fpo.profile_option_id = fpov.profile_option_id
                       AND fpov.level_value = frv.responsibility_id
                       AND frv.responsibility_name = gv_responsibility_name
                       AND fpov.profile_option_value IN
                               (SELECT security_profile_id
                                  FROM apps.per_security_organizations
                                 WHERE organization_id = i.org_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_resp_id   := NULL;
            END;

            IF ln_resp_id IS NOT NULL
            THEN
                --do intialize and purchssing setup
                apps.fnd_global.apps_initialize (gn_user_id,
                                                 ln_resp_id,
                                                 ln_resp_appl_id);
                mo_global.init ('PO');
                mo_global.set_policy_context ('S', i.org_id);
                fnd_request.set_org_id (i.org_id);
            END IF;

            ln_request_id   :=
                apps.fnd_request.submit_request (
                    application   => 'PO',
                    program       => 'REQIMPORT',
                    argument1     => 'CTO',
                    argument2     => i.interface_batch_id,
                    argument3     => 'VENDOR',
                    argument4     => '',
                    argument5     => 'N',
                    argument6     => 'Y');
            COMMIT;
            l_req_status   :=
                apps.fnd_concurrent.wait_for_request (
                    request_id   => ln_request_id,
                    INTERVAL     => 10,
                    max_wait     => 0,
                    phase        => lv_phase,
                    status       => lv_status,
                    dev_phase    => lv_dev_phase,
                    dev_status   => lv_dev_status,
                    MESSAGE      => lv_message);

            IF ln_request_id IS NOT NULL
            THEN
                BEGIN
                    UPDATE xxdo.xxd_po_ds_pr_upd_t stg1
                       SET status   = 'S',
                           requisition_number   =
                               (SELECT prh.segment1
                                  FROM po_requisition_headers_all prh
                                 WHERE     request_id = ln_request_id
                                       AND EXISTS
                                               (SELECT 1
                                                  FROM xxdo.xxd_po_ds_pr_upd_t stg, oe_order_headers_all ooh, oe_order_lines_all ool
                                                 WHERE     stg.order_number =
                                                           ooh.order_number
                                                       AND ooh.header_id =
                                                           ool.header_id
                                                       AND ool.line_id =
                                                           prh.interface_source_line_id
                                                       AND stg1.order_number =
                                                           stg.order_number
                                                       AND stg.request_id =
                                                           gn_request_id
                                                       AND stg.status = 'N'
                                                       AND ROWNUM = 1))
                     WHERE     request_id = gn_request_id
                           AND status = 'N'
                           AND interface_batch_id = i.interface_batch_id
                           AND EXISTS
                                   (SELECT 1
                                      FROM po_requisition_headers_all prh
                                     WHERE     request_id = ln_request_id
                                           AND EXISTS
                                                   (SELECT 1
                                                      FROM xxdo.xxd_po_ds_pr_upd_t stg, oe_order_headers_all ooh, oe_order_lines_all ool
                                                     WHERE     stg.order_number =
                                                               ooh.order_number
                                                           AND ooh.header_id =
                                                               ool.header_id
                                                           AND ool.line_id =
                                                               prh.interface_source_line_id
                                                           AND stg1.order_number =
                                                               stg.order_number
                                                           AND stg.request_id =
                                                               gn_request_id
                                                           AND stg.status =
                                                               'N'
                                                           AND ROWNUM = 1));

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               ' Error While updating Staging table with Success records '
                            || SQLERRM);
                END;

                BEGIN
                    UPDATE xxdo.xxd_po_ds_pr_upd_t stg1
                       SET status = 'E', error_message = 'Requisition Not Created'
                     WHERE     request_id = gn_request_id
                           AND status = 'N'
                           AND interface_batch_id = i.interface_batch_id
                           AND requisition_number IS NULL;

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               ' Error While updating Staging table with error records '
                            || SQLERRM);
                END;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   ' requisition import failed with unexpected error '
                || SQLERRM);
    END run_req_import;

    PROCEDURE importer_proc (pv_errbuf OUT VARCHAR2, pv_retcode OUT NUMBER)
    IS
        lv_error_message   VARCHAR2 (2000);
        lv_return_status   VARCHAR2 (1) := NULL;
    BEGIN
        --Updating staging table with request_id
        BEGIN
            UPDATE xxdo.xxd_po_ds_pr_upd_t
               SET request_id   = gn_request_id
             WHERE     status = 'N'
                   AND created_by = gn_user_id
                   AND TRUNC (creation_date) = TRUNC (SYSDATE)
                   AND request_id = -1;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_return_status   := g_ret_error;
                lv_error_message   :=
                    SUBSTR (
                           'Error while updating staging table with request id. Error is: '
                        || SQLERRM,
                        1,
                        2000);
                fnd_file.put_line (fnd_file.LOG, lv_error_message);
                pv_retcode         := gn_error;                           --2;
                RAISE;
        END;

        --Purging staging table for 30 days
        BEGIN
            DELETE FROM xxdo.xxd_po_ds_pr_upd_t
                  WHERE TRUNC (creation_date) <= (SYSDATE - 30);

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_message   :=
                    SUBSTR (
                           'Error while purging staging table. Error is: '
                        || SQLERRM,
                        1,
                        2000);
                fnd_file.put_line (fnd_file.LOG, lv_error_message);
        END;

        submit_autocreate_pr ();
        batch_interface_records ();
        run_req_import ();
        status_report ();
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_error_message   :=
                SUBSTR ('Error in submit_import_proc' || SQLERRM, 1, 2000);
            fnd_file.put_line (fnd_file.LOG, lv_error_message);
    END importer_proc;

    PROCEDURE status_report
    IS
        CURSOR status_rep IS
            SELECT order_number, organization_code, NVL (requisition_number, 'Not Created') requisition_number,
                   DECODE (status,  'S', 'Success',  'E', 'Error',  'Not Processed') status, error_message
              FROM xxdo.xxd_po_ds_pr_upd_t
             WHERE request_id = gn_request_id;
    BEGIN
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('Order Number', 20, ' ')
            || CHR (9)
            || RPAD ('Organization Code', 20, ' ')
            || CHR (9)
            || RPAD ('Requisition Number', 20, ' ')
            || CHR (9)
            || RPAD ('Status', 15, ' ')
            || CHR (9)
            || RPAD ('Error Message', 1000, ' ')
            || CHR (9));

        FOR status_rep_rec IN status_rep
        LOOP
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   RPAD (status_rep_rec.order_number, 20, ' ')
                || CHR (9)
                || RPAD (status_rep_rec.organization_code, 20, ' ')
                || CHR (9)
                || RPAD (status_rep_rec.requisition_number, 20, ' ')
                || CHR (9)
                || RPAD (status_rep_rec.status, 15, ' ')
                || CHR (9)
                || RPAD (status_rep_rec.error_message, 1000, ' ')
                || CHR (9));
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Error in submit_import_proc' || SQLERRM);
    END status_report;
END xxd_po_ds_pr_upload_webadi_pkg;
/
