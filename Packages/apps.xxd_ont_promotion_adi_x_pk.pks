--
-- XXD_ONT_PROMOTION_ADI_X_PK  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   XXD_ONT_PROMOTIONS_T (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:23:44 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_PROMOTION_ADI_X_PK"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_PROMOTIONS_X_PK
    * Design       : This package is used for creating Promotions and Discounts
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 14-Feb-2017  1.0        Viswanathan Pandian     Initial Version
    ******************************************************************************************/
    --Global Variables
    gn_org_id     NUMBER := fnd_global.org_id;
    gn_user_id    NUMBER := fnd_global.user_id;
    gn_login_id   NUMBER := fnd_global.login_id;
    gd_sysdate    DATE := SYSDATE;

    PROCEDURE promotion_upload_prc (p_promotion_code IN xxd_ont_promotions_t.promotion_code%TYPE, p_promotion_name IN xxd_ont_promotions_t.promotion_name%TYPE, p_operating_unit IN xxd_ont_promotions_t.operating_unit%TYPE, p_brand IN xxd_ont_promotions_t.brand%TYPE, p_currency IN xxd_ont_promotions_t.currency%TYPE, p_customer_number IN xxd_ont_promotions_t.customer_number%TYPE, p_distribution_channel IN xxd_ont_promotions_t.distribution_channel%TYPE, p_ship_method IN xxd_ont_promotions_t.ship_method%TYPE, p_freight_term IN xxd_ont_promotions_t.freight_term%TYPE, p_payment_term IN xxd_ont_promotions_t.payment_term%TYPE, p_header_discount IN xxd_ont_promotions_t.header_discount%TYPE, p_line_discount IN xxd_ont_promotions_t.line_discount%TYPE, p_ordered_date_from IN xxd_ont_promotions_t.ordered_date_from%TYPE, p_ordered_date_to IN xxd_ont_promotions_t.ordered_date_to%TYPE, p_request_date_from IN xxd_ont_promotions_t.request_date_from%TYPE, p_request_date_to IN xxd_ont_promotions_t.request_date_to%TYPE, p_department IN xxd_ont_promotions_t.department%TYPE, p_division IN xxd_ont_promotions_t.division%TYPE, p_class IN xxd_ont_promotions_t.class%TYPE, p_sub_class IN xxd_ont_promotions_t.sub_class%TYPE, p_style_number IN xxd_ont_promotions_t.style_number%TYPE, p_color_code IN xxd_ont_promotions_t.color_code%TYPE, p_number_of_styles IN xxd_ont_promotions_t.number_of_styles%TYPE, p_number_of_colors IN xxd_ont_promotions_t.number_of_colors%TYPE
                                    , p_country_code IN xxd_ont_promotions_t.country_code%TYPE, p_state IN xxd_ont_promotions_t.state%TYPE);

    PROCEDURE promotion_validate_prc;
END xxd_ont_promotion_adi_x_pk;
/
