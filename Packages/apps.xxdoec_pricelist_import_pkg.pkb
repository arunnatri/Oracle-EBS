--
-- XXDOEC_PRICELIST_IMPORT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:56 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOEC_PRICELIST_IMPORT_PKG"
AS
    PROCEDURE xxdoex_do_delete_table
    IS
    BEGIN
        DELETE FROM XXDOEC_STYLE_COLOR_PRICE;

        COMMIT;
    END xxdoex_do_delete_table;

    PROCEDURE xxdoec_ins_pricelists_to_temp (p_style VARCHAR2, p_color VARCHAR2, p_price NUMBER)
    AS
    BEGIN
        INSERT INTO XXDOEC_STYLE_COLOR_PRICE (STYLE, COLOR, PRICE)
             VALUES (p_style, p_color, p_price);
    END xxdoec_ins_pricelists_to_temp;

    PROCEDURE xxdoec_do_pricelist_import (p_price_list_id NUMBER)
    AS
        CURSOR c_rec IS SELECT * FROM XXDOEC_STYLE_COLOR_PRICE;

        x_ret_stat   VARCHAR2 (1);
        x_ret_msg    VARCHAR2 (2000);
    BEGIN
        FOR rec IN c_rec
        LOOP
            XXDOEC_ADD_STYLE_COLOR_TO_PL (rec.style, rec.color, p_price_list_id
                                          , rec.price, x_ret_stat, x_ret_msg);
            DBMS_OUTPUT.put_line (x_ret_stat);
            DBMS_OUTPUT.put_line (x_ret_msg);
            COMMIT;
        END LOOP;
    END;
END XXDOEC_PRICELIST_IMPORT_PKG;
/
