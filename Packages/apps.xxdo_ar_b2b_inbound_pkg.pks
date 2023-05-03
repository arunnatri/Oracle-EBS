--
-- XXDO_AR_B2B_INBOUND_PKG  (Package) 
--
--  Dependencies: 
--   AR_CASH_RECEIPTS (Synonym)
--   AR_RECEIVABLE_APPLICATIONS (Synonym)
--   FND_API (Package)
--   FND_GLOBAL (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:15:02 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_AR_B2B_INBOUND_PKG"
/***************************************************************************************
* Program Name : XXDO_AR_B2B_INBOUND_PKG                                               *
* Language     : PL/SQL                                                                *
* Description  : Package to Consume and Process Inbound files for B2B Portal           *
*                integration                                                           *
* History      :                                                                       *
*                                                                                      *
* WHO          :       WHAT      Desc                                    WHEN          *
* -------------- ----------------------------------------------------------------------*
* Madhav Dhurjaty      1.0      Initial Version                         06-DEC-2017    *
* Madhav Dhurjaty      2.0      B2B Phase 2 EMEA Changes(CCR0006692)    28-MAY-2018    *
* -------------------------------------------------------------------------------------*/
AS
    --Global Constants
    -- Return Statuses
    gv_ret_success          CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_success;
    gv_ret_error            CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_error;
    gv_ret_unexp_error      CONSTANT VARCHAR2 (1)
                                         := fnd_api.g_ret_sts_unexp_error ;
    gv_ret_warning          CONSTANT VARCHAR2 (1) := 'W';
    gn_success              CONSTANT NUMBER := 0;
    gn_warning              CONSTANT NUMBER := 1;
    gn_error                CONSTANT NUMBER := 2;
    gn_conc_request_id      CONSTANT NUMBER := FND_GLOBAL.CONC_REQUEST_ID;

    gn_grace_days                    NUMBER DEFAULT 0;

    gc_ded_code_delimiter   CONSTANT VARCHAR2 (1) := ',';

    gn_debug_level                   NUMBER DEFAULT 1;

    ----
    ----
    ---- Procedure to send notifications
    ----
    PROCEDURE send_notification (p_program_name IN VARCHAR2, p_log_or_out IN VARCHAR2 DEFAULT NULL, p_conc_request_id IN NUMBER
                                 , p_email_lkp_name IN VARCHAR2, x_ret_code OUT NUMBER, x_ret_message OUT VARCHAR2);

    ----
    ----
    ---- Procedure to Create Receipt Batches
    ----
    PROCEDURE create_receipt_batch (
        p_org_id               IN     NUMBER,
        p_Batch_Source_ID      IN     NUMBER,
        p_Bank_Branch_ID       IN     NUMBER,
        p_Batch_Type           IN     VARCHAR2,
        p_Currency_Code        IN     VARCHAR2,
        p_Bank_Account_ID      IN     VARCHAR2,
        p_Batch_Date           IN     DATE,
        p_Receipt_Class_ID     IN     NUMBER,
        p_Control_Count        IN     NUMBER,
        p_GL_Date              IN     DATE,
        p_Receipt_Method_ID    IN     NUMBER,
        p_Control_Amount       IN     NUMBER,
        p_Deposit_Date         IN     DATE,
        p_lockbox_batch_name   IN     VARCHAR2,
        p_Comments             IN     VARCHAR2,
        p_auto_commit          IN     VARCHAR2 := 'Y',
        x_Batch_ID                OUT NUMBER,
        x_Batch_Name              OUT VARCHAR2,
        x_ret_code                OUT NUMBER,
        x_ret_message             OUT VARCHAR2);

    ----
    ----
    ---- Procedure to Create Receipts
    ---- calls the public API AR_RECEIPT_API_PUB
    PROCEDURE create_receipt (
        p_Batch_ID                   IN     NUMBER,
        p_Receipt_Number             IN     VARCHAR2,
        p_Receipt_Amt                IN     NUMBER,
        p_Transaction_Num            IN     VARCHAR2 := APPS.Fnd_Api.G_MISS_CHAR,
        p_Customer_Number            IN     VARCHAR2 := APPS.Fnd_Api.G_MISS_CHAR,
        p_Customer_Name              IN     VARCHAR2 := APPS.Fnd_Api.G_MISS_CHAR,
        p_customer_id                IN     NUMBER DEFAULT NULL,
        p_Comments                   IN     VARCHAR2 := APPS.Fnd_Api.G_MISS_CHAR,
        p_Payment_Server_Order_Num   IN     VARCHAR2 := APPS.Fnd_Api.G_MISS_CHAR,
        p_Currency_Code              IN     VARCHAR2,
        p_Location                   IN     VARCHAR2 := APPS.Fnd_Api.G_MISS_CHAR,
        p_bill_to_site_use_id        IN     NUMBER DEFAULT NULL,
        p_receipt_date               IN     DATE DEFAULT NULL,
        p_exchange_rate_type         IN     VARCHAR2 DEFAULT NULL,
        p_exchange_rate              IN     NUMBER DEFAULT NULL,
        p_exchange_rate_date         IN     DATE DEFAULT NULL,
        p_auto_commit                IN     VARCHAR2 DEFAULT 'Y',
        x_cash_receipt_id               OUT NUMBER,
        x_ret_code                      OUT NUMBER,
        x_ret_message                   OUT VARCHAR2);

    ----
    ----
    ---- Procedure to apply receipt to transaction
    ---- calls the public API AR_RECEIPT_API_PUB
    PROCEDURE apply_transaction (p_Cash_Receipt_ID IN NUMBER--p_Receipt_Number         IN VARCHAR2
                                                            , p_Customer_Trx_ID IN NUMBER, p_Trx_Number IN VARCHAR2, p_Applied_Amt IN NUMBER, p_Discount IN NUMBER--,p_Apply_Date             IN DATE
                                                                                                                                                                  --,p_GL_Date                IN DATE
                                                                                                                                                                  , p_customer_reference IN VARCHAR2 DEFAULT NULL
                                 , p_auto_commit IN VARCHAR2 DEFAULT 'Y', x_ret_code OUT NUMBER, x_ret_message OUT VARCHAR2);

    ----
    ----
    ---- Procedure to apply receipt on account
    ---- calls the public API AR_RECEIPT_API_PUB
    PROCEDURE apply_on_account (p_Cash_Receipt_ID IN NUMBER, p_Amt_Applied IN NUMBER, p_customer_id IN NUMBER, p_apply_date IN DATE, p_customer_reference IN VARCHAR2 DEFAULT NULL, x_ret_code OUT NUMBER
                                , x_ret_message OUT VARCHAR2);

    ----
    ----
    ---- Procedure to unapply receipt on account
    ---- calls the public API AR_RECEIPT_API_PUB
    PROCEDURE unapply_on_account (p_org_id           IN     NUMBER,
                                  p_customer_id      IN     NUMBER,
                                  p_receipt_number   IN     VARCHAR2,
                                  x_ret_code            OUT NUMBER,
                                  x_ret_message         OUT VARCHAR2);

    ----
    ----
    ---- Procedure to TRX based claims
    ----
    PROCEDURE create_trx_claim (
        p_org_id               IN     NUMBER,
        p_receivable_app_id    IN     NUMBER,
        p_amount               IN     NUMBER,
        p_reason               IN     VARCHAR2,
        p_customer_reference   IN     VARCHAR2 DEFAULT NULL,
        x_deduction_number        OUT VARCHAR2,
        x_ret_code                OUT NUMBER,
        x_ret_message             OUT VARCHAR2);

    ----
    ----
    ---- Procedure to create misc receipt
    ---- calls the public API AR_RECEIPT_API_PUB
    PROCEDURE create_misc (
        p_org_id              IN            NUMBER,
        p_batch_id            IN            NUMBER,
        p_currency_code       IN            VARCHAR2,
        p_amount              IN            NUMBER,
        p_receipt_date        IN            DATE,
        p_gl_date             IN            DATE,
        p_receipt_method_id   IN            NUMBER,
        p_activity            IN            VARCHAR2,
        p_comments            IN            VARCHAR2 DEFAULT NULL,
        p_receipt_number      IN OUT NOCOPY VARCHAR2,
        p_auto_commit         IN            VARCHAR2 DEFAULT 'Y',
        x_misc_receipt_id        OUT        NUMBER,
        x_ret_code               OUT        NUMBER,
        x_ret_message            OUT        VARCHAR2);


    ----
    ----
    ---- Procedure to get reason code id
    ---- takes the BT deduction code
    PROCEDURE get_reason_code_id (p_org_id IN NUMBER, p_reason_code IN VARCHAR2, p_amount IN NUMBER
                                  , x_reason_code_id OUT NUMBER, x_ret_code OUT NUMBER, x_ret_message OUT VARCHAR2);

    ----
    ----
    ---- Procedure to get receivables trxid
    ---- used for claim investigation creation
    PROCEDURE get_receivables_trx_id (p_customer_id IN NUMBER, p_org_id IN NUMBER, p_type IN VARCHAR2 DEFAULT 'CLAIM_INVESTIGATION'
                                      , x_receivables_trx_id OUT NUMBER, x_ret_code OUT NUMBER, x_ret_message OUT VARCHAR2);

    ----
    ----
    ---- Procedure to process surcharge
    ---- creates receipt write-off
    PROCEDURE activity_application (
        p_cash_receipt_id             IN     NUMBER,
        p_receivables_trx_id          IN     NUMBER,
        p_amount_applied              IN     NUMBER,
        p_apply_date                  IN     DATE,
        p_customer_reference          IN     VARCHAR2 DEFAULT NULL,
        x_receivable_application_id      OUT NUMBER,
        x_ret_code                       OUT NUMBER,
        x_ret_message                    OUT VARCHAR2);

    ----
    ----
    ---- Procedure to process deductions
    ---- creates non-trx based deductions
    PROCEDURE apply_other_account (p_reason_code IN VARCHAR2, p_customer_id IN NUMBER, p_org_id IN NUMBER DEFAULT NULL, p_type IN VARCHAR2, p_cash_receipt_id IN ar_cash_receipts.cash_receipt_id%TYPE DEFAULT NULL, p_receipt_number IN ar_cash_receipts.receipt_number%TYPE DEFAULT NULL, p_amount_applied IN ar_receivable_applications.amount_applied%TYPE DEFAULT NULL, --p_receivables_trx_id               IN  ar_receivable_applications.receivables_trx_id%TYPE DEFAULT NULL,
                                                                                                                                                                                                                                                                                                                                                                             p_applied_payment_schedule_id IN ar_receivable_applications.applied_payment_schedule_id%TYPE DEFAULT NULL, p_apply_date IN ar_receivable_applications.apply_date%TYPE DEFAULT NULL, p_apply_gl_date IN ar_receivable_applications.gl_date%TYPE DEFAULT NULL, --p_ussgl_transaction_code           IN  ar_receivable_applications.ussgl_transaction_code%TYPE DEFAULT NULL,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          p_application_ref_type IN ar_receivable_applications.application_ref_type%TYPE DEFAULT NULL, p_application_ref_id IN OUT NOCOPY ar_receivable_applications.application_ref_id%TYPE, p_application_ref_num IN OUT NOCOPY ar_receivable_applications.application_ref_num%TYPE, p_secondary_application_ref_id IN OUT NOCOPY ar_receivable_applications.secondary_application_ref_id%TYPE, p_payment_set_id IN ar_receivable_applications.payment_set_id%TYPE DEFAULT NULL, p_comments IN ar_receivable_applications.comments%TYPE DEFAULT NULL, --p_application_ref_reason           IN  ar_receivable_applications.application_ref_reason%TYPE DEFAULT NULL,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        p_customer_reference IN ar_receivable_applications.customer_reference%TYPE DEFAULT NULL, p_customer_reason IN ar_receivable_applications.customer_reason%TYPE DEFAULT NULL, p_called_from IN VARCHAR2 DEFAULT NULL, x_receivable_application_id OUT NOCOPY ar_receivable_applications.receivable_application_id%TYPE, x_ret_code OUT NUMBER
                                   , x_ret_message OUT VARCHAR2);

    ----
    ----
    ---- Procedure for payment netting
    ----
    PROCEDURE apply_open_receipt (p_org_id IN NUMBER, p_customer_id IN NUMBER, p_cash_receipt_id IN NUMBER DEFAULT NULL, p_receipt_number IN VARCHAR2, p_open_cash_receipt_id IN NUMBER DEFAULT NULL, p_open_receipt_number IN VARCHAR2, p_amount_applied IN NUMBER, p_apply_date IN DATE, p_comments IN VARCHAR2 DEFAULT NULL
                                  , x_receivable_application_id OUT NUMBER, x_ret_code OUT NUMBER, x_ret_message OUT VARCHAR2);

    ----
    ---- Procedure to process valid cashapp data in the staging
    ---- processes valid cashapp data
    ---- used as the Cashapp program from SRS
    PROCEDURE process_cashapp_data (
        errbuf                   OUT NUMBER,
        retcode                  OUT VARCHAR2,
        p_org_id              IN     NUMBER,
        p_bt_job_id           IN     NUMBER,
        p_receipt_date_from   IN     VARCHAR2,
        p_receipt_date_to     IN     VARCHAR2,
        p_load_request_id     IN     NUMBER,
        p_grace_days          IN     NUMBER DEFAULT 0,
        --p_receipt_method    IN  VARCHAR2 ,
        --p_receipt_type      IN  VARCHAR2 ,
        --p_receipt_num       IN  VARCHAR2 ,
        --p_bank_account      IN  VARCHAR2 ,
        --p_receipt_date_from IN  VARCHAR2 ,
        --p_customer          IN  VARCHAR2 ,
        --p_currency          IN  VARCHAR2 ,
        p_reprocess_flag      IN     VARCHAR2,
        p_inbound_filename    IN     VARCHAR2,
        p_debug_mode          IN     VARCHAR2--p_file_path         IN  VARCHAR2,

                                             );

    ----
    ----
    ---- Procedure to call the host program which
    ---- loads the file data into staging table using SQLLDR
    ---- submitted as a program from SRS
    PROCEDURE load_cashapp_file (p_filepath IN VARCHAR2, x_ret_code OUT NUMBER, x_ret_message OUT VARCHAR2);

    ----
    ----
    ---- Main Procedure called from SRS
    ---- Calls the loader, cash app and notification programs
    PROCEDURE cashapp_main (errbuf                   OUT NUMBER,
                            retcode                  OUT VARCHAR2,
                            p_org_id              IN     NUMBER,
                            p_bt_job_id           IN     VARCHAR2,
                            p_receipt_method_id   IN     NUMBER,
                            p_receipt_type        IN     VARCHAR2,
                            p_receipt_num         IN     VARCHAR2,
                            p_bank_account_id     IN     NUMBER,
                            p_receipt_date_from   IN     VARCHAR2,
                            p_receipt_date_to     IN     VARCHAR2,
                            p_customer_id         IN     VARCHAR2,
                            p_currency            IN     VARCHAR2,
                            p_grace_days          IN     NUMBER,
                            p_reprocess_flag      IN     VARCHAR2,
                            p_inbound_filename    IN     VARCHAR2,
                            p_debug_mode          IN     VARCHAR2,
                            p_file_path           IN     VARCHAR2);
END xxdo_ar_b2b_inbound_pkg;
/
