--
-- XXD_ONT_DROP_SHIP_SO_CONV_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:23:09 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXD_ONT_DROP_SHIP_SO_CONV_PKG
/**********************************************************************************************************

    File Name    : XXD_ONT_DROP_SHIP_SO_CONV_PKG

    Created On   : 06-APR-2014

    Created By   : BT Technology Team

    Purpose      : This  package is to extract Open Drop shipment Sales Orders data from 12.0.6 EBS
                   and import into 12.2.3 EBS after validations.
   ***********************************************************************************************************
   Modification History:
   Version   SCN#        By                        Date                     Comments
  1.0              BT Technology Team          06-Apr-2014               Base Version
    ***********************************************************************************************************
   Parameters: 1.Mode
               2.Number of processes
               3.Debug Flag
               4. Operating Unit
   ***********************************************************************************************************/

AS
    gc_yesflag                       VARCHAR2 (1) := 'Y';
    gc_noflag                        VARCHAR2 (1) := 'N';
    gc_new                           VARCHAR2 (3) := 'N';
    gc_api_succ                      VARCHAR2 (1) := 'S';
    --   gc_api_error               VARCHAR2 (10) := 'E';
    gc_insert_fail                   VARCHAR2 (1) := 'F';
    gc_processed                     VARCHAR2 (1) := 'P';
    gn_limit                         NUMBER := 10000;
    gn_retcode                       NUMBER;
    gn_success                       NUMBER := 0;
    gn_warning                       NUMBER := 1;
    gn_error                         NUMBER := 2;
    gd_sys_date                      DATE := SYSDATE;
    gn_conc_request_id               NUMBER := fnd_global.conc_request_id;
    gn_user_id                       NUMBER := fnd_global.user_id;
    gn_login_id                      NUMBER := fnd_global.login_id;
    gn_parent_request_id             NUMBER;
    gn_request_id                    NUMBER := NULL;
    gn_org_id                        NUMBER := FND_GLOBAL.org_id;

    gn_processcnt                    NUMBER;
    gn_successcnt                    NUMBER;
    gn_errorcnt                      NUMBER;
    gc_created_by_module             VARCHAR2 (100) := 'PROCESS_ORDER';
    gc_security_grp                  VARCHAR2 (20) := 'ORG';
    gc_no_flag              CONSTANT VARCHAR2 (10) := 'N';
    gc_yes_flag             CONSTANT VARCHAR2 (10) := 'Y';
    gc_debug_flag                    VARCHAR2 (10);

    gc_code_pointer                  VARCHAR2 (250);
    gc_validate_status      CONSTANT VARCHAR2 (20) := 'V';
    gc_error_status         CONSTANT VARCHAR2 (20) := 'E';
    gc_new_status           CONSTANT VARCHAR2 (20) := 'N';
    gc_process_status       CONSTANT VARCHAR2 (20) := 'P';
    gc_interfaced           CONSTANT VARCHAR2 (20) := 'I';

    gc_extract_only         CONSTANT VARCHAR2 (20) := 'EXTRACT'; --'EXTRACT ONLY';
    gc_po_validate_only     CONSTANT VARCHAR2 (20) := 'PO_VALIDATE';
    gc_rcv_validate_only    CONSTANT VARCHAR2 (20) := 'RCV_VALIDATE'; --- 'VALIDATE ONLY';
    gc_pur_release          CONSTANT VARCHAR2 (20) := 'PUR RELEASE'; -- 'PURCHASE RELEASE ONLY';
    gc_load_only            CONSTANT VARCHAR2 (20) := 'LOAD';   --'LOAD ONLY';
    gc_req_import           CONSTANT VARCHAR2 (20) := 'REQ IMPORT'; --'REQUISITION IMPORT ONLY';
    gc_po_extract_only      CONSTANT VARCHAR2 (20) := 'PO_EXTRACT'; --'EXTRACT ONLY';
    gc_po_import_only       CONSTANT VARCHAR2 (20) := 'PO_IMPORT'; --'LOAD ONLY';
    gc_po_update_only       CONSTANT VARCHAR2 (20) := 'PO_UPDATE';
    gc_rcv_extract_only     CONSTANT VARCHAR2 (20) := 'RCV_EXTRACT';
    gc_rcv_load_only        CONSTANT VARCHAR2 (20) := 'RCV_LOAD';
    gc_rcv_import_only      CONSTANT VARCHAR2 (20) := 'RCV_IMPORT';


    GC_API_SUCCESS          CONSTANT VARCHAR2 (1) := 'S';
    GC_API_ERROR            CONSTANT VARCHAR2 (1) := 'E';
    GC_API_WARNING          CONSTANT VARCHAR2 (1) := 'W';
    GC_API_UNDEFINED        CONSTANT VARCHAR2 (1) := 'U';
    gc_transaction_t_type   CONSTANT VARCHAR2 (20) := 'RECEIVE';
    gc_processing_status_code        VARCHAR2 (25) := 'PENDING';
    gc_processing_mode_code          VARCHAR2 (25) := 'BATCH';
    gc_transaction_type              VARCHAR2 (25) := 'NEW';
    gc_destination_type_code         VARCHAR2 (25) := 'INVENTORY';



    ge_api_exception                 EXCEPTION;

    PROCEDURE main (x_retcode            OUT NUMBER,
                    x_errbuf             OUT VARCHAR2,
                    p_org_name        IN     VARCHAR2,
                    p_process         IN     VARCHAR2,
                    p_debug_flag      IN     VARCHAR2,
                    p_no_of_process   IN     NUMBER);

    PROCEDURE drop_ship_order_child (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_name IN VARCHAR2, p_debug_flag IN VARCHAR2 DEFAULT 'Y', p_action IN VARCHAR2, p_batch_number IN NUMBER
                                     , p_parent_request_id IN NUMBER);
END XXD_ONT_DROP_SHIP_SO_CONV_PKG;
/
