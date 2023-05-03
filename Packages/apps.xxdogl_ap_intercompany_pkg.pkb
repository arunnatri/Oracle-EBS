--
-- XXDOGL_AP_INTERCOMPANY_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:46 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOGL_AP_INTERCOMPANY_PKG"
AS
    /***********************************************************************************
      *$header     :                                                                   *
      *                                                                                *
      * AUTHORS    :  Madhav Dhurjaty                                                  *
      *                                                                                *
      * PURPOSE    :  AP Intercompany GL Interface Utility - Deckers                   *
      *                                                                                *
      * PARAMETERS :                                                                   *
      *                                                                                *
      * DATE     :    13-Jan-2013                                                      *
      *                                                                                *
      * Assumptions :                                                                  *
      *                                                                                *
      *                                                                                *
      * History                                                                        *
      * Vsn     Change Date  Changed By          Change Description                    *
      * -----   -----------  ------------------  ------------------------------------- *
      * 1.0     13-Jan-2013  Madhav Dhurjaty      Initial Creation                     *
      * 1.1     17-Jan-2013  Madhav Dhurjaty      Created function 'check_debit_ccid', *
      *                                           Modified procedures print_output,    *
      *                                           insert_staging, validate_staging per *
      *                                           Alex's QA testing comments           *
      * 1.2     21-Jan-2013  Madhav Dhurjaty      Modified insert_staging,             *
      *                                           populate_gl_int to mitigate          *
      *                                           Shift+F6 issue.                      *
      *                                           Shift+f6 issue: if users creates a   *
      *                                           new line using copy(shift+f6) the    *
      *                                           previous line, attribute15 of the    *
      *                                           copied lines gets populated to       *
      *                                           attribute15 of new line              *
      * 1.3    30-Apr-2013  Madhav Dhurjaty       Modifications as per changes         *
      *                                           requested during UAT                 *
      * 1.4    16-May-2013  Madhav Dhurjaty       Created procedure Check_BSVAssigned  *
      *                                           function to validate if the balancing*
      *                                           segment is valid for target ledger   *
      * 1.5    24-Jul-2013  Madhav Dhurjaty       Modified procedure Check_BSVAssigned *
      *                                           for defect#DFCT0010552               *
      * 1.6    20-oct-2014    BT Team             code change for retrofit                                                       *
      *                                                                                *
      *********************************************************************************/
    FUNCTION check_ledger (p_ledger_id IN NUMBER)
        RETURN BOOLEAN
    IS
        l_cnt   NUMBER;
    BEGIN
        SELECT COUNT (1)
          INTO l_cnt
          FROM apps.gl_ledgers
         WHERE ledger_id = p_ledger_id;

        IF l_cnt = 1
        THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN FALSE;
    END check_ledger;

    FUNCTION get_interco_ledger (p_ccid IN NUMBER)
        RETURN NUMBER
    IS
        l_ledger   NUMBER;
    BEGIN
        SELECT val.attribute15
          INTO l_ledger
          FROM gl_code_combinations_kfv gcc1, fnd_flex_value_sets vset, fnd_flex_values_vl val
         WHERE     1 = 1
               AND vset.flex_value_set_id = val.flex_value_set_id
               AND val.flex_value = gcc1.concatenated_segments
               AND vset.flex_value_set_name = g_mapping_table
               AND val.enabled_flag = 'Y'
               AND gcc1.code_combination_id = p_ccid;

        RETURN l_ledger;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_interco_ledger;

    FUNCTION get_credit_ccid (p_ccid IN NUMBER)
        RETURN NUMBER
    IS
        l_ccid   NUMBER;
    BEGIN
        SELECT gcc2.code_combination_id
          INTO l_ccid
          FROM gl_code_combinations_kfv gcc1, gl_code_combinations_kfv gcc2, fnd_flex_value_sets vset,
               fnd_flex_values_vl val
         WHERE     1 = 1
               AND val.flex_value = gcc1.concatenated_segments
               AND val.description = gcc2.concatenated_segments
               AND vset.flex_value_set_id = val.flex_value_set_id
               AND vset.flex_value_set_name = g_mapping_table
               AND val.enabled_flag = 'Y'
               AND gcc1.code_combination_id = p_ccid;

        RETURN l_ccid;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_credit_ccid;

    FUNCTION check_debit_ccid (p_ccid            IN     NUMBER,
                               p_dff_ccid        IN     NUMBER,
                               x_valid_segment      OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_valid_segment   VARCHAR2 (10);
        l_dff_segment     VARCHAR2 (10);
    BEGIN
        BEGIN
            SELECT gcc2.segment1
              INTO l_valid_segment
              FROM gl_code_combinations_kfv gcc1, gl_code_combinations_kfv gcc2, fnd_flex_value_sets vset,
                   fnd_flex_values_vl val
             WHERE     1 = 1
                   AND vset.flex_value_set_id = val.flex_value_set_id
                   AND vset.flex_value_set_name = g_mapping_table
                   AND val.enabled_flag = 'Y'
                   AND val.flex_value = gcc1.concatenated_segments
                   AND val.description = gcc2.concatenated_segments
                   AND gcc1.code_combination_id = p_ccid;

            x_valid_segment   := l_valid_segment;
        EXCEPTION
            WHEN OTHERS
            THEN
                x_valid_segment   := NULL;
                RETURN FALSE;
        END;

        BEGIN
            SELECT segment1
              INTO l_dff_segment
              FROM gl_code_combinations_kfv gcc
             WHERE gcc.code_combination_id = p_dff_ccid;
        EXCEPTION
            WHEN OTHERS
            THEN
                x_valid_segment   := NULL;
                RETURN FALSE;
        END;

        IF l_valid_segment = l_dff_segment
        THEN
            x_valid_segment   := l_valid_segment;
            RETURN TRUE;
        ELSE
            x_valid_segment   := l_valid_segment;
            RETURN FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN FALSE;
    END check_debit_ccid;

    FUNCTION check_period (p_ledger_id IN NUMBER, p_period IN VARCHAR2)
        RETURN BOOLEAN
    IS
        l_cnt   NUMBER;
    BEGIN
        SELECT COUNT (1)
          INTO l_cnt
          FROM apps.gl_period_statuses
         --commented by BT Technology Team on 28/10/2014     --GL
         --WHERE application_id =101
         WHERE     application_id IN
                       (SELECT application_id
                          FROM fnd_application_vl
                         WHERE APPLICATION_SHORT_NAME = 'SQLGL')
               --Added by BT Technology Team on 28/10/2014
               AND closing_status = 'O'                                 --Open
               AND ledger_id = p_ledger_id
               AND period_name = p_period;

        IF l_cnt = 1
        THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN FALSE;
    END check_period;

    FUNCTION get_user_je_source (p_source IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_source   VARCHAR2 (120);
    BEGIN
        SELECT user_je_source_name
          INTO l_source
          FROM apps.gl_je_sources
         WHERE je_source_name = p_source AND LANGUAGE = 'US';

        RETURN l_source;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_user_je_source;

    FUNCTION get_user_je_category (p_category IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_category   VARCHAR2 (120);
    BEGIN
        SELECT user_je_category_name
          INTO l_category
          FROM apps.gl_je_categories
         WHERE je_category_name = p_category AND LANGUAGE = 'US';

        RETURN l_category;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_user_je_category;

    FUNCTION check_curr_conv_type (p_curr_rate_type IN VARCHAR2)
        RETURN BOOLEAN
    IS
        l_cnt   NUMBER;
    BEGIN
        SELECT COUNT (1)
          INTO l_cnt
          FROM apps.gl_daily_conversion_types
         WHERE conversion_type = p_curr_rate_type;

        IF l_cnt > 0
        THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN FALSE;
    END check_curr_conv_type;

    FUNCTION get_ledger_curr (p_ledger_id IN NUMBER)
        RETURN VARCHAR2
    IS
        l_currency   VARCHAR2 (30);
    BEGIN
        SELECT currency_code
          INTO l_currency
          FROM gl_ledgers
         WHERE ledger_id = p_ledger_id;

        RETURN l_currency;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_ledger_curr;

    FUNCTION check_bsvassigned (p_ledger_id IN NUMBER, p_debit_ccid IN NUMBER, p_credit_ccid IN NUMBER)
        RETURN BOOLEAN
    IS
        l_ccid_seg1   VARCHAR2 (30);
        l_ccid_seg2   VARCHAR2 (30);
    BEGIN
        --Check if Balancing Segment of Debit Account is assigned to target ledger
        BEGIN
            SELECT gcc.segment1
              INTO l_ccid_seg1
              FROM gl_code_combinations gcc, gl_ledger_norm_seg_vals seg
             WHERE     1 = 1
                   AND gcc.segment1 = seg.segment_value
                   AND seg.segment_type_code = 'B'
                   AND SYSDATE BETWEEN NVL (seg.start_date, SYSDATE)
                                   AND NVL (seg.end_date, SYSDATE)
                   -- Added for DFCT0010552
                   --AND seg.legal_entity_id IS NOT NULL     -- Commented for DFCT0010552
                   AND seg.ledger_id = p_ledger_id
                   AND gcc.code_combination_id = p_debit_ccid;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_ccid_seg1   := NULL;
        END;

        --Check if Balancing Segment of Credit Account is assigned to target ledger
        BEGIN
            SELECT gcc.segment1
              INTO l_ccid_seg2
              FROM gl_code_combinations gcc, gl_ledger_norm_seg_vals seg
             WHERE     1 = 1
                   AND gcc.segment1 = seg.segment_value
                   AND seg.segment_type_code = 'B'
                   AND SYSDATE BETWEEN NVL (seg.start_date, SYSDATE)
                                   AND NVL (seg.end_date, SYSDATE)
                   -- Added for DFCT0010552 - 7/24/13 - Madhav Dhurjaty
                   --AND seg.legal_entity_id IS NOT NULL     -- Commented for DFCT0010552 - 7/24/13 - Madhav Dhurjaty
                   AND seg.ledger_id = p_ledger_id
                   AND gcc.code_combination_id = p_credit_ccid;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_ccid_seg2   := NULL;
        END;

        IF l_ccid_seg1 IS NOT NULL AND l_ccid_seg2 IS NOT NULL
        THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN FALSE;
    END check_bsvassigned;

    FUNCTION check_rate_exists (p_curr_rate_type IN VARCHAR2, p_conv_date IN VARCHAR2, p_conv_curr IN VARCHAR2)
        RETURN BOOLEAN
    IS
        l_count   NUMBER;
    BEGIN
        SELECT COUNT (1)
          INTO l_count
          FROM gl_daily_rates_v
         WHERE     user_conversion_type = p_curr_rate_type
               AND to_currency = p_conv_curr
               AND conversion_date = p_conv_date;

        IF l_count > 0
        THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN FALSE;
    END check_rate_exists;

    FUNCTION check_journal_exists (p_journal_name IN VARCHAR2, p_period IN VARCHAR2, p_ledger_id IN NUMBER
                                   , p_source IN VARCHAR2, p_category IN VARCHAR2, p_currency IN VARCHAR2)
        RETURN BOOLEAN
    IS
        l_cnt   NUMBER;
    BEGIN
        SELECT COUNT (1)
          INTO l_cnt
          FROM apps.gl_je_headers
         WHERE     NAME = p_journal_name
               AND period_name = p_period
               AND ledger_id = p_ledger_id
               AND je_source = p_source
               AND je_category = p_category
               AND currency_code = p_currency;

        IF l_cnt > 0
        THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN FALSE;
    END check_journal_exists;

    PROCEDURE get_period_dates (p_period       IN     VARCHAR2,
                                x_start_date      OUT DATE,
                                x_end_date        OUT DATE)
    IS
        l_start_date   DATE;
        l_end_date     DATE;
    BEGIN
        SELECT start_date, end_date
          INTO l_start_date, l_end_date
          FROM apps.gl_periods
         WHERE     period_set_name = g_deckers_calendar
               AND period_name = p_period;

        x_start_date   := l_start_date;
        x_end_date     := l_end_date;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_start_date   := NULL;
            x_end_date     := NULL;
    END get_period_dates;

    PROCEDURE insert_staging (p_org_id IN NUMBER, p_period IN VARCHAR2, p_source IN VARCHAR2, p_category IN VARCHAR2, p_curr_rate_type IN VARCHAR2, x_ret_status OUT VARCHAR2
                              , x_ret_msg OUT VARCHAR2)
    IS
        --Cursor to fetch invoice data
        CURSOR c_inv_data (p_org_id      IN NUMBER,
                           p_from_date   IN DATE,
                           p_to_date     IN DATE)
        IS
            SELECT 'NEW' "STATUS", --NVL(aila.attribute3,aida.attribute2) ledger_id,
                                   --aia.gl_date accounting_date,
                                   aida.accounting_date accounting_date, aia.invoice_currency_code currency_code,
                   SYSDATE date_created, fnd_global.user_id created_by, 'A' "ACTUAL_FLAG",
                   aia.gl_date currency_conversion_date, DECODE (NVL (aia.voucher_num, aia.doc_sequence_value), NULL, NULL, NVL (aia.voucher_num, aia.doc_sequence_value) || ',') || aps.segment1 || ',' || aia.invoice_num || ',' || aia.org_id reference1, DECODE (NVL (aia.voucher_num, aia.doc_sequence_value), NULL, NULL, NVL (aia.voucher_num, aia.doc_sequence_value) || ',') || aps.segment1 || ',' || aia.invoice_num || ',' || aia.org_id reference2,
                   DECODE (NVL (aia.voucher_num, aia.doc_sequence_value), NULL, NULL, NVL (aia.voucher_num, aia.doc_sequence_value) || ',') || aps.segment1 || ',' || aia.invoice_num || ',' || aia.org_id reference4, DECODE (NVL (aia.voucher_num, aia.doc_sequence_value), NULL, NULL, NVL (aia.voucher_num, aia.doc_sequence_value) || ',') || aps.segment1 || ',' || aia.invoice_num || ',' || aia.org_id reference5, DECODE (NVL (aia.voucher_num, aia.doc_sequence_value), NULL, NULL, NVL (aia.voucher_num, aia.doc_sequence_value) || ',') || aps.segment1 || ',' || aia.invoice_num || ',' || 'LINE' || aida.distribution_line_number || '-' || aida.description || ',' || aia.org_id reference10,
                   aida.invoice_distribution_id reference21, aia.invoice_num reference22, aida.distribution_line_number reference23,
                   aia.org_id reference24, aps.segment1 reference25, aps.vendor_name reference26,
                   NVL (aida.attribute1, aila.attribute2) debit_ccid, aida.amount entered, aia.invoice_num invoice_num,
                   aila.line_number line_number, aida.distribution_line_number dist_number, NVL (aida.dist_code_combination_id, aila.default_dist_ccid) user_entered_ccid,
                   NVL (aia.voucher_num, aia.doc_sequence_value) voucher_num, aia.invoice_id, aia.vendor_id,
                   aia.org_id
              FROM ap_invoices_all aia, ap_invoice_lines_all aila, ap_invoice_distributions_all aida,
                   ap_suppliers aps
             WHERE     1 = 1
                   AND aia.invoice_id = aila.invoice_id
                   AND aia.vendor_id = aps.vendor_id
                   AND aila.invoice_id = aida.invoice_id
                   AND aila.line_number = aida.invoice_line_number
                   AND ap_invoices_pkg.get_approval_status (
                           aia.invoice_id,
                           aia.invoice_amount,
                           aia.payment_status_flag,
                           aia.invoice_type_lookup_code) IN
                           ('APPROVED', 'CANCELLED', 'NEEDS REAPPROVAL')
                   --Added 'Needs Reapproval' on 04/30/13 by Madhav
                   AND ap_invoices_pkg.get_posting_status (aia.invoice_id) IN
                           ('Y', 'P')
                   AND NVL (aida.posted_flag, 'X') = 'Y'
                   AND (NVL (aila.attribute15, 'XXX') <> aila.invoice_id || '-' || aila.line_number --This condition is added to mitigate Shift+f6 issue.
                                                                                                    OR NVL (aida.attribute15, 'XXX') <> aida.invoice_id || '-' || aida.invoice_line_number || '-' || aida.distribution_line_number)
                   AND NVL (aida.attribute1, aila.attribute2) IS NOT NULL
                   --Interco Exp Acct must be available at line or dist
                   --AND aia.gl_date BETWEEN p_from_date AND p_to_date
                   AND aida.line_type_lookup_code NOT IN
                           ('REC_TAX', 'NONREC_TAX')
                   -- Added by Srinath 03/12/2014 (DFCT0010838)
                   AND aida.accounting_date BETWEEN p_from_date AND p_to_date
                   AND aia.org_id = p_org_id;

        l_start_date      DATE;
        l_end_date        DATE;
        l_debit_ccid      NUMBER;
        l_credit_ccid     NUMBER;
        l_mapped_ledger   NUMBER;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Inside Insert Staging Procedure');
        get_period_dates (p_period       => p_period,
                          x_start_date   => l_start_date,
                          x_end_date     => l_end_date);

        FOR r_inv_data IN c_inv_data (p_org_id, l_start_date, l_end_date)
        LOOP
            --Get Mapped Ledger
            l_mapped_ledger   := NULL;
            l_mapped_ledger   :=
                get_interco_ledger (p_ccid => r_inv_data.user_entered_ccid);
            --Derive Account to be credited
            l_credit_ccid     := NULL;
            l_credit_ccid     :=
                get_credit_ccid (p_ccid => r_inv_data.user_entered_ccid);

            INSERT INTO xxdo.xxdogl_ap_interco_stg (status, ledger_id, accounting_date, currency_code, date_created, created_by, actual_flag, currency_conversion_date, reference1, reference2, reference4, reference5, reference10, reference21, reference22, reference23, reference24, reference25, reference26, --code_combination_id,
                                                                                                                                                                                                                                                                                                                   amount, invoice_num, line_number, dist_number, conc_request_id, process_flag, user_je_source_name, user_je_category_name, user_currency_conversion_type, je_source_name, je_category_name, debit_ccid, credit_ccid, period_name, line_dist_ccid, voucher_num, invoice_id
                                                    , vendor_id, org_id)
                 VALUES (r_inv_data.status, l_mapped_ledger, --r_inv_data.ledger_id,
                                                             r_inv_data.accounting_date, r_inv_data.currency_code, r_inv_data.date_created, r_inv_data.created_by, r_inv_data.actual_flag, r_inv_data.currency_conversion_date, r_inv_data.reference1, r_inv_data.reference2, r_inv_data.reference4, r_inv_data.reference5, r_inv_data.reference10, r_inv_data.reference21, r_inv_data.reference22, r_inv_data.reference23, r_inv_data.reference24, r_inv_data.reference25, r_inv_data.reference26, --r_inv_data.code_combination_id,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    r_inv_data.entered, r_inv_data.invoice_num, r_inv_data.line_number, r_inv_data.dist_number, g_conc_request_id, 'N' --New record
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      , get_user_je_source (p_source), get_user_je_category (p_category), p_curr_rate_type, p_source, p_category, r_inv_data.debit_ccid, l_credit_ccid, p_period, r_inv_data.user_entered_ccid, r_inv_data.voucher_num, r_inv_data.invoice_id
                         , r_inv_data.vendor_id, r_inv_data.org_id);
        END LOOP;

        COMMIT;
        x_ret_status   := '0';
        x_ret_msg      := 'SUCCESS';
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_status   := '2';
            x_ret_msg      := SQLERRM;
            fnd_file.put_line (fnd_file.LOG,
                               'Error in insert_staging:' || SQLERRM);
    END insert_staging;

    PROCEDURE unaccounted_transactions (p_org_id           IN NUMBER,
                                        p_period           IN VARCHAR2,
                                        p_source           IN VARCHAR2,
                                        p_category         IN VARCHAR2,
                                        p_curr_rate_type   IN VARCHAR2)
    IS
        CURSOR c_unacc_trx (p_org_id      IN NUMBER,
                            p_from_date   IN DATE,
                            p_to_date     IN DATE)
        IS
            SELECT TO_CHAR (aida.accounting_date, 'DD-MON-YYYY') accounting_date, aia.invoice_currency_code currency_code, aia.gl_date currency_conversion_date,
                   NVL (aida.attribute1, aila.attribute2) debit_ccid, aida.amount entered, aia.invoice_num invoice_num,
                   aila.line_number line_number, aida.distribution_line_number dist_number, NVL (aida.dist_code_combination_id, aila.default_dist_ccid) user_entered_ccid,
                   NVL (aia.voucher_num, aia.doc_sequence_value) voucher_num, aia.invoice_id, aia.vendor_id,
                   aia.org_id, xxdogl_ap_intercompany_pkg.get_credit_ccid (NVL (aida.dist_code_combination_id, aila.default_dist_ccid)) credit_ccid, xxdogl_ap_intercompany_pkg.get_interco_ledger (NVL (aida.dist_code_combination_id, aila.default_dist_ccid)) ledger_id
              FROM ap_invoices_all aia, ap_invoice_lines_all aila, ap_invoice_distributions_all aida,
                   ap_suppliers aps
             WHERE     1 = 1
                   AND aia.invoice_id = aila.invoice_id
                   AND aia.vendor_id = aps.vendor_id
                   AND aila.invoice_id = aida.invoice_id
                   AND aila.line_number = aida.invoice_line_number
                   AND ap_invoices_pkg.get_approval_status (
                           aia.invoice_id,
                           aia.invoice_amount,
                           aia.payment_status_flag,
                           aia.invoice_type_lookup_code) IN
                           ('APPROVED', 'CANCELLED', 'NEEDS REAPPROVAL')
                   AND ap_invoices_pkg.get_posting_status (aia.invoice_id) IN
                           ('Y', 'P', 'N')
                   AND NVL (aida.posted_flag, 'X') != 'Y'
                   AND (NVL (aila.attribute15, 'XXX') <> aila.invoice_id || '-' || aila.line_number OR NVL (aida.attribute15, 'XXX') <> aida.invoice_id || '-' || aida.invoice_line_number || '-' || aida.distribution_line_number)
                   AND NVL (aida.attribute1, aila.attribute2) IS NOT NULL
                   AND aida.accounting_date BETWEEN p_from_date AND p_to_date
                   AND aia.org_id = p_org_id;

        l_target_ledger   VARCHAR2 (240);
        l_code_combo1     VARCHAR2 (240);
        l_code_combo2     VARCHAR2 (240);
        l_start_date      DATE;
        l_end_date        DATE;
        l_line            VARCHAR2 (4000);
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'Inside Unaccounted Transactions Procedure');
        get_period_dates (p_period       => p_period,
                          x_start_date   => l_start_date,
                          x_end_date     => l_end_date);
        fnd_file.put_line (fnd_file.output, ' ');
        fnd_file.put_line (fnd_file.output, ' ');
        fnd_file.put_line (fnd_file.output, ' ');
        fnd_file.put_line (
            fnd_file.output,
            LPAD (
                '*** Unaccounted Transactions Eligibile for I/C Processing ***',
                80,
                ' '));
        l_line   := RPAD ('=', 150, '=');
        fnd_file.put_line (fnd_file.output, l_line);
        l_line   :=
               RPAD ('Voucher Num', 21, ' ')
            || RPAD ('Invoice Num', 21, ' ')
            || RPAD ('Line', 5, ' ')
            || RPAD ('Dist', 5, ' ')
            || RPAD ('GL Date', 12, ' ')
            || RPAD ('Amount', 11, ' ')
            || RPAD ('Curr', 5, ' ')
            || RPAD ('Target Ledger', 31, ' ')
            || RPAD ('Debit Account', 19, ' ')
            || RPAD ('Credit Account', 19, ' ');
        fnd_file.put_line (fnd_file.output, l_line);
        l_line   := RPAD ('-', 150, '-');
        fnd_file.put_line (fnd_file.output, l_line);

        FOR r_unacc_trx IN c_unacc_trx (p_org_id, l_start_date, l_end_date)
        LOOP
            BEGIN
                SELECT NAME
                  INTO l_target_ledger
                  FROM gl_ledgers
                 WHERE ledger_id = r_unacc_trx.ledger_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_target_ledger   := NULL;
            END;

            BEGIN
                SELECT concatenated_segments
                  INTO l_code_combo1
                  FROM gl_code_combinations_kfv
                 WHERE code_combination_id = r_unacc_trx.debit_ccid;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_code_combo1   := NULL;
            END;

            BEGIN
                SELECT concatenated_segments
                  INTO l_code_combo2
                  FROM gl_code_combinations_kfv
                 WHERE code_combination_id = r_unacc_trx.credit_ccid;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_code_combo2   := NULL;
            END;

            fnd_file.put_line (
                fnd_file.output,
                   RPAD (NVL (r_unacc_trx.voucher_num, '.'), 20, ' ')
                || ' '
                || RPAD (r_unacc_trx.invoice_num, 20, ' ')
                || ' '
                || RPAD (r_unacc_trx.line_number, 4, ' ')
                || ' '
                || RPAD (r_unacc_trx.dist_number, 4, ' ')
                || ' '
                || RPAD (r_unacc_trx.accounting_date, 11, ' ')
                || ' '
                || LPAD (TO_CHAR (r_unacc_trx.entered), 10, ' ')
                || ' '
                || RPAD (r_unacc_trx.currency_code, 4, ' ')
                || ' '
                || RPAD (l_target_ledger, 30, ' ')
                || ' '
                || RPAD (l_code_combo1, 18, ' ')
                || ' '
                || RPAD (l_code_combo2, 18, ' '));
        END LOOP;

        l_line   := RPAD ('=', 150, '=');
        fnd_file.put_line (fnd_file.output, l_line);
        fnd_file.put_line (
            fnd_file.output,
            '*** Please run "Create Accounting" to process these records. ***');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Error in unaccounted_transactions:' || SQLERRM);
    END unaccounted_transactions;

    PROCEDURE validate_staging (x_ret_status   OUT VARCHAR2,
                                x_ret_msg      OUT VARCHAR2)
    IS
        --Cursor to fetch all New(N) records from staging
        CURSOR c_stg_data IS
            SELECT *
              FROM xxdo.xxdogl_ap_interco_stg
             WHERE     1 = 1
                   AND conc_request_id = g_conc_request_id
                   AND process_flag = 'N';

        l_source          VARCHAR2 (240);
        l_category        VARCHAR2 (240);
        l_error_flag      VARCHAR2 (1) := 'N';
        l_error_msg       VARCHAR2 (2000) := NULL;
        l_valid_flag      BOOLEAN := NULL;
        l_count           NUMBER := 0;
        l_led_currency    VARCHAR2 (30);
        l_valid_segment   VARCHAR2 (10);
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Inside Validate Staging Procedure');

        FOR r_stg_data IN c_stg_data
        LOOP
            l_count           := l_count + 1;
            l_error_flag      := 'N';
            l_error_msg       := NULL;
            --Check if Ledger Exists
            l_valid_flag      := NULL;
            l_valid_flag      :=
                check_ledger (p_ledger_id => r_stg_data.ledger_id);

            IF l_valid_flag = FALSE
            THEN
                l_error_flag   := 'Y';
                l_error_msg    :=
                       l_error_msg
                    || ' Invalid Ledger ID:'
                    || r_stg_data.ledger_id;
            END IF;

            --Check if Period is Open
            l_valid_flag      := NULL;
            l_valid_flag      :=
                check_period (p_ledger_id   => r_stg_data.ledger_id,
                              p_period      => r_stg_data.period_name);

            IF l_valid_flag = FALSE
            THEN
                l_error_flag   := 'Y';
                l_error_msg    :=
                       l_error_msg
                    || ' Check Period:'
                    || r_stg_data.period_name
                    || ' for ledger id:'
                    || r_stg_data.ledger_id;
            END IF;

            --Check if credit ccid/debit ccid are valid
            IF    r_stg_data.credit_ccid IS NULL
               OR r_stg_data.debit_ccid IS NULL
            THEN
                l_error_flag   := 'Y';
                l_error_msg    :=
                       l_error_msg
                    || ' Check if Credit CCID, Debit CCID are Valid.';
            END IF;

            --Check if journal source and category are valid
            IF    r_stg_data.user_je_source_name IS NULL
               OR r_stg_data.user_je_category_name IS NULL
            THEN
                l_error_flag   := 'Y';
                l_error_msg    :=
                       l_error_msg
                    || ' Check if Journal Source and Category are Valid.';
            END IF;

            --Check if currency conversion rate type is valid
            l_valid_flag      := NULL;
            l_valid_flag      :=
                check_curr_conv_type (
                    p_curr_rate_type   =>
                        r_stg_data.user_currency_conversion_type);

            IF l_valid_flag = FALSE
            THEN
                l_error_flag   := 'Y';
                l_error_msg    :=
                       l_error_msg
                    || ' Check if User Currency Conversion Rate Type is valid: '
                    || r_stg_data.user_currency_conversion_type;
            END IF;

            --Get Ledger Currency
            l_led_currency    := NULL;
            l_led_currency    :=
                get_ledger_curr (p_ledger_id => r_stg_data.ledger_id);
            --Check if Conversion rate exists
            l_valid_flag      := NULL;
            l_valid_flag      :=
                check_rate_exists (
                    p_curr_rate_type   =>
                        r_stg_data.user_currency_conversion_type,
                    p_conv_date   => r_stg_data.currency_conversion_date,
                    p_conv_curr   => l_led_currency);

            IF l_valid_flag = FALSE
            THEN
                l_error_flag   := 'Y';
                l_error_msg    :=
                       l_error_msg
                    || ' Check if Currency Conversion Rate type '
                    || r_stg_data.user_currency_conversion_type
                    || ' is valid for: '
                    || l_led_currency
                    || ' on '
                    || TO_CHAR (r_stg_data.currency_conversion_date,
                                'DD-MON-YYYY');
            END IF;

            --Check if the account entered at DFF is valid per the mapping
            l_valid_flag      := NULL;
            l_valid_segment   := NULL;
            l_valid_flag      :=
                check_debit_ccid (p_ccid            => r_stg_data.line_dist_ccid,
                                  p_dff_ccid        => r_stg_data.debit_ccid,
                                  x_valid_segment   => l_valid_segment);

            IF l_valid_flag <> TRUE
            THEN
                l_error_flag   := 'Y';
                l_error_msg    :=
                       l_error_msg
                    || ' Interco Expense Account entered at the DFF must have company segment :'
                    || l_valid_segment;
            END IF;

            --Check if balancing segments of Credit CCID and Debit CCID are assigned to target ledger
            l_valid_flag      := NULL;
            l_valid_flag      :=
                check_bsvassigned (p_ledger_id     => r_stg_data.ledger_id,
                                   p_debit_ccid    => r_stg_data.debit_ccid,
                                   p_credit_ccid   => r_stg_data.credit_ccid);

            IF l_valid_flag <> TRUE
            THEN
                l_error_flag   := 'Y';
                l_error_msg    :=
                       l_error_msg
                    || ' Invalid Balancing segment value for the target ledger.';
            END IF;

            /*If error flag is Y update staging record
            with process flag E (Error) else V (Valid)*/
            IF NVL (l_error_flag, 'X') = 'Y'
            THEN
                UPDATE xxdo.xxdogl_ap_interco_stg
                   SET process_flag = 'E', error_message = error_message || l_error_msg
                 WHERE     1 = 1
                       AND conc_request_id = g_conc_request_id
                       AND invoice_num = r_stg_data.invoice_num
                       AND line_number = r_stg_data.line_number
                       AND NVL (dist_number, 'XYZ') =
                           NVL (r_stg_data.dist_number, 'XYZ')
                       AND invoice_id = r_stg_data.invoice_id
                       AND vendor_id = r_stg_data.vendor_id;
            ELSE
                UPDATE xxdo.xxdogl_ap_interco_stg
                   SET process_flag = 'V', error_message = NULL
                 WHERE     1 = 1
                       AND conc_request_id = g_conc_request_id
                       AND invoice_num = r_stg_data.invoice_num
                       AND line_number = r_stg_data.line_number
                       AND NVL (dist_number, 'XYZ') =
                           NVL (r_stg_data.dist_number, 'XYZ')
                       AND invoice_id = r_stg_data.invoice_id
                       AND vendor_id = r_stg_data.vendor_id;
            END IF;
        END LOOP;

        COMMIT;
        x_ret_status   := '0';
        x_ret_msg      := 'SUCCESS';
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_status   := '2';
            x_ret_msg      := SQLERRM;
            fnd_file.put_line (fnd_file.LOG,
                               'Error in validate_staging:' || SQLERRM);
    END validate_staging;

    PROCEDURE populate_gl_int (x_ret_status   OUT VARCHAR2,
                               x_ret_msg      OUT VARCHAR2)
    IS
        --Cursor to fetch all valid(V) records from staging
        CURSOR c_valid_data IS
            SELECT *
              FROM xxdo.xxdogl_ap_interco_stg
             WHERE     1 = 1
                   AND conc_request_id = g_conc_request_id
                   AND process_flag = 'V';

        l_count   NUMBER := 0;
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'Inside Populate GL Interface Procedure');

        FOR r_valid_data IN c_valid_data
        LOOP
            l_count   := l_count + 1;

            INSERT INTO gl_interface (status,
                                      ledger_id,
                                      accounting_date,
                                      currency_code,
                                      date_created,
                                      created_by,
                                      actual_flag,
                                      currency_conversion_date,
                                      reference1,
                                      reference2,
                                      reference4,
                                      reference5,
                                      reference10,
                                      reference21,
                                      reference22,
                                      reference23,
                                      reference24,
                                      reference25,
                                      reference26,
                                      code_combination_id,
                                      entered_dr,
                                      user_je_source_name,
                                      user_je_category_name,
                                      user_currency_conversion_type)
                     VALUES (r_valid_data.status,
                             r_valid_data.ledger_id,
                             r_valid_data.accounting_date,
                             r_valid_data.currency_code,
                             r_valid_data.date_created,
                             r_valid_data.created_by,
                             r_valid_data.actual_flag,
                             r_valid_data.currency_conversion_date,
                             r_valid_data.reference1,
                             r_valid_data.reference2,
                             r_valid_data.reference4,
                             r_valid_data.reference5,
                             r_valid_data.reference10,
                             r_valid_data.reference21,
                             r_valid_data.reference22,
                             r_valid_data.reference23,
                             r_valid_data.reference24,
                             r_valid_data.reference25,
                             r_valid_data.reference26,
                             r_valid_data.debit_ccid,
                             --r_valid_data.code_combination_id,
                             r_valid_data.amount,
                             r_valid_data.user_je_source_name,
                             r_valid_data.user_je_category_name,
                             r_valid_data.user_currency_conversion_type);

            INSERT INTO gl_interface (status,
                                      ledger_id,
                                      accounting_date,
                                      currency_code,
                                      date_created,
                                      created_by,
                                      actual_flag,
                                      currency_conversion_date,
                                      reference1,
                                      reference2,
                                      reference4,
                                      reference5,
                                      reference10,
                                      reference21,
                                      reference22,
                                      reference23,
                                      reference24,
                                      reference25,
                                      reference26,
                                      code_combination_id,
                                      entered_cr,
                                      user_je_source_name,
                                      user_je_category_name,
                                      user_currency_conversion_type)
                     VALUES (r_valid_data.status,
                             r_valid_data.ledger_id,
                             r_valid_data.accounting_date,
                             r_valid_data.currency_code,
                             r_valid_data.date_created,
                             r_valid_data.created_by,
                             r_valid_data.actual_flag,
                             r_valid_data.currency_conversion_date,
                             r_valid_data.reference1,
                             r_valid_data.reference2,
                             r_valid_data.reference4,
                             r_valid_data.reference5,
                             r_valid_data.reference10,
                             r_valid_data.reference21,
                             r_valid_data.reference22,
                             r_valid_data.reference23,
                             r_valid_data.reference24,
                             r_valid_data.reference25,
                             r_valid_data.reference26,
                             r_valid_data.credit_ccid,
                             --r_valid_data.code_combination_id,
                             r_valid_data.amount,
                             r_valid_data.user_je_source_name,
                             r_valid_data.user_je_category_name,
                             r_valid_data.user_currency_conversion_type);

            UPDATE xxdo.xxdogl_ap_interco_stg
               SET process_flag = 'P', error_message = NULL
             WHERE     1 = 1
                   AND conc_request_id = g_conc_request_id
                   AND invoice_num = r_valid_data.invoice_num
                   AND line_number = r_valid_data.line_number
                   AND NVL (dist_number, 'XYZ') =
                       NVL (r_valid_data.dist_number, 'XYZ')
                   AND invoice_id = r_valid_data.invoice_id
                   AND vendor_id = r_valid_data.vendor_id;

            UPDATE ap_invoice_lines_all
               SET attribute15   = invoice_id || '-' || line_number
             --This condition is added to mitigate Shift+f6 issue.
             WHERE     1 = 1
                   AND line_number = r_valid_data.line_number
                   AND invoice_id = r_valid_data.invoice_id;

            IF r_valid_data.dist_number IS NOT NULL
            THEN
                UPDATE ap_invoice_distributions_all
                   SET attribute15 = invoice_id || '-' || r_valid_data.line_number || '-' || r_valid_data.dist_number
                 --This condition is added to mitigate Shift+f6 issue.
                 WHERE     1 = 1
                       AND distribution_line_number =
                           r_valid_data.dist_number
                       AND invoice_line_number = r_valid_data.line_number
                       AND invoice_id = r_valid_data.invoice_id;
            END IF;
        END LOOP;

        COMMIT;
        x_ret_status   := '0';
        x_ret_msg      := 'SUCCESS';
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_status   := '2';
            x_ret_msg      := SQLERRM;
            fnd_file.put_line (fnd_file.LOG,
                               'Error in populate_gl_int:' || SQLERRM);
    END populate_gl_int;

    PROCEDURE submit_journal_imp (x_ret_status   OUT VARCHAR2,
                                  x_ret_msg      OUT VARCHAR2)
    IS
        CURSOR c_ledgers IS
              SELECT ledger_id, je_source_name
                FROM xxdo.xxdogl_ap_interco_stg
               WHERE     1 = 1
                     AND conc_request_id = g_conc_request_id
                     AND process_flag = 'P'
            GROUP BY ledger_id, je_source_name;

        l_request_id   NUMBER;
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'Inside Submit Journal Import Procedure');
        fnd_file.put_line (fnd_file.LOG,
                           '----------------------------------------');

        FOR r_ledgers IN c_ledgers
        LOOP
            l_request_id   :=
                fnd_request.submit_request (
                    application   => 'XXDO',
                    program       => 'XXDOGL004',
                    description   => NULL,
                    start_time    => SYSDATE,
                    sub_request   => FALSE,
                    argument1     => fnd_profile.VALUE ('GL_ACCESS_SET_ID'),
                    argument2     => r_ledgers.je_source_name,
                    argument3     => r_ledgers.ledger_id,
                    argument4     => NULL,
                    argument5     => 'N',
                    argument6     => 'N',
                    argument7     => 'N');
            COMMIT;
            fnd_file.put_line (fnd_file.LOG, 'Request ID:' || l_request_id);
            fnd_file.put_line (
                fnd_file.LOG,
                'argument1:' || fnd_profile.VALUE ('GL_ACCESS_SET_ID'));
            fnd_file.put_line (fnd_file.LOG,
                               'argument2:' || r_ledgers.ledger_id);
            fnd_file.put_line (fnd_file.LOG,
                               'argument3:' || r_ledgers.je_source_name);
            fnd_file.put_line (fnd_file.LOG, ' ');
        END LOOP;

        fnd_file.put_line (fnd_file.LOG,
                           '----------------------------------------');
        x_ret_status   := '0';
        x_ret_msg      := 'SUCCESS';
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_status   := '2';
            x_ret_msg      := SQLERRM;
            fnd_file.put_line (fnd_file.LOG,
                               'Error in submit_journal_imp:' || SQLERRM);
    END submit_journal_imp;

    PROCEDURE print_output (x_ret_status   OUT VARCHAR2,
                            x_ret_msg      OUT VARCHAR2)
    IS
        CURSOR c_stg_data IS
            SELECT *
              FROM xxdo.xxdogl_ap_interco_stg
             WHERE conc_request_id = g_conc_request_id;

        l_tot_count       NUMBER := 0;
        l_error_cnt       NUMBER := 0;
        l_prcss_cnt       NUMBER := 0;
        l_line            VARCHAR2 (360) := NULL;
        l_status          VARCHAR2 (30) := NULL;
        l_target_ledger   VARCHAR2 (360) := NULL;
        l_code_combo1     VARCHAR2 (120) := NULL;
        l_code_combo2     VARCHAR2 (120) := NULL;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Inside Print Output Procedure');

        SELECT COUNT (*)
          INTO l_tot_count
          FROM xxdo.xxdogl_ap_interco_stg
         WHERE conc_request_id = g_conc_request_id;

        SELECT COUNT (*)
          INTO l_error_cnt
          FROM xxdo.xxdogl_ap_interco_stg
         WHERE conc_request_id = g_conc_request_id AND process_flag <> 'P';

        SELECT COUNT (*)
          INTO l_prcss_cnt
          FROM xxdo.xxdogl_ap_interco_stg
         WHERE conc_request_id = g_conc_request_id AND process_flag = 'P';

        l_line         :=
            '===========================================================';
        fnd_file.put_line (fnd_file.LOG, l_line);
        fnd_file.put_line (
            fnd_file.LOG,
            'Total Records             :' || TO_CHAR (l_tot_count));
        fnd_file.put_line (
            fnd_file.LOG,
            'Error Records             :' || TO_CHAR (l_error_cnt));
        fnd_file.put_line (
            fnd_file.LOG,
            'Processed Records         :' || TO_CHAR (l_prcss_cnt));
        fnd_file.put_line (fnd_file.LOG, l_line);
        l_line         := LPAD (g_program_name, 70, ' ');
        fnd_file.put_line (fnd_file.output, l_line);
        l_line         := RPAD ('=', 150, '=');
        fnd_file.put_line (fnd_file.output, l_line);
        l_line         :=
               RPAD ('Voucher Num', 21, ' ')
            || RPAD ('Invoice Num', 21, ' ')
            || RPAD ('Line', 5, ' ')
            || RPAD ('Dist', 5, ' ')
            || RPAD ('Amount', 11, ' ')
            || RPAD ('Curr', 5, ' ')
            || RPAD ('Target Ledger', 31, ' ')
            || RPAD ('Debit Account', 19, ' ')
            || RPAD ('Credit Account', 19, ' ')
            || RPAD ('Status', 11, ' ')
            || 'Message';
        --FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'Invoice Num         Line Dist Amount    Target Ledger       Debit Account      Credit Account     Status    Message');
        fnd_file.put_line (fnd_file.output, l_line);
        l_line         := RPAD ('-', 150, '-');
        fnd_file.put_line (fnd_file.output, l_line);

        FOR r_stg_data IN c_stg_data
        LOOP
            SELECT DECODE (r_stg_data.process_flag,  'N', 'NEW',  'P', 'PROCESSED',  'E', 'ERROR',  'NEW')
              INTO l_status
              FROM DUAL;

            BEGIN
                SELECT NAME
                  INTO l_target_ledger
                  FROM gl_ledgers
                 WHERE ledger_id = r_stg_data.ledger_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_target_ledger   := NULL;
            END;

            BEGIN
                SELECT concatenated_segments
                  INTO l_code_combo1
                  FROM gl_code_combinations_kfv
                 WHERE code_combination_id = r_stg_data.debit_ccid;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_code_combo1   := NULL;
            END;

            BEGIN
                SELECT concatenated_segments
                  INTO l_code_combo2
                  FROM gl_code_combinations_kfv
                 WHERE code_combination_id = r_stg_data.credit_ccid;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_code_combo2   := NULL;
            END;

            fnd_file.put_line (
                fnd_file.output,
                   RPAD (NVL (r_stg_data.voucher_num, '.'), 20, ' ')
                || ' '
                || RPAD (r_stg_data.invoice_num, 20, ' ')
                || ' '
                || RPAD (r_stg_data.line_number, 4, ' ')
                || ' '
                || RPAD (r_stg_data.dist_number, 4, ' ')
                || ' '
                || LPAD (TO_CHAR (r_stg_data.amount), 10, ' ')
                || ' '
                || RPAD (r_stg_data.currency_code, 4, ' ')
                || ' '
                || RPAD (l_target_ledger, 30, ' ')
                || ' '
                || RPAD (l_code_combo1, 18, ' ')
                || ' '
                || RPAD (l_code_combo2, 18, ' ')
                || ' '
                || RPAD (l_status, 10, ' ')
                || ' '
                || r_stg_data.error_message);
        END LOOP;

        IF l_tot_count = 0
        THEN
            fnd_file.put_line (
                fnd_file.output,
                RPAD (LPAD ('No Records Found.', 40, ' '), 80, ' '));
        END IF;

        l_line         := RPAD ('=', 150, '=');
        fnd_file.put_line (fnd_file.output, l_line);
        x_ret_status   := '0';
        x_ret_msg      := 'SUCCESS';
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_status   := '2';
            x_ret_msg      := SQLERRM;
            fnd_file.put_line (fnd_file.LOG,
                               'Error in print_output:' || SQLERRM);
    END print_output;

    PROCEDURE main (retcode OUT VARCHAR2, errbuf OUT VARCHAR2, p_org_id IN NUMBER, p_period IN VARCHAR2, p_source IN VARCHAR2, p_category IN VARCHAR2
                    , p_curr_rate_type IN VARCHAR2)
    IS
        l_ret_status     VARCHAR2 (30);
        l_ret_msg        VARCHAR2 (4000);
        ex_ins_staging   EXCEPTION;
        ex_val_staging   EXCEPTION;
        ex_jnl_import    EXCEPTION;
        ex_prn_output    EXCEPTION;
        ex_pop_gl_int    EXCEPTION;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Inside Main Procedure');
        fnd_file.put_line (fnd_file.LOG,
                           '----------------------------------------');
        fnd_file.put_line (fnd_file.LOG, 'P_ORG_ID:' || p_org_id);
        fnd_file.put_line (fnd_file.LOG, 'P_PERIOD:' || p_period);
        fnd_file.put_line (fnd_file.LOG, 'P_SOURCE:' || p_source);
        fnd_file.put_line (fnd_file.LOG, 'P_CATEGORY:' || p_category);
        fnd_file.put_line (fnd_file.LOG,
                           'P_CURR_RATE_TYPE:' || p_curr_rate_type);
        fnd_file.put_line (fnd_file.LOG,
                           '----------------------------------------');
        --Insert Data into Staging table
        insert_staging (p_org_id => p_org_id, p_period => p_period, p_source => p_source, p_category => p_category, p_curr_rate_type => p_curr_rate_type, x_ret_status => l_ret_status
                        , x_ret_msg => l_ret_msg);

        IF l_ret_status = '2'
        THEN
            RAISE ex_ins_staging;
        END IF;

        --Validate data in the staging table
        validate_staging (x_ret_status => l_ret_status, x_ret_msg => l_ret_msg);

        IF l_ret_status = '2'
        THEN
            RAISE ex_val_staging;
        END IF;

        --Populate valid data into GL_INTERFACE
        populate_gl_int (x_ret_status => l_ret_status, x_ret_msg => l_ret_msg);

        IF l_ret_status = '2'
        THEN
            RAISE ex_pop_gl_int;
        END IF;

        --Submit Journal Import
        submit_journal_imp (x_ret_status   => l_ret_status,
                            x_ret_msg      => l_ret_msg);

        IF l_ret_status = '2'
        THEN
            RAISE ex_jnl_import;
        END IF;

        --Print Output
        print_output (x_ret_status => l_ret_status, x_ret_msg => l_ret_msg);

        IF l_ret_status = '2'
        THEN
            RAISE ex_prn_output;
        END IF;

        --Print Unaccounted Transactions
        unaccounted_transactions (p_org_id           => p_org_id,
                                  p_period           => p_period,
                                  p_source           => p_source,
                                  p_category         => p_category,
                                  p_curr_rate_type   => p_curr_rate_type);
        COMMIT;
    EXCEPTION
        WHEN ex_ins_staging
        THEN
            retcode   := l_ret_status;
            errbuf    := l_ret_msg;
            fnd_file.put_line (
                fnd_file.LOG,
                'Error Inserting data into Staging:' || l_ret_msg);
        WHEN ex_val_staging
        THEN
            retcode   := l_ret_status;
            errbuf    := l_ret_msg;
            fnd_file.put_line (fnd_file.LOG,
                               'Error Validating Staging Data:' || l_ret_msg);
        WHEN ex_pop_gl_int
        THEN
            retcode   := l_ret_status;
            errbuf    := l_ret_msg;
            fnd_file.put_line (
                fnd_file.LOG,
                'Error Populating GL_INTERFACE table:' || l_ret_msg);
        WHEN ex_jnl_import
        THEN
            retcode   := l_ret_status;
            errbuf    := l_ret_msg;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Submitting Program - Import Journals - Deckers:'
                || l_ret_msg);
        WHEN ex_prn_output
        THEN
            retcode   := l_ret_status;
            errbuf    := l_ret_msg;
            fnd_file.put_line (fnd_file.LOG,
                               'Error Printing Output:' || l_ret_msg);
        WHEN OTHERS
        THEN
            retcode   := '2';
            errbuf    := SQLERRM;
            fnd_file.put_line (fnd_file.LOG, 'Error in main:' || SQLERRM);
    END main;
END xxdogl_ap_intercompany_pkg;
/


--
-- XXDOGL_AP_INTERCOMPANY_PKG  (Synonym) 
--
CREATE OR REPLACE SYNONYM XXDO.XXDOGL_AP_INTERCOMPANY_PKG FOR APPS.XXDOGL_AP_INTERCOMPANY_PKG
/
