--
-- XXD_SALES_ORDER_DEFAULT_PKG  (Package) 
--
--  Dependencies: 
--   XXD_BTOM_OEHEADER_TBLTYPE (Type)
--   XXD_BTOM_OELINE_TBLTYPE (Type)
--   XXD_BTOM_PICK_RELEASE_TBLTYPE (Type)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:25:32 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_SALES_ORDER_DEFAULT_PKG"
IS
    PROCEDURE default_main_sales_order_dls (p_customer_id IN NUMBER, p_org_id IN NUMBER, p_user_id IN NUMBER, p_resp_id IN NUMBER, p_resp_appl_id IN NUMBER, p_call_form IN VARCHAR2, p_brand IN VARCHAR2, p_order_type IN VARCHAR2, p_order_date IN DATE, p_requested_date IN DATE, p_header_rec OUT NOCOPY xxd_btom_oeheader_tbltype, x_error_flag OUT VARCHAR2
                                            , x_error_message OUT VARCHAR2);

    PROCEDURE default_customer_details (
        p_customer_id     IN            NUMBER,
        p_org_id          IN            NUMBER,
        p_header_rec      IN OUT NOCOPY xxd_btom_oeheader_tbltype,
        x_error_flag         OUT        VARCHAR2,
        x_error_message      OUT        VARCHAR2);

    PROCEDURE default_header_details (
        p_customer_id      IN            NUMBER,
        p_org_id           IN            NUMBER,
        p_user_id          IN            NUMBER,
        p_resp_id          IN            NUMBER,
        p_resp_appl_id     IN            NUMBER,
        p_site_to_id       IN            NUMBER,
        p_bill_to_id       IN            NUMBER,
        p_order_type       IN            VARCHAR2,
        p_price_type       IN            VARCHAR2,
        p_header_rec       IN OUT NOCOPY xxd_btom_oeheader_tbltype,
        p_flag             IN            VARCHAR2,
        p_order_date       IN            DATE,
        p_requested_date   IN            DATE,
        p_brand            IN            VARCHAR2,
        p_call_from        IN            VARCHAR2,
        x_error_flag          OUT        VARCHAR2,
        x_error_message       OUT        VARCHAR2);

    PROCEDURE default_line_details (p_customer_id IN NUMBER, p_org_id IN NUMBER, p_user_id IN NUMBER, p_resp_id IN NUMBER, p_resp_appl_id IN NUMBER, p_ship_to_id IN NUMBER, p_bill_to_id IN NUMBER, p_brand IN VARCHAR2, p_division IN VARCHAR2, p_department IN VARCHAR2, p_class IN VARCHAR2, p_sub_class IN VARCHAR2, p_flag IN VARCHAR2, -- Pass Y, IF the Bill_to OR Ship_to is changed at line level
                                                                                                                                                                                                                                                                                                                                              p_price_list IN VARCHAR2, p_order_type IN VARCHAR2, p_call_from IN VARCHAR2, p_ship_or_bill_to IN VARCHAR2, p_style IN VARCHAR2 DEFAULT NULL, --CCR0009598
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            p_color IN VARCHAR2 DEFAULT NULL, --CCR0009598
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              p_header_rec OUT NOCOPY xxd_btom_oeline_tbltype, x_error_flag OUT VARCHAR2
                                    , x_error_message OUT VARCHAR2);

    PROCEDURE default_price_list_details (p_header_rec IN OUT NOCOPY xxd_btom_oeheader_tbltype, x_error_flag OUT VARCHAR2, x_error_message OUT VARCHAR2);

    PROCEDURE doe_profile_value (p_org_id IN NUMBER, p_user_id IN NUMBER, p_resp_id IN NUMBER, p_resp_appl_id IN NUMBER, p_profile_name IN VARCHAR2, x_error_flag OUT VARCHAR2
                                 , x_error_message OUT VARCHAR2);

    PROCEDURE assign_default_values (
        p_org_id                       IN     NUMBER,
        p_user_id                      IN     NUMBER,
        p_resp_id                      IN     NUMBER,
        p_resp_appl_id                 IN     NUMBER,
        x_currency_code                   OUT VARCHAR2,
        x_transaction_type_id             OUT NUMBER,
        x_transaction_type                OUT VARCHAR2,
        x_return_transaction_type_id      OUT NUMBER,
        x_return_transaction_type         OUT VARCHAR2,
        x_error_flag                      OUT VARCHAR2,
        x_error_message                   OUT VARCHAR2);

    PROCEDURE get_price_hire_default (px_header_rec IN OUT NOCOPY xxd_btom_oeheader_tbltype, x_error_flag OUT VARCHAR2, x_error_message OUT VARCHAR2);

    PROCEDURE get_order_hire_default (px_header_rec IN OUT NOCOPY xxd_btom_oeheader_tbltype, x_error_flag OUT VARCHAR2, x_error_message OUT VARCHAR2);

    PROCEDURE check_cust_po_number (p_header_id IN NUMBER, p_cust_acct_id IN NUMBER, p_org_id IN NUMBER
                                    , p_cust_po_no IN VARCHAR2, x_error_flag OUT VARCHAR2, x_error_message OUT VARCHAR2);

    PROCEDURE check_enable_apply_price_adj (p_user_id NUMBER, p_resp_id NUMBER, p_resp_appl_id NUMBER, p_orgid NUMBER, p_order_type_id NUMBER, p_call_from VARCHAR2
                                            , p_status_flag OUT VARCHAR, p_error_flag OUT VARCHAR2, p_error_message OUT VARCHAR2);

    FUNCTION get_line_status_value (p_line_id            NUMBER,
                                    p_flow_status_code   VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_line_reserved_qty_value (p_header_id   NUMBER,
                                          p_line_id     NUMBER)
        RETURN NUMBER;

    PROCEDURE default_warehouse (p_ou_id IN NUMBER, p_brand IN VARCHAR2, p_division IN VARCHAR2, p_department IN VARCHAR2, --Start Changes V2.0
                                                                                                                           pd_request_date IN DATE, pn_order_type_id IN NUMBER, --End Changes V2.0
                                                                                                                                                                                p_style_desc IN VARCHAR2, -- ver 2.5
                                                                                                                                                                                                          x_warehouse OUT VARCHAR2, x_org_id OUT NUMBER
                                 , x_error_msg OUT VARCHAR2);

    FUNCTION get_line_reserved_quantity (p_header_id   NUMBER,
                                         p_line_id     NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_blanket_unschedule_line (p_header_id   NUMBER,
                                          p_org_id      NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_wsh_shipping_oe_header_id (p_delivery_detail_id NUMBER)
        RETURN NUMBER;

    FUNCTION get_wsh_shipping_oe_line_id (p_delivery_detail_id NUMBER)
        RETURN NUMBER;

    PROCEDURE get_pick_rlease_status (P_header_id NUMBER, p_pick_release OUT XXD_BTOM_PICK_RELEASE_TBLTYPE, x_err_msg OUT VARCHAR2);
END xxd_sales_order_default_pkg;
/
