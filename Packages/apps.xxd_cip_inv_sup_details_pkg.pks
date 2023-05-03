--
-- XXD_CIP_INV_SUP_DETAILS_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:19:33 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXD_CIP_INV_SUP_DETAILS_PKG
AS
    /*******************************************************************************
 * Program Name : XXD_CIP_INV_SUP_DETAILS_PKG
 * Language  : PL/SQL
 * Description  : This package will be used for the view XXD_EXP_NEW_TRANSFER_V
 * History :
 *
 *   WHO    Version  when   Desc
 * --------------------------------------------------------------------------
 * BT Technology Team   1.0    21/Jan/2015  Interface Prog
 * --------------------------------------------------------------------------- */

    FUNCTION get_invoice_num (P_transaction_source   VARCHAR2,
                              p_invoice_id           NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_invoice_date (P_transaction_source   VARCHAR2,
                               p_invoice_id           NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_vendor_name (p_vendor_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_vendor_number (p_vendor_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_po_number (p_exp_item_id NUMBER, p_trx_source VARCHAR2)
        RETURN VARCHAR2;
END xxd_cip_inv_sup_details_pkg;
/


GRANT EXECUTE ON APPS.XXD_CIP_INV_SUP_DETAILS_PKG TO XXDO
/
