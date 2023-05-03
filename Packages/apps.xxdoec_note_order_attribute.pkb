--
-- XXDOEC_NOTE_ORDER_ATTRIBUTE  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:00 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOEC_NOTE_ORDER_ATTRIBUTE"
AS
    -- =======================================================
    -- Author:      Amitava Ghosh
    -- Create date: 10/10/2014
    -- Description: This package is used to store attribute details. Presently it is storing Note attribute
    -- =======================================================
    -- Modification History
    -- Modified Date/By/Description:
    -- 12/27/2016 KCOPELAND Added new method to retrieve all records for an order or just a subset based on attribute_type and/or cust_po_number and/or line_id
    -- =======================================================
    -- Sample Execution
    -- =======================================================

    PROCEDURE get_note_detail_lst (p_order_header_id IN VARCHAR2, p_attribute_type IN VARCHAR2, o_order_note_detail OUT t_order_note_detail_cursor)
    IS
    BEGIN
        OPEN o_order_note_detail FOR
              SELECT /*+ parallel(2) */
                     attribute_id, attribute_type, attribute_value,
                     user_name, order_header_id, line_id,
                     creation_date
                FROM XXDOEC_ORDER_ATTRIBUTE
               WHERE     attribute_type = p_attribute_type
                     AND order_header_id = p_order_header_id
            ORDER BY attribute_id ASC;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.PUT_LINE (SQLERRM);
    END get_note_detail_lst;

    PROCEDURE get_order_attribute_detail (
        p_order_header_id     IN     VARCHAR2,
        p_attribute_type      IN     VARCHAR2,
        p_cust_po_number      IN     VARCHAR2,
        p_line_id             IN     NUMBER,
        o_order_note_detail      OUT t_order_note_detail_cursor)
    IS
        l_order_header_id   NUMBER := TO_NUMBER (p_order_header_id);
    BEGIN
        --If the only identifier passed in is the line_id, get the header_id based on the line id
        IF (p_cust_po_number IS NULL AND p_order_header_id IS NULL AND p_line_id > 0)
        THEN
            SELECT header_id
              INTO l_order_header_id
              FROM oe_order_lines_all
             WHERE line_id = p_line_id;
        END IF;

        --If the cust_po_number was passed in use it and ignore what may have been passed in the p_order_header_id parameter
        IF (p_cust_po_number IS NOT NULL AND LENGTH (p_cust_po_number) > 0)
        THEN
            SELECT header_id
              INTO l_order_header_id
              FROM oe_order_headers_all
             WHERE cust_po_number = p_cust_po_number;
        END IF;

        OPEN o_order_note_detail FOR
              SELECT /*+ parallel(2) */
                     attribute_id, attribute_type, attribute_value,
                     user_name, order_header_id, line_id,
                     creation_date
                FROM XXDOEC_ORDER_ATTRIBUTE
               WHERE     1 = 1
                     AND order_header_id =
                         NVL (l_order_header_id, order_header_id)
                     AND (NVL (p_line_id, -1) = NVL (line_id, -1) OR NVL (p_line_id, line_id) = line_id)
                     AND NVL (p_attribute_type, attribute_type) =
                         attribute_type
            ORDER BY attribute_id ASC;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.PUT_LINE (SQLERRM);
    END get_order_attribute_detail;


    PROCEDURE INSERT_ORDER_ATTRIBUTE (p_attribute_type    VARCHAR2,
                                      p_attribute_value   VARCHAR2,
                                      p_username          VARCHAR2,
                                      p_order_header_id   NUMBER,
                                      p_line_id           NUMBER)
    IS
    BEGIN
        INSERT INTO XXDOEC_ORDER_ATTRIBUTE
             VALUES (XXDOEC_ATTRIBUTE_ID_S.NEXTVAL, p_attribute_type, p_attribute_value, p_username, p_order_header_id, p_line_id
                     , SYSDATE);

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            RAISE_APPLICATION_ERROR (
                -20001,
                   p_attribute_type
                || ':$:'
                || p_attribute_value
                || ':$:'
                || p_username
                || ':$:'
                || p_order_header_id
                || ':$:'
                || p_line_id
                || ':$:'
                || SQLERRM,
                TRUE);
    END;
END XXDOEC_NOTE_ORDER_ATTRIBUTE;
/
