--
-- XXD_SBX_O2C_INT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:25:35 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_SBX_O2C_INT_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_SBX_P2P_INT_PKG
    * Design       : This package will be used as hook in the Sabix Tax determination package
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                      Comments
    -- ======================================================================================
    -- 27-JUL-2020  1.0        Deckers                   Initial Version
    -- 01-AUG-2022  1.1        Srinath Siricilla         CCR0009857
    ******************************************************************************************/

    lv_procedure   VARCHAR2 (100);
    lv_location    VARCHAR2 (100);


    PROCEDURE xxd_ont_sbx_pre_calc_prc (p_batch_id IN NUMBER);

    PROCEDURE xxd_ar_sbx_pre_calc_prc (p_batch_id IN NUMBER);

    PROCEDURE xxd_ar_sbx_post_calc_prc (p_batch_id IN NUMBER);

    PROCEDURE xxd_o2c_sbx_post_calc_prc (p_batch_id IN NUMBER);

    FUNCTION get_batch_source_fnc (pn_batch_source_id IN NUMBER, pn_org_id IN NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN VARCHAR;

    FUNCTION get_sales_order_id_fnc (pn_so_num IN NUMBER, pn_org_id IN NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN NUMBER;

    FUNCTION check_drop_ship_order_fnc (pn_header_id IN NUMBER, pn_line_id IN NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_vendor_addr_fnc (pn_site_id IN NUMBER, x_city OUT VARCHAR2, x_postal_code OUT VARCHAR2, x_state OUT VARCHAR2, x_province OUT VARCHAR2, x_county OUT VARCHAR2
                                  , x_country_code OUT VARCHAR2, x_cntry_name OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_revenue_account_fnc (pn_customer_trx_id IN NUMBER, pn_cust_trx_line_id IN NUMBER, pn_set_of_books_id IN NUMBER
                                      , pn_org_id IN NUMBER, pn_batch_id IN NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_item_tax_class_fnc (pn_inv_item_id IN NUMBER, pn_warehouse_id IN NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_memo_line_desc_fnc (pv_desc IN VARCHAR2, pn_org_id IN NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN NUMBER;

    FUNCTION is_manual_invoice_fnc (pn_cust_trx_type_id IN NUMBER, pn_org_id IN NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_ship_from_fnc (pn_inv_org_id   IN     NUMBER,
                                x_ret_msg          OUT VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_ship_add_fnc (pn_site_id IN NUMBER, x_ship_country OUT VARCHAR2, x_ship_province OUT VARCHAR2
                               , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION check_ecom_org_fnc (pn_org_id IN NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_original_id_fnc (pn_header_id   IN     NUMBER,
                                  pn_line_id     IN     NUMBER,
                                  x_header_id       OUT NUMBER,
                                  x_line_id         OUT NUMBER,
                                  x_ret_msg         OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_original_trx_date_fnc (pn_line_id IN NUMBER, pn_org_id IN NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN DATE;

    PROCEDURE debug_prc (p_batch_id NUMBER, p_procedure VARCHAR2, p_location VARCHAR2
                         , p_message VARCHAR2, p_severity VARCHAR2 DEFAULT 0);

    PROCEDURE update_inv_prc (p_batch_id IN NUMBER, p_inv_id IN NUMBER);

    PROCEDURE update_line_prc (
        p_batch_id                   IN NUMBER,
        p_inv_id                     IN NUMBER,
        p_line_id                    IN NUMBER,
        p_user_element_attribute1    IN VARCHAR2 := NULL,
        p_user_element_attribute2    IN VARCHAR2 := NULL,
        p_user_element_attribute3    IN VARCHAR2 := NULL,
        p_user_element_attribute4    IN VARCHAR2 := NULL,
        p_user_element_attribute5    IN VARCHAR2 := NULL,
        p_user_element_attribute6    IN VARCHAR2 := NULL,
        p_user_element_attribute7    IN VARCHAR2 := NULL,
        p_user_element_attribute8    IN VARCHAR2 := NULL,
        p_user_element_attribute9    IN VARCHAR2 := NULL,
        p_user_element_attribute10   IN VARCHAR2 := NULL,
        p_transaction_type           IN VARCHAR2 := NULL,
        p_tax_determination_date     IN DATE := NULL,
        p_sf_country                 IN VARCHAR2 := NULL,
        p_product_code               IN VARCHAR2 := NULL,
        p_st_country                 IN VARCHAR2 := NULL,
        p_st_province                IN VARCHAR2 := NULL,
        p_sf_state                   IN VARCHAR2 := NULL,
        p_sf_district                IN VARCHAR2 := NULL,
        p_sf_province                IN VARCHAR2 := NULL,
        p_sf_postcode                IN VARCHAR2 := NULL,
        p_sf_city                    IN VARCHAR2 := NULL,
        p_sf_geocode                 IN VARCHAR2 := NULL,
        p_sf_county                  IN VARCHAR2 := NULL);

    PROCEDURE update_header_prc (p_batch_id IN NUMBER, p_header_id IN NUMBER, p_user_element_attribute1 IN VARCHAR2:= NULL, p_user_element_attribute2 IN VARCHAR2:= NULL, p_user_element_attribute3 IN VARCHAR2:= NULL, p_user_element_attribute4 IN VARCHAR2:= NULL, p_user_element_attribute5 IN VARCHAR2:= NULL, p_user_element_attribute6 IN VARCHAR2:= NULL, p_user_element_attribute7 IN VARCHAR2:= NULL
                                 , p_user_element_attribute8 IN VARCHAR2:= NULL, p_user_element_attribute9 IN VARCHAR2:= NULL, p_user_element_attribute10 IN VARCHAR2:= NULL);

    FUNCTION get_ship_from_brand_fnc (pv_brand IN VARCHAR2, pn_org_id IN NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION check_ge_order (pv_ship_method_code IN VARCHAR2, pn_header_id IN NUMBER, pn_org_id IN NUMBER
                             , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    -- Start of Change for CCR0009857

    FUNCTION get_tax_rate (pn_trx_id IN NUMBER)
        RETURN NUMBER;
-- End of Change for CCR0009857

END XXD_SBX_O2C_INT_PKG;
/
