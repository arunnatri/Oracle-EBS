--
-- XXD_PO_POMODIFY_UTILS_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--   XXD_PO_ISO_DET_TYPE (Type)
--   XXD_PO_LINE_DET_TYPE (Type)
--
/* Formatted on 4/26/2023 4:24:45 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_PO_POMODIFY_UTILS_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_PO_POMODIFY_UTILS_PKG
    * Design       : This package is used to modify purchase order from PO Modify Utility OA Page
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 16-Aug-2019  1.0        Tejaswi Gangumalla      Initial version
    -- 14-Apr-2010  1.1        Tejaswi Gangumalla      CCR0008501
    -- 09-Jun-2020  1.2        Kranthi Bollam          CCR0008710 - Fix Incorrect Ship to Location on Distributor PO's
    -- 29-jun-2021  2.0        Gaurav Joshi            CCR0009391 - PO Modify Utility Bug
    -- 25-May-2022  2.1        Aravind Kannuri         CCR0010003 - POC Enhancements
    ******************************************************************************************/
    PROCEDURE cancel_po_line (pn_user_id IN NUMBER, pn_header_id IN NUMBER, pn_line_id IN NUMBER
                              , pv_cancel_req_line IN VARCHAR2, pv_status_flag OUT VARCHAR2, pv_error_message OUT VARCHAR2);

    PROCEDURE cancel_req_line (pn_user_id         IN     NUMBER,
                               pn_req_header_id   IN     NUMBER,
                               pn_req_line_id     IN     NUMBER,
                               pv_status_flag        OUT VARCHAR2,
                               pv_error_message      OUT VARCHAR2);

    PROCEDURE cancel_so_line (pn_user_id         IN     NUMBER,
                              pn_header_id       IN     NUMBER,
                              pn_line_id         IN     NUMBER,
                              pv_status_flag        OUT VARCHAR2,
                              pv_error_message      OUT VARCHAR2);

    PROCEDURE create_purchase_req (pn_user_id IN NUMBER, pn_header_id IN NUMBER, pt_line_det IN xxdo.xxd_po_line_det_type, pn_dest_org_id IN NUMBER, pn_vendor_id IN NUMBER, pn_vendor_site_id IN NUMBER, pv_new_req_num OUT VARCHAR2, pn_req_import_id OUT NUMBER, pv_error_flag OUT VARCHAR2
                                   , pv_error_message OUT VARCHAR2);

    PROCEDURE add_lines_to_po (
        -- pn_header_id            IN            NUMBER,
        pv_intercompany_flag   IN     VARCHAR2,                     -- Ver 2.0
        pn_user_id             IN     NUMBER,
        pn_move_po_header_id   IN     NUMBER,
        pn_new_req_header_id   IN     NUMBER,
        pt_line_det            IN     xxdo.xxd_po_line_det_type,
        pn_batch_id               OUT NUMBER,
        pv_error_flag             OUT VARCHAR2,
        pv_error_message          OUT VARCHAR2);

    PROCEDURE create_po (pn_user_id IN NUMBER, pn_header_id IN NUMBER, pn_new_vendor_id IN NUMBER, pn_new_vendor_site_id IN NUMBER, pt_line_det IN xxdo.xxd_po_line_det_type, pn_new_req_header_id IN NUMBER, pn_new_inv_org_id IN NUMBER, pv_intercompany_flag IN VARCHAR2, -- Ver 2.0
                                                                                                                                                                                                                                                                             pv_action_type IN VARCHAR2, pv_new_document_num OUT VARCHAR2, pn_batch_id OUT NUMBER, pv_error_flag OUT VARCHAR2
                         , pv_error_msg OUT VARCHAR2);

    PROCEDURE update_drop_ship (pn_user_id            IN     NUMBER,
                                pn_req_header_id      IN     NUMBER,
                                pn_req_line_id        IN     NUMBER,
                                pn_po_header_id       IN     NUMBER,
                                pn_po_line_id         IN     NUMBER,
                                pn_line_location_id   IN     NUMBER,
                                pv_error_flag            OUT VARCHAR2,
                                pv_error_msg             OUT VARCHAR2);

    PROCEDURE update_po_requisition_line (pn_user_id IN NUMBER, pn_requistion_header_id IN NUMBER, pn_vendor_id IN NUMBER, pn_vendor_site_id IN NUMBER, pn_org_id IN NUMBER, pt_line_det IN xxdo.xxd_po_line_det_type
                                          , pn_req_auto_approval IN VARCHAR2, pv_error_flag OUT VARCHAR2, pv_error_msg OUT VARCHAR2);

    PROCEDURE update_po_req_link (pn_line_id IN NUMBER, pv_error_flag OUT VARCHAR2, pv_error_message OUT VARCHAR2);

    PROCEDURE approve_requisition (pn_requistion_header_id IN NUMBER, pv_error_flag OUT VARCHAR2, pv_error_message OUT VARCHAR2);

    FUNCTION get_destination_org (pn_header_id IN NUMBER)
        RETURN VARCHAR2;

    PROCEDURE create_pr_from_iso (pt_order_header_id IN xxdo.xxd_po_iso_det_type, --ISO to process
                                                                                  pt_line_det IN xxdo.xxd_po_line_det_type, pn_vendor_id IN NUMBER, pn_vedor_site_id IN NUMBER, pn_user_id IN NUMBER, pv_new_req_num OUT VARCHAR2
                                  , pn_request_id OUT NUMBER, pv_error_flag OUT VARCHAR2, pv_error_msg OUT VARCHAR2);

    PROCEDURE link_iso_and_po (pn_order_header_id   IN     NUMBER,
                               pv_error_msg            OUT VARCHAR2);

    /* Added below procedure for change 1.2*/
    PROCEDURE update_po_need_by_date (pn_user_id IN NUMBER, pn_po_number IN VARCHAR2, pv_error_flag OUT VARCHAR2
                                      , pv_error_msg OUT VARCHAR2);

    --Start Added for CCR0010003
    FUNCTION get_po_country_code (pn_po_header_id IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_pol_transit_days (pv_new_po_num         IN VARCHAR2,
                                   pv_action             IN VARCHAR2,
                                   pn_vendor_id          IN NUMBER,
                                   pn_vendor_site_id     IN NUMBER,
                                   pv_vendor_site_code   IN VARCHAR2)
        RETURN NUMBER;

    PROCEDURE update_calc_need_by_date (pn_user_id IN NUMBER, pn_po_number IN VARCHAR2, pn_transit_days IN NUMBER, pn_vendor_id IN NUMBER DEFAULT NULL, pn_vendor_site_id IN NUMBER DEFAULT NULL, pn_source_po_header_id IN NUMBER DEFAULT NULL, pn_source_pr_header_id IN NUMBER DEFAULT NULL, pv_action IN VARCHAR2, pv_error_flag OUT VARCHAR2
                                        , pv_error_msg OUT VARCHAR2);
--End Added for CCR0010003
END xxd_po_pomodify_utils_pkg;
/
