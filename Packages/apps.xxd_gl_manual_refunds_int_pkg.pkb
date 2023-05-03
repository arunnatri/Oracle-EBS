--
-- XXD_GL_MANUAL_REFUNDS_INT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:59 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_GL_MANUAL_REFUNDS_INT_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_GL_MANUAL_REFUNDS_INT_PKG
    * Design       : This package is used for creating GL Journals for the manual refunds
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 14-May-2018  1.0        Viswanathan Pandian     Initial Version
    ******************************************************************************************/
    gc_ledger                     gl_ledgers.name%TYPE;
    gc_user_je_source_name        gl_je_sources.user_je_source_name%TYPE;
    gc_user_je_category_name      gl_je_categories.user_je_category_name%TYPE;
    gc_currency_conversion_type   gl_interface.user_currency_conversion_type%TYPE;
    gn_user_id                    NUMBER := fnd_global.user_id;
    gn_login_id                   NUMBER := fnd_global.login_id;
    gn_request_id                 NUMBER := fnd_global.conc_request_id;
    gd_sysdate                    DATE := SYSDATE;

    -- ======================================================================================
    -- This procedure will insert data into the staging table
    -- ======================================================================================
    PROCEDURE populate_staging (x_ret_status      OUT NOCOPY VARCHAR2,
                                x_ret_msg         OUT NOCOPY VARCHAR2)
    IS
        --Get Valid records from staging
        CURSOR get_data IS
            SELECT 'Zendesk Data' data_type, gl.ledger_id, gl.name ledger_name,
                   gl.currency_code ledger_currency_code, gc_user_je_source_name user_je_source_name, gc_user_je_category_name user_je_category_name,
                   xmr.payment_date accounting_date, xmr.refund_id, xmr.refund_pg_dtl_id,
                   xmr.refund_reason, xmr.payment_tender_type, xmr.currency_code refund_currency_code,
                   xmr.payment_date currency_conversion_date, gc_currency_conversion_type user_currency_conversion_type, xmr.payment_amount entered_cr,
                   xmr.payment_amount entered_dr, flv.attribute5 debit_concatenated_segments, dr_gcc.code_combination_id debit_ccid,
                   cr_gcc.concatenated_segments credit_concatenated_segments, cr_gcc.code_combination_id credit_ccid, xmr.refund_pg_dtl_id line_description,
                   'REFUND_PG_DTL_ID_' || xmr.refund_pg_dtl_id reference21
              FROM xxdo.xxdoec_manual_refund_pg_dtls xmr, xxdo.xxdoec_order_manual_refunds xomr, fnd_lookup_values flv,
                   hr_operating_units hou, gl_ledgers gl, gl_code_combinations_kfv dr_gcc,
                   gl_code_combinations_kfv cr_gcc, xxdo.xxdoec_country_brand_params xcbp, ar_receipt_methods arm,
                   ar_receipt_method_accounts_all armaa, ce_bank_acct_uses_all cbaua, ce_bank_accounts cba
             WHERE     xmr.refund_id = xomr.refund_id
                   AND xomr.header_id = 0
                   AND flv.lookup_type = 'XXDOEC_MANUAL_REFUND_REASONS'
                   AND xmr.refund_reason = flv.attribute4
                   AND xomr.web_site_id = flv.attribute3
                   AND flv.language = USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (
                                                       flv.start_date_active,
                                                       SYSDATE))
                                           AND TRUNC (
                                                   NVL (flv.end_date_active,
                                                        SYSDATE))
                   AND TO_NUMBER (flv.attribute1) = hou.organization_id
                   AND hou.set_of_books_id = gl.ledger_id
                   AND dr_gcc.concatenated_segments = flv.attribute5
                   AND xomr.web_site_id = xcbp.website_id
                   AND TO_NUMBER (flv.attribute1) = xcbp.erp_org_id
                   AND xmr.payment_type = arm.attribute2
                   AND arm.receipt_class_id = xcbp.ar_receipt_class_id
                   AND NVL (arm.attribute4, 'N') = 'N'
                   AND armaa.receipt_method_id = arm.receipt_method_id
                   AND cbaua.bank_acct_use_id = armaa.remit_bank_acct_use_id
                   AND cba.bank_account_id = cbaua.bank_account_id
                   AND cba.currency_code = xmr.currency_code
                   AND TO_NUMBER (flv.attribute1) = armaa.org_id
                   AND cr_gcc.code_combination_id = armaa.cash_ccid
                   AND NVL (xmr.refund_id, 0) > 0
                   AND ((gc_ledger IS NOT NULL AND gl.name = gc_ledger) OR (gc_ledger IS NULL AND 1 = 1))
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxdo.xxd_gl_manual_refunds_int_t xgmr
                             WHERE     xgmr.refund_pg_dtl_id =
                                       xmr.refund_pg_dtl_id
                                   AND xgmr.record_status = 'P')
            UNION
            SELECT 'AMR Data' data_type, gl.ledger_id, gl.name ledger_name,
                   gl.currency_code ledger_currency_code, gc_user_je_source_name user_je_source_name, gc_user_je_category_name user_je_category_name,
                   xmr.payment_date accounting_date, xmr.refund_id, xmr.refund_pg_dtl_id,
                   xmr.refund_reason, xmr.payment_tender_type, xmr.currency_code refund_currency_code,
                   xmr.payment_date currency_conversion_date, gc_currency_conversion_type user_currency_conversion_type, xmr.payment_amount entered_cr,
                   xmr.payment_amount entered_dr, flv.attribute5 debit_concatenated_segments, dr_gcc.code_combination_id debit_ccid,
                   cr_gcc.concatenated_segments credit_concatenated_segments, cr_gcc.code_combination_id credit_ccid, xmr.refund_pg_dtl_id line_description,
                   'REFUND_PG_DTL_ID_' || xmr.refund_pg_dtl_id reference21
              FROM xxdo.xxdoec_manual_refund_pg_dtls xmr,
                   (  SELECT xomr.line_group_id, xomr.web_site_id
                        FROM xxdo.xxdoec_order_manual_refunds xomr
                       WHERE xomr.header_id > 0
                    GROUP BY xomr.line_group_id, xomr.web_site_id) xomr,
                   fnd_lookup_values flv,
                   hr_operating_units hou,
                   gl_ledgers gl,
                   gl_code_combinations_kfv dr_gcc,
                   gl_code_combinations_kfv cr_gcc,
                   xxdo.xxdoec_country_brand_params xcbp,
                   ar_receipt_methods arm,
                   ar_receipt_method_accounts_all armaa,
                   ce_bank_acct_uses_all cbaua,
                   ce_bank_accounts cba
             WHERE     xmr.line_group_id = xomr.line_group_id
                   AND flv.lookup_type = 'XXDOEC_MANUAL_REFUND_REASONS'
                   AND xmr.refund_reason = flv.attribute4
                   AND xomr.web_site_id = flv.attribute3
                   AND flv.language = USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (
                                                       flv.start_date_Active,
                                                       SYSDATE))
                                           AND TRUNC (
                                                   NVL (flv.end_date_active,
                                                        SYSDATE))
                   AND TO_NUMBER (flv.attribute1) = hou.organization_id
                   AND hou.set_of_books_id = gl.ledger_id
                   AND dr_gcc.concatenated_segments = flv.attribute5
                   AND xomr.web_site_id = xcbp.website_id
                   AND TO_NUMBER (flv.attribute1) = xcbp.erp_org_id
                   AND xmr.payment_type = arm.attribute2
                   AND arm.receipt_class_id = xcbp.ar_receipt_class_id
                   AND NVL (arm.attribute4, 'N') = 'N'
                   AND armaa.receipt_method_id = arm.receipt_method_id
                   AND cbaua.bank_acct_use_id = armaa.remit_bank_acct_use_id
                   AND cba.bank_account_id = cbaua.bank_account_id
                   AND cba.currency_code = xmr.currency_code
                   AND TO_NUMBER (flv.attribute1) = armaa.org_id
                   AND cr_gcc.code_combination_id = armaa.cash_ccid
                   AND NVL (xmr.refund_id, 0) = 0
                   AND ((gc_ledger IS NOT NULL AND gl.name = gc_ledger) OR (gc_ledger IS NULL AND 1 = 1))
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxdo.xxd_gl_manual_refunds_int_t xgmr
                             WHERE     xgmr.refund_pg_dtl_id =
                                       xmr.refund_pg_dtl_id
                                   AND xgmr.record_status = 'P');

        ln_count   NUMBER := 0;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Populate Staging Table');

        FOR data_rec IN get_data
        LOOP
            ln_count   := ln_count + 1;

            INSERT INTO xxdo.xxd_gl_manual_refunds_int_t (
                            record_id,
                            data_type,
                            ledger_id,
                            ledger_name,
                            ledger_currency_code,
                            user_je_source_name,
                            user_je_category_name,
                            accounting_date,
                            refund_id,
                            refund_pg_dtl_id,
                            refund_reason,
                            payment_tender_type,
                            refund_currency_code,
                            currency_conversion_date,
                            user_currency_conversion_type,
                            entered_cr,
                            entered_dr,
                            credit_concatenated_segments,
                            credit_ccid,
                            debit_concatenated_segments,
                            debit_ccid,
                            reference10_line_description,
                            reference21,
                            record_status,
                            request_id,
                            created_by,
                            creation_date,
                            last_updated_by,
                            last_update_date,
                            last_update_login)
                 VALUES (xxdo.xxd_gl_manual_refunds_int_s.NEXTVAL, data_rec.data_type, data_rec.ledger_id, data_rec.ledger_name, data_rec.ledger_currency_code, data_rec.user_je_source_name, data_rec.user_je_category_name, data_rec.accounting_date, data_rec.refund_id, data_rec.refund_pg_dtl_id, data_rec.refund_reason, data_rec.payment_tender_type, data_rec.refund_currency_code, data_rec.currency_conversion_date, data_rec.user_currency_conversion_type, data_rec.entered_cr, data_rec.entered_dr, data_rec.credit_concatenated_segments, data_rec.credit_ccid, data_rec.debit_concatenated_segments, data_rec.debit_ccid, data_rec.line_description, data_rec.reference21, 'N', gn_request_id, gn_user_id, gd_sysdate
                         , gn_user_id, gd_sysdate, gn_login_id);
        END LOOP;

        fnd_file.put_line (fnd_file.LOG,
                           'Staging Table Record Count: ' || ln_count);

        x_ret_status   := 'S';
        x_ret_msg      := NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_status   := 'E';
            x_ret_msg      := SQLERRM;
            fnd_file.put_line (fnd_file.LOG,
                               'Error in POPULATE_STAGING:' || SQLERRM);
    END populate_staging;

    -- ======================================================================================
    -- This procedure will insert data into GL_INTERFACE
    -- ======================================================================================
    PROCEDURE populate_gl_int (x_ret_status      OUT NOCOPY VARCHAR2,
                               x_ret_msg         OUT NOCOPY VARCHAR2)
    IS
        --Get Valid records from staging
        CURSOR get_valid_data IS
            SELECT *
              FROM xxdo.xxd_gl_manual_refunds_int_t
             WHERE request_id = gn_request_id AND record_status = 'N';

        ln_count   NUMBER := 0;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Populate GL Interface');

        FOR valid_data_rec IN get_valid_data
        LOOP
            ln_count   := ln_count + 1;

            IF ln_count = 1
            THEN
                fnd_file.put_line (
                    fnd_file.output,
                       RPAD ('GL Manual Refund Journal Creation - Deckers',
                             190,
                             ' ')
                    || TO_CHAR (SYSDATE, 'DD-Mon-YYYY HH:MI:SS PM')
                    || CHR (13)
                    || CHR (10));
                fnd_file.put_line (
                    fnd_file.output,
                       RPAD ('Ledger Name', 32, ' ')
                    || RPAD ('Currency', 10, ' ')
                    || RPAD ('Accounting Date', 17, ' ')
                    || RPAD ('JE Source', 27, ' ')
                    || RPAD ('JE Category', 27, ' ')
                    || RPAD ('GL Segments', 38, ' ')
                    || RPAD ('Entered Cr', 20, ' ')
                    || RPAD ('Entered Dr', 20, ' ')
                    || RPAD ('Line Description (Refund_PG_Dtl_ID)', 37, ' ')
                    || 'Refund Reason');
                fnd_file.put_line (fnd_file.output, RPAD ('=', 241, '='));
            END IF;

            fnd_file.put_line (
                fnd_file.output,
                   RPAD (valid_data_rec.ledger_name, 32, ' ')
                || RPAD (valid_data_rec.refund_currency_code, 10, ' ')
                || RPAD (valid_data_rec.accounting_date, 17, ' ')
                || RPAD (valid_data_rec.user_je_source_name, 27, ' ')
                || RPAD (valid_data_rec.user_je_category_name, 27, ' ')
                || RPAD (valid_data_rec.credit_concatenated_segments,
                         38,
                         ' ')
                || RPAD (valid_data_rec.entered_cr, 20, ' ')
                || RPAD (' ', 20, ' ')
                || RPAD (valid_data_rec.refund_pg_dtl_id, 37, ' ')
                || valid_data_rec.refund_reason);

            INSERT INTO gl_interface (status,
                                      ledger_id,
                                      accounting_date,
                                      currency_code,
                                      date_created,
                                      created_by,
                                      actual_flag,
                                      currency_conversion_date,
                                      reference10,
                                      reference21,
                                      code_combination_id,
                                      entered_cr,
                                      user_je_source_name,
                                      user_je_category_name,
                                      user_currency_conversion_type)
                     VALUES (
                                'NEW',
                                valid_data_rec.ledger_id,
                                valid_data_rec.accounting_date,
                                valid_data_rec.refund_currency_code,
                                valid_data_rec.creation_date,
                                valid_data_rec.created_by,
                                'A',
                                CASE
                                    WHEN valid_data_rec.ledger_currency_code <>
                                         valid_data_rec.refund_currency_code
                                    THEN
                                        valid_data_rec.currency_conversion_date
                                    ELSE
                                        NULL
                                END,
                                valid_data_rec.reference10_line_description,
                                valid_data_rec.reference21,
                                valid_data_rec.credit_ccid,
                                valid_data_rec.entered_cr,
                                valid_data_rec.user_je_source_name,
                                valid_data_rec.user_je_category_name,
                                CASE
                                    WHEN valid_data_rec.ledger_currency_code <>
                                         valid_data_rec.refund_currency_code
                                    THEN
                                        valid_data_rec.user_currency_conversion_type
                                    ELSE
                                        NULL
                                END);

            fnd_file.put_line (
                fnd_file.output,
                   RPAD (valid_data_rec.ledger_name, 32, ' ')
                || RPAD (valid_data_rec.refund_currency_code, 10, ' ')
                || RPAD (valid_data_rec.accounting_date, 17, ' ')
                || RPAD (valid_data_rec.user_je_source_name, 27, ' ')
                || RPAD (valid_data_rec.user_je_category_name, 27, ' ')
                || RPAD (valid_data_rec.debit_concatenated_segments, 38, ' ')
                || RPAD (' ', 20, ' ')
                || RPAD (valid_data_rec.entered_dr, 20, ' ')
                || RPAD (valid_data_rec.refund_pg_dtl_id, 37, ' ')
                || valid_data_rec.refund_reason);

            INSERT INTO gl_interface (status,
                                      ledger_id,
                                      accounting_date,
                                      currency_code,
                                      date_created,
                                      created_by,
                                      actual_flag,
                                      currency_conversion_date,
                                      reference10,
                                      reference21,
                                      code_combination_id,
                                      entered_dr,
                                      user_je_source_name,
                                      user_je_category_name,
                                      user_currency_conversion_type)
                     VALUES (
                                'NEW',
                                valid_data_rec.ledger_id,
                                valid_data_rec.accounting_date,
                                valid_data_rec.refund_currency_code,
                                valid_data_rec.creation_date,
                                valid_data_rec.created_by,
                                'A',
                                CASE
                                    WHEN valid_data_rec.ledger_currency_code <>
                                         valid_data_rec.refund_currency_code
                                    THEN
                                        valid_data_rec.currency_conversion_date
                                    ELSE
                                        NULL
                                END,
                                valid_data_rec.reference10_line_description,
                                valid_data_rec.reference21,
                                valid_data_rec.debit_ccid,
                                valid_data_rec.entered_dr,
                                valid_data_rec.user_je_source_name,
                                valid_data_rec.user_je_category_name,
                                CASE
                                    WHEN valid_data_rec.ledger_currency_code <>
                                         valid_data_rec.refund_currency_code
                                    THEN
                                        valid_data_rec.user_currency_conversion_type
                                    ELSE
                                        NULL
                                END);

            UPDATE xxdo.xxd_gl_manual_refunds_int_t
               SET record_status   = 'P'
             WHERE record_id = valid_data_rec.record_id;
        END LOOP;

        fnd_file.put_line (fnd_file.LOG,
                           'GL_INTERFACE Record Count: ' || ln_count);
        x_ret_status   := 'S';
        x_ret_msg      := NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_status   := 'E';
            x_ret_msg      := SQLERRM;
            fnd_file.put_line (fnd_file.LOG,
                               'Error in POPULATE_GL_INT:' || SQLERRM);
    END populate_gl_int;

    -- ======================================================================================
    -- This procedure will be called from the concurrent program
    -- ======================================================================================
    PROCEDURE main (x_retcode OUT NOCOPY VARCHAR2, x_errbuf OUT NOCOPY VARCHAR2, p_ledger IN gl_ledgers.name%TYPE
                    , p_source IN gl_interface.user_je_source_name%TYPE, p_category IN gl_interface.user_je_category_name%TYPE, p_rate_type IN gl_interface.user_currency_conversion_type%TYPE)
    IS
        lc_ret_status    VARCHAR2 (30);
        lc_ret_msg       VARCHAR2 (4000);
        ex_ins_staging   EXCEPTION;
        ex_pop_gl_int    EXCEPTION;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Inside Main Procedure');
        fnd_file.put_line (fnd_file.LOG,
                           '----------------------------------------');
        fnd_file.put_line (fnd_file.LOG, 'P_SOURCE: ' || p_source);
        fnd_file.put_line (fnd_file.LOG, 'P_CATEGORY: ' || p_category);
        fnd_file.put_line (fnd_file.LOG, 'P_RATE_TYPE: ' || p_rate_type);
        fnd_file.put_line (fnd_file.LOG,
                           '----------------------------------------');
        gc_ledger                     := p_ledger;
        gc_user_je_source_name        := p_source;
        gc_user_je_category_name      := p_category;
        gc_currency_conversion_type   := p_rate_type;

        --Populate Data into Staging table
        populate_staging (x_ret_status   => lc_ret_status,
                          x_ret_msg      => lc_ret_msg);

        IF lc_ret_status = 'E'
        THEN
            RAISE ex_ins_staging;
        END IF;

        --Populate valid data into GL_INTERFACE
        populate_gl_int (x_ret_status   => lc_ret_status,
                         x_ret_msg      => lc_ret_msg);

        IF lc_ret_status = 'E'
        THEN
            RAISE ex_pop_gl_int;
        END IF;
    EXCEPTION
        WHEN ex_ins_staging
        THEN
            x_retcode   := '1';
            x_errbuf    := lc_ret_msg;
            fnd_file.put_line (
                fnd_file.LOG,
                'Error Populating data into Staging:' || lc_ret_msg);
        WHEN ex_pop_gl_int
        THEN
            x_retcode   := '1';
            x_errbuf    := lc_ret_msg;
            fnd_file.put_line (
                fnd_file.LOG,
                'Error Populating GL_INTERFACE table:' || lc_ret_msg);
        WHEN OTHERS
        THEN
            x_retcode   := '2';
            x_errbuf    := SQLERRM;
            fnd_file.put_line (fnd_file.LOG, 'Error in MAIN:' || SQLERRM);
    END main;
END xxd_gl_manual_refunds_int_pkg;
/
