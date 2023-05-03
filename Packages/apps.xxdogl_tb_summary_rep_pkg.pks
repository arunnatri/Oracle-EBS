--
-- XXDOGL_TB_SUMMARY_REP_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:13:28 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOGL_TB_SUMMARY_REP_PKG"
AS
    /***************************************************************************************
    * Program Name : XXDOGL_TB_SUMMARY_REP_PKG                                             *
    * Language     : PL/SQL                                                                *
    * Description  : Package to generate tab-delimited text files with TB Summary at the   *
    *                company and account level                                             *
    * History      :                                                                       *
    *                                                                                      *
    * WHO          :       WHAT      Desc                                    WHEN          *
    * -------------- ----------------------------------------------------------------------*
    * Madhav Dhurjaty      1.0      Initial Version                         06-DEC-2017    *
    * -------------------------------------------------------------------------------------*/
    FUNCTION get_first_period (p_ledger_id     IN NUMBER,
                               p_period_name   IN VARCHAR2)
        RETURN VARCHAR2;

    PROCEDURE main (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_access_set_id IN NUMBER, p_ledger_name IN VARCHAR2, p_ledger_id IN NUMBER, p_chart_of_accounts_id IN NUMBER, p_legal_entity_id IN NUMBER, p_ledger_currency IN VARCHAR2, p_period_from IN VARCHAR2
                    --,p_period_to            IN  VARCHAR2
                    , p_file_path IN VARCHAR2, p_file_name IN VARCHAR2);
END XXDOGL_TB_SUMMARY_REP_PKG;
/
