--
-- XXD_GL_SBX_INT_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   FND_PROFILE (Package)
--   ZX_REGIMES_B (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:21:01 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_GL_SBX_INT_PKG"
AS
    /***********************************************************************************
      *$header     :                                                                   *
      *                                                                                *
      * AUTHORS    :  Srinath Siricilla                                                *
      *                                                                                *
      * PURPOSE    :  Deckers GL One Source Tax Creation                               *
      *                                                                                *
      * PARAMETERS :                                                                   *
      *                                                                                *
      * DATE       :  08-MAR-2021                                                      *
      *                                                                                *
      * Assumptions:                                                                   *
      *                                                                                *
      *                                                                                *
      * History                                                                        *
      * Vsn     Change Date  Changed By            Change Description                  *
      * -----   -----------  ------------------    ------------------------------------*
      * 1.0     08-MAR-2021  Srinath Siricilla     Initial Creation CCR0009103         *
      **********************************************************************************/


    gv_package_name    CONSTANT VARCHAR (30) := 'XXD_GL_SBX_INT_PKG';
    gv_time_stamp               VARCHAR2 (40)
                                    := TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS');
    gv_date                     VARCHAR2 (20)
                                    := TO_CHAR (SYSDATE, 'DD-MON-RRRR');
    gn_invoice_id      CONSTANT NUMBER := 1;
    gv_merch_role      CONSTANT VARCHAR2 (1) := 'B';
    gv_calc_dir        CONSTANT VARCHAR2 (1) := 'T';
    gv_audit_flag      CONSTANT VARCHAR2 (1) := 'N';
    gv_tax_flag        CONSTANT VARCHAR2 (1) := 'Y';
    gv_trx_type        CONSTANT VARCHAR2 (2) := 'GS';
    gv_journal         CONSTANT VARCHAR2 (20) := 'GL JOURNAL';
    gn_qty             CONSTANT NUMBER := 1;
    gv_uom             CONSTANT VARCHAR2 (20) := 'EA';
    gv_host            CONSTANT VARCHAR2 (30)
        := fnd_profile.VALUE ('SABRIX_HOSTED_IDENTIFIER') ;


    gv_file_time_stamp          VARCHAR2 (40)
                                    := TO_CHAR (SYSDATE, 'MMDDYY_HH24MISS');
    gn_user_id         CONSTANT NUMBER := fnd_global.user_id;
    gn_conc_request_id          NUMBER := fnd_global.conc_request_id;
    gv_default_email   CONSTANT VARCHAR2 (50)
        := fnd_profile.VALUE ('XXDO_B2B_DEFAULT_EMAIL_ID') ;
    gn_input_notif_req_id       NUMBER := NULL;
    gv_procedure                VARCHAR2 (100);
    gv_location                 VARCHAR2 (100);
    g_debug_level               VARCHAR2 (50)
        := fnd_profile.VALUE ('SABRIX_DEBUG_LEVEL');

    g_sabrix_regime             zx_regimes_b.tax_regime_code%TYPE;
    g_starting_date             zx_regimes_b.effective_from%TYPE;
    g_country_code              zx_regimes_b.country_code%TYPE;

    --   FUNCTION is_bal_seg_valid (p_company IN VARCHAR2, x_ret_msg OUT VARCHAR2)
    --      RETURN BOOLEAN;

    PROCEDURE insert_data (x_ret_msg OUT NOCOPY VARCHAR2, x_ret_code OUT NOCOPY VARCHAR2, pn_ledger_id IN NUMBER, pv_period_name IN VARCHAR2, pv_source IN VARCHAR2, pv_category IN VARCHAR2
                           , pv_journal_name IN VARCHAR2);

    PROCEDURE MAIN_PRC (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, pn_ledger_id IN VARCHAR2, pv_period_name IN VARCHAR2, pv_source IN VARCHAR2, pv_category IN VARCHAR2
                        , pv_journal_name IN VARCHAR2);

    PROCEDURE tax_call_prc (pn_batch_id IN NUMBER);

    PROCEDURE process_gl_data_prc (pn_batch_id IN NUMBER, x_ret_msg OUT NOCOPY VARCHAR2, x_ret_code OUT NOCOPY VARCHAR2);

    PROCEDURE print_out (pv_msg IN VARCHAR2, pv_time IN VARCHAR2 DEFAULT 'N');

    FUNCTION get_tax_code_new (i_batch_id IN NUMBER, i_invoice_id IN NUMBER, i_line_id IN NUMBER
                               , x_ret_msg OUT VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_tax_code (pv_tax_code IN VARCHAR2, x_tax_code OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_code_comb (p_ccid   IN     NUMBER,
                            x_seg1      OUT VARCHAR2,
                            x_seg2      OUT VARCHAR2,
                            x_seg3      OUT VARCHAR2,
                            x_seg4      OUT VARCHAR2,
                            x_seg5      OUT VARCHAR2,
                            x_seg6      OUT VARCHAR2,
                            x_seg7      OUT VARCHAR2,
                            x_seg8      OUT VARCHAR2--                           x_ret_msg      OUT VARCHAR2
                                                    )
        RETURN BOOLEAN;

    FUNCTION get_tax_ccid (pv_tax_code   IN     VARCHAR2,
                           pn_org_id     IN     NUMBER,
                           x_tax_ccid       OUT NUMBER)
        RETURN BOOLEAN;

    PROCEDURE update_prc (p_batch_id IN NUMBER);

    PROCEDURE debug_log_prc (p_batch_id    NUMBER,
                             p_procedure   VARCHAR2,
                             p_location    VARCHAR2,
                             p_message     VARCHAR2,
                             p_severity    VARCHAR2 DEFAULT 0);

    FUNCTION get_cntry_geo_fnc (pv_geo IN VARCHAR2)
        RETURN VARCHAR2;

    PROCEDURE display_output;
END XXD_GL_SBX_INT_PKG;
/
