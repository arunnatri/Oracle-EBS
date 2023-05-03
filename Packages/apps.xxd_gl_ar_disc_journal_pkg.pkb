--
-- XXD_GL_AR_DISC_JOURNAL_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:22 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_GL_AR_DISC_JOURNAL_PKG"
IS
    --  ###################################################################################
    --  Package         : XXD_GL_AR_DISC_JOURNAL_PKG.pkb
    --  System          : EBS
    --  Change          : CCR0008499
    --  Schema          : APPS
    --  Purpose         : Package is used to extract AR Discounts for Journal Entries
    --  Change History
    --  ------------------------------------------------------------------------------
    --  Date            Name                Version#      Comments
    --  ------------------------------------------------------------------------------
    --  22-May-2020     Aravind Kannuri     1.0           Initial Version
    --
    --  ###################################################################################

    --To fetch Ledger Id based on OU
    FUNCTION get_ledger_id (p_org_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_ledger_id   NUMBER := 0;
    BEGIN
        BEGIN
            SELECT gl.ledger_id
              INTO ln_ledger_id
              FROM apps.hr_operating_units hou, apps.gl_ledgers gl
             WHERE     hou.set_of_books_id = gl.ledger_id
                   AND hou.date_to IS NULL
                   AND hou.organization_id = p_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_ledger_id   := 0;
        END;

        RETURN ln_ledger_id;
    END get_ledger_id;

    --To fetch ledger Currency
    FUNCTION get_ledger_curr (p_ledger_id IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_ledger_curr   VARCHAR2 (10) := NULL;
    BEGIN
        BEGIN
            SELECT currency_code
              INTO lv_ledger_curr
              FROM gl_ledgers
             WHERE ledger_id = p_ledger_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_ledger_curr   := NULL;
        END;

        RETURN lv_ledger_curr;
    END get_ledger_curr;

    --To fetch Period Name
    FUNCTION get_period_name (p_ledger_id IN NUMBER, p_gl_date IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_period_name   VARCHAR2 (100) := NULL;
    BEGIN
        BEGIN
            SELECT period_name
              INTO lv_period_name
              FROM gl_period_statuses
             WHERE     application_id = 101
                   AND ledger_id = p_ledger_id
                   AND closing_status = 'O'
                   AND p_gl_date BETWEEN start_date AND end_date;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Exp- Open Period is not found for date : '
                    || p_gl_date
                    || CHR (9)
                    || ' ledger ID = '
                    || p_ledger_id);

                lv_period_name   := NULL;
            WHEN TOO_MANY_ROWS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Exp- Multiple Open periods found for date : '
                    || p_gl_date
                    || CHR (9)
                    || ' ledger ID = '
                    || p_ledger_id);

                lv_period_name   := NULL;
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Exp- Failed to fetch open period date for date : '
                    || p_gl_date
                    || CHR (9)
                    || SQLERRM);

                lv_period_name   := NULL;
        END;

        RETURN lv_period_name;
    END get_period_name;


    --To fetch Journal Source
    FUNCTION get_journal_source (p_journal_source IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_journal_source   VARCHAR2 (100);
    BEGIN
        BEGIN
            SELECT user_je_source_name
              INTO lv_journal_source
              FROM gl_je_sources
             WHERE user_je_source_name = p_journal_source --'Discount Extract'
                                                          AND language = 'US';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_journal_source   := NULL;
        END;

        RETURN lv_journal_source;
    END get_journal_source;


    --To fetch Journal Category
    FUNCTION get_journal_category (p_journal_category IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_journal_category   VARCHAR2 (100);
    BEGIN
        BEGIN
            SELECT user_je_category_name
              INTO lv_journal_category
              FROM gl_je_categories
             WHERE     user_je_category_name = p_journal_category --'Discount Extract'
                   AND language = 'US';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_journal_category   := NULL;
        END;

        RETURN lv_journal_category;
    END get_journal_category;


    --To fetch Journal Name \ Batch Name
    FUNCTION get_journal_name (p_currency VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_journal_name   VARCHAR2 (100);
    BEGIN
        BEGIN
            SELECT 'Discount Extract' || '-' || TO_CHAR (SYSDATE, 'MMDDRRRR') || '-' || p_currency --'USD'
              INTO lv_journal_name
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_journal_name   := NULL;
        END;

        RETURN lv_journal_name;
    END get_journal_name;


    --To fetch Line Description
    FUNCTION get_description (p_brand VARCHAR2, p_currency VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_description   VARCHAR2 (100);
    BEGIN
        BEGIN
            SELECT 'Discount Extract' || '-' || p_brand || '-' || TO_CHAR (SYSDATE, 'MMDDRRRR') || '-' || p_currency
              INTO lv_description
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_description   := NULL;
        END;

        RETURN lv_description;
    END get_description;

    --To fetch Last Run Date from Valueset
    FUNCTION get_last_run_dt (p_org_id IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_last_run_dt   VARCHAR2 (30) := NULL;
    BEGIN
        BEGIN
            SELECT flv.attribute4
              INTO lv_last_run_dt
              FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl flv
             WHERE     fvs.flex_value_set_id = flv.flex_value_set_id
                   AND fvs.flex_value_set_name =
                       'XXD_GL_AR_DISCOUNT_JOURNAL_VS'
                   AND SYSDATE BETWEEN NVL (TRUNC (flv.start_date_active),
                                            SYSDATE)
                                   AND NVL (TRUNC (flv.end_date_active),
                                            SYSDATE + 1)
                   AND TO_NUMBER (NVL (flv.attribute1, -99)) = p_org_id
                   AND flv.enabled_flag = 'Y'
                   AND flv.summary_flag = 'N';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_last_run_dt   := NULL;
        END;

        RETURN lv_last_run_dt;
    END;

    --To fetch Debit Account from Valueset
    FUNCTION get_debit_acct (p_org_id IN NUMBER, p_brand IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_debit_acct       VARCHAR2 (150) := NULL;
        lv_acct_segments    VARCHAR2 (150) := NULL;
        lv_segment1         VARCHAR2 (50) := NULL;
        lv_segment2         VARCHAR2 (50) := NULL;
        lv_rest_segments    VARCHAR2 (150) := NULL;
        lv_brand_segment2   VARCHAR2 (50) := NULL;
    BEGIN
        --Segregate Account Segments exists in Valueset
        BEGIN
            SELECT flv.attribute2,
                   SUBSTR (flv.attribute2,
                           1,
                           INSTR (flv.attribute2, '.') - 1),
                   SUBSTR (flv.attribute2,
                             INSTR (flv.attribute2, '.', 1,
                                    1)
                           + 1,
                           INSTR (flv.attribute2, '.', 2,
                                  1)),
                   SUBSTR (flv.attribute2,
                             INSTR (flv.attribute2, '.', 1,
                                    2)
                           + 1,
                           INSTR (flv.attribute2, '.', 2,
                                  6))
              INTO lv_acct_segments, lv_segment1, lv_segment2, lv_rest_segments
              FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl flv
             WHERE     fvs.flex_value_set_id = flv.flex_value_set_id
                   AND fvs.flex_value_set_name =
                       'XXD_GL_AR_DISCOUNT_JOURNAL_VS'
                   AND SYSDATE BETWEEN NVL (TRUNC (flv.start_date_active),
                                            SYSDATE)
                                   AND NVL (TRUNC (flv.end_date_active),
                                            SYSDATE + 1)
                   AND TO_NUMBER (NVL (flv.attribute1, -99)) = p_org_id
                   AND flv.enabled_flag = 'Y'
                   AND flv.summary_flag = 'N';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_acct_segments   := NULL;
                lv_segment1        := NULL;
                lv_segment2        := NULL;
                lv_rest_segments   := NULL;
        END;

        --Fetch Segment2 by Brand from Valueset
        BEGIN
            SELECT flv.flex_value
              INTO lv_brand_segment2
              FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl flv
             WHERE     fvs.flex_value_set_id = flv.flex_value_set_id
                   AND fvs.flex_value_set_name = 'DO_GL_BRAND'
                   AND SYSDATE BETWEEN NVL (TRUNC (flv.start_date_active),
                                            SYSDATE)
                                   AND NVL (TRUNC (flv.end_date_active),
                                            SYSDATE + 1)
                   AND UPPER (NVL (flv.description, 'NA')) = p_brand
                   AND flv.enabled_flag = 'Y'
                   AND flv.summary_flag = 'N';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_brand_segment2   := NULL;
        END;

        --To derive final account
        IF (lv_segment1 IS NOT NULL AND lv_brand_segment2 IS NOT NULL AND lv_rest_segments IS NOT NULL)
        THEN
            lv_debit_acct   :=
                   lv_segment1
                || '.'
                || lv_brand_segment2
                || '.'
                || lv_rest_segments;
        ELSIF lv_brand_segment2 IS NULL
        THEN
            lv_debit_acct   := lv_acct_segments;
        ELSE
            lv_debit_acct   := NULL;
        END IF;

        RETURN lv_debit_acct;
    END;

    --To fetch Credit Account from Valueset
    FUNCTION get_credit_acct (p_org_id IN NUMBER, p_brand IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_credit_acct      VARCHAR2 (150) := NULL;
        lv_acct_segments    VARCHAR2 (150) := NULL;
        lv_segment1         VARCHAR2 (50) := NULL;
        lv_segment2         VARCHAR2 (50) := NULL;
        lv_rest_segments    VARCHAR2 (150) := NULL;
        lv_brand_segment2   VARCHAR2 (50) := NULL;
    BEGIN
        --Segregate Account Segments exists in Valueset
        BEGIN
            SELECT flv.attribute3,
                   SUBSTR (flv.attribute3,
                           1,
                           INSTR (flv.attribute3, '.') - 1),
                   SUBSTR (flv.attribute3,
                             INSTR (flv.attribute3, '.', 1,
                                    1)
                           + 1,
                           INSTR (flv.attribute3, '.', 2,
                                  1)),
                   SUBSTR (flv.attribute3,
                             INSTR (flv.attribute3, '.', 1,
                                    2)
                           + 1,
                           INSTR (flv.attribute3, '.', 2,
                                  6))
              INTO lv_acct_segments, lv_segment1, lv_segment2, lv_rest_segments
              FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl flv
             WHERE     fvs.flex_value_set_id = flv.flex_value_set_id
                   AND fvs.flex_value_set_name =
                       'XXD_GL_AR_DISCOUNT_JOURNAL_VS'
                   AND SYSDATE BETWEEN NVL (TRUNC (flv.start_date_active),
                                            SYSDATE)
                                   AND NVL (TRUNC (flv.end_date_active),
                                            SYSDATE + 1)
                   AND TO_NUMBER (NVL (flv.attribute1, -99)) = p_org_id
                   AND flv.enabled_flag = 'Y'
                   AND flv.summary_flag = 'N';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_acct_segments   := NULL;
                lv_segment1        := NULL;
                lv_segment2        := NULL;
                lv_rest_segments   := NULL;
        END;

        --Fetch Segment2 by Brand from Valueset
        BEGIN
            SELECT flv.flex_value
              INTO lv_brand_segment2
              FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl flv
             WHERE     fvs.flex_value_set_id = flv.flex_value_set_id
                   AND fvs.flex_value_set_name = 'DO_GL_BRAND'
                   AND SYSDATE BETWEEN NVL (TRUNC (flv.start_date_active),
                                            SYSDATE)
                                   AND NVL (TRUNC (flv.end_date_active),
                                            SYSDATE + 1)
                   AND UPPER (NVL (flv.description, 'NA')) = p_brand
                   AND flv.enabled_flag = 'Y'
                   AND flv.summary_flag = 'N';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_brand_segment2   := NULL;
        END;

        --To derive final account
        IF (lv_segment1 IS NOT NULL AND lv_brand_segment2 IS NOT NULL AND lv_rest_segments IS NOT NULL)
        THEN
            lv_credit_acct   :=
                   lv_segment1
                || '.'
                || lv_brand_segment2
                || '.'
                || lv_rest_segments;
        ELSIF lv_brand_segment2 IS NULL
        THEN
            lv_credit_acct   := lv_acct_segments;
        ELSE
            lv_credit_acct   := NULL;
        END IF;

        RETURN lv_credit_acct;
    END;

    --To fetch CCID
    FUNCTION get_ccid (p_conc_segments IN VARCHAR2)
        RETURN VARCHAR2
    IS
        ln_ccid   NUMBER := 0;
    BEGIN
        BEGIN
            SELECT code_combination_id
              INTO ln_ccid
              FROM gl_code_combinations_kfv kfv
             WHERE 1 = 1 AND concatenated_segments = TRIM (p_conc_segments);
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_ccid   := 0;
        END;

        RETURN ln_ccid;
    END;

    --To validate OU Exists in Valueset
    FUNCTION valid_ou_exists (p_org_id IN NUMBER, p_generate_gl IN VARCHAR2)
        RETURN VARCHAR2
    IS
        ln_ou_exists_vs   NUMBER := 0;
    BEGIN
        BEGIN
            SELECT COUNT (flv.attribute1)
              INTO ln_ou_exists_vs
              FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl flv
             WHERE     fvs.flex_value_set_id = flv.flex_value_set_id
                   AND fvs.flex_value_set_name =
                       'XXD_GL_AR_DISCOUNT_JOURNAL_VS'
                   AND SYSDATE BETWEEN NVL (TRUNC (flv.start_date_active),
                                            SYSDATE)
                                   AND NVL (TRUNC (flv.end_date_active),
                                            SYSDATE + 1)
                   AND TO_NUMBER (NVL (flv.attribute1, -99)) = p_org_id
                   AND NVL (flv.attribute5, 'N') = 'Y'
                   AND NVL (flv.attribute5, 'N') = NVL (p_generate_gl, 'N')
                   AND flv.enabled_flag = 'Y'
                   AND flv.summary_flag = 'N';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_ou_exists_vs   := 0;
        END;

        RETURN ln_ou_exists_vs;
    END valid_ou_exists;


    --Insert into GL Interface
    PROCEDURE insert_gl_data (p_org_id             IN NUMBER,
                              p_ledger_id          IN NUMBER,
                              p_transaction_date   IN DATE,
                              p_curr_code          IN VARCHAR2,
                              p_journal_source     IN VARCHAR2,
                              p_journal_category   IN VARCHAR2,
                              p_journal_desc       IN VARCHAR2,
                              p_group_id           IN NUMBER,
                              p_journal_name       IN VARCHAR2, --Journal_name\Batch_name
                              p_period_name        IN VARCHAR2,
                              p_brand              IN VARCHAR2,
                              p_db_cr_amt          IN NUMBER,
                              p_db_acct_ccid       IN NUMBER,
                              p_cr_acct_ccid       IN NUMBER)
    IS
    BEGIN
        -- Debit line insertion into GL Interface
        BEGIN
            INSERT INTO gl.gl_interface (status, ledger_id, accounting_date,
                                         currency_code, date_created, created_by, actual_flag, reference10, --Line Description
                                                                                                            entered_dr, user_je_source_name, --Journal Source
                                                                                                                                             user_je_category_name, --Journal Category
                                                                                                                                                                    GROUP_ID, reference1, -- Batch Name
                                                                                                                                                                                          reference4, -- Journal_name
                                                                                                                                                                                                      period_name
                                         , code_combination_id)
                 VALUES ('NEW', p_ledger_id, p_transaction_date,
                         p_curr_code, SYSDATE, fnd_global.user_id,
                         'A', p_journal_desc,               --Line Description
                                              p_db_cr_amt,
                         p_journal_source, p_journal_category, p_group_id,
                         p_journal_name,                          --Batch_name
                                         p_journal_name,        --Journal_name
                                                         p_period_name,
                         p_db_acct_ccid);

            COMMIT;
            fnd_file.put_line (
                fnd_file.LOG,
                'Successfully Inserted of Debit line in GL Interface');
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Failed Debit line Insertion into GL Interface -'
                    || SQLERRM);
        END;

        -- Credit line Insertion into GL Interface
        BEGIN
            INSERT INTO gl.gl_interface (status, ledger_id, accounting_date,
                                         currency_code, date_created, created_by, actual_flag, reference10, --Line Description
                                                                                                            entered_cr, user_je_source_name, --Journal Source
                                                                                                                                             user_je_category_name, --Journal Category
                                                                                                                                                                    GROUP_ID, reference1, -- Batch Name
                                                                                                                                                                                          reference4, -- Journal_name
                                                                                                                                                                                                      period_name
                                         , code_combination_id)
                 VALUES ('NEW', p_ledger_id, p_transaction_date,
                         p_curr_code, SYSDATE, fnd_global.user_id,
                         'A', p_journal_desc,               --Line Description
                                              p_db_cr_amt,
                         p_journal_source, p_journal_category, p_group_id,
                         p_journal_name,                          --Batch_name
                                         p_journal_name,        --Journal_name
                                                         p_period_name,
                         p_cr_acct_ccid);

            COMMIT;
            fnd_file.put_line (
                fnd_file.LOG,
                'Successfully Inserted of Credit line in GL Interface');
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Failed Credit line Insertion into GL Interface -'
                    || SQLERRM);
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Exp- Failed to insert the data into Gl Interface...'
                || SQLERRM);
    END;

    --Main Procedure
    PROCEDURE main (x_retcode          OUT NOCOPY NUMBER,
                    x_errbuf           OUT NOCOPY VARCHAR2,
                    p_org_id        IN            NUMBER,
                    p_as_of_date    IN            VARCHAR2,
                    p_summary_by    IN            VARCHAR2,
                    p_generate_gl   IN            VARCHAR2)
    IS
        CURSOR c_get_ar_disc_dtls (lv_last_run_dt_vs IN VARCHAR2)
        IS
              SELECT brand, SUM (a.original_amt) original_amt, SUM (a.remaining_amt) remaining_amt,
                     SUM (a.discount_amt) discount_amt, ROUND (SUM (a.discount_amt), -3) discount_amt_round_3, SUM (a.line_amount) line_amount,
                     ROUND (AVG (a.discount_percent), 2) discount_percent
                FROM (  SELECT customer_number, customer_name, NVL (brand, 'NONE') AS brand,
                               NVL (trx_number, 'NONE') AS trx_number, NVL (trx_type, 'NONE') AS trx_type, NVL (trx_date, TO_DATE ('01-JAN-1900')) AS trx_date,
                               NVL (terms, 'NONE') terms, NVL (due_date, TO_DATE ('01-JAN-1900')) AS due_date, NVL (discount_percent, 0) discount_percent,
                               past_due_days, SUM (orig_amt) original_amt, SUM (amount) remaining_amt,
                               NVL (ROUND (SUM (line_amount) * (discount_percent / 100), 2), 0) discount_amt, SUM (line_amount) line_amount
                          FROM (SELECT rc.customer_number, rc.customer_name, NVL (hca.attribute1, 'NONE') brand,
                                       apsa.trx_number, types.name trx_type, apsa.trx_date,
                                       rtt.name terms, due_date, rtld.discount_percent,
                                       ROUND ((amount_due_original * NVL (apsa.exchange_rate, 1)), 2) orig_amt, (TO_DATE (p_as_of_date, 'YYYY/MM/DD HH24:MI:SS') - apsa.due_date) past_due_days, acctd_amount_due_remaining amount,
                                       NVL (apsa.amount_line_items_remaining, 0) line_amount
                                  FROM ar_payment_schedules_all apsa, ra_terms_tl rtt, ra_terms_lines_discounts rtld,
                                       ra_cust_trx_types_all types, ra_customer_trx_all rcta, xxd_ra_customers_v rc,
                                       hz_cust_accounts_all hca
                                 WHERE     apsa.status = 'OP'
                                       AND hca.cust_account_id =
                                           rcta.bill_to_customer_id
                                       AND hca.cust_account_id = rc.customer_id
                                       AND TRUNC (apsa.trx_date) BETWEEN TRUNC (
                                                                             NVL (
                                                                                 TO_DATE (
                                                                                     lv_last_run_dt_vs,
                                                                                     'YYYY/MM/DD HH24:MI:SS'),
                                                                                 apsa.trx_date))
                                                                     AND TRUNC (
                                                                             TO_DATE (
                                                                                 p_as_of_date,
                                                                                 'YYYY/MM/DD HH24:MI:SS'))
                                       AND TRUNC (apsa.gl_date) BETWEEN TRUNC (
                                                                            NVL (
                                                                                TO_DATE (
                                                                                    lv_last_run_dt_vs,
                                                                                    'YYYY/MM/DD HH24:MI:SS'),
                                                                                apsa.gl_date))
                                                                    AND TRUNC (
                                                                            TO_DATE (
                                                                                p_as_of_date,
                                                                                'YYYY/MM/DD HH24:MI:SS'))
                                       AND apsa.org_id = p_org_id
                                       AND rc.customer_id = apsa.customer_id
                                       AND rtt.term_id(+) = apsa.term_id
                                       AND rtt.LANGUAGE(+) = 'US'
                                       AND types.cust_trx_type_id(+) =
                                           apsa.cust_trx_type_id
                                       AND types.org_id(+) = apsa.org_id
                                       AND rcta.customer_trx_id(+) =
                                           apsa.customer_trx_id
                                       AND rtld.term_id(+) = apsa.term_id
                                UNION ALL
                                SELECT rc.customer_number, rc.customer_name, NVL (hca.attribute1, 'NONE') brand,
                                       apsa.trx_number, types.name trx_type, apsa.trx_date,
                                       rtt.name terms, apsa.due_date, rtld.discount_percent,
                                       amount_due_original orig_amt, (TO_DATE (p_as_of_date, 'YYYY/MM/DD HH24:MI:SS') - apsa.due_date) past_due_days, -NVL (araa.amount_applied, 0) amount,
                                       -NVL (araa.line_applied, 0) line_amount
                                  FROM ar_payment_schedules_all apsa, apps.ar_receivable_applications_all araa, ra_terms_tl rtt,
                                       ra_terms_lines_discounts rtld, ra_cust_trx_types_all types, ra_customer_trx_all rcta,
                                       xxd_ra_customers_v rc, hz_cust_accounts_all hca
                                 WHERE     apsa.payment_schedule_id =
                                           araa.payment_schedule_id
                                       AND hca.cust_account_id =
                                           rcta.bill_to_customer_id
                                       AND hca.cust_account_id = rc.customer_id
                                       AND araa.gl_date >
                                           TO_DATE (p_as_of_date,
                                                    'YYYY/MM/DD HH24:MI:SS')
                                       AND TRUNC (apsa.trx_date) BETWEEN TRUNC (
                                                                             NVL (
                                                                                 TO_DATE (
                                                                                     lv_last_run_dt_vs,
                                                                                     'YYYY/MM/DD HH24:MI:SS'),
                                                                                 apsa.trx_date))
                                                                     AND TRUNC (
                                                                             TO_DATE (
                                                                                 p_as_of_date,
                                                                                 'YYYY/MM/DD HH24:MI:SS'))
                                       AND TRUNC (apsa.gl_date) BETWEEN TRUNC (
                                                                            NVL (
                                                                                TO_DATE (
                                                                                    lv_last_run_dt_vs,
                                                                                    'YYYY/MM/DD HH24:MI:SS'),
                                                                                apsa.gl_date))
                                                                    AND TRUNC (
                                                                            TO_DATE (
                                                                                p_as_of_date,
                                                                                'YYYY/MM/DD HH24:MI:SS'))
                                       AND apsa.org_id = p_org_id
                                       AND rc.customer_id = apsa.customer_id
                                       AND araa.status IN ('APP', 'ACTIVITY')
                                       AND rtt.term_id(+) = apsa.term_id
                                       AND rtt.LANGUAGE(+) = 'US'
                                       AND types.cust_trx_type_id(+) =
                                           apsa.cust_trx_type_id
                                       AND types.org_id(+) = apsa.org_id
                                       AND rcta.customer_trx_id(+) =
                                           apsa.customer_trx_id
                                       AND rtld.term_id(+) = apsa.term_id
                                UNION ALL
                                SELECT rc.customer_number, rc.customer_name, NVL (hca.attribute1, 'NONE') brand,
                                       apsa.trx_number, types.name trx_type, apsa.trx_date,
                                       rtt.name terms, apsa.due_date, rtld.discount_percent,
                                       amount_due_original orig_amt, (TO_DATE (p_as_of_date, 'YYYY/MM/DD HH24:MI:SS') - apsa.due_date) past_due_days, (NVL (araa.amount_applied, 0) + NVL (araa.earned_discount_taken, 0) + NVL (araa.unearned_discount_taken, 0)) amount,
                                       NVL (araa.line_applied, 0) + NVL (araa.earned_discount_taken, 0) + NVL (araa.unearned_discount_taken, 0) line_amount
                                  FROM ar_payment_schedules_all apsa, apps.ar_receivable_applications_all araa, ra_terms_tl rtt,
                                       ra_terms_lines_discounts rtld, ra_cust_trx_types_all types, ra_customer_trx_all rcta,
                                       xxd_ra_customers_v rc, hz_cust_accounts_all hca
                                 WHERE     apsa.payment_schedule_id =
                                           araa.applied_payment_schedule_id
                                       AND hca.cust_account_id =
                                           rcta.bill_to_customer_id
                                       AND hca.cust_account_id = rc.customer_id
                                       AND araa.gl_date >
                                           TO_DATE (p_as_of_date,
                                                    'YYYY/MM/DD HH24:MI:SS')
                                       AND TRUNC (apsa.trx_date) BETWEEN TRUNC (
                                                                             NVL (
                                                                                 TO_DATE (
                                                                                     lv_last_run_dt_vs,
                                                                                     'YYYY/MM/DD HH24:MI:SS'),
                                                                                 apsa.trx_date))
                                                                     AND TRUNC (
                                                                             TO_DATE (
                                                                                 p_as_of_date,
                                                                                 'YYYY/MM/DD HH24:MI:SS'))
                                       AND TRUNC (apsa.gl_date) BETWEEN TRUNC (
                                                                            NVL (
                                                                                TO_DATE (
                                                                                    lv_last_run_dt_vs,
                                                                                    'YYYY/MM/DD HH24:MI:SS'),
                                                                                apsa.gl_date))
                                                                    AND TRUNC (
                                                                            TO_DATE (
                                                                                p_as_of_date,
                                                                                'YYYY/MM/DD HH24:MI:SS'))
                                       AND apsa.org_id = p_org_id
                                       AND rc.customer_id = apsa.customer_id
                                       AND apsa.CLASS != 'PMT'
                                       AND araa.status IN ('APP', 'ACTIVITY')
                                       AND rtt.term_id(+) = apsa.term_id
                                       AND rtt.LANGUAGE(+) = 'US'
                                       AND types.cust_trx_type_id(+) =
                                           apsa.cust_trx_type_id
                                       AND types.org_id(+) = apsa.org_id
                                       AND rcta.customer_trx_id(+) =
                                           apsa.customer_trx_id
                                       AND rtld.term_id(+) = apsa.term_id
                                UNION ALL
                                SELECT rc.customer_number, --- New Query for Payments
                                                           rc.customer_name, NVL (hca.attribute1, 'NONE') brand,
                                       acra.receipt_number, 'NONE', apsa.trx_date,
                                       'NONE', apsa.due_date, NULL,
                                       amount_due_original orig_amt, (TRUNC (SYSDATE) - apsa.due_date) past_due_days, NVL (-acctd_amount_applied_from, 0) amount,
                                       NVL (apsa.amount_line_items_remaining, 0) line_amount
                                  FROM ar_cash_receipts_all acra, ar_payment_schedules_all apsa, xxd_ra_customers_v rc,
                                       hz_cust_accounts hca, apps.ar_receivable_applications_all araa
                                 WHERE     1 = 1
                                       AND acra.cash_receipt_id =
                                           apsa.cash_receipt_id
                                       AND acra.cash_receipt_id =
                                           araa.cash_receipt_id
                                       AND apsa.customer_id = rc.customer_id
                                       AND hca.cust_account_id = rc.customer_id
                                       AND apsa.org_id = p_org_id
                                       AND araa.status NOT IN ('APP', 'ACTIVITY')
                                       AND TRUNC (apsa.gl_date) BETWEEN TRUNC (
                                                                            NVL (
                                                                                TO_DATE (
                                                                                    lv_last_run_dt_vs,
                                                                                    'YYYY/MM/DD HH24:MI:SS'),
                                                                                apsa.gl_date))
                                                                    AND TRUNC (
                                                                            TO_DATE (
                                                                                p_as_of_date,
                                                                                'YYYY/MM/DD HH24:MI:SS'))
                                       AND TRUNC (araa.gl_date) BETWEEN TRUNC (
                                                                            NVL (
                                                                                TO_DATE (
                                                                                    lv_last_run_dt_vs,
                                                                                    'YYYY/MM/DD HH24:MI:SS'),
                                                                                araa.gl_date))
                                                                    AND TRUNC (
                                                                            TO_DATE (
                                                                                p_as_of_date,
                                                                                'YYYY/MM/DD HH24:MI:SS'))
                                UNION ALL
                                SELECT 'UNIDENTIFIED', --- Unidentified Receipts
                                                       'NONE', 'NONE',
                                       acra.receipt_number, 'NONE', apsa.trx_date,
                                       'NONE', apsa.due_date, NULL,
                                       amount_due_original orig_amt, (TRUNC (SYSDATE) - apsa.due_date) past_due_days, NVL (-araa.amount_applied, 0) amount,
                                       NVL (apsa.amount_line_items_remaining, 0) line_amount
                                  FROM ar_cash_receipts_all acra, ar_payment_schedules_all apsa, apps.ar_receivable_applications_all araa
                                 WHERE     1 = 1
                                       AND acra.cash_receipt_id =
                                           apsa.cash_receipt_id
                                       AND acra.cash_receipt_id =
                                           araa.cash_receipt_id
                                       AND apsa.org_id = p_org_id
                                       AND araa.status IN ('UNID')
                                       AND TRUNC (apsa.gl_date) BETWEEN TRUNC (
                                                                            NVL (
                                                                                TO_DATE (
                                                                                    lv_last_run_dt_vs,
                                                                                    'YYYY/MM/DD HH24:MI:SS'),
                                                                                apsa.gl_date))
                                                                    AND TRUNC (
                                                                            TO_DATE (
                                                                                p_as_of_date,
                                                                                'YYYY/MM/DD HH24:MI:SS'))
                                       AND TRUNC (araa.gl_date) BETWEEN TRUNC (
                                                                            NVL (
                                                                                TO_DATE (
                                                                                    lv_last_run_dt_vs,
                                                                                    'YYYY/MM/DD HH24:MI:SS'),
                                                                                araa.gl_date))
                                                                    AND TRUNC (
                                                                            TO_DATE (
                                                                                p_as_of_date,
                                                                                'YYYY/MM/DD HH24:MI:SS'))
                                UNION ALL
                                SELECT rc.customer_number, -- Reversed payments
                                                           rc.customer_name, NVL (hca.attribute1, 'NONE') AS brand,
                                       NVL (acra.receipt_number, 'NONE') AS receipt_number, NVL (types.name, 'NONE') AS trx_type, NVL (apsa.trx_date, TO_DATE ('01-JAN-1900')) AS trx_date,
                                       NVL (rtt.name, 'NONE') terms, NVL (apsa.due_date, TO_DATE ('01-JAN-1900')) AS due_date, -- 03/19/08 KWG END --
                                                                                                                               rtld.discount_percent,
                                       amount_due_original orig_amt, (TRUNC (SYSDATE) - apsa.due_date) past_due_days, -NVL (acra.amount, 0) amount,
                                       0 line_amount
                                  FROM ar_cash_receipts_all acra, ar_payment_schedules_all apsa, ra_terms_tl rtt,
                                       ra_terms_lines_discounts rtld, ra_cust_trx_types_all types, ra_customer_trx_all rcta,
                                       xxd_ra_customers_v rc, hz_cust_accounts_all hca
                                 WHERE     acra.pay_from_customer =
                                           rc.customer_id
                                       AND hca.cust_account_id =
                                           rcta.bill_to_customer_id
                                       AND hca.cust_account_id = rc.customer_id
                                       AND acra.reversal_date >
                                           TO_DATE (p_as_of_date,
                                                    'YYYY/MM/DD HH24:MI:SS')
                                       AND TRUNC (apsa.trx_date) BETWEEN TRUNC (
                                                                             NVL (
                                                                                 TO_DATE (
                                                                                     lv_last_run_dt_vs,
                                                                                     'YYYY/MM/DD HH24:MI:SS'),
                                                                                 apsa.trx_date))
                                                                     AND TRUNC (
                                                                             TO_DATE (
                                                                                 p_as_of_date,
                                                                                 'YYYY/MM/DD HH24:MI:SS'))
                                       AND TRUNC (acra.receipt_date) BETWEEN TRUNC (
                                                                                 NVL (
                                                                                     TO_DATE (
                                                                                         lv_last_run_dt_vs,
                                                                                         'YYYY/MM/DD HH24:MI:SS'),
                                                                                     acra.receipt_date))
                                                                         AND TRUNC (
                                                                                 TO_DATE (
                                                                                     p_as_of_date,
                                                                                     'YYYY/MM/DD HH24:MI:SS'))
                                       AND TRUNC (apsa.gl_date) BETWEEN TRUNC (
                                                                            NVL (
                                                                                TO_DATE (
                                                                                    lv_last_run_dt_vs,
                                                                                    'YYYY/MM/DD HH24:MI:SS'),
                                                                                apsa.gl_date))
                                                                    AND TRUNC (
                                                                            TO_DATE (
                                                                                p_as_of_date,
                                                                                'YYYY/MM/DD HH24:MI:SS'))
                                       AND apsa.org_id = p_org_id
                                       AND acra.cash_receipt_id =
                                           apsa.cash_receipt_id
                                       AND rc.customer_id = apsa.customer_id
                                       AND rtt.term_id(+) = apsa.term_id
                                       AND rtt.LANGUAGE(+) = 'US'
                                       AND apsa.cust_trx_type_id =
                                           types.cust_trx_type_id(+)
                                       AND apsa.org_id = types.org_id(+)
                                       AND rtld.term_id(+) = apsa.term_id
                                       AND NOT EXISTS
                                               (SELECT 1
                                                  FROM apps.ra_customer_trx_all rct
                                                 WHERE rct.reversed_cash_receipt_id =
                                                       acra.cash_receipt_id)
                                -- Exclude Debit Memo Receipt Reversals - Don't impact receipt AR balances
                                UNION ALL
                                SELECT rc.customer_number, --- New Query for Adjustments
                                                           rc.customer_name, NVL (hca.attribute1, 'NONE') brand,
                                       apsa.trx_number, types.name trx_type, apsa.trx_date,
                                       rtt.name terms, apsa.due_date, rtld.discount_percent,
                                       amount_due_original orig_amt, (TO_DATE (TO_DATE (p_as_of_date, 'YYYY/MM/DD HH24:MI:SS')) - apsa.due_date) past_due_days, NVL (-1 * adj.amount, 0) amount,
                                       NVL (-1 * adj.amount, 0) line_amount
                                  FROM xxd_ra_customers_v rc, hz_cust_accounts hca, ar_adjustments_all adj,
                                       ar_receivables_trx_all rt, ra_customer_trx_all ct, ar_payment_schedules_all apsa,
                                       ra_cust_trx_types_all types, ra_terms_tl rtt, ra_terms_lines_discounts rtld
                                 WHERE     ADJ.STATUS = 'A'
                                       AND adj.org_id = rt.org_id
                                       AND adj.org_id = apsa.org_id
                                       AND adj.receivables_trx_id =
                                           rt.receivables_trx_id(+)
                                       AND adj.customer_trx_id =
                                           ct.customer_trx_id(+)
                                       AND ct.customer_trx_id =
                                           apsa.customer_trx_id
                                       AND apsa.customer_id = rc.customer_id
                                       AND hca.cust_account_id = rc.customer_id
                                       AND rtld.term_id(+) = apsa.term_id
                                       AND rtt.term_id(+) = apsa.term_id
                                       AND rtt.LANGUAGE(+) = 'US'
                                       AND apsa.org_id = p_org_id
                                       AND types.cust_trx_type_id(+) =
                                           apsa.cust_trx_type_id
                                       AND types.org_id(+) = apsa.org_id
                                       AND adj.gl_date >
                                           TO_DATE (p_as_of_date,
                                                    'YYYY/MM/DD HH24:MI:SS')
                                       AND TRUNC (ct.creation_date) BETWEEN TRUNC (
                                                                                NVL (
                                                                                    TO_DATE (
                                                                                        lv_last_run_dt_vs,
                                                                                        'YYYY/MM/DD HH24:MI:SS'),
                                                                                    ct.creation_date))
                                                                        AND TRUNC (
                                                                                TO_DATE (
                                                                                    p_as_of_date,
                                                                                    'YYYY/MM/DD HH24:MI:SS'))
                                       AND TRUNC (apsa.gl_date) BETWEEN TRUNC (
                                                                            NVL (
                                                                                TO_DATE (
                                                                                    lv_last_run_dt_vs,
                                                                                    'YYYY/MM/DD HH24:MI:SS'),
                                                                                apsa.gl_date))
                                                                    AND TRUNC (
                                                                            TO_DATE (
                                                                                p_as_of_date,
                                                                                'YYYY/MM/DD HH24:MI:SS')))
                      GROUP BY customer_number, customer_name, brand,
                               trx_number, trx_type, trx_date,
                               terms, due_date, discount_percent,
                               past_due_days, orig_amt
                        HAVING SUM (amount) <> 0) a
               WHERE 1 = 1 AND p_summary_by = 'BRAND'
            GROUP BY a.brand
            ORDER BY 1;

        --Variables Declaration
        lv_debit_acct         VARCHAR2 (150) := NULL;
        lv_credit_acct        VARCHAR2 (150) := NULL;
        ln_ledger_id          NUMBER := 0;
        lv_period_name        VARCHAR2 (100) := NULL;
        lv_curr_code          VARCHAR2 (10) := NULL;
        lv_last_run_dt_vs     VARCHAR2 (30) := NULL;
        lv_update_run_dt      VARCHAR2 (30) := NULL;
        ln_db_acct_ccid       NUMBER := 0;
        ln_cr_acct_ccid       NUMBER := 0;
        lv_source_category    VARCHAR2 (100) := 'Discount Extract';
        lv_journal_source     VARCHAR2 (100) := NULL;
        lv_journal_category   VARCHAR2 (100) := NULL;
        lv_journal_name       VARCHAR2 (100) := NULL;
        lv_journal_desc       VARCHAR2 (100) := NULL;
        ln_group_id           NUMBER := 99099;
        lv_sysdate            VARCHAR2 (100) := NULL;
        ln_iface_exists       NUMBER := 0;
        ln_base_exists        NUMBER := 0;

        lv_valid_flag         VARCHAR2 (150) := 'S';
        lv_valid_msg          VARCHAR2 (4000) := NULL;
        lv_dis_amt_0_exists   NUMBER := 0;
        lv_dis_amt_3_exists   NUMBER := 0;
        ln_valid_exists       NUMBER := 0;
        ln_success_cnt        NUMBER := 0;
        ln_error_cnt          NUMBER := 0;
        ln_skip_cnt           NUMBER := 0;
        ln_total_cnt          NUMBER := 0;
        ld_accounting_date    DATE;

        gl_exists_warning     EXCEPTION;
    BEGIN
        -------------------------------------------------------
        --Validate Generate_GL 'Y'or 'N' as per OU in Valueset
        -------------------------------------------------------
        ln_valid_exists     := valid_ou_exists (p_org_id, p_generate_gl);
        fnd_file.put_line (
            fnd_file.LOG,
            '**************************************************************************************');
        fnd_file.put_line (
            fnd_file.LOG,
            'Validate Generate_GL for OU exists : ' || ln_valid_exists);

        -------------------------------------------------------------------------
        --#CASE1  --UAT Change requirement
        --As per UAT change requirement, not considering As-of-Date from Valueset
        --Pick all Journal till Parameter-as-of-date all the time
        -------------------------------------------------------------------------
        ---------------------------------
        --Validate Record in IFACE Exists
        ---------------------------------
        BEGIN
            SELECT COUNT (1)
              INTO ln_iface_exists
              FROM gl_interface gl
             WHERE     1 = 1
                   AND user_je_source_name = lv_source_category --'Discount Extract'
                   AND user_je_category_name = lv_source_category
                   AND TRUNC (accounting_date) =
                       TO_DATE (p_as_of_date, 'YYYY/MM/DD HH24:MI:SS');
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_iface_exists   := -99;
        END;

        fnd_file.put_line (
            fnd_file.LOG,
            'Records already exists in GL Interface ' || ln_iface_exists);

        --------------------------------------
        --Validate Record in Base Table Exists
        --------------------------------------
        BEGIN
            SELECT COUNT (1)
              INTO ln_base_exists
              FROM gl_je_headers
             WHERE     1 = 1
                   AND je_source = lv_source_category     --'Discount Extract'
                   AND je_category = lv_source_category
                   AND TRUNC (default_effective_date) =
                       TO_DATE (p_as_of_date, 'YYYY/MM/DD HH24:MI:SS');
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_base_exists   := -99;
        END;

        fnd_file.put_line (
            fnd_file.LOG,
            'Records already exists in GL Base table ' || ln_base_exists);

        -----------------------------------------------------
        --Calling function to get Last Run Date from Valueset
        -----------------------------------------------------
        lv_last_run_dt_vs   := get_last_run_dt (p_org_id);
        fnd_file.put_line (fnd_file.LOG,
                           'Parameter As-of-Date : ' || p_as_of_date);
        fnd_file.put_line (fnd_file.LOG,
                           'Valueset As-of-Date  : ' || lv_last_run_dt_vs);

        --Validate Parameter 'As-of_Date' should not less than 'Last Run Date' in Valueset
        IF lv_last_run_dt_vs IS NOT NULL
        THEN
            IF TO_DATE (p_as_of_date, 'YYYY/MM/DD HH24:MI:SS') <=
               TO_DATE (lv_last_run_dt_vs, 'YYYY/MM/DD HH24:MI:SS')
            THEN
                lv_valid_flag   := 'E';
                lv_valid_msg    :=
                       'Parameter ''p_as_of_date'' :'
                    || TO_DATE (p_as_of_date, 'YYYY/MM/DD HH24:MI:SS')
                    || ' should not be Less than or Equal to ''last_run_date'' in Valueset : '
                    || TO_DATE (lv_last_run_dt_vs, 'YYYY/MM/DD HH24:MI:SS');

                --Validate record exist in Base and Iface table
                IF (NVL (ln_iface_exists, 0) > 0 OR NVL (ln_base_exists, 0) > 0)
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Records exists in GL Interface or in GL. Please correct and take necessary action : '
                        || CHR (10)
                        || lv_valid_msg);
                    RAISE gl_exists_warning;
                END IF;
            END IF;
        END IF;

        -------------------------------------------
        --To get Run Date for to update in valueset
        -------------------------------------------
        IF TO_DATE (p_as_of_date, 'YYYY/MM/DD HH24:MI:SS') = TRUNC (SYSDATE)
        THEN
            lv_update_run_dt   := TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS');
        ELSE
            lv_update_run_dt   := p_as_of_date;
        END IF;

        ---------------------------------------
        --Generate_GL in valueset as 'N' for OU
        ---------------------------------------
        IF (NVL (ln_valid_exists, 0) <= 0 AND p_generate_gl = 'N')
        THEN
            fnd_file.put_line (
                fnd_file.output,
                '###########################################################################################################');
            fnd_file.put_line (
                fnd_file.output,
                '***''Generate_GL'' marked in the value-set as ''No'' for this OU, Skiped Insertion process to GL Interface');
            fnd_file.put_line (
                fnd_file.output,
                '***To Process AR Discount records set both Parameter and Valueset ''Generage_GL'' to ''Yes''..');
            fnd_file.put_line (
                fnd_file.output,
                '###########################################################################################################');
            fnd_file.put_line (fnd_file.output,
                               'Brand' || CHR (9) || 'Discount Amount');
            -------------------------------------------------------------------------
            --#CASE2  --UAT Change requirement
            --Should not consider As-of-Date value in Valueset for Picking Journals
            --Pick all Journals till Parameter-as-of-date in all cases
            -------------------------------------------------------------------------
            lv_last_run_dt_vs   := NULL; -- Passing NULL to pick till Parameter-as-of-date

            --Calling cursor to display in OUTPUT, Generage_GL for OU marked as 'N'
            FOR c_rec IN c_get_ar_disc_dtls (lv_last_run_dt_vs)
            LOOP
                IF c_rec.discount_amt_round_3 <> 0
                THEN
                    fnd_file.put_line (
                        fnd_file.output,
                           c_rec.brand
                        || CHR (9)
                        || TO_CHAR (c_rec.discount_amt_round_3,
                                    'FM999G999G999G999D99'));
                    lv_dis_amt_3_exists   := lv_dis_amt_3_exists + 1;
                ELSIF c_rec.discount_amt_round_3 = 0
                THEN
                    lv_dis_amt_0_exists   := c_get_ar_disc_dtls%ROWCOUNT;
                END IF;
            END LOOP;

            --To display No Records message in OUTPUT
            IF (lv_dis_amt_0_exists > 0 AND lv_dis_amt_3_exists = 0)
            THEN
                fnd_file.put_line (
                    fnd_file.output,
                    'No records fetched which Discount Amounts > 0;');
            END IF;

            fnd_file.put_line (
                fnd_file.output,
                '##############################################################');
        ELSE           --(NVL(ln_valid_exists,0) <= 0 AND p_generate_gl = 'N')
            ---------------------------------------
            --Generate_GL in valueset as 'Y' for OU
            ---------------------------------------
            -- To get Ledger id based on OU AND Currency for Ledger
            ln_ledger_id          := get_ledger_id (p_org_id);

            IF ln_ledger_id = 0
            THEN
                lv_valid_flag   := 'E';
                lv_valid_msg    :=
                       lv_valid_msg
                    || CHR (10)
                    || 'Ledger_Id validation failure ';
            ELSE
                lv_curr_code   := get_ledger_curr (ln_ledger_id);

                IF lv_curr_code IS NULL
                THEN
                    lv_valid_flag   := 'E';
                    lv_valid_msg    :=
                           lv_valid_msg
                        || CHR (10)
                        || 'Currency validation failure ';
                END IF;
            END IF;

            fnd_file.put_line (
                fnd_file.LOG,
                   'Fetch Ledger_Id : '
                || ln_ledger_id
                || ' - '
                || 'for OU :'
                || p_org_id);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Fetch Currency : '
                || lv_curr_code
                || ' - '
                || 'for Ledger Id :'
                || ln_ledger_id);

            -- To get Period name
            lv_period_name        :=
                get_period_name (
                    ln_ledger_id,
                    TO_DATE (p_as_of_date, 'YYYY/MM/DD HH24:MI:SS'));

            IF lv_period_name IS NULL
            THEN
                lv_valid_flag   := 'E';
                lv_valid_msg    :=
                    lv_valid_msg || CHR (10) || 'Period validation failure ';
            END IF;

            fnd_file.put_line (fnd_file.LOG,
                               'Fetch Period : ' || lv_period_name);

            -- To get Journal source
            lv_journal_source     := get_journal_source (lv_source_category);

            IF lv_journal_source IS NULL
            THEN
                lv_valid_flag   := 'E';
                lv_valid_msg    :=
                       lv_valid_msg
                    || CHR (10)
                    || 'Journal Source validation failure ';
            END IF;

            fnd_file.put_line (
                fnd_file.LOG,
                'Fetch Journal Source and Category : ' || lv_journal_source);

            -- To get Journal category
            lv_journal_category   :=
                get_journal_category (lv_source_category);

            IF lv_journal_category IS NULL
            THEN
                lv_valid_flag   := 'E';
                lv_valid_msg    :=
                       lv_valid_msg
                    || CHR (10)
                    || 'Journal Category validation failure ';
            END IF;

            -- To get Journal name\Batch name
            lv_journal_name       := get_journal_name (lv_curr_code);

            IF lv_journal_name IS NULL
            THEN
                lv_valid_flag   := 'E';
                lv_valid_msg    :=
                       lv_valid_msg
                    || CHR (10)
                    || 'Journal\Batch Name validation failure ';
            END IF;

            lv_last_run_dt_vs     := NULL; -- Passing NULL to pick till Parameter-as-of-date for CASE#2

            --Open Cursor to validate Debit and Credit Accounts
            FOR c_rec IN c_get_ar_disc_dtls (lv_last_run_dt_vs)
            LOOP
                IF c_rec.discount_amt_round_3 <> 0
                THEN
                    --Calling function to Validate Debit Account
                    lv_debit_acct   := get_debit_acct (p_org_id, c_rec.brand);

                    IF lv_debit_acct IS NULL
                    THEN
                        lv_valid_flag   := 'E';
                        lv_valid_msg    :=
                               'Debit Account in valueset-DFF is Null\Invalid for Brand: '
                            || c_rec.brand;
                    ELSE
                        -- Validate Debit Account CCID
                        ln_db_acct_ccid   := get_ccid (lv_debit_acct);

                        IF ln_db_acct_ccid = 0
                        THEN
                            lv_valid_flag   := 'E';
                            lv_valid_msg    :=
                                   lv_valid_msg
                                || CHR (10)
                                || 'Debit Account-CCID validation failure ';
                        END IF;
                    END IF;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Fetch Debit Account from Valueset: '
                        || lv_debit_acct
                        || ' and CCID : '
                        || ln_db_acct_ccid);

                    --Calling function to Validate Credit Account
                    lv_credit_acct   :=
                        get_credit_acct (p_org_id, c_rec.brand);

                    IF lv_credit_acct IS NULL
                    THEN
                        lv_valid_flag   := 'E';
                        lv_valid_msg    :=
                               lv_valid_msg
                            || CHR (10)
                            || 'Credit Account in valueset-DFF is Null\Invalid for Brand: '
                            || c_rec.brand;
                    ELSE
                        -- To Validate Credit Account CCID
                        ln_cr_acct_ccid   := get_ccid (lv_credit_acct);

                        IF ln_cr_acct_ccid = 0
                        THEN
                            lv_valid_flag   := 'E';
                            lv_valid_msg    :=
                                   lv_valid_msg
                                || CHR (10)
                                || 'Credit Account-CCID validation failure ';
                        END IF;
                    END IF;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Fetch Credit Account from Valueset: '
                        || lv_credit_acct
                        || ' and CCID: '
                        || ln_cr_acct_ccid);

                    -- To Validate Journal Line Description
                    lv_journal_desc   :=
                        get_description (c_rec.brand, lv_curr_code);

                    IF lv_journal_desc IS NULL
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Journal Line Description validation failure ');
                    END IF;
                END IF;
            END LOOP;

            IF (lv_valid_flag = 'E' AND lv_valid_msg IS NOT NULL)
            THEN
                NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                    '-------------------------------------------------------------------------');
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Validation Status :'
                    || lv_valid_flag
                    || ' and Error Message :'
                    || lv_valid_msg);
                fnd_file.put_line (
                    fnd_file.LOG,
                    '***Validation Failure, skiping GL Interface Insertion..');
                fnd_file.put_line (
                    fnd_file.LOG,
                    '-------------------------------------------------------------------------');
            ELSE
                FOR c_rec IN c_get_ar_disc_dtls (lv_last_run_dt_vs)
                LOOP
                    --Validate Discount Amount
                    IF c_rec.discount_amt_round_3 <> 0
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Fetch Discount Amount: '
                            || c_rec.discount_amt
                            || ' and Rounded Amount: '
                            || c_rec.discount_amt_round_3);

                        --To get Debit Account
                        lv_debit_acct     :=
                            get_debit_acct (p_org_id, c_rec.brand);
                        ln_db_acct_ccid   := get_ccid (lv_debit_acct);

                        --To get Credit Account
                        lv_credit_acct    :=
                            get_credit_acct (p_org_id, c_rec.brand);
                        ln_cr_acct_ccid   := get_ccid (lv_credit_acct);

                        -- To get Journal Line Description
                        lv_journal_desc   :=
                            get_description (c_rec.brand, lv_curr_code);

                        fnd_file.put_line (
                            fnd_file.LOG,
                            '***Calling Insert GL Interface Procedure***');

                        --Calling procedure to Insert GL Interface
                        BEGIN
                            insert_gl_data (
                                p_org_id             => p_org_id,
                                p_ledger_id          => ln_ledger_id,
                                p_transaction_date   =>
                                    TO_DATE (p_as_of_date,
                                             'YYYY/MM/DD HH24:MI:SS'), --TO_DATE(p_as_of_date,'DD-MON-YYYY')
                                p_curr_code          => lv_curr_code,
                                p_journal_source     => lv_journal_source,
                                p_journal_category   => lv_journal_category,
                                p_journal_desc       => lv_journal_desc,
                                p_group_id           => ln_group_id,
                                p_journal_name       => lv_journal_name,
                                p_period_name        => lv_period_name,
                                p_brand              => c_rec.brand,
                                p_db_cr_amt          =>
                                    c_rec.discount_amt_round_3,
                                p_db_acct_ccid       => ln_db_acct_ccid,
                                p_cr_acct_ccid       => ln_cr_acct_ccid);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ln_error_cnt   := ln_error_cnt + 1;
                        END;

                        ln_success_cnt    := ln_success_cnt + 1;
                    ELSE
                        ln_skip_cnt   := ln_skip_cnt + 1; -- If Discount_Amount is 0 for BRAND
                    END IF;

                    ln_total_cnt   := c_get_ar_disc_dtls%ROWCOUNT;
                END LOOP;
            END IF;                                   --IF lv_valid_flag = 'E'

            fnd_file.put_line (fnd_file.LOG,
                               ' Success Records Count :' || ln_success_cnt);
            fnd_file.put_line (fnd_file.LOG,
                               ' Skip Records Count    :' || ln_skip_cnt);
            fnd_file.put_line (fnd_file.LOG,
                               ' Error Records Count   :' || ln_error_cnt);
            fnd_file.put_line (fnd_file.LOG,
                               ' Total Records Count   :' || ln_total_cnt);

            --To display IFACE errored out in OUTPUT
            IF ln_error_cnt > 0
            THEN
                --Validation Failed, display messsage in OUTPUT
                fnd_file.put_line (
                    fnd_file.output,
                    '#########################################################################');
                fnd_file.put_line (
                    fnd_file.output,
                    '***Errors\Validation failed so ''AR Discount Extract'' not processed to GL Interface..');
                fnd_file.put_line (
                    fnd_file.output,
                    ' Success Records Count :' || ln_success_cnt);
                fnd_file.put_line (
                    fnd_file.output,
                    ' Error Records Count   :' || ln_error_cnt);
                fnd_file.put_line (
                    fnd_file.output,
                    '#########################################################################');
            END IF;

            IF ((ln_total_cnt = ln_success_cnt + ln_skip_cnt) AND ln_success_cnt <> 0 AND ln_total_cnt <> 0)
            THEN
                --Succesful Insetion of GL Interface, messsage in OUTPUT
                fnd_file.put_line (
                    fnd_file.output,
                    '#########################################################################');
                fnd_file.put_line (
                    fnd_file.output,
                    '***''Generate_GL'' marked in the value-set as ''Yes'' for this OU..');
                fnd_file.put_line (
                    fnd_file.output,
                    '***AR Discount Extract records is processed to GL Interface..');
                fnd_file.put_line (
                    fnd_file.output,
                    '#########################################################################');

                --Update As-of-Date post success
                fnd_file.put_line (fnd_file.LOG,
                                   '**Update As-of-Date in Valueset-DFF**');
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Updated As-of-Date in VS : ' || lv_update_run_dt);

                BEGIN
                    UPDATE apps.fnd_flex_values flv
                       SET flv.attribute4   = lv_update_run_dt --TO_CHAR(SYSDATE,'YYYY/MM/DD HH24:MI:SS')
                     WHERE     1 = 1
                           AND flv.flex_value_set_id =
                               (SELECT flex_value_set_id
                                  FROM apps.fnd_flex_value_sets
                                 WHERE flex_value_set_name =
                                       'XXD_GL_AR_DISCOUNT_JOURNAL_VS')
                           AND SYSDATE BETWEEN NVL (
                                                   TRUNC (
                                                       flv.start_date_active),
                                                   SYSDATE)
                                           AND NVL (
                                                   TRUNC (
                                                       flv.end_date_active),
                                                   SYSDATE + 1)
                           AND TO_NUMBER (NVL (flv.attribute1, -99)) =
                               p_org_id
                           AND NVL (flv.attribute5, 'N') =
                               NVL (p_generate_gl, 'N')
                           AND flv.enabled_flag = 'Y';

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Exp- Updation As-of-Date failed in Valueset ');
                END;
            END IF;
        END IF;                                           --IF ln_valid_exists

        fnd_file.put_line (
            fnd_file.LOG,
            '**************************************************************************************');
    EXCEPTION
        WHEN gl_exists_warning
        THEN
            x_retcode   := gn_warning;
            x_errbuf    :=
                'Records exists in GL Interface or in GL. Please correct and take necessary action. ';
        --COMMIT;
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               ' Main Exception- Error : ' || SQLERRM);
    END main;
END XXD_GL_AR_DISC_JOURNAL_PKG;
/
