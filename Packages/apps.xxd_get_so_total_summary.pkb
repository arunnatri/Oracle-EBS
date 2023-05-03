--
-- XXD_GET_SO_TOTAL_SUMMARY  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:25 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.XXD_GET_SO_TOTAL_SUMMARY
IS
    FUNCTION get_order_subtotals (p_header_id IN NUMBER)
        RETURN NUMBER
    IS
        v_subtotal   NUMBER;
        v_discount   NUMBER;
        v_charges    NUMBER;
        v_tax        NUMBER;
    BEGIN
        oe_oe_totals_summary.order_totals (p_header_id   => p_header_id,
                                           p_subtotal    => v_subtotal,
                                           p_discount    => v_discount,
                                           p_charges     => v_charges,
                                           p_tax         => v_tax);
        RETURN NVL (v_subtotal, 0);
    END get_order_subtotals;

    FUNCTION get_price_adjustments (p_header_id IN NUMBER)
        RETURN NUMBER
    IS
        v_subtotal   NUMBER;
        v_discount   NUMBER;
        v_charges    NUMBER;
        v_tax        NUMBER;
    BEGIN
        oe_oe_totals_summary.order_totals (p_header_id   => p_header_id,
                                           p_subtotal    => v_subtotal,
                                           p_discount    => v_discount,
                                           p_charges     => v_charges,
                                           p_tax         => v_tax);
        RETURN NVL (v_discount, 0);
    END get_price_adjustments;

    FUNCTION get_charges (p_header_id IN NUMBER)
        RETURN NUMBER
    IS
        v_subtotal   NUMBER;
        v_discount   NUMBER;
        v_charges    NUMBER;
        v_tax        NUMBER;
    BEGIN
        oe_oe_totals_summary.order_totals (p_header_id   => p_header_id,
                                           p_subtotal    => v_subtotal,
                                           p_discount    => v_discount,
                                           p_charges     => v_charges,
                                           p_tax         => v_tax);
        RETURN NVL (v_charges, 0);
    END get_charges;

    FUNCTION get_taxes (p_header_id IN NUMBER)
        RETURN NUMBER
    IS
        v_subtotal   NUMBER;
        v_discount   NUMBER;
        v_charges    NUMBER;
        v_tax        NUMBER;
    BEGIN
        oe_oe_totals_summary.order_totals (p_header_id   => p_header_id,
                                           p_subtotal    => v_subtotal,
                                           p_discount    => v_discount,
                                           p_charges     => v_charges,
                                           p_tax         => v_tax);
        RETURN NVL (v_tax, 0);
    END get_taxes;

    FUNCTION get_net_amount (p_header_id IN NUMBER)
        RETURN NUMBER
    IS
        v_subtotal   NUMBER;
        v_discount   NUMBER;
        v_charges    NUMBER;
        v_tax        NUMBER;
    BEGIN
        oe_oe_totals_summary.order_totals (p_header_id   => p_header_id,
                                           p_subtotal    => v_subtotal,
                                           p_discount    => v_discount,
                                           p_charges     => v_charges,
                                           p_tax         => v_tax);
        /*  RETURN (  NVL (v_subtotal, 0)
                  + NVL (v_discount, 0)
                  + NVL (v_charges, 0)
                  + NVL (v_tax, 0)
                 );
        */
        RETURN (NVL (v_subtotal, 0) + NVL (v_charges, 0) + NVL (v_tax, 0));
    END get_net_amount;

    FUNCTION get_total_item (p_header_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_order_quantity   NUMBER;
    BEGIN
        SELECT SUM (ordered_quantity)
          INTO ln_order_quantity
          FROM oe_order_lines_all
         WHERE header_id = p_header_id;

        RETURN NVL (ln_order_quantity, 0);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END get_total_item;

    FUNCTION get_hold_status (p_header_id IN NUMBER)
        RETURN VARCHAR2
    IS
        v_hold      VARCHAR2 (3);
        v_no_hold   NUMBER;
    BEGIN
        SELECT COUNT (*)
          INTO v_no_hold
          FROM oe_order_holds_all
         WHERE     header_id = p_header_id
               AND line_id IS NULL
               AND released_flag = 'N';

        IF (v_no_hold > 0)
        THEN
            v_hold   := 'Y';
        ELSE
            v_hold   := 'N';
        END IF;

        RETURN v_hold;
    END get_hold_status;

    FUNCTION get_cancel_date (p_cancel_date IN VARCHAR2)
        RETURN DATE
    IS
        ln_cancel_date          VARCHAR2 (15);
        ln_cancel_date_substr   VARCHAR2 (11);
        ld_cancel_date          DATE;
    BEGIN
        /*IF (LENGTH (TRIM (p_cancel_date)) > 0)
        THEN
           IF (LENGTH (p_cancel_date) > 11)
           THEN
              ln_cancel_date_substr := SUBSTR (p_cancel_date, 1, 10);
              ln_cancel_date := TO_DATE (ln_cancel_date_substr, 'yyyy/mm/dd');
           ELSE
              --  LN_CANCEL_DATE_SUBSTR :=P_CANCEL_DATE;
              ln_cancel_date := p_cancel_date;
           END IF;
        END IF;
        */
        SELECT TO_DATE (DECODE (LENGTH (TRIM (SUBSTR (p_cancel_date, 1, 11))), 10, TO_CHAR (TO_DATE (TRIM (SUBSTR (p_cancel_date, 1, 11)), 'yyyy/mm/dd'), 'DD-Mon-YYYY'), TO_CHAR (TO_DATE (p_cancel_date, 'DD-Mon-YY'), 'DD-Mon-YYYY')), 'DD-MON-YYYY')
          INTO ld_cancel_date
          FROM DUAL;

        RETURN ld_cancel_date;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_cancel_date;
END XXD_GET_SO_TOTAL_SUMMARY;
/
