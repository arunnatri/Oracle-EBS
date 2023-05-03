--
-- XXDO_PO_IMPORT_EXCEPTION_REP  (Package) 
--
--  Dependencies: 
--   DO_MAIL_UTILS (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:17:24 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_PO_IMPORT_EXCEPTION_REP"
IS
    PROCEDURE XXDO_PO_IMPORT_EXCP_REP_PROC (p_run_date   IN VARCHAR2,
                                            P_REGION     IN VARCHAR2);

    FUNCTION get_email_recips (v_lookup_type VARCHAR2)
        RETURN do_mail_utils.tbl_recips;
END;
/
