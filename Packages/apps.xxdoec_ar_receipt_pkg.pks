--
-- XXDOEC_AR_RECEIPT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:38 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOEC_AR_RECEIPT_PKG"
AS
    g_application   VARCHAR2 (300) := 'XXDOEC_AR_RECEIPT_PKG';

    PROCEDURE msg (MESSAGE VARCHAR2, debug_level NUMBER:= 100, p_runnum NUMBER:= -1
                   , p_header_id NUMBER:= -1, p_category VARCHAR2:= 'I');

    PROCEDURE create_cash_receipt (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, p_header_id IN NUMBER);

    -- Start of CCR0005991 Changes
    FUNCTION calc_order_total (p_header_id IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_order_line_total (p_header_id IN NUMBER, p_line_group_id IN NUMBER, p_customer_trx_id IN NUMBER)
        RETURN NUMBER;

    FUNCTION check_freight_line (p_customer_trx_id IN NUMBER)
        RETURN BOOLEAN;

    --FUNCTION get_trx_line_total(p_header_id IN NUMBER, p_line_group_id IN NUMBER) RETURN NUMBER;

    FUNCTION get_trx_line_total (p_header_id IN NUMBER, p_line_group_id IN NUMBER, p_customer_trx_id IN NUMBER)
        RETURN NUMBER;
-- FUNCTION get_trx_total(p_header_id IN NUMBER) RETURN NUMBER;
-- End of CCR0005991 Changes

/*FUNCTION check_COD_Order (p_header_id IN NUMBER)
 RETURN BOOLEAN;*/

END XXDOEC_AR_RECEIPT_PKG;
/
