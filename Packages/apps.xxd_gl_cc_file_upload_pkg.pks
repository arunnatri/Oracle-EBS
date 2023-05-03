--
-- XXD_GL_CC_FILE_UPLOAD_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   FND_PROFILE (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:33 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_GL_CC_FILE_UPLOAD_PKG"
AS
    /****************************************************************************************
      * Package         : XXD_GL_CC_FILE_UPLOAD_PKG
      * Description     : This package is for Code combination creation through file upload
      * Notes           : Enable\Disable\New Creation of Code combinations
      * Modification    :
      *-------------------------------------------------------------------------------------
      * Date         Version#      Name                       Description
      *-------------------------------------------------------------------------------------
      * 05-May-2022  1.0           Aravind Kannuri            Initial Version for CCR0009744
      *
      ***************************************************************************************/
    --Global Parameters
    gn_request_id                 NUMBER := fnd_global.conc_request_id;
    gn_org_id                     NUMBER := fnd_profile.VALUE ('ORG_ID');
    gd_date                       DATE := SYSDATE;

    gn_user_id                    NUMBER := fnd_global.user_id;
    gn_resp_id                    NUMBER := fnd_global.resp_id;
    gn_resp_appl_id               NUMBER := fnd_global.resp_appl_id;

    gn_login_id                   NUMBER := fnd_global.login_id;
    gn_created_by                 NUMBER := fnd_global.user_id;
    gn_last_updated_by            NUMBER := fnd_global.user_id;

    gn_success           CONSTANT NUMBER := 0;
    gn_warning           CONSTANT NUMBER := 1;
    gn_error             CONSTANT NUMBER := 2;

    gc_validate_status   CONSTANT VARCHAR2 (20) := 'V';         --'VALIDATED';
    gc_error_status      CONSTANT VARCHAR2 (20) := 'E';             --'ERROR';
    gc_new_status        CONSTANT VARCHAR2 (20) := 'N';               --'NEW';
    gc_process_status    CONSTANT VARCHAR2 (20) := 'S'; --'SUCCESSFULLY PROCESSED';
    g_time_statmp                 VARCHAR2 (100)
        := TO_CHAR (SYSTIMESTAMP, 'DD-MON-RRRR HH24:MI:SSSSS');

    PROCEDURE main (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY NUMBER, p_mode IN VARCHAR2
                    , p_cc_hide_dummy IN VARCHAR2, p_preserved IN VARCHAR2);
--PROCEDURE get_file_names (pv_directory_name IN VARCHAR2);

END XXD_GL_CC_FILE_UPLOAD_PKG;
/
