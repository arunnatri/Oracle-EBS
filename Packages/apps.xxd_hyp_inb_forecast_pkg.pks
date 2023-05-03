--
-- XXD_HYP_INB_FORECAST_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:21:09 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_HYP_INB_FORECAST_PKG"
IS
      /****************************************************************************************************
 NAME           : XXD_HYP_INB_FORECAST_PKG
 REPORT NAME    : Deckers Hyperion Inbound Forecast Program

 REVISIONS:
 Date         Author             Version  Description
 -----------  ----------         -------  ------------------------------------------------------------
 26-OCT-2021  Damodara Gupta     1.0      Created this package using XXD_HYP_INB_FORECAST_PKG
                                          to upload the forecast budget from Hyperion system
                                          into an Oracle staging table
*****************************************************************************************************/

    gn_error        CONSTANT NUMBER := 2;
    gn_warning      CONSTANT NUMBER := 1;

    gn_user_id      CONSTANT NUMBER := fnd_global.user_id;
    gn_request_id   CONSTANT NUMBER := fnd_global.conc_request_id;

    gv_delim_pipe            VARCHAR2 (1) := '|';
    gv_delim_comma           VARCHAR2 (1) := ',';
    g_limit                  NUMBER := 50000;

    PROCEDURE write_log_prc (pv_msg IN VARCHAR2);

    PROCEDURE get_file_names (pv_directory_name IN VARCHAR2);

    PROCEDURE load_file_into_tbl_prc (pv_table IN VARCHAR2, pv_dir IN VARCHAR2 DEFAULT 'XXD_HYP_FORECAST_INB_DIR', pv_filename IN VARCHAR2, pv_ignore_headerlines IN INTEGER DEFAULT 1, pv_delimiter IN VARCHAR2 DEFAULT '|', pv_optional_enclosed IN VARCHAR2 DEFAULT '"'
                                      , pv_num_of_columns IN NUMBER);

    PROCEDURE validate_prc (pv_file_name IN VARCHAR2);

    PROCEDURE generate_hyperion_report_prc (pv_period_from IN VARCHAR2, pv_period_to IN VARCHAR2, pv_consumed IN VARCHAR2
                                            , --pv_override             IN     VARCHAR2,
                                              pv_rep_file_name OUT VARCHAR2);

    PROCEDURE generate_hyp_excep_report_prc (pv_rep_file_name OUT VARCHAR2);

    PROCEDURE generate_hyp_ccid_report_prc (pv_rep_file_name OUT VARCHAR2);

    PROCEDURE purge_hyperion_int_prc (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, pv_num_days IN NUMBER);

    PROCEDURE main_prc (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, pv_gen_rep IN VARCHAR2, pv_dummy IN VARCHAR2, pv_period_from IN VARCHAR2, pv_period_to IN VARCHAR2
                        , pv_consumed IN VARCHAR2, pv_override IN VARCHAR2);
END XXD_HYP_INB_FORECAST_PKG;
/
