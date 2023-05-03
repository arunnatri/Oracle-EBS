--
-- XXD_AP_CONCUR_INBOUND_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:18:20 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_AP_CONCUR_INBOUND_PKG"
AS
    /***********************************************************************************
      *$header     :                                                                   *
      *                                                                                *
      * AUTHORS    :  Srinath Siricilla                                                *
      *                                                                                *
      * PURPOSE    :  AP Invoice Concurr Inbound process                               *
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
      * 1.1     17-APR-2019  Aravind Kannuri       Changes as per CCR0007945           *
      * 1.2     28-MAR-2020  Srinath Siricilla     China Payments CCR0008481           *
      *********************************************************************************/

    FUNCTION is_bal_seg_valid (p_company IN VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    PROCEDURE write_log (pv_msg IN VARCHAR2);

    FUNCTION is_code_comb_valid (p_seg1 IN VARCHAR2, p_seg2 IN VARCHAR2, p_seg3 IN VARCHAR2, p_seg4 IN VARCHAR2, p_seg5 IN VARCHAR2, p_seg6 IN VARCHAR2, p_seg7 IN VARCHAR2, p_seg8 IN VARCHAR2, x_ccid OUT NUMBER
                                 , x_cc OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_gl_code_valid (p_ccid      IN     VARCHAR2,
                               x_cc           OUT VARCHAR2,
                               x_ret_msg      OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_seg_valid (p_seg IN VARCHAR2, p_flex_type IN VARCHAR2, p_seg_type IN VARCHAR2
                           , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_org_valid (p_org_id IN NUMBER, p_org_name IN VARCHAR2 --Added as per version 1.2
                                                                     , x_org_id OUT VARCHAR2
                           , x_org_name OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_vendor_valid (p_vendor_number   IN     VARCHAR2,
                              x_vendor_id          OUT NUMBER,
                              x_vendor_num         OUT VARCHAR2,
                              x_vendor_name        OUT VARCHAR2,
                              x_ret_msg            OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_site_valid (p_org_id IN NUMBER, p_org_name IN VARCHAR2, p_vendor_id IN NUMBER, p_vendor_number IN VARCHAR2 --Added as per version 1.2
                                                                                                                          , x_site_id OUT NUMBER, x_site OUT VARCHAR2
                            , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_curr_code_valid (p_curr_code   IN     VARCHAR2,
                                 x_ret_msg        OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_flag_valid (p_flag      IN     VARCHAR2,
                            x_flag         OUT VARCHAR2,
                            x_ret_msg      OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_curr_code (p_vendor_id        IN     NUMBER,
                            p_vendor_site_id   IN     NUMBER,
                            p_org_id           IN     NUMBER,
                            x_curr_code           OUT VARCHAR2,
                            x_ret_msg             OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_inv_num_valid (p_inv_num IN VARCHAR2, p_vendor_id IN NUMBER, p_vendor_site_id IN NUMBER
                               , p_org_id IN NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_pay_method_valid (p_pay_method IN VARCHAR2, x_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_pay_method (p_vendor_id        IN     NUMBER,
                             p_vendor_site_id   IN     NUMBER,
                             p_org_id           IN     NUMBER,
                             x_pay_method          OUT VARCHAR2,
                             x_ret_msg             OUT VARCHAR2)
        RETURN BOOLEAN;

    /*FUNCTION is_term_valid (p_terms      IN  VARCHAR2
                           ,x_term_id    OUT NUMBER
                           ,x_ret_msg    OUT VARCHAR2)
    RETURN BOOLEAN;*/

    FUNCTION is_term_valid (p_term_id IN NUMBER, x_term_id OUT VARCHAR2, x_term_name OUT VARCHAR2
                            , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_terms (p_vendor_id        IN     NUMBER,
                        p_vendor_site_id   IN     NUMBER,
                        p_org_id           IN     NUMBER,
                        x_term_id             OUT NUMBER,
                        x_term_name           OUT VARCHAR2,
                        x_ret_msg             OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_pay_group_valid (p_pay_group IN VARCHAR2, x_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_line_type_valid (p_line_type IN VARCHAR2, x_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION dist_account_exists (p_dist_acct IN VARCHAR2, x_dist_ccid OUT NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    /*FUNCTION is_interco_acct (p_interco_acct     IN   VARCHAR2
                             ,p_dist_ccid        IN   NUMBER
                             ,x_interco_acct_id  OUT  NUMBER
                             ,x_ret_msg          OUT  NUMBER)
    RETURN BOOLEAN;*/

    FUNCTION is_interco_acct (p_interco_acct_id IN NUMBER, p_dist_ccid IN NUMBER, p_interco_cc IN VARCHAR2
                              , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_ship_to_valid (p_ship_to_code IN VARCHAR2, x_ship_to_loc_id OUT NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_ship_to_loc_id (p_vendor_site_id   IN     NUMBER,
                                 p_org_id           IN     NUMBER,
                                 x_location_id         OUT NUMBER,
                                 x_loc_code            OUT VARCHAR2,
                                 x_ret_msg             OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_gl_date_valid (p_gl_date   IN     DATE,
                               p_org_id    IN     NUMBER,
                               x_ret_msg      OUT VARCHAR2)
        RETURN DATE;

    FUNCTION is_project_period_open (p_gl_date   IN     DATE,
                                     p_org_id    IN     NUMBER,
                                     x_ret_msg      OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_date_future_valid (p_date      IN     DATE,
                                   p_org_id    IN     NUMBER,
                                   x_ret_msg      OUT VARCHAR2)
        RETURN DATE;

    /*FUNCTION get_tax_rate(p_tax_rate       IN VARCHAR2,
                          p_ou_name        IN VARCHAR2,
                          x_tax_rate_code  OUT VARCHAR2,
                          x_ret_msg        OUT VARCHAR2)
    RETURN BOOLEAN; */

    FUNCTION validate_amount (p_amount    IN     VARCHAR2,
                              x_amount       OUT NUMBER,
                              x_ret_msg      OUT VARCHAR2)
        RETURN BOOLEAN;

    /*FUNCTION get_asset_book(p_asset_book IN  VARCHAR2
                           ,x_asset_book OUT VARCHAR2
                           ,x_ret_msg    OUT VARCHAR2)
    RETURN BOOLEAN;*/

    FUNCTION get_asset_book (p_comp_seg1 IN VARCHAR2, x_asset_book OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_asset_book_valid (p_asset_book IN VARCHAR2, p_org_id IN VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_asset_category (p_asset_cat IN VARCHAR2, x_asset_cat_id OUT NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_asset_cc (p_cat_id IN NUMBER, p_asset_book IN VARCHAR2, x_ccid OUT NUMBER
                           , x_cc OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_asset_cat_valid (p_asset_cat_id IN VARCHAR2, p_asset_book IN VARCHAR2, --x_valid_out     OUT VARCHAR2,
                                                                                       x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_asset_location (p_asset_loc IN VARCHAR2, x_asset_loc_id OUT NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_asset_custodian (p_custodian IN VARCHAR2, x_cust_id OUT NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_project_id (p_proj_number IN VARCHAR2, p_org_id IN NUMBER, p_org_name IN VARCHAR2 --Added as per version 1.2
                             , x_proj_id OUT NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_project_task_id (p_task_number IN VARCHAR2, p_proj_id IN NUMBER, x_proj_task_id OUT NUMBER
                                  , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_expend_type_valid (p_expend_type IN VARCHAR2, p_inv_type_code IN VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_exp_org_id (p_exp_org IN VARCHAR2, p_org_id IN NUMBER, x_exp_org_id OUT NUMBER
                             , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_exp_item_date_valid (p_exp_date IN VARCHAR2, p_prj_task_id IN NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    -- Added as per Change 1.2
    FUNCTION get_emp_bank_acct_num (pn_vendor_id IN NUMBER, -- external_bank_account_id
                                                            pv_match_value IN VARCHAR2, pv_emp_name IN VARCHAR2
                                    , x_ext_bank_account_id OUT VARCHAR2, x_ext_bank_account_num OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_match_seg_valid (p_seg_value IN VARCHAR2, p_flex_type IN VARCHAR2, x_match_val OUT VARCHAR2
                                 , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    -- End of Change 3.0

    PROCEDURE create_invoices (x_ret_code   OUT VARCHAR2,
                               x_ret_msg    OUT VARCHAR2);

    --   PROCEDURE MAIN ;
    --                  (x_retcode        OUT NOCOPY VARCHAR2,
    --                   x_errbuf         OUT NOCOPY VARCHAR2);

    PROCEDURE MAIN (x_retcode OUT NOCOPY VARCHAR2, x_errbuf OUT NOCOPY VARCHAR2, p_org_name IN VARCHAR2, p_exp_rep_num IN VARCHAR2, p_reprocess IN VARCHAR2, p_dummy_par IN VARCHAR2, p_inv_type IN VARCHAR2, p_cm_type IN VARCHAR2, p_pay_group IN VARCHAR2
                    , pn_purge_days IN NUMBER);


    FUNCTION get_error_desc (p_rejection_code IN VARCHAR2)
        RETURN VARCHAR2;

    /*FUNCTION is_tax_code_valid (p_tax_code    IN  VARCHAR2
                               ,x_tax_code     OUT VARCHAR2
                               ,x_ret_msg      OUT VARCHAR2)
    RETURN BOOLEAN;*/

    FUNCTION is_tax_code_valid (p_tax_percent IN VARCHAR2, p_tax_ou IN VARCHAR2, x_tax_code OUT VARCHAR2
                                , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_payment_code (p_pay_group IN VARCHAR2, p_pay_ou IN VARCHAR2, x_pay_code OUT VARCHAR2
                               , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_inv_type_valid (p_inv_type IN VARCHAR2, x_inv_type OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_cc_segments (p_ic_acct IN NUMBER, x_seg1 OUT VARCHAR2, x_seg2 OUT VARCHAR2, x_seg3 OUT VARCHAR2, x_seg4 OUT VARCHAR2, x_seg5 OUT VARCHAR2, x_seg6 OUT VARCHAR2, x_seg7 OUT VARCHAR2, x_seg8 OUT VARCHAR2
                              , x_cc OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    /*PROCEDURE insert_staging(x_retcode        OUT NOCOPY VARCHAR2,
                             x_errbuf         OUT NOCOPY VARCHAR2);*/

    PROCEDURE insert_staging (x_ret_code         OUT NOCOPY VARCHAR2,
                              x_ret_msg          OUT NOCOPY VARCHAR2,
                              p_org_name      IN            VARCHAR2,
                              p_exp_rep_num   IN            VARCHAR2,
                              p_reprocess     IN            VARCHAR2);

    /*PROCEDURE validate_staging(x_ret_code      OUT NOCOPY VARCHAR2,
                               x_ret_msg       OUT NOCOPY VARCHAR2,
                               p_re_flag       IN    VARCHAR2); */

    PROCEDURE validate_staging (x_ret_code       OUT NOCOPY VARCHAR2,
                                x_ret_msg        OUT NOCOPY VARCHAR2,
                                p_org         IN            VARCHAR2,
                                p_exp         IN            VARCHAR2,
                                p_re_flag     IN            VARCHAR2,
                                p_inv_type    IN            VARCHAR2,
                                p_cm_type     IN            VARCHAR2,
                                p_pay_group   IN            VARCHAR2);

    PROCEDURE load_interface (x_ret_code   OUT VARCHAR2,
                              x_ret_msg    OUT VARCHAR2);

    PROCEDURE clear_int_tables;

    FUNCTION is_invoice_created (p_org_id           IN     NUMBER,
                                 p_invoice_num      IN     VARCHAR2,
                                 p_vendor_id        IN     NUMBER,
                                 p_vendor_site_id   IN     NUMBER,
                                 x_invoice_id          OUT NUMBER)
        RETURN BOOLEAN;

    FUNCTION is_line_created (p_invoice_id    IN NUMBER,
                              p_line_number   IN NUMBER)
        RETURN BOOLEAN;

    PROCEDURE check_data (x_ret_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2);

    PROCEDURE Update_sae_data (x_ret_code OUT NOCOPY VARCHAR2, x_ret_msg OUT NOCOPY VARCHAR2, p_org IN VARCHAR2
                               , p_exp IN VARCHAR2);

    PROCEDURE display_data (x_ret_code OUT NOCOPY VARCHAR2, x_ret_msg OUT NOCOPY VARCHAR2, p_request_id IN NUMBER);
END XXD_AP_CONCUR_INBOUND_PKG;
/
