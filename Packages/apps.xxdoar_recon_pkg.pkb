--
-- XXDOAR_RECON_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:14 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxdoar_recon_pkg
AS
    --------------------------------------------------------------------------------
    -- Created By              : Venkatesh Ragamgari ( Sunera Technologies )
    -- Creation Date           : 06-FEB-2013
    -- File Name               : XXDOAR_RECON_PKG.pkb
    -- Work Order Num          : AR Reconciliation Correction Report - Deckers
    -- Incident Num            : INC0129722
    -- Description             :
    -- Latest Version          : 1.0
    --
    -- Revision History:
    -- =============================================================================
    -- Date               Version#    Name                    Remarks
    -- =============================================================================
    -- 06-FEB-2013        1.0         Venkatesh Ragamgari
    -- 02-JAN-2014   BT Technology Team  Retrofit for BT project

    -------------------------------------------------------------------------------
    g_mail_message   VARCHAR2 (32767);

    PROCEDURE DEBUG (s VARCHAR2)
    IS
        pg_fp      UTL_FILE.file_type;
        l_count1   NUMBER;
        l_count2   NUMBER;
    BEGIN
        apps.fnd_file.put_line (apps.fnd_file.output, s);
        l_count1   := NVL (LENGTH (g_mail_message), 0);
        l_count2   := NVL (LENGTH (s), 0);

        IF l_count1 + l_count2 < 32600
        THEN
            g_mail_message   := g_mail_message || CHR (10) || s;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (apps.fnd_file.LOG, 'DEBUG:' || SQLERRM);
    --  UTL_FILE.fflush (pg_fp);
    END DEBUG;

    FUNCTION print_spaces (n IN NUMBER)
        RETURN VARCHAR2
    IS
        l_return_string   VARCHAR2 (100);
    BEGIN
        SELECT SUBSTR ('                                                   ', 1, n)
          INTO l_return_string
          FROM DUAL;

        RETURN (l_return_string);
    END print_spaces;

    PROCEDURE get_trx_details (pn_cust_trx IN NUMBER, xv_org_name OUT VARCHAR2, xv_trx_num OUT VARCHAR2
                               , xv_trx_date OUT VARCHAR2)
    IS
    BEGIN
        SELECT rcta.trx_number, TO_CHAR (rcta.trx_date, 'DD-MON-YYYY'), hou.NAME
          INTO xv_trx_num, xv_trx_date, xv_org_name
          FROM apps.ra_customer_trx_all rcta, apps.hr_operating_units hou
         WHERE     rcta.org_id = hou.organization_id
               AND rcta.customer_trx_id = pn_cust_trx;
    EXCEPTION
        WHEN OTHERS
        THEN
            xv_trx_num    := NULL;
            xv_trx_date   := NULL;
            xv_org_name   := NULL;
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'get_trx_details:' || SQLERRM);
    END get_trx_details;

    PROCEDURE get_cash_details (pn_cash_id    IN     NUMBER,
                                xn_cash_num      OUT VARCHAR2)
    IS
    BEGIN
        SELECT receipt_number
          INTO xn_cash_num
          FROM apps.ar_cash_receipts_all
         WHERE cash_receipt_id = pn_cash_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            xn_cash_num   := NULL;
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'get_cash_details:' || SQLERRM);
    END get_cash_details;

    PROCEDURE recon_control (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pn_org_id NUMBER
                             , pd_gl_date_low VARCHAR2, pd_gl_date_high VARCHAR2, pv_to_email VARCHAR2)
    IS
        /* Identify all the transactions with gl_date <= the input gl date and which have
              applications gl_date less than the invoice gl_date
            Case 1 */
        CURSOR ps_apply_cur (l_start_gl_date DATE, l_end_gl_date DATE)
        IS
            SELECT ps.customer_trx_id, ps.payment_schedule_id
              FROM ar_payment_schedules ps
             WHERE     ps.gl_date_closed >= l_start_gl_date
                   AND ps.CLASS <> 'PMT'
                   AND SIGN (ps.payment_schedule_id) <> -1
                   AND EXISTS
                           (SELECT '1'
                              FROM ar_receivable_applications ra
                             WHERE     ra.payment_schedule_id =
                                       ps.payment_schedule_id
                                   AND ra.gl_date < ps.gl_date
                            UNION
                            SELECT '1'
                              FROM ar_receivable_applications ra
                             WHERE     ra.applied_payment_schedule_id =
                                       ps.payment_schedule_id
                                   AND ra.gl_date < ps.gl_date
                            UNION
                            SELECT '1'
                              FROM ar_adjustments adj
                             WHERE     adj.payment_schedule_id =
                                       ps.payment_schedule_id
                                   AND adj.gl_date < ps.gl_date);

        /* Identify all the invoices whose gl_date_closed is wrongly populated
           Case 2 */
        CURSOR ps_gl_date_cur (l_start_gl_date DATE, l_end_gl_date DATE)
        IS
            SELECT ps.customer_trx_id, ps.payment_schedule_id
              FROM ar_payment_schedules ps
             WHERE     gl_date_closed >= l_start_gl_date
                   AND TRUNC (ps.gl_date_closed) <>
                       TO_DATE ('31-DEC-4712', 'dd-MON-YYYY')
                   AND ps.CLASS <> 'PMT'
                   AND SIGN (ps.payment_schedule_id) <> -1
                   AND EXISTS
                           (SELECT '1'
                              FROM ar_receivable_applications ra
                             WHERE     ra.payment_schedule_id =
                                       ps.payment_schedule_id
                                   AND ra.gl_date > ps.gl_date_closed
                            UNION
                            SELECT '1'
                              FROM ar_receivable_applications ra
                             WHERE     ra.applied_payment_schedule_id =
                                       ps.payment_schedule_id
                                   AND ra.gl_date > ps.gl_date_closed
                            UNION
                            SELECT '1'
                              FROM ar_adjustments adj
                             WHERE     adj.payment_schedule_id =
                                       ps.payment_schedule_id
                                   AND adj.gl_date > ps.gl_date_closed);

        /* Identify all the adjustments in functional currency whose amount does
           not match the accounted amount
           Case 3 */
        CURSOR adj_cur (l_start_gl_date DATE, l_end_gl_date DATE)
        IS
            SELECT adj.adjustment_id, ps.customer_trx_id, adj.amount,
                   adj.acctd_amount
              FROM ar_adjustments adj, ar_payment_schedules ps, gl_sets_of_books books,
                   ra_customer_trx trx
             WHERE     ps.gl_date_closed >= l_start_gl_date
                   AND adj.customer_trx_id = ps.customer_trx_id
                   AND ps.customer_trx_id = trx.customer_trx_id
                   AND trx.set_of_books_id = books.set_of_books_id
                   AND books.currency_code = ps.invoice_currency_code
                   AND adj.amount <> adj.acctd_amount;

        /* Identify all the adjustments where sign(amount) <> sign(acctd_amount)
           Case 4 */
        CURSOR adj_sign_cur (l_start_gl_date DATE, l_end_gl_date DATE)
        IS
            SELECT adj.adjustment_id, ps.customer_trx_id, adj.amount,
                   adj.acctd_amount
              FROM ar_adjustments adj, ar_payment_schedules ps
             WHERE     ps.gl_date_closed >= l_start_gl_date
                   AND adj.customer_trx_id = ps.customer_trx_id
                   AND SIGN (adj.amount) <> SIGN (adj.acctd_amount)
                   AND adj.acctd_amount <> 0;

        /* Indetify all the transactions created or applied or adjusted
           in the given gl_date range
           Case 5 */
        CURSOR inv_cur (l_gl_date_low DATE, l_gl_date_high DATE)
        IS
            SELECT pay.customer_trx_id
              FROM ar_payment_schedules pay
             WHERE     pay.gl_date BETWEEN l_gl_date_low AND l_gl_date_high
                   AND pay.CLASS NOT IN ('BR', 'PMT')
                   AND pay.payment_schedule_id > 0
            UNION
            SELECT pay.customer_trx_id
              FROM ar_receivable_applications ra, ar_payment_schedules pay
             WHERE     ra.gl_date BETWEEN l_gl_date_low AND l_gl_date_high
                   AND NVL (ra.confirmed_flag, 'Y') = 'Y'
                   AND ra.status = 'APP'
                   AND ra.application_type = 'CM'
                   AND pay.payment_schedule_id = ra.payment_schedule_id
            UNION
            SELECT pay.customer_trx_id
              FROM ar_receivable_applications ra, ar_payment_schedules pay
             WHERE     ra.gl_date BETWEEN l_gl_date_low AND l_gl_date_high
                   AND NVL (ra.confirmed_flag, 'Y') = 'Y'
                   AND ra.status = 'APP'
                   AND pay.payment_schedule_id =
                       ra.applied_payment_schedule_id
            UNION
            SELECT trx.customer_trx_id
              FROM ra_customer_trx trx, ra_cust_trx_types TYPE, ra_cust_trx_line_gl_dist gl_dist
             WHERE     gl_dist.gl_date BETWEEN l_gl_date_low
                                           AND l_gl_date_high
                   AND gl_dist.gl_date IS NOT NULL
                   AND gl_dist.account_class = 'REC'
                   AND gl_dist.latest_rec_flag = 'Y'
                   AND gl_dist.customer_trx_id = trx.customer_trx_id
                   AND TYPE.cust_trx_type_id = trx.cust_trx_type_id
                   AND trx.complete_flag = 'Y'
                   AND TYPE.TYPE IN ('INV', 'DEP', 'GUAR',
                                     'CM', 'DM', 'CB')
            UNION
            SELECT trx.customer_trx_id
              FROM ra_customer_trx trx, ra_cust_trx_types TYPE, ra_cust_trx_line_gl_dist gl_dist
             WHERE     trx.trx_date BETWEEN l_gl_date_low AND l_gl_date_high
                   AND gl_dist.gl_date IS NULL
                   AND gl_dist.account_class = 'REC'
                   AND gl_dist.latest_rec_flag = 'Y'
                   AND gl_dist.customer_trx_id = trx.customer_trx_id
                   AND TYPE.cust_trx_type_id = trx.cust_trx_type_id
                   AND trx.complete_flag = 'Y'
                   AND TYPE.TYPE IN ('INV', 'DEP', 'GUAR',
                                     'CM', 'DM', 'CB')
            UNION
            SELECT adj.customer_trx_id
              FROM ar_adjustments adj
             WHERE     adj.gl_date BETWEEN l_gl_date_low AND l_gl_date_high
                   AND NVL (adj.status, 'A') = 'A'
                   AND adj.receivables_trx_id <> -15
            UNION
            SELECT gl_dist.customer_trx_id
              FROM ra_cust_trx_line_gl_dist gl_dist
             WHERE     gl_dist.amount = 0
                   AND gl_dist.acctd_amount <> 0
                   AND gl_dist.gl_date BETWEEN l_gl_date_low
                                           AND l_gl_date_high;

        /* Identify all the payment schedules of a given transaction */
        CURSOR ps_cur (l_cust_trx_id NUMBER)
        IS
            SELECT payment_schedule_id, acctd_amount_due_remaining, gl_date_closed
              FROM ar_payment_schedules
             WHERE customer_trx_id = l_cust_trx_id;

        /* Find out if all the APP record in RA has a corresponding UNAPP
          record with same gl_date
          Case 8 */
        CURSOR app_cur (l_gl_date_low DATE, l_gl_date_high DATE)
        IS
            SELECT ra.cash_receipt_id cr_id, ra.receivable_application_id rec_id
              FROM ar_receivable_applications ra
             WHERE     ra.status = 'APP'
                   AND ra.application_type = 'CASH'
                   AND NVL (ra.confirmed_flag, 'Y') = 'Y'
                   AND ra.gl_date BETWEEN l_gl_date_low AND l_gl_date_high
                   AND NOT EXISTS
                           (SELECT ra_unapp.receivable_application_id
                              FROM ar_receivable_applications ra_unapp, ar_distributions ard
                             WHERE     ard.source_id_secondary =
                                       ra.receivable_application_id
                                   AND ard.source_id_secondary IS NOT NULL
                                   AND ra_unapp.receivable_application_id =
                                       ard.source_id
                                   AND ard.source_table = 'RA'
                                   AND ard.source_type = 'UNAPP'
                                   AND ra_unapp.status = 'UNAPP'
                                   AND ra_unapp.gl_date = ra.gl_date
                                   AND ra_unapp.cash_receipt_id =
                                       ra.cash_receipt_id
                                   AND ra_unapp.cash_receipt_history_id =
                                       ra.cash_receipt_history_id)
                   AND NOT EXISTS
                           (SELECT ra_unapp.receivable_application_id
                              FROM ar_receivable_applications ra_unapp, ar_distributions ard
                             WHERE     ra_unapp.cash_receipt_id =
                                       ra.cash_receipt_id
                                   AND ra_unapp.cash_receipt_history_id =
                                       ra.cash_receipt_history_id
                                   AND ra_unapp.gl_date = ra.gl_date
                                   AND ra_unapp.status = 'UNAPP'
                                   AND ra_unapp.posting_control_id =
                                       ra.posting_control_id
                                   AND NVL (ra_unapp.gl_posted_date, SYSDATE) =
                                       NVL (ra.gl_posted_date, SYSDATE)
                                   AND -ra_unapp.amount_applied =
                                       NVL (ra.amount_applied_from,
                                            ra.amount_applied)
                                   AND ra_unapp.apply_date = ra.apply_date
                                   AND ard.source_id =
                                       ra_unapp.receivable_application_id
                                   AND ard.source_table = 'RA'
                                   AND ard.source_id_secondary IS NULL);

        /* Find out the corruption in reversal_gl_date for the APP records
           Case 9 */
        CURSOR get_cr_ids (l_gl_date_low DATE, l_gl_date_high DATE)
        IS
            SELECT DISTINCT cash_receipt_id
              FROM ar_receivable_applications
             WHERE gl_date BETWEEN l_gl_date_low AND l_gl_date_high;

        CURSOR ra_rev_gl_cur (l_cr_id NUMBER)
        IS
            SELECT ra.cash_receipt_id cr_id, ra.receivable_application_id rec_id, ra_rev.receivable_application_id rev_rec_id,
                   ra.amount_applied + NVL (ra.earned_discount_taken, 0) + NVL (ra.unearned_discount_taken, 0) amount_applied
              FROM ar_receivable_applications ra, ar_distributions ard, ar_receivable_applications ra_rev
             WHERE     ra.cash_receipt_id = l_cr_id
                   AND ra.cash_receipt_id = ra_rev.cash_receipt_id
                   AND ard.source_id = ra_rev.receivable_application_id
                   AND ard.source_table = 'RA'
                   AND ard.source_type = 'REC'
                   AND ard.reversed_source_id = ra.receivable_application_id
                   AND ra.status = 'APP'
                   AND ra_rev.status = 'APP'
                   AND NVL (ra.amount_applied_from, ra.amount_applied) =
                       -NVL (ra_rev.amount_applied_from,
                             ra_rev.amount_applied)
                   AND ra.display = 'N'
                   AND ra_rev.display = ra.display
                   AND ra.gl_date > ra_rev.gl_date;

        /* Identify all the receipts whose gl_date_closed is wrongly populated
           Case 11 */
        CURSOR rcpt_gl_date_cur (l_start_gl_date DATE, l_end_gl_date DATE)
        IS
            SELECT ps.cash_receipt_id, ps.payment_schedule_id
              FROM ar_payment_schedules ps
             WHERE     gl_date_closed >= l_start_gl_date
                   AND TRUNC (ps.gl_date_closed) <>
                       TO_DATE ('31-DEC-4712', 'dd-MON-YYYY')
                   AND ps.CLASS = 'PMT'
                   AND SIGN (ps.payment_schedule_id) <> -1
                   AND EXISTS
                           (SELECT '1'
                              FROM ar_receivable_applications ra
                             WHERE     ra.payment_schedule_id =
                                       ps.payment_schedule_id
                                   AND ra.gl_date > ps.gl_date_closed
                                   AND status IN ('APP', 'ACTIVITY')
                            UNION
                            SELECT '1'
                              FROM ar_receivable_applications ra
                             WHERE     ra.applied_payment_schedule_id =
                                       ps.payment_schedule_id
                                   AND ra.gl_date > ps.gl_date_closed);

        l_out_file                  VARCHAR2 (512) := 'recon.log';
        l_out_dir                   VARCHAR2 (512);
        l_out_dir_usr               VARCHAR2 (512) := '/usr/tmp';
        l_begin_age_amt             NUMBER;
        l_begin_age_acctd_amt       NUMBER;
        l_end_age_amt               NUMBER;
        l_end_age_acctd_amt         NUMBER;
        l_trx_reg_amt               NUMBER;
        l_trx_reg_acctd_amt         NUMBER;
        l_unapp_reg_amt             NUMBER;
        l_unapp_reg_acctd_amt       NUMBER;
        l_app_reg_amt               NUMBER;
        l_app_reg_acctd_amt         NUMBER;
        l_adj_reg_amt               NUMBER;
        l_adj_reg_acctd_amt         NUMBER;
        l_cm_gain_loss              NUMBER;
        l_rounding_diff             NUMBER;
        l_inv_exp_amt               NUMBER;
        l_inv_exp_acctd_amt         NUMBER;
        l_period_total_amt          NUMBER;
        l_period_total_acctd_amt    NUMBER;
        l_recon_diff_amt            NUMBER;
        l_recon_diff_acctd_amt      NUMBER;
        l_unapp_amt                 NUMBER;
        l_unapp_acctd_amt           NUMBER;
        l_acc_amt                   NUMBER;
        l_acc_acctd_amt             NUMBER;
        l_claim_amt                 NUMBER;
        l_claim_acctd_amt           NUMBER;
        l_prepay_amt                NUMBER;
        l_prepay_acctd_amt          NUMBER;
        l_app_amt                   NUMBER;
        l_app_acctd_amt             NUMBER;
        l_edisc_amt                 NUMBER;
        l_edisc_acctd_amt           NUMBER;
        l_unedisc_amt               NUMBER;
        l_unedisc_acctd_amt         NUMBER;
        l_fin_chrg_amt              NUMBER;
        l_fin_chrg_acctd_amt        NUMBER;
        l_adj_amt                   NUMBER;
        l_adj_acctd_amt             NUMBER;
        l_guar_amt                  NUMBER;
        l_guar_acctd_amt            NUMBER;
        l_dep_amt                   NUMBER;
        l_dep_acctd_amt             NUMBER;
        l_endorsmnt_amt             NUMBER;
        l_endorsmnt_acctd_amt       NUMBER;
        l_post_excp_amt             NUMBER;
        l_post_excp_acctd_amt       NUMBER;
        l_nonpost_excp_amt          NUMBER;
        l_nonpost_excp_acctd_amt    NUMBER;
        l_ps_id                     NUMBER;
        l_cust_trx_id               NUMBER;
        l_rec_amount                NUMBER;
        l_round_amount              NUMBER;
        l_amount_due_original_inv   NUMBER;
        l_amount_due_rem_inv        NUMBER;
        l_amount_due_remaining      NUMBER;
        l_amount_applied_from       NUMBER;
        l_amount_applied_to         NUMBER;
        l_amount_adjusted           NUMBER;
        l_gl_date_closed            DATE;
        l_max_gl_date               DATE;
        l_amount_app_adj_inv        NUMBER;
        l_set_of_books_id           NUMBER;
        l_sob_name                  VARCHAR2 (300);
        l_functional_currency       VARCHAR2 (15);
        l_coa_id                    NUMBER;
        l_precision                 NUMBER;
        l_sysdate                   VARCHAR2 (20);
        l_organization              VARCHAR2 (300);
        l_bills_receivable_flag     VARCHAR2 (1);
        l_account_affect_flag       VARCHAR2 (1);
        l_non_post_amt              NUMBER;
        l_non_post_acctd_amt        NUMBER;
        l_post_amt                  NUMBER;
        l_post_acctd_amt            NUMBER;
        l_start_gl_date             DATE;
        l_end_gl_date               DATE;
        l_org_id                    NUMBER := pn_org_id;
        l_ado_hist_amount           NUMBER;
        l_adr_ps_amount             NUMBER;
        l_rec_applied_from          NUMBER;
        l_rec_applied_to            NUMBER;
        l_rec_status                VARCHAR2 (15);
        pg_fp                       UTL_FILE.file_type;
        l_on_acc_cm_ref_amt         NUMBER;
        l_on_acc_cm_ref_acctd_amt   NUMBER;
        l_comma_position            NUMBER;
        lv_org_name                 VARCHAR2 (240);
        lv_org_name1                VARCHAR2 (240);
        lv_trx_num                  VARCHAR2 (30);
        lv_trx_date                 VARCHAR2 (30);
        ln_ret_val                  NUMBER := 0;
        ln_cash_num                 VARCHAR2 (30);
        v_mail_recips               apps.do_mail_utils.tbl_recips;
        lv_convert_email            tracking_num_type := tracking_num_type ();
    BEGIN
        g_mail_message     := NULL;
        l_start_gl_date    :=
            TO_DATE (pd_gl_date_low, 'YYYY/MM/DD HH24:MI:SS');
        l_end_gl_date      :=
            TO_DATE (pd_gl_date_high, 'YYYY/MM/DD HH24:MI:SS');
        lv_convert_email   := g_convert (pv_to_email);

        FOR i IN 1 .. lv_convert_email.COUNT
        LOOP
            v_mail_recips (v_mail_recips.COUNT + 1)   :=
                TRIM (lv_convert_email (i));
        END LOOP;

        IF (l_start_gl_date > l_end_gl_date)
        THEN
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    ' REM                            ');
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                ' ERROR: Start GL-DATE should always be less than or equal to end GL-DATE');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    ' REM                            ');
            RETURN;
        END IF;

        SELECT VALUE
          INTO l_out_dir
          FROM v$parameter
         WHERE UPPER (NAME) = 'UTL_FILE_DIR';

        IF    (INSTR (l_out_dir, l_out_dir_usr) = 0 AND l_out_dir_usr IS NOT NULL)
           OR l_out_dir_usr IS NULL
        THEN
            l_comma_position   := INSTR (l_out_dir, ',');

            IF l_comma_position = 0
            THEN
                l_out_dir_usr   := l_out_dir;
            ELSE
                l_out_dir_usr   :=
                    SUBSTR (l_out_dir, 1, INSTR (l_out_dir, ',') - 1);
            END IF;

            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'The entered directory can not be used');
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'The output will be written to ' || l_out_dir_usr);
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    '                            ');
        END IF;

        IF l_out_file IS NULL
        THEN
            l_out_file   := 'Recon.out';
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'The output is available in Recon.out file ');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    '                            ');
        END IF;

        apps.do_mail_utils.send_mail_header ('erp@deckers.com', v_mail_recips, 'Reconciliation validation between' || TO_CHAR (l_start_gl_date, 'DD-MON-YYYY') || ' and ' || TO_CHAR (l_end_gl_date, 'DD-MON-YYYY')
                                             , ln_ret_val);
        pg_fp              := UTL_FILE.fopen (l_out_dir_usr, l_out_file, 'w');

        BEGIN
            SELECT NAME
              INTO lv_org_name1
              FROM hr_operating_units
             WHERE organization_id = l_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_org_name1   := NULL;
        END;

        DEBUG ('Operating Unit = ' || lv_org_name1);
        --      apps.do_mail_utils.send_mail_line ( 'Org Id = ' || l_org_id
        --                             || CHR (10), ln_ret_val);
        DEBUG ('Start GL Date = ' || l_start_gl_date);
        DEBUG ('End GL Date = ' || l_end_gl_date);
        DEBUG ('Now Starting the analysis ..............');
        /* Case 1:
           Identify all the transactions with gl_date <= the input gl date and which have
             applications gl_date less than the invoice gl_date */
        DEBUG ('.................................');
        DEBUG (
            'Finding out transaction that have applications with payment gl_date less than its gl date');
        DEBUG ('TRX NUMBER          ' || 'PAYMENT_SCHEDULE_ID');
        DEBUG ('--------------      ' || '-------------------');

        FOR ps_apply_rec IN ps_apply_cur (l_start_gl_date, l_end_gl_date)
        LOOP
            get_trx_details (pn_cust_trx => ps_apply_rec.customer_trx_id, xv_org_name => lv_org_name, xv_trx_num => lv_trx_num
                             , xv_trx_date => lv_trx_date);
            DEBUG (
                   lv_trx_num
                || print_spaces (20 - LENGTH (lv_trx_num))
                || ps_apply_rec.payment_schedule_id);
        END LOOP;

        DEBUG ('.................................');
        /* Case 2:
           Identify all the transactions whose gl_date_closed is wrongly populated */
        DEBUG (
            'Identifying invoices whose gl_date_closed is wrongly populated');
        DEBUG ('TRX NUMBER          ' || 'PAYMENT_SCHEDULE_ID');
        DEBUG ('--------------      ' || '-------------------');

        FOR ps_gl_date_rec IN ps_gl_date_cur (l_start_gl_date, l_end_gl_date)
        LOOP
            get_trx_details (pn_cust_trx => ps_gl_date_rec.customer_trx_id, xv_org_name => lv_org_name, xv_trx_num => lv_trx_num
                             , xv_trx_date => lv_trx_date);
            DEBUG (
                   lv_trx_num
                || print_spaces (20 - LENGTH (lv_trx_num))
                || ps_gl_date_rec.payment_schedule_id);
        END LOOP;

        DEBUG ('.................................');
        /* Case 11:
           Identify all the receipts whose gl_date_closed is wrongly populated */
        DEBUG (
            'Identifying receipts whose gl_date_closed is wrongly populated');
        DEBUG ('CASH_RECEIPT_NUM    ' || 'PAYMENT_SCHEDULE_ID');
        DEBUG ('--------------      ' || '-------------------');

        FOR rcpt_gl_date_rec
            IN rcpt_gl_date_cur (l_start_gl_date, l_end_gl_date)
        LOOP
            get_cash_details (
                pn_cash_id    => rcpt_gl_date_rec.cash_receipt_id,
                xn_cash_num   => ln_cash_num);
            DEBUG (
                   ln_cash_num
                || print_spaces (20 - LENGTH (ln_cash_num))
                || rcpt_gl_date_rec.payment_schedule_id);
        END LOOP;

        DEBUG ('.................................');
        /* Case 3:
           Identify the adjustments in functional currency where amount <> acctd_amount */
        DEBUG (
            'Identifying adjustments on functional currency invoices where amount and acctd amount do not match ');
        DEBUG (
               'TRX_NUMBER     '
            || 'ADJUSTMENT_ID       '
            || 'ADJ AMOUNT     '
            || 'ADJ ACCTD AMT');
        DEBUG (
               '---------------     '
            || '-------------       '
            || '----------     '
            || '-------------');

        FOR adj_rec IN adj_cur (l_start_gl_date, l_end_gl_date)
        LOOP
            get_trx_details (pn_cust_trx => adj_rec.customer_trx_id, xv_org_name => lv_org_name, xv_trx_num => lv_trx_num
                             , xv_trx_date => lv_trx_date);
            DEBUG (
                   lv_trx_num
                || print_spaces (20 - LENGTH (lv_trx_num))
                || adj_rec.adjustment_id
                || print_spaces (20 - LENGTH (adj_rec.adjustment_id))
                || adj_rec.amount
                || print_spaces (15 - LENGTH (adj_rec.amount))
                || adj_rec.acctd_amount);
        END LOOP;

        DEBUG ('.................................');
        /* Case 4:
           Identify the adjustments where the sign of amount and acctd_amount are different */
        DEBUG (
            'Identifying adjustments for which the sign of amount and acctd_amount are different ');
        DEBUG (
               'TRX_NUMBER     '
            || 'ADJUSTMENT_ID       '
            || 'ADJ AMOUNT     '
            || 'ADJ ACCTD AMT');
        DEBUG (
               '---------------     '
            || '-------------       '
            || '----------     '
            || '-------------');

        FOR adj_sign_rec IN adj_sign_cur (l_start_gl_date, l_end_gl_date)
        LOOP
            get_trx_details (pn_cust_trx => adj_sign_rec.customer_trx_id, xv_org_name => lv_org_name, xv_trx_num => lv_trx_num
                             , xv_trx_date => lv_trx_date);
            DEBUG (
                   lv_trx_num
                || print_spaces (20 - LENGTH (lv_trx_num))
                || adj_sign_rec.adjustment_id
                || print_spaces (20 - LENGTH (adj_sign_rec.adjustment_id))
                || adj_sign_rec.amount
                || print_spaces (15 - LENGTH (adj_sign_rec.amount))
                || adj_sign_rec.acctd_amount);
        END LOOP;

        DEBUG ('.................................');
        /* Case 10
           Identify the corrupt Receipts */
        DEBUG ('Identifying corrupt receipts ');
        DEBUG (
               'CR_ID         '
            || 'STATUS        '
            || 'HIST AMOUNT     '
            || 'ADR            '
            || 'APPLIED_FROM    '
            || 'APPLIED_TO');
        DEBUG (
               '------        '
            || '--------      '
            || '------------    '
            || '---------      '
            || '------------    '
            || '---------');

        FOR rec_cur
            IN (SELECT DISTINCT cash_receipt_id, payment_schedule_id
                  FROM ar_receivable_applications
                 WHERE     gl_date BETWEEN l_start_gl_date AND l_end_gl_date
                       AND cash_receipt_id IS NOT NULL
                       AND NVL (confirmed_flag, 'Y') = 'Y')
        LOOP
            BEGIN
                SELECT acctd_amount + NVL (acctd_factor_discount_amount, 0), status
                  INTO l_ado_hist_amount, l_rec_status
                  FROM ar_cash_receipt_history
                 WHERE     cash_receipt_id = rec_cur.cash_receipt_id
                       AND current_record_flag = 'Y';

                SELECT ps.acctd_amount_due_remaining
                  INTO l_adr_ps_amount
                  FROM ar_payment_schedules ps
                 WHERE ps.cash_receipt_id = rec_cur.cash_receipt_id;

                SELECT SUM (NVL (ra.acctd_amount_applied_from, ra.amount_applied))
                  INTO l_rec_applied_from
                  FROM ar_receivable_applications ra
                 WHERE     cash_receipt_id = rec_cur.cash_receipt_id
                       AND status IN ('APP', 'ACTIVITY')
                       AND application_type = 'CASH'
                       AND NVL (confirmed_flag, 'Y') = 'Y';

                SELECT SUM (NVL (ra.acctd_amount_applied_to, ra.amount_applied))
                  INTO l_rec_applied_to
                  FROM ar_receivable_applications ra
                 WHERE     ra.applied_payment_schedule_id =
                           rec_cur.payment_schedule_id
                       AND ra.status = 'APP'
                       AND application_type = 'CASH'
                       AND NVL (ra.confirmed_flag, 'Y') = 'Y';

                IF l_rec_status <> 'REVERSED'
                THEN
                    IF NVL (l_ado_hist_amount, 0) <>
                       (NVL (-l_adr_ps_amount, 0) - NVL (l_rec_applied_to, 0) + NVL (l_rec_applied_from, 0))
                    THEN
                        DEBUG (
                               rec_cur.cash_receipt_id
                            || print_spaces (
                                   15 - LENGTH (rec_cur.cash_receipt_id))
                            || l_rec_status
                            || print_spaces (14 - LENGTH (l_rec_status))
                            || NVL (l_ado_hist_amount, 0)
                            || print_spaces (
                                   16 - LENGTH (NVL (l_ado_hist_amount, 0)))
                            || NVL (-l_adr_ps_amount, 0)
                            || print_spaces (
                                   16 - LENGTH (NVL (-l_adr_ps_amount, 0)))
                            || NVL (l_rec_applied_from, 0)
                            || print_spaces (
                                   16 - LENGTH (NVL (l_rec_applied_from, 0)))
                            || NVL (l_rec_applied_to, 0));
                    END IF;
                ELSE
                    IF    l_adr_ps_amount <> 0
                       OR NVL (l_rec_applied_to, 0) <> 0
                       OR NVL (l_rec_applied_from, 0) <> 0
                    THEN
                        DEBUG (
                               rec_cur.cash_receipt_id
                            || print_spaces (
                                   15 - LENGTH (rec_cur.cash_receipt_id))
                            || l_rec_status
                            || print_spaces (14 - LENGTH (l_rec_status))
                            || NVL (l_ado_hist_amount, 0)
                            || print_spaces (
                                   16 - LENGTH (NVL (l_ado_hist_amount, 0)))
                            || NVL (-l_adr_ps_amount, 0)
                            || print_spaces (
                                   16 - LENGTH (NVL (-l_adr_ps_amount, 0)))
                            || NVL (l_rec_applied_from, 0)
                            || print_spaces (
                                   16 - LENGTH (NVL (l_rec_applied_from, 0)))
                            || NVL (l_rec_applied_to, 0));
                    END IF;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    DEBUG (
                        'Error occurred for Cash Receipt ID : ' || rec_cur.cash_receipt_id);
                    DEBUG ('Error : ' || SQLCODE || ' : ' || SQLERRM);
            END;
        END LOOP;

        DEBUG ('.................................');
        --   /* case 12 :
        --      Identify applications having wrong values of applied_payment_schedule_id */
        --
        --    debug('Identifying applications whose applied_payment_schedules_id is wrongly populated in RA');
        --    debug('CR_ID          '||'CUSTOMER_TRX_ID (CM) '||'REC_APP_ID     '||'PS_ID          '||'CUSTOMER_TRX_ID');
        --    debug('----------     '||'-------------------  '||'----------     '||'--------       '||'---------------');
        --    FOR rcpt_ra_rec in get_ra_id_curr() LOOP
        --      debug(rcpt_ra_rec.cash_receipt_id||print_spaces(15-length(nvl(rcpt_ra_rec.cash_receipt_id,0)))||
        --            rcpt_ra_rec.cm_id||print_spaces(21-length(nvl(rcpt_ra_rec.cm_id,0)))||
        --            rcpt_ra_rec.receivable_application_id||
        --            print_spaces(15-length(rcpt_ra_rec.receivable_application_id))||
        --            rcpt_ra_rec.payment_schedule_id||
        --            print_spaces(15-length(rcpt_ra_rec.payment_schedule_id))||
        --            rcpt_ra_rec.inv_id);
        --    END LOOP;
        --
        --           debug('.................................');

        --    /* case 13 */
        --    /* Identify the transactions or receipts for which the payment schedule is closed but
        --       the acctd_amount_due_remaining is not zero */
        --    debug('Identifying trx or receipts for which the payment schedule is closed but AADR is NOT ZERO');
        --    debug(' ');
        --    debug('PS_ID      '||'CLASS '||'TRX_ID      '||'ADR             '||'AADR           '||'GL_DATE');
        --    debug('------     '||'----- '||'-------     '||'---------       '||'--------       '||'-------');
        --    FOR incorrect_ps_status in get_incorrect_ps_status(l_start_gl_date,l_end_gl_date) LOOP
        --       debug(incorrect_ps_status.payment_schedule_id||
        --             print_spaces(12-length(incorrect_ps_status.payment_schedule_id))||
        --             incorrect_ps_status.class||
        --             print_spaces(6-length(incorrect_ps_status.class))||
        --             incorrect_ps_status.trx_id||
        --             print_spaces(13-length(incorrect_ps_status.trx_id))||
        --             incorrect_ps_status.adr||
        --             print_spaces(16-length(incorrect_ps_status.adr))||
        --             incorrect_ps_status.aadr||
        --             print_spaces(16-length(incorrect_ps_status.aadr))||
        --             incorrect_ps_status.gl_date);
        --    END LOOP;
        --           debug('---------------------------');
        --           debug('Searching for orphan/GL_DIST and PS mismatched records......');
        --           debug('CUSTOMER_TRX_ID');
        --           debug('---------------');
        --           for orps_rec in orps_cur(l_start_gl_date,l_start_gl_date) loop
        --              debug(orps_rec.customer_trx_id);
        --           end loop;
        --           debug('---------------------------');
        --           debug('Searching for orphan CM Applications in RA....');
        --           debug('PAYMENT_SCHEDULE_ID');
        --           debug('-------------------');
        --           for orra_rec in orra_cur(l_start_gl_date,l_start_gl_date) loop
        --              debug(orra_rec.payment_schedule_id);
        --           end loop;
        DEBUG ('---------------------------');
        DEBUG ('Searching for APP / UNAPP gl_date difference......');

        FOR app_rec IN app_cur (l_start_gl_date, l_end_gl_date)
        LOOP
            DEBUG ('CASH_RECEIPT_ID     ' || 'RECEVIABLE_APP_ID');
            DEBUG ('---------------     ' || '---------------');
            DEBUG (
                   app_rec.cr_id
                || print_spaces (20 - LENGTH (app_rec.rec_id))
                || app_rec.rec_id);
        END LOOP;

        DEBUG ('---------------------------');

        SELECT set_of_books_id
          INTO l_set_of_books_id
          FROM ar_system_parameters;

        ar_calc_aging.get_report_heading ('3000', l_org_id, l_set_of_books_id, l_sob_name, l_functional_currency, l_coa_id, l_precision, l_sysdate, l_organization
                                          , l_bills_receivable_flag);

        WHILE l_start_gl_date <= l_end_gl_date
        LOOP
            ar_calc_aging.aging_as_of (l_start_gl_date - 1,
                                       l_start_gl_date,
                                       '3000',
                                       l_org_id,
                                       NULL,
                                       NULL,
                                       NULL,
                                       l_begin_age_amt,
                                       l_end_age_amt,
                                       l_begin_age_acctd_amt,
                                       l_end_age_acctd_amt);
            ar_calc_aging.transaction_register (l_start_gl_date,
                                                l_start_gl_date,
                                                '3000',
                                                l_org_id,
                                                NULL,
                                                NULL,
                                                NULL,
                                                l_non_post_amt,
                                                l_non_post_acctd_amt,
                                                l_post_amt,
                                                l_post_acctd_amt);
            l_trx_reg_amt              := NVL (l_post_amt, 0) + NVL (l_non_post_amt, 0);
            l_trx_reg_acctd_amt        :=
                NVL (l_post_acctd_amt, 0) + NVL (l_non_post_acctd_amt, 0);
            ar_calc_aging.cash_receipts_register (l_start_gl_date,
                                                  l_start_gl_date,
                                                  '3000',
                                                  l_org_id,
                                                  NULL,
                                                  NULL,
                                                  NULL,
                                                  l_unapp_amt,
                                                  l_unapp_acctd_amt,
                                                  l_acc_amt,
                                                  l_acc_acctd_amt,
                                                  l_claim_amt,
                                                  l_claim_acctd_amt,
                                                  l_prepay_amt,
                                                  l_prepay_acctd_amt,
                                                  l_app_amt,
                                                  l_app_acctd_amt,
                                                  l_edisc_amt,
                                                  l_edisc_acctd_amt,
                                                  l_unedisc_amt,
                                                  l_unedisc_acctd_amt,
                                                  l_cm_gain_loss,
                                                  l_on_acc_cm_ref_amt,
                                                  l_on_acc_cm_ref_acctd_amt);
            l_unapp_reg_amt            :=
                  NVL (l_unapp_amt, 0)
                + NVL (l_acc_amt, 0)
                + NVL (l_claim_amt, 0)
                + NVL (l_prepay_amt, 0);
            l_unapp_reg_acctd_amt      :=
                  NVL (l_unapp_acctd_amt, 0)
                + NVL (l_acc_acctd_amt, 0)
                + NVL (l_claim_acctd_amt, 0)
                + NVL (l_prepay_acctd_amt, 0);
            l_app_reg_amt              :=
                  NVL (l_app_amt, 0)
                + NVL (l_edisc_amt, 0)
                + NVL (l_unedisc_amt, 0)
                + NVL (l_on_acc_cm_ref_amt, 0);
            l_app_reg_acctd_amt        :=
                  NVL (l_app_acctd_amt, 0)
                + NVL (l_edisc_acctd_amt, 0)
                + NVL (l_unedisc_acctd_amt, 0)
                + NVL (l_on_acc_cm_ref_acctd_amt, 0);
            ar_calc_aging.adjustment_register (l_start_gl_date,
                                               l_start_gl_date,
                                               '3000',
                                               l_org_id,
                                               NULL,
                                               NULL,
                                               NULL,
                                               l_fin_chrg_amt,
                                               l_fin_chrg_acctd_amt,
                                               l_adj_amt,
                                               l_adj_acctd_amt,
                                               l_guar_amt,
                                               l_guar_acctd_amt,
                                               l_dep_amt,
                                               l_dep_acctd_amt,
                                               l_endorsmnt_amt,
                                               l_endorsmnt_acctd_amt);
            l_adj_reg_amt              :=
                  NVL (l_fin_chrg_amt, 0)
                + NVL (l_adj_amt, 0)
                + NVL (l_guar_amt, 0)
                + NVL (l_dep_amt, 0)
                + NVL (l_endorsmnt_amt, 0);
            l_adj_reg_acctd_amt        :=
                  NVL (l_fin_chrg_acctd_amt, 0)
                + NVL (l_adj_acctd_amt, 0)
                + NVL (l_guar_acctd_amt, 0)
                + NVL (l_dep_acctd_amt, 0)
                + NVL (l_endorsmnt_acctd_amt, 0);
            ar_calc_aging.invoice_exceptions (l_start_gl_date,
                                              l_start_gl_date,
                                              '3000',
                                              l_org_id,
                                              NULL,
                                              NULL,
                                              NULL,
                                              l_post_excp_amt,
                                              l_post_excp_acctd_amt,
                                              l_nonpost_excp_amt,
                                              l_nonpost_excp_acctd_amt);
            l_inv_exp_amt              :=
                NVL (l_post_excp_amt, 0) + NVL (l_nonpost_excp_amt, 0);
            l_inv_exp_acctd_amt        :=
                  NVL (l_post_excp_acctd_amt, 0)
                + NVL (l_nonpost_excp_acctd_amt, 0);
            l_period_total_acctd_amt   :=
                (l_begin_age_acctd_amt + l_trx_reg_acctd_amt - l_unapp_reg_acctd_amt - l_app_reg_acctd_amt + l_adj_reg_acctd_amt + l_cm_gain_loss - l_inv_exp_acctd_amt);

            IF l_period_total_acctd_amt = l_end_age_acctd_amt
            THEN
                DEBUG ('Figures Match for ' || TO_CHAR (l_start_gl_date));
                DEBUG ('---------------------------');
            ELSE
                DEBUG (
                    'Figures do not match for ' || TO_CHAR (l_start_gl_date));
                /*DEBUG (   'l_begin_age_acctd_amt = '
                       || TO_CHAR (l_begin_age_acctd_amt)
                      );
                DEBUG ('l_trx_reg_acctd_amt = ' || TO_CHAR (l_trx_reg_acctd_amt));
                DEBUG (   'l_unapp_reg_acctd_amt = '
                       || TO_CHAR (l_unapp_reg_acctd_amt)
                      );
                DEBUG ('l_app_reg_acctd_amt = ' || TO_CHAR (l_app_reg_acctd_amt));
                DEBUG ('l_adj_reg_acctd_amt = ' || TO_CHAR (l_adj_reg_acctd_amt));
                DEBUG ('l_cm_gain_loss = ' || TO_CHAR (l_cm_gain_loss));
                DEBUG ('l_inv_exp_acctd_amt = ' || TO_CHAR (l_inv_exp_acctd_amt));
                DEBUG ('l_rounding_diff = ' || TO_CHAR (l_rounding_diff));
                DEBUG ('l_end_age_acctd_amt = ' || TO_CHAR (l_end_age_acctd_amt));
                DEBUG (   'Difference = '
                       || TO_CHAR (l_period_total_acctd_amt - l_end_age_acctd_amt)
                      );
                DEBUG ('---------------------------');
                DEBUG ('Analysing Transactions......');*/
                DEBUG (
                       RPAD ('Operating Unit', 29, ' ')
                    || ' '
                    || RPAD ('Transaction Num', 19, ' ')
                    || ' '
                    || RPAD ('Transaction Date', 19, ' ')
                    || ' '
                    || LPAD ('Amt Due Original', 19, ' ')
                    || ' '
                    || LPAD ('Amt Applied or Adjusted', 29, ' ')
                    || ' '
                    || LPAD ('Amt Due remaining', 19, ' '));
                DEBUG (RPAD ('-', 140, '-'));

                FOR inv_rec IN inv_cur (l_start_gl_date, l_start_gl_date)
                LOOP
                    l_cust_trx_id   := inv_rec.customer_trx_id;

                    SELECT accounting_affect_flag
                      INTO l_account_affect_flag
                      FROM ra_cust_trx_types TYPE, ra_customer_trx trx
                     WHERE     trx.customer_trx_id = l_cust_trx_id
                           AND trx.cust_trx_type_id = TYPE.cust_trx_type_id;

                    IF l_account_affect_flag = 'Y'
                    THEN
                        SELECT SUM (DECODE (account_class, 'REC', DECODE (latest_rec_flag, 'Y', acctd_amount, 0), 0)), SUM (DECODE (account_class, 'ROUND', DECODE (amount, 0, acctd_amount, 0), 0))
                          INTO l_rec_amount, l_round_amount
                          FROM ra_cust_trx_line_gl_dist
                         WHERE customer_trx_id = l_cust_trx_id;

                        /* Don't consider the round difference for the time being. Bug 3430956 */
                        /*   l_amount_due_original_inv  := l_rec_amount - l_round_amount; */
                        l_amount_due_original_inv   := l_rec_amount;
                        l_amount_due_rem_inv        := 0;
                        l_amount_app_adj_inv        := 0;

                        FOR ps_rec IN ps_cur (l_cust_trx_id)
                        LOOP
                            l_ps_id                  := ps_rec.payment_schedule_id;
                            l_amount_due_remaining   :=
                                ps_rec.acctd_amount_due_remaining;
                            l_gl_date_closed         := ps_rec.gl_date_closed;
                            l_amount_due_rem_inv     :=
                                l_amount_due_rem_inv + l_amount_due_remaining;

                            SELECT SUM (acctd_amount_applied_from + NVL (acctd_earned_discount_taken, 0) + NVL (acctd_unearned_discount_taken, 0))
                              INTO l_amount_applied_from
                              FROM ar_receivable_applications
                             WHERE     payment_schedule_id = l_ps_id
                                   AND NVL (confirmed_flag, 'Y') = 'Y'
                                   AND status = 'APP';

                            SELECT SUM (-(acctd_amount_applied_to + NVL (acctd_earned_discount_taken, 0) + NVL (acctd_unearned_discount_taken, 0)))
                              INTO l_amount_applied_to
                              FROM ar_receivable_applications
                             WHERE     applied_payment_schedule_id = l_ps_id
                                   AND NVL (confirmed_flag, 'Y') = 'Y'
                                   AND status = 'APP';

                            SELECT SUM (acctd_amount)
                              INTO l_amount_adjusted
                              FROM ar_adjustments
                             WHERE     payment_schedule_id = l_ps_id
                                   AND NVL (status, 'A') = 'A'
                                   AND receivables_trx_id <> -15;

                            l_amount_app_adj_inv     :=
                                  NVL (l_amount_app_adj_inv, 0)
                                + NVL (l_amount_applied_from, 0)
                                + NVL (l_amount_applied_to, 0)
                                + NVL (l_amount_adjusted, 0);
                        END LOOP;

                        IF   NVL (l_amount_due_rem_inv, 0)
                           - NVL (l_amount_app_adj_inv, 0) =
                           l_amount_due_original_inv
                        THEN
                            NULL;
                        ELSE
                            /*DEBUG ('customer_trx_id  = ' || TO_CHAR (l_cust_trx_id));
                            DEBUG ('---------------------------');
                            DEBUG (   'Amount Due Original = '
                                   || TO_CHAR (l_amount_due_original_inv)
                                  );
                            DEBUG (   'Amount Applied or Adjusted ='
                                   || TO_CHAR (NVL (l_amount_app_adj_inv, 0))
                                  );
                            DEBUG (   'Amount Due Remaining = '
                                   || TO_CHAR (l_amount_due_rem_inv)
                                  );*/
                            get_trx_details (pn_cust_trx => l_cust_trx_id, xv_org_name => lv_org_name, xv_trx_num => lv_trx_num
                                             , xv_trx_date => lv_trx_date);
                            DEBUG (
                                   RPAD (lv_org_name, 29, ' ')
                                || ' '
                                || RPAD (lv_trx_num, 19, ' ')
                                || ' '
                                || RPAD (lv_trx_date, 19, ' ')
                                || ' '
                                || LPAD (TO_CHAR (l_amount_due_original_inv),
                                         19,
                                         ' ')
                                || ' '
                                || LPAD (
                                       TO_CHAR (
                                           NVL (l_amount_app_adj_inv, 0)),
                                       29,
                                       ' ')
                                || ' '
                                || LPAD (TO_CHAR (l_amount_due_rem_inv),
                                         19,
                                         ' '));
                        END IF;
                    END IF;
                END LOOP;

                DEBUG ('---------------------------');
                DEBUG ('Searching for Applications with wrong rev_gl_date');

                FOR get_cr_rec
                    IN get_cr_ids (l_start_gl_date, l_start_gl_date)
                LOOP
                    FOR ra_rev_gl_rec
                        IN ra_rev_gl_cur (get_cr_rec.cash_receipt_id)
                    LOOP
                        IF ra_rev_gl_rec.amount_applied <> 0
                        THEN
                            DEBUG (
                                'Cash_Receipt_id = ' || (ra_rev_gl_rec.cr_id));
                            DEBUG (
                                   'Receivable Application Id = '
                                || (ra_rev_gl_rec.rec_id));
                            DEBUG (
                                   'Reversal Application Id = '
                                || (ra_rev_gl_rec.rev_rec_id));
                        END IF;
                    END LOOP;
                END LOOP;

                DEBUG ('---------------------------');
            END IF;

            l_start_gl_date            := l_start_gl_date + 1;
        END LOOP;

        g_mail_message     := SUBSTR (g_mail_message, 1, 32600);

        IF LENGTH (g_mail_message) > 32600
        THEN
            g_mail_message   :=
                   g_mail_message
                || CHR (10)
                || '*******Message text too long. Hence, Truncated. Please check output of request id:'
                || TO_CHAR (fnd_global.conc_request_id)
                || '*******';
        END IF;

        apps.do_mail_utils.send_mail_line (g_mail_message, ln_ret_val);
        apps.do_mail_utils.send_mail_close (ln_ret_val);
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'RECON_CONTROL:' || SQLERRM);
    END recon_control;

    FUNCTION g_convert (pv_list IN VARCHAR2)
        RETURN tracking_num_type
    AS
        lv_string        VARCHAR2 (32767) := pv_list || ',';
        ln_comma_index   PLS_INTEGER;
        ln_index         PLS_INTEGER := 1;
        l_tab            tracking_num_type := tracking_num_type ();
    BEGIN
        LOOP
            ln_comma_index        := INSTR (lv_string, ',', ln_index);
            EXIT WHEN ln_comma_index = 0;
            l_tab.EXTEND;
            l_tab (l_tab.COUNT)   :=
                SUBSTR (lv_string, ln_index, ln_comma_index - ln_index);
            ln_index              := ln_comma_index + 1;
        END LOOP;

        RETURN l_tab;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                fnd_file.LOG,
                'Error occured while converting the comma seperated to table type');
            RETURN NULL;
    END g_convert;
END xxdoar_recon_pkg;
/
