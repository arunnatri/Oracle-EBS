--
-- XXD_MTL_CI_XREFS_UPLOAD_X_PK  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   HZ_CUST_ACCOUNTS (Synonym)
--   MTL_CUSTOMER_ITEMS (Synonym)
--   MTL_SYSTEM_ITEMS_B (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:21:58 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_MTL_CI_XREFS_UPLOAD_X_PK"
AS
    /****************************************************************************************
    * Package      : XXD_MTL_CI_XREFS_UPLOAD_X_PK
    * Design       : This package is used for Customer Item and its cross reference upload
    * Notes        : Validate and insert
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 26-Jan-2017  1.0        Viswanathan Pandian     Web ADI for Customer Item Xref Upload
    --                                                 for CCR0005889
    ******************************************************************************************/
    --Global Variables
    gn_org_id     NUMBER := fnd_global.org_id;
    gn_user_id    NUMBER := fnd_global.user_id;
    gn_login_id   NUMBER := fnd_global.login_id;
    gd_sysdate    DATE := SYSDATE;

    --Public Subprograms
    /****************************************************************************************
    * Procedure    : CUST_ITEM_XREF_UPLOAD_PRC
    * Design       : This procedure inserts records into MTL CI interface tables
    * Notes        : Validate and insert
    * Return Values: None
    * Modification :
    * ===============================================================================
    * Date         Version#   Name                    Comments
    * ===============================================================================
    * 26-Jan-2017  1.0        Viswanathan Pandian     Initial Version
    ****************************************************************************************/
    PROCEDURE cust_item_xref_upload_prc (
        p_customer_number         IN hz_cust_accounts.account_number%TYPE,
        p_customer_item_number    IN mtl_customer_items.customer_item_number%TYPE,
        p_customer_item_desc      IN mtl_customer_items.customer_item_desc%TYPE,
        p_inventory_item_number   IN mtl_system_items_b.segment1%TYPE);

    /****************************************************************************************
    * Procedure    : RUN_IMPORT_CUST_ITEM_PRC
    * Design       : This procedure submits "Import Customer Items - Deckers" request set
    * Notes        : This is called from WebADI
    * Return Values: None
    * Modification :
    * ===============================================================================
    * Date         Version#   Name                    Comments
    * ===============================================================================
    * 26-Jan-2017  1.0        Viswanathan Pandian     Initial Version
    ****************************************************************************************/
    PROCEDURE run_import_cust_item_prc;

    /****************************************************************************************
    * Procedure    : DELETE_INTERFACE_RECORDS_FNC
    * Design       : This function will delete interface records of 10 or more days old
    * Notes        : This is called from "Customer Item Import Exception Report - Deckers"
    * Return Values: None
    * Modification :
    * ===============================================================================
    * Date         Version#   Name                    Comments
    * ===============================================================================
    * 26-Jan-2017  1.0        Viswanathan Pandian     Initial Version
    ****************************************************************************************/
    FUNCTION delete_interface_records_fnc
        RETURN BOOLEAN;
END xxd_mtl_ci_xrefs_upload_x_pk;
/
