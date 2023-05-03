--
-- XXDOAP_1099_REP_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:11:51 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.xxdoap_1099_rep_pkg
AS
    /******************************************************************************
       NAME:       XXDOAP_1099_REP_PKG
       PURPOSE:

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0        7/28/2008     Shibu        1. Created this package for AP 1099
    ******************************************************************************/

    /*  This fUNCTION is used to get the  CONTRACT DATE AND AMOUNT FOR 1099 REPORT*/
    p_start_date        VARCHAR2 (50);
    p_end_date          VARCHAR2 (50);
    p_fed_reportable    VARCHAR2 (30);
    p_query_driver      VARCHAR2 (10);
    p_tax_entity_id     NUMBER;
    c_chart_accts_id    NUMBER;
    p_rep_start_dt      VARCHAR2 (30);
    p_rep_end_dt        VARCHAR2 (30);
    p_taxid_disp        VARCHAR2 (30);
    p_org_id            NUMBER;
    c_app_column_name   VARCHAR2 (30);
    p_min_report_flag   VARCHAR2 (10);

    FUNCTION f_get_contract_dt_amt (p_vendor_id NUMBER, p_org_id NUMBER, p_start_date VARCHAR2
                                    , p_end_date VARCHAR2, p_col VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION f_insert_valid_vendors (p_start_date VARCHAR2, p_end_date VARCHAR2, p_fed_reportable VARCHAR2, p_query_driver VARCHAR2, p_tax_entity_id NUMBER, c_chart_accts_id NUMBER, p_rep_start_dt VARCHAR2, p_rep_end_dt VARCHAR2, p_taxid_disp VARCHAR2
                                     , p_org_id NUMBER)
        RETURN BOOLEAN;
END xxdoap_1099_rep_pkg;
/
