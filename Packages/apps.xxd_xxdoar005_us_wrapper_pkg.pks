--
-- XXD_XXDOAR005_US_WRAPPER_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:26:29 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_XXDOAR005_US_WRAPPER_PKG"
AS
    /************************************************************************************************
    * Package      : APPS.XXD_XXDOAR005_US_WRAPPER_PKG
    * Author       : BT Technology Team
    * Created      : 25-NOV-2014
    * Program Name  : Account Analysis Report - Deckers
    * Description  : Wrapper Program to call the Account Analysis Report for different output types
    *
    * Modification  :
    *-----------------------------------------------------------------------------------------------
    *  Date     Developer         Version  Description
    *-----------------------------------------------------------------------------------------------
    *  25-Nov-2014 BT Technology Team   V1.1     Development
    * 13-APR-2015 BT Technology Team   V1.2      Wrapper Program to call the Invoice Print - Selected - Deckers Shanghai for different output types
    * 11-JUL-2016 Infosys              V1.3      Wrapper Program to submit the bursting program based on send-email-flag parameter - INC0302174
    ************************************************************************************************/
    PROCEDURE submit_request_layout (errbuf                    OUT VARCHAR2,
                                     retcode                   OUT NUMBER,
                                     p_org_id               IN     NUMBER,
                                     p_trx_class            IN     VARCHAR2,
                                     p_trx_date_low         IN     VARCHAR2 --date
                                                                           ,
                                     p_trx_date_high        IN     VARCHAR2 --DATE
                                                                           ,
                                     p_customer_id          IN     NUMBER,
                                     p_cust_bill_to         IN     NUMBER,
                                     p_invoice_num_from     IN     VARCHAR2,
                                     p_invoice_num_to       IN     VARCHAR2,
                                     p_cust_num_from        IN     VARCHAR2,
                                     p_cust_num_to          IN     VARCHAR2,
                                     p_brand                IN     VARCHAR2,
                                     p_order_by             IN     VARCHAR2,
                                     p_re_transmit_flag     IN     VARCHAR2,
                                     p_from_email_address   IN     VARCHAR2,
                                     p_send_email_flag      IN     VARCHAR2, -- Added for v1.3
                                     p_cc_email_id          IN     VARCHAR2, -- Added for v1.4
                                     p_max_limit            IN     NUMBER,
                                     p_max_sets             IN     NUMBER);

    PROCEDURE submit_request_layout_inv_chn (
        errbuf                    OUT VARCHAR2,
        retcode                   OUT NUMBER,
        p_org_id               IN     NUMBER,
        p_trx_class            IN     VARCHAR2,
        p_trx_date_low         IN     VARCHAR2                          --date
                                              ,
        p_trx_date_high        IN     VARCHAR2                          --DATE
                                              ,
        p_customer_id          IN     NUMBER,
        p_cust_bill_to         IN     NUMBER,
        p_invoice_num_from     IN     VARCHAR2,
        p_invoice_num_to       IN     VARCHAR2,
        p_cust_num_from        IN     VARCHAR2,
        p_cust_num_to          IN     VARCHAR2,
        p_brand                IN     VARCHAR2,
        p_order_by             IN     VARCHAR2,
        p_re_transmit_flag     IN     VARCHAR2,
        p_from_email_address   IN     VARCHAR2);
END xxd_xxdoar005_us_wrapper_pkg;
/
