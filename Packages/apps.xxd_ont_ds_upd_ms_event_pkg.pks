--
-- XXD_ONT_DS_UPD_MS_EVENT_PKG  (Package) 
--
--  Dependencies: 
--   FND_API (Package)
--   FND_GLOBAL (Package)
--   FND_PROFILE (Package)
--   STANDARD (Package)
--   XXD_WMS_EMAIL_OUTPUT_T (Table)
--
/* Formatted on 4/26/2023 4:23:11 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_DS_UPD_MS_EVENT_PKG"
AS
    /********************************************************************************************
      * Package         : XXD_ONT_DS_UPD_MS_EVENT_PKG
      * Description     : Package is for Direct Ship Mile Stone Event Updates in batch mode
      * Notes           : WEBADI
      * Modification    :
      *-----------------------------------------------------------------------------------------
      * Date         Version#      Name                       Description
      *-----------------------------------------------------------------------------------------
      * 15-NOV-2022  1.0           Aravind Kannuri            Initial Version for CCR0010296
      *
      ******************************************************************************************/
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

    gv_debug_text                 VARCHAR2 (4000);
    gv_debug_message              VARCHAR2 (1000);
    gv_package_name      CONSTANT VARCHAR2 (30)
                                      := 'XXD_ONT_DS_UPD_MS_EVENT_PKG' ;
    gn_session_id        CONSTANT NUMBER := USERENV ('SESSIONID');
    gn_debug_id          CONSTANT NUMBER := 0;
    gn_request_id        CONSTANT NUMBER := fnd_global.conc_request_id;
    --gv_application    VARCHAR2(100)    := 'Direct Ship – WMS Ship Confirm Process';
    gn_created_by        CONSTANT NUMBER := fnd_global.user_id;
    gn_last_updated_by   CONSTANT NUMBER := fnd_global.user_id;
    gd_date              CONSTANT DATE := SYSDATE;

    gn_user_id           CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id          CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id            CONSTANT NUMBER := fnd_profile.VALUE ('ORG_ID');
    gn_resp_id           CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id      CONSTANT NUMBER := fnd_global.resp_appl_id;

    --Upload Procedure called by WebADI
    PROCEDURE batch_upload (p_inv_org_code IN VARCHAR2, p_container_number IN VARCHAR2, p_order_number IN NUMBER DEFAULT NULL, p_mile_stone_event IN VARCHAR2, p_attribute_num1 IN NUMBER DEFAULT NULL, p_attribute_num2 IN NUMBER DEFAULT NULL, p_attribute_chr1 IN VARCHAR2 DEFAULT NULL, p_attribute_chr2 IN VARCHAR2 DEFAULT NULL, p_attribute_date1 IN DATE DEFAULT NULL
                            , p_attribute_date2 IN DATE DEFAULT NULL);

    --Procedure called by concurrent program
    PROCEDURE import_pro (pv_errbuf OUT VARCHAR2, pv_retcode OUT NUMBER);

    --Email Procedure
    PROCEDURE email_output (p_request_id IN NUMBER);

    TYPE xxd_wms_email_output_type
        IS TABLE OF xxdo.xxd_wms_email_output_t%ROWTYPE
        INDEX BY BINARY_INTEGER;
END XXD_ONT_DS_UPD_MS_EVENT_PKG;
/
