--
-- XXD_AR_LCX_INVOICES_PKG  (Package) 
--
--  Dependencies: 
--   FND_API (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:19:06 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_AR_LCX_INVOICES_PKG"
AS
    --  ####################################################################################################
    --  Author(s)       : Srinath Siricilla
    --  System          : Oracle Applications
    --  Subsystem       : EBS
    --  Change          : CCR0007668
    --  Schema          : APPS
    --  Purpose         : Lucernex AR Inbound
    --                  : Package is used to create AR transactions
    --  Dependency      : None
    --  Change History
    --  --------------
    --  Date            Name                Ver     Change          Description
    --  ----------      --------------      -----   -------------   ---------------------
    --  02-OCT-2019     Srinath Siricilla   1.0     NA              Initial Version
    --  ####################################################################################################
    --Global Variables declaration
    --Global constants and Return Statuses

    gn_miss_num          CONSTANT NUMBER := apps.fnd_api.g_miss_num;
    gv_miss_char         CONSTANT VARCHAR2 (1) := apps.fnd_api.g_miss_char;
    gd_miss_date         CONSTANT DATE := apps.fnd_api.g_miss_date;
    gv_ret_success       CONSTANT VARCHAR2 (1) := apps.fnd_api.g_ret_sts_success;
    gv_ret_error         CONSTANT VARCHAR2 (1) := apps.fnd_api.g_ret_sts_error;
    gv_ret_unexp_error   CONSTANT VARCHAR2 (1)
                                      := apps.fnd_api.g_ret_sts_unexp_error ;
    gv_ret_warning       CONSTANT VARCHAR2 (1) := 'W';
    gn_success           CONSTANT NUMBER := 0;
    gn_warning           CONSTANT NUMBER := 1;
    gn_error             CONSTANT NUMBER := 2;

    PROCEDURE msg (pv_msg    IN VARCHAR2,
                   pv_time   IN VARCHAR2 DEFAULT 'N',
                   pv_file   IN VARCHAR2 DEFAULT 'LOG');

    FUNCTION get_org_id (p_org_name   IN     VARCHAR2,
                         x_org_id        OUT NUMBER,
                         x_ret_msg       OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_batch_source_id (p_org_id IN NUMBER, p_org_name IN VARCHAR2, x_batch_source_id OUT NUMBER
                                  , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_batch_source_name (p_batch_source_id IN NUMBER, p_org_id IN NUMBER, x_batch_source_name OUT VARCHAR2
                                    , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_currency_code (p_org_id IN NUMBER, p_org_name IN VARCHAR2, x_curr_code OUT VARCHAR2
                                , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    --    FUNCTION is_trx_type_valid (p_trx_name      IN   VARCHAR2
    --                               ,x_trx_code      OUT   VARCHAR2
    --                               ,x_ret_msg       OUT  VARCHAR2)
    --    RETURN BOOLEAN;

    FUNCTION get_cust_trx_type (p_trx_type_name IN VARCHAR2, p_org_id IN NUMBER, x_trx_type_id OUT NUMBER
                                , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_reason_code (p_reason_name IN VARCHAR2, x_reason_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_cust_account_id (p_cust_acct_num    IN     VARCHAR2,
                                  x_cust_acct_id        OUT NUMBER,
                                  x_party_id            OUT NUMBER,
                                  x_cust_acct_name      OUT VARCHAR2,
                                  x_ret_msg             OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_orig_bill_address_id (p_cust_acct_id IN NUMBER, p_cust_acct_num IN VARCHAR2, p_org_name IN VARCHAR2
                                       , p_org_id IN NUMBER, x_orig_bill_address_id OUT NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_brand_valid (p_brand     IN     VARCHAR2,
                             x_brand        OUT VARCHAR2,
                             x_ret_msg      OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_trx_date_valid (p_gl_date   IN     DATE,
                                p_org_id    IN     NUMBER,
                                x_ret_msg      OUT VARCHAR2)
        RETURN DATE;

    FUNCTION is_trx_amt_valid (p_trx_amt IN NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_flag_valid (p_tax_flag   IN     VARCHAR2,
                            x_tax_flag      OUT VARCHAR2,
                            x_ret_msg       OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_print_option_valid (p_print_option IN VARCHAR2, x_print_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_sales_rep_valid (p_sales_per_name IN VARCHAR2, p_org_id IN NUMBER, x_sales_rep_id OUT NUMBER
                                 , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_gl_code_valid (p_gl_code   IN     VARCHAR2,
                               x_ccid         OUT NUMBER,
                               x_ret_msg      OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_trasaction_created (
        p_cust_account_id             IN     NUMBER,
        p_org_id                      IN     NUMBER,
        p_interface_line_context      IN     VARCHAR2,
        p_interface_line_attribute1   IN     VARCHAR2,
        p_interface_line_attribute2   IN     VARCHAR2,
        p_interface_line_attribute3   IN     VARCHAR2,
        p_interface_line_attribute4   IN     VARCHAR2,
        p_interface_line_attribute5   IN     VARCHAR2,
        p_interface_line_attribute6   IN     VARCHAR2,
        x_trx_number                     OUT VARCHAR2,
        x_customer_trx_id                OUT NUMBER)
        RETURN BOOLEAN;

    FUNCTION is_trx_line_created (p_customer_trx_id IN NUMBER, p_interface_line_context IN VARCHAR2, p_interface_line_att3 IN VARCHAR2
                                  --,p_record_id                IN    NUMBER
                                  , x_customer_trx_line_id OUT NUMBER)
        RETURN BOOLEAN;

    FUNCTION is_trx_dist_created (p_customer_trx_id            IN     NUMBER,
                                  p_customer_trx_line_id       IN     NUMBER,
                                  p_account_class              IN     VARCHAR2,
                                  p_ccid                       IN     NUMBER,
                                  x_cust_trx_line_gl_dist_id      OUT NUMBER)
        RETURN BOOLEAN;

    PROCEDURE insert_staging (x_ret_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2, p_file_name IN VARCHAR2, p_org_name IN VARCHAR2, p_trx_type IN VARCHAR2, p_brand IN VARCHAR2, p_account_num IN VARCHAR2, p_trx_date_from IN VARCHAR2, p_trx_date_to IN VARCHAR2
                              , p_reprocess IN VARCHAR2);

    PROCEDURE update_staging (x_ret_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2, p_file_name IN VARCHAR2, p_org_name IN VARCHAR2, p_trx_type IN VARCHAR2, p_brand IN VARCHAR2, p_account_num IN VARCHAR2, p_trx_date_from IN VARCHAR2, p_trx_date_to IN VARCHAR2
                              , p_reprocess IN VARCHAR2);


    PROCEDURE validate_staging (x_ret_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2, p_file_name IN VARCHAR2, p_org_name IN VARCHAR2, p_trx_type IN VARCHAR2, p_brand IN VARCHAR2, p_account_num IN VARCHAR2, p_trx_date_from IN VARCHAR2, p_trx_date_to IN VARCHAR2
                                , p_reprocess IN VARCHAR2);

    PROCEDURE load_interface (x_ret_code   OUT VARCHAR2,
                              x_ret_msg    OUT VARCHAR2);

    PROCEDURE create_transactions (x_ret_code   OUT VARCHAR2,
                                   x_ret_msg    OUT VARCHAR2);

    PROCEDURE check_data (x_ret_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2);

    PROCEDURE Update_act_data (x_ret_code OUT NOCOPY VARCHAR2, x_ret_msg OUT NOCOPY VARCHAR2, p_conc_request_id IN NUMBER);

    PROCEDURE MAIN (x_retcode OUT VARCHAR2, x_errbuf OUT VARCHAR2, p_file_name IN VARCHAR2, p_org_name IN VARCHAR2, p_trx_type IN VARCHAR2, p_brand IN VARCHAR2, p_account_num IN VARCHAR2, p_trx_date_from IN VARCHAR2, p_trx_date_to IN VARCHAR2
                    , p_reprocess IN VARCHAR2);
END XXD_AR_LCX_INVOICES_PKG;
/
