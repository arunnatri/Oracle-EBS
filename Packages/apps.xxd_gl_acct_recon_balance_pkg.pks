--
-- XXD_GL_ACCT_RECON_BALANCE_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--   XXD_GL_ITEM_RECON_TBL_TYPE (Type)
--
/* Formatted on 4/26/2023 4:20:26 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_GL_ACCT_RECON_BALANCE_PKG"
--****************************************************************************************************
--*  NAME       : XXD_GL_ACCT_RECON_BALANCE_PKG
--*  APPLICATION: Oracle General Ledger
--*
--*  AUTHOR     : Gaurav
--*  DATE       : 01-MAR-2021
--*
--*  DESCRIPTION: This package will do the following
--*               A. Extract account balances and generate tab delimted file
--*  REVISION HISTORY:
--*  Change Date     Version             By              Change Description
--****************************************************************************************************
--* 01-MAR-2021      1.0           Gaurav      Initial Creation
--****************************************************************************************************
IS
    gn_error   CONSTANT NUMBER := 2;

    PROCEDURE main_control (p_errbuf OUT VARCHAR2, p_retcode OUT VARCHAR2);

    FUNCTION is_parent (p_in_value VARCHAR2, p_in_vs_name VARCHAR2)
        RETURN VARCHAR2;

    TYPE values_Rec_Type IS RECORD
    (
        p_value    NUMBER
    );

    TYPE values_Tbl_Type IS TABLE OF PLS_INTEGER
        INDEX BY PLS_INTEGER;

    PROCEDURE get_segment_child_values (
        p_value                    IN     VARCHAR2,
        p_hierchy                  IN     VARCHAR2,
        p_type                     IN     VARCHAR2,
        p_gl_item_recon_tbl_type      OUT xxdo.xxd_gl_item_recon_tbl_type);

    PROCEDURE get_ccid_values (p_in_ccid IN NUMBER, p_in_company IN NUMBER, p_in_alt_currency IN VARCHAR2, p_in_period IN VARCHAR2, p_end_date IN VARCHAR2, p_stat_ledger_flag IN VARCHAR2, p_end_bal_flag IN VARCHAR2, p_out_activty_in_prd OUT VARCHAR2, p_out_sec_activty_in_prd OUT VARCHAR2, p_out_active_acct OUT VARCHAR2, p_out_pri_gl_rpt_bal OUT NUMBER, p_out_pri_gl_alt_bal OUT NUMBER, p_out_pri_gl_acct_bal OUT NUMBER, p_out_sec_gl_rpt_bal OUT NUMBER, p_out_sec_gl_alt_bal OUT NUMBER, p_out_sec_gl_acct_bal OUT NUMBER, p_out_alt_currency OUT VARCHAR2, p_out_primary_currency OUT VARCHAR2, p_out_sec_currency OUT VARCHAR2, p_out_secondary_ledger OUT VARCHAR2, p_out_sgl_acct_bal OUT NUMBER
                               , p_sec_curr_code OUT VARCHAR2);

    PROCEDURE account_balance (p_errbuf OUT VARCHAR2, p_retcode OUT VARCHAR2, p_current_period IN VARCHAR2
                               , p_previous_period IN VARCHAR2, p_file_path IN VARCHAR2, p_closing_bal IN VARCHAR2);

    PROCEDURE get_secondary_period (p_period_name          IN     VARCHAR2,
                                    x_period_name             OUT VARCHAR2,
                                    x_start_date              OUT VARCHAR2,
                                    x_quarter_start_date      OUT VARCHAR2,
                                    x_year_start_date         OUT VARCHAR2);

    FUNCTION get_record_exists (pn_ccid IN NUMBER, pv_period_end_date IN VARCHAR2, pv_stat_ledger IN VARCHAR2)
        RETURN NUMBER;
END XXD_GL_ACCT_RECON_BALANCE_PKG;
/
