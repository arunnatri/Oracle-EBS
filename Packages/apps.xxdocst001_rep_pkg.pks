--
-- XXDOCST001_REP_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   FND_PROFILE (Package)
--   XXD_INV_ITEM_CAT_STG_T (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:33 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.xxdocst001_rep_pkg
AS
    /******************************************************************************
          NAME: XXDOCST001_REP_PKG
          REP NAME:Item Cost Upload - Deckers

          REVISIONS:
          Ver        Date        Author                           Description
          ---------  ----------  ---------------       ------------------------------------
          1.0       05/15/2012     Shibu                 1. Created this package Item Cost Upload - Deckers
          1.1       11/27/2014  BT Technology Team         Addition of new procedures
                                                         1) insert_into_interface
                                                         2) insert_into_custom_table
                                                             (Invoke through seperate concurrent program)
                                                         3) purge_custom_table
                                                             (Invoke through seperate concurrent program)
                                                          4)custom_table_report
                                                          (Invoke through seperate concurrent program)
                                                          5) inv_category_load - (Tariff Code Category Assignment)
                                                            (Invoke through seperate concurrent program)
      1.2         06/10/2015                           Added debug parameter for Category programs
       ******************************************************************************/
    gc_validate_status   CONSTANT VARCHAR2 (20) := 'V';         --'VALIDATED';
    gc_error_status      CONSTANT VARCHAR2 (20) := 'E';             --'ERROR';
    gc_new_status        CONSTANT VARCHAR2 (20) := 'N';               --'NEW';
    gc_process_status    CONSTANT VARCHAR2 (20) := 'P';         --'PROCESSED';

    gn_user_id                    NUMBER := FND_GLOBAL.USER_ID;
    gn_login_id                   NUMBER := FND_GLOBAL.CONC_LOGIN_ID;
    gn_request_id                 NUMBER := FND_GLOBAL.CONC_REQUEST_ID;
    gn_parent_request_id          NUMBER := 0;
    gn_conc_request_id            NUMBER := 0;
    gn_org_id                     NUMBER := FND_PROFILE.VALUE ('ORG_ID');
    gc_debug_flag                 VARCHAR2 (10) := 'Y';

    gc_err_msg                    VARCHAR2 (4000) := NULL;
    gc_stg_tbl_process_flag       VARCHAR (20) := NULL;
    gc_stag_table_mssg            VARCHAR2 (200);
    gn_err_cnt                    NUMBER;

    gn_organization_id            NUMBER := NULL;
    gn_inventory_item_id          NUMBER := NULL;
    gn_category_id                NUMBER := NULL;
    gn_category_set_id            NUMBER := NULL;
    gn_inventory_item             VARCHAR2 (300);


    gd_sys_date                   DATE := SYSDATE;
    gn_setup_error_flag           NUMBER := 0; -- Flag to Store If any Setup error is there
    gn_record_error_flag          NUMBER := 0; -- Flag to store if any Record error is there


    TYPE item_categories_tbl IS TABLE OF XXD_INV_ITEM_CAT_STG_T%ROWTYPE
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

    /******************************************************************************
     NAME: XXDO.XXDOCST001_REP_PKG
       REP NAME:Item Cost Upload - Deckers

       REVISIONS:
       Ver        Date        Author                         Description
       ---------  ----------  ---------------         ------------------------------------
       1.0       05/15/2012     Shibu               1. Created this package Item Cost Upload - Deckers
       1.1       11/17/2014    BT Technology Team         Addition of new procedures
                                                      1) insert_into_interface
                                                      2) insert_into_custom_table
                                                          (Invoke through seperate concurrent program)
                                                      3) purge_custom_table
                                                          (Invoke through seperate concurrent program)
                                                       4)custom_table_report
                                                       (Invoke through seperate concurrent program)
                                                       5) inv_category_load - (Tariff Code Category Assignment)
                                                       (Invoke through seperate concurrent program)
    ******************************************************************************/
    PROCEDURE insert_into_interface (errbuff   OUT VARCHAR2,
                                     retcode   OUT VARCHAR2);

    /* Commenting this procedure as Purge Program is not required any more
   PROCEDURE purge_custom_table (errbuff OUT VARCHAR2, retcode OUT VARCHAR2); */

    PROCEDURE insert_into_custom_table (errbuff   OUT VARCHAR2,
                                        retcode   OUT VARCHAR2);

    PROCEDURE custom_table_report (errbuff OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id NUMBER, p_item_id NUMBER, p_style_color VARCHAR2, p_creation_date VARCHAR2
                                   , p_end_date VARCHAR2);

    PROCEDURE item_cost_insert (errbuf OUT VARCHAR2, retcode OUT VARCHAR2);

    FUNCTION get_item_org_id (p_item_number   VARCHAR2,
                              p_org           VARCHAR2,
                              p_col           VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_resource_rate (p_item_id         NUMBER,
                                p_org_id          NUMBER,
                                p_resource_code   VARCHAR2)
        RETURN NUMBER;

    PROCEDURE inv_category_load (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY NUMBER, p_category_set_name IN VARCHAR2
                                 , p_debug IN VARCHAR2);

    PROCEDURE cat_assignment_child_program (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY NUMBER, p_batch_number IN NUMBER
                                            , p_debug IN VARCHAR2);
END xxdocst001_rep_pkg;
/
