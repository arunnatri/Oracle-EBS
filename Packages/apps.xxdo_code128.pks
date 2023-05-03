--
-- XXDO_CODE128  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:15:33 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXDO_CODE128
AS
    FUNCTION Code128C (data_to_encode VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION C128C_to_num (dta VARCHAR2)
        RETURN NUMBER;
END;
/


GRANT EXECUTE ON APPS.XXDO_CODE128 TO APPSRO
/
