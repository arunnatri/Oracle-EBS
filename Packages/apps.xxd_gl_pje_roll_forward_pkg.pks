--
-- XXD_GL_PJE_ROLL_FORWARD_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:56 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXD_GL_PJE_ROLL_FORWARD_PKG
AS
    PN_ACCESS_SET_ID       NUMBER (15);
    PV_LEDGER_NAME         VARCHAR2 (200);
    pv_period_type         VARCHAR2 (10);
    pv_currency_type       VARCHAR2 (10) DEFAULT 'E';
    pn_ledger_id           NUMBER (15);
    pv_currency_code       VARCHAR2 (10);
    pv_period_name         VARCHAR2 (400);
    pv_je_source           VARCHAR2 (200);
    pv_je_category         VARCHAR2 (200);
    pv_period_close_date   DATE;

    PROCEDURE LOG (pv_msgtxt_in IN VARCHAR2);

    PROCEDURE output (pv_msgtxt_in IN VARCHAR2);


    PROCEDURE proc_roll_forward_detail (pn_ledger_id NUMBER, pv_currency_code VARCHAR2, pv_period_name VARCHAR2, pv_je_source VARCHAR2, pv_je_category VARCHAR2, pv_period_close_from_dt DATE
                                        , pv_period_close_to_dt DATE);

    PROCEDURE proc_roll_forward_summary (pv_period_type VARCHAR2, pv_currency_type VARCHAR2 DEFAULT 'E', pn_ledger_id NUMBER, pv_currency_code VARCHAR2, pv_period_name VARCHAR2, pv_je_source VARCHAR2, pv_je_category VARCHAR2, pv_period_close_from_dt DATE, pv_period_close_to_dt DATE
                                         , pv_row_set_name VARCHAR2);

    PROCEDURE proc_roll_forward_main (errbuff                   OUT VARCHAR2,
                                      retcode                   OUT NUMBER,
                                      pv_ledger_name                VARCHAR2,
                                      pn_ledger_id                  NUMBER,
                                      pv_currency_code              VARCHAR2,
                                      Pv_report_level               VARCHAR2, -- SUMMARY OR DETAIL
                                      pv_dummy_param                VARCHAR2,
                                      pv_balance_type               VARCHAR2,
                                      pv_period_name                VARCHAR2,
                                      pv_je_source                  VARCHAR2,
                                      pv_je_category                VARCHAR2,
                                      pv_period_close_from_dt       VARCHAR2,
                                      pv_period_close_to_dt         VARCHAR2,
                                      pv_row_set_name               VARCHAR2);
END;
/
