--
-- XXD_PRINT_TRX_DEC_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:25:14 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_PRINT_TRX_DEC_PKG"
AS
    /************************************************************************************************
    * Package         : XXD_PRINT_TRX_DEC_PKG
    * Author          : Infosys
    * Created         : 07-NOV-2016
    * Program Name    : Print Transactions - Deckers
    * Description     : Wrapper Program  to control output file size for OPP - ENHC0012783
    *
    * Modification  :
    *-----------------------------------------------------------------------------------------------
    * Date         Developer     Version    Description
    *-----------------------------------------------------------------------------------------------
    * 07-NOV-2016  Infosys       1.0        Initial Version for Changes to control output
    *                                       file size for OPP - ENHC0012783
    * 25-AUG-2017  Madhav D      1.1        Added creation date parameters for CCR0005936
    ************************************************************************************************/

    PROCEDURE print_trx_dec_main (errbuf IN OUT VARCHAR2, retcode IN OUT NUMBER, p_org_id IN NUMBER, p_trx_class IN VARCHAR2, p_creation_date_low IN VARCHAR2, --Added for CCR0005936
                                                                                                                                                               p_creation_date_high IN VARCHAR2, --Added for CCR0005936
                                                                                                                                                                                                 p_trx_date_low IN VARCHAR2, p_trx_date_high IN VARCHAR2, p_customer_id IN NUMBER, p_cust_bill_to IN NUMBER, p_invoice_num_from IN VARCHAR2, p_invoice_num_to IN VARCHAR2, p_cust_num_from IN VARCHAR2, p_cust_num_to IN VARCHAR2, p_brand IN VARCHAR2, p_order_by IN VARCHAR2, p_re_transmit_flag IN VARCHAR2, p_printer IN VARCHAR2, p_copies IN NUMBER, p_cc_email_id IN VARCHAR2, p_max_limit IN NUMBER
                                  , p_max_sets IN NUMBER);

    PROCEDURE Submit_print_trx_dec_child (p_org_id IN NUMBER, p_trx_class IN VARCHAR2, p_creation_date_low IN VARCHAR2, --Added for CCR0005936
                                                                                                                        p_creation_date_high IN VARCHAR2, --Added for CCR0005936
                                                                                                                                                          p_trx_date_low IN VARCHAR2, p_trx_date_high IN VARCHAR2, p_customer_id IN NUMBER, p_cust_bill_to IN NUMBER, p_invoice_num_from IN VARCHAR2, p_invoice_num_to IN VARCHAR2, p_cust_num_from IN VARCHAR2, p_cust_num_to IN VARCHAR2, p_brand IN VARCHAR2, p_order_by IN VARCHAR2, p_re_transmit_flag IN VARCHAR2, p_printer IN VARCHAR2, p_copies IN NUMBER, p_cc_email_id IN VARCHAR2
                                          , p_max_limit IN NUMBER, p_max_sets IN NUMBER, p_request_id IN NUMBER);

    TYPE l_start_cust_name IS TABLE OF VARCHAR2 (100)
        INDEX BY BINARY_INTEGER;

    TYPE l_end_cust_name IS TABLE OF VARCHAR2 (100)
        INDEX BY BINARY_INTEGER;

    TYPE l_start_cust_no IS TABLE OF VARCHAR2 (100)
        INDEX BY BINARY_INTEGER;

    TYPE l_end_cust_no IS TABLE OF VARCHAR2 (100)
        INDEX BY BINARY_INTEGER;

    TYPE l_wait_count IS TABLE OF NUMBER
        INDEX BY BINARY_INTEGER;
END XXD_PRINT_TRX_DEC_PKG;
/
