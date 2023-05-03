--
-- XXD_XXDOAR035_CA_WRAPPER_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:26:30 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_XXDOAR035_CA_WRAPPER_PKG"
AS
    /************************************************************************************************
    * Package      : APPS.XXD_XXDOAR035_CA_WRAPPER_PKG
    * Author       : Madhav Dhurjaty
    * Created      : 03-NOV-2016
    * Program Name  : Print Transactions - Deckers Canada
    * Description  : Wrapper Program to call the Print Transactions - Deckers Canada Report for different output types
    *
    * Modification  :
    *-----------------------------------------------------------------------------------------------
    *  Date     Developer         Version  Description
    *-----------------------------------------------------------------------------------------------
    *  03-NOV-2016 Madhav Dhurjaty   V1.0     Development
    *  25-AUG-2017 Madhav Dhurjaty   V1.1     Added creation date parameters for CCR0005936
    ************************************************************************************************/
    PROCEDURE submit_request_layout (errbuf                    OUT VARCHAR2,
                                     retcode                   OUT NUMBER,
                                     p_org_id               IN     NUMBER,
                                     p_trx_class            IN     VARCHAR2,
                                     p_creation_date_low    IN     VARCHAR2, --Added for CCR0005936
                                     p_creation_date_high   IN     VARCHAR2, --Added for CCR0005936
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
                                     -- p_from_email_address   IN       VARCHAR2,
                                     p_printer              IN     VARCHAR2,
                                     p_copies               IN     NUMBER,
                                     p_cc_email_id          IN     VARCHAR2 -- Added for v1.3
                                                                           );
END XXD_XXDOAR035_CA_WRAPPER_PKG;
/
