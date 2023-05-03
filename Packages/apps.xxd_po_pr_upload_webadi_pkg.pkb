--
-- XXD_PO_PR_UPLOAD_WEBADI_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:36 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PO_PR_UPLOAD_WEBADI_PKG"
IS
    /*****************************************************************************************
    * Package      : XXD_PO_PR_UPLOAD_WEBADI_PKG
    * Design       : Package is used to create Purchase Requisitions.
    * Notes        :
    * Modification :
    -- =======================================================================================
    -- Date         Version#   Name                    Comments
    -- =======================================================================================
    -- 05-Dec-2018  1.0        Tejaswi Gangumalla     Initial Version
 -- 18-Feb-2019  1.1        Tejswi Gangumalla      CCR0007830 Modified cusor query in status_report procedure to allign ouput correctly
 -- 23-May-2020  1.2        Gaurav Joshi           CCR0008637 Purchase Requisition WEBADI - Source Derivation
 -- 19-Apr-2022  1.3        Aravind Kannuri        CCR0009960 Prevent duplicate SKU# line under same requisition
    *******************************************************************************************/
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
    PROCEDURE upload_proc (pv_sku                 VARCHAR2,
                           pn_quantity            NUMBER,
                           pv_need_by_date        VARCHAR2,
                           pv_organization_code   VARCHAR2,
                           pv_supplier            VARCHAR2,
                           pv_supplier_site       VARCHAR2,
                           pn_grouping_number     NUMBER,
                           pv_attribute1          NUMBER DEFAULT NULL,
                           pv_attribute2          NUMBER DEFAULT NULL,
                           pv_attribute3          VARCHAR2 DEFAULT NULL,
                           pv_attribute4          VARCHAR2 DEFAULT NULL,
                           pv_attribute5          VARCHAR2 DEFAULT NULL,
                           pv_attribute6          VARCHAR2 DEFAULT NULL,
                           pv_attribute7          VARCHAR2 DEFAULT NULL,
                           pv_attribute8          VARCHAR2 DEFAULT NULL,
                           pv_attribute9          VARCHAR2 DEFAULT NULL,
                           pv_attribute10         VARCHAR2 DEFAULT NULL)
    IS
        ln_seq_id             NUMBER;
        lv_error_message      VARCHAR2 (4000) := NULL;
        lv_return_status      VARCHAR2 (1) := NULL;
        ln_item_id            NUMBER := NULL;
        ln_org_id             NUMBER := NULL;
        ln_source_org_id      NUMBER := NULL;
        ln_dummy              NUMBER := 0;
        --ln_source_trade_enabled     NUMBER :=NULL;
        --  ln_dest_trade_enabled       NUMBER :=NULL;
        lv_uom_code           VARCHAR2 (10) := NULL;
        ln_supplier_id        NUMBER := NULL;
        ln_supplier_site_id   NUMBER := NULL;
        ln_org_enabled        NUMBER := NULL;
        lv_date_format        VARCHAR2 (20) := NULL;
        ln_operating_unit     NUMBER;
        le_webadi_exception   EXCEPTION;
    BEGIN
        -- Mandatory Columns Validation
        IF    pv_sku IS NULL
           OR pn_quantity IS NULL
           OR pv_need_by_date IS NULL
           OR pv_organization_code IS NULL
           OR pn_grouping_number IS NULL
        THEN
            lv_error_message   :=
                'SKU,Organization,Quantity,Need By Date,Grouping Sequence are Mandatory. One or more mandatory columns are missing. ';
            RAISE le_webadi_exception;
        END IF;

        --Organization Validation
        BEGIN
            SELECT organization_id, operating_unit
              INTO ln_org_id, ln_operating_unit
              FROM org_organization_definitions
             WHERE organization_code = UPPER (pv_organization_code);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lv_error_message   :=
                       lv_error_message
                    || 'Invalid Organization: '
                    || pv_organization_code
                    || '. ';
            WHEN OTHERS
            THEN
                lv_error_message   :=
                    SUBSTR (
                           lv_error_message
                        || 'Error While Validating Organization: '
                        || pv_organization_code
                        || ' '
                        || SQLERRM
                        || '. ',
                        1,
                        2000);
        END;

        --Check if organization is enabled for PR upload
        BEGIN
            SELECT COUNT (*)
              INTO ln_org_enabled
              FROM fnd_lookup_values flp, org_organization_definitions ood, hr_operating_units hu
             WHERE     flp.lookup_type = 'XXD_PO_PR_UPLOAD_ORGS'
                   AND flp.LANGUAGE = 'US'
                   AND flp.tag = ood.organization_code
                   AND hu.NAME = flp.description
                   AND hu.organization_id = ood.operating_unit
                   AND ood.organization_code = UPPER (pv_organization_code)
                   AND SYSDATE BETWEEN start_date_active
                                   AND NVL (end_date_active, SYSDATE + 1)
                   AND flp.enabled_flag = 'Y';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_message   :=
                    SUBSTR (
                           lv_error_message
                        || 'Error While Checking If Organization Is Enabled For Purchase Requistion Upload: '
                        || pv_organization_code
                        || ' '
                        || SQLERRM
                        || '. ',
                        1,
                        2000);
        END;

        IF ln_org_enabled = 0
        THEN
            lv_error_message   :=
                SUBSTR (
                       lv_error_message
                    || 'Organization: '
                    || pv_organization_code
                    || ' Is Not Enabled For Purchase Requistion Upload '
                    || '. ',
                    1,
                    2000);
        END IF;

        -- SKU Valication
        BEGIN
            SELECT inventory_item_id, primary_uom_code
              INTO ln_item_id, lv_uom_code
              FROM mtl_system_items_b
             WHERE     segment1 = UPPER (pv_sku)
                   AND organization_id = ln_org_id
                   AND inventory_item_status_code = 'Active';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lv_error_message   :=
                    SUBSTR (
                           lv_error_message
                        || 'Item: '
                        || pv_sku
                        || ' Not assigned to organization: '
                        || pv_organization_code
                        || ' or is not Active. ',
                        1,
                        2000);
            WHEN OTHERS
            THEN
                lv_error_message   :=
                    SUBSTR (
                           lv_error_message
                        || 'Error While Item Validation In Organization '
                        || SQLERRM
                        || '. ',
                        1,
                        2000);
        END;

        --Quantity Validation
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

        --Grouping Sequnce Validation
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

        -- Date Format Validation
        BEGIN
            SELECT TO_CHAR (TO_DATE (pv_need_by_date, 'DD-MM-YYYY'), 'DD-MON-YYYY')
              INTO lv_date_format
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_message   :=
                    SUBSTR (
                           lv_error_message
                        || 'Need By Date Not In DD-MON-YYYY Format '
                        || SQLERRM
                        || '. ',
                        1,
                        2000);
        END;

        IF lv_date_format <> pv_need_by_date
        THEN
            lv_error_message   :=
                SUBSTR (
                       lv_error_message
                    || 'Need By Date Not In DD-MON-YYYY Format',
                    1,
                    2000);
        END IF;

        --Need By Date Validation
        IF lv_date_format = pv_need_by_date
        THEN
            IF TO_DATE (pv_need_by_date, 'DD-MON-YYYY') < TRUNC (SYSDATE)
            THEN
                lv_error_message   :=
                    SUBSTR (
                           lv_error_message
                        || 'Need By Date must be greater than or equal to sysdate. ',
                        1,
                        2000);
            END IF;
        END IF;

        IF pv_supplier IS NULL AND pv_supplier_site IS NOT NULL
        THEN
            lv_error_message   :=
                SUBSTR (
                       lv_error_message
                    || 'Supplier Cannot Be Null When Supplier Site Is Provided: ',
                    1,
                    2000);
        END IF;

        IF pv_supplier IS NOT NULL AND pv_supplier_site IS NULL
        THEN
            lv_error_message   :=
                SUBSTR (
                       lv_error_message
                    || 'Supplier Site Cannot Be Null When Supplier Is Provided: ',
                    1,
                    2000);
        END IF;

        --Supplier and Supplier Site Validation
        IF pv_supplier IS NOT NULL AND pv_supplier_site IS NOT NULL
        THEN
            BEGIN
                SELECT vendor_id
                  INTO ln_supplier_id
                  FROM ap_suppliers
                 WHERE     UPPER (vendor_name) = UPPER (pv_supplier)
                       AND (TRUNC (NVL (end_date_active, SYSDATE)) >= TRUNC (SYSDATE));
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || 'Invalid Supplier: '
                            || pv_supplier
                            || ' ',
                            1,
                            2000);
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || 'Error While Validating Supplier '
                            || SQLERRM
                            || '. ',
                            1,
                            2000);
            END;

            BEGIN
                SELECT vendor_site_id
                  INTO ln_supplier_site_id
                  FROM ap_supplier_sites_all
                 WHERE     vendor_id = ln_supplier_id
                       AND vendor_site_code = pv_supplier_site
                       AND org_id = ln_operating_unit
                       AND (TRUNC (NVL (inactive_date, SYSDATE)) >= TRUNC (SYSDATE));
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || 'Invalid Supplier Site: '
                            || pv_supplier_site
                            || ' ',
                            1,
                            2000);
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || 'Error While Validating Supplier Site '
                            || SQLERRM
                            || '. ',
                            1,
                            2000);
            END;
        END IF;

        --If vendor inforamtion is not given get it from sourcing rules
        IF pv_supplier IS NULL AND pv_supplier_site IS NULL
        THEN
            BEGIN
                SELECT mso.vendor_id, mso.vendor_site_id
                  INTO ln_supplier_id, ln_supplier_site_id
                  FROM mrp_sr_assignments_v msa, mrp_assignment_sets mrpr, mrp_sr_receipt_org_v msr,
                       mrp_sr_source_org mso, mtl_category_sets mcs, mtl_item_categories mic
                 WHERE     msa.organization_id = ln_org_id -- Added for ver 1.2
                       --  msa.organization_id = 107  -- commented for ver 1.2
                       AND msa.category_id = mic.category_id
                       AND mrpr.assignment_set_name =
                           'Deckers Default Set-US-JP'
                       AND msa.assignment_set_id = mrpr.assignment_set_id
                       AND msr.sourcing_rule_id = msa.sourcing_rule_id
                       AND mso.sr_receipt_id = msr.sr_receipt_id
                       AND mcs.category_set_name = 'Inventory'
                       AND mcs.category_set_id = mic.category_set_id
                       AND mic.organization_id = ln_org_id
                       AND mic.inventory_item_id = ln_item_id
                       AND (TRUNC (NVL (disable_date, SYSDATE)) >= TRUNC (SYSDATE))
                       AND msa.assignment_type = 5;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || 'No Active Sourcing Rule Defined For The Item: '
                            || pv_sku
                            || ' And Organization: '
                            || pv_organization_code
                            || ' ',
                            1,
                            2000);
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                        SUBSTR (
                               lv_error_message
                            || 'Error While Getting Vendor Information From Souring Rule'
                            || SQLERRM
                            || '. ',
                            1,
                            2000);
            END;
        END IF;

        IF lv_error_message IS NULL
        THEN
            BEGIN
                INSERT INTO xxdo.xxd_po_pr_upd_stg (status,
                                                    error_message,
                                                    request_id,
                                                    created_by,
                                                    creation_date,
                                                    last_updated_by,
                                                    last_update_date,
                                                    last_update_login,
                                                    sku,
                                                    organization_code,
                                                    quantity,
                                                    need_by_date,
                                                    grouping_sequence,
                                                    supplier,
                                                    supplier_site,
                                                    item_id,
                                                    uom_code,
                                                    org_id,
                                                    supplier_id,
                                                    supplier_site_id,
                                                    sequence_id)
                         VALUES ('N',
                                 NULL,
                                 gn_request_id,
                                 gn_user_id,
                                 SYSDATE,
                                 gn_user_id,
                                 SYSDATE,
                                 gn_login_id,
                                 pv_sku,
                                 pv_organization_code,
                                 pn_quantity,
                                 pv_need_by_date,
                                 pn_grouping_number,
                                 pv_supplier,
                                 pv_supplier_site,
                                 ln_item_id,
                                 lv_uom_code,
                                 ln_org_id,
                                 ln_supplier_id,
                                 ln_supplier_site_id,
                                 xxdo.xxd_po_pr_upd_stg_sno.NEXTVAL);
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
    END;

    PROCEDURE group_sequence_validation (pv_error_message   OUT VARCHAR2,
                                         pv_error_code      OUT VARCHAR2)
    IS
        CURSOR cursor_req_seq (cv_request_id NUMBER)
        IS
            SELECT DISTINCT grouping_sequence
              FROM xxdo.xxd_po_pr_upd_stg
             WHERE status = 'N' AND request_id = cv_request_id;

        ln_org_id              NUMBER;
        -- ln_dest_org_id         NUMBER;
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
            ln_org_id              := NULL;
            --  ln_dest_org_id := NULL;
            ln_location_id         := NULL;
            ln_operating_unit_id   := NULL;
            ln_ccid                := NULL;

            BEGIN
                --validating grouping sequence
                SELECT DISTINCT org_id
                  INTO ln_org_id
                  FROM xxdo.xxd_po_pr_upd_stg
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
                            || 'Same grouping sequence must have same organization'
                            || '. ',
                            1,
                            2000);
                WHEN OTHERS
                THEN
                    lv_return_status   := g_ret_error;
                    lv_error_message   :=
                        SUBSTR (lv_error_message || SQLERRM || '. ', 1, 2000);
            END;

            IF ln_org_id IS NOT NULL
            THEN
                BEGIN
                    --getting operating unit
                    SELECT operating_unit
                      INTO ln_operating_unit_id
                      FROM apps.org_organization_definitions
                     WHERE organization_id = ln_org_id;
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
                     WHERE organization_id = ln_org_id;
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
                     WHERE organization_id = ln_org_id;
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
                    UPDATE xxdo.xxd_po_pr_upd_stg
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
                    SELECT xxd_po_pr_upd_stg_sno.NEXTVAL
                      INTO ln_batch_id
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_return_status   := g_ret_error;
                        lv_error_message   :=
                            SUBSTR (
                                   'Error while getting seq id from XXD_PO_PR_UPD_STG_SNO. Error is: '
                                || SQLERRM,
                                1,
                                2000);
                END;

                BEGIN
                    UPDATE xxdo.xxd_po_pr_upd_stg
                       SET operating_unit_id = ln_operating_unit_id, material_account = ln_ccid, location_id = ln_location_id,
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
                UPDATE xxdo.xxd_po_pr_upd_stg
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

    --Start changes for 1.3
    --Prevent duplicate SKU# line under same requisition
    PROCEDURE duplicate_sku_chk (pv_error_message   OUT VARCHAR2,
                                 pv_error_code      OUT VARCHAR2)
    IS
        CURSOR c_get_sku_dtls (p_request_id IN NUMBER)
        IS
            SELECT DISTINCT sku, organization_code, need_by_date,
                            grouping_sequence
              FROM xxdo.xxd_po_pr_upd_stg
             WHERE status = 'N' AND request_id = p_request_id;

        ln_multi_sku_exists   NUMBER := 0;
        lv_error_count        NUMBER := 0;
        lv_return_status      VARCHAR2 (1) := NULL;
        lv_error_message      VARCHAR2 (2000) := NULL;
    BEGIN
        FOR r_get_sku_dtls IN c_get_sku_dtls (gn_request_id)
        LOOP
            ln_multi_sku_exists   := 0;

            BEGIN
                --validate duplicate sku exists
                SELECT COUNT (1)
                  INTO ln_multi_sku_exists
                  FROM xxdo.xxd_po_pr_upd_stg
                 WHERE     status = 'N'
                       AND request_id = gn_request_id
                       AND sku = r_get_sku_dtls.sku
                       AND organization_code =
                           r_get_sku_dtls.organization_code
                       AND need_by_date = r_get_sku_dtls.need_by_date
                       AND grouping_sequence =
                           r_get_sku_dtls.grouping_sequence;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_multi_sku_exists   := -1;
                    lv_return_status      := g_ret_error;
                    lv_error_message      :=
                        SUBSTR (lv_error_message || SQLERRM || '. ', 1, 2000);
            END;

            IF NVL (ln_multi_sku_exists, 0) > 1
            THEN
                --If duplication SKU exists, stop processing valid records in the batch
                lv_error_count   := lv_error_count + 1;

                --Updating staging for Duplication SKUs
                BEGIN
                    UPDATE xxdo.xxd_po_pr_upd_stg
                       SET status = 'E', error_message = 'Duplicate records have been found for SKU'
                     WHERE     status = 'N'
                           AND request_id = gn_request_id
                           AND sku = r_get_sku_dtls.sku
                           AND organization_code =
                               r_get_sku_dtls.organization_code
                           AND need_by_date = r_get_sku_dtls.need_by_date
                           AND grouping_sequence =
                               r_get_sku_dtls.grouping_sequence;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_return_status   := g_ret_error;
                        pv_error_message   :=
                            SUBSTR (lv_error_message || SQLERRM || '. ',
                                    1,
                                    2000);
                END;
            END IF;
        END LOOP;

        IF NVL (lv_error_count, 0) > 0
        THEN
            --If duplication SKU exists, stop processing valid records in the batch
            BEGIN
                UPDATE xxdo.xxd_po_pr_upd_stg
                   SET status = 'E', error_message = 'Record cannot be processed as few records failed for duplication SKUs'
                 WHERE status = 'N' AND request_id = gn_request_id;

                pv_error_code   := 'E';
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_error_message   :=
                        SUBSTR (
                               'Error while update of duplication SKUs'
                            || SQLERRM,
                            1,
                            2000);
            END;
        ELSE
            pv_error_code      := NULL;
            pv_error_message   := NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_message   :=
                SUBSTR ('Error in duplicate_sku_chk procedure' || SQLERRM,
                        1,
                        2000);
    END duplicate_sku_chk;

    --End changes for 1.3

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

        INSERT INTO po_requisitions_interface_all (interface_source_code, requisition_type, org_id, authorization_status, charge_account_id, quantity, uom_code, group_code, item_id, need_by_date, preparer_id, deliver_to_requestor_id, source_type_code, destination_type_code, destination_organization_id, deliver_to_location_id, creation_date, created_by, last_update_date, last_updated_by, batch_id, line_num, suggested_vendor_id, suggested_vendor_site_id
                                                   , autosource_flag)
            (SELECT 'WEBADI',                         -- interface_source_code
                              'PURCHASE',                  -- Requisition_type
                                          operating_unit_id,
                    'INCOMPLETE',                      -- Authorization_Status
                                  material_account,    -- Destination org ccid
                                                    quantity,      -- Quantity
                    uom_code,                                      -- UOm Code
                              1,                                   -- Group_id
                                 item_id,
                    need_by_date,                             -- neeed by date
                                  ln_person_id,   -- Person id of the preparer
                                                ln_person_id, -- Person_id of the requestor
                    'VENDOR',                              -- source_type_code
                              'INVENTORY',            -- destination_type_code
                                           org_id,       -- Destination org id
                    location_id,                      --deliver to location id
                                 SYSDATE, gn_user_id,
                    SYSDATE, gn_user_id, interface_batch_id,
                    ROW_NUMBER () OVER (PARTITION BY stg.interface_batch_id ORDER BY stg.interface_batch_id, stg.sequence_id) line_number, supplier_id, supplier_site_id,
                    'P'                           -- Override sourincing rules
               FROM xxdo.xxd_po_pr_upd_stg stg
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
            SELECT DISTINCT interface_batch_id, operating_unit_id
              FROM xxdo.xxd_po_pr_upd_stg
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
            mo_global.set_policy_context (
                'S',
                cursor_interface_rec.operating_unit_id);
            fnd_request.set_org_id (cursor_interface_rec.operating_unit_id);
            ln_request_id   :=
                fnd_request.submit_request (
                    application   => 'PO',           -- application short name
                    program       => 'REQIMPORT',        -- program short name
                    description   => 'Requisition Import',      -- description
                    start_time    => SYSDATE,                    -- start date
                    sub_request   => FALSE,                     -- sub-request
                    argument1     => 'WEBADI',        -- interface source code
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
                    UPDATE xxdo.xxd_po_pr_upd_stg stg
                       SET status   = 'S',
                           requisition_number   =
                               (SELECT segment1
                                  FROM po_requisition_headers_all prh
                                 WHERE prh.request_id = ln_request_id)
                     WHERE     stg.status = 'N'
                           AND stg.request_id = gn_request_id
                           AND stg.interface_batch_id =
                               cursor_interface_rec.interface_batch_id
                           AND (stg.item_id, stg.quantity, stg.org_id,
                                TO_DATE (stg.need_by_date, 'DD-MON-YYYY')) IN
                                   (SELECT prl.item_id, prl.quantity, prl.destination_organization_id,
                                           prl.need_by_date
                                      FROM po_requisition_headers_all prh, po_requisition_lines_all prl, xxdo.xxd_po_pr_upd_stg stg
                                     WHERE     prh.request_id = ln_request_id
                                           AND prh.requisition_header_id =
                                               prl.requisition_header_id
                                           AND stg.status = 'N'
                                           AND stg.request_id = gn_request_id
                                           AND interface_batch_id =
                                               cursor_interface_rec.interface_batch_id
                                           AND stg.item_id = prl.item_id
                                           AND stg.quantity = prl.quantity
                                           AND stg.org_id =
                                               prl.destination_organization_id
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
                    UPDATE xxdo.xxd_po_pr_upd_stg stg
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
                    UPDATE xxdo.xxd_po_pr_upd_stg stg
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
        lv_error_message           VARCHAR2 (2000);
        lv_return_status           VARCHAR2 (1) := NULL;
        lv_proc_error_message      VARCHAR2 (2000);
        le_proc_error_exception    EXCEPTION;
        ln_person_id               NUMBER;
        lv_error_code              VARCHAR2 (1);
        --Start changes for 1.3
        lv_dup_sku_error_message   VARCHAR2 (2000);
        le_dup_sku_exception       EXCEPTION;
        lv_dup_err_code            VARCHAR2 (1);
    --End changes for 1.3
    BEGIN
        mo_global.init ('PO');

        --Updating staging table with request_id
        BEGIN
            UPDATE xxdo.xxd_po_pr_upd_stg
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

        --Start changes for 1.3
        BEGIN
            duplicate_sku_chk (lv_dup_sku_error_message, lv_dup_err_code);

            IF lv_dup_sku_error_message IS NOT NULL
            THEN
                RAISE le_dup_sku_exception;
            END IF;
        END;

        --End changes for 1.3

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
        --Start changes for 1.3
        WHEN le_dup_sku_exception
        THEN
            COMMIT;
            raise_application_error (-20000, lv_dup_sku_error_message);
        --End changes for 1.3
        WHEN OTHERS
        THEN
            COMMIT;
            lv_proc_error_message   :=
                SUBSTR (lv_proc_error_message || SQLERRM, 1, 2000);
            fnd_file.put_line (fnd_file.LOG, lv_proc_error_message);
            pv_retcode   := gn_error;
            RAISE;
    END importer_proc;

    PROCEDURE status_report (pv_error_message OUT VARCHAR2)
    IS
        CURSOR status_rep IS
              SELECT UPPER (stg.sku) item, stg.quantity, stg.need_by_date,
                     UPPER (stg.organization_code) ORGANIZATION, stg.grouping_sequence, --stg.supplier, stg.supplier_site, --Commented for CCR  CCR0007830
                                                                                        NVL (stg.supplier, ' ') supplier,
                     NVL (stg.supplier_site, ' ') supplier_site, --Added for CCR  CCR0007830
                                                                 NVL (stg.requisition_number, 'Not Created') requisition_number, DECODE (stg.status,  'S', 'Success',  'E', 'Error',  'N', 'Not Processed',  'Error') status,
                     stg.error_message
                FROM xxdo.xxd_po_pr_upd_stg stg
               WHERE stg.request_id = gn_request_id
            ORDER BY stg.sequence_id;
    BEGIN
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('SKU', 20, ' ')
            || CHR (9)
            || RPAD ('Destination Org', 20, ' ')
            || CHR (9)
            || RPAD ('Quantity', 10, ' ')
            || CHR (9)
            || RPAD ('Need By Date', 15, ' ')
            || CHR (9)
            || RPAD ('Requisition Grouping', 22, ' ')
            || CHR (9)
            || RPAD ('Supplier', 35, ' ')
            || CHR (9)
            || RPAD ('Supplier Site', 15, ' ')
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
                   RPAD (status_rep_rec.item, 20, ' ')
                || CHR (9)
                || RPAD (status_rep_rec.ORGANIZATION, 20, ' ')
                || CHR (9)
                || RPAD (status_rep_rec.quantity, 10, ' ')
                || CHR (9)
                || RPAD (status_rep_rec.need_by_date, 15, ' ')
                || CHR (9)
                || RPAD (status_rep_rec.grouping_sequence, 22, ' ')
                || CHR (9)
                || RPAD (status_rep_rec.supplier, 35, ' ')
                || CHR (9)
                || RPAD (status_rep_rec.supplier_site, 15, ' ')
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
END xxd_po_pr_upload_webadi_pkg;
/
