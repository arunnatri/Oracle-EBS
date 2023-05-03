--
-- XXDOAR021_CIT_TT  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:02 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOAR021_CIT_TT"
AS
    p_sql_stmt    VARCHAR2 (32000);
    p_sql_stmt2   VARCHAR2 (32000);
    -- Report Input Parameters
    pn_org_id     NUMBER;
    p_batch_id    NUMBER;
    p_file_name   VARCHAR2 (100);
    p_source      VARCHAR2 (1000);
    p_iden_rec    VARCHAR2 (2000);
    p_sent_yn     VARCHAR2 (20);

    FUNCTION before_report_1
        RETURN BOOLEAN;
END xxdoar021_cit_tt;
/
