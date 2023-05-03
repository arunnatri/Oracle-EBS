--
-- XXD_PO_POMODIFY_PKG  (Package) 
--
--  Dependencies: 
--   XXD_PO_UTIL_PR_UPD_OBJ_TYP (Synonym)
--   XXD_STYLE_COLOR_TYPE (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:24:44 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_PO_POMODIFY_PKG"
IS
    /****************************************************************************************
    * Package      : XXD_PO_POMODIFY_PKG
    * Design       : This package is used to modify purcahse order from PO Modify Utility OA Page
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 16-Aug-2019  1.0        Tejaswi Gangumalla      Initial version
    -- 16-Apr-2020  1.1        Tejaswi Gangumalla      CCR0008501
    -- 29-Jun-2021  2.0        Gaurav Joshi            CCR0009391 - PO Modify Utility Bug
    ******************************************************************************************/
    --Main Procedure called by OAF to modify PO
    PROCEDURE upload_proc (p_user_id IN NUMBER, p_resp_id IN NUMBER, p_seq_number IN NUMBER, p_po_number IN NUMBER, p_org_id IN NUMBER, p_action IN VARCHAR2, p_to_po_number IN NUMBER, p_dest_org_id IN NUMBER, p_style_color IN xxd_style_color_type
                           , p_vendor_id IN NUMBER, p_vendor_site_id IN NUMBER, p_err_msg OUT VARCHAR2);

    PROCEDURE process_transaction (pv_errbuf         OUT VARCHAR2,
                                   pv_retcode        OUT NUMBER,
                                   p_batch_id     IN     NUMBER,
                                   p_request_id   IN     NUMBER,    -- VER 2.0
                                   p_user_id      IN     NUMBER DEFAULT NULL);

    PROCEDURE move_po_action (pn_user_id               IN     NUMBER,
                              pn_batch_id              IN     NUMBER,
                              pn_po_header_id          IN     NUMBER,
                              pn_source_pr_header_id   IN     NUMBER,
                              pn_move_po_header_id     IN     NUMBER,
                              pv_action_type           IN     VARCHAR2,
                              pv_intercompany_flag     IN     VARCHAR2,
                              pv_error_message            OUT VARCHAR2);

    PROCEDURE change_supplier_action (pn_user_id             IN     NUMBER,
                                      pn_batch_id            IN     NUMBER,
                                      pn_po_header_id        IN     NUMBER,
                                      pn_vendor_id           IN     NUMBER,
                                      pn_vendor_site_id      IN     NUMBER,
                                      pv_action_type         IN     VARCHAR2,
                                      pv_intercompany_flag   IN     VARCHAR2,
                                      pv_error_message          OUT VARCHAR2);

    PROCEDURE move_org_action (pn_user_id IN NUMBER, pn_batch_id IN NUMBER, pn_po_header_id IN NUMBER, pn_source_pr_header_id IN NUMBER, pn_dest_org_id IN NUMBER, pv_action_type IN VARCHAR2
                               , pv_intercompany_flag IN VARCHAR2, move_org_operating_unit_flag IN VARCHAR2, pv_error_message OUT VARCHAR2);

    PROCEDURE submit_process_trans_prog (pn_user_id         IN     NUMBER,
                                         pn_resp_id         IN     NUMBER,
                                         pn_batch_id        IN     NUMBER,
                                         pn_request_id      IN     NUMBER, -- VER 2.0
                                         pv_error_message      OUT VARCHAR2);

    /* Start of changes for change 1.1*/
    PROCEDURE upload_pr_proc (p_user_id IN NUMBER, p_resp_id IN NUMBER, p_action IN VARCHAR2, p_seq_number IN NUMBER, p_header_id IN NUMBER, p_new_vendor_id IN NUMBER, p_new_vendor_site_id IN NUMBER, p_org_id IN NUMBER, p_line_record IN xxd_po_util_pr_upd_obj_typ
                              , p_err_msg OUT VARCHAR2);

    PROCEDURE submit_pr_trans_prog (pn_user_id IN NUMBER, pn_resp_id IN NUMBER, pn_batch_id IN NUMBER
                                    , pv_error_message OUT VARCHAR2);

    PROCEDURE process_pr_transaction (pv_errbuf OUT VARCHAR2, pv_retcode OUT NUMBER, p_batch_id IN NUMBER
                                      , p_user_id IN NUMBER DEFAULT NULL);

    PROCEDURE change_pr_supplier (pn_user_id IN NUMBER, pn_batch_id IN NUMBER, pv_error_message OUT VARCHAR2);
/* End of changes for change 1.1*/
END xxd_po_pomodify_pkg;
/
