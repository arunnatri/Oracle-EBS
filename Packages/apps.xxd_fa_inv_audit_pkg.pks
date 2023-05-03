--
-- XXD_FA_INV_AUDIT_PKG  (Package) 
--
--  Dependencies: 
--   FA_ADDITIONS (Synonym)
--   FA_BOOKS (Synonym)
--   FND_ATTACHED_DOCUMENTS (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:09 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_FA_INV_AUDIT_PKG"
AS
    /************************************************************************************************
       * Package         : XXD_FA_INV_AUDIT_PKG
       * Description     : This package is used to get Invoice Documents by Entity
       * Notes           :
       * Modification    :
       *-----------------------------------------------------------------------------------------------
       * Date         Version#      Name                       Description
       *-----------------------------------------------------------------------------------------------
       * 04-APR-2018  1.0           Aravind Kannuri           Initial Version for CCR0007106
       ************************************************************************************************/

    p_entity_name          fnd_attached_documents.entity_name%TYPE;
    p_asset_book_name      fa_books.book_type_code%TYPE;
    p_period_from          VARCHAR2 (50);
    p_period_to            VARCHAR2 (50);
    p_asset_account_from   VARCHAR2 (50);
    p_asset_account_to     VARCHAR2 (50);
    p_cost_center          VARCHAR2 (50);
    p_asset_location       VARCHAR2 (150);
    p_asset_number         fa_additions.asset_number%TYPE;
    p_user_file_path       VARCHAR2 (1000);

    --To fetch Invoices to upload
    FUNCTION upload_inv_docs
        RETURN BOOLEAN;

    --To fetch Invoice documents file path
    FUNCTION get_doc_file_path (p_pk1_value_id IN NUMBER, p_entity_name IN fnd_attached_documents.entity_name%TYPE, p_user_file_path IN VARCHAR2)
        RETURN VARCHAR2;

    --To get asset_invoice_id
    FUNCTION get_asset_inv_id (p_ap_invoice_id IN NUMBER, p_asset_inv_id IN NUMBER, p_asset_inv_num IN VARCHAR2
                               , p_po_vendor_id IN NUMBER)
        RETURN NUMBER;

    --To get Asset Capitalized Amount
    FUNCTION get_asset_cap_amt (p_asset_type IN VARCHAR2, p_asset_id IN NUMBER, p_asset_inv_num IN VARCHAR2)
        RETURN NUMBER;

    --To get Other Asset Amount for Invoice
    FUNCTION get_oth_asset_amt (p_asset_type IN VARCHAR2, p_asset_id IN NUMBER, p_asset_inv_num IN VARCHAR2)
        RETURN NUMBER;
END xxd_fa_inv_audit_pkg;
/
