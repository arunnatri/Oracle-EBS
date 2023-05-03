--
-- XXD_INV_CATEGORY_CNV_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   FND_PROFILE (Package)
--   STANDARD (Package)
--   XXD_PLM_ATTR_STG_T (Table)
--
/* Formatted on 4/26/2023 4:21:19 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_INV_CATEGORY_CNV_PKG"
AS
    -- +==============================================================================+
    -- +                                                            +
    -- +==============================================================================+
    -- |                                                                              |
    -- |CVS ID:   1.1                                                                 |
    -- |Name: BT Technology team                                                      |
    -- |Creation Date: 12-Dec-2014                                                    |
    -- |Application Name: Business Online                                             |
    -- |Source File Name: XXD_INV_CATEGORY_CNV_PKG.pks                             |
    -- |                                                                              |
    -- |Object Name :   XXD_INV_CATEGORY_CNV_PKG                                      |
    -- |Description   : The package  is defined to convert the                        |
    -- |                Topps INV Item Categories Creation and Assignment             |
    -- |                Conversion to R12                                             |
    -- |                                                                              |
    -- |Usage:                                                                        |
    -- |                                                                              |
    -- |                                                                              |
    -- |Change Record:                                                                |
    -- |===============                                                               |
    -- |Version   Date             Author             Remarks                              |
    -- |=======   ==========  ===================   ============================      |
    -- |1.0       12-Dec-2014  BT Technology team                       Initial draft version           |
    -- +==============================================================================+

    gc_interface_id        CONSTANT VARCHAR2 (50) := 'XXDINVCATEGORYCNV';
    gc_program_name        CONSTANT VARCHAR2 (150)
        := 'Deckers Item Categories Creation and Assignment Program' ;
    gc_prog_source         CONSTANT VARCHAR2 (50) := 'XXDINVCATEGORYCNV';
    gc_source_table_name   CONSTANT VARCHAR2 (50)
                                        := 'XXD_CONV.XXD_PLM_ATTR_STG_T' ;
    gc_table_name          CONSTANT VARCHAR2 (50)
                                        := 'XXD_CONV.XXD_PLM_ATTR_STG_T' ;
    gc_appl_short_name     CONSTANT VARCHAR2 (10) := 'INV';
    gc_yes                 CONSTANT VARCHAR2 (1) := 'Y';
    gc_no                  CONSTANT VARCHAR2 (1) := 'N';

    gc_validate_status     CONSTANT VARCHAR2 (20) := 'V';       --'VALIDATED';
    gc_error_status        CONSTANT VARCHAR2 (20) := 'E';           --'ERROR';
    gc_new_status          CONSTANT VARCHAR2 (20) := 'N';             --'NEW';
    gc_process_status      CONSTANT VARCHAR2 (20) := 'S';       --'PROCESSED';

    gn_user_id                      NUMBER := FND_GLOBAL.USER_ID;
    gn_login_id                     NUMBER := FND_GLOBAL.CONC_LOGIN_ID;
    gn_request_id                   NUMBER := FND_GLOBAL.CONC_REQUEST_ID;
    gn_parent_request_id            NUMBER := 0;
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
    gn_category_set_name            VARCHAR2 (300);


    gd_date                         DATE := SYSDATE;
    gn_setup_error_flag             NUMBER := 0; -- Flag to Store If any Setup error is there
    gn_record_error_flag            NUMBER := 0; -- Flag to store if any Record error is there

    --  gn_value_error_flag             NUMBER := 0;

    ---Define the Global cursors

    --   TYPE gt_err_rec IS TABLE OF XXTOP_COMMON_ERRORS_PKG.custom_error_rec_type
    --        INDEX BY BINARY_INTEGER;
    --
    --   gt_err_tbl             gt_err_rec;

    TYPE item_categories_tbl IS TABLE OF XXD_CONV.XXD_PLM_ATTR_STG_T%ROWTYPE
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
    * Draft1a      04-APR-2011      BT Technology team    Initial creation                       *
    *                                                                                            *
    **********************************************************************************************/

    /*PROCEDURE inv_category_child (x_errbuf             OUT NOCOPY      VARCHAR2
                                   ,x_retcode            OUT NOCOPY      NUMBER
                                   ,p_candidate_set       IN             VARCHAR2
                                   ,p_batch_id            IN             NUMBER
                                   ,p_parent_request_id   IN             NUMBER
                                   ,p_debug               IN             VARCHAR2 DEFAULT NULL
                                   ,p_create_cat_only IN             VARCHAR2
       );*/

    PROCEDURE inv_category_assign (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY NUMBER, p_batch_no IN NUMBER
                                   , p_debug IN VARCHAR2);



    PROCEDURE inv_category_main (errbuf               OUT NOCOPY VARCHAR2,
                                 retcode              OUT NOCOPY NUMBER,
                                 p_process         IN            VARCHAR2,
                                 --p_batch_size      IN             NUMBER,
                                 p_no_of_process   IN            NUMBER,
                                 p_debug           IN            VARCHAR2);

    PROCEDURE inv_category_create (x_error OUT VARCHAR2, x_ret OUT VARCHAR2, p_batch_no IN NUMBER
                                   , p_debug IN VARCHAR2);

    PROCEDURE inv_category_validation (x_error OUT VARCHAR2, x_ret OUT VARCHAR2, p_batch_no IN NUMBER
                                       , p_debug IN VARCHAR2);
END XXD_INV_CATEGORY_CNV_PKG;
/
