--
-- XXD_AP_PREPAID_JOURNAL_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:42 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AP_PREPAID_JOURNAL_PKG"
AS
    /****************************************************************************************
    * Package      : xxd_ont_sales_rep_int_pkg
    * Design       : This package will be used to Ability to automate the Deferred Prepaid Reclass journal creation in GL
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 10-May-2021   1.0        Balavenu Rao        Initial Version
    ******************************************************************************************/

    -- ======================================================================================
    -- Set values for Global Variables
    -- ======================================================================================
    -- Modifed to init G variable from input params

    gn_user_id             NUMBER := fnd_global.user_id;
    gn_login_id            NUMBER := fnd_global.login_id;
    gn_request_id          NUMBER := fnd_global.conc_request_id;
    gc_debug_enable        VARCHAR2 (1);
    gc_delimiter           VARCHAR2 (100);
    gc_ecom_customer_num   VARCHAR2 (100) := NULL;
    gc_ecom_customer       VARCHAR2 (200) := NULL;
    g_order_type           VARCHAR2 (100);
    g_create_file          VARCHAR2 (100);
    g_send_mail            VARCHAR2 (10);
    g_errbuf               VARCHAR2 (100);
    g_retcode              VARCHAR2 (2000);

    -- ======================================================================================
    -- This procedure prints the Debug Messages in Log Or File
    -- ======================================================================================

    PROCEDURE debug_msg (p_msg IN VARCHAR2)
    AS
        lc_debug_mode   VARCHAR2 (1000);
    BEGIN
        fnd_file.put_line (fnd_file.LOG, gc_delimiter || p_msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Others Exception in DEBUG_MSG = ' || SQLERRM);
    END debug_msg;

    FUNCTION get_segment_values_fnc
        RETURN segment_values_tbl
        PIPELINED
    IS
        l_segment_values_rec   segment_values_rec;
    BEGIN
        FOR l_segment_values_rec
            IN (SELECT meaning, description
                  FROM fnd_lookup_values
                 WHERE     1 = 1
                       AND language = USERENV ('LANG')
                       AND enabled_flag = 'Y'
                       AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                       NVL (
                                                           start_date_active,
                                                           SYSDATE))
                                               AND TRUNC (
                                                       NVL (end_date_active,
                                                            SYSDATE))
                       AND lookup_type = 'XXD_AP_PRE_JOURNAL_SEGMENT_LKP')
        LOOP
            PIPE ROW (l_segment_values_rec);
        END LOOP;

        RETURN;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line (
                'Others Exception in l_params_rec = ' || SQLERRM);
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in l_params_rec = ' || SQLERRM);
            NULL;
    END get_segment_values_fnc;


    FUNCTION get_journal_category
        RETURN VARCHAR2
    IS
        lv_je_category   VARCHAR2 (200);
    BEGIN
        BEGIN
            SELECT JE_CATEGORY_NAME
              INTO lv_je_category
              FROM gl_je_categories
             WHERE     user_je_category_name = 'Deferred Prepaid Reclass'
                   AND language = 'US';

            fnd_file.put_line (fnd_file.LOG,
                               'Journal Category is:' || lv_je_category);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_je_category   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Failed to fetch Journal Category' || SQLERRM);
        END;

        RETURN lv_je_category;
    END get_journal_category;

    PROCEDURE main_prc (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_ledger VARCHAR2, p_accounting_from_date VARCHAR2, p_accounting_to_date VARCHAR2, p_currency_rate_date VARCHAR2, p_period VARCHAR2, p_send_mail VARCHAR2, p_dummy_email VARCHAR2
                        , p_email_id VARCHAR2)
    AS
        CURSOR c_ap_inst (p_chart_of_accounts_id NUMBER)
        IS
              SELECT project_id, ou_name, invoice_num,
                     line_number, invoice_date, invoice_amount,
                     SUM (dist_amount) dist_amount, SUM (usd_dist_amount) usd_dist_amount, accounting_date,
                     vendor_name, vendor_site_code, invoice_currency_code,
                     gl_code, cost_center, account,
                     line_description, brand, ic_expense,
                     po_number, latest_rcv_date, rcv_date related_period_rcv,
                     no_of_receipts multiple_receipts, deferred_acctg_flag, def_acctg_start_date,
                     def_acctg_end_date, payment_date, terms_start_date,
                     due_date, creation_date line_creation, segment1,
                     segment2, segment3, segment4,
                     segment5, segment6, segment7,
                     segment8, invoice_id
                FROM (SELECT hou.name
                                 ou_name,
                             aia.invoice_currency_code,
                             aia.invoice_num,
                             aila.line_number,
                             aia.invoice_date,
                             aia.invoice_amount,
                             aida.amount
                                 dist_amount,
                             ROUND (
                                   aida.amount
                                 * NVL (
                                       (SELECT conversion_rate
                                          FROM apps.gl_daily_rates gdr
                                         WHERE     1 = 1
                                               AND gdr.from_currency =
                                                   aia.invoice_currency_code
                                               AND conversion_type = 'Spot'
                                               AND conversion_date =
                                                   TO_DATE (
                                                       p_currency_rate_date,
                                                       'RRRR/MM/DD HH24:MI:SS') --'31-MAR-2019'
                                               AND gdr.from_currency <> 'USD'
                                               AND gdr.to_currency = 'USD'),
                                       1),
                                 2)
                                 usd_dist_amount,
                             aida.accounting_date,
                             asa.vendor_name,
                             assa.vendor_site_code,
                             gcc.concatenated_segments
                                 gl_code,
                             (SELECT description
                                FROM fnd_flex_values_vl
                               WHERE     flex_value_set_id = 1015915
                                     AND gcc.segment5 = flex_value)
                                 cost_center,
                             (SELECT description
                                FROM fnd_flex_values_vl
                               WHERE     flex_value_set_id = 1015916
                                     AND gcc.segment6 = flex_value)
                                 account,
                             aila.description
                                 line_description,
                             DECODE (aida.posted_flag,
                                     'Y', 'Processed',
                                     'UnProcessed')
                                 accounted,
                             (SELECT brand
                                FROM apps.xxd_common_items_v xv
                               WHERE     organization_id = 106
                                     AND xv.inventory_item_id =
                                         aila.inventory_item_id)
                                 brand,
                             (SELECT concatenated_segments
                                FROM apps.gl_code_combinations_kfv c
                               WHERE c.code_combination_id = aila.attribute2)
                                 ic_expense,
                             (SELECT segment1
                                FROM apps.po_headers_all ha
                               WHERE ha.po_header_id = aila.po_header_id)
                                 po_number,
                             (SELECT MAX (transaction_date)
                                FROM apps.rcv_transactions rt
                               WHERE rt.po_line_id = aila.po_line_id)
                                 latest_rcv_date,
                             (SELECT MAX (transaction_date)
                                FROM apps.rcv_transactions rt
                               WHERE     rt.po_line_id = aila.po_line_id
                                     AND transaction_date <
                                         TO_DATE (p_accounting_to_date,
                                                  'RRRR/MM/DD HH24:MI:SS') --from date parameter
                                                                          )
                                 rcv_date,
                             (SELECT COUNT (*)
                                FROM apps.rcv_transactions rt
                               WHERE     rt.po_line_id = aila.po_line_id
                                     AND rt.transaction_type = 'RECEIVE')
                                 no_of_receipts,
                             aila.deferred_acctg_flag,
                             aila.def_acctg_start_date,
                             aila.def_acctg_end_date,
                             aila.creation_date,
                             NVL (aia.project_id, aila.project_id)
                                 project_id,
                             (SELECT MIN (aipa.accounting_date)
                                FROM apps.ap_invoice_payments_all aipa
                               WHERE aipa.invoice_id = aia.invoice_id)
                                 payment_date,
                             (SELECT MIN (apsa.due_date)
                                FROM apps.ap_payment_schedules_all apsa
                               WHERE apsa.invoice_id = aia.invoice_id)
                                 due_date,
                             aia.terms_date
                                 terms_start_date,
                             gcc.segment1,
                             gcc.segment2,
                             gcc.segment3,
                             gcc.segment4,
                             gcc.segment5,
                             gcc.segment6,
                             gcc.segment7,
                             gcc.segment8,
                             aia.invoice_id
                        FROM ap_invoices_all aia, ap_invoice_lines_all aila, apps.ap_invoice_distributions_all aida,
                             gl_code_combinations_kfv gcc, hr_operating_units hou, ap_suppliers asa,
                             ap_supplier_sites_all assa
                       WHERE     aia.invoice_id = aila.invoice_id
                             AND aia.invoice_id = aida.invoice_id
                             AND aila.line_number = aida.invoice_line_number
                             AND aida.dist_code_combination_id =
                                 gcc.code_combination_id
                             AND aia.org_id = hou.organization_id
                             AND aia.vendor_id != 9001
                             AND aia.vendor_id = asa.vendor_id
                             AND aia.vendor_site_id = assa.vendor_site_id
                             AND gcc.chart_of_accounts_id =
                                 NVL (p_chart_of_accounts_id,
                                      gcc.chart_of_accounts_id)
                             AND aida.accounting_date BETWEEN TO_DATE (
                                                                  p_accounting_from_date,
                                                                  'RRRR/MM/DD HH24:MI:SS')
                                                          AND TO_DATE (
                                                                  p_accounting_to_date,
                                                                  'RRRR/MM/DD HH24:MI:SS'))
               WHERE def_acctg_start_date IS NOT NULL AND payment_date IS NULL
            GROUP BY ou_name, invoice_num, invoice_date,
                     invoice_amount, accounting_date, vendor_name,
                     vendor_site_code, invoice_currency_code, gl_code,
                     cost_center, account, line_description,
                     brand, ic_expense, po_number,
                     rcv_date, deferred_acctg_flag, def_acctg_start_date,
                     def_acctg_end_date, creation_date, project_id,
                     no_of_receipts, latest_rcv_date, payment_date,
                     due_date, terms_start_date, line_number,
                     segment1, segment2, segment3,
                     segment4, segment5, segment6,
                     segment7, segment8, invoice_id
              HAVING SUM (usd_dist_amount) <> 0
            ORDER BY 1, 2, 3,
                     5, 6;

        CURSOR c_write IS
            SELECT ou_name, invoice_num, line_number,
                   invoice_date, invoice_amount, dist_amount,
                   usd_dist_amount, accounting_date, vendor_name,
                   vendor_site_code, invoice_currency_code, gl_code,
                   cost_center, account, line_description,
                   brand, ic_expense, po_number,
                   latest_rcv_date, related_period_rcv, multiple_receipts,
                   deferred_acctg_flag, def_acctg_start_date, def_acctg_end_date,
                   payment_date, terms_start_date, due_date,
                   line_creation, segment1, segment2,
                   segment3, segment4, segment5,
                   segment6, segment7, segment8,
                   request_id, status, error_message,
                   je_header_id, attribute1, attribute2,
                   attribute3, attribute4, attribute5,
                   attribute6, attribute7, attribute8,
                   attribute9, attribute10, attribute11,
                   attribute12, attribute13, attribute14,
                   attribute15, creation_date, created_by,
                   last_updated_by, last_update_date, last_update_login,
                   jr_request_id, journal_name
              FROM xxdo.xxd_ap_prepaid_journal_stg_t
             WHERE request_id = gn_request_id;

        TYPE xxd_write_type IS TABLE OF c_write%ROWTYPE;

        v_write                    xxd_write_type := xxd_write_type ();

        CURSOR c_gl_cr (p_segment2 VARCHAR2)
        IS
              SELECT NVL (SUM (usd_dist_amount), 0) usd_dist_amount,
                     --  DECODE (segment2, '1000', '6400', segment2)    segment2,
                     CASE
                         WHEN segment2 = '1000' AND segment4 = '100'
                         THEN
                             segment2
                         WHEN segment2 = '1000' AND segment4 <> '100'
                         THEN
                             p_segment2
                         ELSE
                             segment2
                     END segment2,
                     segment4,
                     NULL error_message
                FROM xxdo.xxd_ap_prepaid_journal_stg_t
               WHERE request_id = gn_request_id AND status = 'N'
            GROUP BY --            DECODE (segment2, '1000', '6400', segment2)
                     CASE
                         WHEN segment2 = '1000' AND segment4 = '100'
                         THEN
                             segment2
                         WHEN segment2 = '1000' AND segment4 <> '100'
                         THEN
                             p_segment2
                         ELSE
                             segment2
                     END,
                     segment4;

        TYPE error_rec_typ IS RECORD
        (
            segment2         gl_code_combinations.segment2%TYPE,
            segment4         gl_code_combinations.segment4%TYPE,
            error_message    VARCHAR2 (2000)
        );

        TYPE error_tbl_type IS TABLE OF error_rec_typ;

        v_error_tbl_type           error_tbl_type := error_tbl_type ();
        ln_dr_usd_dist_amount      NUMBER;

        TYPE xxd_inst_type IS TABLE OF c_ap_inst%ROWTYPE;

        v_ins_type                 xxd_inst_type := xxd_inst_type ();

        TYPE xxd_cr_inst_type IS TABLE OF c_gl_cr%ROWTYPE;

        v_cr_ins_type              xxd_cr_inst_type := xxd_cr_inst_type ();
        v_cr_ins_val_type          xxd_cr_inst_type := xxd_cr_inst_type ();
        lv_error_code              VARCHAR2 (4000) := NULL;
        ln_error_num               NUMBER;
        lv_error_msg               VARCHAR2 (4000) := NULL;
        lv_mail_status             VARCHAR2 (200) := NULL;
        lv_mail_msg                VARCHAR2 (4000) := NULL;
        lv_status                  VARCHAR2 (10) := 'S';
        lv_segment1                gl_code_combinations.segment1%TYPE := NULL;
        lv_segment2                gl_code_combinations.segment2%TYPE := NULL;
        lv_segment3                gl_code_combinations.segment3%TYPE := NULL;
        lv_segment4                gl_code_combinations.segment4%TYPE := NULL;
        lv_segment5                gl_code_combinations.segment5%TYPE := NULL;
        lv_segment6                gl_code_combinations.segment6%TYPE := NULL;
        lv_segment7                gl_code_combinations.segment7%TYPE := NULL;
        lv_segment8                gl_code_combinations.segment8%TYPE := NULL;
        lv_dr_segment1             gl_code_combinations.segment1%TYPE := NULL;
        lv_dr_segment2             gl_code_combinations.segment2%TYPE := NULL;
        lv_dr_segment3             gl_code_combinations.segment3%TYPE := NULL;
        lv_dr_segment4             gl_code_combinations.segment4%TYPE := NULL;
        lv_dr_segment5             gl_code_combinations.segment5%TYPE := NULL;
        lv_dr_segment6             gl_code_combinations.segment6%TYPE := NULL;
        lv_dr_segment7             gl_code_combinations.segment7%TYPE := NULL;
        lv_dr_segment8             gl_code_combinations.segment8%TYPE := NULL;
        ln_interface_run_id        NUMBER;
        ln_request_id              NUMBER;
        ln_group_id                NUMBER := 99089;
        ln_access_set_id           NUMBER;
        ln_parent_request_id       NUMBER;
        lc_phase                   VARCHAR2 (50);
        lc_status                  VARCHAR2 (50);
        lc_dev_phase               VARCHAR2 (50);
        lc_dev_status              VARCHAR2 (50);
        lc_message                 VARCHAR2 (50);
        l_req_return_status        BOOLEAN;
        ln_count                   NUMBER;
        ln_gl_count                NUMBER;
        lv_journal_category        VARCHAR2 (200);
        lv_journal_category_name   VARCHAR2 (1000);
        lv_journal_name            VARCHAR2 (1000);
        lv_batch_name              VARCHAR2 (1000);
        l_val_count                NUMBER;
        ln_je_header_id            NUMBER;
        lv_name                    VARCHAR2 (2000);
        ln_chart_of_accounts_id    NUMBER;
        ln_ccid                    NUMBER;
        lv_period_name             gl_period_statuses.period_name%TYPE
                                       := NULL;
        lv_je_source_name          gl_je_sources.user_je_source_name%TYPE
                                       := NULL;
        lv_je_source_name_id       gl_je_sources.je_source_name%TYPE := NULL;
        lv_je_category             gl_je_categories.user_je_category_name%TYPE
            := NULL;
        lv_instance_name           VARCHAR2 (200) := NULL;
    BEGIN
        v_error_tbl_type.DELETE;
        v_ins_type.DELETE;
        v_cr_ins_type.DELETE;
        v_cr_ins_val_type.DELETE;
        debug_msg (' p_ledger ' || p_ledger);
        debug_msg (' p_accounting_from_date ' || p_accounting_from_date);
        debug_msg (' p_accounting_to_date ' || p_accounting_to_date);
        debug_msg (' p_currency_rate_date ' || p_currency_rate_date);
        debug_msg (' p_period ' || p_period);
        debug_msg (' p_send_mail ' || p_send_mail);
        gc_delimiter   := CHR (9);
        debug_msg (
               ' Start Insert At '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

        BEGIN
            SELECT name INTO lv_instance_name FROM v$database;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_instance_name   := NULL;
        END;

        --Constant Values

        BEGIN
            SELECT MAX (DECODE (identity, 'SEGMENT1', VALUE)) AS segment1, MAX (DECODE (identity, 'SEGMENT2', VALUE)) AS segment2, MAX (DECODE (identity, 'SEGMENT3', VALUE)) AS segment3,
                   MAX (DECODE (identity, 'SEGMENT5', VALUE)) AS segment5, MAX (DECODE (identity, 'SEGMENT6', VALUE)) AS segment6, MAX (DECODE (identity, 'SEGMENT7', VALUE)) AS segment7,
                   MAX (DECODE (identity, 'SEGMENT8', VALUE)) AS segment8, MAX (DECODE (identity, 'DR_SEGMENT1', VALUE)) AS dr_segment1, MAX (DECODE (identity, 'DR_SEGMENT2', VALUE)) AS dr_segment2,
                   MAX (DECODE (identity, 'DR_SEGMENT3', VALUE)) AS dr_segment3, MAX (DECODE (identity, 'DR_SEGMENT4', VALUE)) AS dr_segment4, MAX (DECODE (identity, 'DR_SEGMENT5', VALUE)) AS dr_segment5,
                   MAX (DECODE (identity, 'DR_SEGMENT6', VALUE)) AS dr_segment6, MAX (DECODE (identity, 'DR_SEGMENT7', VALUE)) AS dr_segment7, MAX (DECODE (identity, 'DR_SEGMENT8', VALUE)) AS dr_segment8,
                   MAX (DECODE (identity, 'JOURNAL_CATEGORY', VALUE)) AS journal_category, MAX (DECODE (identity, 'JOURNAL_NAME', VALUE)) || '-' || p_period || '-' || gn_request_id || '-' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS') AS journal_name, MAX (DECODE (identity, 'BATCH_NAME', VALUE)) || '-' || p_period || '-' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS') AS batch_name
              INTO lv_segment1, lv_segment2, lv_segment3, lv_segment5,
                              lv_segment6, lv_segment7, lv_segment8,
                              lv_dr_segment1, lv_dr_segment2, lv_dr_segment3,
                              lv_dr_segment4, lv_dr_segment5, lv_dr_segment6,
                              lv_dr_segment7, lv_dr_segment8, lv_journal_category_name,
                              lv_journal_name, lv_batch_name
              FROM TABLE (get_segment_values_fnc);
        EXCEPTION
            WHEN OTHERS
            THEN
                debug_msg (
                       ' Exception While Getting the Constant Values From Lookup'
                    || SQLCODE);
                lv_status   := 'E';
                g_errbuf    :=
                    SUBSTR (' No Invoices Found ' || SQLERRM, 1, 2000);
                g_retcode   := 1;
        END;

        --Validate the Journal Source
        BEGIN
            SELECT user_je_source_name, je_source_name
              INTO lv_je_source_name, lv_je_source_name_id
              FROM gl_je_sources
             WHERE     user_je_source_name = 'Deferred Prepaid Reclass'
                   AND language = 'US';
        EXCEPTION
            WHEN OTHERS
            THEN
                g_errbuf    :=
                    SUBSTR (' Error in Journal Source value ' || SQLERRM,
                            1,
                            2000);
                g_retcode   := 1;
                debug_msg (' Error in Journal Source value ' || SQLERRM);
                lv_status   := 'E';
        END;

        -- Getting Chart of Account
        BEGIN
            SELECT chart_of_accounts_id
              INTO ln_chart_of_accounts_id
              FROM gl_ledgers
             WHERE ledger_id = p_ledger;
        EXCEPTION
            WHEN OTHERS
            THEN
                g_errbuf    :=
                    SUBSTR (' Error in Chart Of Accounts Value ' || SQLERRM,
                            1,
                            2000);
                g_retcode   := 1;
                debug_msg (' Error in Chart Of Accounts Value ' || SQLERRM);
                lv_status   := 'E';
        END;

        --Period Open Valiadtion
        BEGIN
            SELECT period_name
              INTO lv_period_name
              FROM gl_period_statuses
             WHERE     application_id = 101
                   AND ledger_id = p_ledger
                   AND closing_status = 'O'
                   AND period_name = p_period;
        EXCEPTION
            WHEN OTHERS
            THEN
                g_errbuf    :=
                    SUBSTR (' Error in Open Period Value ' || SQLERRM,
                            1,
                            2000);
                g_retcode   := 1;
                debug_msg (' Error in Open Period Value ' || SQLERRM);
                lv_status   := 'E';
        END;

        --Journal Source Category
        BEGIN
            SELECT user_je_category_name
              INTO lv_je_category
              FROM gl_je_categories
             WHERE     user_je_category_name = lv_journal_category_name
                   AND language = 'US';
        EXCEPTION
            WHEN OTHERS
            THEN
                g_errbuf    :=
                    SUBSTR (' Error in Source Category Value ' || SQLERRM,
                            1,
                            2000);
                g_retcode   := 1;
                debug_msg (' Error in Source Category Value ' || SQLERRM);
                lv_status   := 'E';
        END;

        BEGIN
            UPDATE xxdo.xxd_ap_prepaid_journal_stg_t mainq
               SET (status, error_message, journal_name,
                    je_header_id)   =
                       (SELECT 'S', NULL, name,
                               je_header_id
                          FROM gl_je_headers
                         WHERE     1 = 1
                               AND mainq.request_id =
                                   TO_NUMBER (REGEXP_SUBSTR (name, '([^-]*)-|$', 1
                                                             , 5, NULL, 1))
                               AND JE_CATEGORY = '261')
             WHERE 1 = 1 AND mainq.status = 'IE';

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                g_errbuf    :=
                    SUBSTR (
                           ' Exception While Updating Interface Status To Sucess'
                        || SQLERRM,
                        1,
                        2000);
                g_retcode   := 1;
                debug_msg (
                       ' Exception While Updating Interface Status To Sucess '
                    || SQLERRM);
        --    lv_status := 'E';
        END;

        --Deleting Error Records
        BEGIN
            DELETE FROM xxdo.xxd_ap_prepaid_journal_stg_t
                  WHERE NVL (status, 'ZZ') <> 'S';

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                g_errbuf    :=
                    SUBSTR (
                        ' Exception While Deleting Error Records' || SQLERRM,
                        1,
                        2000);
                g_retcode   := 1;
                debug_msg (
                    ' Exception While Deleting Error Records ' || SQLERRM);
        END;

        --Insert The Values in Stagging Table
        IF (lv_status = 'S')
        THEN
            OPEN c_ap_inst (ln_chart_of_accounts_id);

            LOOP
                FETCH c_ap_inst BULK COLLECT INTO v_ins_type LIMIT 10000;

                BEGIN
                    gc_delimiter   := CHR (9) || CHR (9);
                    debug_msg (
                           ' Start Stg Insert Record Count '
                        || v_ins_type.COUNT
                        || ' at '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

                    IF (v_ins_type.COUNT > 0)
                    THEN
                        FORALL i IN v_ins_type.FIRST .. v_ins_type.LAST
                          SAVE EXCEPTIONS
                            INSERT INTO xxdo.xxd_ap_prepaid_journal_stg_t (
                                            project_id,
                                            ou_name,
                                            invoice_num,
                                            line_number,
                                            invoice_date,
                                            invoice_amount,
                                            dist_amount,
                                            usd_dist_amount,
                                            accounting_date,
                                            vendor_name,
                                            vendor_site_code,
                                            invoice_currency_code,
                                            gl_code,
                                            cost_center,
                                            account,
                                            line_description,
                                            brand,
                                            ic_expense,
                                            po_number,
                                            latest_rcv_date,
                                            related_period_rcv,
                                            multiple_receipts,
                                            deferred_acctg_flag,
                                            def_acctg_start_date,
                                            def_acctg_end_date,
                                            payment_date,
                                            terms_start_date,
                                            due_date,
                                            line_creation,
                                            segment1,
                                            segment2,
                                            segment3,
                                            segment4,
                                            segment5,
                                            segment6,
                                            segment7,
                                            segment8,
                                            status,
                                            error_message,
                                            je_header_id,
                                            attribute1,
                                            attribute2,
                                            attribute3,
                                            attribute4,
                                            attribute5,
                                            attribute6,
                                            attribute7,
                                            attribute8,
                                            attribute9,
                                            attribute10,
                                            attribute11,
                                            attribute12,
                                            attribute13,
                                            attribute14,
                                            attribute15,
                                            request_id,
                                            creation_date,
                                            created_by,
                                            last_updated_by,
                                            last_update_date,
                                            last_update_login,
                                            invoice_id)
                                     VALUES (
                                                v_ins_type (i).project_id,
                                                v_ins_type (i).ou_name,
                                                v_ins_type (i).invoice_num,
                                                v_ins_type (i).line_number,
                                                v_ins_type (i).invoice_date,
                                                v_ins_type (i).invoice_amount,
                                                v_ins_type (i).dist_amount,
                                                v_ins_type (i).usd_dist_amount,
                                                v_ins_type (i).accounting_date,
                                                v_ins_type (i).vendor_name,
                                                v_ins_type (i).vendor_site_code,
                                                v_ins_type (i).invoice_currency_code,
                                                v_ins_type (i).gl_code,
                                                v_ins_type (i).cost_center,
                                                v_ins_type (i).account,
                                                v_ins_type (i).line_description,
                                                v_ins_type (i).brand,
                                                v_ins_type (i).ic_expense,
                                                v_ins_type (i).po_number,
                                                v_ins_type (i).latest_rcv_date,
                                                v_ins_type (i).related_period_rcv,
                                                v_ins_type (i).multiple_receipts,
                                                v_ins_type (i).deferred_acctg_flag,
                                                v_ins_type (i).def_acctg_start_date,
                                                v_ins_type (i).def_acctg_end_date,
                                                v_ins_type (i).payment_date,
                                                v_ins_type (i).terms_start_date,
                                                v_ins_type (i).due_date,
                                                v_ins_type (i).line_creation,
                                                v_ins_type (i).segment1,
                                                v_ins_type (i).segment2,
                                                v_ins_type (i).segment3,
                                                v_ins_type (i).segment4,
                                                v_ins_type (i).segment5,
                                                v_ins_type (i).segment6,
                                                v_ins_type (i).segment7,
                                                v_ins_type (i).segment8,
                                                'N',
                                                NULL,
                                                NULL,
                                                NULL,
                                                NULL,
                                                NULL,
                                                NULL,
                                                NULL,
                                                NULL,
                                                NULL,
                                                NULL,
                                                NULL,
                                                NULL,
                                                NULL,
                                                NULL,
                                                NULL,
                                                NULL,
                                                NULL,
                                                gn_request_id,
                                                SYSDATE,
                                                gn_user_id,
                                                gn_user_id,
                                                SYSDATE,
                                                gn_login_id,
                                                v_ins_type (i).invoice_id);

                        COMMIT;
                    ELSE
                        debug_msg (' No Invoices Found ');
                        lv_status   := 'E';
                        g_errbuf    :=
                            SUBSTR (' No Invoices Found ' || SQLERRM,
                                    1,
                                    2000);
                        g_retcode   := 1;
                    END IF;


                    debug_msg (
                           ' End Stg Insert Record Count '
                        || v_ins_type.COUNT
                        || ' at '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                        LOOP
                            ln_error_num   :=
                                SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                            lv_error_code   :=
                                SQLERRM (
                                    -1 * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                            lv_error_msg   :=
                                SUBSTR (
                                    (lv_error_msg || ' Error While Insert into Table Item' || v_ins_type (ln_error_num).invoice_num || ' ' || lv_error_code || CHR (10)),
                                    1,
                                    4000);

                            debug_msg (lv_error_msg);
                            lv_status   := 'E';
                            g_errbuf    := (lv_error_msg);
                            g_retcode   := 1;
                        END LOOP;

                        debug_msg (
                               ' End  Stg Insert Record Count '
                            || v_ins_type.COUNT
                            || ' at '
                            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
                END;

                v_ins_type.DELETE;
                EXIT WHEN c_ap_inst%NOTFOUND;
            END LOOP;
        END IF;

        BEGIN
            UPDATE xxdo.xxd_ap_prepaid_journal_stg_t mainq
               SET status = 'E', error_message = 'Records Existing In GL'
             WHERE     request_id = gn_request_id
                   AND EXISTS
                           (SELECT 1
                              FROM xxdo.xxd_ap_prepaid_journal_stg_t xapj, gl_je_headers gl
                             WHERE     xapj.status = 'S'
                                   AND xapj.je_header_id = gl.je_header_id
                                   AND NVL (ACCRUAL_REV_STATUS, 'XXX') <> 'R'
                                   AND xapj.invoice_num = mainq.invoice_num
                                   AND request_id <> gn_request_id);

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                g_errbuf    :=
                    SUBSTR (' Records Existing In GL ' || SQLERRM, 1, 2000);
                g_retcode   := 1;
                debug_msg (
                    ' Error While Validating The Existing Records' || SQLERRM);
                lv_status   := 'E';
        END;

        CLOSE c_ap_inst;

        BEGIN
            UPDATE xxdo.xxd_ap_prepaid_journal_stg_t xapj
               SET status = 'E', error_message = DECODE (error_message, NULL, 'Invalid Currency Code', error_message || ' ; Invalid Currency Code ')
             WHERE     NOT EXISTS
                           (SELECT 1
                              FROM apps.fnd_currencies
                             WHERE     enabled_flag = 'Y'
                                   AND currency_code =
                                       UPPER (
                                           TRIM (xapj.invoice_currency_code)))
                   AND request_id = gn_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                g_errbuf    :=
                    SUBSTR (
                           ' Exception while Updating Invoice Currency Code '
                        || SQLERRM,
                        1,
                        2000);
                g_retcode   := 1;
                debug_msg (
                       ' Exception while Updating Invoice Currency Code '
                    || SQLERRM);
        --    lv_status := 'E';
        END;

        IF (lv_status = 'S')
        THEN
            OPEN c_gl_cr (lv_segment2);

            LOOP
                FETCH c_gl_cr BULK COLLECT INTO v_cr_ins_type LIMIT 10000;

                gc_delimiter   := CHR (9) || CHR (9);
                debug_msg (
                       ' Start Credir Insert Record Count '
                    || v_cr_ins_type.COUNT
                    || ' at '
                    || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

                IF (v_cr_ins_type.COUNT > 0)
                THEN
                    BEGIN
                        debug_msg (
                               ' strt for all Insert Record Count '
                            || v_cr_ins_type.COUNT
                            || ' at '
                            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

                        FORALL i IN v_cr_ins_type.FIRST .. v_cr_ins_type.LAST
                          SAVE EXCEPTIONS
                            INSERT INTO gl.gl_interface (
                                            status,
                                            ledger_id,
                                            accounting_date,
                                            currency_code,
                                            date_created,
                                            created_by,
                                            actual_flag,
                                            reference10,         --description
                                            entered_cr,
                                            user_je_source_name,
                                            user_je_category_name,
                                            GROUP_ID,
                                            reference1,          -- batch Name
                                            reference4,        -- journal_name
                                            period_name,
                                            segment1,
                                            segment2,
                                            segment3,
                                            segment4,
                                            segment5,
                                            segment6,
                                            segment7,
                                            segment8)
                                     VALUES (
                                                'NEW',
                                                p_ledger,
                                                SYSDATE,
                                                'USD',
                                                SYSDATE,
                                                fnd_global.user_id,
                                                'A',
                                                lv_batch_name,   --description
                                                v_cr_ins_type (i).usd_dist_amount,
                                                lv_je_source_name,
                                                lv_journal_category_name, ---journal_category,
                                                ln_group_id,        --group_id
                                                lv_batch_name,    --batch_name
                                                lv_journal_name, --journal_name
                                                p_period,
                                                lv_segment1,
                                                CASE
                                                    WHEN     v_cr_ins_type (
                                                                 i).segment2 =
                                                             '1000'
                                                         AND v_cr_ins_type (
                                                                 i).segment4 =
                                                             '100'
                                                    THEN
                                                        v_cr_ins_type (i).segment2
                                                    WHEN     v_cr_ins_type (
                                                                 i).segment2 =
                                                             '1000'
                                                         AND v_cr_ins_type (
                                                                 i).segment4 <>
                                                             '100'
                                                    THEN
                                                        lv_segment2
                                                    ELSE
                                                        v_cr_ins_type (i).segment2
                                                END,
                                                lv_segment3,
                                                v_cr_ins_type (i).segment4,
                                                lv_segment5,
                                                lv_segment6,
                                                lv_segment7,
                                                lv_segment8);


                        COMMIT;


                        debug_msg (
                               ' End credit Insert Record Count '
                            || v_cr_ins_val_type.COUNT
                            || ' at '
                            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                            LOOP
                                ln_error_num   :=
                                    SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                                lv_error_code   :=
                                    SQLERRM (
                                          -1
                                        * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                                lv_error_msg   :=
                                    SUBSTR (
                                        (lv_error_msg || ' Error While Insert into Table Item segment2 ' || v_cr_ins_type (ln_error_num).segment2 || ' segment4 ' || v_cr_ins_type (ln_error_num).segment4 || ' ' || lv_error_code || CHR (10)),
                                        1,
                                        4000);

                                debug_msg (lv_error_msg);
                                lv_status   := 'E';
                                g_errbuf    :=
                                    SUBSTR (
                                           ' No credit Invoices Found '
                                        || SQLERRM,
                                        1,
                                        2000);
                                g_retcode   := 1;
                            END LOOP;

                            debug_msg (
                                   ' End Insert Record Count '
                                || v_ins_type.COUNT
                                || ' at '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                    END;
                END IF;

                v_cr_ins_type.DELETE;
                v_error_tbl_type.DELETE;
                v_cr_ins_val_type.DELETE;
                EXIT WHEN c_gl_cr%NOTFOUND;
            END LOOP;

            CLOSE c_gl_cr;
        END IF;

        BEGIN
            SELECT SUM (usd_dist_amount)
              INTO ln_dr_usd_dist_amount
              FROM xxdo.xxd_ap_prepaid_journal_stg_t
             WHERE request_id = gn_request_id AND status = 'N';
        EXCEPTION
            WHEN OTHERS
            THEN
                debug_msg (
                       ' Exception while Finding ln_dr_usd_dist_amount  '
                    || SQLERRM);
                lv_status               := 'E';
                g_errbuf                :=
                    SUBSTR (
                           ' Exception while Finding ln_dr_usd_dist_amount  '
                        || SQLERRM
                        || SQLERRM,
                        1,
                        2000);
                g_retcode               := 1;
                ln_dr_usd_dist_amount   := NULL;
        END;

        BEGIN
            SELECT code_combination_id
              INTO ln_ccid
              FROM gl_code_combinations_kfv
             WHERE     1 = 1
                   AND NVL (enabled_flag, 'N') = 'Y'
                   AND segment1 = lv_dr_segment1
                   AND segment2 = lv_dr_segment2
                   AND segment3 = lv_dr_segment3
                   AND segment4 = lv_dr_segment4
                   AND segment5 = lv_dr_segment5
                   AND segment6 = lv_dr_segment6
                   AND segment7 = lv_dr_segment7
                   AND segment8 = lv_dr_segment8;
        EXCEPTION
            WHEN OTHERS
            THEN
                debug_msg (
                       ' Exception Debit Code Combination not exists '
                    || lv_dr_segment1
                    || '.'
                    || lv_dr_segment2
                    || '.'
                    || lv_dr_segment3
                    || '.'
                    || lv_dr_segment4
                    || '.'
                    || lv_dr_segment5
                    || '.'
                    || lv_dr_segment6
                    || '.'
                    || lv_dr_segment7
                    || '.'
                    || lv_dr_segment8
                    || SQLERRM);
                lv_status               := 'E';
                g_errbuf                :=
                    SUBSTR (
                           ' Exception Debit Code Combination not exists  '
                        || SQLERRM
                        || SQLERRM,
                        1,
                        2000);
                g_retcode               := 1;
                ln_dr_usd_dist_amount   := NULL;
        END;



        IF (ln_dr_usd_dist_amount IS NOT NULL AND lv_status = 'S')
        THEN
            BEGIN
                INSERT INTO gl.gl_interface (status, ledger_id, accounting_date, currency_code, date_created, created_by, actual_flag, reference10, entered_dr, user_je_source_name, user_je_category_name, GROUP_ID, reference1, -- batch Name
                                                                                                                                                                                                                                  reference4, -- journal_name
                                                                                                                                                                                                                                              period_name, segment1, segment2, segment3, segment4, segment5, segment6
                                             , segment7, segment8)
                     VALUES ('NEW', p_ledger, SYSDATE,
                             'USD', SYSDATE, fnd_global.user_id,
                             'A', lv_batch_name, ln_dr_usd_dist_amount,
                             lv_je_source_name, lv_journal_category_name, ---journal_category,
                                                                          ln_group_id, --group_id
                                                                                       lv_batch_name, --batch_name
                                                                                                      lv_journal_name, --journal_name
                                                                                                                       p_period, lv_dr_segment1, lv_dr_segment2, lv_dr_segment3, lv_dr_segment4, lv_dr_segment5, lv_dr_segment6
                             , lv_dr_segment7, lv_dr_segment8);


                gc_delimiter   := CHR (9);
                debug_msg (
                       ' End Inserting At '
                    || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            EXCEPTION
                WHEN OTHERS
                THEN
                    gc_delimiter   := CHR (9);
                    debug_msg (
                           ' End DR Inserting At '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
                    lv_status      := 'E';
                    g_errbuf       :=
                        SUBSTR (
                            'Error While Inserting Into Table ' || SQLERRM,
                            1,
                            2000);
                    g_retcode      := 1;
            END;
        ELSE
            lv_status   := 'E';
            debug_msg (' No Dr Amount');
            g_errbuf    := SUBSTR (' No Dr Amount ' || SQLERRM, 1, 2000);
            g_retcode   := 1;
        END IF;

        BEGIN
            SELECT access_set_id
              INTO ln_access_set_id
              FROM (  SELECT gas.access_set_id
                        FROM gl_access_sets gas, gl_ledgers gl
                       WHERE     gas.default_ledger_id = gl.ledger_id
                             AND gl.ledger_id = p_ledger
                    ORDER BY gas.access_set_id)
             WHERE ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_access_set_id   := fnd_profile.VALUE ('GL_ACCESS_SET_ID');
        END;

        IF (lv_status = 'S')
        THEN
            BEGIN
                DELETE gl_interface
                 WHERE     USER_JE_CATEGORY_NAME = 'Deferred Prepaid Reclass'
                       AND reference4 <> lv_journal_name;

                ln_parent_request_id   :=
                    fnd_request.submit_request ('SQLGL', 'GLLEZLSRS', -- Short Name of program
                                                                      NULL,
                                                NULL, FALSE, ln_access_set_id, --Data Access Set ID
                                                                               lv_je_source_name_id, --lv_je_source_name,  --Source
                                                                                                     p_ledger, --Ledger
                                                                                                               ln_group_id
                                                ,                   --Group ID
                                                  'N', --Post Errors to Suspense
                                                       'N', --Create Summary Journals
                                                            'O'   --Import DFF
                                                               );

                debug_msg (
                    ' Journals Import Request_id ' || ln_parent_request_id);

                COMMIT;

                IF ln_parent_request_id = 0
                THEN
                    debug_msg (
                           'Request Not Submitted due to "'
                        || fnd_message.get
                        || '".');
                ELSE
                    debug_msg (
                           'The Program Journals Import submitted successfully – Parent Request id :'
                        || ln_parent_request_id);
                END IF;

                IF ln_parent_request_id > 0
                THEN
                    LOOP
                        --To make process execution to wait for 1st program to complete
                        l_req_return_status   :=
                            fnd_concurrent.wait_for_request (
                                request_id   => ln_parent_request_id,
                                INTERVAL     => 5 --interval Number of seconds to wait between checks
                                                 ,
                                max_wait     => 60 --Maximum number of seconds to wait for the request completion
                                                  -- out arguments
                                                  ,
                                phase        => lc_phase,
                                status       => lc_status,
                                dev_phase    => lc_dev_phase,
                                dev_status   => lc_dev_status,
                                MESSAGE      => lc_message);

                        EXIT WHEN    UPPER (lc_phase) = 'COMPLETED'
                                  OR UPPER (lc_status) IN
                                         ('CANCELLED', 'ERROR', 'TERMINATED');
                    END LOOP;

                    BEGIN
                        SELECT request_id
                          INTO ln_request_id
                          FROM fnd_concurrent_requests
                         WHERE parent_request_id = ln_parent_request_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_request_id   := 0;
                    END;

                    IF ln_request_id > 0
                    THEN
                        BEGIN
                            UPDATE xxdo.xxd_ap_prepaid_journal_stg_t
                               SET jr_request_id   = ln_request_id
                             WHERE     request_id = gn_request_id
                                   AND error_message IS NULL;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                debug_msg (
                                       ' Exception While Updating The jr_request_id'
                                    || SQLCODE);
                                lv_status   := 'E';
                                g_errbuf    :=
                                    SUBSTR (
                                           ' Exception While Updating The jr_request_id '
                                        || SQLERRM,
                                        1,
                                        2000);
                                g_retcode   := 1;
                        END;

                        LOOP
                            --To make process execution to wait for 1st program to complete

                            l_req_return_status   :=
                                fnd_concurrent.wait_for_request (
                                    request_id   => ln_request_id,
                                    INTERVAL     => 5 --interval Number of seconds to wait between checks
                                                     ,
                                    max_wait     => 60 --Maximum number of seconds to wait for the request completion
                                                      -- out arguments
                                                      ,
                                    phase        => lc_phase,
                                    status       => lc_status,
                                    dev_phase    => lc_dev_phase,
                                    dev_status   => lc_dev_status,
                                    MESSAGE      => lc_message);

                            EXIT WHEN    UPPER (lc_phase) = 'COMPLETED'
                                      OR UPPER (lc_status) IN
                                             ('CANCELLED', 'ERROR', 'TERMINATED');
                        END LOOP;

                        IF     UPPER (lc_phase) = 'COMPLETED'
                           AND UPPER (lc_status) = 'ERROR'
                        THEN
                            debug_msg (
                                   'The Child Journal Import completed in error. Oracle request id: '
                                || ln_request_id
                                || ' '
                                || SQLERRM);
                        ELSIF     UPPER (lc_phase) = 'COMPLETED'
                              AND UPPER (lc_status) = 'NORMAL'
                        THEN
                            debug_msg (
                                   'The Child Journal Import request successful for request id: '
                                || ln_request_id);

                            BEGIN
                                SELECT je_header_id, name
                                  INTO ln_je_header_id, lv_name
                                  FROM gl_je_headers
                                 WHERE name LIKE lv_journal_name || '%';

                                UPDATE xxdo.xxd_ap_prepaid_journal_stg_t
                                   SET status = 'S', journal_name = lv_name, je_header_id = ln_je_header_id
                                 WHERE     request_id = gn_request_id
                                       AND jr_request_id = ln_request_id
                                       AND ERROR_MESSAGE IS NULL;

                                COMMIT;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    debug_msg (
                                           'OTHERS exception while submitting Child Journal Import Program '
                                        || SQLERRM);
                                    lv_status   := 'E';
                                    g_errbuf    :=
                                        SUBSTR (
                                               'OTHERS exception while submitting Child Journal Import Program '
                                            || SQLERRM,
                                            1,
                                            2000);
                                    g_retcode   := 1;
                            END;
                        ELSE
                            debug_msg (
                                   'The Child Journal Import  request failed. Oracle request id: '
                                || ln_request_id
                                || ' '
                                || SQLERRM);
                            lv_status   := 'E';
                            g_errbuf    :=
                                SUBSTR (
                                       'The Child Journal Import  request failed. Oracle request id: '
                                    || SQLERRM,
                                    1,
                                    2000);
                            g_retcode   := 1;

                            BEGIN
                                UPDATE xxdo.xxd_ap_prepaid_journal_stg_t xapj
                                   SET status   = 'IE',
                                       error_message   =
                                           (SELECT DECODE (gl.status, 'P', 'Pending', gl.status || '-' || status_description)
                                              FROM gl_interface gl
                                             WHERE     gl.request_id =
                                                       xapj.jr_request_id
                                                   AND DECODE (
                                                           xapj.segment2,
                                                           '1000', '6400',
                                                           xapj.segment2) =
                                                       gl.segment2
                                                   AND xapj.segment4 =
                                                       gl.segment4
                                                   AND request_id =
                                                       ln_request_id)
                                 WHERE     request_id = gn_request_id
                                       AND jr_request_id = ln_request_id
                                       AND ERROR_MESSAGE IS NULL;

                                COMMIT;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    debug_msg (
                                           ' Error While Updating the Status in Custom Table '
                                        || ln_request_id
                                        || ' '
                                        || SQLERRM);
                                    lv_status   := 'E';
                                    g_errbuf    :=
                                        SUBSTR (
                                               'Error While Updating the Status in Custom Table '
                                            || SQLERRM,
                                            1,
                                            2000);
                                    g_retcode   := 1;
                            END;
                        END IF;
                    END IF;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    debug_msg (
                           'OTHERS exception while submitting Journal Impoer Program: '
                        || SQLERRM);
                    NULL;
            END;
        END IF;

        apps.fnd_file.put_line (
            apps.fnd_file.OUTPUT,
               'OU_NAME'
            || CHR (9)
            || ' INVOICE_NUM'
            || CHR (9)
            || ' LINE_NUMBER'
            || CHR (9)
            || ' INVOICE_DATE'
            || CHR (9)
            || ' INVOICE_AMOUNT'
            || CHR (9)
            || ' DIST_AMOUNT'
            || CHR (9)
            || ' USD_DIST_AMOUNT'
            || CHR (9)
            || ' ACCOUNTING_DATE'
            || CHR (9)
            || ' VENDOR_NAME'
            || CHR (9)
            || ' VENDOR_SITE_CODE'
            || CHR (9)
            || ' INVOICE_CURRENCY_CODE'
            || CHR (9)
            || ' GL_CODE'
            || CHR (9)
            || ' COST_CENTER'
            || CHR (9)
            || ' ACCOUNT'
            || CHR (9)
            || ' LINE_DESCRIPTION'
            || CHR (9)
            || ' BRAND'
            || CHR (9)
            || ' IC_EXPENSE'
            || CHR (9)
            || ' PO_NUMBER'
            || CHR (9)
            || ' LATEST_RCV_DATE'
            || CHR (9)
            || ' RELATED_PERIOD_RCV'
            || CHR (9)
            || ' MULTIPLE_RECEIPTS'
            || CHR (9)
            || ' DEFERRED_ACCTG_FLAG'
            || CHR (9)
            || ' DEF_ACCTG_START_DATE'
            || CHR (9)
            || ' DEF_ACCTG_END_DATE'
            || CHR (9)
            || ' PAYMENT_DATE'
            || CHR (9)
            || ' TERMS_START_DATE'
            || CHR (9)
            || ' DUE_DATE'
            || CHR (9)
            || ' LINE_CREATION'
            || CHR (9)
            || ' SEGMENT1'
            || CHR (9)
            || ' SEGMENT2'
            || CHR (9)
            || ' SEGMENT3'
            || CHR (9)
            || ' SEGMENT4'
            || CHR (9)
            || ' SEGMENT5'
            || CHR (9)
            || ' SEGMENT6'
            || CHR (9)
            || ' SEGMENT7'
            || CHR (9)
            || ' SEGMENT8'
            || CHR (9)
            || ' REQUEST_ID'
            || CHR (9)
            || ' STATUS'
            || CHR (9)
            || ' ERROR_MESSAGE'
            || CHR (9)
            || ' JE_HEADER_ID'
            || CHR (9)
            || ' JR_REQUEST_ID'
            || CHR (9)
            || ' JOURNAL_NAME');

        OPEN c_write;

        LOOP
            FETCH c_write BULK COLLECT INTO v_write LIMIT 1000;

            IF (v_write.COUNT > 0)
            THEN
                FOR i IN v_write.FIRST .. v_write.LAST
                LOOP
                    BEGIN
                        apps.fnd_file.put_line (
                            apps.fnd_file.OUTPUT,
                               v_write (i).OU_NAME
                            || CHR (9)
                            || v_write (i).INVOICE_NUM
                            || CHR (9)
                            || v_write (i).LINE_NUMBER
                            || CHR (9)
                            || v_write (i).INVOICE_DATE
                            || CHR (9)
                            || v_write (i).INVOICE_AMOUNT
                            || CHR (9)
                            || v_write (i).DIST_AMOUNT
                            || CHR (9)
                            || v_write (i).USD_DIST_AMOUNT
                            || CHR (9)
                            || v_write (i).ACCOUNTING_DATE
                            || CHR (9)
                            || v_write (i).VENDOR_NAME
                            || CHR (9)
                            || v_write (i).VENDOR_SITE_CODE
                            || CHR (9)
                            || v_write (i).INVOICE_CURRENCY_CODE
                            || CHR (9)
                            || v_write (i).GL_CODE
                            || CHR (9)
                            || v_write (i).COST_CENTER
                            || CHR (9)
                            || v_write (i).ACCOUNT
                            || CHR (9)
                            || v_write (i).LINE_DESCRIPTION
                            || CHR (9)
                            || v_write (i).BRAND
                            || CHR (9)
                            || v_write (i).IC_EXPENSE
                            || CHR (9)
                            || v_write (i).PO_NUMBER
                            || CHR (9)
                            || v_write (i).LATEST_RCV_DATE
                            || CHR (9)
                            || v_write (i).RELATED_PERIOD_RCV
                            || CHR (9)
                            || v_write (i).MULTIPLE_RECEIPTS
                            || CHR (9)
                            || v_write (i).DEFERRED_ACCTG_FLAG
                            || CHR (9)
                            || v_write (i).DEF_ACCTG_START_DATE
                            || CHR (9)
                            || v_write (i).DEF_ACCTG_END_DATE
                            || CHR (9)
                            || v_write (i).PAYMENT_DATE
                            || CHR (9)
                            || v_write (i).TERMS_START_DATE
                            || CHR (9)
                            || v_write (i).DUE_DATE
                            || CHR (9)
                            || v_write (i).LINE_CREATION
                            || CHR (9)
                            || v_write (i).SEGMENT1
                            || CHR (9)
                            || v_write (i).SEGMENT2
                            || CHR (9)
                            || v_write (i).SEGMENT3
                            || CHR (9)
                            || v_write (i).SEGMENT4
                            || CHR (9)
                            || v_write (i).SEGMENT5
                            || CHR (9)
                            || v_write (i).SEGMENT6
                            || CHR (9)
                            || v_write (i).SEGMENT7
                            || CHR (9)
                            || v_write (i).SEGMENT8
                            || CHR (9)
                            || v_write (i).REQUEST_ID
                            || CHR (9)
                            || v_write (i).STATUS
                            || CHR (9)
                            || v_write (i).ERROR_MESSAGE
                            || CHR (9)
                            || v_write (i).JE_header_ID
                            || CHR (9)
                            || v_write (i).JR_REQUEST_ID
                            || CHR (9)
                            || v_write (i).JOURNAL_NAME);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            apps.fnd_file.put_line (
                                apps.fnd_file.OUTPUT,
                                   ' Exception while writing into output for PO Number '
                                || v_write (i).INVOICE_NUM
                                || ' '
                                || SQLERRM);
                    END;
                END LOOP;
            END IF;

            EXIT WHEN c_write%NOTFOUND;
        END LOOP;

        CLOSE c_write;

        IF (lv_status = 'E')
        THEN
            x_errbuf    := g_errbuf;
            x_retcode   := g_retcode;
        END IF;

        IF (lv_status = 'S')
        THEN
            IF (p_send_mail = 'Y')
            THEN
                XXDO_MAIL_PKG.send_mail ('Erp@deckers.com', p_email_id, NULL,
                                         lv_instance_name || ' - Deckers Payable Prepaid Reclass Journal Creation Program Completed at ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'), ' Hi,' || CHR (10) || CHR (10) || ' Deckers Payable Prepaid Reclass Journal Creation Program Successfully Completed ' || CHR (10) || CHR (10) || ' Sincerely,' || CHR (10) || ' Finance IT Team', NULL
                                         , lv_mail_status, lv_mail_msg);
                debug_msg (
                       ' Mail Status '
                    || lv_mail_status
                    || ' Mail Message '
                    || lv_mail_msg);
            END IF;
        ELSE
            IF (p_send_mail = 'Y')
            THEN
                XXDO_MAIL_PKG.send_mail ('Erp@deckers.com', p_email_id, NULL,
                                         lv_instance_name || ' - Deckers Payable Prepaid Reclass Journal Creation Program Completed at ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'), ' Hi,' || CHR (10) || CHR (10) || ' Deckers Payable Prepaid Reclass Journal Creation Program Completed in Warning Please check log file and output file of request id: ' || gn_request_id || ' for details ' || CHR (10) || CHR (10) || ' Sincerely,' || CHR (10) || ' Finance IT Team', NULL
                                         , lv_mail_status, lv_mail_msg);
                debug_msg (
                       ' Mail Status '
                    || lv_mail_status
                    || ' Mail Message '
                    || lv_mail_msg);
            END IF;
        END IF;

        debug_msg (' Please check the Output ');
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_status      := 'E';
            g_errbuf       :=
                SUBSTR ('Error While Inserting Into Table ' || SQLERRM,
                        1,
                        2000);
            g_retcode      := 1;

            IF (p_send_mail = 'Y')
            THEN
                XXDO_MAIL_PKG.send_mail ('Erp@deckers.com', p_email_id, NULL,
                                         lv_instance_name || ' - Deckers Payable Prepaid Reclass Journal Creation Program Completed at ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'), ' Hi,' || CHR (10) || CHR (10) || ' Deckers Payable Prepaid Reclass Journal Creation Program Completed in Warning Please check log file and output file of request id: ' || gn_request_id || ' for details ' || CHR (10) || CHR (10) || ' Sincerely,' || CHR (10) || ' Finance IT Team', NULL
                                         , lv_mail_status, lv_mail_msg);
                debug_msg (
                       ' Mail Status '
                    || lv_mail_status
                    || ' Mail Message '
                    || lv_mail_msg);
            END IF;

            x_errbuf       := g_errbuf;
            x_retcode      := g_retcode;
            gc_delimiter   := CHR (9);
            debug_msg (
                ' Error While Inserting ' || SQLERRM || ' ' || gc_delimiter);
            debug_msg (
                   ' End Inserting at '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
    END main_prc;
END xxd_ap_prepaid_journal_pkg;
/
