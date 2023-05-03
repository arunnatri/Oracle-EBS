--
-- XXDOAR020_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:26 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxdoar020_pkg
AS
    /******************************************************************************
       NAME: XXDOAR020_PKG
      Program NAME:Create Factored Remittance Batch - Deckers

       REVISIONS:
       Ver             Date        Author                        Description
       ---------    ----------  ---------------           ------------------------------------               -- MODIFICATION HISTORY
    --                Date         Person                          Comments
    --                11-17-2011  Shibu Alex                   Initial Version
    --                05-22-2012  Shibu Alex                  Added TERMS_SEQUENCE_NUMBER
    --   1.1          11-25-2014  BT Technology Team       The Payment terms are either Credit card or Pre pay or COD, then those invoices are not eligible for creating '
    --                                                     Factored Receipts''The Factored Profile class will be at the customer account level only instead of the customer
    --                                                     account and bill-to-site,so modified curosor c_trx .
    ******************************************************************************/
    -- This procedure will create the receipt batch
    -- Then will create Receipts with customer and bill_to site combination for factured customers
    -- Then will assign those receipts to the batch created.
    PROCEDURE create_receipt_batch (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pd_from_date IN VARCHAR2, pd_to_date IN VARCHAR2, pn_batch_source_id IN NUMBER, pn_org_d IN NUMBER
                                    , pd_receipt_date IN VARCHAR2, pd_gl_date IN VARCHAR2, pn_brand IN VARCHAR2)
    IS
        CURSOR c_trx (pd_from_dt DATE, pd_to_dt DATE, pn_org_d NUMBER,
                      pn_brand VARCHAR2)
        IS
            SELECT ps.org_id, ps.customer_id, ps.customer_site_use_id,
                   ps.customer_trx_id, ps.trx_number, ps.trx_date,
                   ps.amount_due_remaining, ps.terms_sequence_number
              FROM apps.ar_payment_schedules_all ps, apps.ra_customer_trx_all trx, apps.hz_cust_accounts hzc, -- Added by BT Technology Team on 24-NOV-2014 (Version 1.1)
                   apps.ra_terms rt -- Added by BT Technology Team on 24-NOV-2014 (Version 1.1)
             WHERE     ps.customer_trx_id = trx.customer_trx_id
                   AND trx.BILL_TO_CUSTOMER_ID = hzc.PARTY_ID -- Added by BT Technology Team on 24-NOV-2014 (Version 1.1)
                   AND ps.status = 'OP'
                   AND ps.trx_date >= pd_from_dt
                   AND ps.trx_date <= pd_to_dt
                   AND ps.CLASS = 'INV' -- Excluding all CM/DM and chargebacks
                   AND trx.interface_header_context = 'ORDER ENTRY'
                   -- AND trx.attribute5 = pn_brand                                -- Commented by BT Technology Team on 24-NOV-2014 (Version 1.1)
                   AND hzc.ATTRIBUTE1 = pn_brand -- Modified by BT Technology Team on 24-NOV-2014  (Version 1.1)
                   --and ps.AMOUNT_DUE_REMAINING > 100000 -- For testing purpose need to remove.
                   -- and ps.CUSTOMER_ID   =      3403     -- For testing purpose need to remove.
                   -- and ps.TRX_DATE      =  '16-JAN-2012' -- For testing purpose need to remove.
                   AND ps.org_id = pn_org_d
                   AND trx.term_id = rt.term_id -- Added by BT Technology Team on 02-DEC-2014  (Version 1.1)
                   AND rt.name NOT IN ('CREDIT CARD', 'PREPAY', 'COD') -- Added by BT Technology Team on 02-DEC-2014  (Version 1.1)
                   AND 'Y' =
                       xxdoom_cit_int_pkg.is_fact_cust_f (
                           interface_header_attribute1,
                           ps.customer_id,
                           ps.customer_site_use_id);

        CURSOR c_trx_cust IS
              SELECT org_id, customer_id, customer_site_use_id,
                     SUM (amount_due_remaining) amount_due_remaining
                FROM xxdo.xxdoar020_temp_gt
            GROUP BY org_id, customer_id, customer_site_use_id;

        CURSOR c_trx_id (c_customer_id            NUMBER,
                         c_customer_site_use_id   NUMBER,
                         c_org_id                 NUMBER)
        IS
            SELECT customer_trx_id, amount_due_remaining, terms_sequence_number
              FROM xxdo.xxdoar020_temp_gt
             WHERE     customer_id = c_customer_id
                   AND customer_site_use_id = c_customer_site_use_id
                   AND org_id = c_org_id;

        TYPE c_trx_tabtype IS TABLE OF c_trx%ROWTYPE
            INDEX BY PLS_INTEGER;

        trx_tbl                        c_trx_tabtype;
        ld_open_period_dt              DATE;
        ld_from_dt                     DATE;
        ld_to_dt                       DATE;
        ld_receipt_dt                  DATE;
        ld_gl_dt                       DATE;
        ln_receipt_cnt                 NUMBER;
        ln_amt_sum                     NUMBER;
        lv_type                        VARCHAR2 (20);
        lv_last_batch_num              NUMBER;
        ln_default_receipt_class_id    NUMBER;
        ln_default_receipt_method_id   NUMBER;
        ln_remit_bank_acct_use_id      NUMBER;
        ln_bank_branch_id              NUMBER;
        lv_currency_code               VARCHAR2 (20);
        ln_batch_id                    NUMBER;
        ln_cash_receipt_id             NUMBER;
        lv_return_status               VARCHAR2 (2000);
        ln_msg_count                   NUMBER;
        lv_msg_data                    VARCHAR2 (4022);
        lv_receipt_number              VARCHAR2 (30);
        ln_count                       NUMBER;
        ln_rcnt                        NUMBER := 0;
        ln_insert_cnt                  NUMBER := 0;
    BEGIN
        ld_from_dt      := apps.fnd_date.canonical_to_date (pd_from_date);
        ld_to_dt        := apps.fnd_date.canonical_to_date (pd_to_date);
        ld_receipt_dt   := apps.fnd_date.canonical_to_date (pd_receipt_date);
        ld_gl_dt        := apps.fnd_date.canonical_to_date (pd_gl_date);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'From Date: ' || ld_from_dt);
        apps.fnd_file.put_line (apps.fnd_file.LOG, 'To Date: ' || ld_to_dt);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Receipt Date: ' || ld_receipt_dt);
        fnd_file.put_line (fnd_file.LOG, 'Gl Date: ' || ld_gl_dt);
        fnd_file.put_line (fnd_file.output,
                           '**** From Date:      ' || ld_from_dt);
        fnd_file.put_line (fnd_file.output,
                           '**** To Date:        ' || ld_to_dt);
        fnd_file.put_line (fnd_file.output,
                           '**** Receipt Date:   ' || ld_receipt_dt);
        fnd_file.put_line (
            fnd_file.output,
            '**** Gl Date:        ' || ld_gl_dt || fnd_profile.VALUE ('GL_SET_OF_BKS_ID'));

        -- Open period checking
        BEGIN
            SELECT MAX (end_date)
              INTO ld_open_period_dt
              FROM gl_period_statuses
             WHERE     application_id = 222
                   AND set_of_books_id =
                       fnd_profile.VALUE ('GL_SET_OF_BKS_ID')
                   --     AND ld_gl_dt BETWEEN start_date AND end_date  ws                                                                     -- Commented by BT Technology Team on 02-DEC-2014 (Version 1.1)
                   AND TO_DATE (ld_gl_dt, 'DD-MON-YYYY') BETWEEN TO_DATE (
                                                                     start_date,
                                                                     'DD-MON-YYYY')
                                                             AND TO_DATE (
                                                                     end_date,
                                                                     'DD-MON-YYYY') -- Modified by BT Technology Team on 02-DEC-2014 (Version 1.1)
                   AND closing_status = 'O';

            IF ld_open_period_dt IS NULL
            THEN
                fnd_file.put_line (
                    fnd_file.output,
                       '**** Parameter Gl Date not belong to an Open Period, Please pass the correct GL Date.'
                    || ld_gl_dt);
                RETURN;
            END IF;
        END;                                           -- Open period checking

        -- Delete temp tables records.
        --delete XXDO.XXDOAR020_TEMP_T;
        --commit;
        -- apps.fnd_file.put_line (apps.fnd_file.LOG, ' Deleted XXDOAR020_TEMP_T');

        OPEN c_trx (ld_from_dt, ld_to_dt, pn_org_d,
                    pn_brand);

        LOOP
            FETCH c_trx BULK COLLECT INTO trx_tbl LIMIT 1000;

            IF trx_tbl.COUNT > 0
            THEN
                FOR itrx IN trx_tbl.FIRST .. trx_tbl.LAST
                LOOP
                    ln_insert_cnt   := ln_insert_cnt + 1;

                    INSERT INTO xxdo.xxdoar020_temp_gt (
                                    org_id,
                                    customer_id,
                                    customer_site_use_id,
                                    customer_trx_id,
                                    trx_number,
                                    trx_date,
                                    amount_due_remaining,
                                    terms_sequence_number)
                             VALUES (trx_tbl (itrx).org_id,
                                     trx_tbl (itrx).customer_id,
                                     trx_tbl (itrx).customer_site_use_id,
                                     trx_tbl (itrx).customer_trx_id,
                                     trx_tbl (itrx).trx_number,
                                     trx_tbl (itrx).trx_date,
                                     trx_tbl (itrx).amount_due_remaining,
                                     trx_tbl (itrx).terms_sequence_number);

                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'INSERTED INTO XXDOAR020_TEMP_T'
                        || trx_tbl.COUNT
                        || '  '
                        || trx_tbl (itrx).amount_due_remaining);
                END LOOP;                                               --itrx

                COMMIT;
            END IF;

            EXIT WHEN c_trx%NOTFOUND;
        END LOOP;

        --C_trx
        CLOSE c_trx;

        --Open
        IF ln_insert_cnt = 0
        THEN
            fnd_file.put_line (
                fnd_file.output,
                '**** No Open Transactions found for the given parameters');
        ELSE
            fnd_file.put_line (
                fnd_file.output,
                '**** Total Open Transactions found :- ' || ln_insert_cnt);
        END IF;



        BEGIN                  -- Count and amount for Receipt Batch Creation.
            SELECT COUNT (*), SUM (amount_due_remaining)
              INTO ln_receipt_cnt, ln_amt_sum
              FROM (  SELECT SUM (amount_due_remaining) amount_due_remaining
                        FROM xxdo.xxdoar020_temp_gt
                    GROUP BY org_id, customer_id, customer_site_use_id);
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_receipt_cnt   := 0;
                ln_amt_sum       := 0;
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                    ' Count and amount for Receipt Batch Creation');
        END;                    -- Count and amount for Receipt Batch Creation

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            'Receipt Cnt ' || ln_receipt_cnt || ' Amount  ' || ln_amt_sum);

        BEGIN
            --Get the Batch Sourse Detail using the parameter pn_batch_source_id
            SELECT bs.TYPE, bs.last_batch_num + 1, bs.default_receipt_class_id,
                   bs.default_receipt_method_id, bs.remit_bank_acct_use_id, cba.bank_branch_id,
                   cba.currency_code
              INTO lv_type, lv_last_batch_num, ln_default_receipt_class_id, ln_default_receipt_method_id,
                          ln_remit_bank_acct_use_id, ln_bank_branch_id, lv_currency_code
              FROM ar_batch_sources_all bs, ce_bank_acct_uses_ou_v ba, ce_bank_accounts cba
             -- ,ce_bank_branches_v     bb
             WHERE     bs.remit_bank_acct_use_id = ba.bank_acct_use_id(+)
                   AND ba.bank_account_id = cba.bank_account_id(+)
                   --and    cba.bank_branch_id          = bb.branch_party_id(+)
                   AND bs.batch_source_id = pn_batch_source_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                    'Get the Batch Sourse Detail using the parameter pn_batch_source_id');
        END;

        --Get the Batch Sourse Detail using the parameter pn_batch_source_id

        SAVEPOINT my_savepoint;

        -- Create Batch Receipt
        IF ln_amt_sum > 0
        THEN
            INSERT INTO ar_batches_all (batch_id,
                                        NAME,
                                        batch_date,
                                        gl_date,
                                        status,
                                        deposit_date,
                                        TYPE,
                                        batch_source_id,
                                        control_count,
                                        control_amount,
                                        batch_applied_status,
                                        currency_code,
                                        comments,
                                        receipt_method_id,
                                        receipt_class_id,
                                        remittance_bank_branch_id,
                                        set_of_books_id,
                                        org_id,
                                        remit_bank_acct_use_id,
                                        last_updated_by,
                                        last_update_date,
                                        last_update_login,
                                        created_by,
                                        creation_date)
                 VALUES (ar_batches_s.NEXTVAL, lv_last_batch_num, ld_receipt_dt, ld_gl_dt, 'NB', ld_receipt_dt, lv_type, pn_batch_source_id, ln_receipt_cnt, ln_amt_sum, 'PROCESSED', NVL (lv_currency_code, 'USD'), 'BATCH' || '-' || TO_CHAR (SYSDATE, 'DD-MON-RRRR'), ln_default_receipt_method_id, ln_default_receipt_class_id, ln_bank_branch_id, fnd_profile.VALUE ('GL_SET_OF_BKS_ID'), pn_org_d, ln_remit_bank_acct_use_id, apps.fnd_profile.VALUE ('USER_ID'), SYSDATE
                         , -1, apps.fnd_profile.VALUE ('USER_ID'), SYSDATE);

            COMMIT;

            SELECT ar_batches_s.CURRVAL INTO ln_batch_id FROM DUAL;
        ELSE
            RETURN;
        END IF;

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               'Batch ID Created :'
            || ln_batch_id
            || '-'
            || 'Batch Number: '
            || lv_last_batch_num);
        fnd_file.put_line (fnd_file.output,
                           '**** Batch Number : ' || lv_last_batch_num);

        --Calling the Receipt API for each cust and bill_to
        FOR i IN c_trx_cust
        LOOP
            IF i.amount_due_remaining > 0
            THEN
                ln_rcnt   := ln_rcnt + 1;
                lv_receipt_number   :=
                    lv_last_batch_num || '-' || LPAD (ln_rcnt, 4, '0');
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                    '**** Begin Create Receipt ' || lv_receipt_number);
                fnd_file.put_line (
                    fnd_file.output,
                    '**** Receipt Number: ' || lv_receipt_number);
                apps.ar_receipt_api_pub.create_cash (
                    p_api_version            => 1.0,
                    p_init_msg_list          => fnd_api.g_true,
                    p_commit                 => fnd_api.g_false,
                    p_validation_level       => fnd_api.g_valid_level_full,
                    x_return_status          => lv_return_status,
                    x_msg_count              => ln_msg_count,
                    x_msg_data               => lv_msg_data,
                    p_currency_code          => NVL (lv_currency_code, 'USD'),
                    p_amount                 => i.amount_due_remaining,
                    p_receipt_number         => lv_receipt_number,
                    p_receipt_date           => ld_receipt_dt,
                    p_gl_date                => ld_gl_dt,
                    p_customer_id            => i.customer_id,
                    p_customer_site_use_id   => i.customer_site_use_id,
                    p_receipt_method_id      => ln_default_receipt_method_id,
                    p_cr_id                  => ln_cash_receipt_id);
                fnd_file.put_line (fnd_file.LOG,
                                   'Status: ' || lv_return_status);
                fnd_file.put_line (fnd_file.LOG,
                                   'Cash Receipt Id: ' || ln_cash_receipt_id);
                fnd_file.put_line (fnd_file.LOG,
                                   'Receipt Number: ' || lv_receipt_number);
                fnd_file.put_line (fnd_file.LOG,
                                   'Message Count: ' || ln_msg_count);

                IF NVL (lv_return_status, fnd_api.g_ret_sts_error) !=
                   fnd_api.g_ret_sts_success
                THEN
                    ROLLBACK TO my_savepoint;

                    IF NOT fnd_concurrent.set_completion_status (
                               'ERROR',
                               'Failed To Create Cash')
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            '*** FAILED TO SET COMPLETION STATUS TO ERROR');
                    END IF;

                    -- Write any messages to the log
                    IF ln_msg_count = 1
                    THEN
                        fnd_file.put_line (fnd_file.LOG,
                                           '*** Message: ' || lv_msg_data);
                    ELSIF ln_msg_count > 1
                    THEN
                        LOOP
                            ln_count   := ln_count + 1;
                            lv_msg_data   :=
                                fnd_msg_pub.get (fnd_msg_pub.g_next,
                                                 fnd_api.g_false);

                            IF lv_msg_data IS NULL
                            THEN
                                EXIT;
                            END IF;

                            fnd_file.put_line (
                                fnd_file.LOG,
                                   '*** Message: '
                                || ln_count
                                || '.'
                                || lv_msg_data);
                        END LOOP;
                    END IF;

                    RETURN;
                END IF;

                -- If receipt create was successful then perform the mass apply
                fnd_file.put_line (
                    fnd_file.LOG,
                       '**** Begin Mass Apply '
                    || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

                --fnd_file.put_line(fnd_file.log, '**** CUSTOMER_ID ' || i.CUSTOMER_ID);
                -- fnd_file.put_line(fnd_file.log, '**** CUSTOMER_SITE_USE_ID ' || i.CUSTOMER_SITE_USE_ID);
                -- fnd_file.put_line(fnd_file.log, '**** ORG_ID ' || i.ORG_ID);
                FOR j
                    IN c_trx_id (i.customer_id,
                                 i.customer_site_use_id,
                                 i.org_id)
                LOOP
                    ar_receipt_api_pub.APPLY (
                        p_api_version            => 1.0,
                        p_init_msg_list          => fnd_api.g_true,
                        p_commit                 => fnd_api.g_false,
                        p_validation_level       => fnd_api.g_valid_level_full,
                        p_cash_receipt_id        => ln_cash_receipt_id,
                        p_customer_trx_id        => j.customer_trx_id,
                        p_installment            => j.terms_sequence_number,
                        p_amount_applied         => j.amount_due_remaining,
                        p_discount               => 0,
                        p_apply_date             => ld_receipt_dt,
                        p_apply_gl_date          => ld_gl_dt,
                        p_show_closed_invoices   => 'Y',
                        x_return_status          => lv_return_status,
                        x_msg_count              => ln_msg_count,
                        x_msg_data               => lv_msg_data);

                    IF NVL (lv_return_status, fnd_api.g_ret_sts_error) !=
                       fnd_api.g_ret_sts_success
                    THEN
                        --  ROLLBACK TO my_savepoint;
                        IF NOT fnd_concurrent.set_completion_status (
                                   'ERROR',
                                   'Failed To Apply Cash To Trx ID ' || j.customer_trx_id)
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                '*** FAILED TO SET COMPLETION STATUS TO ERROR');
                        END IF;

                        fnd_file.put_line (fnd_file.LOG,
                                           'Trx ID ' || j.customer_trx_id);
                        fnd_file.put_line (fnd_file.LOG,
                                           'Status: ' || lv_return_status);
                        fnd_file.put_line (fnd_file.LOG,
                                           'Message Count: ' || ln_msg_count);

                        -- Write any messages to the log
                        IF ln_msg_count = 1
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                '*** Message: ' || lv_msg_data);
                        ELSIF ln_msg_count > 1
                        THEN
                            LOOP
                                ln_count   := ln_count + 1;
                                lv_msg_data   :=
                                    fnd_msg_pub.get (fnd_msg_pub.g_next,
                                                     fnd_api.g_false);

                                IF lv_msg_data IS NULL
                                THEN
                                    EXIT;
                                END IF;

                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       '*** Message: '
                                    || ln_count
                                    || '.'
                                    || lv_msg_data);
                            END LOOP;
                        END IF;

                        RETURN;
                    END IF;
                END LOOP;                                                  --j

                fnd_file.put_line (
                    fnd_file.LOG,
                       'RECEIPT ID: '
                    || ln_cash_receipt_id
                    || ' in AR_CASH_RECEIPT_HISTORY_ALL updated with ID :'
                    || ln_batch_id);

                -- Updates the Receipts history table with the batch info.
                UPDATE ar_cash_receipt_history_all
                   SET batch_id = ln_batch_id, last_update_date = SYSDATE, last_updated_by = apps.fnd_profile.VALUE ('USER_ID')
                 WHERE     cash_receipt_id = ln_cash_receipt_id
                       AND org_id = i.org_id;

                COMMIT;
            END IF;
        END LOOP;



        -- Batch Source last Num update in The Source table.
        UPDATE ar_batch_sources_all
           SET last_batch_num   = lv_last_batch_num
         WHERE batch_source_id = pn_batch_source_id;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            IF NOT fnd_concurrent.set_completion_status (
                       'ERROR',
                       'A Global Exception Was Encountered')
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    '*** FAILED TO SET COMPLETION STATUS TO ERROR');
            END IF;

            fnd_file.put_line (fnd_file.LOG, '*** EXCEPTION: ' || SQLERRM);
            ROLLBACK TO my_savepoint;
    END create_receipt_batch;
END xxdoar020_pkg;
/
