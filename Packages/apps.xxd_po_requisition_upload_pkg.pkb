--
-- XXD_PO_REQUISITION_UPLOAD_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:30 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PO_REQUISITION_UPLOAD_PKG"
IS
    --  ####################################################################################################
    --  Author(s)       : Tejaswi Gangumalla (Suneratech Consultant)
    --  System          : Oracle Applications
    --  Subsystem       : EBS
    --  Change          : CCR0006710
    --  Schema          : APPS
    --  Purpose         : Package is used to create Internal Requisitions for DC to Transfers
    --  Dependency      : None
    --  Change History
    --  --------------
    --  Date            Name                Ver     Change          Description
    --  ----------      --------------      -----   -------------   ---------------------
    --  21-Feb-2018     Tejaswi Gangumalla  1.0     NA              Initial Version
    --  15-Jun-2018     Kranthi Bollam      1.1     CCR0007136      Maintain the order of SKUS in DC To DC
    --                                                              Transfer Internal Requisition Upload Tool
    --  5-MAR-2020      Tejaswi Gangumalla  1.2     CCR0008870      GAS Project
    --  ####################################################################################################
    gv_package_name   CONSTANT VARCHAR2 (30)
                                   := 'XXD_PO_REQUISITION_UPLOAD_PKG' ;
    gn_user_id        CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id       CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id         CONSTANT NUMBER := fnd_profile.VALUE ('ORG_ID');
    gn_resp_id        CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id   CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_request_id     CONSTANT NUMBER := fnd_global.conc_request_id;

    --gn_global_resp_id CONSTANT NUMBER := 51406; --Commented for change 1.1 as it is not used in the package

    --Main Procedure called by WebADI
    PROCEDURE upload_proc (pv_sku VARCHAR2, pv_dest_org VARCHAR2, pv_source_org VARCHAR2, pn_quantity NUMBER, pv_need_by_date VARCHAR2, pn_grouping_number NUMBER, pv_sales_channel VARCHAR2, --Added for change 1.2
                                                                                                                                                                                              pv_attribute1 VARCHAR2, --Added for change 1.2
                                                                                                                                                                                                                      pv_attribute2 VARCHAR2, --Added for change 1.2
                                                                                                                                                                                                                                              pv_attribute3 VARCHAR2, --Added for change 1.2
                                                                                                                                                                                                                                                                      pv_attribute4 VARCHAR2, --Added for change 1.2
                                                                                                                                                                                                                                                                                              pv_attribute5 VARCHAR2, --Added for change 1.2
                                                                                                                                                                                                                                                                                                                      pn_attribute6 NUMBER, --Added for change 1.2
                                                                                                                                                                                                                                                                                                                                            pn_attribute7 NUMBER, --Added for change 1.2
                                                                                                                                                                                                                                                                                                                                                                  pn_attribute8 NUMBER
                           ,                            --Added for change 1.2
                             pd_attribute9 DATE,        --Added for change 1.2
                                                 pd_attribute10 DATE --Added for change 1.2
                                                                    )
    IS
        ln_seq_id                 NUMBER;
        lv_error_message          VARCHAR2 (4000) := NULL;
        lv_return_status          VARCHAR2 (1) := NULL;
        ln_item_id                NUMBER := NULL;
        ln_dest_org_id            NUMBER := NULL;
        ln_source_org_id          NUMBER := NULL;
        ln_dummy                  NUMBER := 0;
        ln_source_trade_enabled   NUMBER := NULL;
        ln_dest_trade_enabled     NUMBER := NULL;
        lv_uom_code               VARCHAR2 (10) := NULL;
        le_webadi_exception       EXCEPTION;
        lv_sales_channel          VARCHAR2 (200) := NULL;
    BEGIN
        IF    pv_sku IS NULL
           OR pv_dest_org IS NULL
           OR pv_source_org IS NULL
           OR pn_quantity IS NULL
           OR pv_need_by_date IS NULL
           OR pn_grouping_number IS NULL
        THEN
            lv_error_message   :=
                'SKU,Destination Org,Source Org,Quantity,Need By Date,Grouping Sequence are Mandatory. One or more mandatory columns are missing. ';
            RAISE le_webadi_exception;
        END IF;

        BEGIN
            SELECT organization_id, attribute13
              INTO ln_dest_org_id, ln_dest_trade_enabled
              FROM mtl_parameters
             WHERE organization_code = UPPER (pv_dest_org);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lv_error_message   :=
                       lv_error_message
                    || 'Invalid Destination Organization: '
                    || pv_dest_org
                    || '. ';
            WHEN OTHERS
            THEN
                lv_error_message   :=
                    SUBSTR (
                           lv_error_message
                        || 'Error While Validating Destination Organization: '
                        || pv_dest_org
                        || ' '
                        || SQLERRM
                        || '. ',
                        1,
                        2000);
        END;

        IF ln_dest_trade_enabled = 1
        THEN
            lv_error_message   :=
                   lv_error_message
                || ' Destination Organization is not trade enabled. ';
        END IF;

        BEGIN
            SELECT organization_id, attribute13
              INTO ln_source_org_id, ln_source_trade_enabled
              FROM mtl_parameters
             WHERE organization_code = UPPER (pv_source_org);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lv_error_message   :=
                    SUBSTR (
                           lv_error_message
                        || 'Invalid Source Organization: '
                        || pv_source_org
                        || '. ',
                        1,
                        2000);
            WHEN OTHERS
            THEN
                lv_error_message   :=
                    SUBSTR (
                           lv_error_message
                        || 'Error While Validating Source Organization: '
                        || pv_source_org
                        || ' '
                        || SQLERRM
                        || '. ',
                        1,
                        2000);
        END;

        IF ln_source_trade_enabled = 1
        THEN
            lv_error_message   :=
                   lv_error_message
                || ' Source Organization is not trade enabled. ';
        END IF;

        BEGIN
            SELECT inventory_item_id, primary_uom_code
              INTO ln_item_id, lv_uom_code
              FROM mtl_system_items_b
             WHERE     segment1 = UPPER (pv_sku)
                   AND organization_id = ln_dest_org_id
                   AND inventory_item_status_code = 'Active';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lv_error_message   :=
                    SUBSTR (
                           lv_error_message
                        || 'Item:'
                        || pv_sku
                        || ' Not assigned to destination organization: '
                        || pv_dest_org
                        || ' or is not Active. ',
                        1,
                        2000);
            WHEN OTHERS
            THEN
                lv_error_message   :=
                    SUBSTR (
                           lv_error_message
                        || 'Error While Item Validation In Destination Organization '
                        || SQLERRM
                        || '. ',
                        1,
                        2000);
        END;

        BEGIN
            SELECT inventory_item_id
              INTO ln_item_id
              FROM mtl_system_items_b
             WHERE     segment1 = UPPER (pv_sku)
                   AND organization_id = ln_source_org_id
                   AND inventory_item_status_code = 'Active';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lv_error_message   :=
                    SUBSTR (
                           lv_error_message
                        || 'Item:'
                        || pv_sku
                        || ' Not assigned to source organization: '
                        || pv_source_org
                        || ' or is not Active. ',
                        1,
                        2000);
            WHEN OTHERS
            THEN
                lv_error_message   :=
                    SUBSTR (
                           lv_error_message
                        || 'Error While Item Validation In Source Organization'
                        || SQLERRM
                        || '. ',
                        1,
                        2000);
        END;

        IF pn_quantity <= 0
        THEN
            lv_error_message   :=
                SUBSTR (
                    lv_error_message || 'Quantity must be greater than 0. ',
                    1,
                    2000);
        ELSE
            BEGIN
                SELECT TO_NUMBER (pn_quantity, '999999999')
                  INTO ln_dummy
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || 'Quantity should be a whole number. ',
                            1,
                            2000);
            END;
        END IF;

        IF pn_grouping_number <= 0
        THEN
            lv_error_message   :=
                SUBSTR (
                       lv_error_message
                    || 'Requisition Grouping Sequence must be greater than 0. ',
                    1,
                    2000);
        ELSE
            BEGIN
                SELECT TO_NUMBER (pn_grouping_number, '999999999')
                  INTO ln_dummy
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || 'Requisition Grouping Sequence should be a whole number. ',
                            1,
                            2000);
            END;
        END IF;

        IF TO_DATE (pv_need_by_date, 'DD-MON-YYYY') < TRUNC (SYSDATE)
        THEN
            lv_error_message   :=
                SUBSTR (
                       lv_error_message
                    || 'Need By Date must be greater than or equal to sysdate. ',
                    1,
                    2000);
        END IF;

        /*Start of changes 1.2*/
        IF pv_sales_channel IS NOT NULL
        THEN
            BEGIN
                SELECT lookup_code
                  INTO lv_sales_channel
                  FROM apps.fnd_lookup_values
                 WHERE     lookup_type = 'SALES_CHANNEL'
                       AND language = USERENV ('LANG')
                       AND enabled_flag = 'Y'
                       AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                                       AND NVL (end_date_active, SYSDATE)
                       AND UPPER (meaning) = UPPER (pv_sales_channel);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || 'Sales Channel:'
                            || pv_sales_channel
                            || ' is not valid ',
                            1,
                            2000);
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || 'Error While Validating Sales Channel'
                            || SQLERRM
                            || '. ',
                            1,
                            2000);
            END;
        ELSE
            lv_sales_channel   := NULL;
        END IF;

        /*End of changes 1.2*/

        IF lv_error_message IS NULL
        THEN
            BEGIN
                INSERT INTO xxdo.xxd_po_requisition_upd_stg (
                                status,
                                error_message,
                                request_id,
                                created_by,
                                creation_date,
                                last_updated_by,
                                last_update_date,
                                last_update_login,
                                sku,
                                destination_org,
                                source_org,
                                quantity,
                                need_by_date,
                                grouping_sequence,
                                item_id,
                                uom_code,
                                dest_org_id,
                                source_org_id,
                                sequence_id,            --Added for change 1.1
                                sales_channel           --Added for change 2.1
                                             )
                         VALUES ('N',
                                 NULL,
                                 gn_request_id,
                                 gn_user_id,
                                 SYSDATE,
                                 gn_user_id,
                                 SYSDATE,
                                 gn_login_id,
                                 pv_sku,
                                 pv_dest_org,
                                 pv_source_org,
                                 pn_quantity,
                                 pv_need_by_date,
                                 pn_grouping_number,
                                 ln_item_id,
                                 lv_uom_code,
                                 ln_dest_org_id,
                                 ln_source_org_id,
                                 xxdo.xxd_po_req_upd_stg_seq_no.NEXTVAL, --Added for change 1.1
                                 lv_sales_channel       --Added for change 1.2
                                                 );
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || ' Error while inserting into staging table: '
                            || SQLERRM,
                            1,
                            2000);
                    RAISE le_webadi_exception;
            END;
        ELSE
            RAISE le_webadi_exception;
        END IF;
    EXCEPTION
        WHEN le_webadi_exception
        THEN
            lv_error_message   := SUBSTR (lv_error_message, 1, 2000);
            fnd_message.set_name ('XXDO', 'XXD_REQ_UPLOAD_WEBADI_MSG');
            fnd_message.set_token ('ERROR_MESSAGE', lv_error_message);
            lv_error_message   := fnd_message.get ();
            raise_application_error (-20000, lv_error_message);
        WHEN OTHERS
        THEN
            lv_error_message   :=
                SUBSTR (lv_error_message || '.' || SQLERRM, 1, 2000);
            fnd_message.set_name ('XXDO', 'XXD_REQ_UPLOAD_WEBADI_MSG');
            fnd_message.set_token ('ERROR_MESSAGE', lv_error_message);
            lv_error_message   := fnd_message.get ();
            raise_application_error (-20000, lv_error_message);
    END;

    PROCEDURE group_sequence_validation (pv_error_message   OUT VARCHAR2,
                                         pv_error_code      OUT VARCHAR2)
    IS
        CURSOR cursor_req_seq (cv_request_id NUMBER)
        IS
            SELECT DISTINCT grouping_sequence
              FROM xxdo.xxd_po_requisition_upd_stg
             WHERE status = 'N' AND request_id = cv_request_id;

        ln_source_org_id       NUMBER;
        ln_dest_org_id         NUMBER;
        ln_operating_unit_id   NUMBER;
        ln_location_id         NUMBER;
        ln_ccid                NUMBER;
        ln_batch_id            NUMBER;
        lv_error_message       VARCHAR2 (2000);
        lv_return_status       VARCHAR2 (1) := NULL;
        lv_error_count         NUMBER := 0;
        ln_resp_org_count      NUMBER;
    BEGIN
        FOR cursor_req_seq_rec IN cursor_req_seq (gn_request_id)
        LOOP
            ln_source_org_id       := NULL;
            ln_dest_org_id         := NULL;
            ln_location_id         := NULL;
            ln_operating_unit_id   := NULL;
            ln_ccid                := NULL;

            BEGIN
                --validating grouping sequence
                SELECT DISTINCT source_org_id, dest_org_id
                  INTO ln_source_org_id, ln_dest_org_id
                  FROM xxd_po_requisition_upd_stg
                 WHERE     status = 'N'
                       AND request_id = gn_request_id
                       AND grouping_sequence =
                           cursor_req_seq_rec.grouping_sequence;
            EXCEPTION
                WHEN TOO_MANY_ROWS
                THEN
                    lv_error_count     := lv_error_count + 1;
                    lv_return_status   := g_ret_error;
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || 'Same grouping sequence must have same source organization and destination organization'
                            || '. ',
                            1,
                            2000);
                WHEN OTHERS
                THEN
                    lv_return_status   := g_ret_error;
                    lv_error_message   :=
                        SUBSTR (lv_error_message || SQLERRM || '. ', 1, 2000);
            END;

            IF ln_source_org_id IS NOT NULL AND ln_dest_org_id IS NOT NULL
            THEN
                BEGIN
                    --getting operating unit
                    SELECT operating_unit
                      INTO ln_operating_unit_id
                      FROM apps.org_organization_definitions
                     WHERE organization_id = ln_dest_org_id; --ln_source_org_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_return_status   := g_ret_error;
                        lv_error_message   :=
                            SUBSTR (
                                   lv_error_message
                                || 'Error while getting operating unit. Error is: '
                                || SQLERRM
                                || '. ',
                                1,
                                2000);
                END;

                BEGIN
                    --getting location_id
                    SELECT location_id
                      INTO ln_location_id
                      FROM hr_organization_units_v
                     WHERE organization_id = ln_dest_org_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_return_status   := g_ret_error;
                        lv_error_message   :=
                            SUBSTR (
                                   lv_error_message
                                || 'Error while getting location id. Error is: '
                                || SQLERRM
                                || '. ',
                                1,
                                2000);
                END;

                BEGIN
                    --getting material account
                    SELECT material_account
                      INTO ln_ccid
                      FROM mtl_parameters
                     WHERE organization_id = ln_dest_org_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_return_status   := g_ret_error;
                        lv_error_message   :=
                            SUBSTR (
                                   lv_error_message
                                || 'Error while getting material account. Error is: '
                                || SQLERRM
                                || '. ',
                                1,
                                2000);
                END;
            END IF;

            IF lv_error_message IS NOT NULL
            THEN
                --Updating staging table with error message
                BEGIN
                    UPDATE xxd_po_requisition_upd_stg
                       SET status = 'E', error_message = SUBSTR (lv_error_message, 1, 2000)
                     WHERE     status = 'N'
                           AND request_id = gn_request_id
                           AND grouping_sequence =
                               cursor_req_seq_rec.grouping_sequence;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_error_message   :=
                            SUBSTR (
                                   'Error in group_sequence_validation procedure while updating error records'
                                || SQLERRM,
                                1,
                                2000);
                END;
            ELSE
                BEGIN
                    --getting interface batch_id
                    SELECT xxd_po_requisition_upd_stg_sno.NEXTVAL
                      INTO ln_batch_id
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_return_status   := g_ret_error;
                        lv_error_message   :=
                            SUBSTR (
                                   'Error while getting seq id from xxd_po_requisition_upd_stg_sno. Error is: '
                                || SQLERRM,
                                1,
                                2000);
                END;

                BEGIN
                    UPDATE xxd_po_requisition_upd_stg
                       SET org_id = ln_operating_unit_id, material_account = ln_ccid, location_id = ln_location_id,
                           interface_batch_id = ln_batch_id
                     WHERE     status = 'N'
                           AND request_id = gn_request_id
                           AND grouping_sequence =
                               cursor_req_seq_rec.grouping_sequence;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_error_message   :=
                            SUBSTR (
                                   'Error in group_sequence_validation procedure while updating valid records: '
                                || SQLERRM,
                                1,
                                2000);
                END;
            END IF;
        END LOOP;

        IF lv_error_count > 0
        THEN
            --If one records fails requisition grouping validation stop processing valid records
            BEGIN
                UPDATE xxd_po_requisition_upd_stg
                   SET status = 'E', error_message = 'Record cannot be processed as one or more records failed requisition grouping validation'
                 WHERE status = 'N' AND request_id = gn_request_id;

                pv_error_code   := 'E';
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_error_message   :=
                        SUBSTR (
                               'Error in group_sequence_validation procedure while updating requisition grouping validation records'
                            || SQLERRM,
                            1,
                            2000);
            END;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_message   :=
                SUBSTR (
                    'Error in group_sequence_validation procedure' || SQLERRM,
                    1,
                    2000);
    END group_sequence_validation;

    PROCEDURE insert_into_interface_table (pv_error_message   OUT VARCHAR2,
                                           pn_person_id       OUT NUMBER)
    IS
        ln_person_id       NUMBER;
        lv_return_status   VARCHAR2 (1) := NULL;
    BEGIN
        --Getting person_id of user
        BEGIN
            SELECT employee_id
              INTO ln_person_id
              FROM fnd_user
             WHERE user_id = gn_user_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_return_status   := g_ret_error;
                pv_error_message   :=
                    SUBSTR (
                        'Error getting employee id. Error is: ' || SQLERRM,
                        1,
                        2000);
        END;


        pn_person_id   := ln_person_id;

        INSERT INTO po_requisitions_interface_all (
                        interface_source_code,
                        requisition_type,
                        org_id,
                        authorization_status,
                        charge_account_id,
                        quantity,
                        uom_code,
                        group_code,
                        item_id,
                        need_by_date,
                        preparer_id,
                        deliver_to_requestor_id,
                        source_type_code,
                        source_organization_id,
                        destination_type_code,
                        destination_organization_id,
                        deliver_to_location_id,
                        creation_date,
                        created_by,
                        last_update_date,
                        last_updated_by,
                        batch_id,
                        line_num,                       --Added for change 1.1
                        header_attribute1               --Added for change 1.2
                                         )
            (SELECT 'INV',                            -- interface_source_code
                           'INTERNAL',                     -- Requisition_type
                                       org_id,
                    'INCOMPLETE',                      -- Authorization_Status
                                  material_account,    -- Destination org ccid
                                                    quantity,      -- Quantity
                    uom_code,                                      -- UOm Code
                              1,                                   -- Group_id
                                 item_id,
                    need_by_date,                             -- neeed by date
                                  ln_person_id,   -- Person id of the preparer
                                                ln_person_id, -- Person_id of the requestor
                    'INVENTORY',                           -- source_type_code
                                 source_org_id,               -- Source org id
                                                'INVENTORY', -- destination_type_code
                    dest_org_id,                         -- Destination org id
                                 location_id,         --deliver to location id
                                              SYSDATE,
                    gn_user_id, SYSDATE, gn_user_id,
                    interface_batch_id, ROW_NUMBER () OVER (PARTITION BY stg.interface_batch_id ORDER BY stg.interface_batch_id, stg.sequence_id) line_number, --Added for change 1.1
                                                                                                                                                               stg.sales_channel --Added for change 1.2
               FROM xxdo.xxd_po_requisition_upd_stg stg
              WHERE     1 = 1
                    AND stg.status = 'N'
                    AND stg.request_id = gn_request_id);
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_return_status   := g_ret_error;
            pv_error_message   :=
                SUBSTR (
                       'Error while inserting data into staging table. Error is: '
                    || SQLERRM,
                    1,
                    2000);
    END insert_into_interface_table;

    PROCEDURE submit_import_proc (pn_person_id       IN     NUMBER,
                                  pv_error_message      OUT VARCHAR2)
    IS
        CURSOR cursor_interface_records (cv_request_id NUMBER)
        IS
            SELECT DISTINCT interface_batch_id, org_id
              FROM xxdo.xxd_po_requisition_upd_stg
             WHERE status = 'N' AND request_id = cv_request_id;

        lv_error_message     VARCHAR2 (2000);
        lv_return_status     VARCHAR2 (1) := NULL;
        ln_request_id        NUMBER;
        lb_concreqcallstat   BOOLEAN := FALSE;
        lv_phasecode         VARCHAR2 (100) := NULL;
        lv_statuscode        VARCHAR2 (100) := NULL;
        lv_devphase          VARCHAR2 (100) := NULL;
        lv_devstatus         VARCHAR2 (100) := NULL;
        lv_returnmsg         VARCHAR2 (200) := NULL;
        ln_int_error_count   NUMBER;
        lv_error_stat        NUMBER;
        lv_error_msg         NUMBER;
    BEGIN
        FOR cursor_interface_rec IN cursor_interface_records (gn_request_id)
        LOOP
            fnd_global.apps_initialize (user_id        => gn_user_id,
                                        resp_id        => gn_resp_id,
                                        resp_appl_id   => gn_resp_appl_id);
            mo_global.init ('PO');
            mo_global.set_policy_context ('S', cursor_interface_rec.org_id);
            fnd_request.set_org_id (cursor_interface_rec.org_id);
            ln_request_id   :=
                fnd_request.submit_request (
                    application   => 'PO',           -- application short name
                    program       => 'REQIMPORT',        -- program short name
                    description   => 'Requisition Import',      -- description
                    start_time    => SYSDATE,                    -- start date
                    sub_request   => FALSE,                     -- sub-request
                    argument1     => 'INV',           -- interface source code
                    argument2     => cursor_interface_rec.interface_batch_id, -- Batch Id
                    argument3     => 'ALL',                        -- Group By
                    argument4     => NULL,          -- Last Requisition Number
                    argument5     => NULL,              -- Multi Distributions
                    argument6     => 'N' -- Initiate Requisition Approval after Requisition Import
                                        );
            COMMIT;

            IF ln_request_id = 0
            THEN
                lv_return_status   := g_ret_error;
                pv_error_message   :=
                    SUBSTR (
                           'Error while submitting requisition import. Error is: '
                        || SQLERRM,
                        1,
                        2000);
            ELSE
                LOOP
                    lb_concreqcallstat   :=
                        apps.fnd_concurrent.wait_for_request (ln_request_id,
                                                              5, -- wait 5 seconds between db checks
                                                              0,
                                                              lv_phasecode,
                                                              lv_statuscode,
                                                              lv_devphase,
                                                              lv_devstatus,
                                                              lv_returnmsg);
                    EXIT WHEN lv_devphase = 'COMPLETE';
                END LOOP;
            END IF;

            SELECT COUNT (*)
              INTO ln_int_error_count
              FROM po_requisitions_interface_all
             WHERE request_id = ln_request_id AND process_flag = 'ERROR';

            IF ln_int_error_count > 0
            THEN
                BEGIN
                    UPDATE xxdo.xxd_po_requisition_upd_stg stg
                       SET status   = 'S',
                           requisition_number   =
                               (SELECT segment1
                                  FROM po_requisition_headers_all prh
                                 WHERE prh.request_id = ln_request_id)
                     WHERE     stg.status = 'N'
                           AND stg.request_id = gn_request_id
                           AND stg.interface_batch_id =
                               cursor_interface_rec.interface_batch_id
                           AND (stg.item_id, stg.quantity, stg.dest_org_id,
                                stg.source_org_id, TO_DATE (stg.need_by_date, 'DD-MON-YYYY')) IN
                                   (SELECT prl.item_id, prl.quantity, prl.destination_organization_id,
                                           prl.source_organization_id, prl.need_by_date
                                      FROM po_requisition_headers_all prh, po_requisition_lines_all prl, xxdo.xxd_po_requisition_upd_stg stg
                                     WHERE     prh.request_id = ln_request_id
                                           AND prh.requisition_header_id =
                                               prl.requisition_header_id
                                           AND stg.status = 'N'
                                           AND stg.request_id = gn_request_id
                                           AND interface_batch_id =
                                               cursor_interface_rec.interface_batch_id
                                           AND stg.item_id = prl.item_id
                                           AND stg.quantity = prl.quantity
                                           AND stg.dest_org_id =
                                               prl.destination_organization_id
                                           AND stg.source_org_id =
                                               prl.source_organization_id
                                           AND stg.location_id =
                                               prl.deliver_to_location_id
                                           AND prl.to_person_id =
                                               pn_person_id
                                           AND TO_DATE (stg.need_by_date,
                                                        'DD-MON-YYYY') =
                                               prl.need_by_date);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_error_message   :=
                            SUBSTR (
                                   'Error while updating staging table with requisition number'
                                || SQLERRM,
                                1,
                                2000);
                END;

                --Updating error_records
                BEGIN
                    UPDATE xxdo.xxd_po_requisition_upd_stg stg
                       SET status   = 'E',
                           error_message   =
                               NVL (
                                   (SELECT SUBSTR (REPLACE (error_message, CHR (10), ''), 1, 2000)
                                      FROM po_interface_errors ie, po_requisitions_interface_all rie
                                     WHERE     rie.transaction_id =
                                               ie.interface_transaction_id
                                           AND rie.request_id = ln_request_id
                                           AND ROWNUM = 1),
                                   'Requistion import error. Please check interface error table')
                     WHERE     stg.status = 'N'
                           AND stg.request_id = gn_request_id
                           AND stg.interface_batch_id =
                               cursor_interface_rec.interface_batch_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_error_message   :=
                            SUBSTR (
                                   'Error while updating staging table with error records'
                                || SQLERRM,
                                1,
                                2000);
                END;
            ELSE
                BEGIN
                    UPDATE xxdo.xxd_po_requisition_upd_stg stg
                       SET status   = 'S',
                           requisition_number   =
                               (SELECT segment1
                                  FROM po_requisition_headers_all prh
                                 WHERE prh.request_id = ln_request_id)
                     WHERE     stg.status = 'N'
                           AND stg.request_id = gn_request_id
                           AND stg.interface_batch_id =
                               cursor_interface_rec.interface_batch_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_error_message   :=
                            SUBSTR (
                                   'Error while updating staging table with requisition number'
                                || SQLERRM,
                                1,
                                2000);
                END;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_message   :=
                SUBSTR ('Error in submit_import_proc' || SQLERRM, 1, 2000);
    END submit_import_proc;

    PROCEDURE importer_proc (pv_errbuf OUT VARCHAR2, pv_retcode OUT NUMBER)
    IS
        lv_error_message          VARCHAR2 (2000);
        lv_return_status          VARCHAR2 (1) := NULL;
        lv_proc_error_message     VARCHAR2 (2000);
        le_proc_error_exception   EXCEPTION;
        ln_person_id              NUMBER;
        lv_error_code             VARCHAR2 (1);
    BEGIN
        mo_global.init ('PO');

        --Updating staging table with request_id
        BEGIN
            UPDATE xxdo.xxd_po_requisition_upd_stg
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

        BEGIN
            group_sequence_validation (lv_proc_error_message, lv_error_code);

            IF lv_proc_error_message IS NOT NULL
            THEN
                RAISE le_proc_error_exception;
            END IF;
        END;

        IF NVL (lv_error_code, 'N') <> 'E'
        THEN
            BEGIN
                insert_into_interface_table (lv_proc_error_message,
                                             ln_person_id);

                IF lv_proc_error_message IS NOT NULL
                THEN
                    RAISE le_proc_error_exception;
                END IF;
            END;

            BEGIN
                submit_import_proc (ln_person_id, lv_proc_error_message);

                IF lv_proc_error_message IS NOT NULL
                THEN
                    RAISE le_proc_error_exception;
                END IF;
            END;
        END IF;

        BEGIN
            status_report (lv_proc_error_message);

            IF lv_proc_error_message IS NOT NULL
            THEN
                RAISE le_proc_error_exception;
            END IF;
        END;

        IF lv_error_code = 'E'
        THEN
            lv_proc_error_message   :=
                'Record cannot be processed as one or more records failed requisition grouping validation';
            RAISE le_proc_error_exception;
        END IF;
    EXCEPTION
        WHEN le_proc_error_exception
        THEN
            COMMIT;
            raise_application_error (-20000, lv_proc_error_message);
        WHEN OTHERS
        THEN
            COMMIT;
            lv_proc_error_message   :=
                SUBSTR (lv_proc_error_message || SQLERRM, 1, 2000);
            fnd_file.put_line (fnd_file.LOG, lv_proc_error_message);
            pv_retcode   := gn_error;                                     --2;
            RAISE;
    END importer_proc;

    PROCEDURE status_report (pv_error_message OUT VARCHAR2)
    IS
        CURSOR status_rep IS
              SELECT UPPER (stg.sku) sku, UPPER (stg.destination_org) destination_org, UPPER (stg.source_org) source_org,
                     stg.quantity, stg.need_by_date, stg.grouping_sequence,
                     NVL (stg.requisition_number, 'Not Created') requisition_number, DECODE (stg.status,  'S', 'Success',  'E', 'Error',  'N', 'Not Processed',  'Error') status, stg.error_message
                FROM xxdo.xxd_po_requisition_upd_stg stg
               WHERE stg.request_id = gn_request_id
            ORDER BY requisition_number;
    BEGIN
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('SKU', 20, ' ')
            || CHR (9)
            || RPAD ('Destination Org', 20, ' ')
            || CHR (9)
            || RPAD ('Source Org', 15, ' ')
            || CHR (9)
            || RPAD ('Quantity', 10, ' ')
            || CHR (9)
            || RPAD ('Need By Date', 15, ' ')
            || CHR (9)
            || RPAD ('Requisition Grouping', 22, ' ')
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
                   RPAD (status_rep_rec.sku, 20, ' ')
                || CHR (9)
                || RPAD (status_rep_rec.destination_org, 20, ' ')
                || CHR (9)
                || RPAD (status_rep_rec.source_org, 15, ' ')
                || CHR (9)
                || RPAD (status_rep_rec.quantity, 10, ' ')
                || CHR (9)
                || RPAD (status_rep_rec.need_by_date, 15, ' ')
                || CHR (9)
                || RPAD (status_rep_rec.grouping_sequence, 22, ' ')
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
            pv_error_message   :=
                SUBSTR ('Error in submit_import_proc' || SQLERRM, 1, 2000);
    END status_report;
END xxd_po_requisition_upload_pkg;
/
