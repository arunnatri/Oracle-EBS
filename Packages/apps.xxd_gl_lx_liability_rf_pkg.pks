--
-- XXD_GL_LX_LIABILITY_RF_PKG  (Package) 
--
--  Dependencies: 
--   FND_API (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:47 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_GL_LX_LIABILITY_RF_PKG"
/***************************************************************************************
* Program Name : XXD_GL_LX_LIABILITY_RF_PKG                                            *
* Language     : PL/SQL                                                                *
* Description  : Package used to report the LX Liability Report                        *
*                                                                                      *
* History      :                                                                       *
*                                                                                      *
* WHO          :       WHAT      Desc                                    WHEN          *
* -------------- ----------------------------------------------------------------------*
* Balavenu Rao         1.0       Initial Version                         15-FEB-2023   *
* -------------------------------------------------------------------------------------*/
AS
    --Global Constants
    -- Return Statuses
    gv_ret_success       CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_success;
    gv_ret_error         CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_error;
    gv_ret_unexp_error   CONSTANT VARCHAR2 (1)
                                      := fnd_api.g_ret_sts_unexp_error ;
    gv_ret_warning       CONSTANT VARCHAR2 (1) := 'W';
    gn_success           CONSTANT NUMBER := 0;
    gn_warning           CONSTANT NUMBER := 1;
    gn_error             CONSTANT NUMBER := 2;

    P_REPORT_PROCESS              VARCHAR2 (100);
    P_LX_REPORT_DUMMY2            VARCHAR2 (100);
    P_LX_REPORT_DUMMY             VARCHAR2 (100);
    P_DATE                        VARCHAR2 (100);
    P_OB_SPOT_RATE_DATE           VARCHAR2 (100);
    P_CURRENCY                    VARCHAR2 (100);
    --    P_RATE_TYPE             VARCHAR2(100);
    P_BALLANCE_RATE_TYPE          VARCHAR2 (100);
    P_PERIOD_RATE_TYPE            VARCHAR2 (100);
    P_REPROCESS                   VARCHAR2 (100);

    FUNCTION main
        RETURN BOOLEAN;

    FUNCTION get_balance_rate_value
        RETURN VARCHAR2;

    FUNCTION get_period_rate_value
        RETURN VARCHAR2;

    FUNCTION get_usd_previous_month_prepaid_amount (p_current_ob_date DATE, p_current_portfolio VARCHAR2, current_contract_name VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_sum_usd_previous_month_prepaid_amount (p_parameter_date DATE, p_ob_date DATE, p_current_portfolio VARCHAR2
                                                        , current_contract_name VARCHAR2, P_amount_type VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_sum_functional_previous_month_prepaid_amount (p_parameter_date DATE, p_ob_date DATE, p_current_portfolio VARCHAR2
                                                               , current_contract_name VARCHAR2, P_amount_type VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_reprocess_days_control_value
        RETURN NUMBER;
END XXD_GL_LX_LIABILITY_RF_PKG;
/
