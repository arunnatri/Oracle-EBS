--
-- XXD_GL_BALANCES_CONV_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:30 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.xxd_gl_balances_conv_pkg
-- +=======================================================================+
-- |                    Deckers BT Team                                    |
-- +=======================================================================+
-- |                                                                       |
-- | $Id: $                                                                |
-- |                                                                       |
-- | Description      : XXD_GL_BALANCES_CONV_PKG.sql                       |
-- |                                                                       |
-- |                                                                       |
-- | Purpose          : Script to create package spec for GL Balances      |
-- |                    Conversion                                         |
-- |                                                                       |
-- |Change Record:                                                         |
-- |===============                                                        |
-- |Version   Date        Author                Remarks                    |
-- |=======   ==========  =============        ============================|
-- |Draft 1a  19-Nov-2014 BT Technology Team  Draft Version                |
-- +=======================================================================+
AS
    ------------------------------------------------------------------------
    --Global Variable declaration
    ------------------------------------------------------------------------
    gc_complete_phase       CONSTANT VARCHAR2 (15) := 'COMPLETE';
    gc_completed_phase      CONSTANT VARCHAR2 (15) := 'COMPLETED';
    gc_complete_status      CONSTANT VARCHAR2 (15) := 'NORMAL';
    gc_dev_warn             CONSTANT VARCHAR2 (15) := 'WARNING';
    gc_dev_error            CONSTANT VARCHAR2 (15) := 'ERROR';
    gc_phase_value          CONSTANT VARCHAR2 (10) := 'Pending';
    gc_journal_import_pgm   CONSTANT VARCHAR2 (30) := 'GLLEZL';
    gc_source_name          CONSTANT VARCHAR2 (50) := 'BIC Payroll';
    gc_category_name1       CONSTANT VARCHAR2 (50) := 'WEEKLY PAYROLL';
    gc_category_name2       CONSTANT VARCHAR2 (50) := 'MONTHLY PAYROLL';
    gc_segment5             CONSTANT VARCHAR2 (50) := '000';
    gc_segment6             CONSTANT VARCHAR2 (50) := '00000';
    gc_segment7             CONSTANT VARCHAR2 (50) := '000';
    gc_segment8             CONSTANT VARCHAR2 (50) := '00000';
    gc_appl_short_name      CONSTANT VARCHAR2 (10) := 'SQLGL';
    gc_id_flex_code         CONSTANT VARCHAR2 (3) := 'GL#';
    gc_yes                  CONSTANT VARCHAR2 (1) := 'Y';
    gc_no                   CONSTANT VARCHAR2 (1) := 'N';
    gn_suc_const            CONSTANT NUMBER := 0;
    gn_warn_const           CONSTANT NUMBER := 1;
    gn_err_const            CONSTANT NUMBER := 2;
    gc_validate_status      CONSTANT VARCHAR2 (20) := 'VALIDATED';
    gc_error_status         CONSTANT VARCHAR2 (20) := 'ERROR';
    gc_new_status           CONSTANT VARCHAR2 (20) := 'NEW';
    gc_process_status       CONSTANT VARCHAR2 (20) := 'PROCESSED';
    gn_wait_time            CONSTANT NUMBER := 300;
    gn_interval             CONSTANT NUMBER := 10;
    gn_chart_of_accounts_id          NUMBER := NULL;
    gn_set_of_books_id               NUMBER := NULL;
    gn_ledger_id                     NUMBER := NULL;
    gn_user_id                       NUMBER := fnd_global.user_id;
    gn_request_id                    NUMBER := fnd_global.conc_request_id;
    gn_err_cnt                       NUMBER;
    gn_intf_record_id                NUMBER := NULL;
    gn_group_id                      NUMBER := NULL;
    gc_ledger_name                   VARCHAR (100) := NULL;
    gc_debug_flag                    VARCHAR2 (1) := 'N';
    gd_date                          DATE := SYSDATE;
    gn_conc_request_id               NUMBER;
    gc_extract_only         CONSTANT VARCHAR2 (20) := 'EXTRACT';
    --'EXTRACT ONLY';
    gc_validate_only        CONSTANT VARCHAR2 (20) := 'VALIDATE';
    -- 'VALIDATE ONLY';
    gc_load_only            CONSTANT VARCHAR2 (20) := 'LOAD';   --'LOAD ONLY';
    gn_org_id                        NUMBER := fnd_global.org_id;

    --  gc_debug_flag                                  VARCHAR2(5);
    --  gc_no_flag               CONSTANT VARCHAR2 (10)                    := 'N';
    --  gc_yes_flag              CONSTANT VARCHAR2 (10)                    := 'Y';
    PROCEDURE main (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, p_process_level IN VARCHAR2, p_no_of_process IN VARCHAR2, p_debug_flag IN VARCHAR2, p_summary_detail IN VARCHAR2
                    , p_period IN VARCHAR2, p_ledger_name IN VARCHAR2);

    PROCEDURE gl_balance_child (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_debug_flag IN VARCHAR2 DEFAULT 'N', p_action IN VARCHAR2, --p_org_name     IN VARCHAR2,
                                                                                                                                       p_batch_id IN NUMBER, p_parent_request_id IN NUMBER, p_summary_detail IN VARCHAR2, p_period IN VARCHAR2, p_group_id IN NUMBER
                                , p_ledger_name IN VARCHAR2);
END xxd_gl_balances_conv_pkg;
/
