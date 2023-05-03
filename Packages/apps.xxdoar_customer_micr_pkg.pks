--
-- XXDOAR_CUSTOMER_MICR_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:15 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOAR_CUSTOMER_MICR_PKG"
AS
    /*
    * Package to load MICR information to customer
    *
    *---------------------------------------------------------------*
    *Who                 Version  When            What              *
    *===============================================================*
    * Madhav Dhurjaty    v1.0     03/07/2016      Created           *
    *                                                               *
    *---------------------------------------------------------------*
    */
    g_conc_req_id             NUMBER := FND_GLOBAL.CONC_REQUEST_ID;
    g_org_id                  NUMBER := FND_GLOBAL.ORG_ID;
    g_default_bank_name       VARCHAR2 (360) := 'Lockbox Bank - Customer MICR';
    g_default_branch_type     VARCHAR2 (30) := 'ABA';
    g_default_bank_country    VARCHAR2 (10) := 'US';
    g_default_bank_currency   VARCHAR2 (10) := 'USD';
    g_default_pmt_function    VARCHAR2 (30) := 'CUSTOMER_PAYMENT';
    g_default_instr_type      VARCHAR2 (30) := 'BANKACCOUNT';
    g_legacy_org_id           NUMBER := 2;

    FUNCTION get_party_id (p_customer_id IN NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN NUMBER;

    FUNCTION invoice_exists (p_trx_number   IN     VARCHAR2,
                             p_org_id       IN     NUMBER,
                             --                            p_use_db_link  IN     VARCHAR2,
                             x_ret_msg         OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_cust_id (p_trx_number IN VARCHAR2, p_org_id IN NUMBER, --                         p_use_db_link  IN     VARCHAR2,
                                                                        x_customer_num OUT VARCHAR2
                          , x_ret_msg OUT VARCHAR2)
        RETURN NUMBER;

    FUNCTION validate_bank_info (p_routing_num IN VARCHAR2, p_account_num IN VARCHAR2, x_bank_id OUT NUMBER
                                 , x_branch_id OUT NUMBER, x_account_id OUT NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    PROCEDURE load_staging (p_filename IN VARCHAR2, p_timestamp IN VARCHAR2, p_directory IN VARCHAR2
                            , x_ret_msg OUT VARCHAR2);

    PROCEDURE create_bank (p_bank_name IN VARCHAR2, p_bank_number IN VARCHAR2, p_country IN VARCHAR2
                           , x_bank_id OUT NUMBER, x_ret_msg OUT VARCHAR2);

    PROCEDURE create_branch (p_bank_id IN NUMBER, p_branch_name IN VARCHAR2, p_branch_type IN VARCHAR2
                             , p_routing_number IN VARCHAR2, x_branch_id OUT NUMBER, x_ret_msg OUT VARCHAR2);

    PROCEDURE create_account (p_bank_id IN NUMBER, p_branch_id IN NUMBER, p_party_id IN NUMBER, p_account_number IN VARCHAR2, p_country IN VARCHAR2, p_currency IN VARCHAR2
                              , p_check_digits IN NUMBER, x_account_id OUT NUMBER, x_ret_msg OUT VARCHAR2);

    PROCEDURE set_payer_assignment (p_party_id IN NUMBER, p_pmt_function IN VARCHAR2, p_org_type IN VARCHAR2, p_org_id IN NUMBER DEFAULT NULL, p_account_id IN NUMBER, p_cust_account_id IN NUMBER
                                    , p_acct_site_id IN NUMBER, x_assign_id OUT NUMBER, x_ret_msg OUT VARCHAR2);

    PROCEDURE print_stats (p_filename    IN     VARCHAR2,
                           p_timestamp   IN     VARCHAR2,
                           x_ret_msg        OUT VARCHAR2);

    PROCEDURE main (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_directory IN VARCHAR2
                    , p_filename IN VARCHAR2, p_reprocess IN VARCHAR2      --,
                                                                     --p_use_db_link IN     VARCHAR2
                                                                     );
END xxdoar_customer_micr_pkg;
/
