--
-- XXD_ONT_PROMOTIONS_X_PK  (Package) 
--
--  Dependencies: 
--   HR_OPERATING_UNITS (View)
--   OE_ORDER_HEADERS_ALL (Synonym)
--   OE_PRICE_ADJUSTMENTS (Synonym)
--   QP_LIST_HEADERS (Synonym)
--   QP_LIST_LINES (Synonym)
--   XXD_ONT_PROMOTIONS_T (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:23:43 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_PROMOTIONS_X_PK"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_PROMOTIONS_X_PK
    * Design       : This package is used for applying/removing Promotions and Discounts
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 14-Feb-2017  1.0        Viswanathan Pandian     Initial Version
    ******************************************************************************************/
    gc_sub_prog_name        VARCHAR2 (100);
    gc_debug_enable         VARCHAR2 (1);
    gn_org_id               NUMBER;
    gn_user_id              NUMBER;
    gn_login_id             NUMBER;
    gn_request_id           NUMBER;
    gn_list_header_id       qp_list_headers.list_header_id%TYPE;
    gn_order_list_line_id   qp_list_lines.list_line_id%TYPE;
    gn_line_list_line_id    qp_list_lines.list_line_id%TYPE;
    gc_change_reason_code   oe_price_adjustments.change_reason_code%TYPE;
    gc_change_reason_text   oe_price_adjustments.change_reason_text%TYPE;
    gc_override_flag        VARCHAR2 (1);
    gc_flag                 VARCHAR2 (1) := 'N';

    FUNCTION check_order_lock (
        p_header_id IN oe_order_headers_all.header_id%TYPE)
        RETURN VARCHAR2;

    FUNCTION get_reservation (
        p_order_number IN oe_order_headers_all.order_number%TYPE)
        RETURN VARCHAR2;

    PROCEDURE apply_promotion (p_header_id IN oe_order_headers_all.header_id%TYPE, p_promotion_code IN xxd_ont_promotions_t.promotion_code%TYPE);

    PROCEDURE remove_promotion (p_header_id IN oe_order_headers_all.header_id%TYPE, p_promotion_code IN xxd_ont_promotions_t.promotion_code%TYPE);

    PROCEDURE child_prc (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_org_id IN hr_operating_units.organization_id%TYPE, p_brand IN xxd_ont_promotions_t.brand%TYPE, p_cust_account_id IN oe_order_headers_all.sold_to_org_id%TYPE, p_cust_po_number IN oe_order_headers_all.cust_po_number%TYPE, p_order_number_from IN oe_order_headers_all.order_number%TYPE, p_order_number_to IN oe_order_headers_all.order_number%TYPE, p_ordered_date_from IN VARCHAR2, p_ordered_date_to IN VARCHAR2, p_request_date_from IN VARCHAR2, p_request_date_to IN VARCHAR2, p_order_source_id IN oe_order_headers_all.order_source_id%TYPE, p_order_type_id IN oe_order_headers_all.order_type_id%TYPE, p_exclude_picked_orders IN VARCHAR2, p_reapply_promotion IN VARCHAR2, p_promotion_code IN xxd_ont_promotions_t.promotion_code%TYPE, p_override_promotion IN VARCHAR2, p_override_promotion_code IN xxd_ont_promotions_t.promotion_code%TYPE, p_threads IN NUMBER, p_debug IN VARCHAR2
                         , p_run_id IN NUMBER);

    PROCEDURE master_prc (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_org_id IN hr_operating_units.organization_id%TYPE, p_brand IN xxd_ont_promotions_t.brand%TYPE, p_cust_account_id IN oe_order_headers_all.sold_to_org_id%TYPE, p_cust_po_number IN oe_order_headers_all.cust_po_number%TYPE, p_order_number_from IN oe_order_headers_all.order_number%TYPE, p_order_number_to IN oe_order_headers_all.order_number%TYPE, p_dummy_order_number_to IN oe_order_headers_all.order_number%TYPE, p_ordered_date_from IN VARCHAR2, p_ordered_date_to IN VARCHAR2, p_request_date_from IN VARCHAR2, p_request_date_to IN VARCHAR2, p_order_source_id IN oe_order_headers_all.order_source_id%TYPE, p_order_type_id IN oe_order_headers_all.order_type_id%TYPE, p_exclude_picked_orders IN VARCHAR2, p_reapply_promotion IN VARCHAR2, p_promotion_code IN xxd_ont_promotions_t.promotion_code%TYPE, p_override_promotion IN VARCHAR2, p_dummy_override_promotion IN VARCHAR2, p_override_promotion_code IN xxd_ont_promotions_t.promotion_code%TYPE
                          , p_threads IN NUMBER, p_debug IN VARCHAR2);

    FUNCTION check_promotion_eligibility (
        p_header_id IN oe_order_headers_all.header_id%TYPE)
        RETURN NUMBER;

    PROCEDURE inactivate_promotion (x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2, p_org_id IN xxd_ont_promotions_t.org_id%TYPE, p_brand IN xxd_ont_promotions_t.brand%TYPE, p_promotion_code IN xxd_ont_promotions_t.promotion_code%TYPE, p_inactivation_reason IN xxd_ont_promotions_t.inactivation_reason%TYPE, p_ordered_date_from IN VARCHAR2, p_ordered_date_to IN VARCHAR2, p_request_date_from IN VARCHAR2
                                    , p_request_date_to IN VARCHAR2, p_country_code IN xxd_ont_promotions_t.country_code%TYPE, p_state IN xxd_ont_promotions_t.state%TYPE);

    PROCEDURE apply_remove_promotion (p_header_id IN oe_order_headers_all.header_id%TYPE, p_promotion_code IN xxd_ont_promotions_t.promotion_code%TYPE, p_user_id IN NUMBER, p_resp_id IN NUMBER, p_resp_app_id IN NUMBER, p_org_id IN NUMBER, p_is_apply IN NUMBER, x_status_flag OUT VARCHAR2, x_error_message OUT VARCHAR2
                                      , x_clear_flag OUT VARCHAR2);

    PROCEDURE schedule_promotion (p_header_id IN oe_order_headers_all.header_id%TYPE, p_promotion_code IN xxd_ont_promotions_t.promotion_code%TYPE, p_promotion_status IN VARCHAR2, p_user_id IN NUMBER, p_resp_id IN NUMBER, p_resp_app_id IN NUMBER
                                  , p_org_id IN NUMBER, x_status_flag OUT VARCHAR2, x_error_message OUT VARCHAR2);

    PROCEDURE check_order_lock_doe (p_header_id IN oe_order_headers_all.header_id%TYPE, p_order_locked OUT VARCHAR2, x_status_flag OUT VARCHAR2
                                    , x_error_message OUT VARCHAR2);
END xxd_ont_promotions_x_pk;
/
