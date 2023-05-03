--
-- XXD_QP_AGR_ADI_UPLOAD_PK  (Package) 
--
--  Dependencies: 
--   MTL_SYSTEM_ITEMS_B (Synonym)
--   OE_AGREEMENTS_VL (View)
--   QP_LIST_LINES_V (View)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:25:19 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_QP_AGR_ADI_UPLOAD_PK"
AS
    /****************************************************************************************
    * Package      : XXD_QP_AGR_ADI_UPLOAD_PK
    * Design       : This package is used for Pricing Agreement WebADI upload
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 07-Jun-2017  1.0        Viswanathan Pandian     Initial Version
    ******************************************************************************************/
    PROCEDURE agr_upload_prc (p_agreement_name IN oe_agreements_vl.name%TYPE, p_inventory_item IN mtl_system_items_b.segment1%TYPE, p_uom_code IN qp_list_lines_v.product_uom_code%TYPE, p_list_price IN qp_list_lines_v.list_price%TYPE, p_start_date IN qp_list_lines_v.start_date_active%TYPE, p_end_date IN qp_list_lines_v.end_date_active%TYPE
                              , p_list_line_id IN qp_list_lines_v.list_line_id%TYPE, p_mdm_notes IN qp_list_lines_v.attribute3%TYPE);
END xxd_qp_agr_adi_upload_pk;
/
