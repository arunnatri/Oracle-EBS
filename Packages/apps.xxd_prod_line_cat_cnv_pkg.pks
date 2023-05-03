--
-- XXD_PROD_LINE_CAT_CNV_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   FND_PROFILE (Package)
--   XXD_INV_PROD_LINE_CAT_STG_T (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:25:15 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXD_PROD_LINE_CAT_CNV_PKG
AS
    -- +==============================================================================+
    -- +                        Oracle 12i                                            +
    -- +==============================================================================+
    -- |                                                                              |
    -- |Object Name :   XXD_PROD_LINE_CAT_CNV_PKG                                    |
    -- |Description   : The package  is defined to assign the                        |
    -- |                default production line category to all the items in R12      |
    -- |                                                           |
    -- |                                                                              |
    -- |Usage:                                                                        |
    -- |                                                                              |
    -- |                                                                              |
    -- |                                                                              |
    -- |Change Record:                                                                |
    -- |===============                                                               |
    -- |Version   Date             Author             Remarks                              |
    -- |=======   ==========  ===================   ============================      |
    -- |1.0       26-MAY-2015  BT Technology Team     Initial draft version           |
    -- +==============================================================================+

    gc_source_table_name   CONSTANT VARCHAR2 (50)
                                        := 'XXD_INV_PROD_LINE_CAT_STG_T' ;
    gc_table_name          CONSTANT VARCHAR2 (50)
                                        := 'XXD_INV_PROD_LINE_CAT_STG_T' ;
    gc_appl_short_name     CONSTANT VARCHAR2 (10) := 'INV';
    gc_yes                 CONSTANT VARCHAR2 (1) := 'Y';
    gc_no                  CONSTANT VARCHAR2 (1) := 'N';

    gc_validate_status     CONSTANT VARCHAR2 (20) := 'V';       --'VALIDATED';
    gc_error_status        CONSTANT VARCHAR2 (20) := 'E';           --'ERROR';
    gc_new_status          CONSTANT VARCHAR2 (20) := 'N';             --'NEW';
    gc_process_status      CONSTANT VARCHAR2 (20) := 'P';       --'PROCESSED';

    gn_user_id                      NUMBER := FND_GLOBAL.USER_ID;
    gn_login_id                     NUMBER := FND_GLOBAL.CONC_LOGIN_ID;
    gn_request_id                   NUMBER := FND_GLOBAL.CONC_REQUEST_ID;
    gn_parent_request_id            NUMBER := 0;
    gn_conc_request_id              NUMBER := 0;
    gn_org_id                       NUMBER := FND_PROFILE.VALUE ('ORG_ID');
    gc_debug_flag                   VARCHAR2 (10) := 'N';

    gc_err_msg                      VARCHAR2 (4000) := NULL;
    gc_stg_tbl_process_flag         VARCHAR (20) := NULL;
    gc_stag_table_mssg              VARCHAR2 (200);
    gn_err_cnt                      NUMBER;

    gn_organization_id              NUMBER := NULL;
    gn_inventory_item_id            NUMBER := NULL;
    gn_category_id                  NUMBER := NULL;
    gn_category_set_id              NUMBER := NULL;
    gn_inventory_item               VARCHAR2 (300);


    gc_extract_only        CONSTANT VARCHAR2 (20) := 'EXTRACT'; --'EXTRACT ONLY';
    gc_validate_only       CONSTANT VARCHAR2 (20) := 'VALIDATE'; -- 'VALIDATE ONLY';
    gc_load_only           CONSTANT VARCHAR2 (20) := 'LOAD';    --'LOAD ONLY';

    gd_sys_date                     DATE := SYSDATE;
    gn_setup_error_flag             NUMBER := 0; -- Flag to Store If any Setup error is there
    gn_record_error_flag            NUMBER := 0; -- Flag to store if any Record error is there

    --  gn_value_error_flag             NUMBER := 0;

    ---Define the Global cursors


    TYPE item_categories_tbl IS TABLE OF XXD_INV_PROD_LINE_CAT_STG_T%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gt_item_cat_rec                 item_categories_tbl;

    /*********************************************************************************************
    *                                                                                            *
    * Function  Name       :  inv_category_main                                                  *
    *                                                                                            *
    * Description          :                                                                     *
    *                                                                                            *
    *                                                                                            *
    *                                                                                            *
    * Change History                                                                             *
    * -----------------                                                                          *
    * Version       Date            Author                 Description                           *
    * -------       ----------      -----------------      ---------------------------           *
    * 1.0       26-MAY-2015  BT Technology Team     Initial draft version                        *
    *                                                                                            *
    **********************************************************************************************/

    PROCEDURE inv_category_child (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_debug_flag IN VARCHAR2 DEFAULT 'N'
                                  , p_action IN VARCHAR2, p_batch_number IN NUMBER, p_parent_request_id IN NUMBER);

    PROCEDURE inv_category_main (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY NUMBER, p_Process IN VARCHAR2
                                 , p_batch_size IN NUMBER, p_debug IN VARCHAR2, p_inv_org IN NUMBER);
END XXD_PROD_LINE_CAT_CNV_PKG;
/
