--
-- XXD_QP_PRICELISTCNV_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:25:21 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXD_QP_PRICELISTCNV_PKG
AS
    gd_sys_date                   DATE := SYSDATE;
    gn_conc_request_id            NUMBER := fnd_global.conc_request_id;
    gn_user_id                    NUMBER := fnd_global.user_id;
    gn_login_id                   NUMBER := fnd_global.login_id;
    gn_parent_request_id          NUMBER;
    gc_xxdo              CONSTANT VARCHAR2 (10) := 'XXDO';
    gc_qp                CONSTANT VARCHAR2 (10) := 'QP';
    gc_pll_std_imp_pgm   CONSTANT VARCHAR2 (20) := 'QPXVBLK';
    gc_no_flag           CONSTANT VARCHAR2 (10) := 'N';
    gc_yes_flag          CONSTANT VARCHAR2 (10) := 'Y';
    gn_batch_size                 NUMBER;
    gc_debug_flag                 VARCHAR2 (10);
    gc_debug_msg                  VARCHAR2 (4000);
    null_data                     EXCEPTION;
    gn_request_id                 NUMBER := NULL;
    gn_application_id             NUMBER := FND_GLOBAL.RESP_APPL_ID; --this stores application id
    gn_responsibility_id          NUMBER := FND_GLOBAL.RESP_ID; --this stores responsibility id
    gn_org_id                     NUMBER := FND_GLOBAL.org_id;
    gc_pr_list_type               VARCHAR2 (100) := 'LIST_TYPE_CODE';
    gc_pr_list_code               VARCHAR2 (100) := 'PRL';
    gc_pr_list_line_type          VARCHAR2 (100) := 'LIST_LINE_TYPE_CODE';
    gc_pr_list_line_code          VARCHAR2 (100) := 'PLL';

    gn_suc_const         CONSTANT NUMBER := 0;
    gn_warn_const        CONSTANT NUMBER := 1;
    gn_err_const         CONSTANT NUMBER := 2;

    gc_validate_status   CONSTANT VARCHAR2 (20) := 'VALIDATED';
    gc_error_status      CONSTANT VARCHAR2 (20) := 'ERROR';
    gc_new_status        CONSTANT VARCHAR2 (20) := 'NEW';
    gc_process_status    CONSTANT VARCHAR2 (20) := 'PROCESSED';
    gc_interfaced        CONSTANT VARCHAR2 (20) := 'INTERFACED';

    gc_extract_only      CONSTANT VARCHAR2 (20) := 'EXTRACT'; --'EXTRACT ONLY';
    gc_validate_only     CONSTANT VARCHAR2 (20) := 'VALIDATE'; -- 'VALIDATE ONLY';
    gc_load_only         CONSTANT VARCHAR2 (20) := 'LOAD';      --'LOAD ONLY';

    PROCEDURE pricelist_main (
        errbuf           OUT NOCOPY VARCHAR2,
        retcode          OUT NOCOPY NUMBER,
        p_action      IN            VARCHAR2,
        p_batch_cnt   IN            NUMBER,
        -- p_batch_size     IN        NUMBER,
        p_debug       IN            VARCHAR2 DEFAULT NULL);

    PROCEDURE pricelist_child (errbuf                   OUT VARCHAR2,
                               retcode                  OUT VARCHAR2,
                               p_debug_flag          IN     VARCHAR2 DEFAULT 'N',
                               p_action              IN     VARCHAR2,
                               p_batch_id            IN     NUMBER,
                               p_parent_request_id   IN     NUMBER);
END XXD_QP_PRICELISTCNV_PKG;
/
