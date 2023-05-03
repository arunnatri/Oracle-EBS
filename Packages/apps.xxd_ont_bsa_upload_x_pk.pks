--
-- XXD_ONT_BSA_UPLOAD_X_PK  (Package) 
--
--  Dependencies: 
--   MTL_CUSTOMER_ITEMS (Synonym)
--   MTL_SYSTEM_ITEMS_B (Synonym)
--   OE_BLANKET_HEADERS_ALL (Synonym)
--   OE_BLANKET_LINES_EXT (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:22:39 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_BSA_UPLOAD_X_PK"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_BSA_UPLOAD_X_PK
    * Design       : This package is used for Blanket Sales Agreement Upload WebADI
    * Notes        : Validate and insert
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 09-Jan-2017  1.0        Viswanathan Pandian     WebADI for Blanket Sales Agreement Upload
    --                                                 for CCR0005549
    ******************************************************************************************/
    --Public Subprograms
    /****************************************************************************************
    * Procedure    : BSA_VALIDATE_PRC
    * Design       : This procedure validates and calls public API to create Blanket Sales Agreement
    * Notes        : This is called from WebADI
    * Return Values: None
    * Modification :
    * ===============================================================================
    * Date         Version#   Name                    Comments
    * ===============================================================================
    * 09-Jan-2017  1.0        Viswanathan Pandian     Initial Version
    ****************************************************************************************/
    PROCEDURE bsa_upload_prc (p_order_number IN oe_blanket_headers_all.order_number%TYPE, p_inventory_item_number IN mtl_system_items_b.segment1%TYPE, p_customer_item_number IN mtl_customer_items.customer_item_number%TYPE, p_blanket_min_quantity IN oe_blanket_lines_ext.blanket_min_quantity%TYPE, p_blanket_max_quantity IN oe_blanket_lines_ext.blanket_max_quantity%TYPE, p_override_rel_controls_flag IN oe_blanket_lines_ext.override_release_controls_flag%TYPE
                              , p_blanket_min_release_quantity IN oe_blanket_lines_ext.min_release_quantity%TYPE, p_blanket_max_release_quantity IN oe_blanket_lines_ext.max_release_quantity%TYPE);
END xxd_ont_bsa_upload_x_pk;
/
