--
-- XXD_ONT_OPEN_SO_CONV_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:23:35 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.xxd_ont_open_so_conv_pkg
/**********************************************************************************************************

    File Name    : XXD_ONT_SALES_ORDER_CONV_PKG

    Created On   : 13-JUN-2014

    Created By   : BT Technology Team

    Purpose      : This  package is to extract Open Sales Orders data from 12.0.6 EBS
                   and import into 12.2.3 EBS after validations.
   ***********************************************************************************************************
   Modification History:
   Version   SCN#        By                        Date                     Comments
  1.0              BT Technology Team          13-Jun-2014               Base Version
  1.1              BT Technology Team          14-Aug-2014               Added Validations
   ***********************************************************************************************************
   Parameters: 1.Mode
               2.Batch Size
               3.Debug Flag
   ***********************************************************************************************************/

AS
    gc_yesflag                    VARCHAR2 (1) := 'Y';
    gc_noflag                     VARCHAR2 (1) := 'N';
    gc_new                        VARCHAR2 (3) := 'N';
    gc_api_succ                   VARCHAR2 (1) := 'S';
    --   gc_api_error               VARCHAR2 (10) := 'E';
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
    gc_created_by_module          VARCHAR2 (100) := 'PROCESS_ORDER';
    gc_security_grp               VARCHAR2 (20) := 'ORG';
    gc_no_flag           CONSTANT VARCHAR2 (10) := 'N';
    gc_yes_flag          CONSTANT VARCHAR2 (10) := 'Y';
    gc_debug_flag                 VARCHAR2 (10);

    gc_validate_status   CONSTANT VARCHAR2 (20) := 'V';
    gc_error_status      CONSTANT VARCHAR2 (20) := 'E';
    gc_new_status        CONSTANT VARCHAR2 (20) := 'N';
    gc_process_status    CONSTANT VARCHAR2 (20) := 'P';
    gc_interfaced        CONSTANT VARCHAR2 (20) := 'I';

    gc_extract_only      CONSTANT VARCHAR2 (20) := 'EXTRACT'; --'EXTRACT ONLY';
    gc_validate_only     CONSTANT VARCHAR2 (20) := 'VALIDATE'; -- 'VALIDATE ONLY';
    gc_load_only         CONSTANT VARCHAR2 (20) := 'LOAD';      --'LOAD ONLY';

    gc_api_success       CONSTANT VARCHAR2 (1) := 'S';
    gc_api_error         CONSTANT VARCHAR2 (1) := 'E';
    gc_api_warning       CONSTANT VARCHAR2 (1) := 'W';
    gc_api_undefined     CONSTANT VARCHAR2 (1) := 'U';

    ge_api_exception              EXCEPTION;

    PROCEDURE main (x_retcode             OUT NUMBER,
                    x_errbuf              OUT VARCHAR2,
                    p_org_name         IN     VARCHAR2,
                    p_org_type         IN     VARCHAR2,
                    p_process          IN     VARCHAR2,
                    p_customer_type    IN     VARCHAR2,
                    p_debug_flag       IN     VARCHAR2,
                    p_no_of_process    IN     NUMBER,
                    p_order_ret_type   IN     VARCHAR2);

    PROCEDURE sales_order_child (errbuf                   OUT VARCHAR2,
                                 retcode                  OUT VARCHAR2,
                                 p_org_name            IN     VARCHAR2,
                                 p_debug_flag          IN     VARCHAR2 DEFAULT 'N',
                                 p_action              IN     VARCHAR2,
                                 p_batch_number        IN     NUMBER,
                                 p_customer_type       IN     VARCHAR2,
                                 p_parent_request_id   IN     NUMBER);
END xxd_ont_open_so_conv_pkg;
/
