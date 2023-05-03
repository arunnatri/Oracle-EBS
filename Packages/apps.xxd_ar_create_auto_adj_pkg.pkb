--
-- XXD_AR_CREATE_AUTO_ADJ_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:31 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AR_CREATE_AUTO_ADJ_PKG"
AS
    --  ####################################################################################################
    --  Author(s)       : Showkath Ali (Suneratech Consultant)
    --  System          : Oracle Applications
    --  Subsystem       : EBS(Accounts Receivables)
    --  Change          : CCR0008295
    --  Schema          : APPS
    --  Purpose         : This package is used to create Adjustments to Credit Memos of DXLAB
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

    PROCEDURE insert_eligible_adj_prc (p_errbuf OUT VARCHAR2, p_retcode OUT NUMBER, p_credit_memo_number IN VARCHAR2
                                       , p_return_order_number IN VARCHAR2, p_credit_memo_date_from IN DATE, p_credit_memo_date_to IN DATE)
    AS
        CURSOR eligible_creditmemos_cur IS
              -- Cursor to fetch the eligible records for auto Adjustments
              SELECT ooha.order_number, ooha.header_id, rcta.trx_number,
                     rcta.customer_trx_id, rcta.trx_date, (apsa.amount_due_original) trx_amount,
                     rcta.invoice_currency_code, hca.account_number, rcta.org_id,
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
                     AND hca.attribute1 = 'DXLAB'
                     AND ooha.attribute5 = 'DXLAB'
                     AND apsa.status = 'OP'
                     AND apsa.class = 'CM'
                     AND apsa.amount_due_remaining <> 0
                     AND apsa.amount_due_original - apsa.amount_due_remaining =
                         0
                     AND ooha.flow_status_code IN ('BOOKED', 'CLOSED')
                     AND ooha.order_number =
                         NVL (p_return_order_number, ooha.order_number)
                     AND rcta.trx_number =
                         NVL (p_credit_memo_number, rcta.trx_number)
                     AND rcta.trx_date >=
                         NVL (p_credit_memo_date_from, rcta.trx_date)
                     AND rcta.trx_date <=
                         NVL (p_credit_memo_date_to, rcta.trx_date)
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
                                     AND NVL (ffv.attribute2, 'N') = 'Y') -- Auto Receipt falg
            GROUP BY ooha.order_number, ooha.header_id, rcta.trx_number,
                     rcta.invoice_currency_code, hca.account_number, rcta.customer_trx_id,
                     rcta.trx_date, rcta.org_id, hou.name,
                     rcta.set_of_books_id, apsa.amount_due_original;

        l_trx_count      NUMBER := 0;
        l_cursor_count   NUMBER := 0;
    BEGIN
        gv_debug_message   := 'insert_eligible_cm_prc Procedure';

        FOR i IN eligible_creditmemos_cur
        LOOP
            l_cursor_count   := l_cursor_count + 1;

            -- Before inserting into the table verify the credit memo is exist or not, if exist remove status and error message
            BEGIN
                SELECT COUNT (1)
                  INTO l_trx_count
                  FROM xxdo.xxd_ar_auto_adjustments_t
                 WHERE trx_number = i.trx_number AND status <> 'S';

                IF l_trx_count = 1
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Credit Memo is exist with error status, removed status and error message'
                        || i.trx_number
                        || '-'
                        || gv_debug_message);

                    BEGIN
                        UPDATE xxdo.xxd_ar_auto_adjustments_t
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
                        INSERT INTO xxdo.xxd_ar_auto_adjustments_t (
                                        order_number,
                                        customer_number,
                                        header_id,
                                        trx_number,
                                        customer_trx_id,
                                        trx_date,
                                        trx_amount,
                                        invoice_currency_code,
                                        operating_unit_id,
                                        operating_unit,
                                        creation_date,
                                        created_by,
                                        updated_by,
                                        last_update_date,
                                        request_id,
                                        ledger_id)
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
            fnd_file.put_line (
                fnd_file.LOG,
                'No Credit Memo exist for the given parameters');
            p_retcode   := 1;
            p_errbuf    := 'No Credit Memo exist for the given parameters';
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'In insert_eligible_adj_prc Procedure Exception');
    END insert_eligible_adj_prc;                                       -- main

    /***********************************************************************************************
 ***************************************** Procudure to Validate eligible records****************
 ************************************************************************************************/

    PROCEDURE validations_prc (p_errbuf OUT VARCHAR2, p_retcode OUT NUMBER)
    AS
        -- Cursor to fetch new recors from custom table

        CURSOR new_records_cur IS
            SELECT *
              FROM xxdo.xxd_ar_auto_adjustments_t
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
                    UPDATE xxdo.xxd_ar_auto_adjustments_t
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
            --Payment method count is 0 warning the program and quit
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
                     UPDATE xxdo.xxd_ar_auto_adjustments_t
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
                           'Payment method for the invoice:'
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
                    UPDATE xxdo.xxd_ar_auto_adjustments_t
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
                    UPDATE xxdo.xxd_ar_auto_adjustments_t
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
            fnd_file.put_line (fnd_file.LOG, 'In validations_prc exception');
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

        fnd_file.put_line (fnd_file.LOG,
                           'Receipt Claee Id:' || l_receipt_class_id);
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
  ******************* Function to get Receivable Activity for the receipt_method ****************
  ************************************************************************************************/

    PROCEDURE get_activity_name (p_rct_method           IN     NUMBER,
                                 p_org_id               IN     NUMBER,
                                 p_rece_act_name           OUT VARCHAR2,
                                 p_activity_type           OUT VARCHAR2,
                                 p_receivables_trx_id      OUT NUMBER)
    AS
        l_rece_act_name        VARCHAR2 (100);
        l_activity_type        VARCHAR2 (60);
        l_receivables_trx_id   NUMBER;
    BEGIN
        BEGIN
            SELECT name, TYPE, receivables_trx_id
              INTO l_rece_act_name, l_activity_type, l_receivables_trx_id
              FROM ar_receivables_trx_all
             WHERE     attribute4 = TO_CHAR (p_rct_method)
                   AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                                   AND NVL (end_date_active, SYSDATE)
                   AND status = 'A'
                   AND org_id = p_org_id;

            fnd_file.put_line (
                fnd_file.LOG,
                'Receivable Activity Name:' || l_rece_act_name);
            fnd_file.put_line (
                fnd_file.LOG,
                'Receivable Activity Type:' || l_activity_type);
            fnd_file.put_line (fnd_file.LOG,
                               'Receivable Trx Id:' || l_receivables_trx_id);
        EXCEPTION
            WHEN OTHERS
            THEN
                l_rece_act_name        := NULL;
                l_activity_type        := NULL;
                l_receivables_trx_id   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Failed to fetch Receivable Activity Name and Type');
        END;

        p_rece_act_name        := l_rece_act_name;
        p_activity_type        := l_activity_type;
        p_receivables_trx_id   := l_receivables_trx_id;
    END get_activity_name;

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
 ******************* Procedure to create and apply adjustments to Credit Memos *********************
 ************************************************************************************************/

    PROCEDURE create_auto_adj_prc (p_errbuf OUT VARCHAR2, p_retcode OUT VARCHAR2, p_result OUT VARCHAR2)
    AS
        -- Cursot to pull valid recors from custom table

        CURSOR valid_records_cur IS
            SELECT *
              FROM xxdo.xxd_ar_auto_adjustments_t
             WHERE status = 'V';

        l_receipt_method        NUMBER;
        l_bank_account_id       NUMBER;
        l_bank_branch_id        NUMBER;
        l_receipt_class_id      NUMBER;
        l_error_msg             VARCHAR2 (2000);
        l_pmt_status            VARCHAR2 (1);
        l_rtn_status            VARCHAR2 (1);
        l_debug                 NUMBER := 0;
        l_rc                    NUMBER := 0;
        v_boolean1              BOOLEAN;
        l_sqlerrm               VARCHAR2 (4000);
        l_adj_activity          VARCHAR2 (100);
        l_activity_type         VARCHAR2 (60);
        l_adj_amount            NUMBER;
        l_adj_id                NUMBER;
        l_adj_number            NUMBER;
        v_init_msg_list         VARCHAR2 (1000);
        v_commit_flag           VARCHAR2 (5) := 'F';
        v_validation_level      NUMBER (4) := fnd_api.g_valid_level_full;
        v_msg_count             NUMBER (4);
        v_msg_data              VARCHAR2 (2000);
        v_return_status         VARCHAR2 (5);
        v_adj_rec               ar_adjustments%ROWTYPE;
        v_chk_approval_limits   VARCHAR2 (5) := 'F';
        v_check_amount          VARCHAR2 (5) := 'F';
        v_move_deferred_tax     VARCHAR2 (1) := 'Y';
        v_new_adjust_number     ar_adjustments.adjustment_number%TYPE;
        v_new_adjust_id         ar_adjustments.adjustment_id%TYPE;
        v_called_from           VARCHAR2 (25) := 'ADJ-API';
        v_old_adjust_id         ar_adjustments.adjustment_id%TYPE;
        l_customer_trx_id       NUMBER;
        l_payment_schedule_id   NUMBER;
        l_receivables_trx_id    NUMBER;
        l_period_status         VARCHAR2 (100);
        l_receipt_date          DATE;
    BEGIN
        gv_debug_message   := 'create_auto_adj_prc Procedure';

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
                       'Unable to find the Receipt Method for Payment Type:'
                    || i.payment_method);

                -- Update the error message i custom table
                BEGIN
                    UPDATE xxdo.xxd_ar_auto_adjustments_t
                       SET status = 'E', error_message = 'Unable to find the Receipt Method for Payment Type: ' || i.payment_method || '-' || gv_debug_message, updated_by = gn_created_by,
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
                       'Unable to find the Receipt Method for Payment Type: '
                    || i.payment_method;
            ELSE
                -- Update the receipt method in custom table.
                BEGIN
                    UPDATE xxdo.xxd_ar_auto_adjustments_t
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
                        UPDATE xxdo.xxd_ar_auto_adjustments_t
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

                l_receipt_class_id   :=
                    xxd_ar_create_auto_adj_pkg.get_receipt_class (
                        l_receipt_method);

                IF l_receipt_class_id IS NULL
                THEN
                    -- Update the custom table with error message.
                    BEGIN
                        UPDATE xxdo.xxd_ar_auto_adjustments_t
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

                -- Call the Procedure to get the receivable activity for Receipt_method

                get_activity_name (l_receipt_method, i.operating_unit_id, l_adj_activity
                                   , l_activity_type, l_receivables_trx_id);
                fnd_file.put_line (fnd_file.LOG,
                                   'l_adj_activity:' || l_adj_activity);

                IF    l_adj_activity IS NULL
                   OR l_activity_type IS NULL
                   OR l_receivables_trx_id IS NULL
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Adjustment Activity Name Setup for Payment Method is missing:'
                        || l_receipt_method
                        || '-'
                        || gv_debug_message);

                    BEGIN
                        UPDATE xxdo.xxd_ar_auto_adjustments_t
                           SET status = 'E', error_message = 'Adjustment Activity Name Setup for Payment Method is missing:' || l_receipt_method || '-' || gv_debug_message, updated_by = gn_created_by,
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
                           'Adjustment Activity Name Setup for Payment Method is missing'
                        || l_receipt_method
                        || '-'
                        || gv_debug_message;
                END IF;

                -- call the Function to get period status of invoice date

                l_period_status   :=
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

                BEGIN
                    SELECT ABS (i.trx_amount) INTO l_adj_amount FROM DUAL;

                    fnd_file.put_line (fnd_file.LOG,
                                       'l_adj_amount:' || l_adj_amount);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_adj_amount   := 0;
                END;

                BEGIN
                    SELECT payment_schedule_id
                      INTO l_payment_schedule_id
                      FROM ar_payment_schedules_all b
                     WHERE b.customer_trx_id = i.customer_trx_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_payment_schedule_id   := -1;
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Transaction Number does not exist' || i.trx_number);
                END;

                BEGIN
                    -- Call the Adjustment creation API
                    v_adj_rec.customer_trx_id       := i.customer_trx_id;
                    v_adj_rec.TYPE                  := 'INVOICE';
                    v_adj_rec.payment_schedule_id   := l_payment_schedule_id;
                    v_adj_rec.receivables_trx_id    := l_receivables_trx_id;
                    v_adj_rec.amount                := l_adj_amount;
                    v_adj_rec.apply_date            := i.trx_date;
                    v_adj_rec.gl_date               := i.trx_date;
                    v_adj_rec.created_from          := 'ADJ-API';
                    -- API
                    ar_adjust_pub.create_adjustment ('AR_ADJUST_PUB', 1.0, v_init_msg_list, v_commit_flag, v_validation_level, v_msg_count, v_msg_data, v_return_status, v_adj_rec, v_chk_approval_limits, v_check_amount, v_move_deferred_tax, v_new_adjust_number, v_new_adjust_id, v_called_from
                                                     , v_old_adjust_id);

                    --API

                    IF v_msg_data IS NOT NULL
                    THEN
                        FOR i IN 1 .. v_msg_count
                        LOOP
                            l_error_msg   := l_error_msg || '-' || v_msg_data;
                        END LOOP;

                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Unable to create Adjustment for Credit Memo #: '
                            || i.trx_number
                            || '-'
                            || l_error_msg);

                        BEGIN
                            UPDATE xxdo.xxd_ar_auto_adjustments_t
                               SET status = 'E', error_message = 'Unable to create Adjustment for Credit Memo #: ' || i.trx_number || '-' || l_error_msg, updated_by = gn_created_by,
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
                               'Unable to create Adjustment for Credit Memo #: '
                            || i.trx_number
                            || '-'
                            || l_error_msg;
                    ELSE
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Successfully created Adjustment#: '
                            || v_new_adjust_number
                            || ' for Credit Memo #: '
                            || i.trx_number);

                        BEGIN
                            UPDATE xxdo.xxd_ar_auto_adjustments_t
                               SET status = 'S', adjustment_number = v_new_adjust_number, adjustment_id = v_new_adjust_id,
                                   adjustment_amount = i.trx_amount, updated_by = gn_created_by, last_update_date = SYSDATE
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
                    END IF;                              -- adjustment success
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        FOR i IN 1 .. v_msg_count
                        LOOP
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Error message:' || v_msg_data);
                        END LOOP;
                END;
            --Adjustment creation API END

            END IF;                                -- l_receipt_method IS NULL
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'In create_auto_adj_prc exception');
    END create_auto_adj_prc;             -- procedure create_apply_receipt_prc

    /***********************************************************************************************
  ****************Procedure to print Applied and failed records**********************************
  ************************************************************************************************/

    PROCEDURE print_suc_fail_adjs_prc
    AS
        CURSOR success_records_cur IS
            SELECT *
              FROM xxdo.xxd_ar_auto_adjustments_t
             WHERE status = 'S' AND request_id = gn_request_id;

        CURSOR failed_records_cur IS
            SELECT *
              FROM xxdo.xxd_ar_auto_adjustments_t
             WHERE status = 'E' AND request_id = gn_request_id;

        l_status   VARCHAR2 (10);
    BEGIN
        fnd_file.put_line (fnd_file.output,
                           'Deckers Create Automatic Adjustments Program');
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
            || RPAD ('Adjustment Number', 50)
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
                || RPAD (NVL (i.adjustment_number, 'NULL'), 50, ' ')
                || CHR (9)
                || RPAD (l_status, 20, ' ')
                || CHR (9)
                || RPAD ('NULL', 100, ''));
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
                || RPAD (NVL (i.adjustment_number, 'NULL'), 50, ' ')
                || CHR (9)
                || RPAD (l_status, 20, ' ')
                || CHR (9)
                || RPAD (i.error_message, 100, ' '));
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Printing records Failed');
    END print_suc_fail_adjs_prc;

    /***********************************************************************************************
 *****************************************Main Procedure*****************************************
 ************************************************************************************************/

    PROCEDURE main (p_errbuf OUT VARCHAR2, p_retcode OUT NUMBER, p_return_order_number IN VARCHAR2
                    , p_credit_memo_number IN VARCHAR2, p_credit_memo_date_from IN DATE, p_credit_memo_date_to IN DATE)
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
            'Deckers Create Automatic adjustments program starts here...');
        fnd_file.put_line (
            fnd_file.LOG,
            '********************************************************');
        fnd_file.put_line (
            fnd_file.LOG,
               'Input Parameters Are: p_return_order_number:'
            || p_return_order_number
            || ' and p_credit_memo_number:'
            || p_credit_memo_number
            || ' and p_credit_memo_date_from:'
            || p_credit_memo_date_from
            || ' and p_credit_memo_date_to:'
            || p_credit_memo_date_to);

        gv_debug_message   := 'Main Procedure';
        --Calling insert_eligible_cm_prc procedure
        insert_eligible_adj_prc (l_errbuf,
                                 l_retcode,
                                 p_credit_memo_number,
                                 p_return_order_number,
                                 p_credit_memo_date_from,
                                 p_credit_memo_date_to);

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

        --Calling create auto adjustments procedure
        create_auto_adj_prc (l_errbuf, l_retcode, l_result);

        IF l_retcode = 1
        THEN
            p_retcode   := 1;
            p_errbuf    := l_errbuf;
        END IF;

        --Calling procedure to print details
        print_suc_fail_adjs_prc;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'In Main Procedure Exception' || SQLERRM);
    END main;
END;
/
