--
-- XXD_AP_SEND_REM_ADV_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:18:41 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_AP_SEND_REM_ADV_PKG"
AS
    --  ####################################################################################################
    --  Package      : XXD_ONT_CALLOFF_PROCESS_PKG
    --  Design       : This package is used to send Remittance Advice to the vendors.
    --  Notes        :
    --  Modification :
    --  ======================================================================================
    --  Date            Version#   Name                    Comments
    --  ======================================================================================
    --  19-Mar-2020     1.0        Showkath Ali             Initial Version
    --  ####################################################################################################
    p_ou                        VARCHAR2 (100);
    p_pay_group                 VARCHAR2 (100);
    p_payment_method            VARCHAR2 (100);
    p_vendor_name               VARCHAR2 (100);
    p_vendor_num                VARCHAR2 (100);
    p_vendor_site               VARCHAR2 (100);
    p_vendor_type               VARCHAR2 (100);
    p_pay_date_from             VARCHAR2 (50);
    p_pay_date_to               VARCHAR2 (50);
    p_invoice_num               VARCHAR2 (100);
    p_payment_num               NUMBER;
    P_EMAIL_DISTRIBUTION_LIST   VARCHAR2 (100);
    P_EMAIL_REQUIRED            VARCHAR2 (100);
    P_OUTPUT_TYPE               VARCHAR2 (10);

    FUNCTION xml_main (p_ou IN VARCHAR2, p_pay_group IN VARCHAR2, p_payment_method IN VARCHAR2, p_vendor_name IN VARCHAR2, p_vendor_num IN VARCHAR2, p_vendor_site IN VARCHAR2, p_vendor_type IN VARCHAR2, P_PAY_DATE_FROM IN VARCHAR2, p_pay_date_to IN VARCHAR2, p_invoice_num IN VARCHAR2, p_payment_num IN NUMBER, P_EMAIL_DISTRIBUTION_LIST IN VARCHAR2
                       , P_OUTPUT_TYPE IN VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION send_email (P_EMAIL_REQUIRED IN VARCHAR2)
        RETURN BOOLEAN;

    PROCEDURE main (p_errbuf OUT VARCHAR2, p_retcode OUT NUMBER, p_ou IN VARCHAR2, p_pay_group IN VARCHAR2, p_payment_method IN VARCHAR2, p_vendor_name IN VARCHAR2, p_vendor_num IN VARCHAR2, p_vendor_site IN VARCHAR2, p_vendor_type IN VARCHAR2, P_PAY_DATE_FROM IN VARCHAR2, p_pay_date_to IN VARCHAR2, p_invoice_num IN VARCHAR2, p_payment_num IN NUMBER, P_EMAIL_DISTRIBUTION_LIST IN VARCHAR2, P_EMAIL_REQUIRED IN VARCHAR2
                    , P_OUTPUT_TYPE IN VARCHAR2);
END xxd_ap_send_rem_adv_pkg;
/
