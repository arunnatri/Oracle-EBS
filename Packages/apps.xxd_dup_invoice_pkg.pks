--
-- XXD_DUP_INVOICE_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:19:57 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.xxd_dup_invoice_pkg
AS
    /****************************************************************************************
    * Package      : XXD_DUP_INVOICE_PKG
    * Author       : BT Technology Team
    * Created      : 09-SEP-2014
    * Program Name : Deckers Populate 1206 Closed Invoices in Custom Table
    * Description  : Package used to populate closed AP invoices into a custom table
    *
    * Modification :
    *--------------------------------------------------------------------------------------
    * Date          Developer           Version    Description
    *--------------------------------------------------------------------------------------
    * 09-SEP-2014   BT Technology Team  1.00       Created package to pull closed invoices
    ****************************************************************************************/
    PROCEDURE populate_paid_invoices (x_retcode OUT NUMBER, x_errbuff OUT VARCHAR2, p_date_from IN DATE);
END xxd_dup_invoice_pkg;
/
