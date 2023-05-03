--
-- XXD_PO_REQ_SUPP_UPD_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:29 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PO_REQ_SUPP_UPD_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_PO_REQ_SUPP_UPD_PKG
    * Design       : This package is used for Supplier update on PR WebADI
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 14-Apr-2019  1.0        Gaurav Joshi     Initial Version
 -- 07-jUL-2019  1.1        Gaurav Joshi     Submit for Approval (changes for CCR#CCR0008063 )
    ******************************************************************************************/
    PROCEDURE update_prc (p_operating_unit IN hr_operating_units.name%TYPE, p_requisition_header_id IN po_requisition_lines_all.requisition_header_id%TYPE, p_requisition_number IN po_requisition_headers_all.segment1%TYPE, p_authorization_status IN po_requisition_headers_all.authorization_status%TYPE, p_requisition_line_id IN po_requisition_lines_all.requisition_line_id%TYPE, p_requisition_line_num IN po_requisition_lines_all.line_num%TYPE, p_inventory_item IN mtl_system_items_b.segment1%TYPE, p_quantity IN po_requisition_lines_all.quantity%TYPE, p_need_by_date IN po_requisition_lines_all.need_by_date%TYPE, p_dest_org IN mtl_parameters.organization_code%TYPE, p_curr_supplier_name IN ap_suppliers.vendor_name%TYPE, p_curr_supplier_site_code IN ap_supplier_sites_all.vendor_site_code%TYPE
                          , p_new_supplier_name IN ap_suppliers.vendor_name%TYPE, p_new_supplier_site_code IN ap_supplier_sites_all.vendor_site_code%TYPE)
    AS
        le_webadi_exception   EXCEPTION;
        lc_return_status      VARCHAR2 (10);
        lc_err_message        VARCHAR2 (4000);
        lc_ret_message        VARCHAR2 (4000);
        lc_error_msg          VARCHAR2 (4000);
        ln_org_id             hr_operating_units.organization_id%TYPE
                                  DEFAULT fnd_global.org_id;
        ln_application_id     fnd_application.application_id%TYPE;
        ln_vendor_id          ap_suppliers.vendor_id%TYPE;
        ln_vendor_site_id     ap_supplier_sites_all.vendor_site_id%TYPE;
        l_req_line            po_requisition_update_pub.req_line_rec_type;
        /**Begin Changes:  ver 1.1  Declare needed variables for preparer update**/
        l_progress            VARCHAR2 (4);
        l_msg_data            VARCHAR2 (2000);
        l_msg_count           NUMBER;
        l_return_status       VARCHAR2 (1);
        l_update_person       VARCHAR2 (200);
        l_old_preparer_id     NUMBER;
        l_new_preparer_id     NUMBER;
        l_document_type       VARCHAR2 (200);
        l_document_no_from    VARCHAR2 (200);
        l_document_no_to      VARCHAR2 (200);
        l_date_from           VARCHAR2 (200);
        l_date_to             VARCHAR2 (200);
        l_commit_interval     NUMBER;
        x_date_from           DATE;
        x_date_to             DATE;
        ln_req_preparer_id    NUMBER;
    /**End Changes:  ver 1.1  Declare needed variables for preparer update**/
    BEGIN
        -- Derive Org ID
        BEGIN
            SELECT organization_id
              INTO ln_org_id
              FROM hr_operating_units
             WHERE name = p_operating_unit;
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_err_message   :=
                    lc_err_message || 'Unable to derive Org ID.';
        END;

        /**Begin Changes:  ver 1.1  check the preparer of this PR **/
        -- webadi wont pass readonly fields back to plsql, so had to use requisition_line_id ti derive  preparer_id
        BEGIN
            SELECT preparer_id
              INTO ln_req_preparer_id
              FROM po_requisition_headers_all a, po_requisition_lines_all b
             WHERE     a.requisition_header_id = b.requisition_header_id
                   AND b.requisition_line_id = p_requisition_line_id
                   AND a.org_id = ln_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_err_message   :=
                    lc_err_message || 'Unable to derive Preparer id.';
        END;

        /**End Changes:  ver 1.1 check the preparer of this PR**/
        -- Derive Appl ID
        BEGIN
            SELECT application_id
              INTO ln_application_id
              FROM fnd_responsibility_vl
             WHERE responsibility_id = fnd_global.resp_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_err_message   :=
                    lc_err_message || 'Unable to derive Application ID.';
        END;

        -- Validate New Supplier
        IF p_new_supplier_name IS NULL
        THEN
            lc_err_message   :=
                lc_err_message || 'New Supplier Name cannot be blank.';
        ELSE
            BEGIN
                SELECT vendor_id
                  INTO ln_vendor_id
                  FROM ap_suppliers
                 WHERE vendor_name = p_new_supplier_name;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_err_message   :=
                        lc_err_message || 'Unable to derive Vendor ID.';
            END;
        END IF;

        -- Validate New Supplier Site
        IF p_new_supplier_site_code IS NULL
        THEN
            lc_err_message   :=
                lc_err_message || 'New Supplier Site Code cannot be blank.';
        ELSIF     p_new_supplier_site_code IS NOT NULL
              AND ln_vendor_id IS NOT NULL
              AND ln_org_id IS NOT NULL
        THEN
            BEGIN
                SELECT vendor_site_id
                  INTO ln_vendor_site_id
                  FROM ap_supplier_sites_all
                 WHERE     vendor_id = ln_vendor_id
                       AND vendor_site_code = p_new_supplier_site_code
                       AND org_id = ln_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_err_message   :=
                        lc_err_message || 'Unable to derive Vendor Site ID.';
            END;
        END IF;

        -- Check Errors
        IF lc_err_message IS NOT NULL
        THEN
            RAISE le_webadi_exception;
        -- Call API
        ELSE
            mo_global.init ('PO');
            mo_global.set_policy_context ('S', ln_org_id);
            fnd_global.apps_initialize (fnd_global.user_id,
                                        fnd_global.resp_id,
                                        ln_application_id);

            l_req_line.requisition_header_id   := p_requisition_header_id;
            l_req_line.requisition_line_id     := p_requisition_line_id;
            l_req_line.org_id                  := ln_org_id;
            l_req_line.vendor_id               := ln_vendor_id;
            l_req_line.vendor_site_id          := ln_vendor_site_id;
            l_req_line.action_flag             := 'UPDATE';

            /**Begin Changes:  ver 1.1  update  preparer id with buyer id i.e. the current person using this webadi at this moment with an assumption that only buyer has acccess to this webadi **/

            IF fnd_global.employee_id <> ln_req_preparer_id
            THEN
                -- if the preparer on this PR is not logged in user then only call this; and also this will avoid duplicate call of below code if the preparer has already been updated in the first call

                l_update_person      := 'PREPARER';
                l_old_preparer_id    := ln_req_preparer_id; -- person id of  current preparer
                l_new_preparer_id    := fnd_global.EMPLOYEE_ID; -- Pass New Person Id
                l_document_type      := 'PURCHASE';
                l_document_no_from   := p_requisition_number; -- keeping to and from PR number as same
                l_document_no_to     := p_requisition_number; -- keeping to and from PR number as same
                l_commit_interval    := 100000000; -- keeping it higher so that below API wont commit by its own. API has logic to compre l_commit_interval with NO of eligble records and then commit.
                x_date_from          := TO_DATE (NULL);
                x_date_to            := TO_DATE (NULL);
                -- we dont have any pub API to update preparer_id and the same is not updatable using po_requisition_update_pub.update_requisition_line, so using below API after taking consent from Srini.
                PO_Mass_Update_Req_GRP.Update_Persons (
                    p_update_person      => l_update_person,
                    p_old_personid       => l_old_preparer_id,
                    p_new_personid       => l_new_preparer_id,
                    p_document_type      => l_document_type,
                    p_document_no_from   => l_document_no_from,
                    p_document_no_to     => l_document_no_to,
                    p_date_from          => x_date_from,
                    p_date_to            => x_date_to,
                    p_commit_interval    => l_commit_interval,
                    p_msg_data           => l_msg_data,
                    p_msg_count          => l_msg_count,
                    p_return_status      => l_return_status);

                IF l_return_status <> 'S'
                THEN
                    lc_err_message   :=
                        lc_err_message || SUBSTR (lc_error_msg, 1, 3900);
                    RAISE le_webadi_exception;
                END IF;
            END IF;

            /**End Chnages:  ver 1.1  update  preparer id with buyer id**/

            po_requisition_update_pub.update_requisition_line (
                p_req_line          => l_req_line,
                p_init_msg          => fnd_api.g_false,
                p_submit_approval   => 'Y',     -- ver 1.1 submit for approval
                x_return_status     => lc_return_status,
                x_error_msg         => lc_error_msg,
                p_commit            => 'N');

            IF lc_return_status <> 'S'
            THEN
                lc_err_message   :=
                    lc_err_message || SUBSTR (lc_error_msg, 1, 3900);
                RAISE le_webadi_exception;
            END IF;
        END IF;
    EXCEPTION
        WHEN le_webadi_exception
        THEN
            fnd_message.set_name ('XXDO', 'XXD_ORDER_UPLOAD_WEBADI_MSG');
            fnd_message.set_token ('ERROR_MESSAGE', lc_err_message);
            lc_ret_message   := fnd_message.get ();
            raise_application_error (-20000, lc_ret_message);
        WHEN OTHERS
        THEN
            lc_ret_message   := SQLERRM;
            raise_application_error (-20001, lc_ret_message);
    END update_prc;
END xxd_po_req_supp_upd_pkg;
/
