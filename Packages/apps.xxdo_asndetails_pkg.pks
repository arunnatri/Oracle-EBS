--
-- XXDO_ASNDETAILS_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:15:16 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.xxdo_asndetails_pkg
IS
    FUNCTION afterReport
        RETURN BOOLEAN;

    FUNCTION SMTP_HOST
        RETURN VARCHAR2;
END xxdo_asndetails_pkg;
/
