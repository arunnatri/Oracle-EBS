--
-- XXD_INV_UPC_UPLOAD_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:21:38 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_INV_UPC_UPLOAD_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_INV_UPC_UPLOAD_PKG
    * Design       : This package is used for uploading UPC Codes for Items
    * Notes        :
    * Modification :
    -- =======================================================================================
    -- Date         Version#   Name                    Comments
    -- =======================================================================================
    -- 10-Dec-2019  1.0        Viswanathan Pandian     Initial Version
    ******************************************************************************************/
    PROCEDURE upload_prc (p_trans_type IN VARCHAR2, p_item_number IN VARCHAR2, p_upc_code IN VARCHAR2);
END xxd_inv_upc_upload_pkg;
/
