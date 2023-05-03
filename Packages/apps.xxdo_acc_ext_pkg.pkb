--
-- XXDO_ACC_EXT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:35 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_ACC_EXT_PKG"
AS
    /**********************************************************************************
       NAME:       xxdo_inv_item_conv_pkg
       PURPOSE:    This package contains procedures for Accrual Extract

       REVISIONS:
       Ver        Date         Author                      Description
       ---------  ----------   ---------------  ---------------------------------------
       1.0        09/23/2016   Infosys                Created this package.
       1.1        03-Aug-2017  Viswanathan Pandian    Updated for CCR0006444
    ***********************************************************************************/

    --Global Variables-----
    c_num_debug        NUMBER := 0;
    g_num_request_id   NUMBER := fnd_global.conc_request_id;

    /* g_num_operating_unit     NUMBER         := fnd_profile.VALUE ('ORG_ID');
    g_chr_status             VARCHAR2 (100) := 'UNPROCESSED';
    g_num_user_id            NUMBER         := fnd_global.user_id;
    g_num_resp_id            NUMBER         := fnd_global.resp_id;
    g_num_login_id           NUMBER         := fnd_global.login_id;*/

    --------------------------------------------------------------------------------
    -- Procedure  : msg
    -- Description: procedure to print debug messages
    --------------------------------------------------------------------------------

    PROCEDURE main_acc_ext (p_out_var_errbuf         OUT VARCHAR2,
                            p_out_var_retcode        OUT NUMBER,
                            --  p_in_trxn_date      IN VARCHAR2,
                            p_org_id              IN     NUMBER,
                            p_in_acct_date_from   IN     VARCHAR2,
                            p_in_acct_date_to     IN     VARCHAR2)
    AS
        CURSOR cur_item IS
              SELECT project_id, ou_name, invoice_id,  -- Added for CCR0006444
                     invoice_num, invoice_date, invoice_amount,
                     SUM (dist_amount) AS dist_amount, accounting_date, vendor_name,
                     vendor_site_code, invoice_currency_code, gl_code,
                     cost_center, account, line_number, -- Added for CCR0006444
                     line_description, brand, ic_expense,
                     po_number, latest_rcv_date, rcv_date related_period_rcv,
                     no_of_receipts multiple_receipts, deferred_acctg_flag, def_acctg_start_date,
                     def_acctg_end_date, creation_date line_creation
                FROM (SELECT hou.name
                                 ou_name,
                             aia.invoice_currency_code,
                             aia.invoice_id,           -- Added for CCR0006444
                             aia.invoice_num,
                             aia.invoice_date,
                             aia.invoice_amount,
                             aida.amount
                                 dist_amount,
                             aida.accounting_date,
                             asa.vendor_name,
                             assa.vendor_site_code,
                             gcc.concatenated_segments
                                 gl_code,
                             (SELECT ffvl.description
                                FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffvl
                               WHERE     ffvs.flex_value_set_id =
                                         ffvl.flex_value_set_id
                                     AND ffvs.flex_value_set_name =
                                         'DO_GL_COST_CENTER'
                                     AND gcc.segment5 = ffvl.flex_value)
                                 cost_center,
                             (SELECT ffvl.description
                                FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffvl
                               WHERE     ffvs.flex_value_set_id =
                                         ffvl.flex_value_set_id
                                     AND ffvs.flex_value_set_name =
                                         'DO_GL_ACCOUNT'
                                     AND gcc.segment6 = ffvl.flex_value)
                                 account,
                             -- Start modification for CCR0006444
                             --aila.description line_description,
                             aila.line_number,
                             REPLACE (aila.description, CHR (9))
                                 line_description,
                             -- End modification for CCR0006444
                             DECODE (aida.posted_flag,
                                     'Y', 'Processed',
                                     'UnProcessed')
                                 accounted,
                             (SELECT brand
                                FROM apps.xxd_common_items_v xv
                               WHERE     organization_id =
                                         (SELECT m.organization_id
                                            FROM mtl_parameters m
                                           WHERE organization_code = 'MST')
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
                               WHERE rt.po_line_id = aila.po_line_id --  AND transaction_date < fnd_date.canonical_to_date (p_in_trxn_date) --from date parameter
                                                                    --AND transaction_date < to_date (p_in_trxn_date) --from date parameter
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
                                 project_id
                        FROM ap_invoices_all aia, ap_invoice_lines_all aila, apps.ap_invoice_distributions_all aida,
                             gl_code_combinations_kfv gcc, hr_operating_units hou, ap_suppliers asa,
                             ap_supplier_sites_all assa
                       WHERE     aia.invoice_id = aila.invoice_id
                             AND aia.invoice_id = aida.invoice_id
                             AND aila.line_number = aida.invoice_line_number
                             AND aida.dist_code_combination_id =
                                 gcc.code_combination_id
                             AND aia.org_id = hou.organization_id
                             AND aia.vendor_id <>
                                 (SELECT vendor_id
                                    FROM ap_suppliers
                                   WHERE vendor_name = 'On-Hand Conversion')
                             AND aia.vendor_id = asa.vendor_id
                             AND aia.vendor_site_id = assa.vendor_site_id
                             AND aida.accounting_date >=
                                 fnd_date.canonical_to_date (
                                     p_in_acct_date_from) --from date parameter
                             AND aida.accounting_date <=
                                 fnd_date.canonical_to_date (p_in_acct_date_to) --to date parameter
                             AND aia.org_id = NVL (p_org_id, aia.org_id) --operating unit parameter if commented all
                                                                        )
            GROUP BY ou_name, invoice_id,              -- Added for CCR0006444
                                          invoice_num,
                     invoice_date, invoice_amount, accounting_date,
                     vendor_name, vendor_site_code, invoice_currency_code,
                     gl_code, cost_center, account,
                     line_number,                      -- Added for CCR0006444
                                  line_description, brand,
                     ic_expense, po_number, rcv_date,
                     deferred_acctg_flag, def_acctg_start_date, def_acctg_end_date,
                     creation_date, project_id, no_of_receipts,
                     latest_rcv_date
            ORDER BY 1, 2, 3,
                     5, 6;


        fhandle               UTL_FILE.file_type;
        lv_file_name          VARCHAR2 (50)
                                  := 'Items-' || g_num_request_id || '.xls';
        lv_hdata_record       VARCHAR2 (32767);
        l_num_count           NUMBER := 0;

        /* lv_location                VARCHAR2 (50)     := 'XXDO_INV_ITEM_FILE_DIR';
         l_chr_req_failure          VARCHAR2 (1)       := 'N';
         l_chr_phase                VARCHAR2 (100)     := NULL;
         l_chr_status               VARCHAR2 (100)     := NULL;
         l_chr_dev_phase            VARCHAR2 (100)     := NULL;
         l_chr_dev_status           VARCHAR2 (100)     := NULL;
         l_chr_message              VARCHAR2 (1000)    := NULL;

         ln_set_process_id          NUMBER             := 0;

         ln_batch_size              NUMBER             := 1000;
         ln_total_count             NUMBER;*/
        -- Start changes for CCR0006444
        CURSOR get_payment_details (
            p_invoice_id IN ap_invoices_all.invoice_id%TYPE)
        IS
            SELECT LISTAGG (ipa.payment_date, ', ') WITHIN GROUP (ORDER BY ipa.payment_date) payment_date, MIN (ipa.creation_date) entered_date, MAX (ipa.last_update_date) last_update_date
              FROM iby_payments_all ipa, ap_checks_all aca, ap_invoice_payments_all aipa
             WHERE     ipa.payment_id = aca.payment_id
                   AND aca.check_id = aipa.check_id
                   AND NVL (aipa.reversal_flag, 'N') <> 'Y'
                   AND aipa.invoice_id = p_invoice_id;

        lc_payment_date       VARCHAR2 (2000);
        ld_entered_date       DATE;
        ld_last_update_date   DATE;
    -- End changes for CCR0006444
    BEGIN
        FOR rec_cur_item IN cur_item
        LOOP
            l_num_count   := l_num_count + 1;

            IF l_num_count = 1
            THEN
                fnd_file.put_line (
                    fnd_file.output,
                       'PROJECT ID'
                    || CHR (9)
                    || 'OU_NAME'
                    || CHR (9)
                    || 'INVOICE NUMBER'
                    || CHR (9)
                    || 'INVOICE DATE'
                    || CHR (9)
                    || 'INVOICE AMOUNT'
                    || CHR (9)
                    || 'DIST AMOUNT'
                    || CHR (9)
                    || 'ACCOUNTING DATE'
                    || CHR (9)
                    || 'VENDOR NAME'
                    || CHR (9)
                    || 'VENDOR SITE CODE'
                    || CHR (9)
                    || 'INVOICE CURRENCY CODE'
                    || CHR (9)
                    || 'GL CODE'
                    || CHR (9)
                    || 'COST CENTER'
                    || CHR (9)
                    || 'ACCOUNT'
                    || CHR (9)
                    -- Start changes for CCR0006444
                    || 'LINE NUMBER'
                    || CHR (9)
                    -- End changes for CCR0006444
                    || 'LINE DESCRIPTION'
                    || CHR (9)
                    -- Start changes for CCR0006444
                    || 'PAYMENT DATE'
                    || CHR (9)
                    || 'ENTERED DATE'
                    || CHR (9)
                    || 'LAST UPDATE DATE'
                    || CHR (9)
                    -- End changes for CCR0006444
                    || 'BRAND'
                    || CHR (9)
                    || 'IC EXPENSE'
                    || CHR (9)
                    || 'PO NUMBER'
                    || CHR (9)
                    || 'LATEST RCV DATE'
                    || CHR (9)
                    || 'RELATED PERIOD RCV'
                    || CHR (9)
                    || 'MULTPLE RECEIPTS'
                    || CHR (9)
                    || 'DEF ACCTG FLAG'
                    || CHR (9)
                    || 'DEF ACCTG START DATE'
                    || CHR (9)
                    || 'DEF ACCTG END DATE'
                    || CHR (9)
                    || 'LINE CREATION');
            END IF;

            -- Start changes for CCR0006444
            OPEN get_payment_details (rec_cur_item.invoice_id);

            FETCH get_payment_details INTO lc_payment_date, ld_entered_date, ld_last_update_date;

            CLOSE get_payment_details;

            -- End changes for CCR0006444

            lv_hdata_record   :=
                   rec_cur_item.project_id
                || CHR (9)
                || rec_cur_item.ou_name
                || CHR (9)
                || rec_cur_item.invoice_num
                || CHR (9)
                || rec_cur_item.invoice_date
                || CHR (9)
                || rec_cur_item.invoice_amount
                || CHR (9)
                || rec_cur_item.dist_amount
                || CHR (9)
                || rec_cur_item.accounting_date
                || CHR (9)
                || rec_cur_item.vendor_name
                || CHR (9)
                || rec_cur_item.vendor_site_code
                || CHR (9)
                || rec_cur_item.invoice_currency_code
                || CHR (9)
                || rec_cur_item.gl_code
                || CHR (9)
                || rec_cur_item.cost_center
                || CHR (9)
                || rec_cur_item.account
                || CHR (9)
                -- Start changes for CCR0006444
                || rec_cur_item.line_number
                || CHR (9)
                -- End changes for CCR0006444
                || REPLACE (rec_cur_item.line_description, CHR (10), ' ')
                -- ||  trim(rec_cur_item.line_description)
                || CHR (9)
                -- Start changes for CCR0006444
                || lc_payment_date
                || CHR (9)
                || ld_entered_date
                || CHR (9)
                || ld_last_update_date
                || CHR (9)
                -- End changes for CCR0006444
                || rec_cur_item.brand
                || CHR (9)
                || rec_cur_item.ic_expense
                || CHR (9)
                || rec_cur_item.po_number
                || CHR (9)
                || rec_cur_item.latest_rcv_date
                || CHR (9)
                || rec_cur_item.related_period_rcv
                || CHR (9)
                || rec_cur_item.multiple_receipts
                || CHR (9)
                || rec_cur_item.deferred_acctg_flag
                || CHR (9)
                || rec_cur_item.def_acctg_start_date
                || CHR (9)
                || rec_cur_item.def_acctg_end_date
                || CHR (9)
                || rec_cur_item.line_creation;
            --UTL_FILE.put_line (fhandle, lv_hdata_record);
            fnd_file.put_line (fnd_file.output, lv_hdata_record);
        END LOOP;
    EXCEPTION
        WHEN UTL_FILE.invalid_path
        THEN
            raise_application_error (-20100, 'Invalid Path');
            UTL_FILE.fclose (fhandle);
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
        WHEN UTL_FILE.invalid_mode
        THEN
            raise_application_error (-20101, 'Invalid Mode');
            UTL_FILE.fclose (fhandle);
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
        WHEN UTL_FILE.invalid_operation
        THEN
            raise_application_error (-20102, 'Invalid Operation');
            UTL_FILE.fclose (fhandle);
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
        WHEN UTL_FILE.invalid_filehandle
        THEN
            raise_application_error (-20103, 'Invalid Filehandle');
            UTL_FILE.fclose (fhandle);
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
        WHEN UTL_FILE.write_error
        THEN
            raise_application_error (-20104, 'Write Error');
            UTL_FILE.fclose (fhandle);
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
        WHEN UTL_FILE.read_error
        THEN
            raise_application_error (-20105, 'Read Error');
            UTL_FILE.fclose (fhandle);
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
        WHEN UTL_FILE.internal_error
        THEN
            raise_application_error (-20106, 'Internal Error');
            UTL_FILE.fclose (fhandle);
    END main_acc_ext;
END xxdo_acc_ext_pkg;
/
