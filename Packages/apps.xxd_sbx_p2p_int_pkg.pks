--
-- XXD_SBX_P2P_INT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:25:36 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_SBX_P2P_INT_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_SBX_P2P_INT_PKG
    * Design       : This package will be used as hook in the Sabix Tax determination package
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 27-JUL-2020  1.0        Deckers                 Initial Version
    -- 02-APR-2021  1,1        Srinath Siricilla       CCR0009031
    -- 13-APR-2021  1.2        Srinath Siricilla       CCR0009257
    -- 01-DEC-2021  2.0        Srinath Siricilla       CCR0009257
    ******************************************************************************************/

    lv_procedure   VARCHAR2 (100);
    lv_location    VARCHAR2 (100);

    PROCEDURE update_line_prc (p_batch_id IN NUMBER, p_inv_id IN NUMBER, p_line_id IN NUMBER, p_user_element_attribute1 IN VARCHAR2:= NULL, p_user_element_attribute2 IN VARCHAR2:= NULL, p_user_element_attribute3 IN VARCHAR2:= NULL, p_user_element_attribute4 IN VARCHAR2:= NULL, p_user_element_attribute5 IN VARCHAR2:= NULL, p_user_element_attribute6 IN VARCHAR2:= NULL, p_user_element_attribute7 IN VARCHAR2:= NULL, p_user_element_attribute8 IN VARCHAR2:= NULL, p_user_element_attribute9 IN VARCHAR2:= NULL, p_user_element_attribute10 IN VARCHAR2:= NULL, p_user_element_attribute11 IN VARCHAR2:= NULL, -- Added as per CCR0009727
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          p_transaction_type IN VARCHAR2:= NULL
                               , p_sf_country IN VARCHAR2:= NULL);

    PROCEDURE update_header_prc (p_batch_id IN NUMBER, p_header_id IN NUMBER, -- Added as per CCR0009257
                                                                              p_calling_system_number IN NUMBER, p_ext_company_id IN VARCHAR2:= NULL, -- End of Change
                                                                                                                                                      p_user_element_attribute1 IN VARCHAR2:= NULL, p_user_element_attribute2 IN VARCHAR2:= NULL, p_user_element_attribute3 IN VARCHAR2:= NULL, p_user_element_attribute4 IN VARCHAR2:= NULL, p_user_element_attribute5 IN VARCHAR2:= NULL, p_user_element_attribute6 IN VARCHAR2:= NULL, p_user_element_attribute7 IN VARCHAR2:= NULL, p_user_element_attribute8 IN VARCHAR2:= NULL
                                 , p_user_element_attribute9 IN VARCHAR2:= NULL, p_user_element_attribute10 IN VARCHAR2:= NULL, p_user_element_attribute11 IN VARCHAR2:= NULL -- Added as per CCR0009727
                                                                                                                                                                             );

    PROCEDURE xxd_ap_sbx_pre_calc_prc (p_batch_id IN NUMBER);

    PROCEDURE xxd_po_sbx_pre_calc_prc (p_batch_id IN NUMBER);

    PROCEDURE xxd_req_sbx_pre_calc_prc (p_batch_id IN NUMBER);

    PROCEDURE xxd_p2p_sbx_post_calc_prc (p_batch_id IN NUMBER);

    FUNCTION get_category_seg_fnc (pn_category_id   IN     NUMBER,
                                   x_seg1              OUT VARCHAR2,
                                   x_seg2              OUT VARCHAR2,
                                   x_seg3              OUT VARCHAR2,
                                   x_err_msg           OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_ship_from_fnc (pn_inv_org_id   IN     NUMBER,
                                x_err_msg          OUT VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION invoice_type_fnc (pn_invoice_id   IN     NUMBER,
                               x_err_msg          OUT VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION invoice_source_fnc (pn_invoice_id   IN     NUMBER,
                                 x_err_msg          OUT VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_po_category_fnc (pn_header_id IN NUMBER, pn_line_loc_id IN NUMBER, x_err_msg OUT VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_ship_to_org_fnc (pn_line_loc_id   IN     NUMBER,
                                  x_err_msg           OUT VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_item_tax_class_fnc (pn_line_loc_id IN NUMBER, pn_ship_to_organization_id IN NUMBER, x_err_msg OUT VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_natural_acc_fnc (pn_invoice_id IN NUMBER, pn_line_number IN NUMBER, x_err_msg OUT VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION check_multi_period_flag_fnc (pn_invoice_id IN NUMBER, pn_line_number IN NUMBER, x_err_msg OUT VARCHAR2)
        RETURN NUMBER;

    PROCEDURE debug_prc (p_batch_id NUMBER, p_procedure VARCHAR2, p_location VARCHAR2
                         , p_message VARCHAR2, p_severity VARCHAR2 DEFAULT 0);

    PROCEDURE update_inv_prc (p_batch_id IN NUMBER, p_inv_id IN NUMBER);

    -- Start of Change for CCR0009103
    FUNCTION bypass_tax_fnc (p_event_class_code IN VARCHAR2, p_appl_id IN NUMBER, p_entity_code IN VARCHAR2
                             , p_trx_id IN NUMBER)
        RETURN NUMBER;
-- End of Change fpr CCR0009103

END XXD_SBX_P2P_INT_PKG;
/
