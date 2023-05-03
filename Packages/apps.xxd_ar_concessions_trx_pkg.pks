--
-- XXD_AR_CONCESSIONS_TRX_PKG  (Package) 
--
--  Dependencies: 
--   AR_INVOICE_API_PUB (Package)
--   FND_API (Package)
--   XXD_AR_CONC_TBL_VARCHAR2 (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:18:49 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_AR_CONCESSIONS_TRX_PKG"
AS
    --  ####################################################################################################
    --  Author(s)       : Kranthi Bollam (Suneratech Consultant)
    --  System          : Oracle Applications
    --  Subsystem       : EBS
    --  Change          : ENHC0013435(CCR0007174)
    --  Schema          : APPS
    --  Purpose         : Package is used to create AR transactions for the Concession Stores sales
    --  Dependency      : None
    --  Change History
    --  --------------
    --  Date            Name                Ver     Change          Description
    --  ----------      --------------      -----   -------------   ---------------------
    --  15-May-2018     Kranthi Bollam      1.0     NA              Initial Version
    --  06-Aug-2018     Kranthi Bollam      1.1     UAT Defect#13   Transactions to be created for Closed
    --                                                              period Dates records with current open
    --                                                              period date
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

    PROCEDURE proc_ar_trx_main (
        pv_errbuf               OUT VARCHAR2,
        pn_retcode              OUT NUMBER,
        pv_mode              IN     VARCHAR2,
        pv_version           IN     VARCHAR2,
        pv_as_of_date        IN     VARCHAR2,
        pv_store_number      IN     VARCHAR2,
        pv_brand             IN     VARCHAR2,
        pv_trx_date_from     IN     VARCHAR2,
        pv_trx_date_to       IN     VARCHAR2,
        pv_reprocess_flag    IN     VARCHAR2 DEFAULT 'N',
        pv_use_curr_per_dt   IN     VARCHAR2 DEFAULT 'N' --Added for change 1.1
                                                        );

    PROCEDURE proc_process_stg_data (x_ret_msg   OUT VARCHAR2,
                                     x_ret_sts   OUT NUMBER);

    PROCEDURE create_ar_trxns (pn_org_id IN NUMBER, p_batch_source_rec IN ar_invoice_api_pub.batch_source_rec_type, p_trx_header_tbl IN ar_invoice_api_pub.trx_header_tbl_type, p_trx_lines_tbl IN ar_invoice_api_pub.trx_line_tbl_type, p_trx_dist_tbl IN ar_invoice_api_pub.trx_dist_tbl_type, p_trx_salescredits_tbl IN ar_invoice_api_pub.trx_salescredits_tbl_type
                               , x_customer_trx_id OUT NUMBER, x_ret_sts OUT VARCHAR2, x_ret_msg OUT VARCHAR2);

    PROCEDURE upd_ar_trx_det_to_stg (pn_customer_trx_id IN NUMBER, x_ret_msg OUT VARCHAR2, x_ret_sts OUT NUMBER);

    PROCEDURE upd_errors_to_stg (
        pn_int_hdr_id      IN     NUMBER,
        p_trx_lines_tbl    IN     ar_invoice_api_pub.trx_line_tbl_type,
        pv_error_message   IN     VARCHAR2,
        x_ret_msg             OUT VARCHAR2,
        x_ret_sts             OUT NUMBER);

    FUNCTION replace_text (p_text    IN VARCHAR2,
                           p_parse   IN xxd_ar_conc_tbl_varchar2)
        RETURN VARCHAR2;

    FUNCTION get_calculated_amt (pv_program_mode      IN VARCHAR2,
                                 pn_store_number      IN NUMBER,
                                 pv_brand             IN VARCHAR2,
                                 pn_org_id            IN NUMBER,
                                 pn_retail_amount     IN NUMBER,
                                 pn_discount_amount   IN NUMBER,
                                 pn_paytotal_amount   IN NUMBER,
                                 pn_tax_amount        IN NUMBER)
        RETURN NUMBER;

    --Added for change 1.1
    FUNCTION get_period_status (pn_org_id            IN NUMBER,
                                pv_trx_period_name   IN VARCHAR2)
        RETURN NUMBER;

    --Added for change 1.1
    PROCEDURE get_next_open_period (pn_org_id                  IN     NUMBER,
                                    pd_trx_per_end_dt          IN     DATE,
                                    x_next_open_per_name          OUT VARCHAR2,
                                    x_next_open_per_start_dt      OUT DATE,
                                    x_next_open_per_end_dt        OUT DATE);
END xxd_ar_concessions_trx_pkg;
/
