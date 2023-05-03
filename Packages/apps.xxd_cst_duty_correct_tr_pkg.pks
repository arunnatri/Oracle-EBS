--
-- XXD_CST_DUTY_CORRECT_TR_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   FND_PROFILE (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:19:43 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_CST_DUTY_CORRECT_TR_PKG"
AS
    /******************************************************************************************
    NAME           : XXD_CST_DUTY_CORRECT_TR_PKG
    REPORT NAME    : Deckers Average Cost Correction

    REVISIONS:
    Date            Author                  Version     Description
    ----------      ----------              -------     ---------------------------------------------------
    13-AUG-2021     Srinath Siricilla       1.0         Created this package using XXD_CST_DUTY_CORRECT_TR_PKG
                                                        to load the Corrective into the staging table and process them.
    *********************************************************************************************/

    -- Global constants
    -- Return Statuses
    --gn_user_id      CONSTANT NUMBER := fnd_global.user_id;
    --gn_request_id   CONSTANT NUMBER := fnd_global.conc_request_id;
    --gv_delimeter             VARCHAR2 (1) := '|';
    --gn_error        CONSTANT NUMBER := 2;
    --gn_warning      CONSTANT NUMBER := 1;

    --gn_login_id          CONSTANT NUMBER := fnd_global.login_id;
    --gn_org_id            CONSTANT NUMBER := fnd_profile.VALUE ('ORG_ID');
    --gn_resp_id           CONSTANT NUMBER := fnd_global.resp_id;
    --gn_resp_appl_id      CONSTANT NUMBER := fnd_global.resp_appl_id;
    --gv_ret_success       CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_success;
    --gv_ret_error         CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_error;
    --gv_ret_unexp_error   CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_unexp_error ;
    --gv_ret_warning       CONSTANT VARCHAR2 (1) := 'W';
    --gn_success           CONSTANT NUMBER := 0;
    --gn_limit_rec         CONSTANT NUMBER := 100;
    --gn_commit_rows       CONSTANT NUMBER := 1000;

    gc_validate_status   CONSTANT VARCHAR2 (20) := 'V';         --'VALIDATED';
    gc_error_status      CONSTANT VARCHAR2 (20) := 'E';             --'ERROR';
    gc_new_status        CONSTANT VARCHAR2 (20) := 'N';               --'NEW';
    gc_process_status    CONSTANT VARCHAR2 (20) := 'P';         --'PROCESSED';
    gn_error             CONSTANT NUMBER := 2;
    gn_warning           CONSTANT NUMBER := 1;
    gc_err_msg                    VARCHAR2 (4000) := NULL;
    gc_stg_tbl_process_flag       VARCHAR2 (20) := NULL;
    gc_stag_table_mssg            VARCHAR2 (200);
    gn_err_cnt                    NUMBER;

    gn_user_id           CONSTANT NUMBER := fnd_global.user_id;
    gn_request_id        CONSTANT NUMBER := fnd_global.conc_request_id;
    gn_parent_request_id          NUMBER := 0;
    gn_conc_request_id            NUMBER := 0;
    gc_debug_flag                 VARCHAR2 (10) := 'Y';


    gn_org_id                     NUMBER := FND_PROFILE.VALUE ('ORG_ID');
    gn_organization_id            NUMBER := NULL;
    gn_inventory_item_id          NUMBER := NULL;


    gv_delim_pipe                 VARCHAR2 (1) := '|';
    gv_delim_comma                VARCHAR2 (1) := ',';
    g_limit                       NUMBER := 50000;


    PROCEDURE main_prc (errbuf       OUT NOCOPY VARCHAR2,
                        retcode      OUT NOCOPY VARCHAR2);

    --                        pv_send_mail   IN            VARCHAR2);

    PROCEDURE write_log_prc (pv_msg IN VARCHAR2);

    PROCEDURE get_file_names (pv_directory_name IN VARCHAR2);

    PROCEDURE insert_into_staging_prc (pv_file_name IN VARCHAR2);


    PROCEDURE load_file_into_tbl_prc (pv_table IN VARCHAR2, pv_dir IN VARCHAR2 DEFAULT 'XXD_CST_DUTY_CORR_INB_DIR', pv_filename IN VARCHAR2, pv_ignore_headerlines IN INTEGER DEFAULT 1, pv_delimiter IN VARCHAR2 DEFAULT '|', pv_optional_enclosed IN VARCHAR2 DEFAULT '"'
                                      , pv_num_of_columns IN NUMBER);

    PROCEDURE copyfile_prc (pv_in_filename IN VARCHAR2, pv_out_filename IN VARCHAR2, pv_src_dir IN VARCHAR2
                            , pv_dest_dir IN VARCHAR2);

    PROCEDURE validate_prc (pv_file_name IN VARCHAR2);

    PROCEDURE validate_interface_prc (pv_file_name IN VARCHAR2);

    PROCEDURE load_interface_prc (pv_file_name IN VARCHAR2);

    PROCEDURE update_interface_status_prc (pv_file_name IN VARCHAR2);

    PROCEDURE get_cost_prc (pn_inventory_item_id IN NUMBER, pn_organization_id IN NUMBER, x_mat_cost OUT NUMBER
                            , x_mat_OH_cost OUT NUMBER, x_total_cost OUT NUMBER, x_error_msg OUT VARCHAR2);
--    PROCEDURE insert_into_custom_table_prc (pv_file_name IN VARCHAR2);

--    PROCEDURE generate_exception_report_prc (pv_exc_file_name OUT VARCHAR2);

END XXD_CST_DUTY_CORRECT_TR_PKG;
/
