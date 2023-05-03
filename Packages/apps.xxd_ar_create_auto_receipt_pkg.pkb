--
-- XXD_AR_CREATE_AUTO_RECEIPT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:31 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AR_CREATE_AUTO_RECEIPT_PKG"
AS
    --  ####################################################################################################
    --  Author(s)       : Showkath Ali (Suneratech Consultant)
    --  System          : Oracle Applications
    --  Subsystem       : EBS(Accounts Receivables)
    --  Change          : CCR0008295
    --  Schema          : APPS
    --  Purpose         : This package is used to create receipts and apply to invoices of DXLAB
    --  Dependency      : None
    --  Change History
    --  --------------
    --  Date            Name                Ver     Change          Description
    --  ----------      --------------      -----   -------------   ---------------------
    --  12-Dec-2019      Showkath Ali       1.0     NA              Initial Version
    --  ####################################################################################################

    gn_user_id        CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id       CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id         CONSTANT NUMBER := fnd_global.org_id;
    gn_resp_id        CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id   CONSTANT NUMBER := fnd_global.resp_appl_id;

    /***********************************************************************************************
 **************** Procudure to identify eligible recods and to insert into custom table**********
 ************************************************************************************************/

    PROCEDURE insert_eligible_receipts_prc (p_errbuf OUT VARCHAR2, p_retcode OUT NUMBER, p_invoice_number IN VARCHAR2
                                            , p_order_number IN VARCHAR2, p_invoice_date_from IN DATE, p_invoice_date_to IN DATE)
    AS
        CURSOR eligible_receipts_cur IS
              -- Cursor to fetch the eligible records for auto receipt
              SELECT ooha.order_number, hca.account_number, ooha.header_id,
                     rcta.trx_number, rcta.customer_trx_id, rcta.trx_date,
                     (apsa.amount_due_original) trx_amount, rcta.invoice_currency_code, rcta.org_id,
                     hou.name ou_name, rcta.set_of_books_id
                FROM oe_order_headers_all ooha, ra_customer_trx_all rcta, ra_customer_trx_lines_all rctl,
                     ar_payment_schedules_all apsa, hz_parties hp, hz_cust_accounts hca,
                     hr_operating_units hou
               WHERE     1 = 1
                     AND rcta.customer_trx_id = rctl.customer_trx_id
                     AND rctl.interface_line_attribute1 =
                         TO_CHAR (ooha.order_number)
                     AND rcta.customer_trx_id = apsa.customer_trx_id
                     AND rcta.bill_to_customer_id = apsa.customer_id
                     AND rcta.bill_to_site_use_id = apsa.customer_site_use_id
                     AND hp.party_id = hca.party_id
                     AND hca.cust_account_id = rcta.bill_to_customer_id
                     AND ooha.sold_to_org_id = hca.cust_account_id
                     AND hou.organization_id = rcta.org_id
                     AND hca.status = 'A'
                     AND hca.attribute1 = 'DXLAB'                     -- Brand
                     AND ooha.attribute5 = 'DXLAB'
                     AND apsa.status = 'OP'                   -- Open Invoices
                     AND apsa.class = 'INV'
                     AND apsa.amount_due_remaining > 0 -- Amount should be greater than zero
                     AND apsa.amount_due_original - apsa.amount_due_remaining =
                         0                              -- No partial Invoices
                     AND ooha.flow_status_code IN ('BOOKED', 'CLOSED')
                     AND ooha.order_number =
                         NVL (p_order_number, ooha.order_number)
                     AND rcta.trx_number =
                         NVL (p_invoice_number, rcta.trx_number)
                     AND rcta.trx_date >=
                         NVL (p_invoice_date_from, rcta.trx_date)
                     AND rcta.trx_date <=
                         NVL (p_invoice_date_to, rcta.trx_date)
                     AND rcta.org_id = gn_org_id      -- Responsibility Org Id
                     AND EXISTS
                             (SELECT 1
                                FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffv
                               WHERE     ffvs.flex_value_set_name =
                                         'XXD_AR_AUTO_APPLICATION' -- Value set holds customer number, auto receipt flag, Auto adjust flag, Default receipt method
                                     AND ffvs.flex_value_set_id =
                                         ffv.flex_value_set_id
                                     AND ffv.enabled_flag = 'Y'
                                     AND SYSDATE BETWEEN NVL (
                                                             ffv.start_date_active,
                                                             SYSDATE)
                                                     AND NVL (
                                                             ffv.end_date_active,
                                                             SYSDATE)
                                     AND ffv.flex_value = hca.account_number -- DXLAB Customer Number
                                     AND NVL (ffv.attribute1, 'N') = 'Y') -- Auto Receipt falg
            GROUP BY ooha.order_number, hca.account_number, ooha.header_id,
                     rcta.trx_number, rcta.customer_trx_id, rcta.trx_date,
                     rcta.org_id, hou.name, rcta.set_of_books_id,
                     rcta.invoice_currency_code, apsa.amount_due_original;

        l_trx_count      NUMBER := 0;
        l_cursor_count   NUMBER := 0;
    BEGIN
        gv_debug_message   := 'insert_eligible_receipts_prc Procedure';
        fnd_file.put_line (fnd_file.LOG,
                           'Responsibility Org id:' || gn_org_id);

        FOR i IN eligible_receipts_cur
        LOOP
            l_cursor_count   := l_cursor_count + 1;

            -- Before inserting into the table verify the invoice number is exist or not, if exist remove status and error message
            BEGIN
                SELECT COUNT (1)
                  INTO l_trx_count
                  FROM xxdo.xxd_ar_auto_receipts_t
                 WHERE trx_number = i.trx_number AND status <> 'S';

                IF l_trx_count = 1
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Invoice Number is exist with error status, removed status and error message'
                        || i.trx_number
                        || '-'
                        || gv_debug_message);

                    BEGIN
                        UPDATE xxdo.xxd_ar_auto_receipts_t
                           SET status = NULL, error_message = NULL, updated_by = gn_created_by,
                               last_update_date = SYSDATE, request_id = gn_request_id
                         WHERE trx_number = i.trx_number;

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Updating the custom table failed for trx_number:'
                                || i.trx_number);
                    END;
                ELSE
                    -- Insert the cursor data in custom table
                    BEGIN
                        INSERT INTO xxdo.xxd_ar_auto_receipts_t (order_number, customer_number, header_id, trx_number, customer_trx_id, trx_date, trx_amount, invoice_currency_code, operating_unit_id, operating_unit, creation_date, created_by, updated_by, last_update_date, request_id
                                                                 , ledger_id)
                             VALUES (i.order_number, i.account_number, i.header_id, i.trx_number, i.customer_trx_id, i.trx_date, i.trx_amount, i.invoice_currency_code, i.org_id, i.ou_name, SYSDATE, gn_created_by, gn_created_by, SYSDATE, gn_request_id
                                     , i.set_of_books_id);

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Inserting data into custom table failed'
                                || '-'
                                || SQLERRM
                                || '-'
                                || gv_debug_message);

                            p_retcode   := 1;
                            p_errbuf    :=
                                'Inserting data into custom table failed';
                            EXIT;
                    END;
                END IF;
            END;
        END LOOP;

        --If no records exists complete the program in waring and return

        IF l_cursor_count = 0
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'No Invoice exist for the given parameters');
            p_retcode   := 1;
            p_errbuf    := 'No Invoice exist for the given parameters';
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'In insert_eligible_receipts_prc EXCEPTION');
    END insert_eligible_receipts_prc;                                  -- main

    /***********************************************************************************************
 ***************************************** Procudure to Validate eligible records****************
 ************************************************************************************************/

    PROCEDURE validations_prc (p_errbuf OUT VARCHAR2, p_retcode OUT NUMBER)
    AS
        -- Cursor to fetch new recors from custom table

        CURSOR new_records_cur IS
            SELECT *
              FROM xxdo.xxd_ar_auto_receipts_t
             WHERE status IS NULL;

        -- Cursor to get count of payment methods from order line s for a given invoice

        CURSOR payment_method_cur (p_order_number VARCHAR2)
        IS
            SELECT COUNT (DISTINCT oola.attribute6)
              FROM oe_order_headers_all ooha, oe_order_lines_all oola
             WHERE     ooha.header_id = oola.header_id
                   AND ooha.order_number = p_order_number;

        l_payment_method         VARCHAR2 (100);
        l_payment_method_count   NUMBER;
    BEGIN
        gv_debug_message   := 'Validations Procedure';

        FOR i IN new_records_cur
        LOOP
            -- Validation1: payment method for a given invoice from order line level shoould not be multiple
            -- Get the payment method count
            OPEN payment_method_cur (i.order_number);

            FETCH payment_method_cur INTO l_payment_method_count;

            IF payment_method_cur%NOTFOUND
            THEN
                l_payment_method_count   := 0;
            END IF;

            CLOSE payment_method_cur;

            fnd_file.put_line (
                fnd_file.LOG,
                   'Payment Method Count:'
                || l_payment_method_count
                || '-'
                || gv_debug_message);

            --Payment method count is more than 1 warning the program and quit

            IF l_payment_method_count > 1
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Multiple Payment Methods at sales order lines for a given invoice:'
                    || i.trx_number
                    || '-'
                    || gv_debug_message);

                --Update the error message in staging table

                BEGIN
                    UPDATE xxdo.xxd_ar_auto_receipts_t
                       SET status = 'E', error_message = 'Multiple Payment Methods at sales order lines for a given invoice:' || i.trx_number || '-' || gv_debug_message, updated_by = gn_created_by,
                           last_update_date = SYSDATE
                     WHERE trx_number = i.trx_number;

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Updating the custom table failed for Invoice:'
                            || i.trx_number
                            || '-'
                            || gv_debug_message);
                END;

                p_retcode   := 1;
                p_errbuf    :=
                       'Multiple Payment Methods at sales order lines for a given invoice:'
                    || i.trx_number
                    || '-'
                    || gv_debug_message;
            --Payment method count is 0 update the staging table as no payment method
            ELSIF l_payment_method_count = 0
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'No Payment Method exists at sales order lines for a given invoice:'
                    || i.trx_number
                    || '-'
                    || gv_debug_message);

                --Update the error message in staging table

                /* BEGIN
                     UPDATE xxdo.xxd_ar_auto_receipts_t
                     SET
                         status = 'E',
                         error_message = 'No Payment Method exists at sales order lines for a given invoice:'
                                         || i.trx_number
                                         || '-'
                                         || gv_debug_message,
                         updated_by = gn_created_by,
                         last_update_date = SYSDATE
                     WHERE
                         trx_number = i.trx_number;

                     COMMIT;
                 EXCEPTION
                     WHEN OTHERS THEN
                         fnd_file.put_line(fnd_file.log, 'Updating the custom table failed for Invoice:'
                                                         || i.trx_number
                                                         || '-'
                                                         || gv_debug_message);
                 END;

                 p_retcode := 1;
                 p_errbuf := 'No Payment Method exists at sales order lines for a given invoice:'
                             || i.trx_number
                             || '-'
                             || gv_debug_message;*/
                l_payment_method   := 'Default Pay Method';
            ELSIF l_payment_method_count = 1
            THEN
                -- Query to fetch payment method from order line level
                BEGIN
                    SELECT DISTINCT oola.attribute6
                      INTO l_payment_method
                      FROM oe_order_headers_all ooha, oe_order_lines_all oola
                     WHERE     ooha.header_id = oola.header_id
                           AND ooha.order_number = i.order_number;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Payment method for the invoice'
                        || i.trx_number
                        || '-'
                        || l_payment_method
                        || '-'
                        || gv_debug_message);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_payment_method   := NULL;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Failed to fetch the Payment method for the invoice'
                            || i.trx_number
                            || '-'
                            || gv_debug_message);
                END;
            END IF;

            -- Validation 1 end
            -- Update the payment method in staging table

            IF l_payment_method IS NOT NULL
            THEN
                BEGIN
                    UPDATE xxdo.xxd_ar_auto_receipts_t
                       SET payment_method = l_payment_method, status = 'V', updated_by = gn_created_by,
                           last_update_date = SYSDATE
                     WHERE trx_number = i.trx_number;

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Updating the custom table failed for Invoice:'
                            || i.trx_number
                            || '-'
                            || gv_debug_message);
                END;
            ELSE
                BEGIN
                    UPDATE xxdo.xxd_ar_auto_receipts_t
                       SET status = 'E', error_message = 'Failed to fetch the Payment method for the invoice' || i.trx_number || '-' || gv_debug_message, updated_by = gn_created_by,
                           last_update_date = SYSDATE
                     WHERE trx_number = i.trx_number;

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Updating the custom table failed for Invoice:'
                            || i.trx_number
                            || '-'
                            || gv_debug_message);
                END;

                p_retcode   := 1;
                p_errbuf    :=
                       'Failed to fetch the Payment method for the invoice'
                    || i.trx_number
                    || '-'
                    || gv_debug_message;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'In validations_prc Exception');
    END validations_prc;

    /***********************************************************************************************
  ******************* Function to get receipt method for invoice *******************************
  ************************************************************************************************/

    FUNCTION get_receipt_method (p_payment_method IN VARCHAR2, p_operating_unit_id IN NUMBER, p_account_number IN VARCHAR2)
        RETURN NUMBER
    IS
        l_receipt_method   NUMBER;
    BEGIN
        BEGIN
            SELECT attribute2
              INTO l_receipt_method
              FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffv
             WHERE     ffvs.flex_value_set_name = 'XXD_AR_PAY_RECPT_TYPE_VS'
                   AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                   AND ffv.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (ffv.start_date_active, SYSDATE)
                                   AND NVL (ffv.end_date_active, SYSDATE)
                   AND ffv.attribute3 = p_payment_method
                   AND ffv.attribute1 = TO_CHAR (p_operating_unit_id);

            fnd_file.put_line (fnd_file.LOG,
                               'Receipt_method:' || l_receipt_method);
        EXCEPTION
            WHEN OTHERS
            THEN
                l_receipt_method   := NULL;
        END;

        IF l_receipt_method IS NULL
        THEN
            BEGIN
                SELECT attribute3
                  INTO l_receipt_method
                  FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffv
                 WHERE     ffvs.flex_value_set_name =
                           'XXD_AR_AUTO_APPLICATION'
                       AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                       AND ffv.enabled_flag = 'Y'
                       AND SYSDATE BETWEEN NVL (ffv.start_date_active,
                                                SYSDATE)
                                       AND NVL (ffv.end_date_active, SYSDATE)
                       AND ffv.flex_value = p_account_number;

                fnd_file.put_line (
                    fnd_file.LOG,
                    'Default Receipt_method:' || l_receipt_method);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Failed to fetch Receipt_method:' || l_receipt_method);
                    l_receipt_method   := NULL;
            END;
        END IF;

        RETURN (l_receipt_method);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Failed to fetch Receipt_method:' || l_receipt_method);
            l_receipt_method   := NULL;
            RETURN (l_receipt_method);
    END get_receipt_method;

    /***********************************************************************************************
   ******************* Procedure to fetch the Bank details **************************************
   ************************************************************************************************/

    PROCEDURE get_bank_details_prc (p_receipt_method IN NUMBER, p_invoice_currency_code IN VARCHAR2, p_bank_branch_id OUT NUMBER
                                    , p_bank_account_id OUT NUMBER)
    AS
        l_bank_account_id   NUMBER;
        l_bank_branch_id    NUMBER;
    BEGIN
        BEGIN
            --Query to fetch bank branch id and bank account id
            SELECT bau.bank_account_id, cba.bank_branch_id
              INTO l_bank_account_id, l_bank_branch_id
              FROM ar_receipt_methods arm, ar_receipt_method_accounts_all arma, ce_bank_acct_uses_all bau,
                   ce_bank_accounts cba
             WHERE     1 = 1
                   AND NVL (arm.attribute4, 'N') = 'N'
                   AND SYSDATE BETWEEN NVL (arm.start_date, SYSDATE)
                                   AND NVL (arm.end_date, SYSDATE)
                   AND arma.receipt_method_id = arm.receipt_method_id
                   AND bau.bank_acct_use_id = arma.remit_bank_acct_use_id
                   AND cba.bank_account_id = bau.bank_account_id
                   AND NVL (cba.currency_code, p_invoice_currency_code) =
                       p_invoice_currency_code
                   AND cba.account_classification = 'INTERNAL'
                   AND arm.receipt_method_id = p_receipt_method;

            fnd_file.put_line (fnd_file.LOG,
                               'Bank Account id:' || l_bank_account_id);
            fnd_file.put_line (fnd_file.LOG,
                               'Bank Branch id:' || l_bank_branch_id);
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'Failed to fetch Bank details');
                l_bank_account_id   := NULL;
                l_bank_branch_id    := NULL;
        END;

        p_bank_account_id   := l_bank_account_id;
        p_bank_branch_id    := l_bank_branch_id;
    END get_bank_details_prc;

    /***********************************************************************************************
  ******************* Function to get Receipt class id for the receipt_method *******************
  ************************************************************************************************/

    FUNCTION get_receipt_class (p_receipt_method IN NUMBER)
        RETURN NUMBER
    AS
        l_receipt_class_id   NUMBER;
    BEGIN
        SELECT receipt_class_id
          INTO l_receipt_class_id
          FROM ar_receipt_methods
         WHERE receipt_method_id = p_receipt_method;

        RETURN (l_receipt_class_id);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Failed to fetch the receipt class id for the receipt method:'
                || p_receipt_method);
            l_receipt_class_id   := NULL;
            RETURN (l_receipt_class_id);
    END get_receipt_class;

    /***********************************************************************************************
  ******************* Procedure to get  Receipt batch source id and Type ************************
  ************************************************************************************************/

    PROCEDURE receipt_source_details_prc (p_receipt_method IN NUMBER, p_bank_account_id IN NUMBER, p_batch_source_id OUT NUMBER
                                          , p_batch_type OUT VARCHAR2)
    AS
        l_batch_source_id   NUMBER;
        l_batch_type        VARCHAR2 (30);
    BEGIN
        BEGIN
            SELECT batch_source_id, TYPE
              INTO l_batch_source_id, l_batch_type
              FROM ar_batch_sources_all
             WHERE     default_receipt_method_id = p_receipt_method
                   AND remit_bank_acct_use_id = p_bank_account_id;

            fnd_file.put_line (fnd_file.LOG,
                               'Batch_source_id:' || l_batch_source_id);
            fnd_file.put_line (fnd_file.LOG, 'Batch Type:' || l_batch_type);
        EXCEPTION
            WHEN OTHERS
            THEN
                l_batch_source_id   := NULL;
                l_batch_type        := NULL;
                fnd_file.put_line (fnd_file.LOG,
                                   'Failed to fetch Batch source details');
        END;

        p_batch_source_id   := l_batch_source_id;
        p_batch_type        := l_batch_type;
    END receipt_source_details_prc;

    /************************************************************************************************
  ******************* Function to get period status of invoice date*******************************
  ************************************************************************************************/

    FUNCTION get_period_status_inv (p_trx_date          DATE,
                                    p_set_of_books_id   NUMBER)
        RETURN VARCHAR
    IS
        l_period_status   VARCHAR2 (100);
    BEGIN
        SELECT ps.closing_status
          INTO l_period_status
          FROM gl_period_statuses ps, gl_sets_of_books sob, fnd_application_vl fnd
         WHERE     fnd.application_short_name = 'SQLGL'
               AND sob.set_of_books_id = ps.set_of_books_id
               AND fnd.application_id = ps.application_id
               AND ps.adjustment_period_flag = 'N'
               AND (TRUNC (p_trx_date) >= TRUNC (ps.start_date) AND TRUNC (p_trx_date) <= TRUNC (ps.end_date))
               AND ps.set_of_books_id = p_set_of_books_id;

        fnd_file.put_line (fnd_file.LOG,
                           'Invoice Period Status:' || l_period_status);
        RETURN l_period_status;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_period_status   := NULL;
            fnd_file.put_line (fnd_file.LOG,
                               'Invoice Period Status:' || l_period_status);
            RETURN l_period_status;
    END get_period_status_inv;

    /***********************************************************************************************
 ******************* Procedure to create and apply cash receipt to invoices *********************
 ************************************************************************************************/

    PROCEDURE create_apply_receipt_prc (p_errbuf OUT VARCHAR2, p_retcode OUT VARCHAR2, p_result OUT VARCHAR2)
    AS
        -- Cursor to pull valid recors from custom table

        CURSOR valid_records_cur IS
            SELECT *
              FROM xxdo.xxd_ar_auto_receipts_t
             WHERE status = 'V';

        l_receipt_method     NUMBER;
        l_bank_account_id    NUMBER;
        l_bank_branch_id     NUMBER;
        l_receipt_class_id   NUMBER;
        l_batch_source_id    NUMBER;
        l_batch_type         VARCHAR2 (30);
        l_batch_id           NUMBER;
        l_cash_receipt_id    NUMBER;
        l_receipt_number     VARCHAR2 (30);
        l_batch_name         VARCHAR2 (120);
        l_error_msg          VARCHAR2 (2000);
        l_pmt_status         VARCHAR2 (1);
        l_rtn_status         VARCHAR2 (1);
        l_debug              NUMBER := 0;
        l_rc                 NUMBER := 0;
        v_boolean1           BOOLEAN;
        l_sqlerrm            VARCHAR2 (4000);
        l_period_status      VARCHAR2 (100);
        l_receipt_date       DATE;
    BEGIN
        gv_debug_message   := 'create_apply_receipt_prc Procedure';

        -- call the function to get the receipt method
        FOR i IN valid_records_cur
        LOOP
            l_receipt_method   :=
                get_receipt_method (i.payment_method,
                                    i.operating_unit_id,
                                    i.customer_number);

            IF l_receipt_method IS NULL
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Unable to find the Receipt Method for Payment Type' || i.payment_method);

                -- Update the error message i custom table
                BEGIN
                    UPDATE xxdo.xxd_ar_auto_receipts_t
                       SET status = 'E', error_message = 'Unable to find the Receipt Method for Payment Type ' || i.payment_method || '-' || gv_debug_message, updated_by = gn_created_by,
                           last_update_date = SYSDATE
                     WHERE trx_number = i.trx_number;

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Updating the custom table failed for Invoice:'
                            || i.trx_number
                            || '-'
                            || gv_debug_message);
                END;

                p_retcode   := 1;
                p_errbuf    :=
                       'Unable to find the Receipt Method for Payment Type '
                    || i.payment_method;
            ELSE
                -- Update the receipt method in custom table.
                BEGIN
                    UPDATE xxdo.xxd_ar_auto_receipts_t
                       SET receipt_method = l_receipt_method, updated_by = gn_created_by, last_update_date = SYSDATE
                     WHERE trx_number = i.trx_number;

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Updating the custom table failed for Invoice:'
                            || i.trx_number
                            || '-'
                            || gv_debug_message);
                END;

                -- Calling the procedure to get the bank details for the receipt method

                get_bank_details_prc (l_receipt_method, i.invoice_currency_code, l_bank_branch_id
                                      , l_bank_account_id);

                IF l_bank_branch_id IS NULL OR l_bank_account_id IS NULL
                THEN
                    -- Update the custom table with error message.
                    BEGIN
                        UPDATE xxdo.xxd_ar_auto_receipts_t
                           SET status = 'E', error_message = 'Failed to fetch bank details for the receipt method:' || l_receipt_method || '-' || gv_debug_message, updated_by = gn_created_by,
                               last_update_date = SYSDATE
                         WHERE trx_number = i.trx_number;

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Updating the custom table failed for Invoice:'
                                || i.trx_number
                                || '-'
                                || gv_debug_message);
                    END;

                    p_retcode   := 1;
                    p_errbuf    :=
                           'Failed to fetch bank details for the receipt method'
                        || l_receipt_method
                        || '-'
                        || gv_debug_message;
                END IF;

                -- Function to get receipt_class

                l_receipt_class_id   := get_receipt_class (l_receipt_method);

                IF l_receipt_class_id IS NULL
                THEN
                    -- Update the custom table with error message.
                    BEGIN
                        UPDATE xxdo.xxd_ar_auto_receipts_t
                           SET status = 'E', error_message = 'Failed to fetch receipt class for the receipt method:' || l_receipt_method || '-' || gv_debug_message, updated_by = gn_created_by,
                               last_update_date = SYSDATE
                         WHERE trx_number = i.trx_number;

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Updating the custom table failed for Invoice:'
                                || i.trx_number
                                || '-'
                                || gv_debug_message);
                    END;

                    p_retcode   := 1;
                    p_errbuf    :=
                           'Failed to fetch receipt class for the receipt method'
                        || l_receipt_method
                        || '-'
                        || gv_debug_message;
                END IF;

                -- Procedure to get the Receipt batch source id and receipt type

                receipt_source_details_prc (l_receipt_method, l_bank_account_id, l_batch_source_id
                                            , l_batch_type);

                IF l_batch_source_id IS NULL OR l_batch_type IS NULL
                THEN
                    -- Update the custom table with error message.
                    BEGIN
                        UPDATE xxdo.xxd_ar_auto_receipts_t
                           SET status = 'E', error_message = 'Failed to fetch receipt batch source details:' || l_receipt_method || '-' || gv_debug_message, updated_by = gn_created_by,
                               last_update_date = SYSDATE
                         WHERE trx_number = i.trx_number;

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Updating the custom table failed for Invoice:'
                                || i.trx_number
                                || '-'
                                || gv_debug_message);
                    END;

                    p_retcode   := 1;
                    p_errbuf    :=
                           'Failed to fetch receipt batch source details:'
                        || l_receipt_method
                        || '-'
                        || gv_debug_message;
                END IF;

                -- call the Function to get period status of invoice date

                l_period_status      :=
                    get_period_status_inv (i.trx_date, i.ledger_id);

                -- If period status is not open consider the start_date of current open period
                IF l_period_status <> 'O'
                THEN
                    BEGIN
                        SELECT ps.start_date
                          INTO l_receipt_date
                          FROM gl_period_statuses ps, gl_sets_of_books sob, fnd_application_vl fnd
                         WHERE     fnd.application_short_name = 'SQLGL'
                               AND sob.set_of_books_id = ps.set_of_books_id
                               AND fnd.application_id = ps.application_id
                               AND ps.adjustment_period_flag = 'N'
                               AND (TRUNC (SYSDATE) >= TRUNC (ps.start_date) AND TRUNC (SYSDATE) <= TRUNC (ps.end_date))
                               AND ps.set_of_books_id = i.ledger_id
                               AND ps.closing_status = 'O';

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Current Period start date:' || l_receipt_date);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_receipt_date   := NULL;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Failed to fetch start date of current period:'
                                || l_receipt_date);

                            BEGIN
                                UPDATE xxdo.xxd_ar_auto_receipts_t
                                   SET status = 'E', error_message = 'Failed to Fetch start date of Current Period' || gv_debug_message, updated_by = gn_created_by,
                                       last_update_date = SYSDATE
                                 WHERE trx_number = i.trx_number;

                                COMMIT;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Updating the custom table failed for Invoice:'
                                        || i.trx_number
                                        || '-'
                                        || gv_debug_message);
                            END;

                            p_retcode        := 1;
                            p_errbuf         :=
                                'Failed to Fetch start date of Current Period';
                    END;
                ELSE
                    l_receipt_date   := i.trx_date;
                END IF;

                -- Call the Receipt batch creation API
                -- Create Receipt Batch

                fnd_file.put_line (fnd_file.LOG,
                                   'l_batch_type:' || l_batch_type);
                do_ar_utils.create_receipt_batch_trans (
                    p_company             => i.operating_unit,
                    p_batch_source_id     => l_batch_source_id,
                    p_bank_branch_id      => l_bank_branch_id,
                    p_batch_type          => l_batch_type,
                    p_currency_code       => i.invoice_currency_code,
                    p_bank_account_id     => l_bank_account_id,
                    p_batch_date          => l_receipt_date,
                    p_receipt_class_id    => l_receipt_class_id,
                    p_control_count       => 1,
                    p_gl_date             => l_receipt_date,
                    p_receipt_method_id   => l_receipt_method,
                    p_control_amount      => i.trx_amount,
                    p_deposit_date        => l_receipt_date,
                    p_comments            => 'Order# ' || i.order_number,
                    p_auto_commit         => 'N',
                    x_batch_id            => l_batch_id,
                    x_batch_name          => l_batch_name,
                    x_error_msg           => l_error_msg);

                fnd_file.put_line (fnd_file.LOG, 'l_batch_id:' || l_batch_id);
                fnd_file.put_line (fnd_file.LOG,
                                   'l_error_msg:' || l_error_msg);

                IF l_batch_id <> -1
                THEN
                    -- create receipt
                    SELECT xxdo.xxdoec_cash_receipts_s.NEXTVAL
                      INTO l_receipt_number
                      FROM DUAL;

                    l_error_msg   := NULL;
                    do_ar_utils.create_receipt_trans (
                        p_batch_id                   => l_batch_id,
                        p_receipt_number             => l_receipt_number,
                        p_receipt_amt                => i.trx_amount,
                        p_transaction_num            => i.order_number,
                        p_payment_server_order_num   => i.order_number,
                        p_customer_number            => i.customer_number,
                        p_customer_name              => NULL,
                        p_comments                   => 'Order# ' || i.order_number,
                        p_currency_code              =>
                            i.invoice_currency_code,
                        p_location                   => NULL,
                        p_auto_commit                => 'N',
                        x_cash_receipt_id            => l_cash_receipt_id,
                        x_error_msg                  => l_error_msg);

                    IF NVL (l_cash_receipt_id, -200) = -200
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Unable to create Cash Receipt for the amount '
                            || i.trx_amount);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Unable to create Cash Receipt Error: '
                            || l_error_msg);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Unable to create Cash Receipt Error: '
                            || SQLERRM);
                        l_pmt_status   := fnd_api.g_ret_sts_error;
                        -- Update the error message in custom TABLE
                        l_sqlerrm      := SQLERRM;
                        p_result       := 'E';

                        BEGIN
                            UPDATE xxdo.xxd_ar_auto_receipts_t
                               SET status = 'E', error_message = 'Unable to create Cash Receipt Error: ' || '-' || l_error_msg, updated_by = gn_created_by,
                                   last_update_date = SYSDATE
                             WHERE trx_number = i.trx_number;

                            COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Updating the custom table failed for Invoice:'
                                    || i.trx_number
                                    || '-'
                                    || gv_debug_message);
                        END;

                        p_retcode      := 1;
                        p_errbuf       :=
                               'Unable to create Cash Receipt Error: '
                            || '-'
                            || l_error_msg;
                    ELSE
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Successfully created Cash Receipt for the amount '
                            || i.trx_amount);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Cash Receipt ID: ' || l_cash_receipt_id);



                        --Added by Madhav for ENHC0011797
                        l_error_msg   := NULL;
                        -- Apply cash to Invoice
                        do_ar_utils.apply_transaction_trans (
                            p_cash_receipt_id   => l_cash_receipt_id,
                            p_customer_trx_id   => i.customer_trx_id,
                            p_trx_number        => NULL,
                            p_applied_amt       => i.trx_amount,
                            p_discount          => NULL,
                            p_auto_commit       => 'N',
                            x_error_msg         => l_error_msg);

                        IF l_error_msg IS NULL
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Successfully Applied Amount: '
                                || i.trx_amount
                                || ' to Invoice ID: '
                                || i.customer_trx_id);
                            -- UPDATE the Status as Success in custom table

                            p_result   := 'S';

                            BEGIN
                                UPDATE xxdo.xxd_ar_auto_receipts_t
                                   SET status = 'S', receipt_number = l_receipt_number, cash_receipt_id = l_cash_receipt_id,
                                       receipt_amount = i.trx_amount, updated_by = gn_created_by, last_update_date = SYSDATE
                                 WHERE trx_number = i.trx_number;

                                COMMIT;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Updating the custom table failed for Invoice:'
                                        || i.trx_number
                                        || '-'
                                        || gv_debug_message);
                            END;
                        ELSE
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Unable to Apply Cash Receipt to Invoice ID: '
                                || i.customer_trx_id
                                || '-'
                                || l_error_msg);

                            l_pmt_status   := fnd_api.g_ret_sts_error;
                            -- Update the error message in custom TABLE
                            l_sqlerrm      := SQLERRM;
                            p_result       := 'E';

                            BEGIN
                                UPDATE xxdo.xxd_ar_auto_receipts_t
                                   SET status = 'E', error_message = 'Unable to Apply Cash Receipt to Invoice ID: ' || i.customer_trx_id || '-' || l_error_msg, updated_by = gn_created_by,
                                       last_update_date = SYSDATE
                                 WHERE trx_number = i.trx_number;

                                COMMIT;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Updating the custom table failed for Invoice:'
                                        || i.trx_number
                                        || '-'
                                        || gv_debug_message);
                            END;

                            p_retcode      := 1;
                            p_errbuf       :=
                                   'Unable to Apply Cash Receipt to Invoice ID: '
                                || i.customer_trx_id
                                || '-'
                                || l_error_msg;
                        END IF;                    -- Cash Receipt App success
                    END IF;                            -- Cash Receipt success
                ELSE
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Failed to create Cash Receipt Batch'
                        || '-'
                        || l_error_msg);
                    l_pmt_status   := fnd_api.g_ret_sts_error;
                    -- UPDATE the error message in custom TABLE
                    l_sqlerrm      := SQLERRM;
                    p_result       := 'E';

                    BEGIN
                        UPDATE xxdo.xxd_ar_auto_receipts_t
                           SET status = 'E', error_message = 'Failed to create Cash Receipt Batch:' || '-' || l_error_msg, updated_by = gn_created_by,
                               last_update_date = SYSDATE
                         WHERE trx_number = i.trx_number;

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Updating the custom table failed for Invoice:'
                                || i.trx_number
                                || '-'
                                || gv_debug_message);
                    END;

                    p_retcode      := 1;
                    p_errbuf       :=
                           'Failed to create Cash Receipt Batch:'
                        || '-'
                        || l_error_msg;
                END IF;                               -- Receipt Batch success
            END IF;                                -- l_receipt_method IS NULL
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'In create_apply_receipt_prc Exception');
    END create_apply_receipt_prc;        -- procedure create_apply_receipt_prc

    /***********************************************************************************************
  ****************Procedure to print Applied and failed records**********************************
  ************************************************************************************************/

    PROCEDURE print_app_fail_receipts_prc
    AS
        CURSOR success_records_cur IS
            SELECT *
              FROM xxdo.xxd_ar_auto_receipts_t
             WHERE status = 'S' AND request_id = gn_request_id;

        CURSOR failed_records_cur IS
            SELECT *
              FROM xxdo.xxd_ar_auto_receipts_t
             WHERE status = 'E' AND request_id = gn_request_id;

        l_status   VARCHAR2 (10);
    BEGIN
        fnd_file.put_line (fnd_file.output,
                           'Deckers Create Automatic Receipts Program');
        fnd_file.put_line (fnd_file.output,
                           '-----------------------------------------');
        fnd_file.put_line (
            fnd_file.output,
               RPAD ('Customer Number', 30)
            || CHR (9)
            || RPAD ('Trx Number', 30)
            || CHR (9)
            || RPAD ('Trx Amount', 20)
            || CHR (9)
            || RPAD ('Order Number', 20)
            || CHR (9)
            || RPAD ('Operating Unit', 25)
            || CHR (9)
            || RPAD ('Receipt Number', 30)
            || CHR (9)
            || RPAD ('Apply Status', 20)
            || CHR (9)
            || RPAD ('Error Message', 100));

        FOR i IN success_records_cur
        LOOP
            l_status   := 'Success';
            fnd_file.put_line (
                fnd_file.output,
                   RPAD (i.customer_number, 30, ' ')
                || CHR (9)
                || RPAD (i.trx_number, 30, ' ')
                || CHR (9)
                || RPAD (i.trx_amount, 20, ' ')
                || CHR (9)
                || RPAD (i.order_number, 20, ' ')
                || CHR (9)
                || RPAD (i.operating_unit, 25, ' ')
                || CHR (9)
                || RPAD (NVL (i.receipt_number, 'NULL'), 30)
                || CHR (9)
                || RPAD (l_status, 20, ' ')
                || CHR (9)
                || RPAD ('NULL', 1000, ' '));
        END LOOP;

        FOR i IN failed_records_cur
        LOOP
            l_status   := 'Error';
            fnd_file.put_line (
                fnd_file.output,
                   RPAD (i.customer_number, 30, ' ')
                || CHR (9)
                || RPAD (i.trx_number, 30, ' ')
                || CHR (9)
                || RPAD (i.trx_amount, 20, ' ')
                || CHR (9)
                || RPAD (i.order_number, 20, ' ')
                || CHR (9)
                || RPAD (i.operating_unit, 25, ' ')
                || CHR (9)
                || RPAD (NVL (i.receipt_number, 'NULL'), 30)
                || CHR (9)
                || RPAD (l_status, 20, ' ')
                || CHR (9)
                || RPAD (i.error_message, 1000, ' '));
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'In print_app_fail_receipts_prc Exception');
    END print_app_fail_receipts_prc;

    /***********************************************************************************************
 *****************************************Main Procedure*****************************************
 ************************************************************************************************/

    PROCEDURE main (p_errbuf OUT VARCHAR2, p_retcode OUT NUMBER, p_order_number IN VARCHAR2
                    , p_invoice_number IN VARCHAR2, p_invoice_date_from IN DATE, p_invoice_date_to IN DATE)
    AS
        l_errbuf    VARCHAR2 (4000);
        l_retcode   NUMBER;
        l_result    VARCHAR2 (10);
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            '********************************************************');
        fnd_file.put_line (
            fnd_file.LOG,
            'Deckers Create Automatic Receipts program starts here...');
        fnd_file.put_line (
            fnd_file.LOG,
            '********************************************************');
        fnd_file.put_line (
            fnd_file.LOG,
               'Input Parameters Are: p_order_number:'
            || p_order_number
            || ' and p_invoice_number:'
            || p_invoice_number
            || ' and p_invoice_date_from:'
            || p_invoice_date_from
            || ' and p_invoice_date_to:'
            || p_invoice_date_to);

        gv_debug_message   := 'Main Procedure';
        --Calling insert_eligible_receipts_prc procedure
        insert_eligible_receipts_prc (l_errbuf,
                                      l_retcode,
                                      p_invoice_number,
                                      p_order_number,
                                      p_invoice_date_from,
                                      p_invoice_date_to);

        IF l_retcode = 1
        THEN
            p_retcode   := 1;
            p_errbuf    := l_errbuf;
        END IF;

        --Calling Validations Procedure
        validations_prc (l_errbuf, l_retcode);

        IF l_retcode = 1
        THEN
            p_retcode   := 1;
            p_errbuf    := l_errbuf;
        END IF;

        --Calling Receipt creation and apply procedure
        create_apply_receipt_prc (l_errbuf, l_retcode, l_result);

        IF l_retcode = 1
        THEN
            p_retcode   := 1;
            p_errbuf    := l_errbuf;
        END IF;

        --Calling procedure to print details
        print_app_fail_receipts_prc;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'In Main Exception' || SQLERRM);
    END main;
END;
/
