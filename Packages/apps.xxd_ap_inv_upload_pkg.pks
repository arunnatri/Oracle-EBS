--
-- XXD_AP_INV_UPLOAD_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   FND_PROFILE (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:18:30 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_AP_INV_UPLOAD_PKG"
AS
    /******************************************************************************************
    NAME           : XXD_AP_INV_UPLOAD_PKG
    REPORT NAME    : Deckers AP Invoice Inbound from Pagero

    REVISIONS:
    Date            Author                  Version     Description
    ----------      ----------              -------     ---------------------------------------------------
    16-NOV-2021     Laltu Sah                 1.0         Created this package using XXD_AP_INV_UPLOAD_PKG to load the
                                                          AP Invoices into staging table from Pagero and process them.
    *********************************************************************************************/
    gn_user_id           CONSTANT NUMBER := fnd_global.user_id;
    gn_request_id        CONSTANT NUMBER := fnd_global.conc_request_id;
    gn_login_id          CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id            CONSTANT NUMBER := fnd_profile.VALUE ('ORG_ID');
    gn_resp_id           CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id      CONSTANT NUMBER := fnd_global.resp_appl_id;
    gc_inv_source                 VARCHAR2 (100) := 'SDI';
    gc_validate_status   CONSTANT VARCHAR2 (20) := 'V';         --'VALIDATED';
    gc_error_status      CONSTANT VARCHAR2 (20) := 'E';             --'ERROR';
    gc_new_status        CONSTANT VARCHAR2 (20) := 'N';               --'NEW';
    gc_process_status    CONSTANT VARCHAR2 (20) := 'P';         --'PROCESSED';
    gc_interfaced                 VARCHAR2 (1) := 'I';
    g_dist_list_name              VARCHAR2 (50) := 'XXD_AP_INV_EMAIL_LKP';
    gc_dd_reported                VARCHAR2 (100) := 'DD-REPORTED';
    g_unique_seq                  VARCHAR2 (100)
        := TO_CHAR (SYSTIMESTAMP, 'DD-MON-RRRR HH24:MI:SSSSS');
    gc_hold_name                  VARCHAR2 (1000) := 'SDI-HOLD';

    FUNCTION get_error_desc (p_rejection_code IN VARCHAR2)
        RETURN VARCHAR2;

    PROCEDURE main_prc (errbuf                  OUT NOCOPY VARCHAR2,
                        retcode                 OUT NOCOPY VARCHAR2,
                        p_org_id                           NUMBER,
                        p_reprocess                        VARCHAR2,
                        p_file_name                        VARCHAR2,
                        p_reprocess_period                 NUMBER);

    FUNCTION xxd_remove_junk_fnc (p_input IN VARCHAR2)
        RETURN VARCHAR2;

    PROCEDURE write_log_prc (pv_msg IN VARCHAR2);
END xxd_ap_inv_upload_pkg;
/
