--
-- XXD_TM_APPR_RULES_UPL_PKG  (Package) 
--
--  Dependencies: 
--   FND_API (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:25:44 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_TM_APPR_RULES_UPL_PKG"
IS
    --  ####################################################################################################
    --  Author(s)       : Aravind Kannuri
    --  System          : Oracle Applications
    --  Subsystem       : EBS
    --  Change          : CCR0007546
    --  Schema          : APPS
    --  Purpose         : Package is used for WebADI to Create\Edit of AMS Approval Rules
    --  Dependency      : None
    --  Change History
    --  --------------
    --  Date            Name                Ver     Change          Description
    --  ----------      --------------      -----   -------------   ---------------------
    --  23-Oct-2018     Aravind Kannuri     1.0     NA              Initial Version
    --  10-Dec-2019     Showkath Ali        1.1     CCR0008340      Added Setup Type
    --
    --  ####################################################################################################

    --Global Variables
    -- Return Statuses
    gv_ret_success       CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_success;
    gv_ret_error         CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_error;
    gv_ret_unexp_error   CONSTANT VARCHAR2 (1)
                                      := fnd_api.g_ret_sts_unexp_error ;
    gv_ret_warning       CONSTANT VARCHAR2 (1) := 'W';
    gn_success           CONSTANT NUMBER := 0;
    gn_warning           CONSTANT NUMBER := 1;
    gn_error             CONSTANT NUMBER := 2;

    --Upload Procedure called by WebADI
    PROCEDURE upload_proc (pv_mode VARCHAR2, pv_ou_name VARCHAR2, pv_old_appr_rule_name VARCHAR2, pv_appr_rule_name VARCHAR2, pv_approval_type VARCHAR2, pv_claim_type VARCHAR2, pv_reason VARCHAR2, pv_start_date VARCHAR2, pv_end_date VARCHAR2, pv_currency VARCHAR2, pn_min_amount NUMBER, pn_max_amount NUMBER, pv_description VARCHAR2, pv_appr_order NUMBER, pv_approver_type VARCHAR2, pv_appr_user_role VARCHAR2, pv_appr_start_date VARCHAR2, pv_appr_end_date VARCHAR2, pv_attribute_num1 NUMBER DEFAULT NULL, pv_attribute_num2 NUMBER DEFAULT NULL, pv_attribute_num3 NUMBER DEFAULT NULL, pv_attribute_num4 NUMBER DEFAULT NULL, --pv_attribute_chr1         VARCHAR2  DEFAULT NULL, --CCR0008340
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               pv_attribute_chr1 VARCHAR2, --CCR0008340
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           pv_attribute_chr2 VARCHAR2 DEFAULT NULL, pv_attribute_chr3 VARCHAR2 DEFAULT NULL, pv_attribute_chr4 VARCHAR2 DEFAULT NULL, pv_attribute_date1 DATE DEFAULT NULL
                           , pv_attribute_date2 DATE DEFAULT NULL);

    PROCEDURE import_proc (pv_errbuf OUT VARCHAR2, pv_retcode OUT NUMBER);


    PROCEDURE status_report (pv_error_msg OUT VARCHAR2);
END XXD_TM_APPR_RULES_UPL_PKG;
/
