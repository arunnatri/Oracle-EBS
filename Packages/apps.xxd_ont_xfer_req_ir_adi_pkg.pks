--
-- XXD_ONT_XFER_REQ_IR_ADI_PKG  (Package) 
--
--  Dependencies: 
--   MTL_PARAMETERS (Synonym)
--   OE_ORDER_LINES_ALL (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:24:03 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_XFER_REQ_IR_ADI_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_XFER_REQ_IR_ADI_PKG
    * Design       : This package is Transfer Order Requisition and IR Creation WebADI
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 16-Mar-2022  1.0        Jayarajan AK            Initial Version
    ******************************************************************************************/

    PROCEDURE validate_prc (p_src_org_code IN mtl_parameters.organization_code%TYPE, p_dest_org_code IN mtl_parameters.organization_code%TYPE, p_sku IN oe_order_lines_all.ordered_item%TYPE
                            , p_qty IN oe_order_lines_all.ordered_quantity%TYPE, p_group_num IN NUMBER);

    PROCEDURE main_proc (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2);
END xxd_ont_xfer_req_ir_adi_pkg;
/
