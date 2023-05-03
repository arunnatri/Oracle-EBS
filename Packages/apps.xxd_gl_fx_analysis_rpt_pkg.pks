--
-- XXD_GL_FX_ANALYSIS_RPT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:39 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_GL_FX_ANALYSIS_RPT_PKG"
IS
    PROCEDURE proc_main (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, pn_ledger_id NUMBER, pv_FROM_PERIOD VARCHAR2, pv_to_period VARCHAR2, pv_source VARCHAR2, pv_category VARCHAR2, pv_rate_type VARCHAR2, pd_rate_from_date VARCHAR2, pd_rate_to_date VARCHAR2, pv_mode VARCHAR2, pv_reval_only VARCHAR2
                         , pv_from_account VARCHAR2, pv_to_account VARCHAR2);

    FUNCTION get_period_names (pv_FROM_PERIOD   VARCHAR2,
                               pv_to_period     VARCHAR2)
        RETURN VARCHAR2;
END XXD_GL_FX_ANALYSIS_RPT_PKG;
/
