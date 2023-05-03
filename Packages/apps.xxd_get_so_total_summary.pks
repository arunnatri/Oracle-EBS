--
-- XXD_GET_SO_TOTAL_SUMMARY  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:22 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXD_GET_SO_TOTAL_SUMMARY
IS
    FUNCTION get_order_subtotals (p_header_id NUMBER)
        RETURN NUMBER;

    FUNCTION get_price_adjustments (p_header_id NUMBER)
        RETURN NUMBER;

    FUNCTION get_charges (p_header_id NUMBER)
        RETURN NUMBER;

    FUNCTION get_taxes (p_header_id NUMBER)
        RETURN NUMBER;

    FUNCTION get_net_amount (p_header_id NUMBER)
        RETURN NUMBER;

    FUNCTION get_total_item (p_header_id NUMBER)
        RETURN NUMBER;

    FUNCTION get_hold_status (p_header_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_cancel_date (p_cancel_date IN VARCHAR2)
        RETURN DATE;
END XXD_GET_SO_TOTAL_SUMMARY;
/
