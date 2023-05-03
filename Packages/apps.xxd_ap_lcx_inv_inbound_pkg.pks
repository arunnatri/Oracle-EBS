--
-- XXD_AP_LCX_INV_INBOUND_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:18:31 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_AP_LCX_INV_INBOUND_PKG"
AS
    /***********************************************************************************
      *$header     :                                                                   *
      *                                                                                *
      * AUTHORS    :  Gaurav  Joshi                                                    *
      *                                                                                *
      * PURPOSE    :  AP Invoice Luncernex Inbound process                             *
      *                                                                                *
      * PARAMETERS :                                                                   *
      *                                                                                *
      * DATE       :  27-SEP-2019                                                      *
      *                                                                                *
      * Assumptions:                                                                   *
      *                                                                                *
      *                                                                                *
      * History                                                                        *
      * Vsn     Change Date  Changed By            Change Description                  *
      * -----   -----------  ------------------    ------------------------------------*
      * 1.0     27-SEP-2019  Gaurav                Initial Creation                    *
      * 1.1     27-JAN-2020  Srinath Siricilla     CCR0008396                          *
      * 2.0     05-NOV-2020  Srinath Siricilla     CCR0008507 - MTD Changes            *
      *********************************************************************************/
    g_interfaced       VARCHAR2 (1) := 'I';
    g_errored          VARCHAR2 (1) := 'E';
    g_validated        VARCHAR2 (1) := 'V';
    g_processed        VARCHAR2 (1) := 'P';
    g_created          VARCHAR2 (1) := 'C';
    g_new              VARCHAR2 (1) := 'N';
    g_other            VARCHAR2 (1) := 'O';
    g_format_mask      VARCHAR2 (240) := 'MM/DD/YYYY';
    g_invoice_source   VARCHAR2 (50) DEFAULT 'LUCERNEX';

    PROCEDURE main (x_retcode OUT NOCOPY VARCHAR2, x_errbuf OUT NOCOPY VARCHAR2, p_file_name IN VARCHAR2, p_invoice_number IN VARCHAR2, p_vendor_number IN NUMBER, p_vendor_site IN VARCHAR2
                    , p_invoice_date_from IN VARCHAR2, p_invoice_date_to IN VARCHAR2, p_reprocess IN VARCHAR2);

    PROCEDURE insert_staging (x_ret_code               OUT NOCOPY VARCHAR2,
                              x_ret_msg                OUT NOCOPY VARCHAR2,
                              p_file_name           IN            VARCHAR2,
                              p_invoice_number      IN            VARCHAR2,
                              p_vendor_number       IN            NUMBER,
                              p_vendor_site         IN            VARCHAR2,
                              p_invoice_date_from   IN            DATE,
                              p_invoice_date_to     IN            DATE);

    PROCEDURE update_staging (x_ret_code               OUT NOCOPY VARCHAR2,
                              x_ret_msg                OUT NOCOPY VARCHAR2,
                              p_file_name           IN            VARCHAR2,
                              p_invoice_number      IN            VARCHAR2,
                              p_vendor_number       IN            NUMBER,
                              p_vendor_site         IN            VARCHAR2,
                              p_invoice_date_from   IN            DATE,
                              p_invoice_date_to     IN            DATE);

    PROCEDURE load_interface (x_ret_code   OUT VARCHAR2,
                              x_ret_msg    OUT VARCHAR2);

    PROCEDURE validate_staging (x_ret_code OUT NOCOPY VARCHAR2, x_ret_msg OUT NOCOPY VARCHAR2, p_reprocess IN VARCHAR2);

    PROCEDURE create_invoices (x_ret_code   OUT VARCHAR2,
                               x_ret_msg    OUT VARCHAR2);

    FUNCTION is_org_valid (p_org_name   IN     VARCHAR2,
                           x_org_id        OUT NUMBER,
                           x_ret_msg       OUT VARCHAR2)
        RETURN BOOLEAN;

    -- Added Function for CCR0008507

    FUNCTION is_mtd_org (p_org_name       IN     VARCHAR2,
                         x_mtd_org_name      OUT VARCHAR2,
                         x_ret_msg           OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_vendor_valid (p_vendor_number IN VARCHAR2, x_vendor_id OUT NUMBER, x_vendor_name OUT VARCHAR2
                              , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_site_valid (p_site_code IN VARCHAR2, p_org_id IN NUMBER, p_vendor_id IN NUMBER
                            , x_site_id OUT NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_po_exists (p_po_num         IN     VARCHAR2,
                           p_vendor_id      IN     NUMBER,
                           p_org_id         IN     NUMBER,
                           x_po_header_id      OUT NUMBER,
                           x_ret_msg           OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_po_line_exists (p_line_num     IN     NUMBER,
                                p_org_id       IN     NUMBER,
                                p_header_id    IN     NUMBER,
                                x_po_line_id      OUT NUMBER,
                                x_ret_msg         OUT VARCHAR2)
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

    FUNCTION is_inv_num_valid (p_inv_num IN VARCHAR2, p_vendor_id IN NUMBER, p_vendor_site IN NUMBER
                               ,                    -- Added as per change 1.1
                                 p_org_id IN NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_pay_method_valid (p_pay_method IN VARCHAR2, x_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_pay_method (p_vendor_id        IN     NUMBER,
                             p_vendor_site_id   IN     NUMBER,
                             p_org_id           IN     NUMBER,
                             x_pay_method          OUT VARCHAR2,
                             x_ret_msg             OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_term_valid (p_terms     IN     VARCHAR2,
                            x_term_id      OUT NUMBER,
                            x_ret_msg      OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_terms (p_vendor_id IN NUMBER, p_vendor_site_id IN NUMBER, p_org_id IN NUMBER
                        , x_term_id OUT NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_line_type_valid (p_line_type IN VARCHAR2, x_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION dist_account_exists (p_dist_acct IN VARCHAR2, x_dist_ccid OUT NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_interco_acct (p_interco_acct IN VARCHAR2, p_dist_ccid IN NUMBER, x_interco_acct_id OUT NUMBER
                              , x_ret_msg OUT NUMBER)
        RETURN BOOLEAN;

    FUNCTION dist_set_exists (p_dist_set_name IN VARCHAR2, p_org_id IN NUMBER, x_dist_id OUT NUMBER
                              , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_ship_to_valid (p_ship_to_code IN VARCHAR2, x_ship_to_loc_id OUT NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_gl_date_valid (p_gl_date   IN     DATE,
                               p_org_id    IN     NUMBER,
                               x_ret_msg      OUT VARCHAR2)
        RETURN DATE;

    FUNCTION validate_amount (p_amount    IN     VARCHAR2,
                              x_amount       OUT NUMBER,
                              x_ret_msg      OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_asset_book (p_asset_book IN VARCHAR2, x_asset_book OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_asset_book_valid (p_asset_book IN VARCHAR2, p_org_id IN VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_asset_category (p_asset_cat IN VARCHAR2, x_asset_cat_id OUT NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_asset_cat_valid (p_asset_cat_id IN VARCHAR2, p_asset_book IN VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_tax_code_valid (p_tax_code IN VARCHAR2, x_tax_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    PROCEDURE check_data (x_ret_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2);

    PROCEDURE update_soa_data (x_ret_code   OUT VARCHAR2,
                               x_ret_msg    OUT VARCHAR2);


    FUNCTION get_error_desc (p_rejection_code IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION is_invoice_created (p_org_id IN NUMBER, p_invoice_num IN VARCHAR2, p_vendor_id IN NUMBER
                                 , p_vendor_site_id IN NUMBER, p_inv_type IN VARCHAR2, x_invoice_id OUT NUMBER)
        RETURN BOOLEAN;

    FUNCTION is_line_created (p_invoice_id    IN NUMBER,
                              p_line_number   IN NUMBER)
        RETURN BOOLEAN;

    PROCEDURE clear_int_tables;

    PROCEDURE update_proc (p_input        IN     VARCHAR2,
                           x_ret_status      OUT VARCHAR2,
                           x_ret_msg         OUT VARCHAR2);
END xxd_ap_lcx_inv_inbound_pkg;
/


GRANT EXECUTE, DEBUG ON APPS.XXD_AP_LCX_INV_INBOUND_PKG TO SOA_INT
/
