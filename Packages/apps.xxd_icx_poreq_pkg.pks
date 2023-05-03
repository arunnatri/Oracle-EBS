--
-- XXD_ICX_POREQ_PKG  (Package) 
--
--  Dependencies: 
--   FND_API (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:21:11 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ICX_POREQ_PKG"
IS
    /***********************************************************************************
     *$header     :                                                                   *
     *                                                                                *
     * AUTHORS    : Srinath Siricilla                                                 *
     *                                                                                *
     * PURPOSE    : Mass Creation/Updation of Requisitions through WEBADI             *
     *                                                                                *
     * PARAMETERS :                                                                   *
     *                                                                                *
     * DATE       :  03-FEB-2020                                                      *
     *                                                                                *
     * Assumptions:                                                                   *
     *                                                                                *
     *                                                                                *
     * History                                                                        *
     * Vsn     Change Date  Changed By            Change Description                  *
     * -----   -----------  ------------------    ------------------------------------*
     * 1.1     03-FEB-2020  Srinath Siricilla     CCR0008385                          *
     *********************************************************************************/
    --Global Variables
    -- Return Statuses
    g_ret_success       CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_success;
    g_ret_error         CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_error;
    g_ret_unexp_error   CONSTANT VARCHAR2 (1)
                                     := fnd_api.g_ret_sts_unexp_error ;
    g_ret_warning       CONSTANT VARCHAR2 (1) := 'W';
    g_ret_valid         CONSTANT VARCHAR2 (1) := 'V';
    gn_success          CONSTANT NUMBER := 0;
    gn_warning          CONSTANT NUMBER := 1;
    gn_error            CONSTANT NUMBER := 2;

    --Main Procedure called by WebADI
    PROCEDURE upload_proc (pn_cart_num NUMBER, pn_cart_line_num NUMBER, pv_operating_unit VARCHAR2, pv_po_item_cat VARCHAR2, pv_item_type VARCHAR2, pv_item_desc VARCHAR2 DEFAULT NULL, pv_requester VARCHAR2 DEFAULT NULL, pn_quantity NUMBER DEFAULT NULL, pv_uom VARCHAR2 DEFAULT NULL, pn_unit_price NUMBER DEFAULT NULL, pn_amount NUMBER DEFAULT NULL, pv_currency VARCHAR2 DEFAULT NULL, pv_vendor_name VARCHAR2 DEFAULT NULL, pv_vendor_site VARCHAR2 DEFAULT NULL, pd_need_by_date DATE DEFAULT NULL, pv_charge_account VARCHAR2 DEFAULT NULL, pv_deliver_to_loc VARCHAR2 DEFAULT NULL, pv_justification VARCHAR2, pv_requisition_num VARCHAR2, pv_attribute1 VARCHAR2, pv_attribute2 VARCHAR2, pv_attribute3 VARCHAR2, pv_attribute4 VARCHAR2, pv_attribute5 VARCHAR2, pv_attribute6 VARCHAR2, pv_attribute7 VARCHAR2, pv_attribute8 VARCHAR2, pv_attribute9 VARCHAR2, pv_attribute10 VARCHAR2, pv_attribute11 VARCHAR2, pv_attribute12 VARCHAR2, pv_attribute13 VARCHAR2, pv_attribute14 VARCHAR2
                           , pv_attribute15 VARCHAR2);

    PROCEDURE validate_staging (pn_request_id    IN     NUMBER,
                                pv_ret_message      OUT VARCHAR2);

    PROCEDURE submit_import_proc (pn_request_id IN NUMBER);

    PROCEDURE importer_proc;

    PROCEDURE purge_data (pv_ret_message OUT VARCHAR2);

    FUNCTION validate_cost_center (pn_requester_id IN NUMBER)
        RETURN VARCHAR2;

    PROCEDURE get_cost_center (pn_resp_id        IN     NUMBER,
                               pn_requester_id   IN     NUMBER,
                               pn_cc             IN     NUMBER,
                               x_cost_center        OUT NUMBER,
                               x_person_id          OUT NUMBER);

    PROCEDURE check_req_valid_prc (pn_resp_id IN NUMBER, pn_requester_id IN NUMBER, x_cc OUT VARCHAR2
                                   , x_req OUT VARCHAR2);

    FUNCTION get_supervisor_id (pn_requester_id IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_company_segment (p_org_id IN NUMBER)
        RETURN NUMBER;

    PROCEDURE insert_into_interface_table (pv_error_message OUT VARCHAR2);

    FUNCTION check_expense_or_asset (p_unit_price IN NUMBER, p_category_id IN NUMBER, p_currency_code IN VARCHAR2)
        RETURN VARCHAR2;

    PROCEDURE status_report (pn_request_id          IN     NUMBER,
                             x_proc_error_message      OUT VARCHAR2);
END XXD_ICX_POREQ_PKG;
/
