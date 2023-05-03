--
-- XXD_INV_ITEM_ONHAND_QTY_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:21:26 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_INV_ITEM_ONHAND_QTY_PKG"
AS
    /*******************************************************************************
    * Program Name : XXD_CUSTOMER_CONV_PKG
    * Language     : PL/SQL
    * Description  : This package will load data in to party, location, site, uses, contacts, account.
    *
    * History      :
    *
    * WHO                   WHAT              Desc                             WHEN
    * -------------- ---------------------------------------------- ---------------
    * BT Technology Team    1.0                                             17-JUN-2014
    *******************************************************************************/
    gc_yesflag                          VARCHAR2 (1) := 'Y';
    gc_noflag                           VARCHAR2 (1) := 'N';
    gc_new                              VARCHAR2 (3) := 'N';
    gc_api_succ                         VARCHAR2 (1) := 'S';
    gc_api_error                        VARCHAR2 (10) := 'E';
    gc_insert_fail                      VARCHAR2 (1) := 'F';
    gc_processed                        VARCHAR2 (1) := 'P';
    gn_limit                            NUMBER := 10000;
    gn_retcode                          NUMBER;
    gn_success                          NUMBER := 0;
    gn_warning                          NUMBER := 1;
    gn_error                            NUMBER := 2;
    gd_sys_date                         DATE := SYSDATE;
    gn_conc_request_id                  NUMBER := fnd_global.conc_request_id;
    gn_user_id                          NUMBER := fnd_global.user_id;
    gn_login_id                         NUMBER := fnd_global.login_id;
    gn_parent_request_id                NUMBER;
    gn_request_id                       NUMBER := NULL;
    gn_org_id                           NUMBER := FND_GLOBAL.org_id;

    gc_code_pointer                     VARCHAR2 (250);
    gn_processcnt                       NUMBER;
    gn_successcnt                       NUMBER;
    gn_errorcnt                         NUMBER;
    gc_security_grp                     VARCHAR2 (20) := 'ORG';
    gc_no_flag                 CONSTANT VARCHAR2 (10) := 'N';
    gc_yes_flag                CONSTANT VARCHAR2 (10) := 'Y';
    gc_debug_flag                       VARCHAR2 (10);
    gc_program_shrt_name       CONSTANT VARCHAR2 (10) := 'POXPOPDOI';
    gc_appl_shrt_name          CONSTANT VARCHAR2 (10) := 'PO';
    gc_standard_type           CONSTANT VARCHAR2 (10) := 'STANDARD';
    gc_approved                CONSTANT VARCHAR2 (10) := 'APPROVED';
    gc_update_create           CONSTANT VARCHAR2 (2) := 'N';
    gc_rcv_prog_shrt_name      CONSTANT VARCHAR2 (10) := 'RVCTP';
    --   gc_appl_shrt_name        CONSTANT VARCHAR2(10)  := 'PO';
    gc_rvctp_mode              CONSTANT VARCHAR2 (10) := 'BATCH';


    gc_validate_status         CONSTANT VARCHAR2 (20) := 'VALIDATED';
    gc_error_status            CONSTANT VARCHAR2 (20) := 'ERROR';
    gc_new_status              CONSTANT VARCHAR2 (20) := 'NEW';
    gc_process_status          CONSTANT VARCHAR2 (20) := 'PROCESSED';
    gc_interfaced              CONSTANT VARCHAR2 (20) := 'INTERFACED';

    gc_extract_only            CONSTANT VARCHAR2 (20) := 'EXTRACT'; --'EXTRACT ONLY';
    gc_validate_only           CONSTANT VARCHAR2 (20) := 'VALIDATE'; -- 'VALIDATE ONLY';
    gc_load_only               CONSTANT VARCHAR2 (20) := 'LOAD'; --'LOAD ONLY';
    gc_load_po_only            CONSTANT VARCHAR2 (20) := 'LOAD PO'; --'LOAD PO';
    gc_load_recpt_only         CONSTANT VARCHAR2 (20) := 'LOAD RCV'; --'LOAD_REV';
    gc_load_lpn_only           CONSTANT VARCHAR2 (20) := 'LOAD LPN';
    gc_unpack_pack_container   CONSTANT VARCHAR2 (20) := 'PACK LPN';

    gn_suc_const               CONSTANT NUMBER := 0;
    gn_warn_const              CONSTANT NUMBER := 1;
    gn_err_const               CONSTANT NUMBER := 2;
    gn_lpn_status                       VARCHAR2 (2) := 'Y';

    ge_api_exception                    EXCEPTION;


    PROCEDURE main (x_retcode                OUT NUMBER,
                    x_errbuf                 OUT VARCHAR2,
                    p_process             IN     VARCHAR2,
                    p_debug_flag          IN     VARCHAR2,
                    p_no_of_process       IN     NUMBER,
                    p_operating_unit_id   IN     VARCHAR2,
                    p_inventory_org_id    IN     VARCHAR2,
                    P_TRANSACTION_DATE    IN     VARCHAR2);

    PROCEDURE inv_onhand_qty_child (
        errbuf                   OUT VARCHAR2,
        retcode                  OUT VARCHAR2,
        p_debug_flag          IN     VARCHAR2 DEFAULT 'N',
        p_action              IN     VARCHAR2,
        p_batch_id            IN     NUMBER,
        p_parent_request_id   IN     NUMBER,
        p_operating_unit_id   IN     VARCHAR2,
        p_inventory_org_id    IN     VARCHAR2);
END XXD_INV_ITEM_ONHAND_QTY_PKG;
/
