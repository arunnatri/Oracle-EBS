--
-- XXD_GL_LX_REPORTS_PKG  (Package) 
--
--  Dependencies: 
--   FND_API (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:48 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_GL_LX_REPORTS_PKG"
/***************************************************************************************
* Program Name : XXD_GL_LX_REPORTS_PKG                                               *
* Language     : PL/SQL                                                                *
* Description  : Package used to import the data and process the FASB Min LX Obligation*
*                Report                                                                *
* History      :                                                                       *
*                                                                                      *
* WHO          :       WHAT      Desc                                    WHEN          *
* -------------- ----------------------------------------------------------------------*
* Balavenu Rao         1.0       Initial Version                         17-Feb-2022   *
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
    P_CURRENCY                    VARCHAR2 (100);
    P_LX_REPORT_DUMMY3            VARCHAR2 (10);
    P_RATE_TYPE                   VARCHAR2 (100);
    P_REPORT_TYPE                 VARCHAR2 (100);
    P_REPROCESS                   VARCHAR2 (100);

    FUNCTION main
        RETURN BOOLEAN;

    FUNCTION get_rate_type_value
        RETURN VARCHAR2;

    FUNCTION get_current_lease_liability
        RETURN VARCHAR2;

    FUNCTION get_long_term_lease_liability
        RETURN VARCHAR2;

    FUNCTION get_account_info_msg
        RETURN VARCHAR2;

    FUNCTION get_summary_report_lease_liability
        RETURN VARCHAR2;

    FUNCTION get_reprocess_days_control_value
        RETURN NUMBER;
END XXD_GL_LX_REPORTS_PKG;
/
