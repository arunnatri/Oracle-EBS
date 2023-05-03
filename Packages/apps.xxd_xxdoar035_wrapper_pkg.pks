--
-- XXD_XXDOAR035_WRAPPER_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:26:31 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_XXDOAR035_WRAPPER_PKG"
AS
    /************************************************************************************************
    * Package      : APPS.XXD_XXDOAR005_WRAPPER_PKG
    * Author       : BT Technology Team
    * Created      : 27-JAN-2015
    * Program Name  : Print Transactions - Deckers
    * Description  : Wrapper Program to call the Print Transactions - Deckers Report for different output types
    *
    * Modification  :
    *-----------------------------------------------------------------------------------------------
    *  Date     Developer         Version  Description
    *-----------------------------------------------------------------------------------------------
    *  27-JAN-2015 BT Technology Team   V1.1     Development
    *  14-APR-2015 BT Technology Team   V1.2       Wrapper Program to call the Print Transactions - Deckers(CHN)
    *                                                Report for different output types
    *  11-AUG-2016 Infosys              V1.3      To add cc email while sending outbound emails - ENHC0012628
    *  25-AUG-2017 Madhav D             V1.4      Added Creation date parameters
    ************************************************************************************************/
    PROCEDURE submit_request_layout (errbuf OUT VARCHAR2, retcode OUT NUMBER, p_org_id IN NUMBER, p_trx_class IN VARCHAR2, p_creation_date_low IN VARCHAR2, --Added for CCR0005936
                                                                                                                                                            p_creation_date_high IN VARCHAR2, --Added for CCR0005936
                                                                                                                                                                                              p_trx_date_low IN VARCHAR2 --date
                                                                                                                                                                                                                        , p_trx_date_high IN VARCHAR2 --DATE
                                                                                                                                                                                                                                                     , p_customer_id IN NUMBER, p_cust_bill_to IN NUMBER, p_invoice_num_from IN VARCHAR2, p_invoice_num_to IN VARCHAR2, p_cust_num_from IN VARCHAR2, p_cust_num_to IN VARCHAR2, p_brand IN VARCHAR2, p_order_by IN VARCHAR2, p_re_transmit_flag IN VARCHAR2, -- p_from_email_address   IN       VARCHAR2,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             p_printer IN VARCHAR2, p_copies IN NUMBER, p_cc_email_id IN VARCHAR2, -- Added for v1.3
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   p_max_limit IN NUMBER
                                     , p_max_sets IN NUMBER);

    PROCEDURE submit_request_layout_pri_chn (
        errbuf                  OUT VARCHAR2,
        retcode                 OUT NUMBER,
        p_org_id             IN     NUMBER,
        p_trx_class          IN     VARCHAR2,
        p_trx_date_low       IN     VARCHAR2                            --date
                                            ,
        p_trx_date_high      IN     VARCHAR2                            --DATE
                                            ,
        p_customer_id        IN     NUMBER,
        p_cust_bill_to       IN     NUMBER,
        p_invoice_num_from   IN     VARCHAR2,
        p_invoice_num_to     IN     VARCHAR2,
        p_cust_num_from      IN     VARCHAR2,
        p_cust_num_to        IN     VARCHAR2,
        p_brand              IN     VARCHAR2,
        p_order_by           IN     VARCHAR2,
        p_re_transmit_flag   IN     VARCHAR2,
        -- p_from_email_address   IN       VARCHAR2,
        p_printer            IN     VARCHAR2,
        p_copies             IN     NUMBER);
END xxd_xxdoar035_wrapper_pkg;
/
