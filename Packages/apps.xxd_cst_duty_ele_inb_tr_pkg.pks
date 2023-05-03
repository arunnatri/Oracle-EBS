--
-- XXD_CST_DUTY_ELE_INB_TR_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   FND_PROFILE (Package)
--   XXD_CST_DUTY_ELE_CAT_STG_T (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:19:44 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_CST_DUTY_ELE_INB_TR_PKG"
IS
      /****************************************************************************************************
 NAME           : XXD_CST_DUTY_ELE_INB_TR_PKG
 PACKAGE NAME   : Deckers TRO Inbound Duty Elements Upload

 REVISIONS:
 Date        Author             Version  Description
 ----------  ----------         -------  ------------------------------------------------------------
 13-AUG-2021 Damodara Gupta     1.0      Created this package using XXD_CST_DUTY_ELE_INB_TR_PKG
                                         to load the Duty/Cost Elements into the staging table,
                                         upload the Cost Elements into the XXDO_INVVAL_DUTY_COST
                                         staging table and process to ORACLE
*****************************************************************************************************/

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

    TYPE item_categories_tbl IS TABLE OF xxd_cst_duty_ele_cat_stg_t%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gt_item_cat_rec               item_categories_tbl;
    gn_cost_element_id            NUMBER;
    gn_process_flag               NUMBER := 1;
    gc_cost_type                  VARCHAR2 (150 BYTE) := 'AvgRates';
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

    PROCEDURE get_file_names (pv_directory_name IN VARCHAR2);

    PROCEDURE load_file_into_tbl_prc (pv_table IN VARCHAR2, pv_dir IN VARCHAR2 DEFAULT 'XXD_CST_DUTY_ELE_INB_DIR', pv_filename IN VARCHAR2, pv_ignore_headerlines IN INTEGER DEFAULT 1, pv_delimiter IN VARCHAR2 DEFAULT '|', pv_optional_enclosed IN VARCHAR2 DEFAULT '"'
                                      , pv_num_of_columns IN NUMBER);

    PROCEDURE validate_prc (pv_file_name IN VARCHAR2-- pv_duty_override IN VARCHAR2
                                                    );

    -- PROCEDURE insert_into_custom_table_prc (pv_duty_override IN VARCHAR2);
    PROCEDURE insert_into_custom_table_prc;

    PROCEDURE generate_exception_report_prc (pv_exc_file_name OUT VARCHAR2);

    PROCEDURE main_prc (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, -- pv_duty_override           IN VARCHAR2,
                                                                                 pv_send_mail IN VARCHAR2);

    PROCEDURE insert_into_interface_prc (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, pv_region IN VARCHAR2, pv_inv_org IN VARCHAR2, pv_style IN VARCHAR2, pv_color IN VARCHAR2, pv_reprocess IN VARCHAR2, pv_mode IN VARCHAR2, pv_send_mail IN VARCHAR2
                                         , pv_dis_sku IN VARCHAR2);

    -- PROCEDURE insert_into_invval_duty_cost_prc;

    -- PROCEDURE insert_cat_to_stg_prc (x_errbuf  OUT NOCOPY VARCHAR2,
    -- x_retcode OUT NOCOPY VARCHAR2);

    PROCEDURE cat_assignment_child_prc (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY NUMBER, pn_batch_number IN NUMBER);

    PROCEDURE inv_category_load_prc (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY NUMBER, pv_category_set_name IN VARCHAR2);

    PROCEDURE purge_xxd_cst_duty_ele_inb_prc (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, pv_num_days IN NUMBER);

    PROCEDURE purge_xxd_cst_duty_ele_upld_prc (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, pv_num_days IN NUMBER);

    PROCEDURE purge_xxd_cst_duty_ele_cat_prc (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, pv_num_days IN NUMBER);

    PROCEDURE purge_xxdo_invval_duty_cost_prc (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, pv_num_days IN NUMBER);
END XXD_CST_DUTY_ELE_INB_TR_PKG;
/
