--
-- XXD_CST_OH_ELEMENTS_COPY_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   FND_PROFILE (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:19:47 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_CST_OH_ELEMENTS_COPY_PKG"
IS
      /******************************************************************************************
 NAME           : XXD_CST_OH_ELEMENTS_COPY_PKG
 PACKAGE NAME   : Deckers OH Elements Copy Program

 REVISIONS:
 Date        Author             Version  Description
 ----------  ----------         -------  ---------------------------------------------------
 04-JAN-2022 Damodara Gupta     1.0      Created this package using xxd_cst_oh_elements_copy_pkg
                                         to override the Duty/Cost Elements to ORACLE
 28-FEB-2022 Damodara Gupta     1.1      CCR0009885
*********************************************************************************************/

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
    g_invval_cnt                  NUMBER := 0;

    gn_user_id           CONSTANT NUMBER := fnd_global.user_id;
    gn_request_id        CONSTANT NUMBER := fnd_global.conc_request_id;
    gn_int_request_id             NUMBER := 0;
    gn_parent_request_id          NUMBER := 0;
    gn_conc_request_id            NUMBER := 0;
    gc_debug_flag                 VARCHAR2 (10) := 'Y';


    gn_org_id                     NUMBER := FND_PROFILE.VALUE ('ORG_ID');
    gn_organization_id            NUMBER := NULL;
    gn_inventory_item_id          NUMBER := NULL;
    gn_category_id                NUMBER := NULL;
    gn_category_set_id            NUMBER := NULL;
    gn_inventory_item             VARCHAR2 (300);


    gv_delim_pipe                 VARCHAR2 (1) := '|';
    gv_delim_comma                VARCHAR2 (1) := ',';
    g_limit                       NUMBER := 50000;

    gn_cost_element_id            NUMBER;
    gn_process_flag               NUMBER := 1;
    gc_cost_type                  VARCHAR2 (150) := 'AvgRates';
    gn_cost_type_id               NUMBER;
    gc_freight                    VARCHAR2 (100) := 'FREIGHT';
    gc_duty                       VARCHAR2 (100) := 'DUTY';
    gc_oh_duty                    VARCHAR2 (100) := 'OH DUTY';
    gc_oh_nonduty                 VARCHAR2 (100) := 'OH NONDUTY';
    gc_freight_du                 VARCHAR2 (100) := 'FREIGHT DU';

    gd_sys_date                   DATE := SYSDATE;
    gn_setup_error_flag           NUMBER := 0; -- Flag to Store If any Setup error is there
    gn_record_error_flag          NUMBER := 0; -- Flag to store if any Record error is there

    PROCEDURE write_log_prc (pv_msg IN VARCHAR2);

    PROCEDURE main_prc (errbuf              OUT NOCOPY VARCHAR2,
                        retcode             OUT NOCOPY VARCHAR2,
                        pv_mode          IN            VARCHAR2,
                        pv_dummy         IN            VARCHAR2,
                        pv_from_org      IN            NUMBER,
                        pv_to_org        IN            NUMBER,
                        pv_duty_vs       IN            VARCHAR2, -- Added CCR0009885
                        pv_dummy1        IN            VARCHAR2,
                        pv_display_sku   IN            VARCHAR2);

    PROCEDURE oh_ele_data_into_tbl_prc (pv_from_org   IN VARCHAR2,
                                        pv_duty_vs    IN VARCHAR2); -- Added CCR0009885

    PROCEDURE write_duty_ele_report_prc (pv_display_sku IN VARCHAR2);

    PROCEDURE insert_into_interface_prc (pv_from_org   IN VARCHAR2,
                                         pv_to_org     IN VARCHAR2);

    PROCEDURE duty_ele_rep_send_mail_prc (pv_rep_file_name IN VARCHAR2);
END xxd_cst_oh_elements_copy_pkg;
/
