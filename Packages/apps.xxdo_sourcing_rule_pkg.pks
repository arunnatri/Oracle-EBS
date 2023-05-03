--
-- XXDO_SOURCING_RULE_PKG  (Package) 
--
--  Dependencies: 
--   FND_API (Package)
--   FND_GLOBAL (Package)
--   MRP_SOURCING_RULE_PUB (Package)
--   MRP_SRC_ASSIGNMENT_PUB (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:17:49 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_SOURCING_RULE_PKG"
AS
    -- =============================================
    -- Deckers- Business Transformation
    -- Description:
    -- This package is used to create sourcing rule and sourcing assignment
    -- =============================================
    -------------------------------------------------
    -------------------------------------------------
    --Author:
    /******************************************************************************
    1.Components: main_conv_proc
       Purpose:  Main procedure which does validation and calls API wrapper procs if needed
                For initial conversion purpose,takes sourcing rule stg records in new/null status from stage
                Performs validation against each record
                Calls API wrappers to create the sourcing rule and assignment for validated records
                Updates API return status in stage table for initial conversion purpose


       Execution Method: As a script for initial converison purpose and through custom web ADI for user upload purpose

       Note:Initial package version designed primarily for conversion purpose. Needs modification for usage in custom web ADI

     2.Components: main_conv_proc
       Purpose:  Main procedure which does validation and calls API wrapper procs if needed
                 Parameters to mimic the web ADI fields
                Performs validation against each record
                Calls API wrappers to create the sourcing rule and assignment for validated records
                Returns status as out parameter


       Execution Method: As a script for initial converison purpose and through custom web ADI for user upload purpose

       Note:Initial package version designed primarily for conversion purpose. Needs modification for usage in custom web ADI

    3.Components: sourcing_rule_upload
       Purpose: Takes sourcing rule stg records in new/null status from stage
                Performs validation against each record
                Calls sourcing rule API to create the sourcing rule for validated records
                Updates API return status in stage table

       Execution Method:

       Note:

    4.Components: sourcing_rule_assignment
       Purpose: Takes stage table records for which the rules have been created successfully
                Calls sourcing rule API to create the sourcing rule assignment
                Updates status in stage tables

       Execution Method:

       Note:


       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0        3/6/2015             1.     Created this package.Initial package version designed primarily for conversion purpose.
                                              Needs modification for usage in custom web ADI
       2.0        5/18/2016  Sunera Tech     Changes to add additional parameter to reprocess error records;
                                              Identified by REPROCESS_PARAM

    ******************************************************************************/

    -- Define package global variables
    g_new_status                 CONSTANT VARCHAR2 (40) := 'NEW';
    g_valid_success_status       CONSTANT VARCHAR2 (40) := 'VALIDATION SUCCESS';
    g_valid_error_status         CONSTANT VARCHAR2 (40) := 'VALIDATION ERROR';
    g_valid_reprocess_status              VARCHAR2 (40) := 'VALIDATION ERROR';
    g_sr_success_status          CONSTANT VARCHAR2 (40)
                                              := 'RULE CREATION SUCCESS' ;
    g_sr_error_status            CONSTANT VARCHAR2 (40) := 'RULE CREATION ERROR';
    g_sr_update_success_status   CONSTANT VARCHAR2 (40)
                                              := 'RULE UPDATION SUCCESS' ;
    g_sr_update_error_status     CONSTANT VARCHAR2 (40)
                                              := 'RULE UPDATION ERROR' ;
    g_sr_update_success_plm      CONSTANT VARCHAR2 (40)
                                              := 'RULE UPDATION SUCCESS-PLM' ;
    g_sr_update_error_plm        CONSTANT VARCHAR2 (40)
                                              := 'RULE UPDATION ERROR-PLM' ;
    -- g_assign_delete_success_status   CONSTANT VARCHAR2 (40) := 'ASSIGNMENT DELETION SUCCESS';
    -- g_assign_delete_error_status     CONSTANT VARCHAR2 (40) := 'ASSIGNMENT DELETION ERROR';
    g_assign_success_status      CONSTANT VARCHAR2 (40)
                                              := 'ASSIGNMENT SUCCESS' ;
    g_assign_error_status        CONSTANT VARCHAR2 (40) := 'ASSIGNMENT ERROR';
    g_init_msg_list_flag         CONSTANT VARCHAR2 (10) := fnd_api.g_true; -- Standard API Parameter
    g_api_commit_flag            CONSTANT VARCHAR2 (10) := fnd_api.g_false; -- Standard API Parameter
    g_commit                     CONSTANT BOOLEAN := TRUE; -- Boolean to decide whether explicit commit is required
    g_commit_count               CONSTANT NUMBER := 200; -- Number of records after which program will commit if g_commit = TRUE
    g_run_id                              NUMBER;

    -- WHO_COLUMNS - Start
    g_num_user_id                         NUMBER := fnd_global.user_id;
    g_num_login_id                        NUMBER := fnd_global.login_id;
    g_num_request_id                      NUMBER
                                              := fnd_global.conc_request_id;

    -- WHO_COLUMNS - End

    -- Define Program Units
    -- Main procedure which does validation and calls API wrapper procs if needed
    -- Parameters to mimic the web ADI fields
    -- For initial conversion purpose, parameters are not to be used
    PROCEDURE main_conv_proc (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, extract_data_flag VARCHAR2, -- Valid values 'Y' and 'N'
                                                                                                     validation_only_mode VARCHAR2, -- Valid values 'Y' and 'N'
                                                                                                                                    ip_assignment_set_id NUMBER DEFAULT NULL, ip_db_link_name VARCHAR2 DEFAULT NULL
                              , reprocess_err_records VARCHAR2 DEFAULT 'N'); --REPROCESS_PARAM

    PROCEDURE main_webadi_proc;

    PROCEDURE printmessage (p_msgtoken IN VARCHAR2);

    PROCEDURE POPULATE_GLOBAL_RG_RECORDS; -----TO POPULATE RECORDS FOR 'GLOBAL' REGION

    PROCEDURE FEED_ORACLE_REGION (v_errbuf    OUT VARCHAR2,
                                  v_retcode   OUT NUMBER);


    PROCEDURE STAGING_WEBADI_UPLOAD (P_style VARCHAR2 DEFAULT NULL, P_color VARCHAR2 DEFAULT NULL, P_region VARCHAR2 DEFAULT NULL, P_start_date DATE DEFAULT NULL, P_end_date DATE DEFAULT NULL, P_supplier_name VARCHAR2 DEFAULT NULL
                                     , P_supplier_site_code VARCHAR2 DEFAULT NULL, P_RUN_ID NUMBER);

    FUNCTION GET_END_DATE (ip_style IN VARCHAR2, ip_color IN VARCHAR2, ip_region IN VARCHAR2
                           , P_START_DATE DATE)
        RETURN DATE;

    FUNCTION GET_START_VALIDATION (ip_style VARCHAR2, ip_color VARCHAR2, ip_region VARCHAR2
                                   , P_START_DATE DATE)
        RETURN BOOLEAN;

    FUNCTION GET_MAX_START_DATE (ip_style    VARCHAR2,
                                 ip_color    VARCHAR2,
                                 ip_region   VARCHAR2)
        RETURN DATE;

    FUNCTION RULE_SOURCE_EXISTS (p_sourcing_rule_id IN NUMBER, P_VENDOR_ID IN NUMBER, P_VENDOR_SITE_ID IN NUMBER
                                 , p_end_date IN DATE)
        RETURN BOOLEAN;

    -- Wrapper program which invokes standard API to create rule
    PROCEDURE sourcing_rule_upload (
        ip_sourcing_rule_rec           mrp_sourcing_rule_pub.sourcing_rule_rec_type,
        ip_sourcing_rule_val_rec       mrp_sourcing_rule_pub.sourcing_rule_val_rec_type,
        ip_receiving_org_tbl           mrp_sourcing_rule_pub.receiving_org_tbl_type,
        ip_receiving_org_val_tbl       mrp_sourcing_rule_pub.receiving_org_val_tbl_type,
        ip_shipping_org_tbl            mrp_sourcing_rule_pub.shipping_org_tbl_type,
        ip_shipping_org_val_tbl        mrp_sourcing_rule_pub.shipping_org_val_tbl_type,
        x_sourcing_rule_rec        OUT mrp_sourcing_rule_pub.sourcing_rule_rec_type,
        x_sourcing_rule_val_rec    OUT mrp_sourcing_rule_pub.sourcing_rule_val_rec_type,
        x_receiving_org_tbl        OUT mrp_sourcing_rule_pub.receiving_org_tbl_type,
        x_receiving_org_val_tbl    OUT mrp_sourcing_rule_pub.receiving_org_val_tbl_type,
        x_shipping_org_tbl         OUT mrp_sourcing_rule_pub.shipping_org_tbl_type,
        x_shipping_org_val_tbl     OUT mrp_sourcing_rule_pub.shipping_org_val_tbl_type,
        x_return_status            OUT VARCHAR2,
        x_api_message              OUT VARCHAR2);

    -- Wrapper program which invokes standard API to create assignment
    PROCEDURE sourcing_rule_assignment (ip_assignment_set_rec mrp_src_assignment_pub.assignment_set_rec_type, ip_assignment_set_val_rec mrp_src_assignment_pub.assignment_set_val_rec_type, ip_assignment_tbl mrp_src_assignment_pub.assignment_tbl_type, ip_assignment_val_tbl mrp_src_assignment_pub.assignment_val_tbl_type, x_assignment_set_rec OUT mrp_src_assignment_pub.assignment_set_rec_type, x_assignment_set_val_rec OUT mrp_src_assignment_pub.assignment_set_val_rec_type, x_assignment_tbl OUT mrp_src_assignment_pub.assignment_tbl_type, x_assignment_val_tbl OUT mrp_src_assignment_pub.assignment_val_tbl_type, x_return_status OUT VARCHAR2
                                        , x_api_message OUT VARCHAR2);

    -- Function to validate region for OU
    FUNCTION get_org_id_for_region (ip_region VARCHAR2)
        RETURN NUMBER;

    -- Function to validate region for assignment set
    FUNCTION get_assignment_id_for_region (ip_region VARCHAR2)
        RETURN NUMBER;


    -- Function to validate region for Inv Org
    FUNCTION inv_org_found_for_region (ip_region VARCHAR2)
        RETURN BOOLEAN;


    -- Function to get the inventory org for the region
    FUNCTION get_inv_org_id_for_region (ip_region       VARCHAR2,
                                        op_org_id   OUT NUMBER)
        RETURN BOOLEAN;


    -- Function to validate where the style / color is in Active or Planned status
    FUNCTION is_valid_style_color (ip_style        VARCHAR2,
                                   ip_color        VARCHAR2,
                                   ip_inv_org_id   NUMBER)
        RETURN BOOLEAN;



    -- Function to check if rule already exists
    FUNCTION rule_exists (ip_style    VARCHAR2,
                          ip_color    VARCHAR2,
                          ip_region   VARCHAR2)
        RETURN BOOLEAN;

    -- Function to validate supplier and site
    FUNCTION get_supplier_and_site_id (ip_supplier_name VARCHAR2, ip_site_code VARCHAR2, ip_org_id NUMBER
                                       , ip_start_date DATE, x_vendor_id OUT NUMBER, x_vendor_site_id OUT NUMBER)
        RETURN BOOLEAN;

    FUNCTION format_char (ip_text VARCHAR2)
        RETURN VARCHAR2;

    PROCEDURE print_message (ip_text VARCHAR2);

    -- Procedure to extract data from 12.0.6 into 12.2.3 stage table
    PROCEDURE extract_data (ip_assignment_set_id   NUMBER,
                            ip_db_link_name        VARCHAR2);

    --Start Modification by BT Technology Team v2.0 for CR 118 on 20-AUG-2015
    PROCEDURE send_email_report;
--End Modification by BT Technology Team v2.0 for CR 118 on 20-AUG-2015
END xxdo_sourcing_rule_pkg;
/
