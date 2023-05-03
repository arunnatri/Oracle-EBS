--
-- XXD_OM_SHP_EXT_PKG  (Package) 
--
--  Dependencies: 
--   DO_MAIL_UTILS (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:22:23 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXD_OM_SHP_EXT_PKG
IS
    PROCEDURE shipping_data_extract_report (p_d1 OUT VARCHAR2, p_d2 OUT VARCHAR2, p_from_date IN VARCHAR2
                                            , p_to_date IN VARCHAR2);

    FUNCTION get_email_recips (v_lookup_type VARCHAR2)
        RETURN do_mail_utils.tbl_recips;

    PROCEDURE p_line (p_output VARCHAR2);
END XXD_OM_SHP_EXT_PKG;
/
