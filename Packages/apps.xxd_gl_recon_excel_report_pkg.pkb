--
-- XXD_GL_RECON_EXCEL_REPORT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:55 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_GL_RECON_EXCEL_REPORT_PKG"
AS
    /*
    ********************************************************************************************************************************
    **                                                                                                                             *
    **    Author          : Srinath Siricilla                                                                                      *
    **                                                                                                                             *
    **    Purpose         : This is based on General Ledger Reconciliation Report - Deckers                                        *
    **                      This is excel version of the report.                                                                   *
    **                      This will provide the details of the Text version of report in Excel format.                           *
    **                                                                                                                             *
    **                                                                                                                             *
    **History         :                                                                                                            *
    **------------------------------------------------------------------------------------------                                   *
    **Date        Author              Version   Change Notes                                                                       *
    **----------- ---------           -------   ------------------------------------------------------------                       *
    *29-JUL-2018  Srinath Siricilla   1.0       Initial creation for CCR0007351                                                    *
 *20-NOV-2019  Showkath Ali        1.1       CCR0007883 -- Modified to print all Statement lines matched to a Transaction       *
                                                           created/cleared in the next period not showing in the report         *
    ********************************************************************************************************************************/

    /*********************************************************************************************************************
    * Type                : Procedure                                                                                    *
    * Name                : xxd_main                                                                                     *
    * Purpose             : Function to Initiate the XML data generation                                                 *
    *********************************************************************************************************************/
    FUNCTION xxd_main
        RETURN BOOLEAN
    IS
        ln_bank_account_id   NUMBER;
        ln_closing_balance   NUMBER;
        ld_from_date         DATE;
        ld_as_of_date        DATE;
        lv_report_type       VARCHAR2 (100);
        lv_include_reval     VARCHAR2 (10);
        lv_exld_prev_reval   VARCHAR2 (10);
        lv_temp              VARCHAR2 (10);
    BEGIN
        IF p_bank_account_id IS NOT NULL AND p_closing_balance IS NOT NULL --AND p_from_date IS NOT NULL and p_as_of_date IS NOT NULL
        THEN
            ln_bank_account_id   := p_bank_account_id;
            ln_closing_balance   := p_closing_balance;
            lv_include_reval     := pv_include_reval;
            lv_exld_prev_reval   := NVL (pv_exld_prev_reval, 'N');

            IF UPPER (lv_exld_prev_reval) = 'YES'
            THEN
                lv_exld_prev_reval   := 'Y';
            ELSIF UPPER (lv_exld_prev_reval) = 'NO'
            THEN
                lv_exld_prev_reval   := 'N';
            END IF;

            lv_temp              := NULL;

            --ld_from_date := fnd_date.canonical_to_date(p_from_date);
            --ld_as_of_date := fnd_date.canonical_to_date(p_as_of_date);

            --EXECUTE IMMEDIATE 'truncate table XXDO.XXD_GL_RECON_REP_GT';

            BEGIN
                xxd_main_proc (ln_bank_account_id, ln_closing_balance, p_from_date, p_as_of_date, p_report_type, lv_include_reval
                               , lv_exld_prev_reval, lv_temp);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
                    fnd_file.put_line (fnd_file.LOG,
                                       ' Error is - ' || SQLERRM);
            END;
        END IF;

        RETURN TRUE;
    END xxd_main;

    /*********************************************************************************************************************
    * Type                : Procedure                                                                                    *
    * Name                : xxd_main_proc                                                                                *
    * Purpose             : To Run both summary procedure and detail procedure                                           *
    *********************************************************************************************************************/
    PROCEDURE xxd_main_proc (p_bank_account_id    IN NUMBER,
                             p_closing_balance    IN NUMBER,
                             p_from_date          IN VARCHAR2,
                             p_as_of_date         IN VARCHAR2,
                             p_report_type        IN VARCHAR2,
                             pv_include_reval     IN VARCHAR2,
                             pv_exld_prev_reval   IN VARCHAR2,
                             pv_temp              IN VARCHAR2)
    IS
        --Local variable declaration
        lc_status      VARCHAR2 (20);
        lc_error_msg   VARCHAR2 (32567);
    BEGIN
        IF p_report_type IN ('SUMMARY', 'DETAIL')
        THEN
            xxd_sum_detail_proc (p_bank_account_id,
                                 p_closing_balance,
                                 p_from_date,
                                 p_as_of_date,
                                 p_report_type,
                                 pv_include_reval,
                                 pv_exld_prev_reval,
                                 lc_status,
                                 lc_error_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error in main procedure -- '
                || lc_status
                || '-'
                || lc_error_msg);
    END;



    FUNCTION get_current_period (P_as_of_date        VARCHAR2,
                                 P_SET_OF_BOOKS_ID   NUMBER)
        RETURN VARCHAR2
    IS
        lv_curr_period   VARCHAR2 (50);
    BEGIN
        SELECT period_name
          INTO lv_curr_period
          FROM gl_periods gp, gl_ledgers gl, gl_access_sets gas
         WHERE     1 = 1
               AND fnd_date.canonical_to_date (p_as_of_date) BETWEEN start_date
                                                                 AND end_date
               AND gl.ledger_id = P_SET_OF_BOOKS_ID
               AND gl.implicit_access_set_id = gas.access_set_id
               AND gas.period_set_name = gp.period_set_name;

        RETURN lv_curr_period;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Error in get_current_period -- ' || SQLERRM);
    END;

    /*********************************************************************************************************************
  * Type                : Procedure                                                                                      *
  * Name                : xxd_sum_detail_proc                                                                            *
  * Purpose             : The Summary report lists the General Ledger cash account balance and an adjusted balance for   *
                          the bank statement. It also lists a separate adjustment amount for unreconciled receipts,      *
                          payments, and journal entries which have been recorded in the General Ledger cash account,     *
                          as well as bank errors.                                                                        *
                          The Detail report provides details for the unreconciled items as well as the information       *
                          contained in the Summary report.This report does not include information on Payroll            *
                          payments, Treasury settlements, or external transactions in the Reconciliation Open            *
                          Interface because they may have been posted to a different General Ledger account              *
                          than the one assigned to the bank account.                                                       *
  ************************************************************************************************************************/


    FUNCTION xxd_format_amount (p_amount NUMBER)
        RETURN VARCHAR2
    IS
        lv_amount   VARCHAR2 (100);
    BEGIN
        lv_amount   :=
            TO_CHAR (p_amount, 'FM9G999G999G999G999G999G999G999G990D00PT');


        RETURN lv_amount;
    END;

    PROCEDURE xxd_sum_detail_proc (p_bank_account_id IN NUMBER, p_closing_balance IN NUMBER, p_from_date IN VARCHAR2, p_as_of_date IN VARCHAR2, p_report_type IN VARCHAR2, pv_include_reval IN VARCHAR2
                                   , pv_exld_prev_reval IN VARCHAR2, p_sum_status OUT VARCHAR2, p_sum_error_msg OUT VARCHAR2)
    IS
        --Local Variable Declaration
        l_date                      VARCHAR2 (200);

        ln_set_of_books_id          NUMBER;
        ln_cash_clearing_ccid       NUMBER;
        ln_asset_cc_id              NUMBER;
        lc_bank_curr_code           CE_BANK_ACCOUNTS.currency_code%TYPE;
        lc_gl_curr_code             gl_sets_of_books.currency_code%TYPE;
        ln_chart_of_acct_id         NUMBER;
        lc_meaning                  ce_lookups.meaning%TYPE;
        ld_end_date                 DATE;


        ln_sum_cash                 NUMBER := 0;
        ln_sum_clearing             NUMBER := 0;
        ln_sum_receipts_no_rev      NUMBER := 0;
        --added by Arun N Murthy on 21 Jan 2017
        ln_sum_receipts_rec_nxt     NUMBER := 0;
        ln_sum_void_curr_amt        NUMBER := 0;
        ln_gl_balance               NUMBER := 0;
        --added by Arun N Murthy on 21 Jan 2017
        ln_sum_receipts_rev         NUMBER := 0;
        ln_sum_line_errors          NUMBER := 0;
        ln_sum_cf_amt               NUMBER := 0;
        ln_sum_cf_acct_amt          NUMBER := 0;
        ln_sum_dep_amt              NUMBER := 0;
        ln_sum_pay_amt              NUMBER := 0;
        ln_sum_journal_par_amt      NUMBER := 0;
        ln_sum_journal_no_par_amt   NUMBER := 0;
        ln_sum_no_void_clear_amt    NUMBER := 0;
        ln_sum_clear_amt            NUMBER := 0;
        ln_sum_void_amt             NUMBER := 0;
        ln_sum_stmt_next_period     NUMBER := 0;
        ln_sum_rec_rec_mismtch      NUMBER := 0;
        ln_sum_pymt_mismtch         NUMBER := 0;
        ln_sum_adjustment           NUMBER := 0;
        ln_difference               NUMBER := 0;
        lc_bank_branch_name         ce_bank_branches_v.bank_branch_name%TYPE;
        lc_bank_name                ce_bank_branches_v.bank_name%TYPE;
        lc_bank_account_name        ce_bank_accounts.bank_account_name%TYPE;
        lc_bank_account_num         ce_bank_accounts.bank_account_num%TYPE;



        lc_from_date                VARCHAR2 (200);
        lc_as_of_date               VARCHAR2 (200);

        lc_out_bank_branch          VARCHAR2 (200);
        lc_out_bank_name            VARCHAR2 (200);
        lc_out_bank_acc_name        VARCHAR2 (200);
        lc_out_bank_acc_num         VARCHAR2 (200);
        lc_out_bank_currency        VARCHAR2 (200);

        lc_closing_balance          VARCHAR2 (2000);
        lc_summary_output           VARCHAR2 (2000);
        lc_ar_recp_rev              VARCHAR2 (2000);
        --added by Deckers IT Team  on 21 Jan 2017
        lc_sum_receipts_rec_nxt     VARCHAR2 (2000);
        lc_ar_recp_no_rev           VARCHAR2 (2000);
        lc_ap_payments              VARCHAR2 (2000);
        lc_ap_payments_cleared      VARCHAR2 (2000);
        lc_ap_payments_voided       VARCHAR2 (2000);
        lc_cashflows                VARCHAR2 (2000);
        lc_journal_no_par           VARCHAR2 (2000);
        lc_journal_par              VARCHAR2 (2000);
        lc_line_errors              VARCHAR2 (2000);
        lc_lines                    VARCHAR2 (2000);
        lc_adjustment_balance       VARCHAR2 (2000);
        lc_diff_lines               VARCHAR2 (2000);
        lc_difference               VARCHAR2 (2000);
        lc_gl_balances              VARCHAR2 (2000);
        lc_gl_cash                  VARCHAR2 (2000);
        lc_gl_clearing              VARCHAR2 (2000);
        lc_statement_dep            VARCHAR2 (2000);
        lc_statement_pay            VARCHAR2 (2000);
        lc_statement_trans          VARCHAR2 (2000);

        lc_detail_output            VARCHAR2 (2000);
        lc_detail_view              VARCHAR2 (2000);
        lc_detail_fields            VARCHAR2 (2000);
        lc_detail_data              VARCHAR2 (2000);
        lc_detail_total             VARCHAR2 (2000);
        lv_period_name              VARCHAR2 (50);
        ln_sum_ce_line_mismtch      NUMBER := 0;
        ln_trx_amount               NUMBER := 0;
        ln_trx_acctd_amount         NUMBER := 0;
        lv_error_flag               VARCHAR2 (1) := 'N';


        -- Fetching details for code combinations
        CURSOR gl_set_of_books_c (p_bank_account_id NUMBER)
        IS
            SELECT cb.set_of_books_id, ba.cash_clearing_ccid, ba.ASSET_CODE_COMBINATION_ID,
                   ba.currency_code
              FROM ce_system_parameters cb, CE_BANK_ACCOUNTS ba
             WHERE     cb.legal_entity_id = ba.account_owner_org_id
                   AND ba.bank_account_id = P_BANK_ACCOUNT_ID;



        -- Fetching General ledger details
        CURSOR gl_details_c (P_SET_OF_BOOKS_ID NUMBER, p_as_of_date VARCHAR2)
        IS
            SELECT gl.set_of_books_id, gl.currency_code, gl.chart_of_accounts_id,
                   l.meaning, p.end_date
              FROM gl_sets_of_books gl, ce_lookups l, gl_period_statuses p
             WHERE     p.period_name =
                       NVL (
                           TO_CHAR (
                               fnd_date.canonical_to_date (p_as_of_date),
                               'MON-YY'),
                           p.period_name)
                   AND p.application_id = 101
                   AND p.set_of_books_id = P_SET_OF_BOOKS_ID
                   AND gl.set_of_books_id = P_SET_OF_BOOKS_ID
                   AND l.lookup_type = 'LITERAL'
                   AND l.lookup_code = 'ALL';



        -- Fetching CE Bank Details
        CURSOR ce_bank_details_c (p_bank_account_id NUMBER)
        IS
            SELECT abb.bank_branch_name, abb.bank_name, aba.bank_account_name,
                   aba.bank_account_num
              FROM ce_bank_branches_v abb, ce_bank_accounts aba
             WHERE     abb.branch_party_id = aba.bank_branch_id
                   AND aba.bank_account_id = P_BANK_ACCOUNT_ID;


        -- Fetching details for asset code combinations
        CURSOR asset_ccid_c (p_bank_account_id NUMBER)
        IS
            SELECT DISTINCT gac.asset_code_combination_id
              FROM ce_bank_acct_uses_all bau, ce_GL_ACCOUNTS_CCID gac
             WHERE     gac.bank_acct_use_id = bau.bank_acct_use_id
                   AND bau.bank_account_id = P_BANK_ACCOUNT_ID;


        ---General Ledger Cash Account Balance for CASH
        CURSOR gl_balances_cash_c (P_SET_OF_BOOKS_ID NUMBER, p_bank_curr_dsp VARCHAR2, p_chart_of_Accounts_id NUMBER
                                   , p_from_date VARCHAR2, p_as_of_date VARCHAR2, p_asset_cc_id NUMBER)
        IS
            SELECT *
              FROM (  SELECT glck.concatenated_segments C_GL_ACCOUNT, TO_NUMBER (NVL (BAL.period_net_dr, 0) - NVL (BAL.period_net_cr, 0) + NVL (BAL.begin_balance_dr, 0) - NVL (begin_balance_cr, 0)) C_END_BAL_CASH
                        FROM GL_BALANCES BAL, GL_CODE_COMBINATIONS GLCC, gl_code_combinations_kfv GLCK,
                             GL_LEDGERS gl, gl_periods gp, GL_ACCESS_SETS gas
                       WHERE     BAL.ACTUAL_FLAG = 'A'
                             AND BAL.LEDGER_ID = TO_NUMBER (P_SET_OF_BOOKS_ID)
                             AND BAL.CURRENCY_CODE = P_BANK_CURR_DSP
                             AND NVL (BAL.TRANSLATED_FLAG, 'R') = 'R'
                             AND --BAL.period_name = NVL (to_char(fnd_date.canonical_to_date (p_as_of_date),'MON-YY'), BAL.period_name) AND
                                 BAL.CODE_COMBINATION_ID =
                                 GLCC.CODE_COMBINATION_ID
                             AND GLCC.CHART_OF_ACCOUNTS_ID =
                                 TO_NUMBER (P_CHART_OF_ACCOUNTS_ID)
                             AND GLCC.TEMPLATE_ID IS NULL
                             AND GLCK.code_combination_id =
                                 GLCC.CODE_COMBINATION_ID
                             AND gl.ledger_id = BAL.LEDGER_ID
                             AND gl.implicit_access_set_id = gas.access_set_id
                             AND gas.period_set_name = gp.period_set_name
                             AND BAL.period_name = gp.period_name
                             AND   --and gp.period_set_name = 'DO_FY_CALENDAR'
                                 TRUNC (gp.start_Date) >=
                                 TRUNC (
                                     NVL (
                                         fnd_date.canonical_to_date (
                                             P_FROM_DATE),
                                         gp.start_Date))
                             AND gp.end_Date <=
                                 TRUNC (
                                     NVL (
                                         fnd_date.canonical_to_date (
                                             p_as_of_date),
                                         gp.end_Date))
                             AND GLCC.code_combination_id =
                                 TO_NUMBER (P_ASSET_CC_ID)
                    ORDER BY gp.period_year DESC, gp.period_num DESC)
             WHERE 1 = 1 AND ROWNUM = 1;

        -- ---General Ledger Cash Account Balance for CASH CLEARING
        CURSOR gl_balances_clearing_c (P_SET_OF_BOOKS_ID NUMBER, p_bank_curr_dsp VARCHAR2, p_chart_of_Accounts_id NUMBER
                                       , p_from_date VARCHAR2, p_as_of_date VARCHAR2, p_clearing_cc_id NUMBER)
        IS
            SELECT *
              FROM (  SELECT glck.concatenated_segments C_GL_ACCOUNT, TO_NUMBER (NVL (BAL.period_net_dr, 0) - NVL (BAL.period_net_cr, 0) + NVL (BAL.begin_balance_dr, 0) - NVL (begin_balance_cr, 0)) C_END_BAL_ClEARING
                        FROM GL_BALANCES BAL, GL_CODE_COMBINATIONS GLCC, gl_code_combinations_kfv GLCK,
                             GL_LEDGERS gl, gl_periods gp, GL_ACCESS_SETS gas
                       WHERE     BAL.ACTUAL_FLAG = 'A'
                             AND BAL.LEDGER_ID = TO_NUMBER (P_SET_OF_BOOKS_ID)
                             AND BAL.CURRENCY_CODE = P_BANK_CURR_DSP
                             AND NVL (BAL.TRANSLATED_FLAG, 'R') = 'R'
                             AND --BAL.period_name = NVL (to_char(fnd_date.canonical_to_date (p_as_of_date),'MON-YY'), BAL.period_name) AND
                                 BAL.CODE_COMBINATION_ID =
                                 GLCC.CODE_COMBINATION_ID
                             AND GLCC.CHART_OF_ACCOUNTS_ID =
                                 TO_NUMBER (P_CHART_OF_ACCOUNTS_ID)
                             AND GLCC.TEMPLATE_ID IS NULL
                             AND GLCK.code_combination_id =
                                 GLCC.CODE_COMBINATION_ID
                             AND gl.ledger_id = BAL.LEDGER_ID
                             AND gl.implicit_access_set_id = gas.access_set_id
                             AND gas.period_set_name = gp.period_set_name
                             AND BAL.period_name = gp.period_name
                             AND   --and gp.period_set_name = 'DO_FY_CALENDAR'
                                 TRUNC (gp.start_Date) >=
                                 TRUNC (
                                     NVL (
                                         fnd_date.canonical_to_date (
                                             P_FROM_DATE),
                                         gp.start_Date))
                             AND TRUNC (gp.end_Date) <=
                                 TRUNC (
                                     NVL (
                                         fnd_date.canonical_to_date (
                                             p_as_of_date),
                                         gp.end_Date))
                             AND GLCC.code_combination_id =
                                 TO_NUMBER (p_clearing_cc_id)
                    ORDER BY gp.period_year DESC, gp.period_num DESC)
             WHERE 1 = 1 AND ROWNUM = 1;


        -- Unreconciled Receipts not reversed
        CURSOR ar_receipts_not_reversed_c (p_bank_account_id    NUMBER,
                                           p_from_date          VARCHAR2,
                                           p_as_of_date         VARCHAR2,
                                           P_BANK_CURR_DSP      VARCHAR2,
                                           P_GL_CURRENCY_CODE   VARCHAR2)
        IS
              SELECT 'RECEIPT' C_AR_TYPE, NVL (ROUND (DECODE (P_BANK_CURR_DSP, P_GL_CURRENCY_CODE, DECODE (crh.status, 'REVERSED', -crh.acctd_amount, crh.acctd_amount), DECODE (crh.status, 'REVERSED', -crh.amount, crh.amount)), fc.precision), 0) C_AR_AMOUNT_NO_REV, REPLACE (LTRIM (RTRIM (hz.party_name)), CHR (9), '') C_AR_CUSTOMER_NAME,
                     aeh.accounting_date C_AR_GL_DATE, cr.receipt_date C_AR_REMIT_DATE, arm.name C_AR_PAYMENT_METHOD,
                     cr.receipt_number C_AR_RECEIPT_NUMBER, cr.currency_code C_AR_CURRENCY, cr.amount C_AR_TRANS_AMOUNT,
                     crh.status C_AR_STATUS, fnd_access_control_util.get_org_name (cr.org_id) C_ORG_NAME_AR
                FROM ar_cash_receipts_all cr, ar_cash_receipt_history_all crh, hz_cust_accounts cu,
                     hz_parties hz, ar_receipt_methods arm, ce_bank_acct_uses_all bau,
                     ce_bank_accounts ba, ce_system_parameters SYS, xla_transaction_entities_upg trx,
                     xla_ae_headers aeh, xla_ae_lines ael, fnd_currencies fc
               WHERE     cr.cash_receipt_id = crh.cash_receipt_id
                     AND cr.remit_bank_acct_use_id = bau.bank_acct_use_id
                     AND bau.bank_account_id = P_BANK_ACCOUNT_ID
                     AND bau.org_id = cr.org_id
                     AND TRX.application_id = 222       /* 13536461 - added */
                     AND TRX.ledger_id = SYS.set_of_books_id /* 13536461 - added */
                     AND NVL (TRX.source_id_int_1, -99) = crh.cash_receipt_id
                     AND TRX.entity_code = 'RECEIPTS'
                     --         and aeh.event_id = crh.event_id
                     AND AEH.entity_id(+) = TRX.entity_id
                     AND NVL (AEH.application_id, 222) = 222 /* 13536461 - added */
                     AND NVL (AEH.ledger_id, SYS.set_of_books_id) =
                         SYS.set_of_books_id /* 17078656 - nvl added for outer join */
                     --         AND NVL (AEH.event_type_code, 'X') NOT IN ('PAYMENT CANCELLED',
                     --                                                    'REFUND CANCELLED')
                     AND aeh.ae_header_id = ael.ae_header_id(+)
                     AND aeh.ledger_id = ael.ledger_id(+)
                     AND aeh.application_id = ael.application_id(+)
                     AND ael.accounting_class_code(+) = 'CASH'
                     AND bau.bank_account_id = ba.bank_account_id
                     AND ba.account_owner_org_id = sys.legal_entity_id
                     AND crh.account_code_combination_id =
                         ba.asset_code_combination_id
                     AND crh.status NOT IN ('REVERSED')
                     AND crh.current_record_flag = 'Y'
                     AND ba.currency_code = fc.currency_code
                     --         AND  aeh.accounting_date  BETWEEN NVL (fnd_date.canonical_to_date ( P_FROM_DATE ),aeh.accounting_date)
                     --                                     AND NVL (fnd_date.canonical_to_date ( P_AS_OF_DATE ),aeh.accounting_date)
                     AND TRUNC (cr.receipt_date) BETWEEN TRUNC (
                                                             NVL (
                                                                 fnd_date.canonical_to_date (
                                                                     P_FROM_DATE),
                                                                 cr.receipt_date))
                                                     AND TRUNC (
                                                             NVL (
                                                                 fnd_date.canonical_to_date (
                                                                     P_AS_OF_DATE),
                                                                 cr.receipt_date))
                     AND DECODE (
                             crh.status,
                             'REMITTED', NVL (crh.reversal_created_from, 'X'),
                             crh.created_from) <>
                         'RATE ADJUSTMENT TRIGGER'
                     /* Do not consider current_record flag. Max accounted event before
                        as-of-date will not have its reversal event before as-of-date. Posting to
                        GL should be checked by posting_control_id flag */
                     AND (   AEH.event_id =
                             (SELECT MAX (event_id)
                                FROM xla_events xe
                               WHERE     xe.application_id = 222 /* 14698507 - Added */
                                     AND xe.entity_id = TRX.entity_id
                                     --Added by ANM on 27 Mar 2017
                                     AND xe.event_id = aeh.event_id
                                     AND xe.event_number =
                                         (SELECT MAX (event_number)
                                            FROM xla_events xe2
                                           WHERE     xe2.application_id = 222 /* 14698507 - Added */
                                                 --AND xe2.event_id = aeh.event_id
                                                 AND xe2.entity_id =
                                                     xe.entity_id
                                                 --AND xe2.event_date <= C_AS_OF_DATE
                                                 AND TRUNC (xe2.event_date) >=
                                                     TRUNC (
                                                         SYS.cashbook_begin_date)
                                                 AND xe2.event_status_code =
                                                     'P'
                                                 AND xe2.event_type_code NOT IN
                                                         ('ADJ_CREATE'))) /* 8241869 */
                          OR AEH.event_id IS NULL)
                     AND crh.posting_control_id > 0
                     AND NOT EXISTS
                             (SELECT 1
                                FROM ar_cash_receipt_history_all crh_r
                               WHERE     crh_r.cash_receipt_history_id =
                                         crh.reversal_cash_receipt_hist_id
                                     AND TRUNC (crh_r.gl_date) BETWEEN TRUNC (
                                                                           NVL (
                                                                               fnd_date.canonical_to_date (
                                                                                   P_FROM_DATE),
                                                                               crh_r.gl_date))
                                                                   AND TRUNC (
                                                                           NVL (
                                                                               fnd_date.canonical_to_date (
                                                                                   P_AS_OF_DATE),
                                                                               crh_r.gl_date))
                                     AND crh_r.posting_control_id > 0
                                     AND crh_r.created_from <>
                                         'RATE ADJUSTMENT TRIGGER')
                     AND cu.cust_account_id(+) = cr.pay_from_customer
                     AND hz.party_id(+) = cu.party_id
                     AND arm.receipt_method_id = cr.receipt_method_id
                     AND cr.status NOT IN ('REV')
                     AND NOT EXISTS
                             (SELECT NULL
                                FROM ce_statement_reconcils_all sr, ce_statement_lines sl, ce_statement_headers sh
                               WHERE     sr.reference_id =
                                         crh.cash_receipt_history_id
                                     AND sr.reference_type = 'RECEIPT'
                                     --Start changes V2.0 by Deckers IT Team-- excluding Eternal Cash Statement Lines
                                     AND (sr.status_flag = 'M' OR sl.status = 'EXTERNAL')
                                     AND sr.current_record_flag = 'Y'
                                     --End changes V2.0 by Deckers IT Team
                                     AND sl.statement_line_id =
                                         sr.statement_line_id
                                     AND sl.statement_header_id =
                                         sh.statement_header_id
                                     AND sh.bank_account_id = P_BANK_ACCOUNT_ID
                                     AND TRUNC (sh.statement_date) BETWEEN TRUNC (
                                                                               NVL (
                                                                                   fnd_date.canonical_to_date (
                                                                                       P_FROM_DATE),
                                                                                   sh.statement_date))
                                                                       AND TRUNC (
                                                                               NVL (
                                                                                   fnd_date.canonical_to_date (
                                                                                       P_AS_OF_DATE),
                                                                                   sh.statement_date))
                              /*   For receipts cleared with rate adjustment, reference id that
                                  is reconciled will be created from RATE ADJUSTMENT TRIGGER.*/
                              UNION
                              SELECT NULL
                                FROM ce_statement_reconcils_all sr, ce_statement_lines sl, ce_statement_headers sh,
                                     ar_cash_receipt_history_all crh_rc
                               WHERE     sr.reference_id =
                                         crh_rc.cash_receipt_history_id
                                     AND sr.reference_type = 'RECEIPT'
                                     --Start changes V2.0 by Deckers IT Team-- excluding Eternal Cash Statement Lines
                                     AND (sr.status_flag = 'M' OR sl.status = 'EXTERNAL')
                                     AND sr.current_record_flag = 'Y'
                                     --End changes V2.0 by Deckers IT Team
                                     AND sl.statement_line_id =
                                         sr.statement_line_id
                                     AND sl.statement_header_id =
                                         sh.statement_header_id
                                     AND sh.bank_account_id = P_BANK_ACCOUNT_ID
                                     AND TRUNC (sh.statement_date) BETWEEN TRUNC (
                                                                               NVL (
                                                                                   fnd_date.canonical_to_date (
                                                                                       P_FROM_DATE),
                                                                                   sh.statement_date))
                                                                       AND TRUNC (
                                                                               NVL (
                                                                                   fnd_date.canonical_to_date (
                                                                                       P_AS_OF_DATE),
                                                                                   sh.statement_date))
                                     AND crh_rc.created_from =
                                         'RATE ADJUSTMENT TRIGGER'
                                     AND crh_rc.cash_receipt_id =
                                         cr.cash_receipt_id)
                     AND NOT EXISTS
                             (SELECT 1
                                FROM ar_cash_receipt_history_all CRH2
                               WHERE     crh.cash_receipt_history_id =
                                         crh2.reversal_cash_receipt_hist_id
                                     AND crh.status = 'REVERSED'
                                     AND crh2.status = 'CONFIRMED')
            ORDER BY C_ORG_NAME_AR, C_AR_GL_DATE, C_AR_CUSTOMER_NAME;



        --unreconciled receipts cleared in next period
        CURSOR ar_receipts_clr_nxt_period_c (p_bank_account_id    NUMBER,
                                             p_from_date          VARCHAR2,
                                             p_as_of_date         VARCHAR2,
                                             P_BANK_CURR_DSP      VARCHAR2,
                                             P_GL_CURRENCY_CODE   VARCHAR2)
        IS
              SELECT 'RECEIPT' C_AR_TYPE, NVL (ROUND (DECODE (P_BANK_CURR_DSP, P_GL_CURRENCY_CODE, DECODE (crh.status, 'REVERSED', -crh.acctd_amount, crh.acctd_amount), DECODE (crh.status, 'REVERSED', -crh.amount, crh.amount)), fc.precision), 0) C_AR_AMOUNT_CLR, REPLACE (LTRIM (RTRIM (hz.party_name)), CHR (9), '') C_AR_CUSTOMER_NAME,
                     aeh.accounting_date C_AR_GL_DATE, cr.receipt_date C_AR_REMIT_DATE, arm.name C_AR_PAYMENT_METHOD,
                     cr.receipt_number C_AR_RECEIPT_NUMBER, cr.currency_code C_AR_CURRENCY, cr.amount C_AR_TRANS_AMOUNT,
                     crh.status C_AR_STATUS, fnd_access_control_util.get_org_name (cr.org_id) C_ORG_NAME_AR
                FROM ar_cash_receipts_all cr, ar_cash_receipt_history_all crh, hz_cust_accounts cu,
                     hz_parties hz, ar_receipt_methods arm, ce_bank_acct_uses_all bau,
                     ce_bank_accounts ba, ce_system_parameters SYS, xla_transaction_entities_upg trx,
                     xla_ae_headers aeh, xla_ae_lines ael, fnd_currencies fc
               WHERE     cr.cash_receipt_id = crh.cash_receipt_id
                     AND cr.remit_bank_acct_use_id = bau.bank_acct_use_id
                     AND bau.bank_account_id = P_BANK_ACCOUNT_ID
                     AND bau.org_id = cr.org_id
                     AND TRX.application_id = 222       /* 13536461 - added */
                     AND TRX.ledger_id = SYS.set_of_books_id /* 13536461 - added */
                     AND NVL (TRX.source_id_int_1, -99) = crh.cash_receipt_id
                     AND TRX.entity_code = 'RECEIPTS'
                     --         and aeh.event_id = crh.event_id
                     AND crh.current_record_flag = 'Y'
                     AND AEH.entity_id(+) = TRX.entity_id
                     AND NVL (AEH.application_id, 222) = 222 /* 13536461 - added */
                     AND NVL (AEH.ledger_id, SYS.set_of_books_id) =
                         SYS.set_of_books_id /* 17078656 - nvl added for outer join */
                     --         AND NVL (AEH.event_type_code, 'X') NOT IN ('PAYMENT CANCELLED',
                     --                                                    'REFUND CANCELLED')
                     AND bau.bank_account_id = ba.bank_account_id
                     AND ba.account_owner_org_id = sys.legal_entity_id
                     AND crh.account_code_combination_id =
                         ba.asset_code_combination_id
                     AND crh.status NOT IN ('REVERSED')
                     AND ba.currency_code = fc.currency_code
                     AND aeh.ae_header_id = ael.ae_header_id
                     AND aeh.ledger_id = ael.ledger_id
                     AND aeh.application_id = ael.application_id
                     AND ael.accounting_class_code = 'CASH'
                     AND TRUNC (aeh.accounting_date) >
                         TRUNC (
                             NVL (fnd_date.canonical_to_date (p_as_of_date),
                                  aeh.accounting_date))
                     AND TRUNC (cr.receipt_date) BETWEEN TRUNC (
                                                             NVL (
                                                                 fnd_date.canonical_to_date (
                                                                     p_from_date),
                                                                 cr.receipt_date))
                                                     AND TRUNC (
                                                             NVL (
                                                                 fnd_date.canonical_to_date (
                                                                     p_as_of_date),
                                                                 cr.receipt_date))
                     AND DECODE (
                             crh.status,
                             'REMITTED', NVL (crh.reversal_created_from, 'X'),
                             crh.created_from) <>
                         'RATE ADJUSTMENT TRIGGER'
                     /* Do not consider current_record flag. Max accounted event before
                        as-of-date will not have its reversal event before as-of-date. Posting to
                        GL should be checked by posting_control_id flag */
                     AND (   AEH.event_id =
                             (SELECT MAX (event_id)
                                FROM xla_events xe
                               WHERE     xe.application_id = 222 /* 14698507 - Added */
                                     AND xe.entity_id = TRX.entity_id
                                     AND xe.event_number =
                                         (SELECT MAX (event_number)
                                            FROM xla_events xe2
                                           WHERE     xe2.application_id = 222 /* 14698507 - Added */
                                                 AND xe2.entity_id =
                                                     xe.entity_id
                                                 --AND xe2.event_date <= C_AS_OF_DATE
                                                 AND TRUNC (xe2.event_date) >=
                                                     TRUNC (
                                                         SYS.cashbook_begin_date)
                                                 AND xe2.event_status_code =
                                                     'P'
                                                 AND xe2.event_type_code NOT IN
                                                         ('ADJ_CREATE'))
                                     AND NOT EXISTS
                                             (SELECT 1
                                                FROM xla_transaction_entities_upg xte2, xla_ae_headers aeh2, xla_ae_lines ael2
                                               WHERE     xte2.application_id =
                                                         222 /* 14698507 - Added */
                                                     AND xte2.entity_id =
                                                         trx.entity_id
                                                     AND xe.application_id =
                                                         xte2.application_id
                                                     AND aeh2.ae_header_id =
                                                         ael2.ae_header_id
                                                     AND xte2.entity_id =
                                                         aeh2.entity_id
                                                     AND aeh2.ledger_id =
                                                         ael2.ledger_id
                                                     AND aeh2.application_id =
                                                         ael2.application_id
                                                     AND ael2.accounting_class_code =
                                                         'CASH'
                                                     AND TRUNC (
                                                             ael2.accounting_date) BETWEEN TRUNC (
                                                                                               NVL (
                                                                                                   fnd_date.canonical_to_date (
                                                                                                       p_from_date),
                                                                                                   ael2.accounting_date))
                                                                                       AND TRUNC (
                                                                                               NVL (
                                                                                                   fnd_date.canonical_to_date (
                                                                                                       p_as_of_date),
                                                                                                   ael2.accounting_date))
                                              HAVING SUM (
                                                           NVL (
                                                               ael2.entered_dr,
                                                               0)
                                                         - NVL (
                                                               ael2.entered_cr,
                                                               0)) <>
                                                     0))         /* 8241869 */
                          OR AEH.event_id IS NULL)
                     AND crh.posting_control_id > 0
                     AND NOT EXISTS
                             (SELECT 1
                                FROM ar_cash_receipt_history_all crh_r
                               WHERE     crh_r.cash_receipt_history_id =
                                         crh.reversal_cash_receipt_hist_id
                                     AND TRUNC (crh_r.gl_date) BETWEEN TRUNC (
                                                                           NVL (
                                                                               fnd_date.canonical_to_date (
                                                                                   p_from_date),
                                                                               crh_r.gl_date))
                                                                   AND TRUNC (
                                                                           NVL (
                                                                               fnd_date.canonical_to_date (
                                                                                   p_as_of_date),
                                                                               crh_r.gl_date))
                                     AND crh_r.posting_control_id > 0
                                     AND crh_r.created_from <>
                                         'RATE ADJUSTMENT TRIGGER')
                     AND cu.cust_account_id(+) = cr.pay_from_customer
                     AND hz.party_id(+) = cu.party_id
                     AND arm.receipt_method_id = cr.receipt_method_id
                     AND cr.status NOT IN ('REV')
                     AND EXISTS
                             (SELECT NULL
                                FROM ce_statement_reconcils_all sr, ce_statement_lines sl, ce_statement_headers sh
                               WHERE     sr.reference_id =
                                         crh.cash_receipt_history_id
                                     AND sr.reference_type = 'RECEIPT'
                                     --Start changes V2.0 by Deckers IT Team-- excluding Eternal Cash Statement Lines
                                     AND (sr.status_flag = 'M' OR sl.status != 'EXTERNAL')
                                     AND sr.current_record_flag = 'Y'
                                     --End changes V2.0 by Deckers IT Team
                                     AND sl.statement_line_id =
                                         sr.statement_line_id
                                     AND sl.statement_header_id =
                                         sh.statement_header_id
                                     AND sh.bank_account_id = P_BANK_ACCOUNT_ID
                              --                            AND TRUNC (sh.statement_date) BETWEEN NVL (
                              --                                                                     fnd_date.canonical_to_date ( p_from_date),
                              --                                                                     sh.statement_date)
                              --                                                              AND NVL (
                              --                                                                     fnd_date.canonical_to_date ( p_as_of_date),
                              --                                                                     sh.statement_date)
                              /*   For receipts cleared with rate adjustment, reference id that
                                  is reconciled will be created from RATE ADJUSTMENT TRIGGER.*/
                              UNION
                              SELECT NULL
                                FROM ce_statement_reconcils_all sr, ce_statement_lines sl, ce_statement_headers sh,
                                     ar_cash_receipt_history_all crh_rc
                               WHERE     sr.reference_id =
                                         crh_rc.cash_receipt_history_id
                                     AND sr.reference_type = 'RECEIPT'
                                     --Start changes V2.0 by Deckers IT Team-- excluding Eternal Cash Statement Lines
                                     AND (sr.status_flag = 'M' OR sl.status != 'EXTERNAL')
                                     AND sr.current_record_flag = 'Y'
                                     --End changes V2.0 by Deckers IT Team
                                     AND sl.statement_line_id =
                                         sr.statement_line_id
                                     AND sl.statement_header_id =
                                         sh.statement_header_id
                                     AND sh.bank_account_id = P_BANK_ACCOUNT_ID
                                     --                            AND TRUNC (sh.statement_date) BETWEEN NVL (
                                     --                                                                     fnd_date.canonical_to_date ( p_from_date),sh.statement_date)
                                     --                                                              AND NVL (
                                     --                                                                     fnd_date.canonical_to_date ( p_as_of_date),sh.statement_date)
                                     AND crh_rc.created_from =
                                         'RATE ADJUSTMENT TRIGGER'
                                     AND crh_rc.cash_receipt_id =
                                         cr.cash_receipt_id)
                     AND NOT EXISTS
                             (SELECT 1
                                FROM ar_cash_receipt_history_all CRH2
                               WHERE     crh.cash_receipt_history_id =
                                         crh2.reversal_cash_receipt_hist_id
                                     AND crh.status = 'REVERSED'
                                     AND crh2.status = 'CONFIRMED')
            ORDER BY C_ORG_NAME_AR, C_AR_GL_DATE, C_AR_CUSTOMER_NAME;

        --Unreconciled Receipts reversed in the next period
        CURSOR ar_receipts_reversed_c (p_bank_account_id    NUMBER,
                                       p_from_date          VARCHAR2,
                                       p_as_of_date         VARCHAR2,
                                       P_BANK_CURR_DSP      VARCHAR2,
                                       P_GL_CURRENCY_CODE   VARCHAR2)
        IS
            SELECT 'RECEIPT' C_AR_TYPE, NVL (ROUND (DECODE (P_BANK_CURR_DSP, P_GL_CURRENCY_CODE, DECODE (crh.status, 'REVERSED', -crh.acctd_amount, crh.acctd_amount), DECODE (crh.status, 'REVERSED', -crh.amount, crh.amount)), fc.precision), 0) C_AR_AMOUNT_REV, --to_clob(REPLACE (LTRIM (RTRIM (hz.party_name)), CHR (9), ''))
                                                                                                                                                                                                                                                                     --  C_AR_CUSTOMER_NAME,
                                                                                                                                                                                                                                                                     REPLACE (LTRIM (RTRIM (hz.party_name)), CHR (9), '') C_AR_CUSTOMER_NAME,
                   aeh.accounting_date C_AR_GL_DATE, cr.receipt_date C_AR_REMIT_DATE, arm.name C_AR_PAYMENT_METHOD,
                   cr.receipt_number C_AR_RECEIPT_NUMBER, cr.currency_code C_AR_CURRENCY, cr.amount C_AR_TRANS_AMOUNT,
                   crh.status C_AR_STATUS, fnd_access_control_util.get_org_name (cr.org_id) C_ORG_NAME_AR
              FROM ar_cash_receipts_all cr, ar_cash_receipt_history_all crh, hz_cust_accounts cu,
                   hz_parties hz, ar_receipt_methods arm, ce_bank_acct_uses_all bau,
                   ce_bank_accounts ba, ce_system_parameters SYS, xla_transaction_entities_upg trx,
                   xla_ae_headers aeh, fnd_currencies fc
             WHERE     cr.cash_receipt_id = crh.cash_receipt_id
                   AND cr.remit_bank_acct_use_id = bau.bank_acct_use_id
                   AND bau.bank_account_id = P_BANK_ACCOUNT_ID
                   AND TRX.application_id = 222         /* 13536461 - added */
                   AND TRX.ledger_id = SYS.set_of_books_id /* 13536461 - added */
                   AND NVL (TRX.source_id_int_1, -99) = crh.cash_receipt_id
                   AND TRX.entity_code = 'RECEIPTS'
                   --         and aeh.event_id = crh.event_id
                   AND AEH.entity_id(+) = TRX.entity_id
                   AND NVL (AEH.application_id, 222) = 222 /* 13536461 - added */
                   AND NVL (AEH.ledger_id, SYS.set_of_books_id) =
                       SYS.set_of_books_id /* 17078656 - nvl added for outer join */
                   AND bau.org_id = cr.org_id
                   AND bau.bank_account_id = ba.bank_account_id
                   AND ba.account_owner_org_id = sys.legal_entity_id
                   AND crh.account_code_combination_id =
                       ba.asset_code_combination_id
                   AND crh.status IN ('REVERSED')
                   AND crh.current_record_flag = 'Y'
                   AND ba.currency_code = fc.currency_code
                   --AND    crh.gl_date > NVL (fnd_date.canonical_to_date ( p_as_of_date), crh.gl_date)
                   AND TRUNC (aeh.accounting_date) >
                       TRUNC (
                           NVL (fnd_date.canonical_to_date (p_as_of_date),
                                aeh.accounting_date))
                   AND TRUNC (cr.receipt_date) BETWEEN TRUNC (
                                                           NVL (
                                                               fnd_date.canonical_to_date (
                                                                   p_from_date),
                                                               cr.receipt_date))
                                                   AND TRUNC (
                                                           NVL (
                                                               fnd_date.canonical_to_date (
                                                                   p_as_of_date),
                                                               cr.receipt_date))
                   AND DECODE (
                           crh.status,
                           'REMITTED', NVL (crh.reversal_created_from, 'X'),
                           crh.created_from) <>
                       'RATE ADJUSTMENT TRIGGER'
                   AND crh.posting_control_id > 0
                   AND (   AEH.event_id =
                           (SELECT MAX (event_id)
                              FROM xla_events xe
                             WHERE     xe.application_id = 222 /* 14698507 - Added */
                                   AND xe.entity_id = TRX.entity_id
                                   AND xe.event_number =
                                       (SELECT MAX (event_number)
                                          FROM xla_events xe2
                                         WHERE     xe2.application_id = 222 /* 14698507 - Added */
                                               AND xe2.entity_id =
                                                   xe.entity_id
                                               --AND xe2.event_date <= C_AS_OF_DATE
                                               AND TRUNC (xe2.event_date) >=
                                                   TRUNC (
                                                       SYS.cashbook_begin_date)
                                               AND xe2.event_status_code =
                                                   'P'
                                               AND xe2.event_type_code NOT IN
                                                       ('ADJ_CREATE'))) /* 8241869 */
                        OR AEH.event_id IS NULL)
                   AND NOT EXISTS
                           (SELECT 1
                              FROM ar_cash_receipt_history_all crh_r
                             WHERE     crh_r.cash_receipt_history_id =
                                       crh.reversal_cash_receipt_hist_id
                                   AND TRUNC (crh_r.gl_date) BETWEEN TRUNC (
                                                                         NVL (
                                                                             fnd_date.canonical_to_date (
                                                                                 p_from_date),
                                                                             crh_r.gl_date))
                                                                 AND TRUNC (
                                                                         NVL (
                                                                             fnd_date.canonical_to_date (
                                                                                 p_as_of_date),
                                                                             crh_r.gl_date))
                                   AND crh_r.posting_control_id > 0
                                   AND crh_r.created_from <>
                                       'RATE ADJUSTMENT TRIGGER')
                   AND cu.cust_account_id(+) = cr.pay_from_customer
                   AND hz.party_id(+) = cu.party_id
                   AND arm.receipt_method_id = cr.receipt_method_id
                   AND cr.status <> 'REV'
                   AND EXISTS
                           (SELECT NULL
                              FROM ce_statement_reconcils_all sr, ce_statement_lines sl, ce_statement_headers sh
                             WHERE     sr.reference_id =
                                       crh.cash_receipt_history_id
                                   AND sr.reference_type = 'RECEIPT'
                                   --Start changes V2.0 by Deckers IT Team-- excluding Eternal Cash Statement Lines
                                   AND (sr.status_flag = 'M' OR sl.status != 'EXTERNAL')
                                   AND sr.current_record_flag = 'Y'
                                   --End changes V2.0 by Deckers IT Team
                                   AND sl.statement_line_id =
                                       sr.statement_line_id
                                   AND sl.statement_header_id =
                                       sh.statement_header_id
                                   AND sh.bank_account_id = P_BANK_ACCOUNT_ID
                            --    AND   sh.statement_date     BETWEEN NVL (fnd_date.canonical_to_date ( p_from_date)
                            --                                        ,  sh.statement_date )
                            --                                  AND NVL (fnd_date.canonical_to_date ( p_as_of_date), sh.statement_date)
                            UNION
                            SELECT NULL
                              FROM ce_statement_reconcils_all sr, ce_statement_lines sl, ce_statement_headers sh,
                                   ar_cash_receipt_history_all crh_rc
                             WHERE     sr.reference_id =
                                       crh_rc.cash_receipt_history_id
                                   AND sr.reference_type = 'RECEIPT'
                                   --Start changes V2.0 by Deckers IT Team-- excluding Eternal Cash Statement Lines
                                   AND (sr.status_flag = 'M' OR sl.status != 'EXTERNAL')
                                   AND sr.current_record_flag = 'Y'
                                   --End changes V2.0 by Deckers IT Team
                                   AND sl.statement_line_id =
                                       sr.statement_line_id
                                   AND sl.statement_header_id =
                                       sh.statement_header_id
                                   AND sh.bank_account_id = P_BANK_ACCOUNT_ID
                                   --    AND   sh.statement_date     BETWEEN NVL (fnd_date.canonical_to_date ( p_from_date)
                                   --                                        ,  sh.statement_date )
                                   --                                  AND NVL (fnd_date.canonical_to_date ( p_as_of_date), sh.statement_date)
                                   AND crh_rc.created_from =
                                       'RATE ADJUSTMENT TRIGGER'
                                   AND crh_rc.cash_receipt_id =
                                       cr.cash_receipt_id)
                   AND EXISTS
                           (SELECT 1
                              FROM ar_cash_receipt_history_all CRH2
                             WHERE     crh.cash_receipt_history_id =
                                       crh2.reversal_cash_receipt_hist_id
                                   AND crh.status != 'REVERSED'
                                   AND crh2.status = 'CONFIRMED')
            /*
                Query 2: Fetch cleared event for a reversed receipt which has not been
                reconciled
            */
            UNION ALL
            SELECT 'RECEIPT' C_AR_TYPE, ROUND (DECODE (P_BANK_CURR_DSP, P_GL_CURRENCY_CODE, crh.acctd_amount, crh.amount), fc.precision) C_AR_AMOUNT_REV, -- to_clob(REPLACE (LTRIM (RTRIM (hz.party_name)), CHR (9), ''))
                                                                                                                                                          --C_AR_CUSTOMER_NAME,
                                                                                                                                                          REPLACE (LTRIM (RTRIM (hz.party_name)), CHR (9), '') C_AR_CUSTOMER_NAME,
                   aeh.accounting_date C_AR_GL_DATE, cr.receipt_date C_AR_REMIT_DATE, arm.name C_AR_PAYMENT_METHOD,
                   cr.receipt_number C_AR_RECEIPT_NUMBER, cr.currency_code C_AR_CURRENCY, cr.amount C_AR_TRANS_AMOUNT,
                   crh2.status C_AR_STATUS, fnd_access_control_util.get_org_name (cr.org_id) C_ORG_NAME_AR
              FROM ar_cash_receipts_all cr, ar_cash_receipt_history_all crh2, ar_cash_receipt_history_all crh,
                   hz_cust_accounts cu, hz_parties hz, ar_receipt_methods arm,
                   ce_bank_acct_uses_ou_v bau, ce_bank_accounts ba, ce_system_parameters SYS,
                   xla_transaction_entities_upg trx, xla_ae_headers aeh, fnd_currencies fc
             WHERE     cr.cash_receipt_id = crh.cash_receipt_id
                   AND cr.remit_bank_acct_use_id = bau.bank_acct_use_id
                   AND bau.bank_account_id = P_BANK_ACCOUNT_ID
                   AND bau.org_id = cr.org_id
                   AND bau.bank_account_id = ba.bank_account_id
                   AND NVL (CRH2.current_record_flag, 'N') = 'Y'
                   AND ba.account_owner_org_id = sys.legal_entity_id
                   AND crh.account_code_combination_id =
                       ba.asset_code_combination_id
                   AND crh.status IN ('REMITTED', 'CLEARED')
                   AND TRX.application_id = 222         /* 13536461 - added */
                   AND TRX.ledger_id = SYS.set_of_books_id /* 13536461 - added */
                   AND NVL (TRX.source_id_int_1, -99) = crh.cash_receipt_id
                   AND TRX.entity_code = 'RECEIPTS'
                   --         and aeh.event_id = crh.event_id
                   AND AEH.entity_id(+) = TRX.entity_id
                   AND NVL (AEH.application_id, 222) = 222 /* 13536461 - added */
                   AND NVL (AEH.ledger_id, SYS.set_of_books_id) =
                       SYS.set_of_books_id
                   AND ba.currency_code = fc.currency_code
                   AND TRUNC (cr.receipt_date) BETWEEN TRUNC (
                                                           NVL (
                                                               fnd_date.canonical_to_date (
                                                                   p_from_date),
                                                               cr.receipt_date))
                                                   AND TRUNC (
                                                           NVL (
                                                               fnd_date.canonical_to_date (
                                                                   p_as_of_date),
                                                               cr.receipt_date))
                   AND TRUNC (aeh.accounting_date) >
                       TRUNC (
                           NVL (fnd_date.canonical_to_date (p_as_of_date),
                                aeh.accounting_date))
                   AND crh.gl_posted_date IS NOT NULL
                   AND crh.created_from <> 'RATE ADJUSTMENT TRIGGER'
                   AND crh2.cash_receipt_id = crh.cash_receipt_id
                   AND crh2.cash_receipt_history_id =
                       crh.reversal_cash_receipt_hist_id
                   AND crh2.status = 'REVERSED'
                   AND cu.cust_account_id(+) = cr.pay_from_customer
                   AND hz.party_id(+) = cu.party_id
                   AND arm.receipt_method_id = cr.receipt_method_id
                   AND (cr.status <> 'REV' OR (cr.status = 'REV'))
                   AND TRUNC (NVL (crh.reversal_gl_date, SYSDATE + 9999)) BETWEEN TRUNC (
                                                                                      NVL (
                                                                                          fnd_date.canonical_to_date (
                                                                                              p_from_date),
                                                                                          crh.reversal_gl_date))
                                                                              AND TRUNC (
                                                                                      NVL (
                                                                                          fnd_date.canonical_to_date (
                                                                                              p_as_of_date),
                                                                                          crh.reversal_gl_date))
                   AND (   AEH.event_id =
                           (SELECT MAX (event_id)
                              FROM xla_events xe
                             WHERE     xe.application_id = 222 /* 14698507 - Added */
                                   AND xe.entity_id = TRX.entity_id
                                   AND xe.event_number =
                                       (SELECT MAX (event_number)
                                          FROM xla_events xe2
                                         WHERE     xe2.application_id = 222 /* 14698507 - Added */
                                               AND xe2.entity_id =
                                                   xe.entity_id
                                               --AND xe2.event_date <= C_AS_OF_DATE
                                               AND TRUNC (xe2.event_date) >=
                                                   TRUNC (
                                                       SYS.cashbook_begin_date)
                                               AND xe2.event_status_code =
                                                   'P'
                                               AND xe2.event_type_code NOT IN
                                                       ('ADJ_CREATE'))) /* 8241869 */
                        OR AEH.event_id IS NULL)
                   AND EXISTS
                           (SELECT NULL
                              FROM ce_statement_reconcils_all sr, ce_statement_lines sl, ce_statement_headers sh
                             WHERE     sr.reference_id =
                                       crh.cash_receipt_history_id
                                   AND sr.reference_type = 'RECEIPT'
                                   --Start changes V2.0 by Deckers IT Team-- excluding Eternal Cash Statement Lines
                                   AND (sr.status_flag = 'M' OR sl.status != 'EXTERNAL')
                                   AND sr.current_record_flag = 'Y'
                                   --End changes V2.0 by Deckers IT Team
                                   AND sl.statement_line_id =
                                       sr.statement_line_id
                                   AND sl.statement_header_id =
                                       sh.statement_header_id
                                   AND sh.bank_account_id = P_BANK_ACCOUNT_ID --    AND sh.statement_date   <= NVL (fnd_date.canonical_to_date ( p_as_of_date), sh.statement_date)
                                                                             )
            ORDER BY C_ORG_NAME_AR, C_AR_GL_DATE, C_AR_CUSTOMER_NAME;



        --Unreconciled Cashflows
        CURSOR unrecon_cashflows_c (p_bank_account_id NUMBER, p_from_date VARCHAR2, p_as_of_date VARCHAR2)
        IS
            SELECT 'CASHFLOW' C_CF_TYPE, ca.cashflow_id C_CF_NUMBER, ch.accounting_date C_GL_DATE,
                   ca.cashflow_date C_CF_DATE, NVL (xle.name, ca.customer_text) C_COUNTER_NAME, trxn.transaction_sub_type_name C_SUBTYPE_NAME,
                   l1.meaning C_CF_STATUS, ca.cashflow_currency_code C_CF_CURRENCY, ca.cashflow_amount C_CF_AMOUNT,
                   DECODE (ca.cashflow_direction,  'RECEIPT', (-1),  'PAYMENT', (1)) * NVL (ch.cleared_amount, ca.cashflow_amount) C_ACCOUNT_AMOUNT, TRUNC (ca.cashflow_date), ch.accounting_date,
                   ca.cashflow_status_code, ch.event_id
              FROM ce_cashflows ca, ce_cashflow_acct_h ch, ce_trxns_subtype_codes trxn,
                   xle_firstparty_information_v xle, ce_lookups l1, ce_system_parameters SYS
             WHERE     ca.cashflow_bank_account_id = P_BANK_ACCOUNT_ID
                   AND ca.CASHFLOW_LEGAL_ENTITY_ID = sys.legal_entity_id
                   AND ca.cashflow_id = ch.cashflow_id
                   AND ca.source_trxn_subtype_code_id =
                       trxn.trxn_subtype_code_id(+)
                   AND TRUNC (ch.accounting_date) BETWEEN TRUNC (
                                                              NVL (
                                                                  fnd_date.canonical_to_date (
                                                                      P_FROM_DATE),
                                                                  ch.accounting_date))
                                                      AND TRUNC (
                                                              NVL (
                                                                  fnd_date.canonical_to_date (
                                                                      p_as_of_date),
                                                                  ch.accounting_date))
                   AND ca.counterparty_party_id = xle.party_id(+)
                   AND l1.lookup_type = 'CASHFLOW_STATUS_CODE'
                   AND l1.lookup_code = ca.cashflow_status_code
                   AND ca.cashflow_status_code = 'RECONCILED'
                   AND ch.event_id =
                       (SELECT NVL (MAX (a.event_id), -1)
                          FROM ce.ce_cashflow_acct_h a
                         WHERE     a.cashflow_id = ch.cashflow_id
                               AND TRUNC (a.accounting_date) <=
                                   TRUNC (
                                       NVL (
                                           fnd_date.canonical_to_date (
                                               p_as_of_date),
                                           a.accounting_date)))
                   AND ch.event_type =
                       DECODE (ca.source_trxn_type,
                               'BAT', 'CE_BAT_CLEARED',
                               'STMT', 'CE_STMT_RECORDED')
                   AND ch.status_code = 'UNACCOUNTED'
            UNION
            SELECT 'CASHFLOW' C_CF_TYPE, ca.cashflow_id C_CF_NUMBER, ch.accounting_date C_GL_DATE,
                   ca.cashflow_date C_CF_DATE, NVL (xle.name, ca.customer_text) C_COUNTER_NAME, trxn.transaction_sub_type_name C_SUBTYPE_NAME,
                   l1.meaning C_CF_STATUS, ca.cashflow_currency_code C_CF_CURRENCY, ca.cashflow_amount C_CF_AMOUNT,
                   DECODE (ca.cashflow_direction,  'RECEIPT', (1),  'PAYMENT', (-1)) * NVL (ch.cleared_amount, ca.cashflow_amount) C_ACCOUNT_AMOUNT, TRUNC (ca.cashflow_date), ch.accounting_date,
                   ca.cashflow_status_code, ch.event_id
              FROM ce_cashflows ca, ce_cashflow_acct_h ch, xla_events e,
                   xla_ae_headers eh, xla_ae_lines el, ce_trxns_subtype_codes trxn,
                   xle_firstparty_information_v xle, ce_lookups l1, ce_system_parameters SYS
             WHERE     ca.cashflow_bank_account_id = P_BANK_ACCOUNT_ID
                   AND ca.source_trxn_subtype_code_id =
                       trxn.trxn_subtype_code_id(+)
                   AND ca.CASHFLOW_LEGAL_ENTITY_ID = sys.legal_entity_id
                   AND ca.cashflow_id = ch.cashflow_id
                   AND ch.event_id = e.event_id
                   AND eh.event_id = e.event_id
                   AND el.ae_header_id = eh.ae_header_id
                   AND el.accounting_class_code = 'CASH'
                   AND TRUNC (ch.accounting_date) BETWEEN TRUNC (
                                                              NVL (
                                                                  fnd_date.canonical_to_date (
                                                                      P_FROM_DATE),
                                                                  ch.accounting_date))
                                                      AND TRUNC (
                                                              NVL (
                                                                  fnd_date.canonical_to_date (
                                                                      p_as_of_date),
                                                                  ch.accounting_date))
                   AND ca.counterparty_party_id = xle.party_id(+)
                   AND l1.lookup_type = 'CASHFLOW_STATUS_CODE'
                   AND l1.lookup_code = ca.cashflow_status_code
                   AND ca.cashflow_status_code = 'CLEARED'
                   AND ch.event_id =
                       (SELECT NVL (MAX (a.event_id), -1)
                          FROM ce.ce_cashflow_acct_h a
                         WHERE     a.cashflow_id = ch.cashflow_id
                               AND TRUNC (a.accounting_date) <=
                                   TRUNC (
                                       NVL (
                                           fnd_date.canonical_to_date (
                                               p_as_of_date),
                                           a.accounting_date)))
                   AND ch.event_type =
                       DECODE (ca.source_trxn_type,
                               'BAT', 'CE_BAT_CLEARED',
                               'STMT', 'CE_STMT_RECORDED')
                   AND ch.status_code = 'ACCOUNTED'
            UNION
            SELECT 'CASHFLOW' C_CF_TYPE, ca.cashflow_id C_CF_NUMBER, ch.accounting_date C_GL_DATE,
                   ca.cashflow_date C_CF_DATE, NVL (xle.name, ca.customer_text) C_COUNTER_NAME, trxn.transaction_sub_type_name C_SUBTYPE_NAME,
                   l1.meaning C_CF_STATUS, ca.cashflow_currency_code C_CF_CURRENCY, ca.cashflow_amount C_CF_AMOUNT,
                   DECODE (ca.cashflow_direction,  'RECEIPT', (-1),  'PAYMENT', (1)) * NVL (ch.cleared_amount, ca.cashflow_amount) C_ACCOUNT_AMOUNT, TRUNC (ca.cashflow_date), ch.accounting_date,
                   ca.cashflow_status_code, ch.event_id
              FROM ce_cashflows ca, ce_cashflow_acct_h ch, ce_trxns_subtype_codes trxn,
                   xle_firstparty_information_v xle, ce_lookups l1, ce_system_parameters SYS
             WHERE     ca.cashflow_bank_account_id = P_BANK_ACCOUNT_ID
                   AND ca.source_trxn_subtype_code_id =
                       trxn.trxn_subtype_code_id(+)
                   AND ca.CASHFLOW_LEGAL_ENTITY_ID = sys.legal_entity_id
                   AND ca.cashflow_id = ch.cashflow_id
                   AND TRUNC (ch.accounting_date) BETWEEN TRUNC (
                                                              NVL (
                                                                  fnd_date.canonical_to_date (
                                                                      P_FROM_DATE),
                                                                  ch.accounting_date))
                                                      AND TRUNC (
                                                              NVL (
                                                                  fnd_date.canonical_to_date (
                                                                      p_as_of_date),
                                                                  ch.accounting_date))
                   AND ca.counterparty_party_id = xle.party_id(+)
                   AND l1.lookup_type = 'CASHFLOW_STATUS_CODE'
                   AND l1.lookup_code = ca.cashflow_status_code
                   AND ca.cashflow_status_code = 'CREATED'
                   AND ch.event_id =
                       (SELECT NVL (MAX (a.event_id), -1)
                          FROM ce.ce_cashflow_acct_h a
                         WHERE     a.cashflow_id = ch.cashflow_id
                               AND TRUNC (a.accounting_date) <=
                                   TRUNC (
                                       NVL (
                                           fnd_date.canonical_to_date (
                                               p_as_of_date),
                                           a.accounting_date)))
                   AND ((ch.event_type = 'CE_BAT_UNCLEARED' AND ch.status_code = 'ACCOUNTED') OR (ch.event_type = 'CE_BAT_CREATED'))
                   AND EXISTS
                           (SELECT NULL
                              FROM ce_statement_lines CSL, ce_statement_headers CSH, ce_transaction_codes_v COD
                             WHERE     CSL.trx_type IN ('DEBIT', 'CREDIT', 'SWEEP_IN',
                                                        'SWEEP_OUT')
                                   AND CSL.trx_code = COD.trx_code
                                   AND COD.bank_account_id =
                                       P_BANK_ACCOUNT_ID
                                   AND COD.reconcile_flag = 'CE'
                                   --Start changes V2.0 by Deckers IT Team-- excluding Eternal Cash Statement Lines
                                   AND CSL.status != 'EXTERNAL'
                                   --End changes V2.0 by Deckers IT Team
                                   AND CSL.bank_trx_number =
                                       ca.bank_trxn_number
                                   AND CSH.statement_header_id =
                                       CSL.statement_header_id
                                   AND CSH.bank_account_id =
                                       P_BANK_ACCOUNT_ID);

        --Lines Marked As Errors
        CURSOR lines_errors_c (p_bank_account_id NUMBER, p_from_date VARCHAR2, p_as_of_date VARCHAR2)
        IS
              SELECT 'LINE_ERROR' C_LINE_TYPE, ROUND (DECODE (sl.trx_type,  'CREDIT', -sl.amount,  'MISC_CREDIT', -sl.amount,  'STOP', -sl.amount,  'DEBIT', sl.amount,  'MISC_DEBIT', sl.amount,  'NSF', sl.amount,  'REJECTED', sl.amount,  0), fc.precision) C_ERROR_AMOUNT, sh.statement_number C_ERR_STMT_NUMBER,
                     sh.statement_date C_ERR_STATEMENT_DATE, sl.trx_date C_ERR_TRANSACTION_DATE, sl.trx_type C_ERR_TRX_TYPE,
                     sl.line_number C_ERR_LINE_NUMBER, NVL (sl.currency_code, NVL (sh.currency_code, aba.currency_code)) C_ERR_CURRENCY, DECODE (NVL (sl.currency_code, NVL (sh.currency_code, aba.currency_code)), sob.currency_code, sl.amount, NVL (sl.original_amount, sl.amount)) C_ERR_TRANS_AMOUNT,
                     'ERROR' C_ERR_STATUS
                FROM ce_statement_lines sl, ce_statement_headers sh, ce_bank_accounts aba,
                     gl_sets_of_books sob, ce_system_parameters sys, fnd_currencies fc
               WHERE     sl.statement_header_id = sh.statement_header_id
                     AND sh.bank_account_id = P_BANK_ACCOUNT_ID
                     --AND     sh.statement_date BETWEEN NVL (fnd_date.canonical_to_date (P_FROM_DATE )
                     --                                        ,  sh.statement_date    )
                     --                                  AND NVL (fnd_date.canonical_to_date ( p_as_of_date), sh.statement_date)
                     AND sl.status = 'ERROR'
                     AND aba.bank_account_id = sh.bank_account_id
                     AND sob.set_of_books_id = sys.set_of_books_id
                     AND aba.currency_code = fc.currency_code
                     AND sys.legal_entity_id = aba.ACCOUNT_OWNER_ORG_ID
            ORDER BY C_ERR_STATEMENT_DATE, C_ERR_STMT_NUMBER;


        --Unreconciled Bank Statement Lines - Deposits
        CURSOR unrecon_statement_credit_c (p_bank_account_id NUMBER, p_from_date VARCHAR2, p_as_of_date VARCHAR2)
        IS
              SELECT DISTINCT csli.trx_date C_TRX_DATE, ROUND (NVL (DECODE (csli.trx_type,  'CREDIT', -1 * csra.amount,  'MISC_CREDIT', -1 * csra.amount,  'DEBIT', 1 * csra.amount,  'MISC_DEBIT', 1 * csra.amount,  'NSF', 1 * csra.amount,  csra.amount), 0), fc.precision) C_DEP_AMOUNT, csli.status C_STATUS,
                              csli.Trx_Type C_TRX_TYPE, csli.line_number C_LINE_NUMBER, csli.effective_date C_EFFECTIVE_DATE,
                              NVL (csli.bank_trx_number, '          ') C_BANK_TRX_NUMBER, --             csli.bank_trx_number C_BANK_TRX_NUMBER,
                                                                                          csh.statement_number C_STATEMENT_NUMBER, csh.statement_date C_STATEMENT_DATE,
                              trx.entity_id, --             NVL(Aph.Accounting_Date,
                                             --                 (select jel.effective_Date
                                             --                    from gl_je_lines jel
                                             --                   where JEL.JE_HEADER_ID = csra.JE_HEADER_ID
                                             --                     AND JEL.JE_LINE_NUM  = csra.REFERENCE_ID)) C_GL_DATE
                                             NVL (aeh.Accounting_Date, csh.gl_date) C_GL_DATE
                --            Aph.Accounting_Date
                FROM ce_statement_lines csli, ce_statement_headers csh, ce_bank_accounts cba,
                     ce_bank_acct_uses_all bau, fnd_currencies fc, ar_cash_receipt_history_all crh,
                     ar_cash_receipts_all cr, ce_statement_reconcils_all csra, xla_ae_headers aeh,
                     xla_ae_lines ael, xla_transaction_entities_upg trx
               WHERE     cba.bank_Account_id = csh.bank_account_id
                     AND cba.bank_account_id = bau.bank_account_id
                     AND csh.statement_header_id = csli.statement_header_id
                     --Start changes V2.0 by Deckers IT Team-- excluding Eternal Cash Statement Lines
                     AND csli.status != 'EXTERNAL'
                     --End changes V2.0 by Deckers IT Team
                     AND csra.status_flag != 'M'
                     AND csra.current_record_flag = 'Y'
                     AND cba.bank_Account_id = P_BANK_ACCOUNT_ID
                     AND csli.trx_type IN ('MISC_CREDIT', 'CREDIT')
                     AND cba.currency_code = fc.currency_code
                     --        and  not exists (select 1 from ap_payment_history_all where 1=1 and check_id = csra.reference_id)
                     --        and csh.statement_number = '170131'
                     AND crh.cash_receipt_id = trx.source_id_int_1
                     AND aeh.application_id = trx.application_id
                     AND aeh.application_id = 222
                     AND aeh.entity_id = trx.entity_id
                     AND aeh.event_type_code <> 'RECP_REVERSE'
                     AND aeh.ae_header_id = ael.ae_header_id
                     AND aeh.ledger_id = ael.ledger_id
                     AND aeh.application_id = ael.application_id
                     AND ael.accounting_class_code = 'CASH'
                     AND csra.statement_line_id = csli.statement_line_id
                     AND crh.cash_receipt_history_id = csra.reference_id
                     AND crh.cash_receipt_id = cr.cash_receipt_id
                     AND cr.cash_receipt_id = trx.source_id_int_1
                     AND cr.remit_bank_acct_use_id = bau.bank_acct_use_id
                     AND bau.org_id = cr.org_id
                     --      AND APH.transaction_type (+) = 'PAYMENT CLEARING'
                     AND TRUNC (cr.receipt_date) BETWEEN TRUNC (
                                                             NVL (
                                                                 fnd_date.canonical_to_date (
                                                                     P_FROM_DATE),
                                                                 cr.receipt_date))
                                                     AND TRUNC (
                                                             NVL (
                                                                 fnd_date.canonical_to_date (
                                                                     p_as_of_date),
                                                                 cr.receipt_date))
                     --                AND aeh.accounting_date >
                     --                       NVL ( ( ( (p_as_of_date))),
                     --                            aeh.accounting_date)
                     AND (   AEH.event_id =
                             (SELECT MAX (event_id)
                                FROM xla_events xe
                               WHERE     xe.application_id = 222 /* 14698507 - Added */
                                     AND xe.entity_id = TRX.entity_id
                                     AND xe.event_id = aeh.event_id
                                     AND xe.event_number =
                                         (SELECT MAX (event_number)
                                            FROM xla_events xe2
                                           WHERE     xe2.application_id = 222 /* 14698507 - Added */
                                                 AND xe2.entity_id =
                                                     xe.entity_id
                                                 --AND xe2.event_date <= C_AS_OF_DATE
                                                 --            AND xe2.event_date >= SYS.cashbook_begin_date
                                                 AND xe2.event_status_code =
                                                     'P'
                                                 AND xe2.event_type_code NOT IN
                                                         ('ADJ_CREATE'))) /* 8241869 */
                          OR AEH.event_id IS NULL)
            ORDER BY C_STATEMENT_NUMBER ASC;

        --Unreconciled Bank Statement Lines - Payments
        CURSOR unrecon_statement_debit_c (p_bank_account_id NUMBER, p_from_date VARCHAR2, p_as_of_date VARCHAR2)
        IS
              SELECT csl.trx_date C_TRX_DATE, ROUND (NVL (DECODE (csl.trx_type,  'CREDIT', 1 * (NVL (csl.amount, 0) - SUM (NVL (csra.amount, 0))),  'MISC_CREDIT', 1 * (NVL (csl.amount, 0) - SUM (NVL (csra.amount, 0))),  'DEBIT', -1 * (NVL (csl.amount, 0) - SUM (NVL (csra.amount, 0))),  'MISC_DEBIT', -1 * (NVL (csl.amount, 0) - SUM (NVL (csra.amount, 0))),  'NSF', -1 * (NVL (csl.amount, 0) - SUM (NVL (csra.amount, 0))),  (NVL (csl.amount, 0) - SUM (NVL (csra.amount, 0)))), 0), 2) C_PAY_AMOUNT, csl.statement_line_id,
                     --                   ael.ae_header_id,
                     csl.status C_STATUS, csl.Trx_Type C_TRX_TYPE, csl.line_number C_LINE_NUMBER,
                     csl.effective_date C_EFFECTIVE_DATE, NVL (csl.bank_trx_number, '          ') C_BANK_TRX_NUMBER, csh.statement_number C_STATEMENT_NUMBER,
                     csh.statement_date C_STATEMENT_DATE, csh.gl_date C_GL_DATE, --   trx.entity_id
                                                                                 csl.trx_code trx_code, -- Added as a part of CCR0007351
                     csl.trx_text line_desc   -- Added as a part of CCR0007351
                FROM ce_statement_reconcils_all csra, ce_statement_lines csl, ce_statement_headers csh
               WHERE     1 = 1
                     --and csl.statement_line_id = 490384
                     AND csh.bank_account_id = P_BANK_ACCOUNT_ID
                     AND csra.statement_line_id(+) = csl.statement_line_id
                     AND csra.status_flag(+) = 'M'
                     AND csra.current_record_flag(+) = 'Y'
                     --Start changes V2.0 by Deckers IT Team-- excluding External Cash Statement Lines
                     AND csl.status NOT IN ('RECONCILED', 'EXTERNAL')
                     --End changes V2.0 by Deckers IT Team
                     AND csl.statement_header_id = csh.statement_header_id
                     AND csh.statement_date BETWEEN TRUNC (
                                                        NVL (
                                                            fnd_date.canonical_to_date (
                                                                P_FROM_DATE),
                                                            csh.statement_date))
                                                AND TRUNC (
                                                        NVL (
                                                            fnd_date.canonical_to_date (
                                                                p_as_of_date),
                                                            csh.statement_date))
            GROUP BY csl.trx_type, csl.amount, csl.statement_line_id,
                     csl.status, csl.Trx_Type, csl.line_number,
                     csl.effective_date, NVL (csl.bank_trx_number, '          '), csh.statement_number,
                     csh.statement_date, csl.trx_date, csh.gl_date,
                     csl.trx_code, csl.trx_text
              HAVING NVL (csl.amount, 0) - SUM (NVL (csra.amount, 0)) <> 0;



        --Unreconciled Journal Entries with  Parental Control
        CURSOR unrecon_journal_parental_c (P_BANK_CURR_DSP VARCHAR2, P_GL_CURRENCY_CODE VARCHAR2, P_SET_OF_BOOKS_ID NUMBER, P_BANK_ACCOUNT_ID NUMBER, P_ASSET_CC_ID NUMBER, --Start changes by Deckers IT Team V2.0
                                                                                                                                                                            P_CASH_CLEAR_ID NUMBER
                                           , --End changes by Deckers IT Team V2.0
                                             p_from_date VARCHAR2, P_AS_OF_DATE VARCHAR2, p_period_name VARCHAR2)
        IS
            SELECT 'JE_LINE' C_JE_TYPE,
                   ROUND (
                       DECODE (
                           P_BANK_CURR_DSP,
                           P_GL_CURRENCY_CODE, DECODE (
                                                   NVL (jel.accounted_dr, 0),
                                                   0, NVL (-jel.accounted_cr,
                                                           0),
                                                   NVL (jel.accounted_dr, 0)),
                           DECODE (
                               P_BANK_CURR_DSP,
                               jeh.currency_code, DECODE (
                                                      jeh.je_category,
                                                      'Revaluation',   DECODE (
                                                                           NVL (
                                                                               jel.accounted_dr,
                                                                               0),
                                                                           0, NVL (
                                                                                  -jel.accounted_cr,
                                                                                  0),
                                                                           NVL (
                                                                               jel.accounted_dr,
                                                                               0))
                                                                     * NVL (
                                                                           (SELECT conversion_rate
                                                                              FROM apps.gl_daily_rates
                                                                             WHERE     conversion_type =
                                                                                       'Corporate'
                                                                                   AND from_currency =
                                                                                       jeh.currency_code
                                                                                   AND to_currency =
                                                                                       P_BANK_CURR_DSP
                                                                                   AND conversion_date =
                                                                                       TRUNC (
                                                                                           NVL (
                                                                                               jeh.CURRENCY_CONVERSION_DATE,
                                                                                               jeh.default_effective_date))),
                                                                           1),
                                                      DECODE (
                                                          NVL (
                                                              jel.entered_dr,
                                                              0),
                                                          0, NVL (
                                                                 -jel.entered_cr,
                                                                 0),
                                                          NVL (
                                                              jel.entered_dr,
                                                              0))),
                               DECODE (
                                   jeh.je_category,
                                   'Revaluation',   DECODE (
                                                        NVL (
                                                            jel.accounted_dr,
                                                            0),
                                                        0, NVL (
                                                               -jel.accounted_cr,
                                                               0),
                                                        NVL (
                                                            jel.accounted_dr,
                                                            0))
                                                  * NVL (
                                                        (SELECT conversion_rate
                                                           FROM apps.gl_daily_rates
                                                          WHERE     conversion_type =
                                                                    'Corporate'
                                                                AND from_currency =
                                                                    jeh.currency_code
                                                                AND to_currency =
                                                                    P_BANK_CURR_DSP
                                                                AND conversion_date =
                                                                    TRUNC (
                                                                        NVL (
                                                                            jeh.CURRENCY_CONVERSION_DATE,
                                                                            jeh.default_effective_date))),
                                                        1),
                                     DECODE (NVL (jel.entered_dr, 0),
                                             0, NVL (-jel.entered_cr, 0),
                                             NVL (jel.entered_dr, 0))
                                   * NVL (
                                         (SELECT conversion_rate
                                            FROM apps.gl_daily_rates
                                           WHERE     conversion_type =
                                                     'Corporate'
                                                 AND from_currency =
                                                     jeh.currency_code
                                                 AND to_currency =
                                                     P_BANK_CURR_DSP
                                                 AND conversion_date =
                                                     TRUNC (
                                                         NVL (
                                                             jeh.CURRENCY_CONVERSION_DATE,
                                                             jeh.default_effective_date))),
                                         1)))),
                       fc.precision) C_JE_AMOUNT_PAR,
                   jeh.name C_JE_JOURNAL_ENTRY_NAME,
                   jel.effective_date C_JE_EFFECTIVE_DATE,
                   jeh.posted_date C_JE_POSTED_DATE,
                   cel.meaning C_JE_LINE_TYPE,
                   jel.je_line_num C_JE_LINE_NUMBER,
                   jeh.currency_code C_JE_CURRENCY,
                   DECODE (NVL (jel.entered_dr, 0),
                           0, jel.entered_cr,
                           jel.entered_dr) C_JE_TRANS_AMOUNT,
                   gll.meaning C_JE_STATUS
              FROM gl_je_lines jel, gl_je_headers jeh, ce_lookups cel,
                   gl_lookups gll, ce_bank_accounts aba, gl_sets_of_books sob,
                   fnd_currencies fc, gl_periods gp
             WHERE     jel.LEDGER_ID = TO_NUMBER (P_SET_OF_BOOKS_ID)
                   --Start changes by Deckers IT Team V2.0
                   --                AND jel.code_combination_id = aba.asset_code_combination_id
                   AND (jel.code_combination_id = aba.asset_code_combination_id OR jel.code_combination_id = aba.CASH_CLEARING_CCID)
                   AND aba.bank_account_id = P_BANK_ACCOUNT_ID
                   AND sob.set_of_books_id = TO_NUMBER (P_SET_OF_BOOKS_ID)
                   AND aba.currency_code = fc.currency_code
                   AND DECODE (aba.currency_code,
                               sob.currency_code, jeh.currency_code,
                               aba.currency_code) =
                       jeh.currency_code
                   AND jel.status = 'P'
                   AND gp.period_name = p_period_name
                   --                AND jel.code_combination_id = TO_NUMBER (P_ASSET_CC_ID)
                   AND jel.code_combination_id IN
                           (TO_NUMBER (P_ASSET_CC_ID), TO_NUMBER (P_CASH_CLEAR_ID))
                   --Start changes by Deckers IT Team V2.0
                   --                AND gp.period_name = jeh.Accrual_Rev_Period_Name
                   AND gp.period_name =
                       NVL (jeh.Accrual_Rev_Period_Name, gp.period_name) -- added as a part of CCR0007351
                   --End changes by Deckers IT Team V2.0
                   AND TRUNC (gp.start_Date) >=
                       TRUNC (
                           NVL (fnd_date.canonical_to_date (P_FROM_DATE),
                                gp.start_Date))
                   AND TRUNC (gp.end_Date) <=
                       TRUNC (
                           NVL (fnd_date.canonical_to_date (p_as_of_date),
                                gp.end_Date))
                   AND TRUNC (jel.effective_date) BETWEEN TRUNC (
                                                              NVL (
                                                                    fnd_date.canonical_to_date (
                                                                        p_from_date)
                                                                  - 1,
                                                                  jel.effective_date))
                                                      AND TRUNC (
                                                              NVL (
                                                                    fnd_date.canonical_to_date (
                                                                        P_AS_OF_DATE)
                                                                  - 1,
                                                                  jel.effective_date))
                   AND jeh.je_header_id = jel.je_header_id
                   AND jeh.je_source NOT IN ('Payables', 'Receivables', 'AP Translator',
                                             'AR Translator', 'Treasury', 'Cash Management',
                                             'Consolidation', 'Payroll')
                   AND ((pv_include_reval = 'Y' AND 1 = 1) OR (pv_include_reval = 'N' AND jeh.je_category != 'Revaluation'))
                   AND (   (    pv_exld_prev_reval = 'Y'
                            AND NOT EXISTS
                                    (SELECT 1
                                       FROM gl_je_headers jeh11
                                      WHERE     1 = 1
                                            AND jeh.reversed_je_header_id =
                                                jeh11.je_header_id --is not null
                                            --                                        AND jeh.parent_je_header_id = a.je_header_id
                                            AND jeh11.je_category =
                                                'Revaluation'
                                            AND jeh.je_category =
                                                'Revaluation'
                                            AND jeh.period_name <>
                                                jeh11.period_name))
                        OR (pv_exld_prev_reval = 'N' AND 1 = 1))
                   AND cel.lookup_type = 'TRX_TYPE'
                   AND cel.lookup_code =
                       DECODE (NVL (jel.entered_dr, 0),
                               0, 'JE_CREDIT',
                               'JE_DEBIT')
                   AND gll.lookup_type = 'MJE_BATCH_STATUS'
                   AND gll.lookup_code = jel.status
                   AND jeh.actual_flag = 'A'
                   --start changes on 10/17/2017 by Deckers IT Team
                   --                AND jeh.accrual_rev_je_header_id IS NOT NULL       -- Parental
                   AND (    jeh.accrual_rev_je_header_id IS NOT NULL -- Parental
                        AND EXISTS
                                (SELECT 1
                                   FROM gl_je_headers gjh1
                                  WHERE     1 = 1
                                        AND gjh1.je_header_id =
                                            jeh.ACCRUAL_REV_JE_HEADER_ID
                                        AND gjh1.default_effective_date <
                                            TRUNC (
                                                NVL (
                                                    fnd_date.canonical_to_date (
                                                        p_from_date),
                                                    jeh.default_effective_date))))
                   --End changes on 10/17/2017 by Deckers IT Team
                   AND NOT EXISTS
                           (SELECT NULL
                              FROM ce_statement_reconcils_all sr, ce_statement_lines sl, ce_statement_headers sh
                             WHERE     sr.reference_id = jel.je_line_num
                                   AND sr.reference_type = 'JE_LINE'
                                   AND sr.je_header_id = jel.je_header_id
                                   --Start changes V2.0 by Deckers IT Team-- excluding Eternal Cash Statement Lines
                                   AND (sr.status_flag = 'M' OR sl.status = 'EXTERNAL')
                                   AND sr.current_record_flag = 'Y'
                                   --End changes V2.0 by Deckers IT Team
                                   AND sl.statement_line_id =
                                       sr.statement_line_id
                                   AND sl.statement_header_id =
                                       sh.statement_header_id
                                   AND TRUNC (sh.statement_date) BETWEEN TRUNC (
                                                                             NVL (
                                                                                 fnd_date.canonical_to_date (
                                                                                     p_from_date),
                                                                                 sh.statement_date))
                                                                     AND TRUNC (
                                                                             NVL (
                                                                                 fnd_date.canonical_to_date (
                                                                                     P_AS_OF_DATE),
                                                                                 sh.statement_date)))
            UNION ALL              --credit je only, je with both dr/cr amount
            SELECT 'JE_LINE' C_JE_TYPE,
                   --                ROUND (
                   --                   DECODE (P_BANK_CURR_DSP,
                   --                           P_GL_CURRENCY_CODE, NVL (-jel.accounted_cr, 0),
                   --                           NVL (-jel.entered_cr, 0)),
                   --                   fc.precision)
                   ROUND (
                       DECODE (
                           P_BANK_CURR_DSP,
                           P_GL_CURRENCY_CODE, DECODE (
                                                   NVL (jel.accounted_dr, 0),
                                                   0, NVL (-jel.accounted_cr,
                                                           0),
                                                   NVL (jel.accounted_dr, 0)),
                           DECODE (
                               P_BANK_CURR_DSP,
                               jeh.currency_code, DECODE (
                                                      jeh.je_category,
                                                      'Revaluation',   DECODE (
                                                                           NVL (
                                                                               jel.accounted_dr,
                                                                               0),
                                                                           0, NVL (
                                                                                  -jel.accounted_cr,
                                                                                  0),
                                                                           NVL (
                                                                               jel.accounted_dr,
                                                                               0))
                                                                     * NVL (
                                                                           (SELECT conversion_rate
                                                                              FROM apps.gl_daily_rates
                                                                             WHERE     conversion_type =
                                                                                       'Corporate'
                                                                                   AND from_currency =
                                                                                       jeh.currency_code
                                                                                   AND to_currency =
                                                                                       P_BANK_CURR_DSP
                                                                                   AND conversion_date =
                                                                                       TRUNC (
                                                                                           NVL (
                                                                                               jeh.CURRENCY_CONVERSION_DATE,
                                                                                               jeh.default_effective_date))),
                                                                           1),
                                                      DECODE (
                                                          NVL (
                                                              jel.entered_dr,
                                                              0),
                                                          0, NVL (
                                                                 -jel.entered_cr,
                                                                 0),
                                                          NVL (
                                                              jel.entered_dr,
                                                              0))),
                               DECODE (
                                   jeh.je_category,
                                   'Revaluation',   DECODE (
                                                        NVL (
                                                            jel.accounted_dr,
                                                            0),
                                                        0, NVL (
                                                               -jel.accounted_cr,
                                                               0),
                                                        NVL (
                                                            jel.accounted_dr,
                                                            0))
                                                  * NVL (
                                                        (SELECT conversion_rate
                                                           FROM apps.gl_daily_rates
                                                          WHERE     conversion_type =
                                                                    'Corporate'
                                                                AND from_currency =
                                                                    jeh.currency_code
                                                                AND to_currency =
                                                                    P_BANK_CURR_DSP
                                                                AND conversion_date =
                                                                    TRUNC (
                                                                        NVL (
                                                                            jeh.CURRENCY_CONVERSION_DATE,
                                                                            jeh.default_effective_date))),
                                                        1),
                                     DECODE (NVL (jel.entered_dr, 0),
                                             0, NVL (-jel.entered_cr, 0),
                                             NVL (jel.entered_dr, 0))
                                   * NVL (
                                         (SELECT conversion_rate
                                            FROM apps.gl_daily_rates
                                           WHERE     conversion_type =
                                                     'Corporate'
                                                 AND from_currency =
                                                     jeh.currency_code
                                                 AND to_currency =
                                                     P_BANK_CURR_DSP
                                                 AND conversion_date =
                                                     TRUNC (
                                                         NVL (
                                                             jeh.CURRENCY_CONVERSION_DATE,
                                                             jeh.default_effective_date))),
                                         1)))),
                       fc.precision) C_JE_AMOUNT_PAR,
                   jeh.name C_JE_JOURNAL_ENTRY_NAME,
                   jel.effective_date C_JE_EFFECTIVE_DATE,
                   jeh.posted_date C_JE_POSTED_DATE,
                   cel.meaning C_JE_LINE_TYPE,
                   jel.je_line_num C_JE_LINE_NUMBER,
                   jeh.currency_code C_JE_CURRENCY,
                   jel.entered_cr C_JE_TRANS_AMOUNT,
                   gll.meaning C_JE_STATUS
              FROM gl_je_lines jel, gl_je_headers jeh, ce_lookups cel,
                   gl_lookups gll, ce_bank_accounts aba, gl_sets_of_books sob,
                   fnd_currencies fc, gl_periods gp
             WHERE     jel.LEDGER_ID = TO_NUMBER (P_SET_OF_BOOKS_ID)
                   --Start changes by Deckers IT Team V2.0
                   --                AND jel.code_combination_id = aba.asset_code_combination_id
                   AND (jel.code_combination_id = aba.asset_code_combination_id OR jel.code_combination_id = aba.CASH_CLEARING_CCID)
                   AND aba.bank_account_id = P_BANK_ACCOUNT_ID
                   AND sob.set_of_books_id = TO_NUMBER (P_SET_OF_BOOKS_ID)
                   AND DECODE (aba.currency_code,
                               sob.currency_code, jeh.currency_code,
                               aba.currency_code) =
                       jeh.currency_code
                   AND jel.status = 'P'
                   AND aba.currency_code = fc.currency_code
                   --                AND jel.code_combination_id = TO_NUMBER (P_ASSET_CC_ID)
                   AND jel.code_combination_id IN
                           (TO_NUMBER (P_ASSET_CC_ID), TO_NUMBER (P_CASH_CLEAR_ID))
                   --End changes by Deckers IT Team V2.0
                   -- AND gp.period_name = jeh.Accrual_Rev_Period_Name
                   AND gp.period_name =
                       NVL (jeh.Accrual_Rev_Period_Name, gp.period_name) -- added as a part of CCR0007351
                   --AND gp.period_name = p_period_name              -- Commented as part of CCR0007351
                   AND gp.period_name = p_period_name
                   AND TRUNC (gp.start_Date) >=
                       TRUNC (
                           NVL (fnd_date.canonical_to_date (P_FROM_DATE),
                                gp.start_Date))
                   AND TRUNC (gp.end_Date) <=
                       TRUNC (
                           NVL (fnd_date.canonical_to_date (p_as_of_date),
                                gp.end_Date))
                   AND TRUNC (jel.effective_date) BETWEEN TRUNC (
                                                              NVL (
                                                                    fnd_date.canonical_to_date (
                                                                        p_from_date)
                                                                  - 1,
                                                                  jel.effective_date))
                                                      AND TRUNC (
                                                              NVL (
                                                                    fnd_date.canonical_to_date (
                                                                        P_AS_OF_DATE)
                                                                  - 1,
                                                                  jel.effective_date))
                   AND NVL (jel.entered_dr, 0) <> 0
                   AND NVL (jel.entered_cr, 0) <> 0
                   AND jeh.je_header_id = jel.je_header_id
                   AND jeh.je_source NOT IN ('Payables', 'Receivables', 'AP Translator',
                                             'AR Translator', 'Treasury', 'Cash Management',
                                             'Consolidation', 'Payroll')
                   AND ((pv_include_reval = 'Y' AND 1 = 1) OR (pv_include_reval = 'N' AND jeh.je_category != 'Revaluation'))
                   AND (   (    pv_exld_prev_reval = 'Y'
                            AND NOT EXISTS
                                    (SELECT 1
                                       FROM gl_je_headers jeh11
                                      WHERE     1 = 1
                                            AND jeh.reversed_je_header_id =
                                                jeh11.je_header_id --is not null
                                            --                                        AND jeh.parent_je_header_id = a.je_header_id
                                            AND jeh11.je_category =
                                                'Revaluation'
                                            AND jeh.je_category =
                                                'Revaluation'
                                            AND jeh.period_name <>
                                                jeh11.period_name))
                        OR (pv_exld_prev_reval = 'N' AND 1 = 1))
                   AND cel.lookup_type = 'TRX_TYPE'
                   AND cel.lookup_code = 'JE_CREDIT'
                   AND gll.lookup_type = 'MJE_BATCH_STATUS'
                   AND gll.lookup_code = jel.status
                   AND jeh.actual_flag = 'A'
                   --start changes on 10/17/2017 by Deckers IT Team
                   --                AND jeh.accrual_rev_je_header_id IS NOT NULL       -- Parental
                   AND (    jeh.accrual_rev_je_header_id IS NOT NULL -- Parental
                        AND EXISTS
                                (SELECT 1
                                   FROM gl_je_headers gjh1
                                  WHERE     1 = 1
                                        AND gjh1.je_header_id =
                                            jeh.ACCRUAL_REV_JE_HEADER_ID
                                        AND gjh1.default_effective_date <
                                            TRUNC (
                                                NVL (
                                                    fnd_date.canonical_to_date (
                                                        p_from_date),
                                                    jeh.default_effective_date))))
                   --End changes on 10/17/2017 by Deckers IT Team
                   AND NOT EXISTS
                           (SELECT NULL
                              FROM ce_statement_reconcils_all sr, ce_statement_lines sl, ce_statement_headers sh
                             WHERE     sr.reference_id = jel.je_line_num
                                   AND sr.reference_type = 'JE_LINE'
                                   AND sr.je_header_id = jel.je_header_id
                                   --Start changes V2.0 by Deckers IT Team-- excluding Eternal Cash Statement Lines
                                   AND (sr.status_flag = 'M' OR sl.status = 'EXTERNAL')
                                   AND sr.current_record_flag = 'Y'
                                   --End changes V2.0 by Deckers IT Team
                                   AND sl.statement_line_id =
                                       sr.statement_line_id
                                   AND sl.statement_header_id =
                                       sh.statement_header_id
                                   AND TRUNC (sh.statement_date) BETWEEN TRUNC (
                                                                             NVL (
                                                                                 fnd_date.canonical_to_date (
                                                                                     p_from_date),
                                                                                 sh.statement_date))
                                                                     AND TRUNC (
                                                                             NVL (
                                                                                 fnd_date.canonical_to_date (
                                                                                     P_AS_OF_DATE),
                                                                                 sh.statement_date)))
            ORDER BY C_JE_EFFECTIVE_DATE, C_JE_JOURNAL_ENTRY_NAME;



        --Unreconciled Journal Entries with no Parental Control
        CURSOR unrecon_journal_no_parental_c (P_BANK_CURR_DSP VARCHAR2, P_GL_CURRENCY_CODE VARCHAR2, P_SET_OF_BOOKS_ID NUMBER, P_BANK_ACCOUNT_ID NUMBER, P_ASSET_CC_ID NUMBER, --Start changes by Deckers IT Team V2.0
                                                                                                                                                                               P_CASH_CLEAR_ID NUMBER
                                              , --End changes by Deckers IT Team V2.0
                                                p_from_date VARCHAR2, P_AS_OF_DATE VARCHAR2, P_period_name VARCHAR2)
        IS
            SELECT 'JE_LINE' C_JE_TYPE,
                   --                ROUND (
                   --                   DECODE (
                   --                      P_BANK_CURR_DSP,
                   --                      P_GL_CURRENCY_CODE, DECODE (
                   --                                             NVL (jel.accounted_dr, 0),
                   --                                             0, NVL (-jel.accounted_cr, 0),
                   --                                             NVL (jel.accounted_dr, 0)),
                   --                      DECODE (NVL (jel.entered_dr, 0),
                   --                              0, NVL (-jel.entered_cr, 0),
                   --                              NVL (jel.entered_dr, 0))),
                   --                   fc.precision)
                   ROUND (
                       DECODE (
                           P_BANK_CURR_DSP,
                           P_GL_CURRENCY_CODE, DECODE (
                                                   NVL (jel.accounted_dr, 0),
                                                   0, NVL (-jel.accounted_cr,
                                                           0),
                                                   NVL (jel.accounted_dr, 0)),
                           DECODE (
                               P_BANK_CURR_DSP,
                               jeh.currency_code, DECODE (
                                                      jeh.je_category,
                                                      'Revaluation',   DECODE (
                                                                           NVL (
                                                                               jel.accounted_dr,
                                                                               0),
                                                                           0, NVL (
                                                                                  -jel.accounted_cr,
                                                                                  0),
                                                                           NVL (
                                                                               jel.accounted_dr,
                                                                               0))
                                                                     * NVL (
                                                                           (SELECT conversion_rate
                                                                              FROM apps.gl_daily_rates
                                                                             WHERE     conversion_type =
                                                                                       'Corporate'
                                                                                   AND from_currency =
                                                                                       jeh.currency_code
                                                                                   AND to_currency =
                                                                                       P_BANK_CURR_DSP
                                                                                   AND conversion_date =
                                                                                       TRUNC (
                                                                                           NVL (
                                                                                               jeh.CURRENCY_CONVERSION_DATE,
                                                                                               jeh.default_effective_date))),
                                                                           1),
                                                      DECODE (
                                                          NVL (
                                                              jel.entered_dr,
                                                              0),
                                                          0, NVL (
                                                                 -jel.entered_cr,
                                                                 0),
                                                          NVL (
                                                              jel.entered_dr,
                                                              0))),
                               DECODE (
                                   jeh.je_category,
                                   'Revaluation',   DECODE (
                                                        NVL (
                                                            jel.accounted_dr,
                                                            0),
                                                        0, NVL (
                                                               -jel.accounted_cr,
                                                               0),
                                                        NVL (
                                                            jel.accounted_dr,
                                                            0))
                                                  * NVL (
                                                        (SELECT conversion_rate
                                                           FROM apps.gl_daily_rates
                                                          WHERE     conversion_type =
                                                                    'Corporate'
                                                                AND from_currency =
                                                                    jeh.currency_code
                                                                AND to_currency =
                                                                    P_BANK_CURR_DSP
                                                                AND conversion_date =
                                                                    TRUNC (
                                                                        NVL (
                                                                            jeh.CURRENCY_CONVERSION_DATE,
                                                                            jeh.default_effective_date))),
                                                        1),
                                     DECODE (NVL (jel.entered_dr, 0),
                                             0, NVL (-jel.entered_cr, 0),
                                             NVL (jel.entered_dr, 0))
                                   * NVL (
                                         (SELECT conversion_rate
                                            FROM apps.gl_daily_rates
                                           WHERE     conversion_type =
                                                     'Corporate'
                                                 AND from_currency =
                                                     jeh.currency_code
                                                 AND to_currency =
                                                     P_BANK_CURR_DSP
                                                 AND conversion_date =
                                                     TRUNC (
                                                         NVL (
                                                             jeh.CURRENCY_CONVERSION_DATE,
                                                             jeh.default_effective_date))),
                                         1)))),
                       fc.precision) C_JE_AMOUNT_NO_PAR,
                   jeh.name C_JE_JOURNAL_ENTRY_NAME,
                   jel.effective_date C_JE_EFFECTIVE_DATE,
                   jeh.posted_date C_JE_POSTED_DATE,
                   cel.meaning C_JE_LINE_TYPE,
                   jel.je_line_num C_JE_LINE_NUMBER,
                   jeh.currency_code C_JE_CURRENCY,
                   DECODE (NVL (jel.entered_dr, 0),
                           0, jel.entered_cr,
                           jel.entered_dr) C_JE_TRANS_AMOUNT,
                   gll.meaning C_JE_STATUS
              FROM gl_je_lines jel, gl_je_headers jeh, ce_lookups cel,
                   gl_lookups gll, ce_bank_accounts aba, gl_sets_of_books sob,
                   fnd_currencies fc
             WHERE     jel.LEDGER_ID = TO_NUMBER (P_SET_OF_BOOKS_ID)
                   --Start changes by Deckers IT Team V2.0
                   --                AND jel.code_combination_id = aba.asset_code_combination_id
                   AND (jel.code_combination_id = aba.asset_code_combination_id OR jel.code_combination_id = aba.CASH_CLEARING_CCID)
                   AND aba.bank_account_id = P_BANK_ACCOUNT_ID
                   AND sob.set_of_books_id = TO_NUMBER (P_SET_OF_BOOKS_ID)
                   AND DECODE (aba.currency_code,
                               sob.currency_code, jeh.currency_code,
                               aba.currency_code) =
                       jeh.currency_code
                   AND jel.status = 'P'
                   AND aba.currency_code = fc.currency_code
                   AND jel.period_name = p_period_name
                   --                AND jel.code_combination_id = TO_NUMBER (P_ASSET_CC_ID)
                   AND jel.code_combination_id IN
                           (TO_NUMBER (P_ASSET_CC_ID), TO_NUMBER (P_CASH_CLEAR_ID))
                   --End changes by Deckers IT Team V2.0
                   AND TRUNC (jel.effective_date) BETWEEN TRUNC (
                                                              NVL (
                                                                  fnd_date.canonical_to_date (
                                                                      p_from_date),
                                                                  jel.effective_date))
                                                      AND TRUNC (
                                                              NVL (
                                                                  fnd_date.canonical_to_date (
                                                                      P_AS_OF_DATE),
                                                                  jel.effective_date))
                   AND jeh.je_header_id = jel.je_header_id
                   AND jeh.je_source NOT IN ('Payables', 'Receivables', 'AP Translator',
                                             'AR Translator', 'Treasury', 'Cash Management',
                                             'Consolidation', 'Payroll')
                   AND ((pv_include_reval = 'Y' AND 1 = 1) OR (pv_include_reval = 'N' AND jeh.je_category != 'Revaluation'))
                   AND (   (    pv_exld_prev_reval = 'Y'
                            AND NOT EXISTS
                                    (SELECT 1
                                       FROM gl_je_headers jeh11
                                      WHERE     1 = 1
                                            AND jeh.reversed_je_header_id =
                                                jeh11.je_header_id --is not null
                                            --                                        AND jeh.parent_je_header_id = a.je_header_id
                                            AND jeh11.je_category =
                                                'Revaluation'
                                            AND jeh.je_category =
                                                'Revaluation'
                                            AND jeh.period_name <>
                                                jeh11.period_name))
                        OR (pv_exld_prev_reval = 'N' AND 1 = 1))
                   AND cel.lookup_type = 'TRX_TYPE'
                   AND cel.lookup_code =
                       DECODE (NVL (jel.entered_dr, 0),
                               0, 'JE_CREDIT',
                               'JE_DEBIT')
                   AND gll.lookup_type = 'MJE_BATCH_STATUS'
                   AND gll.lookup_code = jel.status
                   AND jeh.actual_flag = 'A'
                   --start changes on 10/17/2017 by Deckers IT Team
                   --                AND jeh.accrual_rev_je_header_id IS NULL        -- No Parental
                   AND (   jeh.accrual_rev_je_header_id IS NULL -- No Parental
                        OR NOT EXISTS
                               (SELECT 1
                                  FROM gl_je_headers gjh1
                                 WHERE     1 = 1
                                       AND gjh1.je_header_id =
                                           jeh.ACCRUAL_REV_JE_HEADER_ID
                                       AND gjh1.default_effective_date <
                                           TRUNC (
                                               NVL (
                                                   fnd_date.canonical_to_date (
                                                       p_from_date),
                                                   jeh.default_effective_date))))
                   --End changes on 10/17/2017 by Deckers IT Team
                   AND NOT EXISTS
                           (SELECT NULL
                              FROM ce_statement_reconcils_all sr, ce_statement_lines sl, ce_statement_headers sh
                             WHERE     sr.reference_id = jel.je_line_num
                                   AND sr.reference_type = 'JE_LINE'
                                   AND sr.je_header_id = jel.je_header_id
                                   --Start changes V2.0 by Deckers IT Team-- excluding Eternal Cash Statement Lines
                                   AND (sr.status_flag = 'M' OR sl.status = 'EXTERNAL')
                                   AND sr.current_record_flag = 'Y'
                                   --End changes V2.0 by Deckers IT Team
                                   AND sl.statement_line_id =
                                       sr.statement_line_id
                                   AND sl.statement_header_id =
                                       sh.statement_header_id
                                   AND TRUNC (sh.statement_date) BETWEEN TRUNC (
                                                                             NVL (
                                                                                 fnd_date.canonical_to_date (
                                                                                     p_from_date),
                                                                                 sh.statement_date))
                                                                     AND TRUNC (
                                                                             NVL (
                                                                                 fnd_date.canonical_to_date (
                                                                                     P_AS_OF_DATE),
                                                                                 sh.statement_date)))
            UNION ALL              --credit je only, je with both dr/cr amount
            SELECT 'JE_LINE' C_JE_TYPE,
                   --                ROUND (
                   --                   DECODE (P_BANK_CURR_DSP,
                   --                           P_GL_CURRENCY_CODE, NVL (-jel.accounted_cr, 0),
                   --                           NVL (-jel.entered_cr, 0)),
                   --                   fc.precision)
                   ROUND (
                       DECODE (
                           P_BANK_CURR_DSP,
                           P_GL_CURRENCY_CODE, DECODE (
                                                   NVL (jel.accounted_dr, 0),
                                                   0, NVL (-jel.accounted_cr,
                                                           0),
                                                   NVL (jel.accounted_dr, 0)),
                           DECODE (
                               P_BANK_CURR_DSP,
                               jeh.currency_code, DECODE (
                                                      jeh.je_category,
                                                      'Revaluation',   DECODE (
                                                                           NVL (
                                                                               jel.accounted_dr,
                                                                               0),
                                                                           0, NVL (
                                                                                  -jel.accounted_cr,
                                                                                  0),
                                                                           NVL (
                                                                               jel.accounted_dr,
                                                                               0))
                                                                     * NVL (
                                                                           (SELECT conversion_rate
                                                                              FROM apps.gl_daily_rates
                                                                             WHERE     conversion_type =
                                                                                       'Corporate'
                                                                                   AND from_currency =
                                                                                       jeh.currency_code
                                                                                   AND to_currency =
                                                                                       P_BANK_CURR_DSP
                                                                                   AND conversion_date =
                                                                                       TRUNC (
                                                                                           NVL (
                                                                                               jeh.CURRENCY_CONVERSION_DATE,
                                                                                               jeh.default_effective_date))),
                                                                           1),
                                                      DECODE (
                                                          NVL (
                                                              jel.entered_dr,
                                                              0),
                                                          0, NVL (
                                                                 -jel.entered_cr,
                                                                 0),
                                                          NVL (
                                                              jel.entered_dr,
                                                              0))),
                               DECODE (
                                   jeh.je_category,
                                   'Revaluation',   DECODE (
                                                        NVL (
                                                            jel.accounted_dr,
                                                            0),
                                                        0, NVL (
                                                               -jel.accounted_cr,
                                                               0),
                                                        NVL (
                                                            jel.accounted_dr,
                                                            0))
                                                  * NVL (
                                                        (SELECT conversion_rate
                                                           FROM apps.gl_daily_rates
                                                          WHERE     conversion_type =
                                                                    'Corporate'
                                                                AND from_currency =
                                                                    jeh.currency_code
                                                                AND to_currency =
                                                                    P_BANK_CURR_DSP
                                                                AND conversion_date =
                                                                    TRUNC (
                                                                        NVL (
                                                                            jeh.CURRENCY_CONVERSION_DATE,
                                                                            jeh.default_effective_date))),
                                                        1),
                                     DECODE (NVL (jel.entered_dr, 0),
                                             0, NVL (-jel.entered_cr, 0),
                                             NVL (jel.entered_dr, 0))
                                   * NVL (
                                         (SELECT conversion_rate
                                            FROM apps.gl_daily_rates
                                           WHERE     conversion_type =
                                                     'Corporate'
                                                 AND from_currency =
                                                     jeh.currency_code
                                                 AND to_currency =
                                                     P_BANK_CURR_DSP
                                                 AND conversion_date =
                                                     TRUNC (
                                                         NVL (
                                                             jeh.CURRENCY_CONVERSION_DATE,
                                                             jeh.default_effective_date))),
                                         1)))),
                       fc.precision) C_JE_AMOUNT_NO_PAR,
                   jeh.name C_JE_JOURNAL_ENTRY_NAME,
                   jel.effective_date C_JE_EFFECTIVE_DATE,
                   jeh.posted_date C_JE_POSTED_DATE,
                   cel.meaning C_JE_LINE_TYPE,
                   jel.je_line_num C_JE_LINE_NUMBER,
                   jeh.currency_code C_JE_CURRENCY,
                   jel.entered_cr C_JE_TRANS_AMOUNT,
                   gll.meaning C_JE_STATUS
              FROM gl_je_lines jel, gl_je_headers jeh, ce_lookups cel,
                   gl_lookups gll, ce_bank_accounts aba, gl_sets_of_books sob,
                   fnd_currencies fc
             WHERE     jel.LEDGER_ID = TO_NUMBER (P_SET_OF_BOOKS_ID)
                   --Start changes by Deckers IT Team V2.0
                   --                AND jel.code_combination_id = aba.asset_code_combination_id
                   AND (jel.code_combination_id = aba.asset_code_combination_id OR jel.code_combination_id = aba.CASH_CLEARING_CCID)
                   AND aba.bank_account_id = P_BANK_ACCOUNT_ID
                   AND sob.set_of_books_id = TO_NUMBER (P_SET_OF_BOOKS_ID)
                   AND DECODE (aba.currency_code,
                               sob.currency_code, jeh.currency_code,
                               aba.currency_code) =
                       jeh.currency_code
                   AND jel.status = 'P'
                   AND jel.period_name = p_period_name
                   --                AND jel.code_combination_id = TO_NUMBER (P_ASSET_CC_ID)
                   AND jel.code_combination_id IN
                           (TO_NUMBER (P_ASSET_CC_ID), TO_NUMBER (P_CASH_CLEAR_ID))
                   --End changes by Deckers IT Team V2.0
                   AND TRUNC (jel.effective_date) BETWEEN TRUNC (
                                                              NVL (
                                                                  fnd_date.canonical_to_date (
                                                                      p_from_date),
                                                                  jel.effective_date))
                                                      AND TRUNC (
                                                              NVL (
                                                                  fnd_date.canonical_to_date (
                                                                      P_AS_OF_DATE),
                                                                  jel.effective_date))
                   AND NVL (jel.entered_dr, 0) <> 0
                   AND NVL (jel.entered_cr, 0) <> 0
                   AND jeh.je_header_id = jel.je_header_id
                   AND jeh.je_source NOT IN ('Payables', 'Receivables', 'AP Translator',
                                             'AR Translator', 'Treasury', 'Cash Management',
                                             'Consolidation', 'Payroll')
                   AND ((pv_include_reval = 'Y' AND 1 = 1) OR (pv_include_reval = 'N' AND jeh.je_category != 'Revaluation'))
                   AND (   (    pv_exld_prev_reval = 'Y'
                            AND NOT EXISTS
                                    (SELECT 1
                                       FROM gl_je_headers jeh11
                                      WHERE     1 = 1
                                            AND jeh.reversed_je_header_id =
                                                jeh11.je_header_id --is not null
                                            --                                        AND jeh.parent_je_header_id = a.je_header_id
                                            AND jeh11.je_category =
                                                'Revaluation'
                                            AND jeh.je_category =
                                                'Revaluation'
                                            AND jeh.period_name <>
                                                jeh11.period_name))
                        OR (pv_exld_prev_reval = 'N' AND 1 = 1))
                   AND cel.lookup_type = 'TRX_TYPE'
                   AND cel.lookup_code = 'JE_CREDIT'
                   AND gll.lookup_type = 'MJE_BATCH_STATUS'
                   AND gll.lookup_code = jel.status
                   AND jeh.actual_flag = 'A'
                   AND aba.currency_code = fc.currency_code
                   --                AND jeh.accrual_rev_je_header_id IS NULL        -- No Parental
                   --start changes on 10/17/2017 by Deckers IT Team
                   --                AND jeh.accrual_rev_je_header_id IS NULL        -- No Parental
                   AND (   jeh.accrual_rev_je_header_id IS NULL -- No Parental
                        OR NOT EXISTS
                               (SELECT 1
                                  FROM gl_je_headers gjh1
                                 WHERE     1 = 1
                                       AND gjh1.je_header_id =
                                           jeh.ACCRUAL_REV_JE_HEADER_ID
                                       AND gjh1.default_effective_date <
                                           TRUNC (
                                               NVL (
                                                   fnd_date.canonical_to_date (
                                                       p_from_date),
                                                   jeh.default_effective_date))))
                   --End changes on 10/17/2017 by Deckers IT Team
                   AND NOT EXISTS
                           (SELECT NULL
                              FROM ce_statement_reconcils_all sr, ce_statement_lines sl, ce_statement_headers sh
                             WHERE     sr.reference_id = jel.je_line_num
                                   AND sr.reference_type = 'JE_LINE'
                                   --start changes by ANM on 10/18/2017
                                   AND sr.je_header_id = jel.je_header_id
                                   --End changes by ANM on 10/18/2017
                                   --Start changes V2.0 by Deckers IT Team-- excluding Eternal Cash Statement Lines
                                   AND (sr.status_flag = 'M' OR sl.status = 'EXTERNAL')
                                   AND sr.current_record_flag = 'Y'
                                   --End changes V2.0 by Deckers IT Team
                                   AND sl.statement_line_id =
                                       sr.statement_line_id
                                   AND sl.statement_header_id =
                                       sh.statement_header_id
                                   AND TRUNC (sh.statement_date) BETWEEN TRUNC (
                                                                             NVL (
                                                                                 fnd_date.canonical_to_date (
                                                                                     p_from_date),
                                                                                 sh.statement_date))
                                                                     AND TRUNC (
                                                                             NVL (
                                                                                 fnd_date.canonical_to_date (
                                                                                     P_AS_OF_DATE),
                                                                                 sh.statement_date)))
            ORDER BY C_JE_EFFECTIVE_DATE, C_JE_JOURNAL_ENTRY_NAME;

        ---- Unreconciled Payments not Voided/Cleared
        CURSOR payments_not_void_clear_c (P_BANK_CURR_DSP      VARCHAR2,
                                          P_GL_CURRENCY_CODE   VARCHAR2,
                                          P_BANK_ACCOUNT_ID    NUMBER,
                                          p_from_date          VARCHAR2,
                                          P_AS_OF_DATE         VARCHAR2)
        IS
              --Start changes by Arun N Murthy on 20 Jan 2017 -- Changed the complete query
              SELECT DISTINCT 'PAYMENT' C_AP_TYPE, C.check_id C_AP_ID, NVL (-1. * DECODE (P_BANK_CURR_DSP, P_GL_CURRENCY_CODE, NVL (NVL (C.cleared_base_amount, C.base_amount), C.amount), C.amount), 0) C_AP_AMOUNT,
                              C.vendor_name C_AP_SUPPLIER_NAME, aeh.accounting_date C_AP_GL_DATE, C.check_date C_AP_PAYMENT_DATE,
                              C.payment_method_code C_AP_PAYMENT_METHOD, C.check_number C_AP_PAYMENT_NUMBER, C.currency_code C_AP_CURRENCY,
                              C.amount C_AP_TRANS_AMOUNT, C.status_lookup_code C_AP_STATUS, FND_ACCESS_CONTROL_UTIL.get_org_name (C.org_id) C_ORG_NAME_AP
                FROM ap_checks_all C, ce_bank_acct_uses_all BAU, ce_bank_accounts BA,
                     ce_system_parameters SYS, xla_transaction_entities_upg trx, xla_ae_headers aeh,
                     xla_ae_lines ael, fnd_currencies fc
               WHERE     C.check_date BETWEEN (NVL (fnd_date.canonical_to_date (P_FROM_DATE), c.check_date))
                                          AND (NVL (fnd_date.canonical_to_date (P_AS_OF_DATE), c.check_date))
                     AND C.ce_bank_acct_use_id = BAU.bank_acct_use_id
                     AND C.org_id = BAU.org_id
                     AND TRX.application_id = 200       /* 13536461 - added */
                     AND TRX.ledger_id = SYS.set_of_books_id /* 13536461 - added */
                     AND NVL (TRX.source_id_int_1, -99) = C.check_id
                     AND TRX.entity_code = 'AP_PAYMENTS'
                     AND aeh.application_id = trx.application_id
                     AND AEH.entity_id(+) = TRX.entity_id
                     AND NVL (AEH.application_id, 200) = 200 /* 13536461 - added */
                     AND NVL (AEH.ledger_id, SYS.set_of_books_id) =
                         SYS.set_of_books_id /* 17078656 - nvl added for outer join */
                     AND NVL (AEH.event_type_code, 'X') NOT IN
                             ('PAYMENT CANCELLED', 'REFUND CANCELLED')
                     AND aeh.ae_header_id = ael.ae_header_id(+)
                     AND aeh.ledger_id = ael.ledger_id(+)
                     AND aeh.application_id = ael.application_id(+)
                     AND ael.accounting_class_code(+) = 'CASH'
                     AND BAU.bank_account_id = P_BANK_ACCOUNT_ID
                     AND BAU.bank_account_id = BA.bank_account_id
                     AND BA.account_owner_org_id = SYS.legal_entity_id
                     AND ba.currency_code = fc.currency_code
                     --AND aeh.accounting_date BETWEEN   NVL (fnd_date.canonical_to_date ( P_FROM_DATE ), aeh.accounting_date)
                     --                            AND   NVL (fnd_date.canonical_to_date ( P_AS_OF_DATE ), aeh.accounting_date)
                     --                  AND (   c.cleared_date <=
                     --                             fnd_date.canonical_to_date (P_AS_OF_DATE)
                     --                       OR c.void_date <=
                     --                             fnd_date.canonical_to_date (P_AS_OF_DATE))
                     AND NVL (c.status_lookup_code, 'ABC') NOT IN
                             ('RECONCILED', 'VOIDED')
                     AND EXISTS
                             (SELECT 1
                                FROM ap_payment_history_all H2
                               WHERE     H2.check_id = C.check_id
                                     AND H2.transaction_type LIKE
                                             DECODE (C.void_date,
                                                     NULL, H2.transaction_type,
                                                     '%CANCEL%'))
                     /* Check that payment is not reconciled */
                     AND NOT EXISTS
                             (SELECT /*+ PUSH_SUBQ NO_UNNEST */
                                     NULL
                                FROM ce_statement_reconcils_all CSR, ce_Statement_lines CSL, ce_statement_headers CSH
                               WHERE     CSR.reference_id = C.check_id
                                     AND CSR.reference_type = 'PAYMENT'
                                     --Start changes V2.0 by Deckers IT Team-- excluding Eternal Cash Statement Lines
                                     AND (csr.status_flag = 'M' OR csl.status = 'EXTERNAL')
                                     AND csr.current_record_flag = 'Y'
                                     --End changes V2.0 by Deckers IT Team
                                     AND CSR.statement_line_id =
                                         CSL.statement_line_id
                                     AND CSL.statement_header_id =
                                         CSH.statement_header_id --      AND CSH.statement_date <= NVL (fnd_date.canonical_to_date ( P_AS_OF_DATE ), CSH.statement_date)
                                     AND TRUNC (csh.statement_date) BETWEEN TRUNC (
                                                                                NVL (
                                                                                    fnd_date.canonical_to_date (
                                                                                        P_FROM_DATE),
                                                                                    csh.statement_date))
                                                                        AND TRUNC (
                                                                                NVL (
                                                                                    fnd_date.canonical_to_date (
                                                                                        P_AS_OF_DATE),
                                                                                    csh.statement_date)))
                     AND (   AEH.event_id =
                             (SELECT MAX (event_id)
                                FROM xla_events xe
                               WHERE     xe.application_id = 200 /* 14698507 - Added */
                                     AND xe.entity_id = TRX.entity_id
                                     --Added by ANM on 27 Mar 2017
                                     --                                     AND xe.event_id = aeh.event_id
                                     AND xe.event_number =
                                         (SELECT MAX (event_number)
                                            FROM xla_events xe2
                                           WHERE     xe2.application_id = 200 /* 14698507 - Added */
                                                 --AND xe2.event_id = aeh.event_id
                                                 AND xe2.entity_id =
                                                     xe.entity_id
                                                 --AND xe2.event_date <= C_AS_OF_DATE
                                                 AND TRUNC (xe2.event_date) >=
                                                     TRUNC (
                                                         SYS.cashbook_begin_date)
                                                 AND xe2.event_status_code =
                                                     'P'
                                                 AND xe2.event_type_code NOT IN
                                                         ('PAYMENT MATURITY ADJUSTED', 'MANUAL PAYMENT ADJUSTED', 'PAYMENT ADJUSTED',
                                                          'PAYMENT CLEARING ADJUSTED', 'MANUAL REFUND ADJUSTED', 'REFUND ADJUSTED'))) /* 8241869 */
                          OR AEH.event_id IS NULL)
            ORDER BY C_AP_GL_DATE NULLS FIRST;


        ---- Unreconicled Payments got Cleared in next period
        CURSOR payments_clear_c (P_BANK_CURR_DSP      VARCHAR2,
                                 P_GL_CURRENCY_CODE   VARCHAR2,
                                 P_BANK_ACCOUNT_ID    NUMBER,
                                 p_from_date          VARCHAR2,
                                 P_AS_OF_DATE         VARCHAR2)
        IS
              --Start changes by Arun N Murthy on 20 Jan 2017 -- Changed the complete query
              SELECT DISTINCT 'PAYMENT' C_AP_TYPE, C.check_id C_AP_ID, NVL (-1. * ROUND (DECODE (P_BANK_CURR_DSP, P_GL_CURRENCY_CODE, NVL (NVL (C.cleared_base_amount, C.base_amount), C.amount), C.amount), fc.precision), 0) C_AP_AMOUNT,
                              C.vendor_name C_AP_SUPPLIER_NAME, --    aeh.gl_transfer_date C_AP_GL_DATE,
                                                                aeh.accounting_date C_AP_GL_DATE, C.check_date C_AP_PAYMENT_DATE,
                              C.payment_method_code C_AP_PAYMENT_METHOD, C.check_number C_AP_PAYMENT_NUMBER, C.currency_code C_AP_CURRENCY,
                              ROUND (C.amount, fc.precision) C_AP_TRANS_AMOUNT, C.status_lookup_code C_AP_STATUS, FND_ACCESS_CONTROL_UTIL.get_org_name (C.org_id) C_ORG_NAME_AP
                FROM ap_checks_all C, ce_bank_acct_uses_all BAU, ce_bank_accounts BA,
                     ce_system_parameters SYS, -- Start changes by Arun on 01/14/2017 commented AIP and added xla tables
                                               --ap_invoice_payments_all AIP,
                                               xla_transaction_entities_upg trx, xla_ae_headers aeh,
                     xla_ae_lines ael, fnd_currencies fc
               WHERE     C.check_date BETWEEN (NVL (fnd_date.canonical_to_date (P_FROM_DATE), c.check_date))
                                          AND (NVL (fnd_date.canonical_to_date (P_AS_OF_DATE), c.check_date))
                     AND C.ce_bank_acct_use_id = BAU.bank_acct_use_id
                     AND C.org_id = BAU.org_id
                     AND TRX.application_id = 200       /* 13536461 - added */
                     AND TRX.ledger_id = SYS.set_of_books_id /* 13536461 - added */
                     AND NVL (TRX.source_id_int_1, -99) = C.check_id
                     AND TRX.entity_code = 'AP_PAYMENTS'
                     AND AEH.entity_id(+) = TRX.entity_id
                     AND NVL (AEH.application_id, 200) = 200 /* 13536461 - added */
                     AND NVL (AEH.ledger_id, SYS.set_of_books_id) =
                         SYS.set_of_books_id /* 17078656 - nvl added for outer join */
                     AND NVL (AEH.event_type_code, 'X') NOT IN
                             ('PAYMENT CANCELLED', 'REFUND CANCELLED')
                     AND BAU.bank_account_id = P_BANK_ACCOUNT_ID
                     AND BAU.bank_account_id = BA.bank_account_id
                     AND BA.account_owner_org_id = SYS.legal_entity_id
                     AND ba.currency_code = fc.currency_code
                     AND aeh.ae_header_id = ael.ae_header_id
                     AND aeh.ledger_id = ael.ledger_id
                     AND aeh.application_id = ael.application_id
                     AND ael.accounting_class_code = 'CASH'
                     AND TRUNC (aeh.accounting_date) >
                         TRUNC (
                             NVL (fnd_date.canonical_to_date (P_AS_OF_DATE),
                                  aeh.accounting_date))
                     --AND (c.cleared_date <= fnd_date.canonical_to_date ( P_AS_OF_DATE ))
                     AND EXISTS
                             (SELECT 1
                                FROM ap_payment_history_all H2
                               WHERE     H2.check_id = C.check_id
                                     AND H2.transaction_type LIKE
                                             DECODE (C.void_date,
                                                     NULL, H2.transaction_type,
                                                     '%CANCEL%'))
                     /* Check that payment is reconciled */
                     AND EXISTS
                             (SELECT NULL
                                FROM ce_statement_reconcils_all CSR, ce_Statement_lines CSL, ce_statement_headers CSH
                               WHERE     CSR.reference_id = C.check_id
                                     AND CSR.reference_type = 'PAYMENT'
                                     --Start changes V2.0 by Deckers IT Team-- excluding Eternal Cash Statement Lines
                                     AND (csr.status_flag = 'M' OR csl.status != 'EXTERNAL')
                                     AND csr.current_record_flag = 'Y'
                                     --End changes V2.0 by Deckers IT Team
                                     AND CSR.statement_line_id =
                                         CSL.statement_line_id
                                     AND CSL.statement_header_id =
                                         CSH.statement_header_id
                                     --      AND CSH.statement_date <= NVL (fnd_date.canonical_to_date ( P_AS_OF_DATE ), CSH.statement_date)
                                     AND CSH.statement_date >=
                                         TRUNC (SYS.cashbook_begin_date))
                     AND (   AEH.event_id =
                             (SELECT MAX (event_id)
                                FROM xla_events xe
                               WHERE     xe.application_id = 200 /* 14698507 - Added */
                                     AND xe.entity_id = TRX.entity_id
                                     AND xe.event_number =
                                         (SELECT MAX (event_number)
                                            FROM xla_events xe2
                                           WHERE     xe2.application_id = 200 /* 14698507 - Added */
                                                 AND xe2.entity_id =
                                                     xe.entity_id
                                                 --AND xe2.event_date <= C_AS_OF_DATE
                                                 AND xe2.event_date >=
                                                     SYS.cashbook_begin_date
                                                 AND xe2.event_status_code =
                                                     'P'
                                                 AND xe2.event_type_code NOT IN
                                                         ('PAYMENT MATURITY ADJUSTED', 'MANUAL PAYMENT ADJUSTED', 'PAYMENT ADJUSTED',
                                                          'PAYMENT CLEARING ADJUSTED', 'MANUAL REFUND ADJUSTED', 'REFUND ADJUSTED'))
                                     AND NOT EXISTS
                                             (SELECT 1
                                                FROM xla_transaction_entities_upg xte2, xla_ae_headers aeh2, xla_ae_lines ael2
                                               WHERE     xte2.application_id =
                                                         200 /* 14698507 - Added */
                                                     AND xte2.entity_id =
                                                         trx.entity_id
                                                     AND xe.application_id =
                                                         xte2.application_id
                                                     AND aeh2.ae_header_id =
                                                         ael2.ae_header_id
                                                     AND xte2.entity_id =
                                                         aeh2.entity_id
                                                     AND aeh2.ledger_id =
                                                         ael2.ledger_id
                                                     AND aeh2.application_id =
                                                         ael2.application_id
                                                     AND ael2.accounting_class_code =
                                                         'CASH'
                                                     AND TRUNC (
                                                             ael2.accounting_date) BETWEEN TRUNC (
                                                                                               NVL (
                                                                                                   fnd_date.canonical_to_date (
                                                                                                       p_from_date),
                                                                                                   ael2.accounting_date))
                                                                                       AND TRUNC (
                                                                                               NVL (
                                                                                                   fnd_date.canonical_to_date (
                                                                                                       p_as_of_date),
                                                                                                   ael2.accounting_date))
                                              HAVING SUM (
                                                           NVL (
                                                               ael2.entered_dr,
                                                               0)
                                                         - NVL (
                                                               ael2.entered_cr,
                                                               0)) <>
                                                     0))         /* 8241869 */
                          OR AEH.event_id IS NULL)
            ORDER BY C_AP_GL_DATE NULLS FIRST;


        ---- Unreconicled Payments got Voided in next period
        CURSOR payments_void_c (P_BANK_CURR_DSP      VARCHAR2,
                                P_GL_CURRENCY_CODE   VARCHAR2,
                                P_BANK_ACCOUNT_ID    NUMBER,
                                p_from_date          VARCHAR2,
                                P_AS_OF_DATE         VARCHAR2)
        IS
              SELECT DISTINCT 'PAYMENT' C_AP_TYPE, C.check_id C_AP_ID, NVL (-1. * ROUND (DECODE (P_BANK_CURR_DSP, P_GL_CURRENCY_CODE, NVL (NVL (C.cleared_base_amount, C.base_amount), C.amount), C.amount), fc.precision), 0) C_AP_AMOUNT,
                              C.vendor_name C_AP_SUPPLIER_NAME, aeh.accounting_date C_AP_GL_DATE, C.check_date C_AP_PAYMENT_DATE,
                              C.payment_method_code C_AP_PAYMENT_METHOD, C.check_number C_AP_PAYMENT_NUMBER, C.currency_code C_AP_CURRENCY,
                              ROUND (C.amount, fc.precision) C_AP_TRANS_AMOUNT, C.status_lookup_code C_AP_STATUS, FND_ACCESS_CONTROL_UTIL.get_org_name (C.org_id) C_ORG_NAME_AP,
                              c.cleared_date
                FROM ap_checks_all C, ce_bank_acct_uses_all BAU, ce_bank_accounts BA,
                     ce_system_parameters SYS, -- Start changes by Arun on 01/14/2017 commented AIP and added xla tables
                                               --ap_invoice_payments_all AIP,
                                               xla_transaction_entities_upg trx, xla_ae_headers aeh,
                     fnd_currencies fc
               WHERE     C.check_date BETWEEN (NVL (fnd_date.canonical_to_date (P_FROM_DATE), c.check_date))
                                          AND (NVL (fnd_date.canonical_to_date (P_AS_OF_DATE), c.check_date))
                     AND C.ce_bank_acct_use_id = BAU.bank_acct_use_id
                     AND C.org_id = BAU.org_id
                     AND TRX.application_id = 200       /* 13536461 - added */
                     AND TRX.ledger_id = SYS.set_of_books_id /* 13536461 - added */
                     AND NVL (TRX.source_id_int_1, -99) = C.check_id
                     AND TRX.entity_code = 'AP_PAYMENTS'
                     AND AEH.entity_id(+) = TRX.entity_id
                     AND NVL (AEH.application_id, 200) = 200 /* 13536461 - added */
                     AND NVL (AEH.ledger_id, SYS.set_of_books_id) =
                         SYS.set_of_books_id /* 17078656 - nvl added for outer join */
                     --AND  nvl(AEH.event_type_code,'X') NOT IN ('PAYMENT CANCELLED','REFUND CANCELLED')
                     AND BAU.bank_account_id = P_BANK_ACCOUNT_ID
                     AND BAU.bank_account_id = BA.bank_account_id
                     AND BA.account_owner_org_id = SYS.legal_entity_id
                     AND ba.currency_code = fc.currency_code
                     AND aeh.accounting_date >
                         NVL (fnd_date.canonical_to_date (P_AS_OF_DATE),
                              aeh.accounting_date)
                     AND (TRUNC (c.void_date) > TRUNC (fnd_date.canonical_to_date (P_AS_OF_DATE)))
                     AND EXISTS
                             (SELECT 1
                                FROM ap_payment_history_all H2
                               WHERE     H2.check_id = C.check_id
                                     AND H2.transaction_type LIKE
                                             DECODE (C.void_date,
                                                     NULL, H2.transaction_type,
                                                     '%CANCEL%'))
                     /* Check that payment is not reconciled */
                     AND NOT EXISTS
                             (SELECT /*+ PUSH_SUBQ NO_UNNEST*/
                                     NULL
                                FROM ce_statement_reconcils_all CSR, ce_Statement_lines CSL, ce_statement_headers CSH
                               WHERE     CSR.reference_id = C.check_id
                                     AND CSR.reference_type = 'PAYMENT'
                                     --Start changes V2.0 by Deckers IT Team-- excluding Eternal Cash Statement Lines
                                     AND (csr.status_flag = 'M' OR csl.status = 'EXTERNAL')
                                     AND csr.current_record_flag = 'Y'
                                     --End changes V2.0 by Deckers IT Team
                                     AND CSR.statement_line_id =
                                         CSL.statement_line_id
                                     AND CSL.statement_header_id =
                                         CSH.statement_header_id
                                     --      AND CSH.statement_date <= NVL (fnd_date.canonical_to_date ( P_AS_OF_DATE ), CSH.statement_date)
                                     AND CSH.statement_date >=
                                         TRUNC (SYS.cashbook_begin_date))
                     AND (   AEH.event_id =
                             (SELECT MAX (event_id)
                                FROM xla_events xe
                               WHERE     xe.application_id = 200 /* 14698507 - Added */
                                     AND xe.entity_id = TRX.entity_id
                                     AND xe.event_number =
                                         (SELECT MAX (event_number)
                                            FROM xla_events xe2
                                           WHERE     xe2.application_id = 200 /* 14698507 - Added */
                                                 AND xe2.entity_id =
                                                     xe.entity_id
                                                 --AND xe2.event_date <= C_AS_OF_DATE
                                                 AND TRUNC (xe2.event_date) >=
                                                     TRUNC (
                                                         SYS.cashbook_begin_date)
                                                 AND xe2.event_status_code =
                                                     'P'
                                                 AND xe2.event_type_code NOT IN
                                                         ('PAYMENT MATURITY ADJUSTED', 'MANUAL PAYMENT ADJUSTED', 'PAYMENT ADJUSTED',
                                                          'PAYMENT CLEARING ADJUSTED', 'MANUAL REFUND ADJUSTED', 'REFUND ADJUSTED'))) /* 8241869 */
                          OR AEH.event_id IS NULL)
            ORDER BY C_AP_GL_DATE NULLS FIRST;

        -- Unreconicled Payments got Voided in this period for the prior period
        CURSOR payments_void_curr_c (P_BANK_CURR_DSP      VARCHAR2,
                                     P_GL_CURRENCY_CODE   VARCHAR2,
                                     P_BANK_ACCOUNT_ID    NUMBER,
                                     p_from_date          VARCHAR2,
                                     P_AS_OF_DATE         VARCHAR2)
        IS
              SELECT DISTINCT 'PAYMENT' C_AP_TYPE, C.check_id C_AP_ID, NVL (-1. * ROUND (DECODE (P_BANK_CURR_DSP, P_GL_CURRENCY_CODE, NVL (NVL (C.cleared_base_amount, C.base_amount), C.amount), C.amount), fc.precision), 0) C_AP_AMOUNT,
                              C.vendor_name C_AP_SUPPLIER_NAME, --    aeh.gl_transfer_date C_AP_GL_DATE,
                                                                aeh.accounting_date C_AP_GL_DATE, C.check_date C_AP_PAYMENT_DATE,
                              C.payment_method_code C_AP_PAYMENT_METHOD, C.check_number C_AP_PAYMENT_NUMBER, C.currency_code C_AP_CURRENCY,
                              ROUND (C.amount, fc.precision) C_AP_TRANS_AMOUNT, C.status_lookup_code C_AP_STATUS, FND_ACCESS_CONTROL_UTIL.get_org_name (C.org_id) C_ORG_NAME_AP,
                              c.cleared_date
                FROM ap_checks_all C, ce_bank_acct_uses_all BAU, ce_bank_accounts BA,
                     ce_system_parameters SYS, -- Start changes by Arun on 01/14/2017 commented AIP and added xla tables
                                               --ap_invoice_payments_all AIP,
                                               xla_transaction_entities_upg trx, xla_ae_headers aeh,
                     fnd_currencies fc
               WHERE     TRUNC (C.check_date) BETWEEN TRUNC (
                                                          NVL (
                                                              ADD_MONTHS (
                                                                  fnd_date.canonical_to_date (
                                                                      P_FROM_DATE),
                                                                  -1),
                                                              c.check_date))
                                                  AND TRUNC (
                                                          NVL (
                                                              ADD_MONTHS (
                                                                  fnd_date.canonical_to_date (
                                                                      P_AS_OF_DATE),
                                                                  -1),
                                                              c.check_date))
                     AND C.ce_bank_acct_use_id = BAU.bank_acct_use_id
                     AND C.org_id = BAU.org_id
                     AND TRX.application_id = 200       /* 13536461 - added */
                     AND TRX.ledger_id = SYS.set_of_books_id /* 13536461 - added */
                     AND NVL (TRX.source_id_int_1, -99) = C.check_id
                     AND TRX.entity_code = 'AP_PAYMENTS'
                     AND AEH.entity_id(+) = TRX.entity_id
                     AND NVL (AEH.application_id, 200) = 200 /* 13536461 - added */
                     AND NVL (AEH.ledger_id, SYS.set_of_books_id) =
                         SYS.set_of_books_id /* 17078656 - nvl added for outer join */
                     --AND  nvl(AEH.event_type_code,'X') NOT IN ('PAYMENT CANCELLED','REFUND CANCELLED')
                     AND BAU.bank_account_id = P_BANK_ACCOUNT_ID
                     AND BAU.bank_account_id = BA.bank_account_id
                     AND BA.account_owner_org_id = SYS.legal_entity_id
                     AND ba.currency_code = fc.currency_code
                     AND TRUNC (aeh.accounting_date) BETWEEN TRUNC (
                                                                 NVL (
                                                                     fnd_date.canonical_to_date (
                                                                         P_FROM_DATE),
                                                                     aeh.accounting_date))
                                                         AND TRUNC (
                                                                 NVL (
                                                                     fnd_date.canonical_to_date (
                                                                         P_AS_OF_DATE),
                                                                     aeh.accounting_date))
                     AND (TRUNC (c.void_date) BETWEEN TRUNC (NVL (fnd_date.canonical_to_date (P_FROM_DATE), c.void_date)) AND TRUNC (NVL (fnd_date.canonical_to_date (P_AS_OF_DATE), c.void_date)))
                     AND EXISTS
                             (SELECT 1
                                FROM ap_payment_history_all H2
                               WHERE     H2.check_id = C.check_id
                                     AND H2.transaction_type LIKE
                                             DECODE (C.void_date,
                                                     NULL, H2.transaction_type,
                                                     '%CANCEL%'))
                     /* Check that payment is not reconciled */
                     AND NOT EXISTS
                             (SELECT /*+ PUSH_SUBQ NO_UNNEST*/
                                     NULL
                                FROM ce_statement_reconcils_all CSR, ce_Statement_lines CSL, ce_statement_headers CSH
                               WHERE     CSR.reference_id = C.check_id
                                     AND CSR.reference_type = 'PAYMENT'
                                     --Start changes V2.0 by Deckers IT Team-- excluding Eternal Cash Statement Lines
                                     AND (csr.status_flag = 'M' OR csl.status = 'EXTERNAL')
                                     AND csr.current_record_flag = 'Y'
                                     --End changes V2.0 by Deckers IT Team
                                     AND CSR.statement_line_id =
                                         CSL.statement_line_id
                                     AND CSL.statement_header_id =
                                         CSH.statement_header_id
                                     --      AND CSH.statement_date <= NVL (fnd_date.canonical_to_date ( P_AS_OF_DATE ), CSH.statement_date)
                                     AND CSH.statement_date >=
                                         TRUNC (SYS.cashbook_begin_date))
                     AND (   AEH.event_id =
                             (SELECT MAX (event_id)
                                FROM xla_events xe
                               WHERE     xe.application_id = 200 /* 14698507 - Added */
                                     AND xe.entity_id = TRX.entity_id
                                     AND xe.event_number =
                                         (SELECT MAX (event_number)
                                            FROM xla_events xe2
                                           WHERE     xe2.application_id = 200 /* 14698507 - Added */
                                                 AND xe2.entity_id =
                                                     xe.entity_id
                                                 --AND xe2.event_date <= C_AS_OF_DATE
                                                 AND xe2.event_date >=
                                                     TRUNC (
                                                         SYS.cashbook_begin_date)
                                                 AND xe2.event_status_code =
                                                     'P'
                                                 AND xe2.event_type_code NOT IN
                                                         ('PAYMENT MATURITY ADJUSTED', 'MANUAL PAYMENT ADJUSTED', 'PAYMENT ADJUSTED',
                                                          'PAYMENT CLEARING ADJUSTED', 'MANUAL REFUND ADJUSTED', 'REFUND ADJUSTED'))) /* 8241869 */
                          OR AEH.event_id IS NULL)
            ORDER BY C_AP_GL_DATE NULLS FIRST;


        --- Statement lines, matched to a transaction created/cleared in the next period
        CURSOR statement_recon_next_period_c (p_bank_account_id NUMBER, p_from_date VARCHAR2, p_as_of_date VARCHAR2)
        IS
            SELECT DISTINCT csli.trx_date C_TRX_DATE, ROUND (DECODE (csli.trx_type,  'CREDIT', -1 * csra.amount,  'MISC_CREDIT', -1 * csra.amount,  'DEBIT', 1 * csra.amount,  'MISC_DEBIT', 1 * csra.amount,  'NSF', 1 * csra.amount,  csra.amount), fc.precision) C_DEP_AMOUNT, csli.status C_STATUS,
                            csli.Trx_Type C_TRX_TYPE, csli.line_number C_LINE_NUMBER, csli.effective_date C_EFFECTIVE_DATE,
                            NVL (csli.bank_trx_number, '          ') C_BANK_TRX_NUMBER, csh.statement_number C_STATEMENT_NUMBER, csh.statement_date C_STATEMENT_DATE,
                            trx.entity_id, NVL (aeh.Accounting_Date, csh.gl_date) C_GL_DATE, csli.trx_code trx_code, -- Added as a part of CCR0007351
                            csli.trx_text line_desc -- Added as a part of CCR0007351
              FROM ce_statement_lines csli, ce_statement_headers csh, ce_bank_accounts cba,
                   fnd_currencies fc, --                ap_payment_history_all aph,
                                      ce_statement_reconcils_all csra, xla_ae_headers aeh,
                   xla_ae_lines ael, xla_transaction_entities_upg trx, ap_checks_all aca
             WHERE     cba.bank_Account_id = csh.bank_account_id
                   AND csh.statement_header_id = csli.statement_header_id
                   AND csli.status = 'RECONCILED'
                   AND csra.status_flag = 'M'
                   AND csra.current_record_flag = 'Y'
                   AND cba.bank_Account_id = P_BANK_ACCOUNT_ID
                   AND cba.currency_code = fc.currency_code
                   AND csra.reference_type = 'PAYMENT'
                   --        and  not exists (select 1 from ap_payment_history_all where 1=1 and check_id = csra.reference_id)
                   --        and csh.statement_number = '170131'
                   AND aca.check_id = trx.source_id_int_1
                   AND aeh.application_id = trx.application_id
                   AND aeh.application_id = 200
                   AND aeh.ae_header_id = ael.ae_header_id
                   AND aeh.ledger_id = ael.ledger_id
                   --                  AND NVL (AEH.event_type_code, 'X') NOT IN ('PAYMENT CANCELLED',
                   --                                                             'REFUND CANCELLED')
                   AND aeh.application_id = ael.application_id
                   AND ael.accounting_class_code = 'CASH'
                   AND aeh.entity_id = trx.entity_id
                   AND csra.statement_line_id = csli.statement_line_id
                   AND aca.check_id = csra.reference_id
                   AND aeh.event_type_code = 'PAYMENT CLEARED'
                   AND csh.statement_date BETWEEN TRUNC (
                                                      NVL (
                                                          (fnd_date.canonical_to_date (P_FROM_DATE)),
                                                          csh.statement_date))
                                              AND TRUNC (
                                                      NVL (
                                                          (fnd_date.canonical_to_date (P_as_of_DATE)),
                                                          csh.statement_date))
                   AND TRUNC (aca.check_date) BETWEEN TRUNC (
                                                          NVL (
                                                              (fnd_date.canonical_to_date (P_FROM_DATE)),
                                                              aca.check_date))
                                                  AND TRUNC (
                                                          NVL (
                                                              (fnd_date.canonical_to_date (P_as_of_DATE)),
                                                              aca.check_date))
                   AND (TRUNC (aeh.accounting_date) > TRUNC (NVL (((fnd_date.canonical_to_date (P_as_of_DATE))), aeh.accounting_date)) OR TRUNC (csli.trx_date) > TRUNC (NVL (fnd_date.canonical_to_date (P_as_of_DATE), csli.trx_date)))
                   --AND (   AEH.event_id = --1.1
                   AND (   AEH.event_id IN                               --1.1
                               (SELECT (event_id)                        --1.1
                                  --(SELECT MAX (event_id)--1.1
                                  FROM xla_events xe
                                 WHERE     xe.application_id = 200 /* 14698507 - Added */
                                       AND xe.entity_id = TRX.entity_id
                                       -- AND xe.event_number = --1.1
                                       AND xe.event_number IN            --1.1
                                               --(SELECT MAX (event_number) --1.1
                                               (SELECT (event_number)
                                                  FROM xla_events xe2
                                                 WHERE     xe2.application_id =
                                                           200 /* 14698507 - Added */
                                                       AND xe2.entity_id =
                                                           xe.entity_id
                                                       --AND xe2.event_date <= C_AS_OF_DATE
                                                       --            AND xe2.event_date >= SYS.cashbook_begin_date
                                                       AND xe2.event_status_code =
                                                           'P'
                                                       AND xe2.event_type_code NOT IN
                                                               ('PAYMENT MATURITY ADJUSTED', 'MANUAL PAYMENT ADJUSTED', 'PAYMENT ADJUSTED',
                                                                'PAYMENT CLEARING ADJUSTED', 'MANUAL REFUND ADJUSTED', 'REFUND ADJUSTED'))
                                       AND NOT EXISTS
                                               (SELECT 1
                                                  FROM xla_transaction_entities_upg xte2, xla_ae_headers aeh2, xla_ae_lines ael2
                                                 WHERE     xte2.application_id =
                                                           200 /* 14698507 - Added */
                                                       AND xte2.entity_id =
                                                           trx.entity_id
                                                       AND xte2.application_id =
                                                           trx.application_id
                                                       AND xe.application_id =
                                                           xte2.application_id
                                                       AND aeh2.ae_header_id =
                                                           ael2.ae_header_id
                                                       AND xte2.entity_id =
                                                           aeh2.entity_id
                                                       AND aeh2.ledger_id =
                                                           ael2.ledger_id
                                                       AND aeh2.application_id =
                                                           ael2.application_id
                                                       AND ael2.accounting_class_code =
                                                           'CASH'
                                                       AND TRUNC (
                                                               ael2.accounting_date) BETWEEN TRUNC (
                                                                                                 NVL (
                                                                                                     (fnd_date.canonical_to_date (P_FROM_DATE)),
                                                                                                     ael2.accounting_date))
                                                                                         AND TRUNC (
                                                                                                 NVL (
                                                                                                     (fnd_date.canonical_to_date (P_as_of_DATE)),
                                                                                                     ael2.accounting_date))
                                                HAVING SUM (
                                                             NVL (
                                                                 ael2.entered_dr,
                                                                 0)
                                                           - NVL (
                                                                 ael2.entered_cr,
                                                                 0)) <>
                                                       0))       /* 8241869 */
                        /* 8241869 */
                        OR AEH.event_id IS NULL)
            UNION
            SELECT DISTINCT csli.trx_date C_TRX_DATE, ROUND (DECODE (csli.trx_type,  'CREDIT', -1 * csra.amount,  'MISC_CREDIT', -1 * csra.amount,  'DEBIT', 1 * csra.amount,  'MISC_DEBIT', 1 * csra.amount,  'NSF', 1 * csra.amount,  csra.amount), fc.precision) C_DEP_AMOUNT, csli.status C_STATUS,
                            csli.Trx_Type C_TRX_TYPE, csli.line_number C_LINE_NUMBER, csli.effective_date C_EFFECTIVE_DATE,
                            NVL (csli.bank_trx_number, '          ') C_BANK_TRX_NUMBER, csh.statement_number C_STATEMENT_NUMBER, csh.statement_date C_STATEMENT_DATE,
                            trx.entity_id, NVL (aeh.Accounting_Date, csh.gl_date) C_GL_DATE, csli.trx_code trx_code, -- Added as a part of CCR0007351
                            csli.trx_text line_desc -- Added as a part of CCR0007351
              FROM ce_statement_lines csli, ce_statement_headers csh, ce_bank_accounts cba,
                   fnd_currencies fc, --                ap_payment_history_all aph,
                                      ce_statement_reconcils_all csra, xla_ae_headers aeh,
                   xla_ae_lines ael, xla_transaction_entities_upg trx, ap_checks_all aca
             WHERE     cba.bank_Account_id = csh.bank_account_id
                   AND csh.statement_header_id = csli.statement_header_id
                   AND csli.status = 'RECONCILED'
                   AND csra.status_flag = 'M'
                   AND csra.current_record_flag = 'Y'
                   AND cba.bank_Account_id = P_BANK_ACCOUNT_ID
                   AND cba.currency_code = fc.currency_code
                   AND csra.reference_type = 'PAYMENT'
                   --        and  not exists (select 1 from ap_payment_history_all where 1=1 and check_id = csra.reference_id)
                   --        and csh.statement_number = '170131'
                   AND aca.check_id = trx.source_id_int_1
                   AND aeh.application_id = trx.application_id
                   AND aeh.application_id = 200
                   AND aeh.ae_header_id = ael.ae_header_id
                   AND aeh.ledger_id = ael.ledger_id
                   --                  AND NVL (AEH.event_type_code, 'X') NOT IN ('PAYMENT CANCELLED',
                   --                                                             'REFUND CANCELLED')
                   AND aeh.application_id = ael.application_id
                   AND ael.accounting_class_code = 'CASH'
                   AND aeh.entity_id = trx.entity_id
                   AND csra.statement_line_id = csli.statement_line_id
                   AND aca.check_id = csra.reference_id
                   AND aeh.event_type_code = 'PAYMENT CLEARED'
                   AND csh.statement_date BETWEEN TRUNC (
                                                      NVL (
                                                          (fnd_date.canonical_to_date (P_FROM_DATE)),
                                                          csh.statement_date))
                                              AND TRUNC (
                                                      NVL (
                                                          (fnd_date.canonical_to_date (P_as_of_DATE)),
                                                          csh.statement_date))
                   AND TRUNC (aca.check_date) >
                       TRUNC (
                           NVL ((fnd_date.canonical_to_date (P_as_of_DATE)),
                                aca.check_date))
                   AND (TRUNC (aeh.accounting_date) > TRUNC (NVL (((fnd_date.canonical_to_date (P_as_of_DATE))), aeh.accounting_date)) OR TRUNC (csli.trx_date) > TRUNC (NVL (fnd_date.canonical_to_date (P_as_of_DATE), csli.trx_date)))
                   -- AND (   AEH.event_id = --1.1
                   AND (   AEH.event_id IN                               --1.1
                               (SELECT (event_id)                        --1.1
                                  -- (SELECT MAX (event_id) --1.1
                                  FROM xla_events xe
                                 WHERE     xe.application_id = 200 /* 14698507 - Added */
                                       AND xe.entity_id = TRX.entity_id
                                       --AND xe.event_number = --1.1
                                       AND xe.event_number IN            --1.1
                                               (SELECT (event_number)
                                                  --(SELECT MAX (event_number)--1.1
                                                  FROM xla_events xe2
                                                 WHERE     xe2.application_id =
                                                           200 /* 14698507 - Added */
                                                       AND xe2.entity_id =
                                                           xe.entity_id
                                                       --AND xe2.event_date <= C_AS_OF_DATE
                                                       --            AND xe2.event_date >= SYS.cashbook_begin_date
                                                       AND xe2.event_status_code =
                                                           'P'
                                                       AND xe2.event_type_code NOT IN
                                                               ('PAYMENT MATURITY ADJUSTED', 'MANUAL PAYMENT ADJUSTED', 'PAYMENT ADJUSTED',
                                                                'PAYMENT CLEARING ADJUSTED', 'MANUAL REFUND ADJUSTED', 'REFUND ADJUSTED'))
                                       AND NOT EXISTS
                                               (SELECT 1
                                                  FROM xla_transaction_entities_upg xte2, xla_ae_headers aeh2, xla_ae_lines ael2
                                                 WHERE     xte2.application_id =
                                                           200 /* 14698507 - Added */
                                                       AND xte2.entity_id =
                                                           trx.entity_id
                                                       AND xte2.application_id =
                                                           trx.application_id
                                                       AND xe.application_id =
                                                           xte2.application_id
                                                       AND aeh2.ae_header_id =
                                                           ael2.ae_header_id
                                                       AND xte2.entity_id =
                                                           aeh2.entity_id
                                                       AND aeh2.ledger_id =
                                                           ael2.ledger_id
                                                       AND aeh2.application_id =
                                                           ael2.application_id
                                                       AND ael2.accounting_class_code =
                                                           'CASH'
                                                       AND TRUNC (
                                                               ael2.accounting_date) BETWEEN TRUNC (
                                                                                                 NVL (
                                                                                                     (fnd_date.canonical_to_date (P_FROM_DATE)),
                                                                                                     ael2.accounting_date))
                                                                                         AND TRUNC (
                                                                                                 NVL (
                                                                                                     (fnd_date.canonical_to_date (P_as_of_DATE)),
                                                                                                     ael2.accounting_date))
                                                HAVING SUM (
                                                             NVL (
                                                                 ael2.entered_dr,
                                                                 0)
                                                           - NVL (
                                                                 ael2.entered_cr,
                                                                 0)) <>
                                                       0))       /* 8241869 */
                        /* 8241869 */
                        OR AEH.event_id IS NULL)
            --      and csli.effective_date > NVL ( (  ( fnd_date.canonical_to_date ( P_as_of_DATE ) ) ), csli.effective_date)
            UNION
            SELECT DISTINCT csli.trx_date C_TRX_DATE, ROUND (DECODE (csli.trx_type,  'CREDIT', -1 * csra.amount,  'MISC_CREDIT', -1 * csra.amount,  'DEBIT', 1 * csra.amount,  'MISC_DEBIT', 1 * csra.amount,  'NSF', 1 * csra.amount,  csra.amount), fc.precision) C_DEP_AMOUNT, csli.status C_STATUS,
                            csli.Trx_Type C_TRX_TYPE, csli.line_number C_LINE_NUMBER, csli.effective_date C_EFFECTIVE_DATE,
                            NVL (csli.bank_trx_number, '          ') C_BANK_TRX_NUMBER, --             csli.bank_trx_number C_BANK_TRX_NUMBER,
                                                                                        csh.statement_number C_STATEMENT_NUMBER, csh.statement_date C_STATEMENT_DATE,
                            trx.entity_id, --             NVL(Aph.Accounting_Date,
                                           --                 (select jel.effective_Date
                                           --                    from gl_je_lines jel
                                           --                   where JEL.JE_HEADER_ID = csra.JE_HEADER_ID
                                           --                     AND JEL.JE_LINE_NUM  = csra.REFERENCE_ID)) C_GL_DATE
                                           NVL (aeh.Accounting_Date, csh.gl_date) C_GL_DATE, csli.trx_code trx_code, -- Added as a part of CCR0007351
                            csli.trx_text line_desc -- Added as a part of CCR0007351
              --            Aph.Accounting_Date
              FROM ce_statement_lines csli, ce_statement_headers csh, ce_bank_accounts cba,
                   ce_bank_acct_uses_all bau, fnd_currencies fc, ar_cash_receipt_history_all crh,
                   ar_cash_receipts_all cr, ce_statement_reconcils_all csra, xla_ae_headers aeh,
                   xla_ae_lines ael, xla_transaction_entities_upg trx
             WHERE     cba.bank_Account_id = csh.bank_account_id
                   AND cba.bank_account_id = bau.bank_account_id
                   AND csh.statement_header_id = csli.statement_header_id
                   AND csli.status = 'RECONCILED'
                   AND csra.status_flag = 'M'
                   AND csra.current_record_flag = 'Y'
                   AND cba.bank_Account_id = P_BANK_ACCOUNT_ID
                   AND cba.currency_code = fc.currency_code
                   --        and  not exists (select 1 from ap_payment_history_all where 1=1 and check_id = csra.reference_id)
                   --        and csh.statement_number = '170131'
                   AND crh.cash_receipt_id = trx.source_id_int_1
                   AND aeh.application_id = trx.application_id
                   AND aeh.application_id = 222
                   AND aeh.entity_id = trx.entity_id
                   AND aeh.event_type_code <> 'RECP_REVERSE'
                   AND aeh.ae_header_id = ael.ae_header_id
                   AND aeh.ledger_id = ael.ledger_id
                   AND aeh.application_id = ael.application_id
                   AND ael.accounting_class_code = 'CASH'
                   AND csra.statement_line_id = csli.statement_line_id
                   AND crh.cash_receipt_history_id = csra.reference_id
                   AND crh.cash_receipt_id = cr.cash_receipt_id
                   AND cr.cash_receipt_id = trx.source_id_int_1
                   AND cr.remit_bank_acct_use_id = bau.bank_acct_use_id
                   AND bau.org_id = cr.org_id
                   AND csh.statement_date BETWEEN TRUNC (
                                                      NVL (
                                                          (fnd_date.canonical_to_date (P_FROM_DATE)),
                                                          csh.statement_date))
                                              AND TRUNC (
                                                      NVL (
                                                          (fnd_date.canonical_to_date (P_as_of_DATE)),
                                                          csh.statement_date))
                   --      AND APH.transaction_type (+) = 'PAYMENT CLEARING'
                   AND TRUNC (cr.receipt_date) BETWEEN TRUNC (
                                                           NVL (
                                                               (fnd_date.canonical_to_date (P_FROM_DATE)),
                                                               cr.receipt_date))
                                                   AND TRUNC (
                                                           NVL (
                                                               (fnd_date.canonical_to_date (P_as_of_DATE)),
                                                               cr.receipt_date))
                   AND (TRUNC (aeh.accounting_date) > TRUNC (NVL (fnd_date.canonical_to_date (P_as_of_DATE), aeh.accounting_date)) OR TRUNC (csli.trx_date) > TRUNC (NVL (fnd_date.canonical_to_date (P_as_of_DATE), csli.trx_date)))
                   --AND (   AEH.event_id = --1.1
                   AND (   AEH.event_id IN                               --1.1
                               (SELECT (event_id)                        --1.1
                                  --(SELECT MAX (event_id)--1.1
                                  FROM xla_events xe
                                 WHERE     xe.application_id = 222 /* 14698507 - Added */
                                       AND xe.entity_id = TRX.entity_id
                                       --AND xe.event_number =--1.1
                                       AND xe.event_number IN            --1.1
                                               (SELECT (event_number)
                                                  --(SELECT MAX (event_number)--1.1
                                                  FROM xla_events xe2
                                                 WHERE     xe2.application_id =
                                                           222 /* 14698507 - Added */
                                                       AND xe2.entity_id =
                                                           xe.entity_id
                                                       --AND xe2.event_date <= C_AS_OF_DATE
                                                       --            AND xe2.event_date >= SYS.cashbook_begin_date
                                                       AND xe2.event_status_code =
                                                           'P'
                                                       AND xe2.event_type_code NOT IN
                                                               ('ADJ_CREATE'))
                                       AND NOT EXISTS
                                               (SELECT 1
                                                  FROM xla_transaction_entities_upg xte2, xla_ae_headers aeh2, xla_ae_lines ael2
                                                 WHERE     xte2.application_id =
                                                           222 /* 14698507 - Added */
                                                       AND xte2.entity_id =
                                                           trx.entity_id
                                                       AND xte2.application_id =
                                                           trx.application_id
                                                       AND xe.application_id =
                                                           xte2.application_id
                                                       AND aeh2.ae_header_id =
                                                           ael2.ae_header_id
                                                       AND xte2.entity_id =
                                                           aeh2.entity_id
                                                       AND aeh2.ledger_id =
                                                           ael2.ledger_id
                                                       AND aeh2.application_id =
                                                           ael2.application_id
                                                       AND ael2.accounting_class_code =
                                                           'CASH'
                                                       AND TRUNC (
                                                               ael2.accounting_date) BETWEEN TRUNC (
                                                                                                 NVL (
                                                                                                     (fnd_date.canonical_to_date (P_FROM_DATE)),
                                                                                                     ael2.accounting_date))
                                                                                         AND TRUNC (
                                                                                                 NVL (
                                                                                                     (fnd_date.canonical_to_date (P_as_of_DATE)),
                                                                                                     ael2.accounting_date))
                                                HAVING SUM (
                                                             NVL (
                                                                 ael2.entered_dr,
                                                                 0)
                                                           - NVL (
                                                                 ael2.entered_cr,
                                                                 0)) <>
                                                       0))       /* 8241869 */
                        OR AEH.event_id IS NULL)
            UNION
            SELECT DISTINCT csli.trx_date C_TRX_DATE, ROUND (DECODE (csli.trx_type,  'CREDIT', -1 * csra.amount,  'MISC_CREDIT', -1 * csra.amount,  'DEBIT', 1 * csra.amount,  'MISC_DEBIT', 1 * csra.amount,  'NSF', 1 * csra.amount,  csra.amount), fc.precision) C_DEP_AMOUNT, csli.status C_STATUS,
                            csli.Trx_Type C_TRX_TYPE, csli.line_number C_LINE_NUMBER, csli.effective_date C_EFFECTIVE_DATE,
                            NVL (csli.bank_trx_number, '          ') C_BANK_TRX_NUMBER, --             csli.bank_trx_number C_BANK_TRX_NUMBER,
                                                                                        csh.statement_number C_STATEMENT_NUMBER, csh.statement_date C_STATEMENT_DATE,
                            trx.entity_id, --             NVL(Aph.Accounting_Date,
                                           --                 (select jel.effective_Date
                                           --                    from gl_je_lines jel
                                           --                   where JEL.JE_HEADER_ID = csra.JE_HEADER_ID
                                           --                     AND JEL.JE_LINE_NUM  = csra.REFERENCE_ID)) C_GL_DATE
                                           NVL (aeh.Accounting_Date, csh.gl_date) C_GL_DATE, csli.trx_code trx_code, -- Added as a part of CCR0007351
                            csli.trx_text line_desc -- Added as a part of CCR0007351
              --            Aph.Accounting_Date
              FROM ce_statement_lines csli, ce_statement_headers csh, ce_bank_accounts cba,
                   ce_bank_acct_uses_all bau, fnd_currencies fc, ar_cash_receipt_history_all crh,
                   ar_cash_receipts_all cr, ce_statement_reconcils_all csra, xla_ae_headers aeh,
                   xla_ae_lines ael, xla_transaction_entities_upg trx
             WHERE     cba.bank_Account_id = csh.bank_account_id
                   AND cba.bank_account_id = bau.bank_account_id
                   AND csh.statement_header_id = csli.statement_header_id
                   AND csli.status = 'RECONCILED'
                   AND csra.status_flag = 'M'
                   AND csra.current_record_flag = 'Y'
                   AND cba.bank_Account_id = P_BANK_ACCOUNT_ID
                   AND cba.currency_code = fc.currency_code
                   --        and  not exists (select 1 from ap_payment_history_all where 1=1 and check_id = csra.reference_id)
                   --        and csh.statement_number = '170131'
                   AND crh.cash_receipt_id = trx.source_id_int_1
                   AND aeh.application_id = trx.application_id
                   AND aeh.application_id = 222
                   AND aeh.entity_id = trx.entity_id
                   AND aeh.event_type_code <> 'RECP_REVERSE'
                   AND aeh.ae_header_id = ael.ae_header_id
                   AND aeh.ledger_id = ael.ledger_id
                   AND aeh.application_id = ael.application_id
                   AND ael.accounting_class_code = 'CASH'
                   AND csra.statement_line_id = csli.statement_line_id
                   AND crh.cash_receipt_history_id = csra.reference_id
                   AND crh.cash_receipt_id = cr.cash_receipt_id
                   AND cr.cash_receipt_id = trx.source_id_int_1
                   AND cr.remit_bank_acct_use_id = bau.bank_acct_use_id
                   AND bau.org_id = cr.org_id
                   AND csh.statement_date BETWEEN TRUNC (
                                                      NVL (
                                                          (fnd_date.canonical_to_date (P_FROM_DATE)),
                                                          csh.statement_date))
                                              AND TRUNC (
                                                      NVL (
                                                          (fnd_date.canonical_to_date (P_as_of_DATE)),
                                                          csh.statement_date))
                   AND TRUNC (cr.receipt_date) >
                       TRUNC (
                           NVL ((fnd_date.canonical_to_date (P_as_of_DATE)),
                                cr.receipt_date))
                   --      AND APH.transaction_type (+) = 'PAYMENT CLEARING'

                   AND (TRUNC (aeh.accounting_date) > TRUNC (NVL (fnd_date.canonical_to_date (P_as_of_DATE), aeh.accounting_date)) OR TRUNC (csli.trx_date) > TRUNC (NVL (fnd_date.canonical_to_date (P_as_of_DATE), csli.trx_date)))
                   --1.1 changes start
                   -- AND (   AEH.event_id =
                   AND (   AEH.event_id IN
                               (SELECT (event_id)
                                  -- (SELECT MAX (event_id)
                                  --1.1 changes end
                                  FROM xla_events xe
                                 WHERE     xe.application_id = 222 /* 14698507 - Added */
                                       AND xe.entity_id = TRX.entity_id
                                       --AND xe.event_number = --1.1
                                       AND xe.event_number IN            --1.1
                                               (SELECT (event_number)
                                                  --(SELECT MAX (event_number)--1.1
                                                  FROM xla_events xe2
                                                 WHERE     xe2.application_id =
                                                           222 /* 14698507 - Added */
                                                       AND xe2.entity_id =
                                                           xe.entity_id
                                                       --AND xe2.event_date <= C_AS_OF_DATE
                                                       --            AND xe2.event_date >= SYS.cashbook_begin_date
                                                       AND xe2.event_status_code =
                                                           'P'
                                                       AND xe2.event_type_code NOT IN
                                                               ('ADJ_CREATE'))
                                       AND NOT EXISTS
                                               (SELECT 1
                                                  FROM xla_transaction_entities_upg xte2, xla_ae_headers aeh2, xla_ae_lines ael2
                                                 WHERE     xte2.application_id =
                                                           222 /* 14698507 - Added */
                                                       AND xte2.entity_id =
                                                           trx.entity_id
                                                       AND xte2.application_id =
                                                           trx.application_id
                                                       AND xe.application_id =
                                                           xte2.application_id
                                                       AND aeh2.ae_header_id =
                                                           ael2.ae_header_id
                                                       AND xte2.entity_id =
                                                           aeh2.entity_id
                                                       AND aeh2.ledger_id =
                                                           ael2.ledger_id
                                                       AND aeh2.application_id =
                                                           ael2.application_id
                                                       AND ael2.accounting_class_code =
                                                           'CASH'
                                                       AND TRUNC (
                                                               ael2.accounting_date) BETWEEN TRUNC (
                                                                                                 NVL (
                                                                                                     (fnd_date.canonical_to_date (P_FROM_DATE)),
                                                                                                     ael2.accounting_date))
                                                                                         AND TRUNC (
                                                                                                 NVL (
                                                                                                     (fnd_date.canonical_to_date (P_as_of_DATE)),
                                                                                                     ael2.accounting_date))
                                                HAVING SUM (
                                                             NVL (
                                                                 ael2.entered_dr,
                                                                 0)
                                                           - NVL (
                                                                 ael2.entered_cr,
                                                                 0)) <>
                                                       0))       /* 8241869 */
                        OR AEH.event_id IS NULL)
            UNION
            SELECT DISTINCT csl.trx_date C_TRX_DATE, ROUND (DECODE (csl.trx_type,  'CREDIT', -1 * csra.amount,  'MISC_CREDIT', -1 * csra.amount,  'DEBIT', 1 * csra.amount,  'MISC_DEBIT', 1 * csra.amount,  'NSF', 1 * csra.amount,  csra.amount), 2) C_DEP_AMOUNT, csl.status C_STATUS,
                            csl.Trx_Type C_TRX_TYPE, csl.line_number C_LINE_NUMBER, csl.effective_date C_EFFECTIVE_DATE,
                            NVL (csl.bank_trx_number, '          ') C_BANK_TRX_NUMBER, csh.statement_number C_STATEMENT_NUMBER, csh.statement_date C_STATEMENT_DATE,
                            NULL entity_id, ch.accounting_date C_GL_DATE, csl.trx_code trx_code, -- Added as a part of CCR0007351
                            csl.trx_text line_desc -- Added as a part of CCR0007351
              FROM ce_statement_lines CSL, ce_statement_headers CSH, ce_transaction_codes_v COD,
                   ce_statement_reconcils_all csra, ce_cashflows ca, ce_cashflow_acct_h ch
             WHERE     CSL.trx_type IN ('DEBIT', 'CREDIT', 'SWEEP_IN',
                                        'SWEEP_OUT')
                   AND CSL.trx_code = COD.trx_code
                   --                               AND COD.bank_account_id = :P_BANK_ACCOUNT_ID
                   AND COD.bank_account_id = csh.bank_account_id
                   AND csra.statement_line_id = csl.statement_line_id
                   AND ca.cashflow_id = ch.cashflow_id
                   --                               AND COD.reconcile_flag = 'CE'
                   AND CSL.STATEMENT_LINE_ID = ca.STATEMENT_LINE_ID
                   AND CSH.statement_header_id = CSL.statement_header_id
                   AND (NVL (csra.status_flag, 'ABC') <> 'M' OR csl.status != 'EXTERNAL')
                   AND csra.current_record_flag = 'Y'
                   --                               and csl.status <> 'RECONCILED'
                   AND csh.statement_date BETWEEN TRUNC (
                                                      NVL (
                                                          (fnd_date.canonical_to_date (P_FROM_DATE)),
                                                          csh.statement_date))
                                              AND TRUNC (
                                                      NVL (
                                                          (fnd_date.canonical_to_date (P_as_of_DATE)),
                                                          csh.statement_date))
                   AND TRUNC (ch.accounting_date) >
                       --                                BETWEEN NVL (
                       --                                                       fnd_date.canonical_to_date (P_FROM_DATE),
                       --                                                  ch.accounting_date)
                       --                                           AND
                       TRUNC (
                           NVL (fnd_date.canonical_to_date (P_as_of_DATE),
                                ch.accounting_date))
                   -- AND ch.event_id =
                   AND ch.event_id IN
                           (SELECT NVL ((a.event_id), -1)
                              --(SELECT NVL (MAX (a.event_id), -1)
                              FROM ce.ce_cashflow_acct_h a
                             WHERE     a.cashflow_id = ch.cashflow_id
                                   AND TRUNC (a.accounting_date) <=
                                       TRUNC (
                                           NVL (
                                               fnd_date.canonical_to_date (
                                                   P_as_of_DATE),
                                               a.accounting_date)))
                   AND ((ch.event_type = 'CE_BAT_UNCLEARED' AND ch.status_code = 'ACCOUNTED') OR (ch.event_type = 'CE_BAT_CREATED'))
            UNION
            SELECT DISTINCT csl.trx_date C_TRX_DATE, ROUND (DECODE (csl.trx_type,  'CREDIT', -1 * csra.amount,  'MISC_CREDIT', -1 * csra.amount,  'DEBIT', 1 * csra.amount,  'MISC_DEBIT', 1 * csra.amount,  'NSF', 1 * csra.amount,  csra.amount), 2) C_DEP_AMOUNT, csl.status C_STATUS,
                            csl.Trx_Type C_TRX_TYPE, csl.line_number C_LINE_NUMBER, csl.effective_date C_EFFECTIVE_DATE,
                            NVL (csl.bank_trx_number, '          ') C_BANK_TRX_NUMBER, csh.statement_number C_STATEMENT_NUMBER, csh.statement_date C_STATEMENT_DATE,
                            NULL entity_id, ch.accounting_date C_GL_DATE, csl.trx_code trx_code, -- Added as a part of CCR0007351
                            csl.trx_text line_desc -- Added as a part of CCR0007351
              FROM ce_statement_lines CSL, ce_statement_headers CSH, ce_transaction_codes_v COD,
                   ce_statement_reconcils_all csra, ce_cashflows ca, ce_cashflow_acct_h ch
             WHERE     CSL.trx_type IN ('DEBIT', 'CREDIT', 'SWEEP_IN',
                                        'SWEEP_OUT')
                   AND CSL.trx_code = COD.trx_code
                   --                               AND COD.bank_account_id = :P_BANK_ACCOUNT_ID
                   AND COD.bank_account_id = csh.bank_account_id
                   AND csra.statement_line_id = csl.statement_line_id
                   AND ca.cashflow_id = ch.cashflow_id
                   --                               AND COD.reconcile_flag = 'CE'
                   AND CSL.STATEMENT_LINE_ID = ca.STATEMENT_LINE_ID
                   AND CSH.statement_header_id = CSL.statement_header_id
                   AND (NVL (csra.status_flag, 'ABC') <> 'M' OR csl.status != 'EXTERNAL')
                   AND csra.current_record_flag = 'Y'
                   --                               and csl.status <> 'RECONCILED'
                   AND csh.statement_date BETWEEN TRUNC (
                                                      NVL (
                                                          (fnd_date.canonical_to_date (P_FROM_DATE)),
                                                          csh.statement_date))
                                              AND TRUNC (
                                                      NVL (
                                                          (fnd_date.canonical_to_date (P_as_of_DATE)),
                                                          csh.statement_date))
                   AND TRUNC (ch.accounting_date) >
                       --                                BETWEEN NVL (
                       --                                                       fnd_date.canonical_to_date (P_FROM_DATE),
                       --                                                  ch.accounting_date)
                       --                                           AND
                       TRUNC (
                           NVL (fnd_date.canonical_to_date (P_as_of_DATE),
                                ch.accounting_date))
                   -- AND ch.event_id =
                   AND ch.event_id IN
                           (SELECT NVL ((a.event_id), -1)
                              --(SELECT NVL (MAX (a.event_id), -1)
                              FROM ce.ce_cashflow_acct_h a
                             WHERE     a.cashflow_id = ch.cashflow_id
                                   AND TRUNC (a.accounting_date) >
                                       TRUNC (
                                           NVL (
                                               fnd_date.canonical_to_date (
                                                   P_as_of_DATE),
                                               a.accounting_date)))
                   AND ((ch.event_type = 'CE_BAT_UNCLEARED' AND ch.status_code = 'ACCOUNTED') OR (ch.event_type = 'CE_BAT_CREATED'))
            ORDER BY C_STATEMENT_NUMBER ASC;


        --Transactions where Matched line amount and GL amount are different- receipts
        CURSOR receipts_recon_mismtch_c (P_BANK_CURR_DSP      VARCHAR2,
                                         P_GL_CURRENCY_CODE   VARCHAR2,
                                         P_BANK_ACCOUNT_ID    NUMBER,
                                         p_from_date          VARCHAR2,
                                         P_AS_OF_DATE         VARCHAR2)
        IS
              SELECT csl.trx_date C_TRX_DATE, ROUND (NVL (DECODE (csl.trx_type,  'CREDIT', 1 * (NVL (csl.amount, 0) - SUM (NVL (csra.amount, 0))),  'MISC_CREDIT', 1 * (NVL (csl.amount, 0) - SUM (NVL (csra.amount, 0))),  'DEBIT', -1 * (NVL (csl.amount, 0) - SUM (NVL (csra.amount, 0))),  'MISC_DEBIT', -1 * (NVL (csl.amount, 0) - SUM (NVL (csra.amount, 0))),  'NSF', -1 * (NVL (csl.amount, 0) - SUM (NVL (csra.amount, 0))),  (NVL (csl.amount, 0) - SUM (NVL (csra.amount, 0)))), 0), 2) C_AR_AMOUNT, csl.statement_line_id,
                     --                   ael.ae_header_id,
                     csl.status C_STATUS, csl.Trx_Type C_TRX_TYPE, csl.line_number C_LINE_NUMBER,
                     csl.effective_date C_EFFECTIVE_DATE, NVL (csl.bank_trx_number, '          ') C_BANK_TRX_NUMBER, csh.statement_number C_STATEMENT_NUMBER,
                     csh.statement_date C_STATEMENT_DATE, bank_account_id
                --                trx.entity_id
                FROM ce_statement_reconcils_all csra, ce_statement_lines csl, ce_statement_headers csh
               WHERE     1 = 1
                     --and csl.statement_line_id = 490384
                     AND csh.bank_account_id = P_BANK_ACCOUNT_ID
                     AND csra.statement_line_id(+) = csl.statement_line_id
                     AND csra.status_flag(+) = 'M'
                     AND csl.status = 'RECONCILED'
                     AND csra.current_record_flag(+) = 'Y'
                     AND csra.reference_type(+) = 'RECEIPT'
                     AND csl.statement_header_id = csh.statement_header_id
                     AND csh.statement_date BETWEEN TRUNC (
                                                        NVL (
                                                            fnd_date.canonical_to_date (
                                                                p_from_date),
                                                            CSH.statement_date))
                                                AND TRUNC (
                                                        NVL (
                                                            fnd_date.canonical_to_date (
                                                                P_AS_OF_DATE),
                                                            CSH.statement_date))
            GROUP BY csl.trx_type, csl.amount, csl.statement_line_id,
                     csl.status, csl.Trx_Type, csl.line_number,
                     csl.effective_date, NVL (csl.bank_trx_number, '          '), csh.statement_number,
                     csh.statement_date, csl.trx_date, bank_account_id
              HAVING NVL (csl.amount, 0) - SUM (NVL (csra.amount, 0)) <> 0
            ORDER BY C_STATEMENT_DATE NULLS FIRST;


        --Transactions where Matched line amount and GL amount are different- Payments
        CURSOR payment_recon_mismtch_c (P_BANK_ACCOUNT_ID NUMBER, p_from_date VARCHAR2, P_AS_OF_DATE VARCHAR2)
        IS
              SELECT csl.trx_date C_TRX_DATE, ROUND (NVL (DECODE (csl.trx_type,  'CREDIT', -1 * (NVL (csl.amount, 0) - SUM (NVL (csra.amount, 0))),  'MISC_CREDIT', -1 * (NVL (csl.amount, 0) - SUM (NVL (csra.amount, 0))),  'DEBIT', 1 * (NVL (csl.amount, 0) - SUM (NVL (csra.amount, 0))),  'MISC_DEBIT', 1 * (NVL (csl.amount, 0) - SUM (NVL (csra.amount, 0))),  'NSF', 1 * (NVL (csl.amount, 0) - SUM (NVL (csra.amount, 0))),  (NVL (csl.amount, 0) - SUM (NVL (csra.amount, 0)))), 0), 2) C_PAY_AMOUNT, csl.statement_line_id,
                     --                   ael.ae_header_id,
                     csl.status C_STATUS, csl.Trx_Type C_TRX_TYPE, csl.line_number C_LINE_NUMBER,
                     csl.effective_date C_EFFECTIVE_DATE, NVL (csl.bank_trx_number, '          ') C_BANK_TRX_NUMBER, csh.statement_number C_STATEMENT_NUMBER,
                     csh.statement_date C_STATEMENT_DATE, bank_account_id, csh.gl_date c_gl_date,
                     csl.trx_code trx_code,   -- Added as a part of CCR0007351
                                            csl.trx_text line_desc -- Added as a part of CCR0007351
                --                trx.entity_id
                FROM ce_statement_reconcils_all csra, ce_statement_lines csl, ce_statement_headers csh
               WHERE     1 = 1
                     --and csl.statement_line_id = 490384
                     AND csh.bank_account_id = P_BANK_ACCOUNT_ID
                     AND csra.statement_line_id(+) = csl.statement_line_id
                     AND csra.status_flag(+) = 'M'
                     AND csl.status = 'RECONCILED'
                     AND csra.current_record_flag(+) = 'Y'
                     --AND csra.reference_type(+) = 'PAYMENT'
                     AND csl.statement_header_id = csh.statement_header_id
                     AND csh.statement_date BETWEEN TRUNC (
                                                        NVL (
                                                            fnd_date.canonical_to_date (
                                                                p_from_date),
                                                            CSH.statement_date))
                                                AND TRUNC (
                                                        NVL (
                                                            fnd_date.canonical_to_date (
                                                                P_AS_OF_DATE),
                                                            CSH.statement_date))
            GROUP BY csl.trx_type, csl.amount, csl.statement_line_id,
                     csl.status, csl.Trx_Type, csl.line_number,
                     csl.effective_date, NVL (csl.bank_trx_number, '          '), csh.statement_number,
                     csh.statement_date, csl.trx_date, bank_account_id,
                     csh.gl_date, csl.trx_code, csl.trx_text
              HAVING NVL (csl.amount, 0) - SUM (NVL (csra.amount, 0)) <> 0
            ORDER BY C_STATEMENT_DATE NULLS FIRST;
    BEGIN
        l_Date   :=
            TO_CHAR (fnd_date.canonical_to_date (p_as_of_date), 'MON-YY');

        /*fnd_file.put_line (
           fnd_file.LOG,
              'ld_from_date -- '
           || ld_from_date
           || CHR (9)
           || 'ld_as_of_date -- '
           || ld_as_of_date
           || CHR (9)
           || 'Date --'
           || l_date);*/

        OPEN gl_set_of_books_c (p_bank_account_id);

        FETCH gl_set_of_books_c INTO ln_set_of_books_id, ln_cash_clearing_ccid, ln_asset_cc_id, lc_bank_curr_code;

        CLOSE gl_set_of_books_c;

        --dbms_output.put_line('Test Begins');



        fnd_file.put_line (
            fnd_file.LOG,
               'ln_set_of_books_id -- '
            || ln_set_of_books_id
            || CHR (9)
            || 'ln_cash_clearing_ccid -- '
            || ln_cash_clearing_ccid
            || CHR (9)
            || 'ln_asset_cc_id -- '
            || ln_asset_cc_id
            || CHR (9)
            || 'lc_bank_curr_code -- '
            || lc_bank_curr_code
            || CHR (9));


        IF ln_set_of_books_id IS NOT NULL
        THEN
            OPEN gl_details_c (ln_set_of_books_id, p_as_of_date);

            FETCH gl_details_c
                INTO ln_set_of_books_id, lc_gl_curr_code, ln_chart_of_acct_id, lc_meaning,
                     ld_end_date;

            CLOSE gl_details_c;
        END IF;

        fnd_file.put_line (
            fnd_file.LOG,
               'ln_set_of_books_id -- '
            || ln_set_of_books_id
            || CHR (9)
            || 'lc_gl_curr_code -- '
            || lc_gl_curr_code
            || CHR (9)
            || 'ln_chart_of_acct_id -- '
            || ln_chart_of_acct_id
            || CHR (9)
            || 'lc_meaning -- '
            || lc_meaning
            || CHR (9)
            || 'ld_end_date -- '
            || ld_end_date
            || CHR (9));


        OPEN ce_bank_details_c (p_bank_account_id);

        FETCH ce_bank_details_c INTO lc_bank_branch_name, lc_bank_name, lc_bank_account_name, lc_bank_account_num;

        CLOSE ce_bank_details_c;


        lv_period_name   :=
            get_current_period (p_as_of_date, ln_set_of_books_id);


        IF ln_asset_cc_id IS NULL
        THEN
            OPEN asset_ccid_c (p_bank_account_id);

            FETCH asset_ccid_c INTO ln_asset_cc_id;

            CLOSE asset_ccid_c;
        END IF;

        fnd_file.put_line (fnd_file.LOG,
                           'ln_asset_cc_id -- ' || ln_asset_cc_id);


        IF p_report_type IN ('DETAIL', 'SUMMARY')
        THEN
            -- Unreconciled Receipts not Reversed/Cleared

            FOR ar_receipts_not_reversed_r
                IN ar_receipts_not_reversed_c (p_bank_account_id,
                                               p_from_date,
                                               p_as_of_date,
                                               lc_bank_curr_code,
                                               lc_gl_curr_code)
            LOOP
                BEGIN
                    INSERT INTO XXDO.XXD_GL_RECON_REP_GT (Description,
                                                          Short_Code,
                                                          receipt_num,
                                                          GL_Date,
                                                          Remit_Date,
                                                          Customer_Name,
                                                          Payment_Method,
                                                          Status,
                                                          Currency,
                                                          Amount,
                                                          Accounted_Amt)
                             VALUES (
                                        'Unreconciled Receipts not Reversed/Cleared',
                                        'URNRORC_1',
                                        ar_receipts_not_reversed_r.C_AR_RECEIPT_NUMBER,
                                        ar_receipts_not_reversed_r.C_AR_GL_DATE,
                                        ar_receipts_not_reversed_r.C_AR_REMIT_DATE,
                                        ar_receipts_not_reversed_r.C_AR_CUSTOMER_NAME,
                                        ar_receipts_not_reversed_r.C_AR_PAYMENT_METHOD,
                                        ar_receipts_not_reversed_r.C_AR_STATUS,
                                        ar_receipts_not_reversed_r.C_AR_CURRENCY,
                                        --xxd_format_amount (ar_receipts_not_reversed_r.C_AR_TRANS_AMOUNT),
                                        --xxd_format_amount (ar_receipts_not_reversed_r.C_AR_AMOUNT_NO_REV)
                                        ar_receipts_not_reversed_r.C_AR_TRANS_AMOUNT,
                                        ar_receipts_not_reversed_r.C_AR_AMOUNT_NO_REV);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_error_flag   := 'E';
                --ROLLBACK;
                END;
            END LOOP;



            --Added by Arun N Murthy on 21 Jan 2017
            ----------------------------------------------------------------------------------------------------------------------------
            --lc_detail_view := 'Unreconciled Receipts Cleared in the next period:';

            FOR ar_receipts_clr_nxt_period_r
                IN ar_receipts_clr_nxt_period_c (p_bank_account_id,
                                                 p_from_date,
                                                 p_as_of_date,
                                                 lc_bank_curr_code,
                                                 lc_gl_curr_code)
            LOOP
                BEGIN
                    /*ln_trx_amount := 0;
                    ln_trx_acctd_amount :=0;

                      BEGIN
                        SELECT  xxd_format_amount (ar_receipts_clr_nxt_period_r.C_AR_TRANS_AMOUNT)
                          INTO  ln_trx_amount
                          FROM  dual;
                      EXCEPTION
                      WHEN OTHERS
                      THEN
                        ln_trx_amount := 0;
                      END;

                      BEGIN
                        SELECT  xxd_format_amount (ar_receipts_clr_nxt_period_r.C_AR_AMOUNT_CLR)
                          INTO  ln_trx_acctd_amount
                          FROM  dual;
                      EXCEPTION
                      WHEN OTHERS
                      THEN
                        ln_trx_acctd_amount := 0;
                      END;*/

                    INSERT INTO XXDO.XXD_GL_RECON_REP_GT (Description,
                                                          Short_Code,
                                                          receipt_num,
                                                          GL_Date,
                                                          Remit_Date,
                                                          Customer_Name,
                                                          Payment_Method,
                                                          Status,
                                                          Currency,
                                                          Amount,
                                                          Accounted_Amt)
                             VALUES (
                                        'Unreconciled Receipts Cleared in the next period',
                                        'URCITNP_2',
                                        ar_receipts_clr_nxt_period_r.C_AR_RECEIPT_NUMBER,
                                        ar_receipts_clr_nxt_period_r.C_AR_GL_DATE,
                                        ar_receipts_clr_nxt_period_r.C_AR_REMIT_DATE,
                                        ar_receipts_clr_nxt_period_r.C_AR_CUSTOMER_NAME,
                                        ar_receipts_clr_nxt_period_r.C_AR_PAYMENT_METHOD,
                                        ar_receipts_clr_nxt_period_r.C_AR_STATUS,
                                        ar_receipts_clr_nxt_period_r.C_AR_CURRENCY,
                                        --xxd_format_amount (ar_receipts_clr_nxt_period_r.C_AR_TRANS_AMOUNT),
                                        --xxd_format_amount (ar_receipts_clr_nxt_period_r.C_AR_AMOUNT_CLR));
                                        ar_receipts_clr_nxt_period_r.C_AR_TRANS_AMOUNT,
                                        ar_receipts_clr_nxt_period_r.C_AR_AMOUNT_CLR);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_error_flag   := 'E';
                --ROLLBACK;
                END;
            END LOOP;

            /*lc_detail_total :=
                  RPAD ('Total Amount', 168)
               || xxd_format_amount (ln_sum_receipts_rec_nxt);*/

            -- lc_detail_view := 'Unreconciled Receipts reversed in the next period :';

            FOR ar_receipts_reversed_r
                IN ar_receipts_reversed_c (p_bank_account_id,
                                           p_from_date,
                                           p_as_of_date,
                                           lc_bank_curr_code,
                                           lc_gl_curr_code)
            LOOP
                BEGIN
                    INSERT INTO XXDO.XXD_GL_RECON_REP_GT (Description,
                                                          Short_Code,
                                                          receipt_num,
                                                          GL_Date,
                                                          Remit_Date,
                                                          Customer_Name,
                                                          Payment_Method,
                                                          Status,
                                                          Currency,
                                                          Amount,
                                                          Accounted_Amt)
                             VALUES (
                                        'Unreconciled Receipts reversed in the next period',
                                        'URRITNP_3',
                                        ar_receipts_reversed_r.C_AR_RECEIPT_NUMBER,
                                        ar_receipts_reversed_r.C_AR_GL_DATE,
                                        ar_receipts_reversed_r.C_AR_REMIT_DATE,
                                        ar_receipts_reversed_r.C_AR_CUSTOMER_NAME,
                                        ar_receipts_reversed_r.C_AR_PAYMENT_METHOD,
                                        ar_receipts_reversed_r.C_AR_STATUS,
                                        ar_receipts_reversed_r.C_AR_CURRENCY,
                                        --xxd_format_amount (ar_receipts_reversed_r.C_AR_TRANS_AMOUNT),
                                        --xxd_format_amount (ar_receipts_reversed_r.C_AR_AMOUNT_REV));
                                        ar_receipts_reversed_r.C_AR_TRANS_AMOUNT,
                                        ar_receipts_reversed_r.C_AR_AMOUNT_REV);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        --ROLLBACK;
                        lv_error_flag   := 'E';
                END;
            END LOOP;

            /*lc_detail_total :=
                  RPAD ('Total Amount', 168)
               || xxd_format_amount (ln_sum_receipts_rev);*/
            --lc_detail_view := 'Unreconciled Payments not voided/cleared:';

            FOR payments_not_void_clear_r
                IN payments_not_void_clear_c (lc_bank_curr_code, lc_gl_curr_code, p_bank_account_id
                                              , p_from_date, p_as_of_date)
            LOOP
                BEGIN
                    /*ln_trx_amount := 0;
                    ln_trx_acctd_amount :=0;

                      BEGIN
                        SELECT  xxd_format_amount (payments_not_void_clear_r.C_AP_TRANS_AMOUNT)
                          INTO  ln_trx_amount
                          FROM  dual;
                      EXCEPTION
                      WHEN OTHERS
                      THEN
                        ln_trx_amount := 0;
                      END;

                      BEGIN
                        SELECT  xxd_format_amount (payments_not_void_clear_r.C_AP_AMOUNT)
                          INTO  ln_trx_acctd_amount
                          FROM  dual;
                      EXCEPTION
                      WHEN OTHERS
                      THEN
                        ln_trx_acctd_amount := 0;
                      END;*/


                    INSERT INTO XXDO.XXD_GL_RECON_REP_GT (Description,
                                                          Short_Code,
                                                          Payment_num,
                                                          GL_Date,
                                                          Payment_Date,
                                                          supplier_Name,
                                                          Payment_Method,
                                                          Status,
                                                          Currency,
                                                          Amount,
                                                          Accounted_Amt)
                             VALUES (
                                        'Unreconciled Payments not voided/cleared',
                                        'UPNVORC_4',
                                        payments_not_void_clear_r.C_AP_PAYMENT_NUMBER,
                                        payments_not_void_clear_r.C_AP_GL_DATE,
                                        payments_not_void_clear_r.C_AP_PAYMENT_DATE,
                                        payments_not_void_clear_r.C_AP_SUPPLIER_NAME,
                                        payments_not_void_clear_r.C_AP_PAYMENT_METHOD,
                                        payments_not_void_clear_r.C_AP_STATUS,
                                        payments_not_void_clear_r.C_AP_CURRENCY,
                                        --xxd_format_amount (payments_not_void_clear_r.C_AP_TRANS_AMOUNT),
                                        --xxd_format_amount (payments_not_void_clear_r.C_AP_AMOUNT)
                                        payments_not_void_clear_r.C_AP_TRANS_AMOUNT,
                                        payments_not_void_clear_r.C_AP_AMOUNT);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        --ROLLBACK;
                        lv_error_flag   := 'E';
                END;
            END LOOP;


            /*lc_detail_total :=
                  RPAD ('Total Amount', 158)
               || xxd_format_amount (ln_sum_no_void_clear_amt);*/

            --lc_detail_view := 'Unreconciled Payments got cleared in next period:';

            FOR payments_clear_r
                IN payments_clear_c (lc_bank_curr_code, lc_gl_curr_code, p_bank_account_id
                                     , p_from_date, p_as_of_date)
            LOOP
                BEGIN
                    INSERT INTO XXDO.XXD_GL_RECON_REP_GT (Description,
                                                          Short_Code,
                                                          Payment_num,
                                                          GL_Date,
                                                          Payment_Date,
                                                          supplier_Name,
                                                          Payment_Method,
                                                          Status,
                                                          Currency,
                                                          Amount,
                                                          Accounted_Amt)
                             VALUES (
                                        'Unreconciled Payments got cleared in next period',
                                        'UPGCINP_5',
                                        payments_clear_r.C_AP_PAYMENT_NUMBER,
                                        payments_clear_r.C_AP_GL_DATE,
                                        payments_clear_r.C_AP_PAYMENT_DATE,
                                        payments_clear_r.C_AP_SUPPLIER_NAME,
                                        payments_clear_r.C_AP_PAYMENT_METHOD,
                                        payments_clear_r.C_AP_STATUS,
                                        payments_clear_r.C_AP_CURRENCY,
                                        --xxd_format_amount (payments_clear_r.C_AP_TRANS_AMOUNT),
                                        --xxd_format_amount (payments_clear_r.C_AP_AMOUNT))
                                        payments_clear_r.C_AP_TRANS_AMOUNT,
                                        payments_clear_r.C_AP_AMOUNT);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        --ROLLBACK;
                        lv_error_flag   := 'E';
                END;
            END LOOP;


            /*lc_detail_total :=
                  RPAD ('Total Amount', 158)
               || xxd_format_amount (ln_sum_clear_amt);*/

            --lc_detail_view := 'Unreconciled Payments got Voided in next period:';

            FOR payments_void_r
                IN payments_void_c (lc_bank_curr_code, lc_gl_curr_code, p_bank_account_id
                                    , p_from_date, p_as_of_date)
            LOOP
                BEGIN
                    INSERT INTO XXDO.XXD_GL_RECON_REP_GT (Description,
                                                          Short_Code,
                                                          Payment_num,
                                                          GL_Date,
                                                          Payment_Date,
                                                          supplier_Name,
                                                          Payment_Method,
                                                          Status,
                                                          Currency,
                                                          Amount,
                                                          Accounted_Amt)
                             VALUES (
                                        'Unreconciled Payments got Voided in next period',
                                        'UPGVINP_6',
                                        payments_void_r.C_AP_PAYMENT_NUMBER,
                                        payments_void_r.C_AP_GL_DATE,
                                        payments_void_r.C_AP_PAYMENT_DATE,
                                        payments_void_r.C_AP_SUPPLIER_NAME,
                                        payments_void_r.C_AP_PAYMENT_METHOD,
                                        payments_void_r.C_AP_STATUS,
                                        payments_void_r.C_AP_CURRENCY,
                                        --xxd_format_amount (payments_void_r.C_AP_TRANS_AMOUNT),
                                        --xxd_format_amount (payments_void_r.C_AP_AMOUNT));
                                        payments_void_r.C_AP_TRANS_AMOUNT,
                                        payments_void_r.C_AP_AMOUNT);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        --ROLLBACK;
                        lv_error_flag   := 'E';
                END;
            END LOOP;


            /*lc_detail_total :=
               RPAD ('Total Amount', 158) || xxd_format_amount (ln_sum_void_amt);*/

            --lc_detail_view := 'Unreconciled Cashflows:';

            FOR unrecon_cashflows_r
                IN unrecon_cashflows_c (p_bank_account_id,
                                        p_from_date,
                                        p_as_of_date)
            LOOP
                BEGIN
                    INSERT INTO XXDO.XXD_GL_RECON_REP_GT (
                                    Description,
                                    Short_Code,
                                    Cashflow_num,
                                    GL_Date,
                                    Transaction_date,
                                    Counterparty_Name,
                                    Transaction_Subtype,
                                    Status,
                                    Currency,
                                    Amount,
                                    Accounted_Amt)
                             VALUES ('Unreconciled Cashflows',
                                     'UCF_7',
                                     unrecon_cashflows_r.C_CF_NUMBER,
                                     unrecon_cashflows_r.C_GL_DATE,
                                     unrecon_cashflows_r.C_CF_DATE,
                                     unrecon_cashflows_r.C_COUNTER_NAME,
                                     unrecon_cashflows_r.C_SUBTYPE_NAME,
                                     unrecon_cashflows_r.C_CF_STATUS,
                                     unrecon_cashflows_r.C_CF_CURRENCY,
                                     --xxd_format_amount (unrecon_cashflows_r.C_CF_AMOUNT),
                                     --xxd_format_amount (unrecon_cashflows_r.C_ACCOUNT_AMOUNT));
                                     unrecon_cashflows_r.C_CF_AMOUNT,
                                     unrecon_cashflows_r.C_ACCOUNT_AMOUNT);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        --ROLLBACK;
                        lv_error_flag   := 'E';
                END;
            END LOOP;

            /*lc_detail_total :=
                  RPAD ('Total Amount', 177)
               || xxd_format_amount (ln_sum_cf_acct_amt);*/

            -- lc_detail_view := 'Unreconciled Journal Entries Original entry/related reversal current month:';
            FOR unrecon_journal_no_parental_r
                IN unrecon_journal_no_parental_c (lc_bank_curr_code,
                                                  lc_gl_curr_code,
                                                  ln_set_of_books_id,
                                                  p_bank_account_id,
                                                  ln_asset_cc_id,
                                                  ln_cash_clearing_ccid,
                                                  p_from_date,
                                                  p_as_of_date,
                                                  lv_period_name)
            LOOP
                BEGIN
                    INSERT INTO XXDO.XXD_GL_RECON_REP_GT (Description,
                                                          Short_Code,
                                                          je_line_num,
                                                          je_effective_date,
                                                          je_posted_date,
                                                          je_entry_name,
                                                          je_line_type,
                                                          Status,
                                                          Currency,
                                                          Amount,
                                                          Accounted_Amt)
                             VALUES (
                                        'Unreconciled Journal Entries Original entry/related reversal current month',
                                        'UJEOEORRRCM_8',
                                        unrecon_journal_no_parental_r.C_JE_LINE_NUMBER,
                                        unrecon_journal_no_parental_r.C_JE_EFFECTIVE_DATE,
                                        unrecon_journal_no_parental_r.C_JE_POSTED_DATE,
                                        unrecon_journal_no_parental_r.C_JE_JOURNAL_ENTRY_NAME,
                                        unrecon_journal_no_parental_r.C_JE_LINE_TYPE,
                                        unrecon_journal_no_parental_r.C_JE_STATUS,
                                        unrecon_journal_no_parental_r.C_JE_CURRENCY,
                                        --xxd_format_amount (unrecon_journal_no_parental_r.C_JE_TRANS_AMOUNT),
                                        --xxd_format_amount (unrecon_journal_no_parental_r.C_JE_AMOUNT_NO_PAR));
                                        unrecon_journal_no_parental_r.C_JE_TRANS_AMOUNT,
                                        unrecon_journal_no_parental_r.C_JE_AMOUNT_NO_PAR);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        --ROLLBACK;
                        lv_error_flag   := 'E';
                END;
            END LOOP;

            /*lc_detail_total :=
                  RPAD ('Total Amount', 159)
               || xxd_format_amount (ln_sum_journal_no_par_amt);*/

            --lc_detail_view := 'Unreconciled Journal Entries - Reversal line this month, original entry previous month:';

            FOR unrecon_journal_parental_r
                IN unrecon_journal_parental_c (lc_bank_curr_code,
                                               lc_gl_curr_code,
                                               ln_set_of_books_id,
                                               p_bank_account_id,
                                               ln_asset_cc_id,
                                               ln_cash_clearing_ccid,
                                               p_from_date,
                                               p_as_of_date,
                                               lv_period_name)
            LOOP
                BEGIN
                    INSERT INTO XXDO.XXD_GL_RECON_REP_GT (Description,
                                                          Short_Code,
                                                          je_line_num,
                                                          je_effective_date,
                                                          je_posted_date,
                                                          je_entry_name,
                                                          je_line_type,
                                                          Status,
                                                          Currency,
                                                          Amount,
                                                          Accounted_Amt)
                             VALUES (
                                        'Unreconciled Journal Entries - Reversal line this month, original entry previous month',
                                        'UJERLTMOEPM_9',
                                        unrecon_journal_parental_r.C_JE_LINE_NUMBER,
                                        unrecon_journal_parental_r.C_JE_EFFECTIVE_DATE,
                                        unrecon_journal_parental_r.C_JE_POSTED_DATE,
                                        unrecon_journal_parental_r.C_JE_JOURNAL_ENTRY_NAME,
                                        unrecon_journal_parental_r.C_JE_LINE_TYPE,
                                        unrecon_journal_parental_r.C_JE_STATUS,
                                        unrecon_journal_parental_r.C_JE_CURRENCY,
                                        --xxd_format_amount (unrecon_journal_parental_r.C_JE_TRANS_AMOUNT),
                                        --xxd_format_amount (unrecon_journal_parental_r.C_JE_AMOUNT_PAR));
                                        unrecon_journal_parental_r.C_JE_TRANS_AMOUNT,
                                        unrecon_journal_parental_r.C_JE_AMOUNT_PAR);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        --ROLLBACK;
                        lv_error_flag   := 'E';
                END;
            END LOOP;


            /*lc_detail_total :=
                  RPAD ('Total Amount', 159)
               || xxd_format_amount (ln_sum_journal_par_amt);*/

            -- lc_detail_view := 'Lines Marked As Errors:';

            FOR lines_errors_r
                IN lines_errors_c (p_bank_account_id,
                                   p_from_date,
                                   p_as_of_date)
            LOOP
                BEGIN
                    INSERT INTO XXDO.XXD_GL_RECON_REP_GT (
                                    Description,
                                    Short_Code,
                                    err_statement,
                                    err_statement_date,
                                    err_transaction_date,
                                    err_transaction_type,
                                    err_line_num,
                                    Status,
                                    Currency,
                                    Amount,
                                    Accounted_Amt)
                             VALUES ('Lines Marked As Errors',
                                     'LMAE_10',
                                     lines_errors_r.C_ERR_STMT_NUMBER,
                                     lines_errors_r.C_ERR_STATEMENT_DATE,
                                     lines_errors_r.C_ERR_TRANSACTION_DATE,
                                     lines_errors_r.C_ERR_TRX_TYPE,
                                     lines_errors_r.C_ERR_LINE_NUMBER,
                                     lines_errors_r.C_ERR_STATUS,
                                     lines_errors_r.C_ERR_CURRENCY,
                                     --xxd_format_amount (lines_errors_r.C_ERR_TRANS_AMOUNT),
                                     --xxd_format_amount (lines_errors_r.C_ERROR_AMOUNT));
                                     lines_errors_r.C_ERR_TRANS_AMOUNT,
                                     lines_errors_r.C_ERROR_AMOUNT);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        --ROLLBACK;
                        lv_error_flag   := 'E';
                END;
            END LOOP;

            /*lc_detail_total :=
                  RPAD ('Total Lines Marked As Errors', 173)
               || xxd_format_amount (ln_sum_line_errors);*/
            --lc_detail_view := 'General Ledger Cash Account Balance for CASH:';

            FOR gl_balances_cash_r
                IN gl_balances_cash_c (ln_set_of_books_id,
                                       lc_bank_curr_code,
                                       ln_chart_of_acct_id,
                                       p_from_Date,
                                       p_as_of_date,
                                       ln_asset_cc_id)
            LOOP
                BEGIN
                    INSERT INTO XXDO.XXD_GL_RECON_REP_GT (Description, Short_Code, gl_account_comb
                                                          , Amount)
                         VALUES ('General Ledger Cash Account Balance for CASH', 'GLCABFC_11', gl_balances_cash_r.C_GL_ACCOUNT
                                 , gl_balances_cash_r.C_END_BAL_CASH);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        --ROLLBACK;
                        lv_error_flag   := 'E';
                END;
            END LOOP;

            /*lc_detail_total :=
               RPAD ('Total Amount', 48) || xxd_format_amount (ln_sum_cash);*/
            -- lc_detail_view := 'General Ledger Cash Account Balance for CLEARING:';

            FOR gl_balances_clearing_r
                IN gl_balances_clearing_c (ln_set_of_books_id,
                                           lc_bank_curr_code,
                                           ln_chart_of_acct_id,
                                           p_from_date,
                                           p_as_of_date,
                                           ln_cash_clearing_ccid)
            LOOP
                BEGIN
                    INSERT INTO XXDO.XXD_GL_RECON_REP_GT (Description, Short_Code, gl_account_comb
                                                          , Amount)
                         VALUES ('General Ledger Cash Account Balance for CLEARING', 'GLCABFCLR_12', gl_balances_clearing_r.C_GL_ACCOUNT
                                 , --xxd_format_amount (gl_balances_clearing_r.C_END_BAL_ClEARING)
                                   gl_balances_clearing_r.C_END_BAL_ClEARING);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        --ROLLBACK;
                        lv_error_flag   := 'E';
                END;
            END LOOP;

            /*lc_detail_total :=
               RPAD ('Total Amount', 48) || xxd_format_amount (ln_sum_clearing);*/

            --lc_detail_view := 'Unreconciled Bank Statement Lines - Payments:';

            FOR unrecon_statement_debit_r
                IN unrecon_statement_debit_c (p_bank_account_id,
                                              p_from_date,
                                              p_as_of_date)
            LOOP
                BEGIN
                    INSERT INTO XXDO.XXD_GL_RECON_REP_GT (Description, Short_Code, statement_num, statement_line_desc, statement_transaction_code, statement_date, gl_date, statement_trx_type, statement_line_num, status, Statement_eff_Date, bank_trx_number
                                                          , Amount)
                         VALUES ('Unreconciled Bank Statement Lines - Payments', 'UBSLP_13', unrecon_statement_debit_r.C_STATEMENT_NUMBER, unrecon_statement_debit_r.line_desc, unrecon_statement_debit_r.trx_code, unrecon_statement_debit_r.C_STATEMENT_DATE, unrecon_statement_debit_r.C_GL_DATE, unrecon_statement_debit_r.C_TRX_TYPE, unrecon_statement_debit_r.C_LINE_NUMBER, unrecon_statement_debit_r.C_STATUS, unrecon_statement_debit_r.C_EFFECTIVE_DATE, unrecon_statement_debit_r.C_BANK_TRX_NUMBER
                                 , --xxd_format_amount (unrecon_statement_debit_r.C_PAY_AMOUNT)
                                   unrecon_statement_debit_r.C_PAY_AMOUNT);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        --ROLLBACK;
                        lv_error_flag   := 'E';
                END;
            END LOOP;

            /*lc_detail_total :=
               RPAD ('Total Amount', 144) || xxd_format_amount (ln_sum_pay_amt); */

            -- lc_detail_view :=   'Statement lines, matched to a Transaction created/cleared in the next period :';

            FOR statement_recon_next_period_r
                IN statement_recon_next_period_c (p_bank_account_id,
                                                  p_from_date,
                                                  p_as_of_date)
            LOOP
                BEGIN
                    INSERT INTO XXDO.XXD_GL_RECON_REP_GT (Description, Short_Code, statement_num, statement_line_desc, statement_transaction_code, statement_date, gl_date, statement_trx_type, statement_line_num, status, Statement_eff_Date, bank_trx_number
                                                          , Amount)
                             VALUES (
                                        'Statement lines, matched to a Transaction created/cleared in the next period',
                                        'SLMTATCORCITNP_14',
                                        statement_recon_next_period_r.C_STATEMENT_NUMBER,
                                        statement_recon_next_period_r.line_desc,
                                        statement_recon_next_period_r.trx_code,
                                        statement_recon_next_period_r.C_STATEMENT_DATE,
                                        statement_recon_next_period_r.C_GL_DATE,
                                        statement_recon_next_period_r.C_TRX_TYPE,
                                        statement_recon_next_period_r.C_LINE_NUMBER,
                                        statement_recon_next_period_r.C_STATUS,
                                        statement_recon_next_period_r.C_EFFECTIVE_DATE,
                                        statement_recon_next_period_r.C_BANK_TRX_NUMBER,
                                        --xxd_format_amount (statement_recon_next_period_r.C_DEP_AMOUNT)
                                        statement_recon_next_period_r.C_DEP_AMOUNT);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        --ROLLBACK;
                        lv_error_flag   := 'E';
                END;
            END LOOP;
        /*lc_detail_total :=
              RPAD ('Total Amount', 144)
           || xxd_format_amount (ln_sum_stmt_next_period);*/

        END IF;

        --lc_detail_view := 'Detail of Checks voided in current month, that were outstanding in the prior month end.';

        FOR payments_void_curr_r
            IN payments_void_curr_c (lc_bank_curr_code, lc_gl_curr_code, p_bank_account_id
                                     , p_from_date, p_as_of_date)
        LOOP
            BEGIN
                INSERT INTO XXDO.XXD_GL_RECON_REP_GT (Description,
                                                      Short_Code,
                                                      Payment_num,
                                                      GL_Date,
                                                      Payment_Date,
                                                      supplier_Name,
                                                      Payment_Method,
                                                      Status,
                                                      Currency,
                                                      Amount,
                                                      Accounted_Amt)
                         VALUES (
                                    'Detail of Checks voided in current month, that were outstanding in the prior month end',
                                    'DOCVICMTWOITPME_15',
                                    payments_void_curr_r.C_AP_PAYMENT_NUMBER,
                                    payments_void_curr_r.C_AP_GL_DATE,
                                    payments_void_curr_r.C_AP_PAYMENT_DATE,
                                    payments_void_curr_r.C_AP_SUPPLIER_NAME,
                                    payments_void_curr_r.C_AP_PAYMENT_METHOD,
                                    payments_void_curr_r.C_AP_STATUS,
                                    payments_void_curr_r.C_AP_CURRENCY,
                                    --xxd_format_amount (payments_void_curr_r.C_AP_TRANS_AMOUNT),
                                    --xxd_format_amount (payments_void_curr_r.C_AP_AMOUNT));
                                    payments_void_curr_r.C_AP_TRANS_AMOUNT,
                                    payments_void_curr_r.C_AP_AMOUNT);
            EXCEPTION
                WHEN OTHERS
                THEN
                    --ROLLBACK;
                    lv_error_flag   := 'E';
            END;
        END LOOP;


        /*lc_detail_total :=
              RPAD ('Total Amount', 158)
           || xxd_format_amount (ln_sum_void_curr_amt);*/

        --lc_detail_view :=  'Transactions where Matched line amount and GL amount are different::';

        FOR payment_recon_mismtch_r
            IN payment_recon_mismtch_c (p_bank_account_id,
                                        p_from_date,
                                        p_as_of_date)
        LOOP
            BEGIN
                INSERT INTO XXDO.XXD_GL_RECON_REP_GT (Description, Short_Code, statement_num, statement_line_desc, statement_transaction_code, statement_date, gl_date, statement_trx_type, statement_line_num, status, Statement_eff_Date, bank_trx_number
                                                      , Amount)
                     VALUES ('Transactions where Matched line amount and GL amount are different', 'TWMLAAGAAD_16', payment_recon_mismtch_r.C_STATEMENT_NUMBER, payment_recon_mismtch_r.line_desc, payment_recon_mismtch_r.trx_code, payment_recon_mismtch_r.C_STATEMENT_DATE, payment_recon_mismtch_r.C_GL_DATE, payment_recon_mismtch_r.C_TRX_TYPE, payment_recon_mismtch_r.C_LINE_NUMBER, payment_recon_mismtch_r.C_STATUS, payment_recon_mismtch_r.C_EFFECTIVE_DATE, payment_recon_mismtch_r.C_BANK_TRX_NUMBER
                             , --xxd_format_amount (payment_recon_mismtch_r.C_PAY_AMOUNT)
                               payment_recon_mismtch_r.C_PAY_AMOUNT);
            EXCEPTION
                WHEN OTHERS
                THEN
                    --ROLLBACK;
                    lv_error_flag   := 'E';
            END;
        END LOOP;

        IF lv_error_flag = 'E'
        THEN
            ROLLBACK;
        ELSE
            COMMIT;
        END IF;
    /*lc_detail_total :=
          RPAD ('Total Amount', 144)
       || xxd_format_amount (ln_sum_ce_line_mismtch);*/
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Error - ' || SQLERRM);
            p_sum_error_msg   := 'Error - ' || SQLERRM;
            p_sum_status      := 'Error';
            ROLLBACK;
            RETURN;
    END;
END XXD_GL_RECON_EXCEL_REPORT_PKG;
/
