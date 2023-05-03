--
-- XXD_PO_PRC_MODIFY_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--   XXD_PO_BATCH_HDR_TBL_TYP (Type)
--   XXD_PO_PRICE_UPD_TBL_TYP (Type)
--
/* Formatted on 4/26/2023 4:24:48 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_PO_PRC_MODIFY_PKG"
IS
    /****************************************************************************************
    * Package      : XXD_PO_PRC_MODIFY_PKG
    * Design       : This package is used to modify purcahse order Price from PO Price Utility OA Page
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 16-Aug-2020  1.0        Gaurav      Initial version
    ******************************************************************************************/
    PROCEDURE main (
        p_batch_id      IN            NUMBER,
        p_org_id        IN            NUMBER,
        p_resp_id       IN            NUMBER,
        p_resp_app_id   IN            NUMBER,
        p_user_id       IN            NUMBER,
        p_style_color   IN            xxdo.xxd_po_price_upd_tbl_typ,
        p_mode          IN            VARCHAR2,
        x_ret_status       OUT NOCOPY VARCHAR2,
        x_err_msg          OUT NOCOPY VARCHAR2);

    PROCEDURE process_price_update (x_ret_status OUT NOCOPY VARCHAR2, x_err_msg OUT NOCOPY VARCHAR2, p_batch_id IN NUMBER);

    PROCEDURE approver_action (x_ret_status OUT NOCOPY VARCHAR2, x_err_msg OUT NOCOPY VARCHAR2, p_batch_id IN VARCHAR2
                               , p_po_header_id IN VARCHAR2);

    FUNCTION approve_po (pn_header_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION po_status (pn_header_id IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION style_color_status (pn_header_id         IN NUMBER,
                                 p_style              IN VARCHAR2,
                                 p_color              IN VARCHAR2,
                                 p_factory_date       IN VARCHAR2,
                                 p_vendor_site_code   IN VARCHAR2)
        RETURN VARCHAR2;

    PROCEDURE submit_for_approval (p_resp_id IN NUMBER, p_resp_app_id IN NUMBER, p_user_id IN NUMBER, p_action IN VARCHAR2, p_batch_hdr IN xxdo.xxd_po_batch_hdr_tbl_typ, x_ret_status OUT NOCOPY VARCHAR2
                                   , x_err_msg OUT NOCOPY VARCHAR2);

    PROCEDURE user_role (p_user_id IN NUMBER, x_role OUT NOCOPY VARCHAR2);

    PROCEDURE process_file (p_file_id IN NUMBER, x_ret_status OUT NOCOPY VARCHAR2, x_err_msg OUT NOCOPY VARCHAR2
                            , x_batch_id OUT NOCOPY VARCHAR2);
END XXD_PO_PRC_MODIFY_PKG;
/
