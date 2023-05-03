--
-- XXD_GL_CONCUR_INBOUND_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:34 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_GL_CONCUR_INBOUND_PKG"
AS
    /***********************************************************************************
      *$header     :                                                                   *
      *                                                                                *
      * AUTHORS    :  Srinath Siricilla                                                *
      *                                                                                *
      * PURPOSE    :  GL Accruals Concur Inbound process                               *
      *                                                                                *
      * PARAMETERS :                                                                   *
      *                                                                                *
      * DATE       :  02-AUG-2018                                                      *
      *                                                                                *
      * Assumptions:                                                                   *
      *                                                                                *
      *                                                                                *
      * History                                                                        *
      * Vsn     Change Date  Changed By            Change Description                  *
      * -----   -----------  ------------------    ------------------------------------*
      * 1.0     02-AUG-2018  Srinath Siricilla     Initial Creation CCR0007443         *
      * 1.1     13-MAY-2019  Srinath Siricilla     CCR0007989                          *
      * 1.2     19-NOV-2019  Srinath Siricilla     CCR0008320                          *
      * 2.0     24-DEC-2021  Srinath Siricilla     CCR0009228                          *
      *********************************************************************************/
    PROCEDURE INSERT_STAGING (x_ret_code        OUT NOCOPY VARCHAR2,
                              x_ret_msg         OUT NOCOPY VARCHAR2,
                              p_source       IN            VARCHAR2,
                              p_category     IN            VARCHAR2,
                              --p_gl_date     IN   VARCHAR2,
                              p_bal_seg      IN            VARCHAR2,
                              p_as_of_date   IN            VARCHAR2,
                              p_report_id    IN            VARCHAR2,
                              p_currency     IN            VARCHAR2);

    -- Added as per change 1.2

    PROCEDURE update_staging (x_ret_code OUT NOCOPY VARCHAR2, x_ret_msg OUT NOCOPY VARCHAR2, p_source IN VARCHAR2, p_category IN VARCHAR2, p_bal_seg IN VARCHAR2, p_as_of_date IN VARCHAR2
                              , p_report_id IN VARCHAR2, p_currency IN VARCHAR2, p_reprocess IN VARCHAR2);

    -- End of Change

    --  PROCEDURE MAIN;
    PROCEDURE MAIN (x_retcode OUT NOCOPY VARCHAR2, x_errbuf OUT NOCOPY VARCHAR2, p_source IN VARCHAR2, p_category IN VARCHAR2, p_gl_date IN VARCHAR2, p_reprocess IN VARCHAR2, p_bal_seg IN VARCHAR2, p_as_of_date IN VARCHAR2, p_report_id IN VARCHAR2, p_currency IN VARCHAR2, p_dist_list_name IN VARCHAR2, p_provided_gl_date IN VARCHAR2
                    ,                        -- Added New parameter as per 1.2
                      pn_purge_days IN NUMBER);     -- Added as per CCR0009228

    PROCEDURE email_out (p_dist_list_name IN VARCHAR2, x_ret_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2);

    /*PROCEDURE check_data(x_ret_code         OUT VARCHAR2
                         ,x_ret_msg          OUT VARCHAR2);*/

    FUNCTION is_gl_date_valid (p_gl_date   IN     DATE,
                               p_org_id    IN     NUMBER,
                               x_ret_msg      OUT VARCHAR2)
        RETURN DATE;

    FUNCTION get_ledger (p_seg_val IN VARCHAR2, x_ledger_id OUT NUMBER, x_ledger_name OUT VARCHAR2
                         , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_period_name (p_ledger_id IN NUMBER, p_gl_date IN VARCHAR2, x_period_name OUT VARCHAR2
                              , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_rev_period_name (p_ledger_id     IN     NUMBER,
                                  p_gl_date       IN     VARCHAR2,
                                  x_period_name      OUT VARCHAR2,
                                  x_date             OUT VARCHAR2 --- Added as part of 1.1
                                                                 ,
                                  x_ret_msg          OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_bal_seg_valid (p_company IN VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_code_comb (p_code_comb IN VARCHAR2, x_code_comb OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_ledger_curr (p_ledger_id IN NUMBER, x_ledger_curr OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_flag_valid (p_flag      IN     VARCHAR2,
                            x_flag         OUT VARCHAR2,
                            x_ret_msg      OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_curr_code_valid (p_curr_code   IN     VARCHAR2,
                                 x_ret_msg        OUT VARCHAR2)
        RETURN BOOLEAN;

    PROCEDURE validate_staging (x_ret_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2, p_source IN VARCHAR2, p_category IN VARCHAR2, p_gl_date IN DATE, p_reprocess IN VARCHAR2, p_bal_seg IN VARCHAR2 --                            p_as_of_date   IN   DATE,
                                                                                                                                                                                                , p_as_of_date IN VARCHAR2, p_report_id IN VARCHAR2
                                , p_currency IN VARCHAR2);

    FUNCTION is_seg_valid (p_seg IN VARCHAR2, p_flex_type IN VARCHAR2, p_seg_type IN VARCHAR2
                           , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    -- Start of Change 1.2

    FUNCTION get_cost_center_begin_value (p_cost_center_seg IN VARCHAR2, x_upd_nat_account OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    -- End of Change 1.2

    FUNCTION get_user_je_source (p_source    IN     VARCHAR2,
                                 x_ret_msg      OUT VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_user_je_category (p_category   IN     VARCHAR2,
                                   x_ret_msg       OUT VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION check_rate_exists (p_conv_date IN VARCHAR2, p_from_curr IN VARCHAR2, p_to_curr IN VARCHAR2
                                , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_code_comb_valid (p_seg1 IN VARCHAR2, p_seg2 IN VARCHAR2, p_seg3 IN VARCHAR2, p_seg4 IN VARCHAR2, p_seg5 IN VARCHAR2, p_seg6 IN VARCHAR2, p_seg7 IN VARCHAR2, p_seg8 IN VARCHAR2, x_ccid OUT NUMBER
                                 , x_cc OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    PROCEDURE load_interface (x_ret_code   OUT VARCHAR2,
                              x_ret_msg    OUT VARCHAR2);

    PROCEDURE Update_acc_data (x_ret_code OUT NOCOPY VARCHAR2, x_ret_msg OUT NOCOPY VARCHAR2, p_source IN VARCHAR2, p_category IN VARCHAR2, p_gl_date IN VARCHAR2, p_reprocess IN VARCHAR2, p_bal_seg IN VARCHAR2, p_as_of_date IN VARCHAR2, p_report_id IN VARCHAR2
                               , p_currency IN VARCHAR2);

    PROCEDURE log_data (x_ret_code      OUT NOCOPY VARCHAR2,
                        x_ret_msg       OUT NOCOPY VARCHAR2);
END XXD_GL_CONCUR_INBOUND_PKG;
/
