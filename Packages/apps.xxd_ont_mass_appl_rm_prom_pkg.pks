--
-- XXD_ONT_MASS_APPL_RM_PROM_PKG  (Package) 
--
--  Dependencies: 
--   OE_ORDER_HEADERS_ALL (Synonym)
--   XXD_ONT_PROMOTIONS_T (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:23:27 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_MASS_APPL_RM_PROM_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_MASS_APPL_RM_PROM_PKG
    * Design       : This package is used for mass applying/removing Promotions
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 24-Jul-2017  1.0       Arun N Murthy     Initial Version
    ******************************************************************************************/


    FUNCTION check_order_line_status (
        p_header_id IN oe_order_headers_all.header_id%TYPE)
        RETURN NUMBER;


    PROCEDURE prc_apply_remove_promotion (p_order_number IN oe_order_headers_all.order_number%TYPE, p_promotion_code IN xxd_ont_promotions_t.promotion_code%TYPE DEFAULT NULL, p_is_apply IN VARCHAR2);
END XXD_ONT_MASS_APPL_RM_PROM_PKG;
/
