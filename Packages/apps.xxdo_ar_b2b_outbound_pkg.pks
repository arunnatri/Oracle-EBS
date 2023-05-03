--
-- XXDO_AR_B2B_OUTBOUND_PKG  (Package) 
--
--  Dependencies: 
--   FND_API (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:15:04 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_AR_B2B_OUTBOUND_PKG"
/***************************************************************************************
* Program Name : XXDO_AR_B2B_OUTBOUND_PKG                                              *
* Language     : PL/SQL                                                                *
* Description  : Package to generate outbound files for B2B Portal integration         *
*                                                                                      *
* History      :                                                                       *
*                                                                                      *
* WHO          :       WHAT      Desc                                    WHEN          *
* -------------- ----------------------------------------------------------------------*
* Madhav Dhurjaty      1.0       Initial Version                         27-SEP-2017   *
* Madhav Dhurjaty      2.0       B2B Phase 2 EMEA Changes (CCR0007216 )  18-Apr-2018   *
* Srinath Siricilla    3.0       Macau Project Changes (CCR0007979)      12-JUL-2019   *
* Srinath Siricilla    4.0      CCR0009103 - MTD P3                      08-MAR-2021   *
* Srinath Siricilla    4.1      CCR0009402                               07-JUN-2021   *
* Kishan Reddy         4.2      CCR0009859                               22-MAY-2022   *
* -------------------------------------------------------------------------------------*/
AS
    --Global Constants
    -- Return Statuses
    gv_ret_success       CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_success;
    gv_ret_error         CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_error;
    gv_ret_unexp_error   CONSTANT VARCHAR2 (1)
                                      := fnd_api.g_ret_sts_unexp_error ;
    gv_ret_warning       CONSTANT VARCHAR2 (1) := 'W';
    gn_success           CONSTANT NUMBER := 0;
    gn_warning           CONSTANT NUMBER := 1;
    gn_error             CONSTANT NUMBER := 2;

    ----
    ----

    FUNCTION get_tax_codes (pv_org_id IN VARCHAR2, pv_tax_rate IN VARCHAR2, pv_ship_to IN VARCHAR2
                            , pv_ship_to_reg IN VARCHAR2, pv_ship_from IN VARCHAR2, x_tax_code OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION check_VS_active (pv_ff_name IN VARCHAR2, pv_flex_context_code IN VARCHAR2, x_count OUT NUMBER)
        RETURN BOOLEAN;

    ---- Added as per change CCR0009103

    FUNCTION get_org_territory_fnc (pv_terr_name IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_ship_from_brand_fnc (pv_brand    IN VARCHAR2,
                                      pn_org_id   IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_ship_from_fnc (pn_inv_org_id IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_ref_num (p_trx_type            IN VARCHAR2,
                          p_batch_name          IN VARCHAR2,
                          pn_ship_site_use_id   IN NUMBER,
                          pn_bill_to_cust_id    IN NUMBER,
                          pn_bill_site_use_id   IN NUMBER,
                          pv_brand              IN VARCHAR2,
                          pn_org_id             IN NUMBER,
                          pn_warehouse_id       IN NUMBER,
                          pv_claim_number       IN VARCHAR2,
                          pv_line_context       IN VARCHAR2, --- Added as per CCR0009402
                          pn_inv_item_id        IN NUMBER -- Added as per CCR0009857
                                                         )
        RETURN NUMBER;

    ---- End of Change CCR0009103
    FUNCTION remove_junk (p_input IN VARCHAR2)
        RETURN VARCHAR2;

    ----
    ----
    FUNCTION get_sales_order_num (pn_customer_trx_id IN NUMBER)
        RETURN VARCHAR2;

    ----
    ----
    FUNCTION get_consolidation_flag (p_customer_id IN NUMBER)
        RETURN VARCHAR2;

    ----
    ----
    FUNCTION ar_rec_num_validate (p_org_id IN NUMBER, p_cust_account_id IN NUMBER, p_receipt_number IN VARCHAR2)
        RETURN VARCHAR2;

    ----
    PROCEDURE get_billing_ship_from (p_customer_trx_id       IN     NUMBER,
                                     p_trx_type              IN     VARCHAR2,
                                     x_ship_from_country        OUT VARCHAR2,
                                     x_ship_from_ctry_name      OUT VARCHAR2,
                                     x_tax_statement            OUT VARCHAR2);

    ----
    ----
    ----
    PROCEDURE get_soa_hdr_details (p_org_id IN NUMBER, p_customer_id IN NUMBER, p_customer_name IN VARCHAR2, x_ou_name OUT VARCHAR2, x_brand_name OUT VARCHAR2, x_lang_code OUT VARCHAR2, x_email_to OUT VARCHAR2, x_email_from OUT VARCHAR2, x_print_flag OUT VARCHAR2
                                   , x_email_flag OUT VARCHAR2);

    ----
    ----
    PROCEDURE open_ar_wrapper (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id IN NUMBER, p_customer_id IN NUMBER, p_include_receipts IN VARCHAR2, p_debug_mode IN VARCHAR2
                               , p_file_path IN VARCHAR2);

    ----
    ----
    PROCEDURE open_ar_main (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id IN NUMBER, p_customer_id IN NUMBER, p_include_receipts IN VARCHAR2, p_debug_mode IN VARCHAR2
                            , p_file_path IN VARCHAR2);

    ----
    ----
    PROCEDURE statement_wrapper (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id IN NUMBER, p_customer_id IN NUMBER, p_as_of_date IN VARCHAR2, p_bucket_name IN VARCHAR2
                                 , p_file_path IN VARCHAR2);

    ----
    ----
    PROCEDURE statement_main (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id IN NUMBER, p_customer_id IN NUMBER, p_as_of_date IN VARCHAR2, p_bucket_name IN VARCHAR2
                              , p_file_path IN VARCHAR2);

    ----
    ----
    PROCEDURE billing_wrapper (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id IN NUMBER, p_trx_class IN VARCHAR2, p_cust_trx_type_id IN NUMBER, p_batch_source_id IN NUMBER, p_creation_date_from IN VARCHAR2, p_creation_date_to IN VARCHAR2, p_trx_date_from IN VARCHAR2, p_trx_date_to IN VARCHAR2, p_trx_num_from IN VARCHAR2, p_trx_num_to IN VARCHAR2, p_customer_id IN NUMBER, p_cc_email_id IN VARCHAR2, p_reprocess_flag IN VARCHAR2
                               , p_file_path IN VARCHAR2);

    ----
    ----
    PROCEDURE billing_main (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id IN NUMBER, p_trx_class IN VARCHAR2, p_cust_trx_type_id IN NUMBER, p_batch_source_id IN NUMBER, p_creation_date_from IN VARCHAR2, p_creation_date_to IN VARCHAR2, p_trx_date_from IN VARCHAR2, p_trx_date_to IN VARCHAR2, p_trx_num_from IN VARCHAR2, p_trx_num_to IN VARCHAR2, p_customer_id IN NUMBER, p_cc_email_id IN VARCHAR2, p_reprocess_flag IN VARCHAR2
                            , p_file_path IN VARCHAR2);

    ----
    ----
    PROCEDURE check_file_exists (p_file_path     IN     VARCHAR2,
                                 p_file_name     IN     VARCHAR2,
                                 x_file_exists      OUT BOOLEAN,
                                 x_file_length      OUT NUMBER,
                                 x_block_size       OUT BINARY_INTEGER);

    ----
    ----
    PROCEDURE send_notification (p_program_name IN VARCHAR2, p_file_path IN VARCHAR2, p_conc_request_id IN NUMBER
                                 , p_email_lkp_name IN VARCHAR2, x_ret_code OUT NUMBER, x_ret_message OUT VARCHAR2);

    ----
    ---- Start of Change for CCR0009859
    FUNCTION validate_invoice (pn_org_id IN NUMBER, pn_customer_trx_id IN NUMBER, pv_invoice_type IN VARCHAR2)
        RETURN NUMBER;
---- End of Change for CCR0009859


END XXDO_AR_B2B_OUTBOUND_PKG;
/
