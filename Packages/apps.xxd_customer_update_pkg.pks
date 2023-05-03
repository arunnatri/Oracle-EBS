--
-- XXD_CUSTOMER_UPDATE_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:19:51 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.xxd_customer_update_pkg
AS
    /*******************************************************************************
     * Program Name : XXD_CUSTOMER_UPDATE_PKG
     * Language     : PL/SQL
     * Description  : This package will update party, Customer, location, site,
     *                uses, contacts, account.
     *
     * History      :
     *
     * WHO                  WHAT              DESC                       WHEN
     * -------------- ---------------------------------------------- ---------------
     * BT Technology Team   1.0              Initial Version          27-May-2015
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
    gn_org_id                     NUMBER := fnd_global.org_id;

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
    gc_delta_status      CONSTANT VARCHAR2 (20) := 'DELTA';

    gc_extract_only      CONSTANT VARCHAR2 (20) := 'EXTRACT'; --'EXTRACT ONLY';
    gc_validate_only     CONSTANT VARCHAR2 (20) := 'VALIDATE'; -- 'VALIDATE ONLY';
    gc_load_only         CONSTANT VARCHAR2 (20) := 'LOAD';      --'LOAD ONLY';

    ge_api_exception              EXCEPTION;

    PROCEDURE main_prc (x_retcode OUT NUMBER, x_errbuf OUT VARCHAR2, p_process IN VARCHAR2
                        , p_debug_flag IN VARCHAR2);

    PROCEDURE log_records (p_debug VARCHAR2, p_message VARCHAR2);
END xxd_customer_update_pkg;
/
