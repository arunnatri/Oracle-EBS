--
-- XXD_CM_CALC_OH_PERCNT_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:19:37 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_CM_CALC_OH_PERCNT_PKG"
IS
      /******************************************************************************************
 NAME           : XXD_CM_CALC_OH_PERCNT_PKG
 PROGRAM NAME   : Deckers CM Calculate OH Percentage

 REVISIONS:
 Date        Author             Version  Description
 ----------  ----------         -------  ---------------------------------------------------
 23-JAN-2022 Damodara Gupta     1.0      Created this package using XXD_CM_CALC_OH_PERCNT_PKG
                                         to calculate the OH NONDuty
*********************************************************************************************/

    gn_user_id      CONSTANT NUMBER := fnd_global.user_id;
    gn_request_id   CONSTANT NUMBER := fnd_global.conc_request_id;

    PROCEDURE main_prc (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, pv_date IN VARCHAR2, pv_start_date IN VARCHAR2, pv_end_date IN VARCHAR2, pv_mode IN VARCHAR2, pv_int_adj_percnt IN NUMBER DEFAULT 0, pv_dom_adj_percnt IN NUMBER DEFAULT 0, pv_expense_adj_percnt IN NUMBER DEFAULT 0
                        , pv_expense_adj_amt IN NUMBER DEFAULT 0);
END xxd_cm_calc_oh_percnt_pkg;
/
