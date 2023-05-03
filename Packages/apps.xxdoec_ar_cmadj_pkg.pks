--
-- XXDOEC_AR_CMADJ_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:35 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOEC_AR_CMADJ_PKG"
AS
    g_application   VARCHAR2 (300) := 'XXDOEC_AR_RECEIPT_PKG';

    PROCEDURE msg (MESSAGE VARCHAR2, debug_level NUMBER:= 100, p_runnum NUMBER:= -1
                   , p_header_id NUMBER:= -1, p_category VARCHAR2:= 'I');

    PROCEDURE create_cm_adjustment (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, p_header_id IN NUMBER);

    FUNCTION get_activity_name (p_rct_method        IN VARCHAR2,
                                p_ret_reason_code   IN VARCHAR2)
        RETURN VARCHAR2;

    --   FUNCTION calc_order_total(p_header_id IN NUMBER) RETURN NUMBER;

    --   FUNCTION get_trx_total(p_header_id IN NUMBER) RETURN NUMBER;

    FUNCTION get_order_line_total (p_header_id IN NUMBER, p_line_group_id IN NUMBER, p_customer_trx_id IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_trx_line_total (p_header_id IN NUMBER, p_line_group_id IN NUMBER, p_customer_trx_id IN NUMBER)
        RETURN NUMBER;
/*FUNCTION check_COD_Order (p_header_id IN NUMBER)
 RETURN BOOLEAN;*/

END XXDOEC_AR_CMADJ_PKG;
/
