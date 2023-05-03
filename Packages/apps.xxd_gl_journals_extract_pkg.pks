--
-- XXD_GL_JOURNALS_EXTRACT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:45 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_GL_JOURNALS_EXTRACT_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_GL_JOURNALS_EXTRACT_PKG
    * Design       : This package will be used to fetch the Journal details and send to blackline
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 03-Mar-2021  1.0        Showkath Ali            Initial Version
    ******************************************************************************************/
    -- ======================================================================================
    -- Set values for Global Variables
    -- ======================================================================================
    PROCEDURE main (p_errbuf OUT VARCHAR2, p_retcode OUT NUMBER, p_ledger_type IN VARCHAR2, p_access_set_id IN NUMBER, p_ledger_name IN VARCHAR2, p_ledger_id IN NUMBER, p_chart_of_accounts_id IN NUMBER, p_ledger_currency IN VARCHAR2, p_period IN VARCHAR2, p_account_from IN VARCHAR2, p_account_to IN VARCHAR2, p_previous_period IN VARCHAR2, p_current_period IN VARCHAR2, p_jl_creation_date_from IN VARCHAR2, p_jl_creation_date_to IN VARCHAR2, p_summerize_sub_ledger IN VARCHAR2, p_summerize_manual IN VARCHAR2, p_open_balances_only IN VARCHAR2, p_incremental_output IN VARCHAR2, p_file_path IN VARCHAR2, p_override_lastrun IN VARCHAR2, p_override_definition IN VARCHAR2, p_file_path_only IN VARCHAR2, p_source IN VARCHAR2
                    , p_category IN VARCHAR2, p_source_type IN VARCHAR2);

    FUNCTION get_close_date (p_close_method   IN VARCHAR2,
                             p_period_name    IN VARCHAR2)
        RETURN DATE;

    FUNCTION get_sec_ledget_amt (p_period IN VARCHAR2, p_in_ccid IN VARCHAR2, p_in_company NUMBER, p_ledger_id IN NUMBER, p_parent_header_id IN NUMBER, p_line_num IN NUMBER
                                 , p_in_alt_currency IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_rep_ledger_amt (p_period             IN VARCHAR2,
                                 p_in_ccid            IN VARCHAR2,
                                 p_ledger_id          IN NUMBER,
                                 p_parent_header_id   IN NUMBER,
                                 p_line_num           IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_uniq_iden_period (p_in_period      IN VARCHAR2,
                                   p_close_method   IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_secondary_period (p_period_name IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_period_name (p_period_set_name IN VARCHAR2, p_period IN VARCHAR2, p_current_period IN VARCHAR2
                              , p_previous_period IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_period_num (p_period_set_name   IN VARCHAR2,
                             p_period            IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_elegible_journal (pn_ccid         IN NUMBER,
                                   pv_period       IN VARCHAR2,
                                   p_ledger_type   IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_file_path (p_period_set_name        IN VARCHAR2,
                            p_period_name            IN VARCHAR2,
                            p_geo                    IN VARCHAR2,
                            p_vs_unique_identifier   IN VARCHAR2,
                            p_company                IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_period_year (p_period_set_name   IN VARCHAR2,
                              p_period            IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_account_info (pn_ccids IN VARCHAR2, pv_info IN VARCHAR2)
        RETURN VARCHAR2;
END xxd_gl_journals_extract_pkg;
/
