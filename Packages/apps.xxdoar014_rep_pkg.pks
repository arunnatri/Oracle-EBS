--
-- XXDOAR014_REP_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:11:58 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOAR014_REP_PKG"
AS
    /******************************************************************************
     NAME: XXDO.XXDOAR014_REP_PKG
     REP NAME:Commerce Receipts Report Details - Deckers

     REVISIONS:
     Ver Date       Author          Description
     --------- ----------           --------------- ------------------------------------
     1.0 04/14/2011 Shibu 1.        Created this package for AR XXDOAR014 Report
     1.1 02/15/2013 Venkatesh R     Modified the package body per DFCT0010410
     2.0 10/7/2013  Bill Simpson    Modified before_report to add "Refund-WO" trx type query to p_sql_stmt
     3.0 10/01/2015 Showkath        Retrofit to BT
     3.1 01/31/2017 Madhav D        Modified for ENHC0013063
     4.0 11/08/2017 Srilekha K      Modified for CCR0006749
     5.0 01/12/2017 Srinath S       Modified for CCR0005991
     5.1 12/02/2019 Kranthi Bollam  Modified for CCR0008335 - DXLAB Changes
    ******************************************************************************/

    --======================================================================+
    -- |
    -- Report Lexical Parameters |
    -- |
    --======================================================================+
    p_sql_stmt          VARCHAR2 (32000);

    --======================================================================+
    -- |
    -- Report Input Parameters |
    -- |
    --======================================================================+
    P_FORMAT            VARCHAR2 (40);
    P_ORG_ID            NUMBER;
    P_FROM_DATE         VARCHAR2 (21);
    P_TO_DATE           VARCHAR2 (21);
    P_CURRENCY_CODE     VARCHAR2 (21);
    P_RECEIPT_TYPE      VARCHAR2 (20);

    --Begin Modifcation for Change Number : CCR0006749
    P_CREAT_DATE_FROM   VARCHAR2 (21);
    P_CREAT_DATE_TO     VARCHAR2 (21);
    --End Modifcation for Change Number : CCR0006749

    P_GL_ACCT           VARCHAR2 (100);
    P_PATH              VARCHAR2 (360);    --Added by Madhav D for ENHC0013063
    P_FILE_PATH         VARCHAR2 (360);    --Added by Madhav D for ENHC0013063
    P_FILE_NAME         VARCHAR2 (360);    --Added by Madhav D for ENHC0013063

    FUNCTION before_report
        RETURN BOOLEAN;

    FUNCTION directory_path
        RETURN VARCHAR2;                   --Added by Madhav D for ENHC0013063

    FUNCTION file_name
        RETURN VARCHAR2;                   --Added by Madhav D for ENHC0013063

    FUNCTION after_report
        RETURN BOOLEAN;                    --Added by Madhav D for ENHC0013063

    FUNCTION get_delivery_id (pv_trx_number IN VARCHAR2)
        RETURN NUMBER;             -- Added for Japan DW Phase II (CCR0005991)

    FUNCTION get_email_id (pn_cust_acct_id IN NUMBER)
        RETURN VARCHAR2;           -- Added for Japan DW Phase II (CCR0005991)

    --Added below GET_RECEIPT_METHOD FUNCTION for change 5.1
    FUNCTION get_receipt_method (pn_cash_receipt_id   IN NUMBER,
                                 pn_customer_trx_id   IN NUMBER)
        RETURN VARCHAR2;               -- Added for DXLAB Changes (CCR0008335)
END XXDOAR014_REP_PKG;
/


--
-- XXDOAR014_REP_PKG  (Synonym) 
--
--  Dependencies: 
--   XXDOAR014_REP_PKG (Package)
--
CREATE OR REPLACE SYNONYM XXDO.XXDOAR014_REP_PKG FOR APPS.XXDOAR014_REP_PKG
/


GRANT EXECUTE ON APPS.XXDOAR014_REP_PKG TO APPS
/
