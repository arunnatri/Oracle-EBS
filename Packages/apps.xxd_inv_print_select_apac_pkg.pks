--
-- XXD_INV_PRINT_SELECT_APAC_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:21:29 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_INV_PRINT_SELECT_APAC_PKG"
AS
    /************************************************************************************************
    * Package         : XXD_INV_PRINT_SELECT_APAC_PKG
    * Author          : Sunera
    * Created         : 12-DEC-2022
    * Program Name    : Invoice Print Selected Invoices - Deckers(APAC)
    * Description     : Invoice Print Selected Invoices - Deckers(APAC)
    *
    * Modification  :
    *-----------------------------------------------------------------------------------------------
    * Date         Developer     Version    Description
    *-----------------------------------------------------------------------------------------------
    * 12-DEC-2022  Kishan Reddy  1.0        Initial Version
    ************************************************************************************************/
    PROCEDURE inv_print_select_main_proc (errbuf OUT VARCHAR2, retcode OUT NUMBER, p_org_id IN NUMBER, p_trx_class IN VARCHAR2, p_trx_date_low IN VARCHAR2, p_trx_date_high IN VARCHAR2, p_customer_id IN NUMBER, p_cust_bill_to IN NUMBER, p_invoice_num_from IN VARCHAR2, p_invoice_num_to IN VARCHAR2, p_cust_num_from IN VARCHAR2, p_cust_num_to IN VARCHAR2, p_brand IN VARCHAR2, p_order_by IN VARCHAR2, p_re_transmit_flag IN VARCHAR2, p_from_email_address IN VARCHAR2, p_send_email_flag IN VARCHAR2, p_cc_email_id IN VARCHAR2
                                          , p_max_limit IN NUMBER, p_max_sets IN NUMBER, p_sales_channel IN VARCHAR2);

    PROCEDURE submit_inv_select_us_child (p_org_id IN NUMBER, p_trx_class IN VARCHAR2, p_trx_date_low IN VARCHAR2, p_trx_date_high IN VARCHAR2, p_customer_id IN NUMBER, p_cust_bill_to IN NUMBER, p_invoice_num_from IN VARCHAR2, p_invoice_num_to IN VARCHAR2, p_cust_num_from IN VARCHAR2, p_cust_num_to IN VARCHAR2, p_brand IN VARCHAR2, p_order_by IN VARCHAR2, p_re_transmit_flag IN VARCHAR2, p_from_email_address IN VARCHAR2, p_send_email_flag IN VARCHAR2, p_cc_email_id IN VARCHAR2, p_max_limit IN NUMBER, p_max_sets IN NUMBER
                                          , p_request_id NUMBER);

    TYPE l_start_cust_name IS TABLE OF VARCHAR2 (100)
        INDEX BY BINARY_INTEGER;

    TYPE l_end_cust_name IS TABLE OF VARCHAR2 (100)
        INDEX BY BINARY_INTEGER;

    TYPE l_wait_count IS TABLE OF NUMBER
        INDEX BY BINARY_INTEGER;

    TYPE l_start_cust_no IS TABLE OF VARCHAR2 (100)
        INDEX BY BINARY_INTEGER;

    TYPE l_end_cust_no IS TABLE OF VARCHAR2 (100)
        INDEX BY BINARY_INTEGER;
END XXD_INV_PRINT_SELECT_APAC_PKG;
/
