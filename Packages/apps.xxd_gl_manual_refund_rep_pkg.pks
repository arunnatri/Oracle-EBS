--
-- XXD_GL_MANUAL_REFUND_REP_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:52 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_GL_MANUAL_REFUND_REP_PKG"
AS
    /******************************************************************************
     NAME: XXDO.XXDOAR014_REP_PKG
     REP NAME:Commerce Receipts Report Details - Deckers

     REVISIONS:
     Ver       Date       Author          Description
     --------- ---------- --------------- ------------------------------------
     1.0       01/14/19   Madhav Dhurjaty Initial Version - CCR0007732
    ******************************************************************************/
    P_PATH                VARCHAR2 (360);
    P_FILE_PATH           VARCHAR2 (360);
    P_FILE_NAME           VARCHAR2 (360);
    P_PAYMENT_DATE_FROM   VARCHAR2 (360);
    P_PAYMENT_DATE_TO     VARCHAR2 (360);
    P_SEND_TO_BLACKLINE   VARCHAR2 (1);

    FUNCTION directory_path
        RETURN VARCHAR2;

    FUNCTION file_name
        RETURN VARCHAR2;

    FUNCTION before_report
        RETURN BOOLEAN;

    FUNCTION after_report
        RETURN BOOLEAN;
END XXD_GL_MANUAL_REFUND_REP_PKG;
/
