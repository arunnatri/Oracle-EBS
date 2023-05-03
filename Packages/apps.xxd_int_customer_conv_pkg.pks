--
-- XXD_INT_CUSTOMER_CONV_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:21:16 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXD_INT_CUSTOMER_CONV_PKG
AS
    /*******************************************************************************
       * Program Name : XXD_INT_CUSTOMER_CONV_PKG
       * Language     : PL/SQL
       * Description  : This package will convert party, Customer, location, site,
       *                uses, contacts, account.
       *
       * History      :
       *
       * WHO                  WHAT              DESC                       WHEN
       * -------------- ---------------------------------------------- ---------------
       * BT Technology Team   1.0              Initial Version          17-JUN-2014
       *******************************************************************************/
    gc_yesflag                    VARCHAR2 (1) := 'Y';
    gc_noflag                     VARCHAR2 (1) := 'N';
    gc_new                        VARCHAR2 (3) := 'N';
    gc_api_succ                   VARCHAR2 (1) := 'S';
    gc_api_error                  VARCHAR2 (10) := 'E';
    gc_insert_fail                VARCHAR2 (1) := 'F';
    gc_processed                  VARCHAR2 (1) := 'P';
    gn_limit                      NUMBER := 10000;
    gn_retcode                    NUMBER;
    gn_success                    NUMBER := 0;
    gn_warning                    NUMBER := 1;
    gn_error                      NUMBER := 2;
    gd_sys_date                   DATE := SYSDATE;
    gn_conc_request_id            NUMBER := fnd_global.conc_request_id;
    gn_user_id                    NUMBER := fnd_global.user_id;
    gn_login_id                   NUMBER := fnd_global.login_id;
    gn_parent_request_id          NUMBER;
    gn_request_id                 NUMBER := NULL;
    gn_org_id                     NUMBER := FND_GLOBAL.org_id;

    gc_code_pointer               VARCHAR2 (250);
    gn_processcnt                 NUMBER;
    gn_successcnt                 NUMBER;
    gn_errorcnt                   NUMBER;
    gc_created_by_module          VARCHAR2 (100) := 'TCA_V1_API';
    gc_security_grp               VARCHAR2 (20) := 'ORG';
    gc_no_flag           CONSTANT VARCHAR2 (10) := 'N';
    gc_yes_flag          CONSTANT VARCHAR2 (10) := 'Y';
    gc_debug_flag                 VARCHAR2 (10);


    gc_validate_status   CONSTANT VARCHAR2 (20) := 'VALIDATED';
    gc_error_status      CONSTANT VARCHAR2 (20) := 'ERROR';
    gc_new_status        CONSTANT VARCHAR2 (20) := 'NEW';
    gc_process_status    CONSTANT VARCHAR2 (20) := 'PROCESSED';
    gc_interfaced        CONSTANT VARCHAR2 (20) := 'INTERFACED';

    gc_extract_only      CONSTANT VARCHAR2 (20) := 'EXTRACT'; --'EXTRACT ONLY';
    gc_validate_only     CONSTANT VARCHAR2 (20) := 'VALIDATE'; -- 'VALIDATE ONLY';
    gc_load_only         CONSTANT VARCHAR2 (20) := 'LOAD';      --'LOAD ONLY';


    ge_api_exception              EXCEPTION;


    TYPE cust_mapping_rec_type IS RECORD
    (
        old_customer_id           NUMBER (15),
        new_customer_id           NUMBER (15),
        old_party_id              NUMBER (15),
        new_party_id              NUMBER (15),
        old_profile_id            NUMBER (15),
        new_profile_id            NUMBER (15),
        old_location_id           NUMBER (15),
        new_location_id           NUMBER (15),
        old_party_site_id         NUMBER (15),
        new_party_site_id         NUMBER (15),
        old_cust_site_id          NUMBER (15),
        new_cust_site_id          NUMBER (15),
        old_site_use_id           NUMBER (15),
        new_site_use_id           NUMBER (15),
        last_update_date          DATE,
        last_updated_by           NUMBER (15),
        creation_date             DATE,
        created_by                NUMBER (15),
        attribute_category        VARCHAR2 (30),
        attribute1                VARCHAR2 (150),
        attribute2                VARCHAR2 (150),
        attribute3                VARCHAR2 (150),
        attribute4                VARCHAR2 (150),
        attribute5                VARCHAR2 (150),
        attribute6                VARCHAR2 (150),
        attribute7                VARCHAR2 (150),
        attribute8                VARCHAR2 (150),
        attribute9                VARCHAR2 (150),
        attribute10               VARCHAR2 (150),
        request_id                NUMBER (15),
        program_application_id    NUMBER (15),
        program_id                NUMBER (15),
        program_update_date       DATE,
        org_id                    NUMBER (15),
        record_status             VARCHAR2 (30),
        error_message             VARCHAR2 (3000),
        inactive_site_useid       NUMBER
    );

    PROCEDURE Customer_main_proc (x_retcode OUT NUMBER, x_errbuf OUT VARCHAR2, p_process IN VARCHAR2
                                  , p_org_name IN VARCHAR2, p_debug_flag IN VARCHAR2, p_no_of_process IN NUMBER);

    PROCEDURE customer_child (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_debug_flag IN VARCHAR2 DEFAULT 'N', p_action IN VARCHAR2, p_org_name IN VARCHAR2, p_batch_id IN NUMBER
                              , p_parent_request_id IN NUMBER);


    PROCEDURE log_records (p_debug VARCHAR2, p_message VARCHAR2);
END XXD_INT_CUSTOMER_CONV_PKG;
/
