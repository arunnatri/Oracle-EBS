--
-- XXDO_DEC_CUST_STMT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:05 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_DEC_CUST_STMT_PKG"
IS
    PROCEDURE XXDO_CUST_DEC_MAIN (p_error_code IN OUT NUMBER, p_error_message IN OUT NUMBER, P_REP_TYPE VARCHAR2, --Report Type
                                                                                                                  P_REPORTING_LEVEL VARCHAR2, --Reporting Level
                                                                                                                                              P_REPORTING_ENTITY_ID NUMBER, --Reporting Context
                                                                                                                                                                            p_ca_set_of_books_id NUMBER, --Ledger Currency
                                                                                                                                                                                                         p_coaid NUMBER, --Chart of Accounts
                                                                                                                                                                                                                         p_in_bal_segment_low VARCHAR2, --Company Segment Low
                                                                                                                                                                                                                                                        p_in_bal_segment_high VARCHAR2, --Company Segment High
                                                                                                                                                                                                                                                                                        p_in_as_of_date_low VARCHAR2, --As Of GL Date
                                                                                                                                                                                                                                                                                                                      P_MASS_REPRINT VARCHAR2, --Report Type
                                                                                                                                                                                                                                                                                                                                               p_in_summary_option_low VARCHAR2, --Report Summary
                                                                                                                                                                                                                                                                                                                                                                                 p_in_format_option_low VARCHAR2, --Report Format
                                                                                                                                                                                                                                                                                                                                                                                                                  p_in_bucket_type_low VARCHAR2, --Aging Bucket Name
                                                                                                                                                                                                                                                                                                                                                                                                                                                 p_credit_option VARCHAR2, --Show Open Credits
                                                                                                                                                                                                                                                                                                                                                                                                                                                                           p_risk_option VARCHAR2, --Show Receipts At Risk
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   p_in_currency VARCHAR2, --Entered Currency
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           p_in_customer_name_low VARCHAR2, --Customer Name Low
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            p_in_customer_name_high VARCHAR2, --Customer Name High
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              p_in_customer_num_low VARCHAR2, --Customer Number Low
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              p_in_customer_num_high VARCHAR2, --Customer Number High
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               p_in_cust_account_name_low VARCHAR2, --Customer Account Desc Low
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    p_in_cust_account_name_high VARCHAR2, --Customer Account Desc High
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          p_in_amt_due_low NUMBER, --Balance Due Low
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   p_in_amt_due_high NUMBER, --Balance Due High
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             p_in_invoice_type_low VARCHAR2, --Transaction Type Low
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             p_in_invoice_type_high VARCHAR2, --Transaction Type High
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              P_COUNTRY VARCHAR2, --Country
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  P_COLLECTOR_ID NUMBER, --Collector
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         p_error_email VARCHAR2
                                  ,                     --Error Report Mail id
                                    p_max_limit NUMBER, p_max_sets NUMBER)
    IS
        CURSOR cur_cust IS
            SELECT xxdo.cust_name_inv, xxdo.cust_no_inv, xxdo.sort_field1_inv,
                   xxdo.class_inv sort_field2_inv, 2000 inv_tid_inv, NVL (stmts.site_use_id, xxdo.contact_site_id_inv) contact_site_id_inv,
                   xxdo.cust_state_inv, xxdo.cust_city_inv, 3000 addr_id_inv,
                   xxdo.cust_id_inv, xxdo.payment_sched_id_inv, xxdo.class_inv,
                   xxdo.due_date_inv, xxdo.amt_due_remaining_inv, xxdo.invnum,
                   xxdo.days_past_due, xxdo.amount_adjusted_inv, xxdo.amount_applied_inv,
                   xxdo.amount_credited_inv, xxdo.gl_date_inv, xxdo.data_converted_inv,
                   xxdo.ps_exchange_rate_inv, xxdo.company_inv, xxdo.cons_billing_number,
                   xxdo.invoice_type_inv
              FROM hz_customer_profiles hz_profile,
                   (SELECT site.site_use_id, site.cust_acct_site_id, acct_site.cust_account_id,
                           SITE_USE_CODE
                      FROM hz_cust_site_uses_all site, hz_cust_acct_sites_all acct_site
                     WHERE     site.cust_acct_site_id =
                               acct_site.cust_acct_site_id
                           AND site.STATUS = 'A'
                           AND site.SITE_USE_CODE = 'STMTS') stmts,
                   (SELECT SUBSTRB (party.party_name, 1, 50) cust_name_inv, cust_acct.account_number cust_no_inv, c.SEGMENT1 || ' 
' || c.SEGMENT2 || ' 
' || c.SEGMENT3 || ' 
' || c.SEGMENT4 || ' 
' || c.SEGMENT5 || ' 
' || c.SEGMENT6 || ' 
' || c.SEGMENT7 || ' 
' || c.SEGMENT8 sort_field1_inv,
                           arpt_sql_func_util.get_org_trx_type_details (ps.cust_trx_type_id, ps.org_id) sort_field2_inv, 2000 inv_tid_inv, site.site_use_id contact_site_id_inv,
                           loc.state cust_state_inv, loc.city cust_city_inv, 3000 addr_id_inv,
                           NVL (cust_acct.cust_account_id, -999) cust_id_inv, ps.payment_schedule_id payment_sched_id_inv, ps.class class_inv,
                           ps.due_date due_date_inv, amt_due_remaining_inv, ps.trx_number invnum,
                           CEIL (TO_DATE (fnd_date.canonical_to_date (p_in_as_of_date_low), 'DD-MON-YYYY') - ps.due_date) days_past_due, ps.amount_adjusted amount_adjusted_inv, ps.amount_applied amount_applied_inv,
                           ps.amount_credited amount_credited_inv, ps.gl_date gl_date_inv, DECODE (ps.invoice_currency_code, NULL, NULL, DECODE (ps.exchange_rate, NULL, '*', NULL)) data_converted_inv,
                           NVL (ps.exchange_rate, 1) ps_exchange_rate_inv, c.SEGMENT1 company_inv, TO_CHAR (NULL) cons_billing_number,
                           arpt_sql_func_util.get_org_trx_type_details (ps.cust_trx_type_id, ps.org_id) invoice_type_inv
                      FROM hz_cust_accounts cust_acct,
                           hz_parties party,
                           (  SELECT a.customer_id, a.customer_site_use_id, a.customer_trx_id,
                                     a.payment_schedule_id, a.class, SUM (a.primary_salesrep_id) primary_salesrep_id,
                                     a.due_date, SUM (a.amount_due_remaining) amt_due_remaining_inv, a.trx_number,
                                     a.amount_adjusted, a.amount_applied, a.amount_credited,
                                     a.amount_adjusted_pending, a.gl_date, a.cust_trx_type_id,
                                     a.org_id, a.invoice_currency_code, a.exchange_rate,
                                     SUM (a.cons_inv_id) cons_inv_id
                                FROM (  SELECT ps.customer_id, ps.customer_site_use_id, ps.customer_trx_id,
                                               ps.payment_schedule_id, ps.class, 0 primary_salesrep_id,
                                               ps.due_date, NVL (SUM (DECODE ('Y', 'Y', NVL (adj.acctd_amount, 0), adj.amount)), 0) * (-1) amount_due_remaining, ps.trx_number,
                                               ps.amount_adjusted, ps.amount_applied, ps.amount_credited,
                                               ps.amount_adjusted_pending, ps.gl_date, ps.cust_trx_type_id,
                                               ps.org_id, ps.invoice_currency_code, NVL (ps.exchange_rate, 1) exchange_rate,
                                               0 cons_inv_id
                                          FROM ar_payment_schedules_all ps, ar_adjustments_all adj
                                         WHERE     ps.gl_date <=
                                                   fnd_date.canonical_to_date (
                                                       p_in_as_of_date_low)
                                               AND ps.customer_id > 0
                                               AND ps.gl_date_closed >
                                                   fnd_date.canonical_to_date (
                                                       p_in_as_of_date_low)
                                               AND DECODE (
                                                       NULL,
                                                       NULL, ps.invoice_currency_code,
                                                       NULL) =
                                                   ps.invoice_currency_code
                                               AND adj.payment_schedule_id =
                                                   ps.payment_schedule_id
                                               AND adj.status = 'A'
                                               AND adj.gl_date >
                                                   fnd_date.canonical_to_date (
                                                       p_in_as_of_date_low)
                                               AND ps.ORG_ID =
                                                   p_reporting_entity_id
                                               AND adj.ORG_ID =
                                                   p_reporting_entity_id
                                      GROUP BY ps.customer_id, ps.customer_site_use_id, ps.customer_trx_id,
                                               ps.class, ps.due_date, ps.trx_number,
                                               ps.amount_adjusted, ps.amount_applied, ps.amount_credited,
                                               ps.amount_adjusted_pending, ps.gl_date, ps.cust_trx_type_id,
                                               ps.org_id, ps.invoice_currency_code, NVL (ps.exchange_rate, 1),
                                               ps.payment_schedule_id
                                      UNION ALL
                                        SELECT ps.customer_id, ps.customer_site_use_id, ps.customer_trx_id,
                                               ps.payment_schedule_id, ps.class, 0 primary_salesrep_id,
                                               ps.due_date, NVL (SUM (DECODE ('Y', 'Y', (DECODE (ps.class, 'CM', DECODE (app.application_type, 'CM', app.acctd_amount_applied_from, app.acctd_amount_applied_to), app.acctd_amount_applied_to) + NVL (app.acctd_earned_discount_taken, 0) + NVL (app.acctd_unearned_discount_taken, 0)), (app.amount_applied + NVL (app.earned_discount_taken, 0) + NVL (app.unearned_discount_taken, 0))) * DECODE (ps.class, 'CM', DECODE (app.application_type, 'CM', -1, 1), 1)), 0) amount_due_remaining_inv, ps.trx_number,
                                               ps.amount_adjusted, ps.amount_applied, ps.amount_credited,
                                               ps.amount_adjusted_pending, ps.gl_date gl_date_inv, ps.cust_trx_type_id,
                                               ps.org_id, ps.invoice_currency_code, NVL (ps.exchange_rate, 1) exchange_rate,
                                               0 cons_inv_id
                                          FROM ar_payment_schedules_all ps, ar_receivable_applications_all app
                                         WHERE     ps.gl_date <=
                                                   fnd_date.canonical_to_date (
                                                       p_in_as_of_date_low)
                                               AND ps.customer_id > 0
                                               AND ps.gl_date_closed >
                                                   fnd_date.canonical_to_date (
                                                       p_in_as_of_date_low)
                                               AND DECODE (
                                                       NULL,
                                                       NULL, ps.invoice_currency_code,
                                                       NULL) =
                                                   ps.invoice_currency_code
                                               AND (app.applied_payment_schedule_id = ps.payment_schedule_id OR app.payment_schedule_id = ps.payment_schedule_id)
                                               AND app.status = 'APP'
                                               AND NVL (app.confirmed_flag, 'Y') =
                                                   'Y'
                                               AND app.gl_date >
                                                   fnd_date.canonical_to_date (
                                                       p_in_as_of_date_low)
                                               AND ps.ORG_ID =
                                                   p_reporting_entity_id
                                               AND app.ORG_ID =
                                                   p_reporting_entity_id
                                      GROUP BY ps.customer_id, ps.customer_site_use_id, ps.customer_trx_id,
                                               ps.class, ps.due_date, ps.trx_number,
                                               ps.amount_adjusted, ps.amount_applied, ps.amount_credited,
                                               ps.amount_adjusted_pending, ps.gl_date, ps.cust_trx_type_id,
                                               ps.org_id, ps.invoice_currency_code, NVL (ps.exchange_rate, 1),
                                               ps.payment_schedule_id
                                      UNION ALL
                                      SELECT ps.customer_id, ps.customer_site_use_id, ps.customer_trx_id,
                                             ps.payment_schedule_id, ps.class class_inv, NVL (ct.primary_salesrep_id, -3) primary_salesrep_id,
                                             ps.due_date due_date_inv, DECODE ('Y', 'Y', ps.acctd_amount_due_remaining, ps.amount_due_remaining) amt_due_remaining_inv, ps.trx_number,
                                             ps.amount_adjusted, ps.amount_applied, ps.amount_credited,
                                             ps.amount_adjusted_pending, ps.gl_date, ps.cust_trx_type_id,
                                             ps.org_id, ps.invoice_currency_code, NVL (ps.exchange_rate, 1) exchange_rate,
                                             ps.cons_inv_id
                                        FROM ar_payment_schedules_all ps, ra_customer_trx_all ct
                                       WHERE     ps.gl_date <=
                                                 fnd_date.canonical_to_date (
                                                     p_in_as_of_date_low)
                                             AND ps.gl_date_closed >
                                                 fnd_date.canonical_to_date (
                                                     p_in_as_of_date_low)
                                             AND DECODE (
                                                     NULL,
                                                     NULL, ps.invoice_currency_code,
                                                     NULL) =
                                                 ps.invoice_currency_code
                                             AND ps.customer_trx_id =
                                                 ct.customer_trx_id
                                             AND ps.ORG_ID =
                                                 p_reporting_entity_id
                                             AND ct.ORG_ID =
                                                 p_reporting_entity_id) a
                            GROUP BY a.customer_id, a.customer_site_use_id, a.customer_trx_id,
                                     a.payment_schedule_id, a.class, a.due_date,
                                     a.trx_number, a.amount_adjusted, a.amount_applied,
                                     a.amount_credited, a.amount_adjusted_pending, a.gl_date,
                                     a.cust_trx_type_id, a.org_id, a.invoice_currency_code,
                                     a.exchange_rate) ps,
                           hz_cust_site_uses_all site,
                           hz_cust_acct_sites_all acct_site,
                           hz_party_sites party_site,
                           hz_locations loc,
                           ra_cust_trx_line_gl_dist_all gld,
                           xla_distribution_links lk,
                           xla_ae_lines ae,
                           ar_dispute_history dh,
                           gl_code_combinations c
                     WHERE     UPPER (
                                   RTRIM (RPAD (p_in_summary_option_low, 1))) =
                               'I'
                           AND ps.customer_site_use_id = site.site_use_id
                           AND site.cust_acct_site_id =
                               acct_site.cust_acct_site_id
                           AND acct_site.party_site_id =
                               party_site.party_site_id
                           AND loc.location_id = party_site.location_id
                           AND gld.account_class = 'REC'
                           AND gld.latest_rec_flag = 'Y'
                           AND gld.cust_trx_line_gl_dist_id =
                               lk.source_distribution_id_num_1(+)
                           AND lk.source_distribution_type(+) =
                               'RA_CUST_TRX_LINE_GL_DIST_ALL'
                           AND lk.application_id(+) = 222
                           AND ae.application_id(+) = 222
                           AND lk.ae_header_id = ae.ae_header_id(+)
                           AND lk.ae_line_num = ae.ae_line_num(+)
                           AND DECODE (lk.accounting_line_code,
                                       '', 'Y',
                                       'CM_EXCH_GAIN_LOSS', 'N',
                                       'AUTO_GEN_GAIN_LOSS', 'N',
                                       'Y') =
                               'Y'
                           AND DECODE (
                                   ae.ledger_id,
                                   '', DECODE (gld.posting_control_id,
                                               -3, -999999,
                                               gld.code_combination_id),
                                   gld.set_of_books_id, ae.code_combination_id,
                                   -999999) =
                               c.code_combination_id
                           AND ps.payment_schedule_id =
                               dh.payment_schedule_id(+)
                           AND ps.org_id = p_reporting_entity_id
                           AND fnd_date.canonical_to_date (
                                   p_in_as_of_date_low) >=
                               NVL (
                                   dh.start_date(+),
                                   fnd_date.canonical_to_date (
                                       p_in_as_of_date_low))
                           AND fnd_date.canonical_to_date (
                                   p_in_as_of_date_low) <
                               NVL (
                                   dh.end_date(+),
                                     fnd_date.canonical_to_date (
                                         p_in_as_of_date_low)
                                   + 1)
                           AND cust_acct.party_id = party.party_id
                           AND cust_acct.account_number >=
                               NVL (p_in_customer_num_low,
                                    cust_acct.account_number)
                           AND cust_acct.account_number <=
                               NVL (p_in_customer_num_high,
                                    cust_acct.account_number)
                           AND ps.customer_id = cust_acct.cust_account_id
                           AND ps.customer_trx_id = gld.customer_trx_id
                           AND gld.ORG_ID = p_reporting_entity_id
                           AND NVL (acct_site.ORG_ID, p_reporting_entity_id) =
                               p_reporting_entity_id
                    UNION ALL
                      SELECT /*+ LEADING(ps) */
                             SUBSTRB (NVL (party.party_name, NULL), 1, 50) cust_name_inv, cust_acct.account_number cust_no_inv, c.SEGMENT1 || ' 
' || c.SEGMENT2 || ' 
' || c.SEGMENT3 || ' 
' || c.SEGMENT4 || ' 
' || c.SEGMENT5 || ' 
' || c.SEGMENT6 || ' 
' || c.SEGMENT7 || ' 
' || c.SEGMENT8,
                             NULL, c.code_combination_id, site.site_use_id,
                             loc.state cust_state_inv, loc.city cust_state_inv, 3000 addr_id_inv,
                             NVL (cust_acct.cust_account_id, -999) cust_id_inv, ps.payment_schedule_id, DECODE (app.applied_payment_schedule_id, -4, 'CLAIM', ps.class),
                             ps.due_date, DECODE ('Y', 'Y', NVL (-SUM (app.acctd_amount_applied_from), 0), NVL (-SUM (app.amount_applied), 0)), ps.trx_number,
                             CEIL (fnd_date.canonical_to_date (p_in_as_of_date_low) - ps.due_date), ps.amount_adjusted, ps.amount_applied,
                             ps.amount_credited, ps.gl_date, DECODE (ps.invoice_currency_code, NULL, NULL, DECODE (ps.exchange_rate, NULL, '*', NULL)),
                             NVL (ps.exchange_rate, 1), c.SEGMENT1 company_inv, TO_CHAR (NULL) cons_billing_number,
                             NULL
                        FROM hz_cust_accounts cust_acct, hz_parties party, ar_payment_schedules_all ps,
                             hz_cust_site_uses_all site, hz_cust_acct_sites_all acct_site, hz_party_sites party_site,
                             hz_locations loc, ar_receivable_applications_all app, gl_code_combinations c
                       WHERE     app.gl_date <=
                                 fnd_date.canonical_to_date (
                                     p_in_as_of_date_low)
                             AND UPPER (
                                     RTRIM (RPAD (p_in_summary_option_low, 1))) =
                                 'I'
                             AND ps.trx_number IS NOT NULL
                             AND ps.customer_id = cust_acct.cust_account_id(+)
                             AND ps.org_id = p_reporting_entity_id
                             AND cust_acct.party_id = party.party_id(+)
                             AND ps.cash_receipt_id = app.cash_receipt_id
                             AND app.code_combination_id =
                                 c.code_combination_id
                             AND app.status IN ('ACC', 'UNAPP', 'UNID',
                                                'OTHER ACC')
                             AND NVL (app.confirmed_flag, 'Y') = 'Y'
                             AND ps.customer_site_use_id = site.site_use_id(+)
                             AND site.cust_acct_site_id =
                                 acct_site.cust_acct_site_id(+)
                             AND acct_site.party_site_id =
                                 party_site.party_site_id(+)
                             AND loc.location_id(+) = party_site.location_id
                             AND ps.gl_date_closed >
                                 fnd_date.canonical_to_date (
                                     p_in_as_of_date_low)
                             AND ((app.reversal_gl_date IS NOT NULL AND ps.gl_date <= fnd_date.canonical_to_date (p_in_as_of_date_low)) OR app.reversal_gl_date IS NULL)
                             AND DECODE (NULL,
                                         NULL, ps.invoice_currency_code,
                                         NULL) =
                                 ps.invoice_currency_code
                             AND NVL (ps.receipt_confirmed_flag, 'Y') = 'Y'
                             AND cust_acct.account_number >=
                                 NVL (p_in_customer_num_low,
                                      cust_acct.account_number)
                             AND cust_acct.account_number <=
                                 NVL (p_in_customer_num_high,
                                      cust_acct.account_number)
                             AND ps.ORG_ID = p_reporting_entity_id
                             AND app.ORG_ID = p_reporting_entity_id
                             AND NVL (acct_site.ORG_ID, p_reporting_entity_id) =
                                 p_reporting_entity_id
                    GROUP BY party.party_name, cust_acct.account_number, site.site_use_id,
                             c.SEGMENT1 || ' 
' || c.SEGMENT2 || ' 
' || c.SEGMENT3 || ' 
' || c.SEGMENT4 || ' 
' || c.SEGMENT5 || ' 
' || c.SEGMENT6 || ' 
' || c.SEGMENT7 || ' 
' || c.SEGMENT8, c.code_combination_id, loc.state,
                             loc.city, acct_site.cust_acct_site_id, cust_acct.cust_account_id,
                             ps.payment_schedule_id, ps.due_date, ps.trx_number,
                             ps.amount_adjusted, ps.amount_applied, ps.amount_credited,
                             ps.gl_date, ps.amount_in_dispute, ps.amount_adjusted_pending,
                             ps.invoice_currency_code, ps.exchange_rate, DECODE (app.applied_payment_schedule_id, -4, 'CLAIM', ps.class),
                             c.SEGMENT1, DECODE (app.status,  'UNID', 'UNID',  'OTHER ACC', 'OTHER ACC',  'UNAPP'), TO_CHAR (NULL),
                             NULL
                    UNION ALL
                    SELECT SUBSTRB (NVL (party.party_name, NULL), 1, 50) cust_name_inv, cust_acct.account_number cust_no_inv, c.SEGMENT1 || ' 
' || c.SEGMENT2 || ' 
' || c.SEGMENT3 || ' 
' || c.SEGMENT4 || ' 
' || c.SEGMENT5 || ' 
' || c.SEGMENT6 || ' 
' || c.SEGMENT7 || ' 
' || c.SEGMENT8,
                           NULL, c.code_combination_id, site.site_use_id,
                           loc.state cust_state_inv, loc.city cust_city_inv, 3000 addr_id_inv,
                           NVL (cust_acct.cust_account_id, -999) cust_id_inv, ps.payment_schedule_id, NULL,
                           ps.due_date, DECODE ('Y', 'Y', crh.acctd_amount, crh.amount), ps.trx_number,
                           CEIL (fnd_date.canonical_to_date (p_in_as_of_date_low) - ps.due_date), ps.amount_adjusted, ps.amount_applied,
                           ps.amount_credited, crh.gl_date, DECODE (ps.invoice_currency_code, NULL, NULL, DECODE (crh.exchange_rate, NULL, '*', NULL)),
                           NVL (crh.exchange_rate, 1), c.SEGMENT1 company_inv, TO_CHAR (NULL) cons_billing_number,
                           NULL
                      FROM hz_cust_accounts cust_acct, hz_parties party, ar_payment_schedules_all ps,
                           hz_cust_site_uses_all site, hz_cust_acct_sites_all acct_site, hz_party_sites party_site,
                           hz_locations loc, ar_cash_receipts_all cr, ar_cash_receipt_history_all crh,
                           gl_code_combinations c
                     WHERE     crh.gl_date <=
                               fnd_date.canonical_to_date (
                                   p_in_as_of_date_low)
                           AND ps.trx_number IS NOT NULL
                           AND UPPER (
                                   RTRIM (RPAD (p_in_summary_option_low, 1))) =
                               'I'
                           AND 'NONE' != 'NONE'
                           AND ps.customer_id = cust_acct.cust_account_id(+)
                           AND cust_acct.party_id = party.party_id(+)
                           AND ps.cash_receipt_id = cr.cash_receipt_id
                           AND ps.org_id = p_reporting_entity_id
                           AND cr.cash_receipt_id = crh.cash_receipt_id
                           AND crh.account_code_combination_id =
                               c.code_combination_id
                           AND ps.customer_site_use_id = site.site_use_id(+)
                           AND site.cust_acct_site_id =
                               acct_site.cust_acct_site_id(+)
                           AND acct_site.party_site_id =
                               party_site.party_site_id(+)
                           AND loc.location_id(+) = party_site.location_id
                           AND DECODE (NULL,
                                       NULL, ps.invoice_currency_code,
                                       NULL) =
                               ps.invoice_currency_code
                           AND (crh.current_record_flag = 'Y' OR crh.reversal_gl_date > fnd_date.canonical_to_date (p_in_as_of_date_low))
                           AND crh.status NOT IN
                                   (DECODE (crh.factor_flag,  'Y', 'RISK_ELIMINATED',  'N', 'CLEARED'), 'REVERSED')
                           AND NOT EXISTS
                                   (SELECT 'x'
                                      FROM ar_receivable_applications_all ra
                                     WHERE     ra.cash_receipt_id =
                                               cr.cash_receipt_id
                                           AND ra.status = 'ACTIVITY'
                                           AND applied_payment_schedule_id =
                                               -2)
                           AND cust_acct.account_number >=
                               NVL (p_in_customer_num_low,
                                    cust_acct.account_number)
                           AND cust_acct.account_number <=
                               NVL (p_in_customer_num_high,
                                    cust_acct.account_number)
                           AND ps.ORG_ID = p_reporting_entity_id
                           AND crh.ORG_ID = p_reporting_entity_id
                           AND cr.ORG_ID = p_reporting_entity_id
                           AND NVL (acct_site.ORG_ID, p_reporting_entity_id) =
                               p_reporting_entity_id
                    UNION ALL
                    SELECT SUBSTRB (party.party_name, 1, 50) cust_name_inv, cust_acct.account_number cust_no_inv, c.SEGMENT1 || ' 
' || c.SEGMENT2 || ' 
' || c.SEGMENT3 || ' 
' || c.SEGMENT4 || ' 
' || c.SEGMENT5 || ' 
' || c.SEGMENT6 || ' 
' || c.SEGMENT7 || ' 
' || c.SEGMENT8 sort_field1_inv,
                           arpt_sql_func_util.get_org_trx_type_details (ps.cust_trx_type_id, ps.org_id) sort_field2_inv, 2000 inv_tid_inv, site.site_use_id contact_site_id_inv,
                           loc.state cust_state_inv, loc.city cust_city_inv, 3000 addr_id_inv,
                           NVL (cust_acct.cust_account_id, -999) cust_id_inv, ps.payment_schedule_id payment_sched_id_inv, ps.class class_inv,
                           ps.due_date due_date_inv, DECODE ('Y', 'Y', ps.acctd_amount_due_remaining, ps.amount_due_remaining) amt_due_remaining_inv, ps.trx_number invnum,
                           CEIL (fnd_date.canonical_to_date (p_in_as_of_date_low) - ps.due_date) days_past_due, ps.amount_adjusted amount_adjusted_inv, ps.amount_applied amount_applied_inv,
                           ps.amount_credited amount_credited_inv, ps.gl_date gl_date_inv, DECODE (ps.invoice_currency_code, NULL, NULL, DECODE (ps.exchange_rate, NULL, '*', NULL)) data_converted_inv,
                           NVL (ps.exchange_rate, 1) ps_exchange_rate_inv, c.SEGMENT1 company_inv, TO_CHAR (NULL) cons_billing_number,
                           arpt_sql_func_util.get_org_trx_type_details (ps.cust_trx_type_id, ps.org_id) invoice_type_inv
                      FROM hz_cust_accounts cust_acct, hz_parties party, ar_payment_schedules_all ps,
                           hz_cust_site_uses_all site, hz_cust_acct_sites_all acct_site, hz_party_sites party_site,
                           hz_locations loc, ar_transaction_history_all th, ar_xla_ard_lines_v dist,
                           gl_code_combinations c
                     WHERE     ps.gl_date <=
                               fnd_date.canonical_to_date (
                                   p_in_as_of_date_low)
                           AND UPPER (
                                   RTRIM (RPAD (p_in_summary_option_low, 1))) =
                               'I'
                           AND ps.customer_site_use_id = site.site_use_id
                           AND ps.org_id = p_reporting_entity_id
                           AND site.cust_acct_site_id =
                               acct_site.cust_acct_site_id
                           AND acct_site.party_site_id =
                               party_site.party_site_id
                           AND loc.location_id = party_site.location_id
                           AND ps.gl_date_closed >
                               fnd_date.canonical_to_date (
                                   p_in_as_of_date_low)
                           AND ps.class = 'BR'
                           AND DECODE (NULL,
                                       NULL, ps.invoice_currency_code,
                                       NULL) =
                               ps.invoice_currency_code
                           AND th.transaction_history_id =
                               (SELECT MAX (transaction_history_id)
                                  FROM ar_transaction_history th2, ar_xla_ard_lines_v dist2
                                 WHERE     th2.transaction_history_id =
                                           dist2.source_id
                                       AND dist2.source_table = 'TH'
                                       AND th2.gl_date <=
                                           fnd_date.canonical_to_date (
                                               p_in_as_of_date_low)
                                       AND dist2.amount_dr IS NOT NULL
                                       AND th2.customer_trx_id =
                                           ps.customer_trx_id)
                           AND th.transaction_history_id = dist.source_id
                           AND dist.source_table = 'TH'
                           AND dist.amount_dr IS NOT NULL
                           AND dist.source_table_secondary IS NULL
                           AND dist.code_combination_id =
                               c.code_combination_id
                           AND cust_acct.party_id = party.party_id
                           AND cust_acct.account_number >=
                               NVL (p_in_customer_num_low,
                                    cust_acct.account_number)
                           AND cust_acct.account_number <=
                               NVL (p_in_customer_num_high,
                                    cust_acct.account_number)
                           AND ps.customer_id = cust_acct.cust_account_id
                           AND ps.customer_trx_id = th.customer_trx_id
                           AND ps.ORG_ID = p_reporting_entity_id
                           AND NVL (acct_site.ORG_ID, p_reporting_entity_id) =
                               p_reporting_entity_id
                    ORDER BY                                            -- 30,
                             1, 2, 13 DESC) xxdo
             WHERE     hz_profile.CUST_ACCOUNT_ID = xxdo.cust_id_inv
                   AND hz_profile.SITE_USE_ID IS NULL
                   AND xxdo.cust_id_inv = stmts.cust_account_id(+)
                   AND xxdo.amt_due_remaining_inv <> 0;


        l_count         NUMBER := 0;
        lp_request_id   NUMBER;
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            '*************************************Input Parameters**********************************************');

        fnd_file.put_line (fnd_file.LOG,
                           'P_REP_TYPE              :' || P_REP_TYPE);
        fnd_file.put_line (fnd_file.LOG,
                           'P_REPORTING_LEVEL       :' || P_REPORTING_LEVEL);
        fnd_file.put_line (
            fnd_file.LOG,
            'P_REPORTING_ENTITY_ID   :' || P_REPORTING_ENTITY_ID);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_ca_set_of_books_id    :' || p_ca_set_of_books_id);
        fnd_file.put_line (fnd_file.LOG,
                           'p_coaid                 :' || p_coaid);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_in_bal_segment_low    :' || p_in_bal_segment_low);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_in_bal_segment_high   :' || p_in_bal_segment_high);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_in_as_of_date_low     :' || p_in_as_of_date_low);
        fnd_file.put_line (fnd_file.LOG,
                           'P_MASS_REPRINT          :' || P_MASS_REPRINT);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_in_summary_option_low :' || p_in_summary_option_low);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_in_format_option_low  :' || p_in_format_option_low);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_in_bucket_type_low    :' || p_in_bucket_type_low);
        fnd_file.put_line (fnd_file.LOG,
                           'p_credit_option         :' || p_credit_option);
        fnd_file.put_line (fnd_file.LOG,
                           'p_risk_option           :' || p_risk_option);
        fnd_file.put_line (fnd_file.LOG,
                           'p_in_currency           :' || p_in_currency);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_in_customer_name_low  :' || p_in_customer_name_low);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_in_customer_name_high :' || p_in_customer_name_high);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_in_customer_num_low   :' || p_in_customer_num_low);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_in_customer_num_high  :' || p_in_customer_num_high);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_in_cust_account_name_low  :' || p_in_cust_account_name_low);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_in_cust_account_name_high :' || p_in_cust_account_name_high);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_in_amt_due_low            :' || p_in_amt_due_low);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_in_amt_due_high           :' || p_in_amt_due_high);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_in_invoice_type_low       :' || p_in_invoice_type_low);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_in_invoice_type_high      :' || p_in_invoice_type_high);
        fnd_file.put_line (fnd_file.LOG,
                           'P_COUNTRY                   :' || P_COUNTRY);
        fnd_file.put_line (fnd_file.LOG,
                           'P_COLLECTOR_ID              :' || P_COLLECTOR_ID);
        fnd_file.put_line (fnd_file.LOG,
                           'p_error_email               :' || p_error_email);
        fnd_file.put_line (fnd_file.LOG,
                           'p_max_limit                 :' || p_max_limit);
        fnd_file.put_line (fnd_file.LOG,
                           'p_max_sets                  :' || p_max_sets);


        FOR cust_rec IN cur_cust
        LOOP
            l_count   := l_count + 1;

            INSERT INTO xxdo_cust_stmt_stg
                 VALUES (cust_rec.cust_name_inv, cust_rec.cust_no_inv, 1,
                         SYSDATE, FND_GLOBAL.CONC_REQUEST_ID);
        END LOOP;

        fnd_file.put_line (fnd_file.LOG, 'Total Records Loaded' || l_count);
        COMMIT;

        lp_request_id   := FND_GLOBAL.CONC_REQUEST_ID;

        Xxdo_Dec_Report_Sub (P_Rep_Type => P_Rep_Type, P_Reporting_Level => P_Reporting_Level, P_Reporting_Entity_Id => P_Reporting_Entity_Id, P_Ca_Set_Of_Books_Id => P_Ca_Set_Of_Books_Id, P_Coaid => P_Coaid, P_In_Bal_Segment_Low => P_In_Bal_Segment_Low, P_In_Bal_Segment_High => P_In_Bal_Segment_High, P_In_As_Of_Date_Low => P_In_As_Of_Date_Low, P_Mass_Reprint => P_Mass_Reprint, P_In_Summary_Option_Low => P_In_Summary_Option_Low, P_In_Format_Option_Low => P_In_Format_Option_Low, P_In_Bucket_Type_Low => P_In_Bucket_Type_Low, P_Credit_Option => P_Credit_Option, P_Risk_Option => P_Risk_Option, P_In_Currency => P_In_Currency, P_In_Customer_Name_Low => P_In_Customer_Name_Low, P_In_Customer_Name_High => P_In_Customer_Name_High, P_In_Customer_Num_Low => P_In_Customer_Num_Low, P_In_Customer_Num_High => P_In_Customer_Num_High, P_In_Cust_Account_Name_Low => P_In_Cust_Account_Name_Low, P_In_Cust_Account_Name_High => P_In_Cust_Account_Name_High, P_In_Amt_Due_Low => P_In_Amt_Due_Low, P_In_Amt_Due_High => P_In_Amt_Due_High, P_In_Invoice_Type_Low => P_In_Invoice_Type_Low, P_In_Invoice_Type_High => P_In_Invoice_Type_High, P_Country => P_Country, P_Collector_Id => P_Collector_Id, P_Error_Email => P_Error_Email, P_Max_Limit => P_Max_Limit, P_Max_Sets => P_Max_Sets
                             , P_Request_Id => lp_request_id);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Error Message' || SQLERRM);
    END;

    /* ============================================================================*/
    PROCEDURE xxdo_dec_report_sub (P_REP_TYPE VARCHAR2,          --Report Type
                                                        P_REPORTING_LEVEL VARCHAR2, --Reporting Level
                                                                                    P_REPORTING_ENTITY_ID NUMBER, --Reporting Context
                                                                                                                  p_ca_set_of_books_id NUMBER, --Ledger Currency
                                                                                                                                               p_coaid NUMBER, --Chart of Accounts
                                                                                                                                                               p_in_bal_segment_low VARCHAR2, --Company Segment Low
                                                                                                                                                                                              p_in_bal_segment_high VARCHAR2, --Company Segment High
                                                                                                                                                                                                                              p_in_as_of_date_low VARCHAR2, --As Of GL Date
                                                                                                                                                                                                                                                            P_MASS_REPRINT VARCHAR2, --Report Type
                                                                                                                                                                                                                                                                                     p_in_summary_option_low VARCHAR2, --Report Summary
                                                                                                                                                                                                                                                                                                                       p_in_format_option_low VARCHAR2, --Report Format
                                                                                                                                                                                                                                                                                                                                                        p_in_bucket_type_low VARCHAR2, --Aging Bucket Name
                                                                                                                                                                                                                                                                                                                                                                                       p_credit_option VARCHAR2, --Show Open Credits
                                                                                                                                                                                                                                                                                                                                                                                                                 p_risk_option VARCHAR2, --Show Receipts At Risk
                                                                                                                                                                                                                                                                                                                                                                                                                                         p_in_currency VARCHAR2, --Entered Currency
                                                                                                                                                                                                                                                                                                                                                                                                                                                                 p_in_customer_name_low VARCHAR2, --Customer Name Low
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  p_in_customer_name_high VARCHAR2, --Customer Name High
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    p_in_customer_num_low VARCHAR2, --Customer Number Low
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    p_in_customer_num_high VARCHAR2, --Customer Number High
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     p_in_cust_account_name_low VARCHAR2, --Customer Account Desc Low
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          p_in_cust_account_name_high VARCHAR2, --Customer Account Desc High
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                p_in_amt_due_low NUMBER, --Balance Due Low
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         p_in_amt_due_high NUMBER, --Balance Due High
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   p_in_invoice_type_low VARCHAR2, --Transaction Type Low
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   p_in_invoice_type_high VARCHAR2, --Transaction Type High
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    P_COUNTRY VARCHAR2, --Country
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        P_COLLECTOR_ID NUMBER, --Collector
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               p_error_email VARCHAR2, --Error Report Mail id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       p_max_limit NUMBER, p_max_sets NUMBER
                                   , p_request_id NUMBER)
    IS
        l_request_id        NUMBER;
        l_layout            BOOLEAN;


        l_phase             VARCHAR2 (100);
        l_status            VARCHAR2 (100);
        l_dev_phase         VARCHAR2 (100);
        l_dev_status        VARCHAR2 (100);
        l_message           VARCHAR2 (4000);
        l_return            BOOLEAN;

        CURSOR cur_acct IS
              SELECT cust_name, COUNT (1) acct_cnt
                FROM (  SELECT DISTINCT cust_name, account_number
                          FROM xxdo_cust_stmt_stg
                         WHERE request_id = p_request_id
                      ORDER BY cust_name, account_number) test
            GROUP BY cust_name
            ORDER BY cust_name;


        v_start_cust_name   l_start_cust_name;
        v_end_cust_name     l_end_cust_name;
        v_wait_count        l_wait_count;

        l_count             NUMBER := 0;
        l_cnt               NUMBER := 1;
        l_num_rec_count     NUMBER := 0;
        l_totl_rec          NUMBER;
        l_party_id_low      NUMBER;
        l_party_id_high     NUMBER;
        l_request_cnt       NUMBER := 1;
        l_loop_cnt          NUMBER := 0;
        v_sub_req           NUMBER;
    BEGIN
        BEGIN
            v_start_cust_name.delete;
            v_end_cust_name.delete;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'Table Type Error Message' || SQLERRM);
        END;


          SELECT COUNT (1)
            INTO l_totl_rec
            FROM (  SELECT DISTINCT cust_name, account_number
                      FROM xxdo_cust_stmt_stg
                     WHERE request_id = p_request_id
                  ORDER BY cust_name, account_number) test
        ORDER BY cust_name;


        fnd_file.put_line (fnd_file.LOG, 'Records count' || l_totl_rec);



        BEGIN
            fnd_file.put_line (
                fnd_file.Output,
                '*****************************Customer Details*************************');

            FOR i IN cur_acct
            LOOP
                l_num_rec_count   := l_num_rec_count + 1;
                fnd_file.put_line (
                    fnd_file.LOG,
                    'l_num_rec_count value' || l_num_rec_count);

                --fnd_file.put_line(fnd_file.output,i.cust_name);
                -- fnd_file.put_line(fnd_file.output,'=====================================================================');

                IF l_count = 0
                THEN
                    v_start_cust_name (l_cnt)   := i.cust_name;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'v_start_cust_name ('
                        || l_cnt
                        || ')'
                        || v_start_cust_name (l_cnt));
                END IF;

                l_count           := l_count + i.acct_cnt;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'l_num_rec_count:'
                    || l_num_rec_count
                    || 'and l_totl_rec:'
                    || l_totl_rec);

                IF l_count >= p_max_limit OR l_num_rec_count = l_totl_rec
                THEN
                    v_end_cust_name (l_cnt)   := i.cust_name;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'v_end_cust_name ('
                        || l_cnt
                        || ')'
                        || v_end_cust_name (l_cnt));
                    l_count                   := 0;
                    l_cnt                     := l_cnt + 1;
                    l_loop_cnt                := l_loop_cnt + 1;
                END IF;
            END LOOP;
        EXCEPTION
            WHEN OTHERS
            THEN
                FND_file.put_line (
                    fnd_file.LOG,
                    'Before assigning value error message' || SQLERRM);
        END;

        fnd_file.put_line (
            fnd_file.LOG,
               'Last Value in v_start_cust_name.LAST Variable'
            || v_start_cust_name.LAST);

        FOR l_cust IN 1 .. l_loop_cnt              --3--v_start_cust_name.LAST
        LOOP
            mo_global.set_policy_context ('S', P_REPORTING_ENTITY_ID);
            --FND_GLOBAL.APPS_INITIALIZE (0, 50743, 695);

            l_layout         :=
                fnd_request.add_layout (
                    template_appl_name   => 'XXDO',
                    template_code        => 'XXDOAR013_REPORT',
                    template_language    => 'en',
                    template_territory   => 'US',
                    output_format        => 'PDF');

            l_party_id_low   := NULL;

            l_party_id_low   := NULL;

            BEGIN
                SELECT party_id
                  INTO l_party_id_low
                  FROM hz_parties
                 WHERE party_name = v_start_cust_name (l_cust) AND ROWNUM = 1;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'v_start_cust_name ('
                    || l_cust
                    || ')'
                    || v_start_cust_name (l_cust));

                SELECT party_id
                  INTO l_party_id_high
                  FROM hz_parties
                 WHERE party_name = v_end_cust_name (l_cust) AND ROWNUM = 1;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'v_end_cust_name ('
                    || l_cust
                    || ')'
                    || v_end_cust_name (l_cust));
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (fnd_file.LOG,
                                       'No Data found for party name');
            END;

            IF l_party_id_low IS NOT NULL AND l_party_id_high IS NOT NULL
            THEN
                v_wait_count (l_request_cnt)   :=
                    fnd_request.submit_request (
                        application   => 'XXDO',
                        program       => 'XXDOAR013_REPORT',
                        description   => p_request_id,
                        start_time    => NULL,
                        sub_request   => FALSE,
                        argument1     => P_REP_TYPE                 --'ARXAGF'
                                                   ,
                        argument2     => P_REPORTING_LEVEL              --3000
                                                          ,
                        argument3     => P_REPORTING_ENTITY_ID            --95
                                                              ,
                        argument4     => 50388,
                        argument5     => p_in_as_of_date_low --'2016/08/18 00:00:00'
                                                            ,
                        argument6     => 'M',
                        argument7     => 'I',
                        argument8     => 'D',
                        argument9     => 'Deckers Statement',
                        argument10    => 'DETAIL',
                        argument11    => 'NONE',
                        argument12    => NULL,
                        argument13    => l_party_id_low,
                        argument14    => l_party_id_high,
                        argument15    => p_in_customer_num_low   --'1177-TEVA'
                                                              ,
                        argument16    => p_in_customer_num_high  --'1177-TEVA'
                                                               );
            END IF;

            fnd_file.put_line (
                fnd_file.output,
                   'Batch :'
                || l_cust
                || '   '
                || 'Start Customer Name :'
                || v_start_cust_name (l_cust)
                || ' '
                || 'End Customer Name  :'
                || v_end_cust_name (l_cust));



            IF l_request_cnt = p_max_sets OR l_request_cnt = l_totl_rec
            THEN                                    --l_request_cnt=l_loop_cnt
                BEGIN
                    FOR l_req_sub IN 1 .. v_wait_count.LAST
                    LOOP
                        IF v_wait_count (l_req_sub) > 0
                        THEN
                            COMMIT;
                            l_return   :=
                                Fnd_Concurrent.wait_for_request (
                                    request_id   => v_wait_count (l_req_sub),
                                    INTERVAL     => 10,
                                    max_wait     => 10000,
                                    phase        => l_phase,
                                    STATUS       => l_status,
                                    dev_phase    => l_dev_phase,
                                    dev_status   => l_dev_status,
                                    MESSAGE      => l_message);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Request id :'
                                || ' '
                                || v_wait_count (l_req_sub)
                                || 'Phase :  '
                                || l_phase
                                || ' '
                                || 'STATUS:  '
                                || l_status);
                            fnd_file.put_line (
                                fnd_file.output,
                                   'Request id :'
                                || v_wait_count (l_req_sub)
                                || ' '
                                || 'Phase :'
                                || l_phase
                                || ' '
                                || 'STATUS:'
                                || l_status);


                            IF l_status = 'Normal'
                            THEN
                                v_sub_req   :=
                                    fnd_request.submit_request (
                                        application   => 'XDO',
                                        -- application
                                        program       => 'XDOBURSTREP',
                                        -- Program
                                        description   =>
                                            'XML Publisher Report Bursting Program',
                                        -- description
                                        argument1     => 'Y',
                                        argument2     =>
                                            v_wait_count (l_req_sub),
                                        -- argument1
                                        argument3     => 'Y'      -- argument2
                                                            );
                                COMMIT;
                            END IF;

                            IF v_sub_req <= 0
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Failed to submit Bursting XML Publisher Request for Request ID = '
                                    || v_wait_count (l_req_sub));
                            ELSE
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Submitted Bursting XML Publisher Request Request ID = '
                                    || v_sub_req);
                            END IF; --*/--Commented for single customer not submitting Brusting
                        END IF;

                        v_wait_count (l_req_sub)   := 0;
                    END LOOP;

                    fnd_file.put_line (
                        fnd_file.LOG,
                        '==================================================================');
                    l_request_cnt   := 0;
                END;
            END IF;

            l_request_cnt    := l_request_cnt + 1;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Error message' || SQLERRM);
    END;
END xxdo_dec_cust_stmt_pkg;
/
