--
-- XXDO_APINV_UPLOAD_PKG  (Package) 
--
--  Dependencies: 
--   DO_MAIL_UTILS (Package)
--   FND_GLOBAL (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:14:53 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_APINV_UPLOAD_PKG"
AS
    /***********************************************************************************
      *$header     :                                                                   *
      *                                                                                *
      * AUTHORS    :  Srinath Siricilla                                                *
      *                                                                                *
      * PURPOSE    :  AP Invoice Excel WEBADI Upload                                   *
      *                                                                                *
      * PARAMETERS :                                                                   *
      *                                                                                *
      * DATE       :  02-FEB-2017                                                      *
      *                                                                                *
      * Assumptions:                                                                   *
      *                                                                                *
      *                                                                                *
      * History                                                                        *
      * Vsn     Change Date  Changed By            Change Description                  *
      * -----   -----------  ------------------    ------------------------------------*
      * 1.0     02-FEB-2017  Srinath Siricilla     Initial Creation                    *
      * 1.1     14-JUN-2017  Srinath Siricilla     Adding fields to WEBADI Template    *
      *                                            ENHC0013263                         *
      * 1.2     26-JIN-2018  Srinath Siricilla     CCR0007341                          *
      * 1.3     08-MAY-2018  Tejaswi Gangumalla    CCR0008618                          *
      * 2.0     05-NOV-2020  Srinath Siricilla     CCR0008507 - MTD Changes            *
      **********************************************************************************/

    G_DATA_IDENTIFIER    VARCHAR2 (50) DEFAULT 'EXCEL_WEB_ADI';
    --   G_INVOICE_SOURCE     VARCHAR2(50)  DEFAULT 'EXCEL';
    G_FORMAT_MASK        VARCHAR2 (240) := 'MM/DD/YYYY';
    --G_CONC_REQUEST_ID    NUMBER        := apps.fnd_global.CONC_REQUEST_ID;
    G_UNIQUE_SEQ         VARCHAR2 (100)
        := TO_CHAR (SYSTIMESTAMP, 'DD-MON-RRRR HH24:MI:SSSSS');
    G_DIST_LIST_NAME     VARCHAR2 (50) := apps.fnd_global.user_id;
    G_INTERFACED         VARCHAR2 (1) := 'I';
    G_ERRORED            VARCHAR2 (1) := 'E';
    G_VALIDATED          VARCHAR2 (1) := 'V';
    G_PROCESSED          VARCHAR2 (1) := 'P';
    G_CREATED            VARCHAR2 (1) := 'C';
    G_NEW                VARCHAR2 (1) := 'N';
    G_OTHER              VARCHAR2 (1) := 'O';
    gn_conc_request_id   NUMBER := apps.fnd_global.conc_request_id; --Added for change 1.3

    PROCEDURE clear_int_tables;

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

    FUNCTION is_inv_num_valid (p_inv_num IN VARCHAR2, p_vendor_id IN NUMBER, p_org_id IN NUMBER
                               , x_ret_msg OUT VARCHAR2)
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

    FUNCTION is_gl_date_valid (p_gl_date IN DATE, p_org_id IN NUMBER, p_param_value IN VARCHAR2 --Added for change1.3
                               , x_ret_msg OUT VARCHAR2)
        RETURN DATE;

    FUNCTION validate_amount (p_amount    IN     VARCHAR2,
                              x_amount       OUT NUMBER,
                              x_ret_msg      OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_invoice_created (p_org_id           IN     NUMBER,
                                 p_invoice_num      IN     VARCHAR2,
                                 p_vendor_id        IN     NUMBER,
                                 p_vendor_site_id   IN     NUMBER,
                                 x_invoice_id          OUT NUMBER)
        RETURN BOOLEAN;

    FUNCTION is_line_created (p_invoice_id    IN NUMBER,
                              p_line_number   IN NUMBER)
        RETURN BOOLEAN;

    FUNCTION get_asset_book (p_asset_book IN VARCHAR2, x_asset_book OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_asset_book_valid (p_asset_book IN VARCHAR2, p_org_id IN VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_asset_category (p_asset_cat IN VARCHAR2, x_asset_cat_id OUT NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION is_asset_cat_valid (p_asset_cat_id IN VARCHAR2, p_asset_book IN VARCHAR2, --x_valid_out     OUT VARCHAR2,
                                                                                       x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_error_desc (p_rejection_code IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION is_tax_code_valid (p_tax_code IN VARCHAR2, x_tax_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    /* Added for change 1.3*/
    FUNCTION is_pay_group_valid (p_pay_group IN VARCHAR2, x_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    -- Added Function for CCR0008507
    FUNCTION get_invoice_source (p_inv_source IN VARCHAR2, x_source OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    PROCEDURE load_interface (x_ret_code   OUT VARCHAR2,
                              x_ret_msg    OUT VARCHAR2);

    PROCEDURE create_invoices (x_ret_code   OUT VARCHAR2,
                               x_ret_msg    OUT VARCHAR2);

    FUNCTION get_email_recips (p_lookup_type IN VARCHAR2)
        RETURN apps.do_mail_utils.tbl_recips;

    FUNCTION get_email (x_ret_msg OUT VARCHAR2)
        RETURN VARCHAR2;

    PROCEDURE check_data (x_ret_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2);

    PROCEDURE email_out (x_ret_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2);

    PROCEDURE main (pv_retcode OUT NUMBER, pv_errproc OUT VARCHAR2);

    PROCEDURE xxdo_apinv_stgload_prc (
        p_po_number                 IN VARCHAR2,
        p_invoice_num               IN VARCHAR2,
        p_operating_unit            IN VARCHAR2,
        p_vendor_name               IN VARCHAR2,
        p_vendor_number             IN VARCHAR2,
        p_vednor_site_code          IN VARCHAR2,
        p_invoice_date              IN DATE,
        p_inv_amount                IN NUMBER,
        p_user_entered_tax          IN VARCHAR2,
        p_tax_control_amt           IN NUMBER,
        p_fapio_received            IN VARCHAR2,
        p_line_type                 IN VARCHAR2,
        p_description               IN VARCHAR2,
        p_line_amount               IN NUMBER,
        p_dist_account              IN VARCHAR2,
        p_ship_to_location          IN VARCHAR2,
        p_po_number_l               IN VARCHAR2,
        p_po_line_num               IN NUMBER,
        p_qty_invoiced              IN NUMBER,
        p_unit_price                IN NUMBER,
        p_tax_classification_code   IN VARCHAR2,
        p_interco_exp_account       IN VARCHAR2,
        p_deferred                  IN VARCHAR2,
        p_deferred_start_date       IN DATE,
        p_deferred_end_date         IN DATE,
        p_prorate                   IN VARCHAR2,
        p_track_as_asset            IN VARCHAR2,
        p_asset_category            IN VARCHAR2,
        p_currency_code             IN VARCHAR2,
        p_pay_method                IN VARCHAR2,
        p_pay_terms                 IN VARCHAR2,
        p_approver                  IN VARCHAR2,
        p_date_sent_approver        IN VARCHAR2,
        p_misc_notes                IN VARCHAR2,
        p_chargeback                IN VARCHAR2,
        p_inv_num_d                 IN VARCHAR2,
        p_payment_ref               IN VARCHAR2,
        p_sample_invoice            IN VARCHAR2,
        p_asset_book                IN VARCHAR2,
        p_distribution_set          IN VARCHAR2/* Changes as a part of CCR0007341*/
                                               ,
        p_inv_addl_info             IN VARCHAR2,
        p_pay_alone                 IN VARCHAR2,
        pv_attribute1               IN VARCHAR2,
        pv_attribute2               IN VARCHAR2,
        pv_attribute3               IN VARCHAR2,
        pv_attribute4               IN VARCHAR2,
        pv_attribute5               IN VARCHAR2,
        pv_attribute6               IN VARCHAR2,
        pv_attribute7               IN VARCHAR2,
        pv_attribute8               IN VARCHAR2,
        pv_attribute9               IN VARCHAR2,
        pv_attribute10              IN VARCHAR2,
        pv_attribute11              IN VARCHAR2,
        pv_attribute12              IN VARCHAR2,
        pv_attribute13              IN VARCHAR2,
        pv_attribute14              IN VARCHAR2,
        pv_attribute15              IN VARCHAR2,
        pv_attribute16              IN VARCHAR2,
        pv_attribute17              IN VARCHAR2,
        pv_attribute18              IN VARCHAR2,
        pv_attribute19              IN VARCHAR2,
        pv_attribute21              IN VARCHAR2,
        pv_attribute22              IN VARCHAR2,
        pv_attribute23              IN VARCHAR2,
        pv_attribute24              IN VARCHAR2,
        pv_attribute25              IN VARCHAR2,
        pv_attribute26              IN VARCHAR2,
        pv_attribute27              IN VARCHAR2,
        pv_attribute28              IN VARCHAR2,
        pv_attribute29              IN VARCHAR2,
        pv_attribute30              IN VARCHAR2/* End of Changes as a part of CCR0007341*/
                                               );
END XXDO_APINV_UPLOAD_PKG;
/
