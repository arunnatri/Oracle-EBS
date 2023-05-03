--
-- XXDO_SALES_PROGRAM_ALERT_PKG  (Package) 
--
--  Dependencies: 
--   DO_MAIL_UTILS (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:17:42 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXDO_SALES_PROGRAM_ALERT_PKG
IS
    FUNCTION GET_EMAIL_RECIPS (v_lookup_type VARCHAR2)
        RETURN DO_MAIL_UTILS.tbl_recips;

    PROCEDURE xxdo_sales_program_alert (p_d1 OUT VARCHAR2, p_d2 OUT VARCHAR2);
END XXDO_SALES_PROGRAM_ALERT_PKG;
/
