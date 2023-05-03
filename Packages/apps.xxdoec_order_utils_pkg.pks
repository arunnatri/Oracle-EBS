--
-- XXDOEC_ORDER_UTILS_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:13:03 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOEC_ORDER_UTILS_PKG"
AS
    -- ==============================================================
    -- Author : VIJAY.REDDY
    -- Created : 11/9/2010 9:12:29 AM
    -- Purpose : Validate and return Oracle ID's for DW Order values
    -- Modified : 12/07/2017 :: Vijay Reddy
    -- Modification: JP DW COD related changes
    -- ==============================================================
    -- Public Variables
    g_payment_term_name     CONSTANT VARCHAR2 (120) := 'PREPAY';
    g_pct_dis_list_name     CONSTANT VARCHAR2 (120)
                                         := 'DOEC MULTI DISCOUNT PCT' ;
    g_amt_dis_list_name     CONSTANT VARCHAR2 (120)
                                         := 'DOEC MULTI DISCOUNT AMT' ;
    g_freight_charge_name   CONSTANT VARCHAR2 (120) := 'DOEC SHIPPING CHARGE';
    g_surcharge_name        CONSTANT VARCHAR2 (120)
                                         := 'DOEC GIFT STORE CARD CHARGE' ;

    TYPE discount_detail_record IS RECORD
    (
        p_discount_name          VARCHAR2 (100),
        p_list_header_id         NUMBER,
        p_list_line_id           NUMBER,
        p_list_line_type_code    VARCHAR2 (30),
        p_arithmetic_operator    VARCHAR2 (30)
    );

    TYPE t_order_list IS TABLE OF VARCHAR2 (100)
        INDEX BY BINARY_INTEGER;

    TYPE t_order_lines_count IS REF CURSOR;

    TYPE t_discount_detail_cursor IS REF CURSOR
        RETURN discount_detail_record;

    -- Public function and procedure declarations
    PROCEDURE validate_order_values (p_website_id IN VARCHAR2, p_currency_code IN VARCHAR2, p_salesrep IN VARCHAR2, p_org_id IN NUMBER, p_ordered_date IN DATE, p_back_ordered_flag IN VARCHAR2, -- Y/N
                                                                                                                                                                                                 p_pct_amt_discount IN VARCHAR2, -- P - percent, A - amount
                                                                                                                                                                                                                                 p_pre_paid_flag IN VARCHAR2, -- Y/N
                                                                                                                                                                                                                                                              x_order_source_id OUT NUMBER, x_salesrep_id OUT NUMBER, x_cancel_date OUT VARCHAR2, x_order_class OUT VARCHAR2, x_order_category OUT VARCHAR2, x_erp_org_id OUT NUMBER, x_inv_org_id OUT NUMBER, x_om_order_type_id OUT NUMBER, x_ar_gl_id_rev OUT NUMBER, x_dflt_price_list_id OUT NUMBER, x_freight_terms_code OUT VARCHAR2, x_fob_point_code OUT VARCHAR2, x_payment_term_id OUT NUMBER, x_kco_header_id OUT NUMBER, x_transaction_user_id OUT NUMBER, x_erp_login_resp_id OUT NUMBER, x_erp_login_app_id OUT NUMBER, x_dis_list_header_id OUT NUMBER, x_dis_list_line_id OUT NUMBER, x_dis_hdr_line_id OUT NUMBER, x_dis_list_line_type_code OUT VARCHAR2, x_chrg_list_header_id OUT NUMBER, x_chrg_list_line_id OUT NUMBER, x_chrg_dis_line_id OUT NUMBER, x_giftwrap_list_line_id OUT NUMBER, x_cod_list_line_id OUT NUMBER, -- JP DW COD related changes
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 x_chrg_list_line_type_code OUT VARCHAR2, x_sur_list_header_id OUT NUMBER
                                     , x_sur_list_line_id OUT NUMBER, x_sur_list_line_type_code OUT VARCHAR2, x_bling_list_line_id OUT NUMBER);

    PROCEDURE validate_upc (p_website_id IN VARCHAR2, p_item_upc IN VARCHAR2, p_inv_org_id IN NUMBER, p_ordered_date IN DATE, p_pre_back_ordered_flag IN VARCHAR2, -- Y/N
                                                                                                                                                                   p_pre_paid_flag IN VARCHAR2, -- Y/N
                                                                                                                                                                                                p_sfs_flag IN VARCHAR2 DEFAULT 'N', -- Y/N
                                                                                                                                                                                                                                    x_inventory_item_id OUT NUMBER, x_style OUT VARCHAR2, x_color OUT VARCHAR2, x_size OUT VARCHAR2, x_primary_uom_code OUT VARCHAR2, x_cancel_date OUT VARCHAR2, x_line_type_id OUT NUMBER, x_inv_org_id OUT NUMBER
                            , x_shipping_method_code OUT VARCHAR2);

    PROCEDURE validate_sku (p_website_id IN VARCHAR2, p_sku IN VARCHAR2, p_inv_org_id IN NUMBER, p_ordered_date IN DATE, p_pre_back_ordered_flag IN VARCHAR2, -- Y/N
                                                                                                                                                              p_pre_paid_flag IN VARCHAR2, -- Y/N
                                                                                                                                                                                           p_sfs_flag IN VARCHAR2 DEFAULT 'N', -- Y/N
                                                                                                                                                                                                                               x_inventory_item_id OUT NUMBER, x_style OUT VARCHAR2, x_color OUT VARCHAR2, x_size OUT VARCHAR2, x_primary_uom_code OUT VARCHAR2, x_cancel_date OUT VARCHAR2, x_line_type_id OUT NUMBER, x_inv_org_id OUT NUMBER
                            , x_shipping_method_code OUT VARCHAR2);

    PROCEDURE get_discounts_details (
        x_discounts_tbl OUT t_discount_detail_cursor);

    PROCEDURE get_ca_cust_number (p_website_id IN VARCHAR2, p_email_address IN VARCHAR2, x_customer_number OUT VARCHAR2);

    PROCEDURE get_order_ship_to_address (p_cust_po_number IN VARCHAR2, x_customer_number OUT VARCHAR2, x_address1 OUT VARCHAR2, x_address2 OUT VARCHAR2, x_address3 OUT VARCHAR2, x_city OUT VARCHAR2, x_state OUT VARCHAR2, x_county OUT VARCHAR2, x_postal_code OUT VARCHAR2
                                         , x_country OUT VARCHAR2, x_rtn_status OUT VARCHAR2, x_rtn_msg OUT VARCHAR2);

    PROCEDURE update_order_ship_to_address (
        p_cust_po_number   IN     VARCHAR2,
        p_address1         IN     VARCHAR2,
        p_address2         IN     VARCHAR2,
        p_address3         IN     VARCHAR2,
        p_city             IN     VARCHAR2,
        p_state            IN     VARCHAR2,
        p_county           IN     VARCHAR2,
        p_postal_code      IN     VARCHAR2,
        p_country          IN     VARCHAR2,
        x_rtn_status          OUT VARCHAR2,
        x_rtn_msg             OUT VARCHAR2);

    PROCEDURE create_sfs_line (p_order_line_id IN NUMBER, x_order_line_id OUT NUMBER, x_rtn_status OUT VARCHAR2
                               , x_error_msg OUT VARCHAR2);

    PROCEDURE cancel_unscheduled_lines (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, p_wait_days IN NUMBER DEFAULT 10
                                        , p_no_of_lines IN NUMBER DEFAULT 1000, p_inv_item IN VARCHAR2, p_cust_po_number IN VARCHAR2);

    PROCEDURE open_order_lines_count (
        p_web_order_numbers   IN     t_order_list,
        o_order_lines_count      OUT t_order_lines_count);

    FUNCTION get_orig_order (p_order_header_id IN NUMBER, p_rtn_status OUT VARCHAR2, p_rtn_message OUT VARCHAR2)
        RETURN VARCHAR2;

    PROCEDURE get_orig_order_type (p_order_cust_po_num IN VARCHAR2, x_original_order_type OUT VARCHAR2, x_rtn_status OUT VARCHAR2
                                   , x_rtn_message OUT VARCHAR2);

    PROCEDURE get_db_apps_values (x_user_id   OUT NUMBER,
                                  x_org_id    OUT NUMBER,
                                  x_resp_id   OUT NUMBER);

    PROCEDURE check_cp_shipped (p_application_id IN NUMBER, p_entity_short_name IN VARCHAR2, p_validation_entity_short_name IN VARCHAR2, p_validation_tmplt_short_name IN VARCHAR2, p_record_set_tmplt_short_name IN VARCHAR2, p_scope IN VARCHAR2
                                , p_result OUT NOCOPY NUMBER);

    PROCEDURE get_sku_from_upc (p_upc       IN     VARCHAR2,
                                p_inv_org   IN     NUMBER,
                                x_sku          OUT VARCHAR2);

    PROCEDURE get_header_id (p_cust_po_number       VARCHAR2,
                             x_header_id        OUT NUMBER);

    PROCEDURE get_line_id (p_header_id         NUMBER,
                           p_line_number       NUMBER,
                           x_line_id       OUT NUMBER);

    PROCEDURE get_line_number (p_line_id NUMBER, x_line_number OUT NUMBER);
END xxdoec_order_utils_pkg;
/
