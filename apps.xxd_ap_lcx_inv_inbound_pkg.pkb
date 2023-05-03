--
-- XXD_AP_LCX_INV_INBOUND_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:46 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AP_LCX_INV_INBOUND_PKG"
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
      * 1.2     31-MAR-2020  Srinath Siricilla    UAT Defect# 27                       *
      * 2.0     05-NOV-2020  Srinath Siricilla     CCR0008507 - MTD Changes            *
      *********************************************************************************/
    gn_user_id             NUMBER := fnd_global.user_id;
    gn_resp_id             NUMBER := fnd_global.resp_id;
    gn_resp_appl_id        NUMBER := fnd_global.resp_appl_id;
    gn_request_id          NUMBER := fnd_global.conc_request_id;
    gn_sob_id              NUMBER := fnd_profile.VALUE ('GL_SET_OF_BKS_ID');
    gn_org_id              NUMBER := fnd_profile.VALUE ('ORG_ID');
    gn_login_id            NUMBER := fnd_global.login_id;
    gd_sysdate             DATE := SYSDATE;
    gn_created_by          NUMBER := fnd_global.user_id;
    gn_last_updated_by     NUMBER := fnd_global.login_id;
    gn_last_update_login   NUMBER := fnd_global.login_id;

    PROCEDURE main (x_retcode OUT NOCOPY VARCHAR2, x_errbuf OUT NOCOPY VARCHAR2, p_file_name IN VARCHAR2, p_invoice_number IN VARCHAR2, p_vendor_number IN NUMBER, p_vendor_site IN VARCHAR2
                    , p_invoice_date_from IN VARCHAR2, p_invoice_date_to IN VARCHAR2, p_reprocess IN VARCHAR2)
    IS
        l_ret_code            VARCHAR2 (10);
        l_err_msg             VARCHAR2 (4000);
        ex_load_interface     EXCEPTION;
        ex_create_invoices    EXCEPTION;
        ex_val_staging        EXCEPTION;
        ex_email_out          EXCEPTION;
        ex_check_data         EXCEPTION;
        ex_insert_stg         EXCEPTION;
        ex_sae_data           EXCEPTION;
        ex_display_data       EXCEPTION;
        lc_err_message        VARCHAR2 (100);
        l_invoice_date_from   DATE;
        l_invoice_date_to     DATE;
    BEGIN
        l_invoice_date_from   :=
            fnd_date.canonical_to_date (p_invoice_date_from);
        l_invoice_date_to   := fnd_date.canonical_to_date (p_invoice_date_to);
        fnd_file.put_line (fnd_file.LOG, ' p_file_name  :- ' || p_file_name);
        fnd_file.put_line (fnd_file.LOG,
                           ' p_invoice_number  :- ' || p_invoice_number);
        fnd_file.put_line (fnd_file.LOG,
                           ' p_vendor_number  :- ' || p_vendor_number);
        fnd_file.put_line (fnd_file.LOG,
                           ' p_vendor_site  :- ' || p_vendor_site);
        fnd_file.put_line (
            fnd_file.LOG,
            ' p_invoice_date_from  :- ' || l_invoice_date_from);
        fnd_file.put_line (fnd_file.LOG,
                           ' p_invoice_date_to  :- ' || l_invoice_date_to);
        fnd_file.put_line (fnd_file.LOG, ' p_reprocess  :- ' || p_reprocess);

        IF NVL (p_reprocess, 'N') = 'N'
        THEN
            ------------------------------------------
            ---  Step 1 ----
            --  insert data into staging table -----
            -----------------------------------------
            insert_staging (l_ret_code, l_err_msg, p_file_name,
                            p_invoice_number, p_vendor_number, p_vendor_site,
                            l_invoice_date_from, l_invoice_date_to);
            fnd_file.put_line (fnd_file.LOG,
                               ' Inserted data into Staging Table ');

            IF l_ret_code = '2'
            THEN
                ---- failure while inserting data into stg table;
                ---- raise the expcetion and come out of the block;
                ---- no need for any futher processing
                RAISE ex_insert_stg;
            END IF;
        ELSE  --  REPROCESS CASE; update the stating table with new request id
            update_staging (l_ret_code, l_err_msg, p_file_name,
                            p_invoice_number, p_vendor_number, p_vendor_site,
                            l_invoice_date_from, l_invoice_date_to);

            IF l_ret_code = '2'
            THEN
                ---- failure while updating data into stg table;
                ---- raise the expcetion and come out of the block;
                ---- no need for any futher processing
                RAISE ex_insert_stg;
            END IF;
        END IF;

        ------------------------------------------
        ---  Step 2 ----
        --  data successfully inserted into the stg table with current request id
        --  this is going to validate all the records inserted for the given request id
        -- lets validate the data for business case validation
        -----------------------------------------

        validate_staging (l_ret_code, l_err_msg, p_reprocess);

        IF l_ret_code = '2'
        THEN
            --  unexpected exception while validating data.
            RAISE ex_val_staging;
        END IF;

        fnd_file.put_line (fnd_file.LOG,
                           ' Validating Staging Data activity is complete ');

        -------clear interface table for orphan errors----------------
        clear_int_tables;

        ------------------load data into staging table-----------------
        load_interface (x_ret_code => l_ret_code, x_ret_msg => l_err_msg);
        fnd_file.put_line (fnd_file.LOG,
                           ' Loading to Interface activity is complete ');

        IF l_ret_code = '2'
        THEN
            RAISE ex_load_interface;
        END IF;

        ------------ create invoice  ------------------
        create_invoices (x_ret_code => l_ret_code, x_ret_msg => l_err_msg);

        fnd_file.put_line (fnd_file.LOG,
                           ' Invoice creation activity is complete ');

        IF l_ret_code = '2'
        THEN
            RAISE ex_create_invoices;
        END IF;

        check_data (x_ret_code => l_ret_code, x_ret_msg => l_err_msg);

        fnd_file.put_line (fnd_file.LOG,
                           ' Data Verification activity is complete ');

        IF l_ret_code = '2'
        THEN
            RAISE ex_check_data;
        END IF;

        ---------- update SOA table with status

        update_soa_data (x_ret_code => l_ret_code, x_ret_msg => l_err_msg);

        fnd_file.put_line (
            fnd_file.LOG,
            ' Updating SOA staging table activity is complete ');

        IF l_ret_code = '2'
        THEN
            RAISE ex_sae_data;
        END IF;
    /*
    display_data (x_ret_code => l_ret_code,
                  x_ret_msg  => l_err_msg);
    */
    EXCEPTION
        WHEN ex_insert_stg
        THEN
            x_retcode   := l_ret_code;
            x_errbuf    := l_err_msg;
            fnd_file.put_line (
                fnd_file.LOG,
                'Error Inserting data into Staging:' || l_err_msg);
        WHEN ex_val_staging
        THEN
            x_retcode   := l_ret_code;
            x_errbuf    := l_err_msg;
            fnd_file.put_line (fnd_file.LOG,
                               'Error Validating Staging Data:' || l_err_msg);
        WHEN ex_load_interface
        THEN
            x_retcode   := l_ret_code;
            x_errbuf    := l_err_msg;
            fnd_file.put_line (
                fnd_file.LOG,
                'Error Populating AP_INTERFACE tables:' || l_err_msg);
        WHEN ex_create_invoices
        THEN
            x_retcode   := l_ret_code;
            x_errbuf    := l_err_msg;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Submitting Program - Payables Import program :'
                || l_err_msg);
        WHEN ex_check_data
        THEN
            x_retcode   := l_ret_code;
            x_errbuf    := l_err_msg;
            fnd_file.put_line (
                fnd_file.LOG,
                'Error while checking Invoice created:' || l_err_msg);
        WHEN ex_sae_data
        THEN
            x_retcode   := l_ret_code;
            x_errbuf    := l_err_msg;
            fnd_file.put_line (
                fnd_file.LOG,
                'Error while updating SOA staging table data:' || l_err_msg);
        WHEN ex_display_data
        THEN
            x_retcode   := l_ret_code;
            x_errbuf    := l_err_msg;
            fnd_file.put_line (
                fnd_file.LOG,
                'Error while displaying output data:' || l_err_msg);
        WHEN OTHERS
        THEN
            x_retcode   := '2';
            x_errbuf    := SQLERRM;
            fnd_file.put_line (fnd_file.LOG, 'Error in main:' || SQLERRM);
    END main;

    -- Procedure to Insert data into  Staging table with new request id

    PROCEDURE insert_staging (x_ret_code               OUT NOCOPY VARCHAR2,
                              x_ret_msg                OUT NOCOPY VARCHAR2,
                              p_file_name           IN            VARCHAR2,
                              p_invoice_number      IN            VARCHAR2,
                              p_vendor_number       IN            NUMBER,
                              p_vendor_site         IN            VARCHAR2,
                              p_invoice_date_from   IN            DATE,
                              p_invoice_date_to     IN            DATE)
    IS
        l_count   NUMBER := 0;

        --  fetech all new records from SOA table i.e. status is N, request id /error message is null

        CURSOR hdr_line_cur IS
            SELECT *
              FROM xxdo.xxd_ap_lcx_invoices_t
             WHERE     1 = 1
                   AND NVL (status, 'N') = 'N'
                   AND file_name = NVL (p_file_name, file_name)
                   AND NVL (invoice_number, '-99') =
                       NVL (p_invoice_number, NVL (invoice_number, '-99'))
                   AND NVL (vendor_number, '-99') =
                       NVL (p_vendor_number, NVL (vendor_number, '-99'))
                   AND NVL (supplier_site_code, '-99') =
                       NVL (p_vendor_site, NVL (supplier_site_code, '-99'))
                   --Commented and  Added as per 1.1
                   -- making sure there wont be any orphan records leftin SOA staging table
                   AND NVL (invoice_date, SYSDATE) BETWEEN COALESCE (
                                                               p_invoice_date_from,
                                                               invoice_date,
                                                               SYSDATE)
                                                       AND COALESCE (
                                                               p_invoice_date_to,
                                                               invoice_date,
                                                               SYSDATE)
                   --                AND invoice_date BETWEEN NVL (p_invoice_date_from,
                   --                                              invoice_date)
                   --                                     AND NVL (p_invoice_date_to,
                   --                                              invoice_date)
                   -- End of Change
                   AND request_id IS NULL
                   AND error_msg IS NULL;
    BEGIN
        --- Loop and insert the data in oracle staging table
        FOR inv_rec IN hdr_line_cur
        LOOP
            BEGIN
                INSERT INTO xxdo.xxd_ap_lcx_invoices_stg_t (
                                record_id,
                                file_name,
                                file_processed_date,
                                status,
                                error_msg,
                                po_number_h,
                                request_id,
                                invoice_number,
                                operating_unit,
                                trading_partner,
                                vendor_number,
                                supplier_site_code,
                                invoice_date,
                                invoice_amount,
                                currency_code,
                                invoice_description,
                                vendor_charged_tax,
                                tax_control_amt,
                                fapio_received,
                                line_type,
                                line_description,
                                line_amount,
                                distribution_acct,
                                ship_to,
                                po_number,
                                po_line_number,
                                quantity_invoiced,
                                unit_price,
                                tax_classification_code,
                                interco_exp_account,
                                deferred,
                                deferred_start_date,
                                deferred_end_date,
                                prorate_accros_all_item_lines,
                                track_as_asset,
                                asset_category,
                                approver,
                                date_sent_approver,
                                misc_notes,
                                chargeback,
                                invoice_number_d,
                                payment_ref_number,
                                sample_invoice,
                                asset_book,
                                distribution_set,
                                payment_terms,
                                invoice_add_info,
                                pay_alone,
                                creation_date,
                                created_by,
                                last_update_date,
                                last_updated_by,
                                last_update_login)
                     VALUES (inv_rec.record_id, TRIM (inv_rec.file_name), TRIM (inv_rec.file_processed_date), g_new, '', TRIM (inv_rec.po_number_h), gn_request_id, TRIM (inv_rec.invoice_number), TRIM (inv_rec.operating_unit), TRIM (inv_rec.trading_partner), TRIM (inv_rec.vendor_number), TRIM (inv_rec.supplier_site_code), TRIM (inv_rec.invoice_date), inv_rec.invoice_amount, inv_rec.currency_code, SUBSTRB (TRIM (inv_rec.invoice_description), 1, 239), inv_rec.vendor_charged_tax, inv_rec.tax_control_amt, inv_rec.fapio_received, inv_rec.line_type, SUBSTRB (TRIM (inv_rec.line_description), 1, 239), inv_rec.line_amount, inv_rec.distribution_acct, inv_rec.ship_to, inv_rec.po_number, inv_rec.po_line_number, inv_rec.quantity_invoiced, inv_rec.unit_price, inv_rec.tax_classification_code, inv_rec.interco_exp_account, inv_rec.deferred, inv_rec.deferred_start_date, inv_rec.deferred_end_date, inv_rec.prorate_accros_all_item_lines, inv_rec.track_as_asset, inv_rec.asset_category, inv_rec.approver, inv_rec.date_sent_approver, inv_rec.misc_notes, inv_rec.chargeback, inv_rec.invoice_number_d, inv_rec.payment_ref_number, inv_rec.sample_invoice, inv_rec.asset_book, inv_rec.distribution_set, inv_rec.payment_terms, inv_rec.invoice_add_info, inv_rec.pay_alone, SYSDATE, gn_created_by, SYSDATE
                             , gn_last_updated_by, gn_last_update_login);

                l_count   := l_count + 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_code   := '2';
                    x_ret_msg    :=
                           'Exception while Inserting the staging Data : '
                        || SUBSTR (SQLERRM, 1, 200);
            END;
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
            'Number of record inserted into the Stg table:' || l_count);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code   := '2';
            x_ret_msg    :=
                   'Exception while Inserting the staging Data : '
                || SUBSTR (SQLERRM, 1, 200);
    END insert_staging;

    -- Procedure to udpate  Staging table with new request id for the reprocess status.
    -- it is needed as the error records would be having old request id becx of last exection

    PROCEDURE update_staging (x_ret_code               OUT NOCOPY VARCHAR2,
                              x_ret_msg                OUT NOCOPY VARCHAR2,
                              p_file_name           IN            VARCHAR2,
                              p_invoice_number      IN            VARCHAR2,
                              p_vendor_number       IN            NUMBER,
                              p_vendor_site         IN            VARCHAR2,
                              p_invoice_date_from   IN            DATE,
                              p_invoice_date_to     IN            DATE)
    IS
    BEGIN
        UPDATE xxdo.xxd_ap_lcx_invoices_stg_t
           SET request_id = gn_request_id, status = g_new
         WHERE     status = 'E'              --- need to verify this condtion;
               AND file_name = NVL (p_file_name, file_name)
               AND NVL (invoice_number, '-99') =
                   NVL (p_invoice_number, NVL (invoice_number, '-99'))
               AND NVL (vendor_number, '-99') =
                   NVL (p_vendor_number, NVL (vendor_number, '-99'))
               AND NVL (supplier_site_code, '-99') =
                   NVL (p_vendor_site, NVL (supplier_site_code, '-99'))
               -- Added as per change 1.1
               -- making sure there wont be any orphan records leftin SOA staging table
               AND NVL (invoice_date, SYSDATE) BETWEEN COALESCE (
                                                           p_invoice_date_from,
                                                           invoice_date,
                                                           SYSDATE)
                                                   AND COALESCE (
                                                           p_invoice_date_to,
                                                           invoice_date,
                                                           SYSDATE);

        --             AND invoice_date BETWEEN NVL (p_invoice_date_from, invoice_date)
        --                                  AND NVL (p_invoice_date_to, invoice_date); -- YET TO HANDLE NVL CONDITION
        -- End of change

        fnd_file.put_line (
            fnd_file.LOG,
            'Number of Record updated for Re-processing:' || SQL%ROWCOUNT);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code   := '2';
            x_ret_msg    :=
                   'Exception while updating the staging Data for reprocess case: '
                || SUBSTR (SQLERRM, 1, 200);
    END update_staging;

    PROCEDURE validate_staging (x_ret_code OUT NOCOPY VARCHAR2, x_ret_msg OUT NOCOPY VARCHAR2, p_reprocess IN VARCHAR2)
    IS
        l_msg                 VARCHAR2 (4000);
        l_ret_msg             VARCHAR2 (4000) := NULL;
        --ln_seq                NUMBER;
        l_boolean             BOOLEAN;
        l_boolean1            BOOLEAN;
        l_hdr_count           NUMBER := 0;
        l_lin_count           NUMBER := 0;
        l_line_num            NUMBER;
        l_unique_seq          VARCHAR2 (100);
        lc_err_message        VARCHAR2 (4000);
        l_status              VARCHAR2 (1);
        l_po_header_inv_id    NUMBER;
        l_valid_org           NUMBER;
        l_resp_id             NUMBER;

        --header variables
        l_org_id              NUMBER;
        l_vendor_id           NUMBER;
        l_vendor_name         VARCHAR2 (100);
        l_site_id             NUMBER;
        l_pay_code            VARCHAR2 (50);
        l_terms_id            NUMBER;
        l_hdr_date            DATE;
        l_gl_date             DATE;
        l_invoice_id          NUMBER;
        l_invoice_amt         NUMBER;
        l_curr_code           VARCHAR2 (30);
        l_asset_book          VARCHAR2 (100);
        l_asset_cat_id        NUMBER;
        l_tax_control_amt     NUMBER;
        l_sample_inv_flag     VARCHAR2 (10);
        l_invoice_type        VARCHAR2 (100);
        l_email               VARCHAR2 (100);
        l_user_entered_tax    VARCHAR2 (100);
        l_fapio_flag          VARCHAR2 (10);
        l_pay_alone_flag      VARCHAR2 (10);
        ln_count_terms        NUMBER := 0;
        ln_count_pay_flag     NUMBER := 0;


        --line variables
        l_dist_acct_id        NUMBER;
        l_ship_to_code        VARCHAR2 (50);
        l_ship_to_loc_id      NUMBER;
        l_po_header_id        NUMBER;
        l_po_line_id          NUMBER;
        l_dist_set_id         NUMBER;
        l_line_type           VARCHAR2 (50);
        l_total_line_amount   NUMBER := 0;
        l_line_amt            NUMBER;
        l_invoice_line_id     NUMBER;
        l_vtx_prod_class      VARCHAR2 (150);
        l_interco_acct_id     NUMBER;
        l_deferred_flag       VARCHAR2 (10);
        l_prorate_flag        VARCHAR2 (10);
        l_asset_flag          VARCHAR2 (10);
        l_def_end_date        DATE;
        l_def_start_date      DATE;
        l_unit_price          NUMBER;
        l_tax_code            VARCHAR2 (100);
        l_valid_out           VARCHAR2 (100);


        CURSOR valdiate_stg_line IS
            SELECT *
              FROM xxdo.xxd_ap_lcx_invoices_stg_t
             WHERE 1 = 1 AND request_id = gn_request_id AND status = g_new;
    BEGIN
        FOR line IN valdiate_stg_line
        LOOP
            l_msg                 := NULL;
            l_status              := g_validated; -- set the flag as validated by default
            -- Start of Change 1.2
            l_ret_msg             := NULL;
            l_boolean             := NULL;
            l_boolean1            := NULL;
            l_hdr_count           := 0;
            l_lin_count           := 0;
            l_line_num            := NULL;
            l_unique_seq          := NULL;
            lc_err_message        := NULL;
            l_po_header_inv_id    := NULL;
            l_valid_org           := NULL;
            l_resp_id             := NULL;

            --header variables
            l_org_id              := NULL;
            l_vendor_id           := NULL;
            l_vendor_name         := NULL;
            l_site_id             := NULL;
            l_pay_code            := NULL;
            l_terms_id            := NULL;
            l_hdr_date            := NULL;
            l_gl_date             := NULL;
            l_invoice_id          := NULL;
            l_invoice_amt         := NULL;
            l_curr_code           := NULL;
            l_asset_book          := NULL;
            l_asset_cat_id        := NULL;
            l_tax_control_amt     := NULL;
            l_sample_inv_flag     := NULL;
            l_invoice_type        := NULL;
            l_email               := NULL;
            l_user_entered_tax    := NULL;
            l_fapio_flag          := NULL;
            l_pay_alone_flag      := NULL;
            ln_count_terms        := NULL;
            ln_count_pay_flag     := NULL;


            --line variables
            l_dist_acct_id        := NULL;
            l_ship_to_code        := NULL;
            l_ship_to_loc_id      := NULL;
            l_po_header_id        := NULL;
            l_po_line_id          := NULL;
            l_dist_set_id         := NULL;
            l_line_type           := NULL;
            l_total_line_amount   := NULL;
            l_line_amt            := NULL;
            l_invoice_line_id     := NULL;
            l_vtx_prod_class      := NULL;
            l_interco_acct_id     := NULL;
            l_deferred_flag       := NULL;
            l_prorate_flag        := NULL;
            l_asset_flag          := NULL;
            l_def_end_date        := NULL;
            l_def_start_date      := NULL;
            l_unit_price          := NULL;
            l_tax_code            := NULL;
            l_valid_out           := NULL;

            -- End of Change 1.2

            /*======================*/
            --Get Org ID
            /*======================*/
            IF line.operating_unit IS NOT NULL
            THEN
                l_org_id    := NULL;                       -- added as per 1.2
                l_ret_msg   := NULL;                       -- added as per 1.2
                l_boolean   := NULL;                       -- added as per 1.2
                l_boolean   :=
                    is_org_valid (p_org_name   => line.operating_unit,
                                  x_org_id     => l_org_id,
                                  x_ret_msg    => l_ret_msg);

                IF l_boolean = FALSE OR l_org_id IS NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || ' - ' || l_ret_msg;
                END IF;
            ELSE
                l_msg   := l_msg || ' Operating Unit cannot be NULL ';
            END IF;

            /*======================*/
            --Get Vendor ID
            /*======================*/

            IF line.vendor_number IS NOT NULL
            THEN
                l_boolean       := NULL;
                l_ret_msg       := NULL;
                l_vendor_id     := NULL;                   -- added as per 1.2
                l_vendor_name   := NULL;                   -- added as per 1.2
                l_boolean       :=
                    is_vendor_valid (p_vendor_number => line.vendor_number, x_vendor_name => l_vendor_name, x_vendor_id => l_vendor_id
                                     , x_ret_msg => l_ret_msg);

                IF l_boolean = FALSE OR l_vendor_id IS NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || ' - ' || l_ret_msg;
                END IF;
            ELSE
                l_msg   := l_msg || ' Vendor Number cannot be NULL ';
            END IF;


            /*==================*/
            --Get Vendor Site ID
            /*==================*/

            IF     l_vendor_id IS NOT NULL
               AND line.supplier_site_code IS NOT NULL
            THEN
                l_boolean   := NULL;
                l_ret_msg   := NULL;
                l_site_id   := NULL;                       -- Added as per 1.2
                l_boolean   :=
                    is_site_valid (p_site_code   => line.supplier_site_code,
                                   p_org_id      => l_org_id,
                                   p_vendor_id   => l_vendor_id,
                                   x_site_id     => l_site_id,
                                   x_ret_msg     => l_ret_msg);

                IF l_boolean = FALSE OR l_site_id IS NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || l_ret_msg;
                END IF;
            ELSE
                l_msg   :=
                       l_msg
                    || ' Please check whether Supplier and Supplier site are Valid ';
            END IF;


            /*==================*/
            --Currency, Payment Terms and Payment Method
            /*==================*/

            IF l_org_id IS NULL OR l_vendor_id IS NULL OR l_site_id IS NULL
            THEN
                l_status    := g_errored;
                l_ret_msg   :=
                    'Valid Operating Unit, Supplier and Supplier Site are Mandatory for Currency, payment Method and Payment terms';
                l_msg       := l_msg || l_ret_msg;
            END IF;


            /*==================*/
            --Validate and Get Currency code
            /*==================*/

            IF line.currency_code IS NOT NULL
            THEN
                l_boolean   := NULL;
                l_ret_msg   := NULL;
                l_boolean   :=
                    is_curr_code_valid (p_curr_code   => line.currency_code,
                                        x_ret_msg     => l_ret_msg);

                IF l_boolean = FALSE
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || ' - ' || l_ret_msg;
                ELSE
                    l_curr_code   := line.currency_code;
                END IF;
            ELSIF line.currency_code IS NULL
            THEN
                IF     l_org_id IS NOT NULL
                   AND l_vendor_id IS NOT NULL
                   AND l_site_id IS NOT NULL
                THEN
                    l_boolean     := NULL;
                    l_ret_msg     := NULL;
                    l_curr_code   := NULL;                 -- added as per 1.2
                    l_boolean     :=
                        get_curr_code (p_vendor_id        => l_vendor_id,
                                       p_vendor_site_id   => l_site_id,
                                       p_org_id           => l_org_id,
                                       x_curr_code        => l_curr_code,
                                       x_ret_msg          => l_ret_msg);

                    IF l_boolean = FALSE OR l_curr_code IS NULL
                    THEN
                        l_status   := g_errored;
                        l_msg      := l_msg || l_ret_msg;
                    END IF;
                END IF;
            END IF;

            /*==================*/
            --Get Payment Method
            /*==================*/

            IF     l_org_id IS NOT NULL
               AND l_vendor_id IS NOT NULL
               AND l_site_id IS NOT NULL
            THEN
                l_boolean    := NULL;
                l_ret_msg    := NULL;
                l_pay_code   := NULL;                      -- added as per 1.2
                l_boolean    :=
                    get_pay_method (p_vendor_id        => l_vendor_id,
                                    p_vendor_site_id   => l_site_id,
                                    p_org_id           => l_org_id,
                                    x_pay_method       => l_pay_code,
                                    x_ret_msg          => l_ret_msg);

                IF l_boolean = FALSE OR l_pay_code IS NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || l_ret_msg;
                END IF;
            END IF;


            /*==================*/
            --Valdiate Terms
            /*==================*/

            IF line.payment_terms IS NOT NULL
            THEN
                l_boolean    := NULL;
                l_ret_msg    := NULL;
                l_terms_id   := NULL;                      -- added as per 1.2
                l_boolean    :=
                    is_term_valid (p_terms     => line.payment_terms,
                                   x_term_id   => l_terms_id,
                                   x_ret_msg   => l_ret_msg);

                IF l_boolean = FALSE OR l_terms_id IS NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || l_ret_msg;
                END IF;
            ELSE
                /*==================*/
                --Get Payment Terms
                /*==================*/
                IF     l_org_id IS NOT NULL
                   AND l_vendor_id IS NOT NULL
                   AND l_site_id IS NOT NULL
                THEN
                    l_boolean    := NULL;
                    l_ret_msg    := NULL;
                    l_terms_id   := NULL;                  -- added as per 1.2
                    l_boolean    :=
                        get_terms (p_vendor_id        => l_vendor_id,
                                   p_vendor_site_id   => l_site_id,
                                   p_org_id           => l_org_id,
                                   x_term_id          => l_terms_id,
                                   x_ret_msg          => l_ret_msg);

                    IF l_boolean = FALSE OR l_terms_id IS NULL
                    THEN
                        l_status   := g_errored;
                        l_msg      := l_msg || l_ret_msg;
                    END IF;
                --ELSE
                --   l_msg := l_msg||' Valid OU and Supplier and Site are mandatory for Payment Terms ';

                END IF;
            END IF;

            /*======================*/
            --Validate Invoice Date
            /*======================*/

            IF line.invoice_date IS NOT NULL
            THEN
                l_boolean    := NULL;
                l_ret_msg    := NULL;
                l_hdr_date   := NULL;                      -- added as per 1.2

                BEGIN
                    SELECT TO_DATE (TO_CHAR (TO_DATE (line.invoice_date), g_format_mask), g_format_mask)
                      INTO l_hdr_date
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_hdr_date   := NULL;
                        l_ret_msg    :=
                               ' Invalid Invoice date format. Please enter in the format: '
                            || g_format_mask;
                END;

                IF l_ret_msg IS NOT NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || l_ret_msg;
                END IF;
            ELSE
                l_msg   := l_msg || ' Invoice date cannot be NULL ';
            END IF;

            /*======================*/
            --Validate GL Date
            /*======================*/

            l_boolean             := NULL;
            l_ret_msg             := NULL;
            l_gl_date             := NULL;                 -- added as per 1.2

            BEGIN
                SELECT TO_DATE (TO_CHAR (TO_DATE (SYSDATE), g_format_mask), g_format_mask)
                  INTO l_gl_date
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_gl_date   := NULL;
                    l_status    := g_errored;
                    l_ret_msg   :=
                           ' Invalid GL date format. Please enter in the format: '
                        || g_format_mask;
                    l_msg       := l_msg || l_ret_msg;
            END;

            l_gl_date             :=
                is_gl_date_valid (p_gl_date   => l_gl_date,
                                  p_org_id    => l_org_id,
                                  x_ret_msg   => l_ret_msg);

            IF l_gl_date IS NULL OR l_ret_msg IS NOT NULL
            THEN
                l_status   := g_errored;
                l_msg      := l_msg || l_ret_msg;
            END IF;

            /*======================*/
            --Validate Invoice num
            /*======================*/

            IF line.invoice_number IS NOT NULL
            THEN
                l_boolean   := NULL;
                l_ret_msg   := NULL;
                l_boolean   :=
                    is_inv_num_valid (p_inv_num       => line.invoice_number,
                                      p_vendor_id     => l_vendor_id,
                                      p_vendor_site   => l_site_id, -- Added as per change 1.1
                                      p_org_id        => l_org_id,
                                      x_ret_msg       => l_ret_msg);

                IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || l_ret_msg;
                END IF;
            ELSE
                l_status   := g_errored;
                l_msg      := l_msg || ' Invoice Number Cannot be NULL ';
            END IF;

            /*=============================*/
            --Validate invoice amount
            /*============================*/

            IF line.invoice_amount IS NOT NULL
            THEN
                l_boolean       := NULL;
                l_ret_msg       := NULL;
                l_invoice_amt   := NULL;                   -- added as per 1.2
                l_boolean       :=
                    validate_amount (p_amount    => line.invoice_amount,
                                     x_amount    => l_invoice_amt,
                                     x_ret_msg   => l_ret_msg);

                IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || l_ret_msg;
                END IF;
            ELSE
                l_status   := g_errored;
                l_msg      := l_msg || ' Invoice Amount Cannot be NULL ';
            END IF;

            /*==================================*/
            --Validate Credit or Standard Invoice
            /*==================================*/

            IF l_invoice_amt < 0
            THEN
                l_invoice_type   := 'CREDIT';
            ELSE
                l_invoice_type   := 'STANDARD';
            END IF;

            /*======================*/
            --Validate line type
            /*======================*/

            IF line.line_type IS NOT NULL
            THEN
                l_boolean     := NULL;
                l_ret_msg     := NULL;
                l_line_type   := NULL;                     -- added as per 1.2
                l_boolean     :=
                    is_line_type_valid (p_line_type   => line.line_type,
                                        x_code        => l_line_type,
                                        x_ret_msg     => l_ret_msg);

                IF l_boolean = FALSE OR l_line_type IS NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || l_ret_msg;
                END IF;
            ELSE
                l_status   := g_errored;
                l_msg      := l_msg || ' Line Type Cannot be NULL ';
            END IF;

            /*=============================*/
            --Validate distribution account
            /*============================*/

            IF line.distribution_acct IS NOT NULL
            THEN
                IF line.po_number IS NOT NULL
                THEN
                    l_status   := g_errored;
                    l_msg      :=
                           l_msg
                        || ' Distribution account cannot be entered for PO Invoices ';
                ELSE
                    l_boolean        := NULL;
                    l_ret_msg        := NULL;
                    l_dist_acct_id   := NULL;              -- added as per 1.2
                    l_boolean        :=
                        dist_account_exists (
                            p_dist_acct   => line.distribution_acct,
                            x_dist_ccid   => l_dist_acct_id,
                            x_ret_msg     => l_ret_msg);

                    IF l_boolean = FALSE OR l_dist_acct_id IS NULL
                    THEN
                        l_status   := g_errored;
                        l_msg      := l_msg || l_ret_msg;
                    END IF;
                END IF;
            ELSIF     line.po_number_h IS NULL
                  AND (line.distribution_acct IS NULL OR line.distribution_set IS NULL)
            THEN
                l_status   := g_errored;
                l_msg      :=
                       l_msg
                    || ' Distribution Account or Distribution set has to be entered ';
            END IF;

            /*=============================*/
            --Validate distribution set
            /*============================*/

            IF line.distribution_set IS NOT NULL
            THEN
                l_boolean       := NULL;
                l_ret_msg       := NULL;
                l_dist_set_id   := NULL;                   -- added as per 1.2
                l_boolean       :=
                    dist_set_exists (p_dist_set_name => line.distribution_set, p_org_id => l_org_id, x_dist_id => l_dist_set_id
                                     , x_ret_msg => l_ret_msg);
            END IF;

            IF line.po_number IS NULL
            THEN
                IF     line.distribution_acct IS NULL
                   AND line.distribution_set IS NULL
                THEN
                    l_status   := g_errored;
                    l_msg      :=
                           l_msg
                        || ' Either of Distribution Account or Distribution set are to be entered. ';
                ELSIF     line.distribution_acct IS NOT NULL
                      AND line.distribution_set IS NOT NULL
                THEN
                    l_status   := g_errored;
                    l_msg      :=
                           l_msg
                        || ' Both Distribution Account and Distribution set are entered. ';
                END IF;
            END IF;

            /*=============================*/
            --Validate ship to location
            /*============================*/
            IF line.ship_to IS NOT NULL
            THEN
                l_boolean          := NULL;
                l_ret_msg          := NULL;
                l_ship_to_loc_id   := NULL;                -- added as per 1.2
                l_boolean          :=
                    is_ship_to_valid (p_ship_to_code     => line.ship_to,
                                      x_ship_to_loc_id   => l_ship_to_loc_id,
                                      x_ret_msg          => l_ret_msg);

                IF l_boolean = FALSE OR l_ship_to_loc_id IS NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || l_ret_msg;
                END IF;
            END IF;

            /*=================================================*/
            -- Validate PO Number at Header and PO Number at Line
            /*=================================================*/

            IF line.po_number_h IS NOT NULL
            THEN
                IF line.po_number IS NULL
                THEN
                    l_status   := g_errored;
                    l_msg      :=
                           l_msg
                        || ' PO Number at Invoice Header require PO Number at Invoice Line level ';
                ELSIF line.po_number IS NOT NULL
                THEN
                    IF line.po_number_h <> line.po_number
                    THEN
                        l_status   := g_errored;
                        l_msg      :=
                               l_msg
                            || ' PO Number at Invoice Header should be same as PO Number at invoice Line level ';
                    END IF;
                END IF;
            END IF;

            /*=====================================*/
            --Validate PO Number at Invoice Header
            /*=====================================*/

            IF l_org_id IS NOT NULL AND l_vendor_id IS NOT NULL
            THEN
                IF line.po_number_h IS NOT NULL
                THEN
                    l_boolean            := NULL;
                    l_ret_msg            := NULL;
                    l_po_header_inv_id   := NULL;          -- added as per 1.2
                    l_boolean            :=
                        is_po_exists (p_po_num         => line.po_number_h,
                                      p_vendor_id      => l_vendor_id,
                                      p_org_id         => l_org_id,
                                      x_po_header_id   => l_po_header_inv_id,
                                      x_ret_msg        => l_ret_msg);

                    IF l_boolean = FALSE OR l_po_header_inv_id IS NULL
                    THEN
                        l_status   := g_errored;
                        l_msg      :=
                               ' PO Number at Invoice Header - '
                            || l_msg
                            || l_ret_msg;
                    END IF;
                END IF;
            END IF;

            /*=======================================*/
            --Validate PO Number at Invoice Line Level
            /*=======================================*/

            IF l_org_id IS NOT NULL AND l_vendor_id IS NOT NULL
            THEN
                IF line.po_number IS NOT NULL
                THEN
                    l_boolean        := NULL;
                    l_ret_msg        := NULL;
                    l_po_header_id   := NULL;              -- added as per 1.2
                    l_boolean        :=
                        is_po_exists (p_po_num         => line.po_number,
                                      p_vendor_id      => l_vendor_id,
                                      p_org_id         => l_org_id,
                                      x_po_header_id   => l_po_header_id,
                                      x_ret_msg        => l_ret_msg);

                    IF l_boolean = FALSE OR l_po_header_id IS NULL
                    THEN
                        l_status   := g_errored;
                        l_msg      := l_msg || l_ret_msg;
                    END IF;
                END IF;
            END IF;

            /*=============================*/
            --Validate PO Line
            /*============================*/

            IF     l_org_id IS NOT NULL
               AND l_vendor_id IS NOT NULL
               AND l_po_header_id IS NOT NULL
            THEN
                IF line.po_line_number IS NOT NULL
                THEN
                    l_boolean      := NULL;
                    l_ret_msg      := NULL;
                    l_po_line_id   := NULL;                -- added as per 1.2
                    l_boolean      :=
                        is_po_line_exists (
                            p_line_num     => line.po_line_number,
                            p_org_id       => l_org_id,
                            p_header_id    => l_po_header_id,
                            x_po_line_id   => l_po_line_id,
                            x_ret_msg      => l_ret_msg);

                    IF l_boolean = FALSE OR l_po_header_id IS NULL
                    THEN
                        l_status   := g_errored;
                        l_msg      := l_msg || l_ret_msg;
                    END IF;
                END IF;
            END IF;

            /*======================*/
            --Validate Quantity Invoiced
            /*======================*/

            IF     line.quantity_invoiced IS NOT NULL
               AND line.quantity_invoiced < 0
            THEN
                l_boolean   := FALSE;
                l_msg       :=
                    l_msg || ' Quantity Invoiced cannot be Neagtive. ';
                l_status    := g_errored;
            END IF;


            /*======================*/
            --Validate Unit Price
            /*======================*/

            IF line.unit_price IS NOT NULL
            THEN
                l_boolean      := NULL;
                l_ret_msg      := NULL;
                l_unit_price   := NULL;                    -- added as per 1.2
                l_boolean      :=
                    validate_amount (p_amount    => line.unit_price,
                                     x_amount    => l_unit_price,
                                     x_ret_msg   => l_ret_msg);

                IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || ' - ' || l_ret_msg;
                END IF;
            END IF;

            /*===========================================*/
            -- Validate PO Unit Price and PO Qty Invoiced
            /*===========================================*/

            IF line.po_number IS NOT NULL AND line.po_line_number IS NOT NULL
            THEN
                IF line.quantity_invoiced IS NULL OR line.unit_price IS NULL
                THEN
                    l_status   := g_errored;
                    l_msg      :=
                           l_msg
                        || ' - '
                        || 'Quantity invoiced and Unit Price has to be entered for PO related invoices ';
                END IF;
            END IF;


            /*=======================*/
            -- Validate Line Amount
            /*=======================*/

            IF line.line_amount IS NOT NULL
            THEN
                l_boolean    := NULL;
                l_ret_msg    := NULL;
                l_line_amt   := NULL;                      -- added as per 1.2
                l_boolean    :=
                    validate_amount (p_amount    => line.line_amount,
                                     x_amount    => l_line_amt,
                                     x_ret_msg   => l_ret_msg);

                IF l_boolean = FALSE OR l_line_amt IS NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || l_ret_msg;
                END IF;
            ELSE
                l_status   := g_errored;
                l_msg      := l_msg || ' Line amount cannot be NULL ';
            END IF;

            /*============================*/
            -- Vendor Charged Tax
            /*============================*/

            IF line.vendor_charged_tax IS NOT NULL
            THEN
                l_boolean            := NULL;
                l_ret_msg            := NULL;
                l_user_entered_tax   := NULL;              -- added as per 1.2
                l_boolean            :=
                    validate_amount (p_amount    => line.vendor_charged_tax,
                                     x_amount    => l_user_entered_tax,
                                     x_ret_msg   => l_ret_msg);

                IF l_boolean = FALSE OR l_user_entered_tax IS NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || l_ret_msg;
                END IF;
            END IF;

            /*=============================*/
            --Get Asset Book
            /*============================*/

            IF line.asset_book IS NOT NULL
            THEN
                l_boolean      := NULL;
                l_ret_msg      := NULL;
                l_boolean1     := NULL;
                l_asset_book   := NULL;                    -- added as per 1.2
                l_boolean      :=
                    get_asset_book (p_asset_book   => line.asset_book,
                                    x_asset_book   => l_asset_book,
                                    x_ret_msg      => l_ret_msg);

                IF l_boolean = FALSE OR l_asset_book IS NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || l_ret_msg;
                ELSIF l_boolean = TRUE OR l_asset_book IS NOT NULL
                THEN
                    l_ret_msg    := NULL;                  -- Added as per 1.2
                    l_boolean1   := NULL;           -- Added as per change 1.2
                    l_boolean1   :=
                        is_asset_book_valid (
                            p_asset_book   => line.asset_book,
                            p_org_id       => l_org_id,
                            x_ret_msg      => l_ret_msg);

                    IF l_boolean1 = FALSE OR l_ret_msg IS NOT NULL
                    THEN
                        l_status   := g_errored;
                        l_msg      := l_msg || l_ret_msg;
                    END IF;
                END IF;
            END IF;

            /*=============================*/
            --Get Asset Category
            /*============================*/

            IF line.asset_book IS NOT NULL
            THEN
                l_boolean        := NULL;
                l_boolean1       := NULL;
                l_ret_msg        := NULL;
                l_asset_cat_id   := NULL;           -- Added as per change 1.2
                l_boolean        :=
                    get_asset_category (p_asset_cat      => line.asset_category,
                                        x_asset_cat_id   => l_asset_cat_id,
                                        x_ret_msg        => l_ret_msg);

                IF l_boolean = FALSE OR l_asset_cat_id IS NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || l_ret_msg;
                ELSIF l_boolean = TRUE OR l_asset_cat_id IS NOT NULL
                THEN
                    l_boolean1   := NULL;           -- Added as per change 1.2
                    l_ret_msg    := NULL;           -- Added as per change 1.2
                    l_boolean1   :=
                        is_asset_cat_valid (
                            p_asset_cat_id   => l_asset_cat_id,
                            p_asset_book     => line.asset_book, --,x_valid_out    => l_valid_out
                            x_ret_msg        => l_ret_msg);

                    IF l_boolean1 = FALSE OR l_ret_msg IS NOT NULL
                    THEN
                        l_status   := g_errored;
                        l_msg      := l_msg || l_ret_msg;
                    END IF;
                END IF;
            END IF;

            /*==========================================*/
            --Validate interco account
            /*=========================================*/

            IF     line.interco_exp_account IS NOT NULL
               AND l_dist_acct_id IS NOT NULL
            THEN
                l_boolean           := NULL;
                l_ret_msg           := NULL;
                l_interco_acct_id   := NULL;        -- Added as per change 1.2
                l_boolean           :=
                    is_interco_acct (p_interco_acct => line.interco_exp_account, p_dist_ccid => l_dist_acct_id, x_interco_acct_id => l_interco_acct_id
                                     , x_ret_msg => l_ret_msg);

                IF l_boolean = FALSE OR l_interco_acct_id IS NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || l_ret_msg;
                END IF;
            END IF;


            /*==========================================*/
            --Validate Deferred Flag
            /*=========================================*/

            IF line.deferred IS NOT NULL
            THEN
                l_boolean         := NULL;
                l_ret_msg         := NULL;
                l_deferred_flag   := NULL;          -- Added as per change 1.2
                l_boolean         :=
                    is_flag_valid (p_flag      => line.deferred,
                                   x_flag      => l_deferred_flag,
                                   x_ret_msg   => l_ret_msg);

                IF l_boolean = FALSE OR l_deferred_flag IS NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || l_ret_msg;
                END IF;
            END IF;

            /*==========================================*/
            --Validate Prorate Flag
            /*=========================================*/

            IF line.prorate_accros_all_item_lines IS NOT NULL
            THEN
                l_boolean        := NULL;
                l_ret_msg        := NULL;
                l_prorate_flag   := NULL;           -- Added as per change 1.2
                l_boolean        :=
                    is_flag_valid (
                        p_flag      => line.prorate_accros_all_item_lines,
                        x_flag      => l_prorate_flag,
                        x_ret_msg   => l_ret_msg);

                IF l_boolean = FALSE OR l_prorate_flag IS NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || l_ret_msg;
                END IF;
            END IF;


            /*==========================================*/
            --FAPIO Received Flag
            /*=========================================*/

            IF line.fapio_received IS NOT NULL
            THEN
                l_boolean      := NULL;
                l_ret_msg      := NULL;
                l_fapio_flag   := NULL;             -- Added as per change 1.2
                l_boolean      :=
                    is_flag_valid (p_flag      => line.fapio_received,
                                   x_flag      => l_fapio_flag,
                                   x_ret_msg   => l_ret_msg);

                IF l_boolean = FALSE OR l_fapio_flag IS NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || l_ret_msg;
                END IF;
            END IF;

            /*==========================================*/
            --Track as asset Flag
            /*=========================================*/

            IF line.track_as_asset IS NOT NULL
            THEN
                l_boolean      := NULL;
                l_ret_msg      := NULL;
                l_asset_flag   := NULL;             -- Added as per change 1.2
                l_boolean      :=
                    is_flag_valid (p_flag      => line.track_as_asset,
                                   x_flag      => l_asset_flag,
                                   x_ret_msg   => l_ret_msg);

                IF l_boolean = FALSE OR l_asset_flag IS NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || l_ret_msg;
                END IF;
            END IF;

            /*==========================================*/
            --Validate Asset Information
            /*=========================================*/

            IF     l_asset_flag = 'Y'
               AND (line.asset_category IS NULL OR line.asset_book IS NULL)
            THEN
                l_status   := g_errored;
                l_msg      :=
                       l_msg
                    || ' Please check asset category and asset book values. ';
            ELSIF     line.asset_book IS NOT NULL
                  AND (line.track_as_asset IS NULL OR l_asset_flag = 'N' OR line.asset_category IS NULL)
            THEN
                l_status   := g_errored;
                l_msg      :=
                       l_msg
                    || ' Please check asset Category and Track as asset values. ';
            ELSIF     line.asset_category IS NOT NULL
                  AND (line.track_as_asset IS NULL OR l_asset_flag = 'N' OR line.asset_book IS NULL)
            THEN
                l_status   := g_errored;
                l_msg      :=
                       l_msg
                    || ' Please check asset book and Track as asset values. ';
            ELSIF     line.asset_category IS NOT NULL
                  AND line.track_as_asset IS NOT NULL
                  AND l_asset_flag = 'Y'
                  AND line.asset_book IS NOT NULL
            THEN
                IF line.po_number IS NULL
                THEN
                    l_status   := g_errored;
                    l_msg      :=
                           l_msg
                        || ' Asset cannot be entered without Purchase Order. ';
                END IF;
            END IF;

            /*==========================================*/
            --Validate Sample Invoice flag
            /*=========================================*/

            IF line.sample_invoice IS NOT NULL
            THEN
                l_boolean           := NULL;
                l_ret_msg           := NULL;
                l_sample_inv_flag   := NULL;        -- Added as per change 1.2
                l_boolean           :=
                    is_flag_valid (p_flag      => line.sample_invoice,
                                   x_flag      => l_sample_inv_flag,
                                   x_ret_msg   => l_ret_msg);

                IF l_boolean = FALSE OR l_sample_inv_flag IS NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || l_ret_msg;
                END IF;
            END IF;

            /*============================*/
            --Validate Deferred Start date
            /*============================*/

            IF line.deferred_start_date IS NOT NULL
            THEN
                l_boolean          := NULL;
                l_ret_msg          := NULL;
                l_def_start_date   := NULL;         -- Added as per change 1.2

                BEGIN
                    SELECT TO_DATE (TO_CHAR (TO_DATE (line.deferred_start_date), g_format_mask), g_format_mask)
                      INTO l_def_start_date
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        --l_hdr_date := NULL;
                        l_def_start_date   := NULL; -- Added as per Change 1.2
                        l_ret_msg          :=
                               ' Invalid deferred start date format. Please enter in the format: '
                            || g_format_mask;
                END;

                IF l_ret_msg IS NOT NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || l_ret_msg;
                END IF;
            END IF;

            /*======================*/
            --Validate Deferred End date
            /*======================*/

            IF line.deferred_end_date IS NOT NULL
            THEN
                l_boolean        := NULL;
                l_ret_msg        := NULL;
                l_def_end_date   := NULL;           -- Added as per change 1.2

                BEGIN
                    SELECT TO_DATE (TO_CHAR (TO_DATE (line.deferred_end_date), g_format_mask), g_format_mask)
                      INTO l_def_end_date
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        --l_hdr_date := NULL;
                        l_def_end_date   := NULL;   -- Added as per Change 1.2
                        l_ret_msg        :=
                               ' Invalid deferred end date format. Please enter in the format: '
                            || g_format_mask;
                END;

                IF l_ret_msg IS NOT NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || l_ret_msg;
                END IF;
            END IF;

            /*==========================================*/
            --Validate Deferred Option details
            /*=========================================*/

            IF     l_deferred_flag = 'Y'
               AND (line.deferred_start_date IS NULL OR line.deferred_end_date IS NULL)
            THEN
                l_status   := g_errored;
                l_msg      :=
                       l_msg
                    || ' Please enter valid deferred start and end date values. ';
            ELSIF     line.deferred_start_date IS NOT NULL
                  AND (line.deferred IS NULL OR l_deferred_flag = 'N' OR line.deferred_end_date IS NULL)
            THEN
                l_status   := g_errored;
                l_msg      :=
                       l_msg
                    || ' Please enter valid deferred and deferred end date values';
            ELSIF     line.deferred_end_date IS NOT NULL
                  AND (line.deferred IS NULL OR l_deferred_flag = 'N' OR line.deferred_start_date IS NULL)
            THEN
                l_status   := g_errored;
                l_msg      :=
                       l_msg
                    || ' Please enter valid deferred and deferred start date values';
            END IF;


            /*==========================*/
            --Validate Tax Control Amout
            /*==========================*/

            IF line.tax_control_amt IS NOT NULL
            THEN
                l_boolean           := NULL;
                l_ret_msg           := NULL;
                l_tax_control_amt   := NULL;        -- Added as per Change 1.2
                l_boolean           :=
                    validate_amount (p_amount    => line.tax_control_amt,
                                     x_amount    => l_tax_control_amt,
                                     x_ret_msg   => l_ret_msg);

                IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || ' - ' || l_ret_msg;
                END IF;
            END IF;

            /*===============================*/
            --Validate Tax Classification Code
            /*===============================*/

            IF line.tax_classification_code IS NOT NULL
            THEN
                l_boolean    := NULL;
                l_ret_msg    := NULL;
                l_tax_code   := NULL;               -- Added as per Change 1.2
                l_boolean    :=
                    is_tax_code_valid (
                        p_tax_code   => line.tax_classification_code,
                        x_tax_code   => l_tax_code,
                        x_ret_msg    => l_ret_msg);

                IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || ' - ' || l_ret_msg;
                END IF;
            END IF;

            IF line.pay_alone IS NOT NULL
            THEN
                l_boolean           := NULL;
                l_ret_msg           := NULL;
                ln_count_pay_flag   := 0;           -- Added as per Change 1.2

                SELECT COUNT (1)
                  INTO ln_count_pay_flag
                  FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values ffv
                 WHERE     ffvs.flex_value_set_id = ffv.flex_value_set_id
                       AND ffvs.flex_value_set_name =
                           'XXD_AP_OVERRIDE_TERMS_VS'
                       AND NVL (ffv.enabled_flag, 'Y') = 'Y'
                       AND SYSDATE BETWEEN NVL (ffv.start_date_active,
                                                SYSDATE)
                                       AND NVL (ffv.end_date_active, SYSDATE)
                       AND UPPER (ffv.flex_value) =
                           TRIM (UPPER (line.operating_unit));

                IF ln_count_pay_flag > 0
                THEN
                    l_boolean   :=
                        is_flag_valid (p_flag      => line.pay_alone,
                                       x_flag      => l_pay_alone_flag,
                                       x_ret_msg   => l_ret_msg);

                    IF l_boolean = FALSE OR l_pay_alone_flag IS NULL
                    THEN
                        l_status   := g_errored;
                        l_msg      := l_msg || l_ret_msg;
                    END IF;
                END IF;
            ELSE
                l_pay_alone_flag   := 'N';
            END IF;

            BEGIN
                UPDATE xxdo.xxd_ap_lcx_invoices_stg_t
                   SET status = l_status, error_msg = l_msg, gl_date = l_gl_date,
                       po_header_id = l_po_header_inv_id, org_id = l_org_id, vendor_id = l_vendor_id,
                       supplier_name = l_vendor_name, vendor_site_id = l_site_id, fapio_flag = l_fapio_flag,
                       dist_account_id = l_dist_acct_id, ship_to_location_id = l_ship_to_loc_id, po_header_l_id = l_po_header_id,
                       po_line_id = l_po_line_id, invoice_type_lookup_code = l_invoice_type, interco_exp_account_id = l_interco_acct_id,
                       deferred_flag = l_deferred_flag, prorate_flag = l_prorate_flag, asset_flag = l_asset_flag,
                       asset_cat_id = l_asset_cat_id, sample_inv_flag = l_sample_inv_flag, asset_book_code = l_asset_book,
                       dist_set_id = l_dist_set_id, payment_term_id = l_terms_id, payment_method = l_pay_code,
                       pay_alone_flag = l_pay_alone_flag, line_type = l_line_type, invoice_date = l_hdr_date,
                       invoice_amount = l_invoice_amt, user_entered_tax = l_user_entered_tax, tax_control_amt = l_tax_control_amt,
                       line_amount = l_line_amt, tax_classification_code = l_tax_code, deferred_start_date = l_def_start_date,
                       deferred_end_date = l_def_end_date, currency_code = l_curr_code
                 WHERE     record_id = line.record_id
                       AND request_id = gn_request_id;
            --            fnd_file.put_line (
            --               fnd_file.LOG,
            --               ' record id  :- ' || line.record_id || ' updated successfully');
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_msg   :=
                        'Error while updating the staging table: ' || SQLERRM;

                    UPDATE xxdo.xxd_ap_lcx_invoices_stg_t
                       SET status = g_errored, error_msg = l_msg
                     WHERE     record_id = line.record_id
                           AND request_id = gn_request_id;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           ' record id  :- '
                        || line.record_id
                        || ' has error while updating Ids :-'
                        || l_msg);
            END;
        END LOOP;

        COMMIT;                       -- commit after validating all the lines
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END validate_staging;


    FUNCTION is_org_valid (p_org_name   IN     VARCHAR2,
                           x_org_id        OUT NUMBER,
                           x_ret_msg       OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_org_id   NUMBER;
    BEGIN
        SELECT organization_id
          INTO x_org_id
          FROM apps.hr_operating_units
         WHERE     UPPER (name) = UPPER (TRIM (p_org_name))
               AND date_from <= SYSDATE
               AND NVL (date_to, SYSDATE) >= SYSDATE;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid Operating Unit Name.';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   := ' Multiple Operating Units exist with same name.';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Operating Unit: ' || SQLERRM;
            RETURN FALSE;
    END is_org_valid;

    -- Added function for CCR0008507

    FUNCTION is_mtd_org (p_org_name       IN     VARCHAR2,
                         x_mtd_org_name      OUT VARCHAR2,
                         x_ret_msg           OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT ffvl.flex_value
          INTO x_mtd_org_name
          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
         WHERE     1 = 1
               AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
               AND ffvl.enabled_flag = 'Y'
               AND ffvs.flex_value_set_name = 'XXD_MTD_OU_VS'
               AND SYSDATE BETWEEN NVL (ffvl.start_date_active, SYSDATE - 1)
                               AND NVL (ffvl.end_date_active, SYSDATE + 1)
               AND UPPER (ffvl.flex_value) = UPPER (TRIM (p_org_name));

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid MTD Operating Unit Name.';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple MTD Operating Units exist with same name.';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid MTD Operating Unit: ' || SQLERRM;
            RETURN FALSE;
    END is_mtd_org;

    -- End of Change

    FUNCTION is_vendor_valid (p_vendor_number IN VARCHAR2, x_vendor_id OUT NUMBER, x_vendor_name OUT VARCHAR2
                              , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT vendor_id, vendor_name
          INTO x_vendor_id, x_vendor_name
          FROM apps.ap_suppliers
         WHERE     UPPER (TRIM (segment1)) = UPPER (TRIM (p_vendor_number))
               AND enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                               AND NVL (end_date_active, SYSDATE); -- Added as per Change 1.2

        --AND NVL(attribute2,'N') = 'N'; -- GTN Supplier
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid Vendor. Supplier should be valid';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   := ' Multiple Vendors exist with same name.';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Vendor: ' || SQLERRM;
            RETURN FALSE;
    END is_vendor_valid;

    FUNCTION is_site_valid (p_site_code IN VARCHAR2, p_org_id IN NUMBER, p_vendor_id IN NUMBER
                            , x_site_id OUT NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT vendor_site_id
          INTO x_site_id
          FROM apps.ap_supplier_sites_all
         WHERE     UPPER (vendor_site_code) = UPPER (TRIM (p_site_code))
               AND org_id = p_org_id
               AND NVL (inactive_date, SYSDATE + 1) > SYSDATE -- -- Added as per Change 1.2
               AND vendor_id = p_vendor_id;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid Vendor Site code.';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   := ' Multiple Vendor Sites exist with same code.';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Vendor Site: ' || SQLERRM;
            RETURN FALSE;
    END is_site_valid;

    FUNCTION is_po_exists (p_po_num         IN     VARCHAR2,
                           p_vendor_id      IN     NUMBER,
                           p_org_id         IN     NUMBER,
                           x_po_header_id      OUT NUMBER,
                           x_ret_msg           OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT po_header_id
          INTO x_po_header_id
          FROM apps.po_headers_all
         WHERE     UPPER (segment1) = UPPER (TRIM (p_po_num))
               AND org_id = p_org_id
               AND vendor_id = p_vendor_id
               AND NVL (cancel_flag, 'N') = 'N'
               AND NVL (authorization_status, 'APPROVED') = 'APPROVED'
               AND NVL (closed_code, 'OPEN') = 'OPEN';

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid PO Number';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple PO exist with same Vendor and OU Combination';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid PO: ' || SQLERRM;
            RETURN FALSE;
    END is_po_exists;

    FUNCTION is_po_line_exists (p_line_num     IN     NUMBER,
                                p_org_id       IN     NUMBER,
                                p_header_id    IN     NUMBER,
                                x_po_line_id      OUT NUMBER,
                                x_ret_msg         OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT po_line_id
          INTO x_po_line_id
          FROM apps.po_lines_all
         WHERE     line_num = TRIM (p_line_num)
               AND org_id = p_org_id
               AND po_header_id = p_header_id
               AND NVL (cancel_flag, 'N') = 'N'
               AND NVL (closed_code, 'OPEN') = 'OPEN';

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid PO Line Number';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple PO lines exist with same PO and Line combination';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid PO Line Number: ' || SQLERRM;
            RETURN FALSE;
    END is_po_line_exists;

    FUNCTION is_curr_code_valid (p_curr_code   IN     VARCHAR2,
                                 x_ret_msg        OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_curr   NUMBER := 0;
    BEGIN
        SELECT 1
          INTO l_curr
          FROM apps.fnd_currencies
         WHERE     enabled_flag = 'Y'
               AND currency_code = UPPER (TRIM (p_curr_code));

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid Currency Code.';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   := ' Multiple Currencies exist with same code.';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Currency Code: ' || SQLERRM;
            RETURN FALSE;
    END is_curr_code_valid;

    FUNCTION is_flag_valid (p_flag      IN     VARCHAR2,
                            x_flag         OUT VARCHAR2,
                            x_ret_msg      OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT lookup_code
          INTO x_flag
          FROM apps.fnd_lookups
         WHERE     lookup_type = 'YES_NO'
               AND enabled_flag = 'Y'
               AND UPPER (meaning) = UPPER (TRIM (p_flag));

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid - Value can be either Yes or No only;';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   := ' Multiple Lookup values exist with same code;';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Lookup Code: ' || SQLERRM;
            RETURN FALSE;
    END is_flag_valid;

    FUNCTION get_curr_code (p_vendor_id        IN     NUMBER,
                            p_vendor_site_id   IN     NUMBER,
                            p_org_id           IN     NUMBER,
                            x_curr_code           OUT VARCHAR2,
                            x_ret_msg             OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT invoice_currency_code
          INTO x_curr_code
          FROM apps.ap_supplier_sites_all
         WHERE     vendor_site_id = p_vendor_site_id
               AND vendor_id = p_vendor_id
               AND org_id = p_org_id;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                ' Please check the Currency Code at Supplier Site.';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   := ' Multiple Currencies exist at the Supplier Site';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Currency Code: ' || SQLERRM;
            RETURN FALSE;
    END get_curr_code;

    FUNCTION is_inv_num_valid (p_inv_num IN VARCHAR2, p_vendor_id IN NUMBER, p_vendor_site IN NUMBER
                               ,                    -- Added as per change 1.1
                                 p_org_id IN NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_count   NUMBER;
    BEGIN
        SELECT COUNT (1)
          INTO l_count
          FROM apps.ap_invoices_all
         WHERE     1 = 1
               AND org_id = p_org_id
               AND vendor_id = p_vendor_id
               AND vendor_site_id = p_vendor_site   -- Added as per change 1.1
               AND UPPER (invoice_num) = TRIM (UPPER (p_inv_num));

        IF l_count > 0
        THEN
            x_ret_msg   :=
                ' Invoice number:' || p_inv_num || ' already exists.';
            RETURN FALSE;
        ELSE
            RETURN TRUE;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN TRUE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Invoice number:' || p_inv_num || ' already exists.';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   ' Unable to validate Invoice number:'
                || p_inv_num
                || ' - '
                || SQLERRM;
            RETURN FALSE;
    END is_inv_num_valid;

    FUNCTION is_pay_method_valid (p_pay_method IN VARCHAR2, x_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT lookup_code
          INTO x_code
          FROM apps.fnd_lookup_values
         WHERE     lookup_type = 'PAYMENT METHOD'
               AND language = USERENV ('LANG')
               AND enabled_flag = 'Y'
               AND UPPER (lookup_code) = UPPER (TRIM (p_pay_method));

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid Payment method lookup code.';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple payment method lookups exist with same name.';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Payment Method: ' || SQLERRM;
            RETURN FALSE;
    END is_pay_method_valid;

    FUNCTION get_pay_method (p_vendor_id        IN     NUMBER,
                             p_vendor_site_id   IN     NUMBER,
                             p_org_id           IN     NUMBER,
                             x_pay_method          OUT VARCHAR2,
                             x_ret_msg             OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT ieppm.payment_method_code
          INTO x_pay_method
          FROM apps.ap_supplier_sites_all assa, apps.ap_suppliers sup, apps.iby_external_payees_all iepa,
               apps.iby_ext_party_pmt_mthds ieppm
         WHERE     sup.vendor_id = assa.vendor_id
               AND assa.vendor_site_id = iepa.supplier_site_id
               AND iepa.ext_payee_id = ieppm.ext_pmt_party_id
               AND NVL (ieppm.inactive_date, SYSDATE + 1) > SYSDATE
               AND ieppm.primary_flag = 'Y'
               AND assa.pay_site_flag = 'Y'
               AND assa.vendor_site_id = p_vendor_site_id
               AND assa.org_id = p_org_id
               AND sup.vendor_id = p_vendor_id;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            BEGIN
                SELECT ibeppm.payment_method_code
                  INTO x_pay_method
                  FROM ap_suppliers sup, iby_external_payees_all ibep, iby_ext_party_pmt_mthds ibeppm
                 WHERE     sup.party_id = ibep.payee_party_id
                       AND ibeppm.ext_pmt_party_id = ibep.ext_payee_id
                       AND ibep.supplier_site_id IS NULL
                       AND ibeppm.primary_flag = 'Y'
                       AND NVL (ibeppm.inactive_date, SYSDATE + 1) > SYSDATE
                       AND sup.vendor_id = p_vendor_id;

                RETURN TRUE;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    x_ret_msg   :=
                        ' Please check the Payment method code at Supplier';
                    RETURN FALSE;
                WHEN OTHERS
                THEN
                    x_ret_msg   :=
                           ' '
                        || 'Invalid Payment Method at Supplier: '
                        || SQLERRM;
                    RETURN FALSE;
            END;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple payment method codes exist with same name.';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Payment Method: ' || SQLERRM;
            RETURN FALSE;
    END get_pay_method;

    FUNCTION get_asset_book (p_asset_book IN VARCHAR2, x_asset_book OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_asset_book   VARCHAR2 (100);
    BEGIN
        SELECT book_type_code
          INTO l_asset_book
          FROM fa_book_controls
         WHERE UPPER (book_type_code) = UPPER (TRIM (p_asset_book));

        x_asset_book   := l_asset_book;
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid Book Type Code';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   := ' Multiple book names exist with same name.';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Book Type: ' || SQLERRM;
            RETURN FALSE;
    END get_asset_book;

    FUNCTION is_asset_book_valid (p_asset_book IN VARCHAR2, p_org_id IN VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_valid   VARCHAR2 (100);
    BEGIN
        SELECT DISTINCT fbc.book_type_code
          INTO l_valid
          FROM xle_le_ou_ledger_v xle, fa_book_controls_sec fbc
         WHERE     1 = 1
               AND fbc.set_of_books_id = xle.ledger_id
               AND UPPER (TRIM (fbc.book_type_code)) =
                   UPPER (TRIM (p_asset_book))
               AND xle.operating_unit_id = p_org_id;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := 'Invalid Asset book for the OU';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple Asset Books exist with same name for OU.';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Book Type for OU: ' || SQLERRM;
            RETURN FALSE;
    END is_asset_book_valid;

    FUNCTION get_asset_category (p_asset_cat IN VARCHAR2, x_asset_cat_id OUT NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_asset_cat_id   VARCHAR2 (100);
    BEGIN
        SELECT category_id
          INTO l_asset_cat_id
          FROM fa_categories
         WHERE    UPPER (TRIM (segment1))
               || '.'
               || UPPER (TRIM (segment2))
               || '.'
               || UPPER (TRIM (segment3)) =
               UPPER (TRIM (p_asset_cat));

        x_asset_cat_id   := l_asset_cat_id;
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid Asset Category';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   := ' Multiple Asset categories exist with same name.';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Asset Category: ' || SQLERRM;
            RETURN FALSE;
    END get_asset_category;

    FUNCTION is_asset_cat_valid (p_asset_cat_id IN VARCHAR2, p_asset_book IN VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_valid   VARCHAR2 (100);
    BEGIN
        SELECT book_type_code
          INTO l_valid
          FROM apps.fa_category_books
         WHERE     UPPER (TRIM (book_type_code)) =
                   UPPER (TRIM (p_asset_book))
               AND category_id = p_asset_cat_id;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Category doesnot belong to Asset Book';
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Asset and Category Exception. ';
    END is_asset_cat_valid;

    FUNCTION is_term_valid (p_terms     IN     VARCHAR2,
                            x_term_id      OUT NUMBER,
                            x_ret_msg      OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_term_id   NUMBER;
    BEGIN
        SELECT term_id
          INTO l_term_id
          FROM apps.ap_terms
         WHERE UPPER (TRIM (name)) = UPPER (TRIM (p_terms));

        x_term_id   := l_term_id;
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid Payment Term Name.';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   := ' Multiple Payment terms exist with same name.';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Payment Term: ' || SQLERRM;
            RETURN FALSE;
    END is_term_valid;

    FUNCTION get_terms (p_vendor_id IN NUMBER, p_vendor_site_id IN NUMBER, p_org_id IN NUMBER
                        , x_term_id OUT NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_term_id   NUMBER;
    BEGIN
        SELECT terms_id
          INTO l_term_id
          FROM apps.ap_supplier_sites_all
         WHERE     vendor_site_id = p_vendor_site_id
               AND vendor_id = p_vendor_id
               AND org_id = p_org_id;

        x_term_id   := l_term_id;
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                ' Please check the Payment Terms at Supplier Site.';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple Payment terms exist at the Supplier Site';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid payment terms: ' || SQLERRM;
            RETURN FALSE;
    END get_terms;

    FUNCTION is_line_type_valid (p_line_type IN VARCHAR2, x_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_code   VARCHAR2 (30);
    BEGIN
        SELECT lookup_code
          INTO l_code
          FROM apps.fnd_lookup_values
         WHERE     lookup_type = 'INVOICE LINE TYPE'
               AND language = USERENV ('LANG')
               AND enabled_flag = 'Y'
               AND UPPER (TRIM (lookup_code)) = UPPER (TRIM (p_line_type));

        x_code   := l_code;
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid Line type lookup code.';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple Line type lookup codes exist with same name.';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                ' ' || 'Invalid Line type lookup code: ' || SQLERRM;
            RETURN FALSE;
    END is_line_type_valid;

    FUNCTION dist_account_exists (p_dist_acct IN VARCHAR2, x_dist_ccid OUT NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT code_combination_id
          INTO x_dist_ccid
          FROM apps.gl_code_combinations_kfv
         WHERE     enabled_flag = 'Y'
               AND concatenated_segments = TRIM (p_dist_acct);

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid Distribution Account.';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple Accounts exist with same code combination.';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Distribution Account: ' || SQLERRM;
            RETURN FALSE;
    END dist_account_exists;

    FUNCTION is_interco_acct (p_interco_acct IN VARCHAR2, p_dist_ccid IN NUMBER, x_interco_acct_id OUT NUMBER
                              , x_ret_msg OUT NUMBER)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT gcc.code_combination_id
          INTO x_interco_acct_id
          FROM apps.gl_code_combinations_kfv gcc
         WHERE     gcc.detail_posting_allowed = 'Y'
               AND gcc.summary_flag = 'N'
               AND gcc.enabled_flag = 'Y'
               AND gcc.concatenated_segments = TRIM (p_interco_acct)
               AND gcc.segment1 IN
                       (SELECT SUBSTR (val.description, 1, 3)
                          FROM apps.fnd_flex_values_vl val, apps.fnd_flex_value_sets vset, apps.gl_code_combinations_kfv gcc1
                         WHERE     1 = 1
                               AND val.flex_value_set_id =
                                   vset.flex_value_set_id
                               AND val.enabled_flag = 'Y'
                               AND vset.flex_value_set_name =
                                   'XXDO_INTERCO_AP_AR_MAPPING'
                               AND val.flex_value =
                                   gcc1.concatenated_segments
                               AND gcc1.code_combination_id = p_dist_ccid)
               AND gcc.segment6 NOT IN
                       (SELECT val1.flex_value
                          FROM apps.fnd_flex_values_vl val1, apps.fnd_flex_value_sets vset1
                         WHERE     1 = 1
                               AND val1.flex_value_set_id =
                                   vset1.flex_value_set_id
                               AND val1.enabled_flag = 'Y'
                               AND vset1.flex_value_set_name =
                                   'XXDO_INTERCO_RESTRICTIONS');

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg   := ' Invalid Interco Account: ' || SQLERRM;
            RETURN FALSE;
    END is_interco_acct;

    FUNCTION dist_set_exists (p_dist_set_name IN VARCHAR2, p_org_id IN NUMBER, x_dist_id OUT NUMBER
                              , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_set_id   NUMBER;
    BEGIN
        SELECT distribution_set_id
          INTO l_set_id
          FROM apps.ap_distribution_sets_all
         WHERE     1 = 1
               AND UPPER (TRIM (distribution_set_name)) =
                   UPPER (TRIM (p_dist_set_name))
               AND org_id = p_org_id;

        x_dist_id   := l_set_id;
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid Distribtuion set name.';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple Distribtuion sets exist with same name.';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' Invalid Distribution Set: ' || SQLERRM;
            RETURN FALSE;
    END dist_set_exists;

    FUNCTION is_ship_to_valid (p_ship_to_code IN VARCHAR2, x_ship_to_loc_id OUT NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_location_id   NUMBER;
    BEGIN
        SELECT location_id
          INTO l_location_id
          FROM apps.hr_locations_all
         WHERE     1 = 1
               AND UPPER (TRIM (location_code)) =
                   UPPER (TRIM (p_ship_to_code));

        x_ship_to_loc_id   := l_location_id;
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                ' Invalid Ship to location code:' || p_ship_to_code;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' Multiple Ship to location codes exist with same name:'
                || p_ship_to_code;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   ' Invalid Ship to location code:'
                || p_ship_to_code
                || '  '
                || SQLERRM;
            RETURN FALSE;
    END is_ship_to_valid;


    FUNCTION is_gl_date_valid (p_gl_date   IN     DATE,
                               p_org_id    IN     NUMBER,
                               x_ret_msg      OUT VARCHAR2)
        RETURN DATE
    IS
        l_valid_date   DATE;
    BEGIN
        IF p_gl_date IS NOT NULL
        THEN
            SELECT p_gl_date
              INTO l_valid_date
              FROM apps.gl_period_statuses gps, apps.hr_operating_units hou
             WHERE     gps.application_id = 200                        --SQLAP
                   AND gps.ledger_id = hou.set_of_books_id
                   AND hou.organization_id = p_org_id
                   AND gps.start_date <= p_gl_date
                   AND gps.end_date >= p_gl_date
                   AND gps.closing_status = 'O';
        ELSE
            SELECT MAX (gps.start_date)
              INTO l_valid_date
              FROM apps.gl_period_statuses gps, apps.hr_operating_units hou
             WHERE     gps.application_id = 200                        --SQLAP
                   AND gps.ledger_id = hou.set_of_books_id
                   AND hou.organization_id = p_org_id
                   AND gps.closing_status = 'O';
        END IF;

        RETURN l_valid_date;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' GL Date is not in open AP Period:' || p_gl_date;
            RETURN NULL;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' Invalid GL Date:' || p_gl_date || SQLERRM;
            RETURN NULL;
    END is_gl_date_valid;

    FUNCTION validate_amount (p_amount    IN     VARCHAR2,
                              x_amount       OUT NUMBER,
                              x_ret_msg      OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_amount   NUMBER;
    BEGIN
        SELECT TO_NUMBER (p_amount) INTO x_amount FROM DUAL;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg   := 'Invalid Number format';
            RETURN FALSE;
    END validate_amount;

    FUNCTION is_tax_code_valid (p_tax_code IN VARCHAR2, x_tax_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT lookup_code
          INTO x_tax_code
          FROM apps.fnd_lookup_values
         WHERE     lookup_type = 'ZX_OUTPUT_CLASSIFICATIONS'
               AND language = USERENV ('LANG')
               AND UPPER (TRIM (lookup_code)) = UPPER (TRIM (p_tax_code));

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid Tax Classification code:' || p_tax_code;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' Multiple Tax Classification codes exist with same name: '
                || p_tax_code;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   ' Invalid Tax Classification code: '
                || p_tax_code
                || '  '
                || SQLERRM;
            RETURN FALSE;
    END is_tax_code_valid;

    PROCEDURE load_interface (x_ret_code   OUT VARCHAR2,
                              x_ret_msg    OUT VARCHAR2)
    IS
        --  Cursor to make invoice hdrs for the current request_id.
        CURSOR hdr_cur IS
              SELECT po_number_h,                         -- header po  number
                                  invoice_number, operating_unit,
                     trading_partner, vendor_number, supplier_site_code,
                     invoice_date, invoice_amount, currency_code,
                     invoice_description, user_entered_tax, tax_control_amt,
                     fapio_received, tax_classification_code, approver,
                     date_sent_approver, misc_notes, chargeback,
                     invoice_number_d, payment_ref_number, sample_invoice,
                     asset_book, gl_date, payment_term_id,
                     --payment_method,
                     invoice_add_info, pay_alone, org_id,
                     vendor_id, vendor_site_id, po_header_id,
                     fapio_flag, sample_inv_flag, invoice_type_lookup_code,
                     pay_alone_flag
                FROM xxdo.xxd_ap_lcx_invoices_stg_t
               WHERE     1 = 1
                     AND status = g_validated
                     AND request_id = gn_request_id
            GROUP BY po_number_h, invoice_number, invoice_number_d,
                     operating_unit, trading_partner, vendor_number,
                     supplier_site_code, invoice_date, invoice_amount,
                     currency_code, invoice_description, user_entered_tax,
                     tax_control_amt, fapio_received, tax_classification_code,
                     approver, date_sent_approver, misc_notes,
                     chargeback, payment_ref_number, sample_invoice,
                     asset_book, gl_date, payment_term_id,
                     --payment_method,
                     pay_alone, org_id, vendor_id,
                     vendor_site_id, po_header_id, fapio_flag,
                     sample_inv_flag, invoice_type_lookup_code, invoice_add_info,
                     pay_alone_flag
            ORDER BY invoice_date, operating_unit, vendor_number,
                     invoice_number;

        --  fetch  lines of the given hdr

        CURSOR line_cur (p_invoice_num IN VARCHAR2, p_vendor_num IN NUMBER, p_org_name IN VARCHAR2
                         , p_vendor_site IN VARCHAR2, p_inv_type IN VARCHAR2)
        IS
            SELECT *
              FROM xxdo.xxd_ap_lcx_invoices_stg_t
             WHERE     1 = 1
                   AND request_id = gn_request_id
                   AND status = g_validated
                   AND invoice_number = p_invoice_num
                   AND vendor_number = p_vendor_num
                   AND supplier_site_code = p_vendor_site
                   AND operating_unit = p_org_name
                   AND invoice_type_lookup_code = p_inv_type;


        l_invoice_id          NUMBER;
        l_hdr_status          VARCHAR2 (1);
        l_line_status         VARCHAR2 (1);
        l_total_line_amount   NUMBER;
        l_invoice_line_id     NUMBER;
        l_lin_count           NUMBER;
        l_hdr_msg             VARCHAR2 (4000);
        l_lin_msg             VARCHAR2 (4000);

        -- Added for Change 1.1
        l_pay_group           PO_LOOKUP_CODES.LOOKUP_CODE%TYPE;
        l_pay_method          AP_LOOKUP_CODES.LOOKUP_CODE%TYPE;
        -- End of Change

        -- Added for CCR0008507
        l_retn_msg            VARCHAR2 (4000);
        l_mtd_boolean         BOOLEAN;
        l_mtd_org_name        VARCHAR2 (100);
        l_mtd_flag            VARCHAR2 (1);
    -- End of Change

    BEGIN
        FOR r_valid_hdr IN hdr_cur
        LOOP
            l_invoice_id          := NULL;
            l_hdr_status          := g_interfaced;
            l_hdr_msg             := NULL;
            l_lin_count           := 0;
            l_total_line_amount   := 0;
            l_pay_group           := NULL;
            l_pay_method          := NULL;

            BEGIN
                SELECT apps.ap_invoices_interface_s.NEXTVAL
                  INTO l_invoice_id
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_invoice_id   := NULL;
            END;

            -- Start of Change 1.1

            -- Derive Pay Group and Payment Method if exists in Valueset for OU

            IF r_valid_hdr.org_id IS NOT NULL
            THEN
                l_pay_group    := NULL;
                l_pay_method   := NULL;

                BEGIN
                    SELECT ffv.attribute2, ffv.attribute3
                      INTO l_pay_group, l_pay_method
                      FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values ffv
                     WHERE     ffvs.flex_value_set_id = ffv.flex_value_set_id
                           AND ffvs.flex_value_set_name =
                               'XXD_AP_LUCERNEX_PAY_GROUP_VS'
                           AND ffv.enabled_flag = 'Y'
                           AND SYSDATE BETWEEN NVL (ffv.start_date_active,
                                                    SYSDATE)
                                           AND NVL (ffv.end_date_active,
                                                    SYSDATE)
                           AND ffv.attribute1 = r_valid_hdr.org_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        l_pay_group    := NULL;
                        l_pay_method   := NULL;
                    WHEN OTHERS
                    THEN
                        l_pay_group    := NULL;
                        l_pay_method   := NULL;
                END;
            END IF;

            -- End of Change

            -- Validate org is MTD OU (Added for CCR0008507)

            IF r_valid_hdr.operating_unit IS NOT NULL
            THEN
                l_mtd_org_name   := NULL;
                l_retn_msg       := NULL;
                l_mtd_boolean    := FALSE;
                l_mtd_flag       := 'N';
                l_mtd_boolean    :=
                    is_mtd_org (p_org_name       => r_valid_hdr.operating_unit,
                                x_mtd_org_name   => l_mtd_org_name,
                                x_ret_msg        => l_retn_msg);

                IF l_mtd_boolean = TRUE OR l_mtd_org_name IS NOT NULL
                THEN
                    l_mtd_flag   := 'Y';
                END IF;
            END IF;

            -- end of Change

            ---- FOR loop to validate line amount with header amount.
            FOR r_valid_line
                IN line_cur (
                       p_invoice_num   => r_valid_hdr.invoice_number,
                       p_vendor_num    => r_valid_hdr.vendor_number,
                       p_org_name      => r_valid_hdr.operating_unit,
                       p_vendor_site   => r_valid_hdr.supplier_site_code,
                       p_inv_type      => r_valid_hdr.invoice_type_lookup_code) --Line Loop first Start to
            LOOP
                l_total_line_amount   :=
                    l_total_line_amount + NVL (r_valid_line.line_amount, 0);

                -- assign temp hdr id to all the lines belongs to this hdr, so that same can be used for update when the line for loop is done
                UPDATE xxdo.xxd_ap_lcx_invoices_stg_t
                   SET temp_invoice_hdr_id   = l_invoice_id
                 WHERE     request_id = gn_request_id
                       AND record_id = r_valid_line.record_id;
            END LOOP;

            l_total_line_amount   :=
                  l_total_line_amount
                + NVL (r_valid_hdr.user_entered_tax, 0)
                + NVL (r_valid_hdr.tax_control_amt, 0);

            IF     l_total_line_amount <> r_valid_hdr.invoice_amount
               AND NVL (l_mtd_flag, 'N') = 'N'         -- Added for CCR0008507
            THEN
                l_hdr_status   := g_errored;
                l_hdr_msg      :=
                       l_hdr_msg
                    || ' Invoice amount does not match with total line amounts.';

                UPDATE xxdo.xxd_ap_lcx_invoices_stg_t
                   SET status = l_hdr_status, error_msg = l_hdr_msg, temp_invoice_hdr_id = NULL
                 WHERE     temp_invoice_hdr_id = l_invoice_id
                       AND request_id = gn_request_id;

                COMMIT;
                CONTINUE;
            END IF;


            FOR r_valid_line
                IN line_cur (
                       p_invoice_num   => r_valid_hdr.invoice_number,
                       p_vendor_num    => r_valid_hdr.vendor_number,
                       p_org_name      => r_valid_hdr.operating_unit,
                       p_vendor_site   => r_valid_hdr.supplier_site_code,
                       p_inv_type      => r_valid_hdr.invoice_type_lookup_code) --Line Loop SECOND Start
            LOOP
                l_line_status       := g_interfaced;
                l_invoice_line_id   := NULL;
                l_lin_msg           := NULL;

                BEGIN
                    l_lin_count   := l_lin_count + 1;

                    BEGIN
                        SELECT apps.ap_invoice_lines_interface_s.NEXTVAL
                          INTO l_invoice_line_id
                          FROM DUAL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_invoice_line_id   := NULL;
                    END;

                    UPDATE xxdo.xxd_ap_lcx_invoices_stg_t
                       SET temp_invoice_line_id = l_invoice_line_id, temp_invoice_hdr_id = l_invoice_id, line_number = l_lin_count
                     WHERE     record_id = r_valid_line.record_id
                           AND request_id = gn_request_id;

                    BEGIN
                        INSERT INTO apps.ap_invoice_lines_interface (
                                        invoice_id,
                                        invoice_line_id,
                                        line_number,
                                        line_type_lookup_code,
                                        amount,
                                        accounting_date,
                                        dist_code_combination_id,
                                        distribution_set_id,
                                        ship_to_location_id,
                                        description,
                                        created_by,
                                        creation_date,
                                        last_updated_by,
                                        last_update_date,
                                        attribute_category,
                                        attribute2,
                                        po_header_id,
                                        po_line_id,
                                        po_shipment_num,
                                        asset_book_type_code,
                                        asset_category_id,
                                        assets_tracking_flag,
                                        prorate_across_flag,
                                        deferred_acctg_flag,
                                        def_acctg_start_date,
                                        def_acctg_end_date,
                                        tax_classification_code)
                                 VALUES (
                                            l_invoice_id,
                                            l_invoice_line_id,
                                            l_lin_count,
                                            r_valid_line.line_type,
                                            r_valid_line.line_amount,
                                            r_valid_hdr.gl_date,
                                            r_valid_line.dist_account_id,
                                            r_valid_line.dist_set_id,
                                            r_valid_line.ship_to_location_id,
                                            r_valid_line.line_description,
                                            gn_created_by,
                                            gd_sysdate,
                                            gn_last_updated_by,
                                            gd_sysdate,
                                            'Invoice Lines Data Elements',
                                            r_valid_line.interco_exp_account_id,
                                            r_valid_line.po_header_l_id,
                                            r_valid_line.po_line_id,
                                            1,
                                            r_valid_line.asset_book_code,
                                            r_valid_line.asset_cat_id,
                                            r_valid_line.asset_flag,
                                            r_valid_line.prorate_flag,
                                            r_valid_line.deferred_flag,
                                            r_valid_line.deferred_start_date,
                                            r_valid_line.deferred_end_date,
                                            r_valid_line.tax_classification_code);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_line_status   := g_errored;
                            l_lin_msg       :=
                                   l_lin_msg
                                || ' Error inserting into staging lines.';
                    --NULL;
                    END;

                    IF l_line_status = g_errored
                    THEN
                        l_hdr_status   := l_line_status;
                        l_hdr_msg      :=
                               l_hdr_msg
                            || ' Error in line: '
                            || TO_CHAR (l_lin_count);
                    END IF;
                END;
            END LOOP;                                         -- END Line Loop

            BEGIN
                INSERT INTO apps.ap_invoices_interface (
                                invoice_id,
                                invoice_num,
                                vendor_id,
                                vendor_site_id,
                                invoice_amount,
                                description,
                                source,
                                org_id,
                                payment_method_code,
                                terms_id,
                                po_number,
                                invoice_type_lookup_code,
                                gl_date,
                                invoice_date,
                                invoice_currency_code,
                                exchange_date,
                                created_by,
                                creation_date,
                                last_updated_by,
                                last_update_date,
                                control_amount,
                                exclusive_payment_flag,
                                attribute_category,
                                attribute1,
                                attribute2,
                                attribute3,
                                attribute4,
                                attribute5,
                                attribute6,
                                attribute7,
                                attribute8,
                                attribute10,
                                attribute11,
                                pay_group_lookup_code, -- Added for Change 1.1
                                calc_tax_during_import_flag -- Added for CCR0008507
                                                           )
                     VALUES (l_invoice_id, r_valid_hdr.invoice_number, r_valid_hdr.vendor_id, r_valid_hdr.vendor_site_id, r_valid_hdr.invoice_amount, r_valid_hdr.invoice_description, g_invoice_source, r_valid_hdr.org_id, l_pay_method, -- Added as per change 1.1
                                                                                                                                                                                                                                           --r_valid_hdr.payment_method,-- Commented as per change 1.1
                                                                                                                                                                                                                                           r_valid_hdr.payment_term_id, r_valid_hdr.po_number_h, r_valid_hdr.invoice_type_lookup_code, r_valid_hdr.gl_date, r_valid_hdr.invoice_date, r_valid_hdr.currency_code, r_valid_hdr.gl_date, gn_created_by, gd_sysdate, gn_last_updated_by, gd_sysdate, r_valid_hdr.tax_control_amt, r_valid_hdr.pay_alone_flag, 'Invoice Global Data Elements', r_valid_hdr.user_entered_tax, r_valid_hdr.date_sent_approver, r_valid_hdr.misc_notes, r_valid_hdr.approver, r_valid_hdr.chargeback, r_valid_hdr.invoice_number_d, r_valid_hdr.payment_ref_number, r_valid_hdr.sample_inv_flag, r_valid_hdr.fapio_flag, r_valid_hdr.invoice_add_info
                             , l_pay_group,           -- Added for Change 1.1,
                                            DECODE (l_mtd_flag, 'Y', 'Y') -- Added for CCR0008507
                                                                         );

                UPDATE xxdo.xxd_ap_lcx_invoices_stg_t
                   SET status = l_hdr_status, error_msg = l_hdr_msg
                 WHERE     temp_invoice_hdr_id = l_invoice_id
                       AND request_id = gn_request_id;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_hdr_status   := g_errored;
                    l_hdr_msg      :=
                           l_hdr_msg
                        || ' Error inserting staging Header. '
                        || SQLERRM;
            END;
        END LOOP;                                           -- END Header Loop

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_hdr_status   := g_errored;
            l_hdr_msg      :=
                   l_hdr_msg
                || ' Exception while inserting staging Header. '
                || SQLERRM;
    END load_interface;

    PROCEDURE create_invoices (x_ret_code   OUT VARCHAR2,
                               x_ret_msg    OUT VARCHAR2)
    IS
        l_request_id       NUMBER;
        l_req_boolean      BOOLEAN;
        l_req_phase        VARCHAR2 (30);
        l_req_status       VARCHAR2 (30);
        l_req_dev_phase    VARCHAR2 (30);
        l_req_dev_status   VARCHAR2 (30);
        l_req_message      VARCHAR2 (4000);
        l_invoice_count    NUMBER := 0;
        ex_no_invoices     EXCEPTION;

        CURSOR get_invoice_orgwise IS
            (SELECT DISTINCT org_id
               FROM apps.ap_invoices_interface
              WHERE     NVL (status, 'XXX') NOT IN ('PROCESSED', 'REJECTED')
                    AND created_by = gn_created_by
                    AND source = g_invoice_source);
    BEGIN
        FOR i IN get_invoice_orgwise
        LOOP
            apps.mo_global.set_policy_context ('S', i.org_id);
            apps.mo_global.init ('SQLAP');

            l_request_id   :=
                apps.fnd_request.submit_request (
                    application   => 'SQLAP',
                    program       => 'APXIIMPT',
                    description   => '',    --'Payables Open Interface Import'
                    start_time    => SYSDATE,                         --,NULL,
                    sub_request   => FALSE,
                    argument1     => i.org_id,                      --2 org_id
                    argument2     => g_invoice_source,
                    argument3     => '',
                    argument4     => 'N/A',
                    argument5     => '',
                    argument6     => '',
                    argument7     =>
                        TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'),
                    argument8     => 'N',                      --'N', -- purge
                    argument9     => 'N',               --'N', -- trace_switch
                    argument10    => 'N',               --'N', -- debug_switch
                    argument11    => 'N',           --'N', -- summarize report
                    argument12    => 1000,        --1000, -- commit_batch_size
                    argument13    => apps.fnd_global.user_id,        --'1037',
                    argument14    => apps.fnd_global.login_id   --'1347386776'
                                                             );

            IF l_request_id <> 0
            THEN
                COMMIT;
                apps.fnd_file.put_line (apps.fnd_file.LOG,
                                        'AP Request ID= ' || l_request_id);
            ELSIF l_request_id = 0
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                       'Request Not Submitted due to "'
                    || apps.fnd_message.get
                    || '".');
            END IF;

            --===IF successful RETURN ar customer trx id as OUT parameter;
            IF l_request_id > 0
            THEN
                LOOP
                    l_req_boolean   :=
                        apps.fnd_concurrent.wait_for_request (
                            l_request_id,
                            15,
                            0,
                            l_req_phase,
                            l_req_status,
                            l_req_dev_phase,
                            l_req_dev_status,
                            l_req_message);
                    EXIT WHEN    UPPER (l_req_phase) = 'COMPLETED'
                              OR UPPER (l_req_status) IN
                                     ('CANCELLED', 'ERROR', 'TERMINATED');
                END LOOP;

                IF     UPPER (l_req_phase) = 'COMPLETED'
                   AND UPPER (l_req_status) = 'ERROR'
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'The Payables Open Import prog completed in error. See log for request id:'
                        || l_request_id);
                    apps.fnd_file.put_line (apps.fnd_file.LOG, SQLERRM);
                    x_ret_code   := '2';
                    x_ret_msg    :=
                           'The Payables Open Import request failed.Review log for Oracle request id '
                        || l_request_id;
                ELSIF     UPPER (l_req_phase) = 'COMPLETED'
                      AND UPPER (l_req_status) = 'NORMAL'
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'The Payables Open Import request id: '
                        || l_request_id);
                ELSE
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'The Payables Open Import request failed.Review log for Oracle request id '
                        || l_request_id);
                    apps.fnd_file.put_line (apps.fnd_file.LOG, SQLERRM);
                    x_ret_code   := '2';
                    x_ret_msg    :=
                           'The Payables Open Import request failed.Review log for Oracle request id '
                        || l_request_id;
                END IF;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN ex_no_invoices
        THEN
            x_ret_msg    :=
                   x_ret_msg
                || ' No invoice data available for invoice creation.';
            x_ret_code   := '2';

            apps.fnd_file.put_line (apps.fnd_file.LOG, x_ret_msg);
        WHEN OTHERS
        THEN
            x_ret_msg    :=
                x_ret_msg || ' Error in create_invoices:' || SQLERRM;
            x_ret_code   := '2';

            apps.fnd_file.put_line (apps.fnd_file.LOG, x_ret_msg);
    END create_invoices;

    PROCEDURE clear_int_tables
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        --Delete Invoice Line rejections
        DELETE apps.ap_interface_rejections apr
         WHERE     parent_table = 'AP_INVOICE_LINES_INTERFACE'
               AND EXISTS
                       (SELECT 1
                          FROM apps.ap_invoice_lines_interface apl, apps.ap_invoices_interface api
                         WHERE     apl.invoice_line_id = apr.parent_id
                               AND api.invoice_id = apl.invoice_id
                               AND api.created_by = apps.fnd_global.user_id
                               AND api.source = g_invoice_source);

        --Delete Invoice rejections
        DELETE apps.ap_interface_rejections apr
         WHERE     parent_table = 'AP_INVOICES_INTERFACE'
               AND EXISTS
                       (SELECT 1
                          FROM apps.ap_invoices_interface api
                         WHERE     api.invoice_id = apr.parent_id
                               AND api.created_by = apps.fnd_global.user_id --1037
                               AND api.source = g_invoice_source);

        --Delete Invoice lines interface
        DELETE apps.ap_invoice_lines_interface lint
         WHERE EXISTS
                   (SELECT 1
                      FROM apps.ap_invoices_interface api
                     WHERE     api.invoice_id = lint.invoice_id
                           AND api.created_by = apps.fnd_global.user_id
                           AND api.source = g_invoice_source);

        --Delete Invoices interface
        DELETE apps.ap_invoices_interface api
         WHERE     1 = 1
               AND api.created_by = apps.fnd_global.user_id
               AND api.source = g_invoice_source;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END clear_int_tables;

    PROCEDURE check_data (x_ret_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
    IS
        CURSOR c_hdr IS
              SELECT org_id, vendor_id, vendor_site_id,
                     invoice_number, temp_invoice_hdr_id, invoice_type_lookup_code
                FROM xxdo.xxd_ap_lcx_invoices_stg_t
               WHERE     1 = 1
                     AND status = g_interfaced
                     AND request_id = gn_request_id
            GROUP BY org_id, vendor_id, vendor_site_id,
                     invoice_number, temp_invoice_hdr_id, invoice_type_lookup_code;

        CURSOR c_line (p_temp_hdr_id IN NUMBER)
        IS
            SELECT *
              FROM xxdo.xxd_ap_lcx_invoices_stg_t
             WHERE 1 = 1 AND temp_invoice_hdr_id = p_temp_hdr_id;

        CURSOR c_hdr_rej (p_header_id IN NUMBER)
        IS
            SELECT reject_lookup_code, get_error_desc (reject_lookup_code) error_message
              FROM apps.ap_interface_rejections
             WHERE     parent_id = p_header_id
                   AND parent_table = 'AP_INVOICES_INTERFACE';

        CURSOR c_line_rej (p_line_id IN NUMBER)
        IS
            SELECT reject_lookup_code, get_error_desc (reject_lookup_code) error_message
              FROM apps.ap_interface_rejections
             WHERE     parent_id = p_line_id
                   AND parent_table = 'AP_INVOICE_LINES_INTERFACE';


        l_hdr_count      NUMBER := 0;
        l_line_count     NUMBER := 0;
        l_invoice_id     NUMBER := 0;
        l_hdr_boolean    BOOLEAN := NULL;
        l_line_boolean   BOOLEAN := NULL;
        l_hdr_error      VARCHAR2 (2000);
        l_line_error     VARCHAR2 (2000);
        l_status         VARCHAR2 (30);
    BEGIN
        FOR r_hdr IN c_hdr
        LOOP
            fnd_file.put_line (
                fnd_file.LOG,
                ' Inside header Loop of check_data r_hdr.org_id:' || r_hdr.org_id);
            fnd_file.put_line (
                fnd_file.LOG,
                   ' Inside header Loop of check_data rr_hdr.invoice_number:'
                || r_hdr.invoice_number);
            fnd_file.put_line (
                fnd_file.LOG,
                ' Inside header Loop of check_data r_hdr.vendor_id:' || r_hdr.vendor_id);
            fnd_file.put_line (
                fnd_file.LOG,
                   ' Inside header Loop of check_data r_hdr.vendor_site_id:'
                || r_hdr.vendor_site_id);
            l_invoice_id    := NULL;
            l_status        := NULL;

            l_hdr_boolean   := NULL;

            l_hdr_boolean   :=
                is_invoice_created (
                    p_org_id           => r_hdr.org_id,
                    p_invoice_num      => r_hdr.invoice_number,
                    p_vendor_id        => r_hdr.vendor_id,
                    p_vendor_site_id   => r_hdr.vendor_site_id,
                    p_inv_type         => r_hdr.invoice_type_lookup_code,
                    x_invoice_id       => l_invoice_id);

            IF l_hdr_boolean = TRUE
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       ' invoice created for the above combination. Invoice id is:'
                    || l_invoice_id);

                UPDATE xxdo.xxd_ap_lcx_invoices_stg_t
                   SET status = g_created, invoice_id = l_invoice_id, error_msg = '',
                       last_update_date = gd_sysdate
                 WHERE temp_invoice_hdr_id = r_hdr.temp_invoice_hdr_id;
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                    ' error while creating invoice for the above combination');
                l_hdr_error   := ' Interface Header Error';

                FOR r_hdr_rej IN c_hdr_rej (r_hdr.temp_invoice_hdr_id)
                LOOP
                    l_hdr_error   :=
                        SUBSTR (
                            l_hdr_error || '. ' || r_hdr_rej.error_message,
                            1,
                            1998);
                END LOOP;

                fnd_file.put_line (fnd_file.LOG, l_hdr_error);

                UPDATE xxdo.xxd_ap_lcx_invoices_stg_t
                   SET status = g_errored, error_msg = SUBSTR (error_msg || l_hdr_error, 1, 3998), last_update_date = gd_sysdate
                 WHERE temp_invoice_hdr_id = r_hdr.temp_invoice_hdr_id;
            END IF;

            FOR r_line IN c_line (r_hdr.temp_invoice_hdr_id)
            LOOP
                l_line_boolean   := NULL;
                l_line_boolean   :=
                    is_line_created (p_invoice_id    => l_invoice_id,
                                     p_line_number   => r_line.line_number);

                IF l_line_boolean = TRUE
                THEN
                    UPDATE xxdo.xxd_ap_lcx_invoices_stg_t
                       SET status = g_created, error_msg_line = '', last_update_date = gd_sysdate
                     WHERE temp_invoice_line_id = r_line.temp_invoice_line_id;
                ELSE
                    l_line_error   := 'Interface Line Error';

                    FOR r_line_rej
                        IN c_line_rej (r_line.temp_invoice_line_id)
                    LOOP
                        l_line_error   :=
                            SUBSTR (
                                l_line_error || '. ' || r_line_rej.error_message,
                                1,
                                1998);
                    END LOOP;

                    UPDATE xxdo.xxd_ap_lcx_invoices_stg_t
                       SET status = g_errored, error_msg_line = SUBSTR (error_msg_line || l_line_error, 1, 3998), last_update_date = gd_sysdate
                     WHERE temp_invoice_line_id = r_line.temp_invoice_line_id;

                    UPDATE xxdo.xxd_ap_lcx_invoices_stg_t
                       SET status = g_errored, error_msg = error_msg || ' Error in Line:' || r_line.line_number, last_update_date = gd_sysdate
                     WHERE temp_invoice_hdr_id = r_hdr.temp_invoice_hdr_id;
                END IF;
            END LOOP;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg    := x_ret_msg || ' Error in check_data: ' || SQLERRM;
            x_ret_code   := '2';
    --apps.fnd_file.put_line(apps.fnd_file.log,SQLERRM);
    END check_data;

    FUNCTION is_invoice_created (p_org_id IN NUMBER, p_invoice_num IN VARCHAR2, p_vendor_id IN NUMBER
                                 , p_vendor_site_id IN NUMBER, p_inv_type IN VARCHAR2, x_invoice_id OUT NUMBER)
        RETURN BOOLEAN
    IS
        l_invoice_id   NUMBER := 0;
    BEGIN
        SELECT invoice_id
          INTO l_invoice_id
          FROM apps.ap_invoices_all
         WHERE     1 = 1
               AND invoice_num = p_invoice_num
               AND org_id = p_org_id
               AND vendor_id = p_vendor_id
               AND vendor_site_id = p_vendor_site_id
               AND invoice_type_lookup_code = p_inv_type;

        x_invoice_id   := l_invoice_id;
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_invoice_id   := NULL;
            RETURN FALSE;
    END is_invoice_created;

    FUNCTION is_line_created (p_invoice_id    IN NUMBER,
                              p_line_number   IN NUMBER)
        RETURN BOOLEAN
    IS
        l_count   NUMBER := 0;
    BEGIN
        SELECT COUNT (1)
          INTO l_count
          FROM apps.ap_invoice_lines_all
         WHERE invoice_id = p_invoice_id AND line_number = p_line_number;

        IF l_count = 1
        THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN FALSE;
    END is_line_created;

    FUNCTION get_error_desc (p_rejection_code IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_desc   VARCHAR2 (240);
    BEGIN
        SELECT description
          INTO l_desc
          FROM apps.fnd_lookup_values
         WHERE     lookup_code = p_rejection_code
               AND lookup_type = 'REJECT CODE'
               AND language = USERENV ('LANG');

        RETURN l_desc;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_error_desc;

    PROCEDURE update_soa_data (x_ret_code   OUT VARCHAR2,
                               x_ret_msg    OUT VARCHAR2)
    IS
        CURSOR update_soa IS
            SELECT *
              FROM xxdo.xxd_ap_lcx_invoices_stg_t
             WHERE request_id = gn_request_id;
    BEGIN
        FOR i IN update_soa
        LOOP
            UPDATE xxdo.xxd_ap_lcx_invoices_t a
               SET status = i.status, -- error_msg = i.error_msg,
                                      error_msg = SUBSTR (i.error_msg || ' - ' || i.error_msg_line, 1, 3900), -- Added as per change 1.2
                                                                                                              last_update_date = i.last_update_date
             WHERE record_id = i.record_id;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END update_soa_data;

    --- THIS IS TO UPDATE LAST RUN PROFILE
    PROCEDURE update_proc (p_input        IN     VARCHAR2,
                           x_ret_status      OUT VARCHAR2,
                           x_ret_msg         OUT VARCHAR2)
    IS
        l_date   VARCHAR2 (50);
        VALUE    BOOLEAN;
    BEGIN
        l_date         := TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS');
        -- note id  Doc ID 943710.1
        VALUE          :=
            fnd_profile.save ('XXD_AP_LCX_VENDCUST_LASTRUNDATE_PRF',
                              l_date,
                              'SITE');

        x_ret_status   := 'S';
        x_ret_msg      := ' Update is succesful ';
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_status   := 'E';
            x_ret_msg      := ' Error while updating the profile ';
    END update_proc;
END xxd_ap_lcx_inv_inbound_pkg;
/


GRANT EXECUTE, DEBUG ON APPS.XXD_AP_LCX_INV_INBOUND_PKG TO SOA_INT
/
