--
-- XXD_AP_MTD_REPORT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:45 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AP_MTD_REPORT_PKG"
AS
    /****************************************************************************************
     * Package      : XXD_MTD_REPORTD_PKG
     * Design       : This package will be used for MTD Reports
     * Notes        :
     * Modification :
     -- ======================================================================================
     -- Date         Version#   Name                    Comments
     -- ======================================================================================
     -- 14-Aug-2020  1.0        Tejaswi Gangumalla      Initial Version
     -- 22-FEB-2021  1.1        Satyanarayana Kotha     Modified for CCR0009103
     -- 06-Oct-2021  1.2        Aravind Kannuri         Modified for CCR0009638
     -- 12-OCT-2021  1.2        Showkath Ali            Modified for CCR0009638
     -- 22-AUG-2022  1.3        Srinath Siricilla       Modified for CCR0010176
    ******************************************************************************************/

    -- Start Added for 1.2
    FUNCTION remove_junk_char (p_input IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_output   VARCHAR2 (32767) := NULL;
    BEGIN
        IF p_input IS NOT NULL
        THEN
            SELECT REPLACE (REPLACE (REPLACE (REPLACE (REPLACE (p_input, CHR (9), ''), CHR (10), ''), '|', ' '), CHR (13), ''), ',', '')
              INTO lv_output
              FROM DUAL;
        ELSE
            RETURN NULL;
        END IF;

        RETURN lv_output;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END remove_junk_char;

    -- End Added for 1.2

    PROCEDURE mtd_ap_rep (pv_errbuf OUT NOCOPY VARCHAR2, pn_retcode OUT NOCOPY NUMBER, pv_operating_unit IN VARCHAR2, pv_company_code IN VARCHAR2, pv_invoice_date_from IN VARCHAR2, pv_invoice_date_to IN VARCHAR2, pv_gl_posted_from IN VARCHAR2, pv_gl_posted_to IN VARCHAR2, pv_tax_regime_code IN VARCHAR2, pv_tax_code IN VARCHAR2, pv_account IN VARCHAR2, pv_cost_center IN VARCHAR2
                          , --  pv_posting_status      IN              VARCHAR2,
                            pv_final_mode IN VARCHAR2)
    AS
        pd_invoice_date_from   DATE
            := fnd_date.canonical_to_date (pv_invoice_date_from);
        pd_invoice_date_to     DATE
            := fnd_date.canonical_to_date (pv_invoice_date_to);
        pd_gl_posted_from      DATE
            := fnd_date.canonical_to_date (pv_gl_posted_from);
        pd_gl_posted_to        DATE
            := fnd_date.canonical_to_date (pv_gl_posted_to);
        lv_outbound_file       VARCHAR2 (100)
            :=    'AP_VAT_EMEA_REPORT_'
               || gn_request_id
               || '_'
               || TO_CHAR (SYSDATE, 'DDMONYYHH24MISS')
               || '.txt';

        lv_output_file         UTL_FILE.file_type;
        pv_directory_name      VARCHAR2 (100) := 'XXD_AP_MTD_REPORT_OUT_DIR';

        CURSOR ap_rep_cur IS
            SELECT transaction_type || '|' || gl_entity_code || '|' || remove_junk_char (ou_name) || '|' || remove_junk_char (vendor_name) --4.1
                                                                                                                                           || '|' || vendor_number || '|' || remove_junk_char (vendor_vat_number) || '|' || vendor_site_country || '|' || ship_to_country || '|' || remove_junk_char (document_type) --4.1
                                                                                                                                                                                                                                                                                                                     || '|' || remove_junk_char (invoice_number) --4.1
                                                                                                                                                                                                                                                                                                                                                                 || '|' || invoice_date_fmt || '|' || invoice_currency || '|' || po_number || '|' || remove_junk_char (purchasing_category) --4.1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            || '|' || line_total_amt || '|' || line_net_amt || '|' || line_input_tax_amt || '|' --Start Added for 1.2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                || line_tax_country || '|' --End Added for 1.2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           || remove_junk_char (line_input_tax_code) --4.1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     || '|' || line_output_tax_amt || '|' || remove_junk_char (line_output_tax_code) --4.1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     || '|' || line_input_tax_recoverability || '|' || line_tax_rate || '|' || ex_rate || '|' || gl_geo_code || '|' -- || nature_of_transaction
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    --|| '|'
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    || gl_natural_acc_code || '|' || accounting_date_fmt || '|' || validation_date || '|' || primary_intended_use --Added for CCR0009103
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  || '|' || gapless_sequence_number rep_data -- Added for CCR0010176
              FROM (  SELECT 'AP'
                                 transaction_type,
                             gcc.segment1
                                 gl_entity_code,
                             hu.NAME
                                 ou_name,
                             aps.vendor_name,
                             aps.segment1
                                 vendor_number,
                             aps.vat_registration_num
                                 vendor_vat_number,
                             -- tax_registration_number
                             apsa.country
                                 vendor_site_country,
                             aila.line_number,
                             (SELECT country
                                FROM hr_locations
                               WHERE location_id = aila.ship_to_location_id)
                                 ship_to_country,
                             alc.meaning
                                 document_type,
                             ai.invoice_num
                                 invoice_number,
                             ai.invoice_date,
                             TO_CHAR (ai.invoice_date, 'DD/MM/YYYY')
                                 invoice_date_fmt,
                             ai.invoice_currency_code
                                 invoice_currency,
                             ai_pha.segment1
                                 po_number,
                             (SELECT mc.segment1 || '-' || mc.segment2 || '-' || mc.segment3
                                FROM po_lines_all pla, mtl_categories mc
                               WHERE     pla.po_line_id = aila.po_line_id
                                     AND mc.category_id = pla.category_id
                                     AND mc.structure_id = 201)
                                 purchasing_category,
                             (  SUM (aida.amount)
                              + (SELECT NVL (SUM (amount), 0)
                                   FROM ap_invoice_distributions_all aid, zx_rec_nrec_dist zx, gl_code_combinations gcc
                                  WHERE     zx.trx_id = aila.invoice_id
                                        AND zx.trx_line_number =
                                            aila.line_number
                                        AND aid.invoice_id = zx.trx_id
                                        AND NVL (aid.reversal_flag, 'N') = 'N'
                                        AND gcc.code_combination_id =
                                            aid.dist_code_combination_id
                                        AND gcc.segment6 IN (11901, 11902)
                                        AND aid.parent_reversal_id IS NULL
                                        AND aid.detail_tax_dist_id =
                                            rec_nrec_tax_dist_id))
                                 line_total_amt,
                             --subrtact dicount
                             SUM (aida.amount)
                                 line_net_amt,
                             -- Added Decode for CCR0009103
                             -- To get the Amount for Tax only Invoice (Where Tax Amount is Zero and line amount is charged to 11901/11092)
                             DECODE (
                                 (SELECT NVL (SUM (amount), 0)
                                    FROM ap_invoice_distributions_all aid, zx_rec_nrec_dist zx, gl_code_combinations gcc
                                   WHERE     zx.trx_id = aila.invoice_id
                                         AND zx.trx_line_number =
                                             aila.line_number
                                         AND aid.invoice_id = zx.trx_id
                                         AND NVL (aid.reversal_flag, 'N') = 'N'
                                         AND gcc.code_combination_id =
                                             aid.dist_code_combination_id
                                         AND gcc.segment6 IN (11901, 11902)
                                         AND aid.parent_reversal_id IS NULL
                                         AND aid.detail_tax_dist_id =
                                             rec_nrec_tax_dist_id),
                                 0, (SELECT SUM (amount)
                                       FROM apps.ap_invoice_distributions_all aid, gl_code_combinations gcc
                                      WHERE     aid.invoice_id =
                                                aila.invoice_id
                                            AND aid.distribution_line_number =
                                                aila.line_number
                                            AND aid.line_type_lookup_code =
                                                'ITEM'
                                            AND gcc.code_combination_id =
                                                aid.dist_code_combination_id
                                            AND gcc.segment6 IN (11901, 11902)
                                            AND aid.parent_reversal_id IS NULL),
                                 --Start Changes for 1.2
                                 /*(SELECT NVL (SUM (amount), 0)
                                    FROM ap_invoice_distributions_all aid,
                                         zx_rec_nrec_dist zx,
                                         gl_code_combinations gcc
                                   WHERE zx.trx_id = aila.invoice_id
                                     AND zx.trx_line_number = aila.line_number
                                     AND aid.invoice_id = zx.trx_id
                                     AND NVL (aid.reversal_flag, 'N') = 'N'
                                     AND gcc.code_combination_id =
                                                     aid.dist_code_combination_id
                                     AND gcc.segment6 IN (11901, 11902)
                                     AND aid.parent_reversal_id IS NULL
                                     AND aid.detail_tax_dist_id =
                                                             rec_nrec_tax_dist_id)
                                ) line_input_tax_amt, */
                                 /* (SELECT NVL (SUM (amount), 0)
                                      FROM ap_invoice_distributions_all aid,
                                           zx_rec_nrec_dist zx
                                     WHERE zx.trx_id = aila.invoice_id
                                       AND zx.trx_line_number = aila.line_number
                                       AND aid.invoice_id = zx.trx_id
                                       AND NVL (aid.reversal_flag, 'N') = 'N'
                                       AND aid.parent_reversal_id IS NULL
                                       AND aid.detail_tax_dist_id =
                                                               rec_nrec_tax_dist_id)
                                  ) line_input_tax_amt, */
                                 -- Commenetd as per CCR0010106
                                 (SELECT NVL (SUM (amount), 0)
                                    FROM ap_invoice_distributions_all aid, zx_rec_nrec_dist zx, gl_code_combinations gcc
                                   WHERE     zx.trx_id = aila.invoice_id
                                         AND zx.trx_line_number =
                                             aila.line_number
                                         AND aid.invoice_id = zx.trx_id
                                         AND NVL (aid.reversal_flag, 'N') = 'N'
                                         AND gcc.code_combination_id =
                                             aid.dist_code_combination_id
                                         AND gcc.segment6 IN (11901, 11902)
                                         AND aid.parent_reversal_id IS NULL
                                         AND aid.detail_tax_dist_id =
                                             rec_nrec_tax_dist_id))
                                 line_input_tax_amt, -- Added as per CCR0010106
                             (SELECT SUBSTR (zx.tax, 1, 2) tax_country
                                FROM ap_invoice_distributions_all aid, zx_rec_nrec_dist zx
                               WHERE     zx.trx_id = aila.invoice_id
                                     AND zx.trx_line_number = aila.line_number
                                     AND aid.invoice_id = zx.trx_id
                                     AND NVL (aid.reversal_flag, 'N') = 'N'
                                     AND aid.parent_reversal_id IS NULL
                                     AND aid.detail_tax_dist_id =
                                         rec_nrec_tax_dist_id
                                     AND ROWNUM = 1)
                                 line_tax_country,
                             /*(SELECT RTRIM
                                       (SUBSTR
                                           (zx.tax,
                                            1,
                                            LENGTH
                                               (RTRIM (TRANSLATE (zx.tax,
                                                                  '0123456789',
                                                                  '0000000000'
                                                                 ),
                                                       '0'
                                                      )
                                               )
                                           ),
                                        '_'
                                       )
                               FROM ap_invoice_distributions_all aid,
                                    zx_rec_nrec_dist zx,
                                    gl_code_combinations gcc
                              WHERE zx.trx_id = aila.invoice_id
                                AND zx.trx_line_number = aila.line_number
                                AND aid.invoice_id = zx.trx_id
                                AND NVL (aid.reversal_flag, 'N') = 'N'
                                AND gcc.code_combination_id =
                                                    aid.dist_code_combination_id
                                AND gcc.segment6 IN (11901, 11902)
                                AND aid.parent_reversal_id IS NULL
                                AND aid.detail_tax_dist_id =
                                                            rec_nrec_tax_dist_id
                                AND ROWNUM = 1) line_input_tax_code,*/
                             /*  NVL(aila.primary_intended_use,
             (SELECT RTRIM
                                         (SUBSTR
                                             (zx.tax,
                                              1,
                                              LENGTH
                                                 (RTRIM (TRANSLATE (zx.tax,
                                                                    '0123456789',
                                                                    '0000000000'
                                                                   ),
                                                         '0'
                                                        )
                                                 )
                                             ),
                                          '_'
                                         )
                                 FROM ap_invoice_distributions_all aid,
                                      zx_rec_nrec_dist zx
                                WHERE zx.trx_id = aila.invoice_id
                                  AND zx.trx_line_number = aila.line_number
                                  AND aid.invoice_id = zx.trx_id
                                  AND NVL (aid.reversal_flag, 'N') = 'N'
                                  AND aid.parent_reversal_id IS NULL
                                  AND aid.detail_tax_dist_id =
                                                              rec_nrec_tax_dist_id
                                  AND ROWNUM = 1) )line_input_tax_code, */
                             -- Commented as per CCR0010106
                             --End Changes for 1.2
                             (SELECT RTRIM (SUBSTR (zx.tax, 1, LENGTH (RTRIM (TRANSLATE (zx.tax, '0123456789', '0000000000'), '0'))), '_')
                                FROM ap_invoice_distributions_all aid, zx_rec_nrec_dist zx, gl_code_combinations gcc
                               WHERE     zx.trx_id = aila.invoice_id
                                     AND zx.trx_line_number = aila.line_number
                                     AND aid.invoice_id = zx.trx_id
                                     AND NVL (aid.reversal_flag, 'N') = 'N'
                                     AND gcc.code_combination_id =
                                         aid.dist_code_combination_id
                                     AND gcc.segment6 IN (11901, 11902)
                                     AND aid.parent_reversal_id IS NULL
                                     AND aid.detail_tax_dist_id =
                                         rec_nrec_tax_dist_id
                                     AND ROWNUM = 1)
                                 line_input_tax_code, -- Added as per CCR0010106
                             (SELECT NVL (SUM (amount), 0)
                                FROM ap_invoice_distributions_all aid, zx_rec_nrec_dist zx, gl_code_combinations gcc
                               WHERE     zx.trx_id = aila.invoice_id
                                     AND zx.trx_line_number = aila.line_number
                                     AND aid.invoice_id = zx.trx_id
                                     AND NVL (aid.reversal_flag, 'N') = 'N'
                                     AND gcc.code_combination_id =
                                         aid.dist_code_combination_id
                                     AND gcc.segment6 = 21802
                                     AND aid.parent_reversal_id IS NULL
                                     AND aid.detail_tax_dist_id =
                                         rec_nrec_tax_dist_id)
                                 line_output_tax_amt,
                             (SELECT RTRIM (SUBSTR (zx.tax, 1, LENGTH (RTRIM (TRANSLATE (zx.tax, '0123456789', '0000000000'), '0'))), '_')
                                FROM ap_invoice_distributions_all aid, zx_rec_nrec_dist zx, gl_code_combinations gcc
                               WHERE     zx.trx_id = aila.invoice_id
                                     AND zx.trx_line_number = aila.line_number
                                     AND aid.invoice_id = zx.trx_id
                                     AND gcc.code_combination_id =
                                         aid.dist_code_combination_id
                                     AND NVL (aid.reversal_flag, 'N') = 'N'
                                     AND gcc.segment6 = 21802
                                     AND aid.parent_reversal_id IS NULL
                                     AND aid.detail_tax_dist_id =
                                         rec_nrec_tax_dist_id
                                     AND ROWNUM = 1)
                                 line_output_tax_code,
                             (SELECT zx.rec_nrec_rate
                                FROM ap_invoice_distributions_all aid, zx_rec_nrec_dist zx, gl_code_combinations gcc
                               WHERE     zx.trx_id = aila.invoice_id
                                     AND zx.trx_line_number = aila.line_number
                                     AND aid.invoice_id = zx.trx_id
                                     AND NVL (aid.reversal_flag, 'N') = 'N'
                                     AND gcc.code_combination_id =
                                         aid.dist_code_combination_id
                                     AND gcc.segment6 IN (11901, 11902)
                                     AND aid.detail_tax_dist_id =
                                         rec_nrec_tax_dist_id
                                     AND aid.parent_reversal_id IS NULL
                                     AND ROWNUM = 1)
                                 line_input_tax_recoverability,
                             (SELECT zx.tax_rate
                                FROM ap_invoice_distributions_all aid, zx_rec_nrec_dist zx, gl_code_combinations gcc
                               WHERE     zx.trx_id = aila.invoice_id
                                     AND zx.trx_line_number = aila.line_number
                                     AND aid.invoice_id = zx.trx_id
                                     AND NVL (aid.reversal_flag, 'N') = 'N'
                                     AND gcc.code_combination_id =
                                         aid.dist_code_combination_id
                                     AND gcc.segment6 IN (11901, 11902)
                                     AND aid.parent_reversal_id IS NULL
                                     AND aid.detail_tax_dist_id =
                                         rec_nrec_tax_dist_id
                                     AND ROWNUM = 1)
                                 line_tax_rate,
                             NVL (ai.exchange_rate, 1)
                                 ex_rate,
                             gcc.segment3
                                 gl_geo_code,
                             --  alc.meaning nature_of_transaction,
                             gcc.segment6
                                 gl_natural_acc_code,
                             aila.accounting_date
                                 accounting_date,
                             TO_CHAR (aila.accounting_date, 'DD/MM/YYYY')
                                 accounting_date_fmt,
                             --    TRUNC (aida.creation_date) validation_date,
                             (SELECT TO_CHAR (xev.event_date, 'DD/MM/YYYY')
                                FROM xla.xla_events xev, xla.xla_ae_headers xah, xla.xla_transaction_entities xte
                               WHERE     xah.event_id = xev.event_id
                                     AND xah.je_category_name =
                                         'Purchase Invoices'
                                     AND xev.entity_id = xte.entity_id
                                     AND xah.entity_id = xte.entity_id
                                     AND xte.source_id_int_1 = ai.invoice_id
                                     AND xte.entity_code = 'AP_INVOICES'
                                     AND xev.event_type_code =
                                         'INVOICE VALIDATED'
                                     AND xah.ledger_id = hu.set_of_books_id
                                     AND ROWNUM = 1)
                                 validation_date,
                             (SELECT zx.tax_regime_code
                                FROM ap_invoice_distributions_all aid, zx_rec_nrec_dist zx, gl_code_combinations gcc
                               WHERE     zx.trx_id = aila.invoice_id
                                     AND zx.trx_line_number = aila.line_number
                                     AND aid.invoice_id = zx.trx_id
                                     AND NVL (aid.reversal_flag, 'N') = 'N'
                                     AND gcc.code_combination_id =
                                         aid.dist_code_combination_id
                                     AND gcc.segment6 IN (11901, 11902)
                                     AND aid.detail_tax_dist_id =
                                         rec_nrec_tax_dist_id
                                     AND ROWNUM = 1)
                                 tax_regime_code,
                             aila.primary_intended_use
                                 primary_intended_use,
                             ai.attribute15
                                 gapless_sequence_number -- Added for CCR0010176
                        FROM ap_invoices_all ai, ap_invoice_lines_all aila, ap_invoice_distributions_all aida,
                             hr_operating_units hu, apps.ap_suppliers aps, ap_supplier_sites_all apsa,
                             fnd_lookup_values alc, po_headers_all ai_pha, gl_code_combinations_kfv gcc,
                             xla_events xla, --Start Added for 1.2
                                             fnd_flex_value_sets ffvs, fnd_flex_values ffv
                       --End Added for 1.2
                       WHERE     ai.invoice_id = aila.invoice_id
                             --AND ai.invoice_num = '11025914'
                             AND aila.invoice_id = aida.invoice_id
                             AND aila.line_number = aida.invoice_line_number
                             AND aila.line_type_lookup_code <> 'TAX'
                             AND NVL (aila.discarded_flag, 'N') = 'N'
                             AND aida.line_type_lookup_code = 'ITEM'
                             AND hu.organization_id = ai.org_id
                             AND xla.event_id = aida.accounting_event_id
                             AND xla.event_type_code = 'INVOICE VALIDATED'
                             --Start Added for 1.2
                             --AND hu.NAME = pv_operating_unit
                             AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                             AND flex_value_set_name = 'XXD_MTD_OU_VS'
                             AND ffv.enabled_flag = 'Y'
                             AND TRUNC (SYSDATE) BETWEEN NVL (
                                                             ffv.start_date_active,
                                                             TRUNC (SYSDATE))
                                                     AND NVL (
                                                             ffv.end_date_active,
                                                             TRUNC (SYSDATE))
                             AND ffv.flex_value <> 'ALL EMEA'
                             AND hu.name = ffv.flex_value
                             AND hu.name =
                                 DECODE (pv_operating_unit,
                                         'ALL EMEA', ffv.flex_value,
                                         pv_operating_unit)
                             --End Added for 1.2
                             AND gcc.segment1 =
                                 NVL (pv_company_code, gcc.segment1)
                             AND gcc.segment6 = NVL (pv_account, gcc.segment6)
                             AND gcc.segment5 =
                                 NVL (pv_cost_center, gcc.segment5)
                             AND aila.accounting_date BETWEEN pd_gl_posted_from
                                                          AND pd_gl_posted_to
                             AND ai.invoice_date BETWEEN NVL (
                                                             pd_invoice_date_from,
                                                             ai.invoice_date)
                                                     AND NVL (
                                                             pd_invoice_date_to,
                                                             ai.invoice_date)
                             AND aps.vendor_id = ai.vendor_id
                             /* AND NVL (aida.posted_flag, 'N') =
                                     NVL (pv_posting_status,
                                          NVL (aida.posted_flag, 'N')
                                         )*/
                             AND apsa.vendor_id = aps.vendor_id
                             AND ai.vendor_site_id = apsa.vendor_site_id
                             AND alc.lookup_type = 'INVOICE TYPE'
                             AND alc.lookup_code = ai.invoice_type_lookup_code
                             AND alc.LANGUAGE = USERENV ('Lang')
                             AND aida.parent_reversal_id IS NULL
                             AND aila.po_header_id = ai_pha.po_header_id(+)
                             AND aida.dist_code_combination_id =
                                 gcc.code_combination_id
                    GROUP BY gcc.segment1, hu.NAME, aps.vendor_name,
                             aps.segment1, aps.vat_registration_num, apsa.country,
                             aila.line_number, alc.meaning, --  TRUNC (aida.creation_date),
                                                            -- aida.creation_date,
                                                            ai.invoice_num,
                             ai.invoice_date, ai.invoice_currency_code, ai_pha.segment1,
                             aila.tax_rate, NVL (ai.exchange_rate, 1), ai.exchange_rate,
                             1, gcc.segment3, gcc.segment6,
                             aila.accounting_date, aila.tax_rate, aila.ship_to_location_id,
                             ai.invoice_date, hu.set_of_books_id, aila.po_line_id,
                             aila.tax, aila.invoice_id, ai.invoice_id,
                             'AP', aila.primary_intended_use, ai.attribute15 -- Added for CCR0010176
                                                                            )
             WHERE     NVL (tax_regime_code, 'XXXX') =
                       NVL (pv_tax_regime_code,
                            NVL (tax_regime_code, 'XXXX'))
                   AND NVL (line_input_tax_code, 'XXXX') =
                       NVL (pv_tax_code, NVL (line_input_tax_code, 'XXXX'))
            UNION ALL
            SELECT transaction_type || '|' || gl_entity_code || '|' || ou_name || '|' || vendor_name || '|' || vendor_number || '|' || vendor_vat_number || '|' || vendor_site_country || '|' || ship_to_country || '|' || document_type || '|' || invoice_number || '|' || invoice_date_fmt || '|' || invoice_currency || '|' || po_number || '|' || purchasing_category || '|' || line_total_amt || '|' || line_net_amt || '|' || line_input_tax_amt || '|' --Start Added for 1.2
                                                                                                                                                                                                                                                                                                                                                                                                                                                              || line_tax_country || '|' --End Added for 1.2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         || line_input_tax_code || '|' || line_output_tax_amt || '|' || line_output_tax_code || '|' || line_input_tax_recoverability || '|' || line_tax_rate || '|' || ex_rate || '|' || gl_geo_code || '|' -- || nature_of_transaction
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            --|| '|'
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            || gl_natural_acc_code || '|' || accounting_date_fmt || '|' || validation_date || '|' || primary_intended_use --Added for CCR0009103
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          || '|' || gapless_sequence_number rep_data -- Added for CCR0010176
              FROM (  SELECT 'AP'
                                 transaction_type,
                             gcc.segment1
                                 gl_entity_code,
                             hu.NAME
                                 ou_name,
                             aps.vendor_name,
                             aps.segment1
                                 vendor_number,
                             aps.vat_registration_num
                                 vendor_vat_number,
                             -- tax_registration_number
                             apsa.country
                                 vendor_site_country,
                             aila.line_number,
                             (SELECT country
                                FROM hr_locations
                               WHERE location_id = aila.ship_to_location_id)
                                 ship_to_country,
                             alc.meaning
                                 document_type,
                             ai.invoice_num
                                 invoice_number,
                             ai.invoice_date,
                             TO_CHAR (ai.invoice_date, 'DD/MM/YYYY')
                                 invoice_date_fmt,
                             ai.invoice_currency_code
                                 invoice_currency,
                             ai_pha.segment1
                                 po_number,
                             (SELECT mc.segment1 || '-' || mc.segment2 || '-' || mc.segment3
                                FROM po_lines_all pla, mtl_categories mc
                               WHERE     pla.po_line_id = aila.po_line_id
                                     AND mc.category_id = pla.category_id
                                     AND mc.structure_id = 201)
                                 purchasing_category,
                             (  SUM (aida.amount)
                              + (SELECT NVL (SUM (amount), 0)
                                   FROM ap_invoice_distributions_all aid, zx_rec_nrec_dist zx, gl_code_combinations gcc
                                  WHERE     zx.trx_id = aila.invoice_id
                                        AND zx.trx_line_number =
                                            aila.line_number
                                        AND aid.invoice_id = zx.trx_id
                                        AND gcc.code_combination_id =
                                            aid.dist_code_combination_id
                                        AND gcc.segment6 IN (11901, 11902)
                                        AND aid.parent_reversal_id IS NOT NULL
                                        AND aid.detail_tax_dist_id =
                                            rec_nrec_tax_dist_id))
                                 line_total_amt,
                             --subrtact dicount
                             -- Added Decode for CCR0009103
                             -- To get the Amount for Tax only Invoice (Where Tax Amount is Zero and line amount is charged to 11901/11092)
                             SUM (aida.amount)
                                 line_net_amt,
                             DECODE (
                                 (SELECT NVL (SUM (amount), 0)
                                    FROM ap_invoice_distributions_all aid, zx_rec_nrec_dist zx, gl_code_combinations gcc
                                   WHERE     zx.trx_id = aila.invoice_id
                                         AND zx.trx_line_number =
                                             aila.line_number
                                         AND aid.invoice_id = zx.trx_id
                                         AND gcc.code_combination_id =
                                             aid.dist_code_combination_id
                                         AND gcc.segment6 IN (11901, 11902)
                                         AND aid.parent_reversal_id IS NOT NULL
                                         AND aid.detail_tax_dist_id =
                                             rec_nrec_tax_dist_id),
                                 0, (SELECT SUM (amount)
                                       FROM apps.ap_invoice_distributions_all aid, gl_code_combinations gcc
                                      WHERE     aid.invoice_id =
                                                aila.invoice_id
                                            AND aid.distribution_line_number =
                                                aila.line_number
                                            AND aid.line_type_lookup_code =
                                                'ITEM'
                                            AND gcc.code_combination_id =
                                                aid.dist_code_combination_id
                                            AND gcc.segment6 IN (11901, 11902)
                                            AND aid.parent_reversal_id
                                                    IS NOT NULL),
                                 --Start Changes for 1.2
                                 /*(SELECT NVL (SUM (amount), 0)
                                    FROM ap_invoice_distributions_all aid,
                                         zx_rec_nrec_dist zx,
                                         gl_code_combinations gcc
                                   WHERE zx.trx_id = aila.invoice_id
                                     AND zx.trx_line_number = aila.line_number
                                     AND aid.invoice_id = zx.trx_id
                                     AND gcc.code_combination_id =
                                                     aid.dist_code_combination_id
                                     AND gcc.segment6 IN (11901, 11902)
                                     AND aid.parent_reversal_id IS NOT NULL
                                     AND aid.detail_tax_dist_id =
                                                             rec_nrec_tax_dist_id)
             ) line_input_tax_amt, */
                                 /*  (SELECT NVL (SUM (amount), 0)
                                      FROM ap_invoice_distributions_all aid,
                                           zx_rec_nrec_dist zx
                                     WHERE zx.trx_id = aila.invoice_id
                                       AND zx.trx_line_number = aila.line_number
                                       AND aid.invoice_id = zx.trx_id
                                       AND aid.parent_reversal_id IS NOT NULL
                                       AND aid.detail_tax_dist_id =
                                                               rec_nrec_tax_dist_id)
                                  ) line_input_tax_amt, */
                                 -- Commented as per CCR0010106
                                 (SELECT NVL (SUM (amount), 0)
                                    FROM ap_invoice_distributions_all aid, zx_rec_nrec_dist zx, gl_code_combinations gcc
                                   WHERE     zx.trx_id = aila.invoice_id
                                         AND zx.trx_line_number =
                                             aila.line_number
                                         AND aid.invoice_id = zx.trx_id
                                         AND gcc.code_combination_id =
                                             aid.dist_code_combination_id
                                         AND gcc.segment6 IN (11901, 11902)
                                         AND aid.parent_reversal_id IS NOT NULL
                                         AND aid.detail_tax_dist_id =
                                             rec_nrec_tax_dist_id))
                                 line_input_tax_amt, -- Added as per CCR0010106
                             (SELECT SUBSTR (zx.tax, 1, 2) tax_country
                                FROM ap_invoice_distributions_all aid, zx_rec_nrec_dist zx
                               WHERE     zx.trx_id = aila.invoice_id
                                     AND zx.trx_line_number = aila.line_number
                                     AND aid.invoice_id = zx.trx_id
                                     AND aid.parent_reversal_id IS NOT NULL
                                     AND aid.detail_tax_dist_id =
                                         rec_nrec_tax_dist_id
                                     AND ROWNUM = 1)
                                 line_tax_country,
                             /*(SELECT RTRIM
                                      (SUBSTR
                                          (zx.tax,
                                           1,
                                           LENGTH
                                              (RTRIM (TRANSLATE (zx.tax,
                                                                 '0123456789',
                                                                 '0000000000'
                                                                ),
                                                      '0'
                                                     )
                                              )
                                          ),
                                       '_'
                                      )
                              FROM ap_invoice_distributions_all aid,
                                   zx_rec_nrec_dist zx,
                                   gl_code_combinations gcc
                             WHERE zx.trx_id = aila.invoice_id
                               AND zx.trx_line_number = aila.line_number
                               AND aid.invoice_id = zx.trx_id
                               AND gcc.code_combination_id =
                                                   aid.dist_code_combination_id
                               AND gcc.segment6 IN (11901, 11902)
                               AND aid.parent_reversal_id IS NOT NULL
                               AND aid.detail_tax_dist_id =
                                                           rec_nrec_tax_dist_id
                               AND ROWNUM = 1) line_input_tax_code,  */
                             /*  NVL(aila.primary_intended_use,
                               (SELECT RTRIM
                                          (SUBSTR
                                              (zx.tax,
                                               1,
                                               LENGTH
                                                  (RTRIM (TRANSLATE (zx.tax,
                                                                     '0123456789',
                                                                     '0000000000'
                                                                    ),
                                                          '0'
                                                         )
                                                  )
                                              ),
                                           '_'
                                          )
                                  FROM ap_invoice_distributions_all aid,
                                       zx_rec_nrec_dist zx
                                 WHERE zx.trx_id = aila.invoice_id
                                   AND zx.trx_line_number = aila.line_number
                                   AND aid.invoice_id = zx.trx_id
                                   AND aid.parent_reversal_id IS NOT NULL
                                   AND aid.detail_tax_dist_id =
                                                               rec_nrec_tax_dist_id
                                   AND ROWNUM = 1) )line_input_tax_code,  */
                             -- Commenetd as per CCR0010106
                             --End Changes for 1.2
                             (SELECT RTRIM (SUBSTR (zx.tax, 1, LENGTH (RTRIM (TRANSLATE (zx.tax, '0123456789', '0000000000'), '0'))), '_')
                                FROM ap_invoice_distributions_all aid, zx_rec_nrec_dist zx, gl_code_combinations gcc
                               WHERE     zx.trx_id = aila.invoice_id
                                     AND zx.trx_line_number = aila.line_number
                                     AND aid.invoice_id = zx.trx_id
                                     AND gcc.code_combination_id =
                                         aid.dist_code_combination_id
                                     AND gcc.segment6 IN (11901, 11902)
                                     AND aid.parent_reversal_id IS NOT NULL
                                     AND aid.detail_tax_dist_id =
                                         rec_nrec_tax_dist_id
                                     AND ROWNUM = 1)
                                 line_input_tax_code, -- Added as per CCR0010106
                             (SELECT NVL (SUM (amount), 0)
                                FROM ap_invoice_distributions_all aid, zx_rec_nrec_dist zx, gl_code_combinations gcc
                               WHERE     zx.trx_id = aila.invoice_id
                                     AND zx.trx_line_number = aila.line_number
                                     AND aid.invoice_id = zx.trx_id
                                     AND gcc.code_combination_id =
                                         aid.dist_code_combination_id
                                     AND gcc.segment6 = 21802
                                     AND aid.parent_reversal_id IS NOT NULL
                                     AND aid.detail_tax_dist_id =
                                         rec_nrec_tax_dist_id)
                                 line_output_tax_amt,
                             (SELECT RTRIM (SUBSTR (zx.tax, 1, LENGTH (RTRIM (TRANSLATE (zx.tax, '0123456789', '0000000000'), '0'))), '_')
                                FROM ap_invoice_distributions_all aid, zx_rec_nrec_dist zx, gl_code_combinations gcc
                               WHERE     zx.trx_id = aila.invoice_id
                                     AND zx.trx_line_number = aila.line_number
                                     AND aid.invoice_id = zx.trx_id
                                     AND gcc.code_combination_id =
                                         aid.dist_code_combination_id
                                     AND gcc.segment6 = 21802
                                     AND aid.parent_reversal_id IS NOT NULL
                                     AND aid.detail_tax_dist_id =
                                         rec_nrec_tax_dist_id
                                     AND ROWNUM = 1)
                                 line_output_tax_code,
                             (SELECT zx.rec_nrec_rate
                                FROM ap_invoice_distributions_all aid, zx_rec_nrec_dist zx, gl_code_combinations gcc
                               WHERE     zx.trx_id = aila.invoice_id
                                     AND zx.trx_line_number = aila.line_number
                                     AND aid.invoice_id = zx.trx_id
                                     AND gcc.code_combination_id =
                                         aid.dist_code_combination_id
                                     AND gcc.segment6 IN (11901, 11902)
                                     AND aid.parent_reversal_id IS NOT NULL
                                     AND aid.detail_tax_dist_id =
                                         rec_nrec_tax_dist_id
                                     AND ROWNUM = 1)
                                 line_input_tax_recoverability,
                             (SELECT zx.tax_rate
                                FROM ap_invoice_distributions_all aid, zx_rec_nrec_dist zx, gl_code_combinations gcc
                               WHERE     zx.trx_id = aila.invoice_id
                                     AND zx.trx_line_number = aila.line_number
                                     AND aid.invoice_id = zx.trx_id
                                     AND gcc.code_combination_id =
                                         aid.dist_code_combination_id
                                     AND gcc.segment6 IN (11901, 11902)
                                     AND aid.parent_reversal_id IS NOT NULL
                                     AND aid.detail_tax_dist_id =
                                         rec_nrec_tax_dist_id
                                     AND ROWNUM = 1)
                                 line_tax_rate,
                             NVL (ai.exchange_rate, 1)
                                 ex_rate,
                             gcc.segment3
                                 gl_geo_code,
                             --  alc.meaning nature_of_transaction,
                             gcc.segment6
                                 gl_natural_acc_code,
                             --aila.accounting_date accounting_date,
                             xla.event_date
                                 accounting_date,
                             TO_CHAR (aila.accounting_date, 'DD/MM/YYYY')
                                 accounting_date_fmt,
                             --    TRUNC (aida.creation_date) validation_date,
                             (SELECT TO_CHAR (xev.event_date, 'DD/MM/YYYY')
                                FROM xla.xla_events xev, xla.xla_ae_headers xah, xla.xla_transaction_entities xte
                               WHERE     xah.event_id = xev.event_id
                                     AND xah.je_category_name =
                                         'Purchase Invoices'
                                     AND xev.entity_id = xte.entity_id
                                     AND xah.entity_id = xte.entity_id
                                     AND xte.source_id_int_1 = ai.invoice_id
                                     AND xte.entity_code = 'AP_INVOICES'
                                     AND xev.event_type_code =
                                         'INVOICE VALIDATED'
                                     AND xah.ledger_id = hu.set_of_books_id
                                     AND ROWNUM = 1)
                                 validation_date,
                             (SELECT zx.tax_regime_code
                                FROM ap_invoice_distributions_all aid, zx_rec_nrec_dist zx, gl_code_combinations gcc
                               WHERE     zx.trx_id = aila.invoice_id
                                     AND zx.trx_line_number = aila.line_number
                                     AND aid.invoice_id = zx.trx_id
                                     AND gcc.code_combination_id =
                                         aid.dist_code_combination_id
                                     AND gcc.segment6 IN (11901, 11902)
                                     AND aid.detail_tax_dist_id =
                                         rec_nrec_tax_dist_id
                                     AND ROWNUM = 1)
                                 tax_regime_code,
                             aila.primary_intended_use
                                 primary_intended_use,  --Added for CCR0009103
                             ai.attribute15
                                 gapless_sequence_number -- Added for CCR0010176
                        FROM ap_invoices_all ai, ap_invoice_lines_all aila, ap_invoice_distributions_all aida,
                             hr_operating_units hu, apps.ap_suppliers aps, ap_supplier_sites_all apsa,
                             fnd_lookup_values alc, po_headers_all ai_pha, gl_code_combinations_kfv gcc,
                             xla_events xla, --Start Added for 1.2
                                             fnd_flex_value_sets ffvs, fnd_flex_values ffv
                       --End Added for 1.2
                       WHERE     ai.invoice_id = aila.invoice_id
                             AND aila.invoice_id = aida.invoice_id
                             AND aila.line_number = aida.invoice_line_number
                             AND aila.line_type_lookup_code <> 'TAX'
                             AND aida.line_type_lookup_code = 'ITEM'
                             AND hu.organization_id = ai.org_id
                             AND xla.event_id = aida.accounting_event_id
                             AND xla.event_type_code = 'INVOICE CANCELLED'
                             --Start Added for 1.2
                             --AND hu.NAME = pv_operating_unit
                             AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                             AND flex_value_set_name = 'XXD_MTD_OU_VS'
                             AND ffv.enabled_flag = 'Y'
                             AND TRUNC (SYSDATE) BETWEEN NVL (
                                                             ffv.start_date_active,
                                                             TRUNC (SYSDATE))
                                                     AND NVL (
                                                             ffv.end_date_active,
                                                             TRUNC (SYSDATE))
                             AND ffv.flex_value <> 'ALL EMEA'
                             AND hu.name = ffv.flex_value
                             AND hu.name =
                                 DECODE (pv_operating_unit,
                                         'ALL EMEA', ffv.flex_value,
                                         pv_operating_unit)
                             --End Added for 1.2
                             AND gcc.segment1 =
                                 NVL (pv_company_code, gcc.segment1)
                             AND gcc.segment6 = NVL (pv_account, gcc.segment6)
                             AND gcc.segment5 =
                                 NVL (pv_cost_center, gcc.segment5)
                             AND xla.event_date BETWEEN pd_gl_posted_from
                                                    AND pd_gl_posted_to
                             AND ai.invoice_date BETWEEN NVL (
                                                             pd_invoice_date_from,
                                                             ai.invoice_date)
                                                     AND NVL (
                                                             pd_invoice_date_to,
                                                             ai.invoice_date)
                             AND aps.vendor_id = ai.vendor_id
                             /* AND NVL (aida.posted_flag, 'N') =
                                     NVL (pv_posting_status,
                                          NVL (aida.posted_flag, 'N')
                                         )*/
                             AND apsa.vendor_id = aps.vendor_id
                             --AND ai.invoice_num = '11025914'
                             AND ai.vendor_site_id = apsa.vendor_site_id
                             AND alc.lookup_type = 'INVOICE TYPE'
                             AND alc.lookup_code = ai.invoice_type_lookup_code
                             AND alc.LANGUAGE = USERENV ('Lang')
                             AND aida.parent_reversal_id IS NOT NULL
                             AND aila.po_header_id = ai_pha.po_header_id(+)
                             AND aida.dist_code_combination_id =
                                 gcc.code_combination_id
                    GROUP BY gcc.segment1, hu.NAME, aps.vendor_name,
                             aps.segment1, aps.vat_registration_num, apsa.country,
                             aila.line_number, alc.meaning, --  TRUNC (aida.creation_date),
                                                            --  aida.creation_date,
                                                            ai.invoice_num,
                             ai.invoice_date, ai.invoice_currency_code, ai_pha.segment1,
                             aila.tax_rate, NVL (ai.exchange_rate, 1), ai.exchange_rate,
                             1, gcc.segment3, gcc.segment6,
                             aila.tax_rate, aila.ship_to_location_id, ai.invoice_date,
                             'DD/MM/YYYY', hu.set_of_books_id, aila.accounting_date,
                             'DD/MM/YYYY', aila.po_line_id, aila.tax,
                             aila.invoice_id, ai.invoice_id, 'AP',
                             xla.event_date, aila.primary_intended_use, --Added for CCR0009103
                                                                        ai.attribute15) -- Added for CCR0010176
             WHERE     NVL (tax_regime_code, 'XXXX') =
                       NVL (pv_tax_regime_code,
                            NVL (tax_regime_code, 'XXXX'))
                   AND NVL (line_input_tax_code, 'XXXX') =
                       NVL (pv_tax_code, NVL (line_input_tax_code, 'XXXX'));

        TYPE fetch_data IS TABLE OF ap_rep_cur%ROWTYPE;

        fetch_cur_data         fetch_data;
        v_header               VARCHAR2 (2000);
        lv_line                VARCHAR2 (4000);
        ln_cnt                 NUMBER := 0;
        lv_err_msg             VARCHAR2 (4000);
    BEGIN
        IF pv_final_mode = 'N'
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   'TRANSACTION_TYPE'
                || '|'
                || 'GL_ENTITY_CODE'
                || '|'
                || 'OU_NAME'
                || '|'
                || 'VENDOR_NAME'
                || '|'
                || 'VENDOR_NUMBER'
                || '|'
                || 'VENDOR_VAT_NUMBER'
                || '|'
                || 'VENDOR_SITE_COUNTRY'
                || '|'
                || 'SHIP_TO_COUNTRY'
                || '|'
                || 'DOCUMENT_TYPE'
                || '|'
                || 'INVOICE_NUMBER'
                || '|'
                || 'INVOICE_DATE'
                || '|'
                || 'INVOICE_CURRENCY'
                || '|'
                || 'PO_NUMBER'
                || '|'
                || 'PURCHASING_CATEGORY'
                || '|'
                || 'LINE_TOTAL_AMT'
                || '|'
                || 'LINE_NET_AMT'
                || '|'
                || 'LINE_INPUT_TAX_AMT'
                || '|'
                --Start Added for 1.2
                || 'TAX_COUNTRY'
                || '|'
                --End Added for 1.2
                || 'LINE_INPUT_TAX_CODE'
                || '|'
                || 'LINE_OUTPUT_TAX_AMT'
                || '|'
                || 'LINE_OUTPUT_TAX_CODE'
                || '|'
                || 'LINE_INPUT_TAX_RECOVERABILITY'
                || '|'
                || 'LINE_TAX_RATE'
                || '|'
                || 'EX_RATE'
                || '|'
                || 'GL_GEO_CODE'
                || '|'
                --   || 'NATURE_OF_TRANSACTION'
                -- || '|'
                || 'GL_NATURAL_ACC_CODE'
                || '|'
                || 'ACCOUNTING _DATE'
                || '|'
                || 'VALIDATION_DATE'
                || '|'
                || 'PRIMARY_INTENDED_USE'               --Added for CCR0009103
                || '|'
                || 'GAPLESS_SEQUENCE_NUMBER'           -- Added for CCR0010176
                                            );

            /*OPEN ap_rep_cur;

            LOOP
               FETCH ap_rep_cur
               BULK COLLECT INTO fetch_cur_data LIMIT 10000;*/
            FOR i IN ap_rep_cur
            LOOP
                apps.fnd_file.put_line (apps.fnd_file.output, i.rep_data);
            END LOOP;
        -- END LOOP;
        END IF;

        IF pv_final_mode = 'Y'
        THEN
            BEGIN
                v_header   :=
                       'TRANSACTION_TYPE'
                    || '|'
                    || 'GL_ENTITY_CODE'
                    || '|'
                    || 'OU_NAME'
                    || '|'
                    || 'VENDOR_NAME'
                    || '|'
                    || 'VENDOR_NUMBER'
                    || '|'
                    || 'VENDOR_VAT_NUMBER'
                    || '|'
                    || 'VENDOR_SITE_COUNTRY'
                    || '|'
                    || 'SHIP_TO_COUNTRY'
                    || '|'
                    || 'DOCUMENT_TYPE'
                    || '|'
                    || 'INVOICE_NUMBER'
                    || '|'
                    || 'INVOICE_DATE'
                    || '|'
                    || 'INVOICE_CURRENCY'
                    || '|'
                    || 'PO_NUMBER'
                    || '|'
                    || 'PURCHASING_CATEGORY'
                    || '|'
                    || 'LINE_TOTAL_AMT'
                    || '|'
                    || 'LINE_NET_AMT'
                    || '|'
                    || 'LINE_INPUT_TAX_AMT'
                    || '|'
                    --Start Added for 1.2
                    || 'TAX_COUNTRY'
                    || '|'
                    --End Added for 1.2
                    || 'LINE_INPUT_TAX_CODE'
                    || '|'
                    || 'LINE_OUTPUT_TAX_AMT'
                    || '|'
                    || 'LINE_OUTPUT_TAX_CODE'
                    || '|'
                    || 'LINE_INPUT_TAX_RECOVERABILITY'
                    || '|'
                    || 'LINE_TAX_RATE'
                    || '|'
                    || 'EX_RATE'
                    || '|'
                    || 'GL_GEO_CODE'
                    || '|'
                    --     || 'NATURE_OF_TRANSACTION'
                    --   || '|'
                    || 'GL_NATURAL_ACC_CODE'
                    || '|'
                    || 'ACCOUNTING _DATE'
                    || '|'
                    || 'VALIDATION_DATE'
                    || '|'
                    || 'PRIMARY_INTENDED_USE'           --Added for CCR0009103
                    || '|'
                    || 'GAPLESS_SEQUENCE_NUMBER';      -- Added for CCR0010176

                lv_output_file   :=
                    UTL_FILE.fopen (pv_directory_name, lv_outbound_file, 'W' --opening the file in write mode
                                                                            );

                IF UTL_FILE.is_open (lv_output_file)
                THEN
                    UTL_FILE.put_line (lv_output_file, v_header);

                    FOR ap_rep IN ap_rep_cur
                    LOOP
                        lv_line   := ap_rep.rep_data;
                        UTL_FILE.put_line (lv_output_file, lv_line);
                        ln_cnt    := ln_cnt + 1;
                    END LOOP;
                ELSE
                    lv_err_msg   :=
                        SUBSTR (
                               'Error in Opening the AP_VAT_EMEA_Report file for writing. Error is : '
                            || SQLERRM,
                            1,
                            2000);
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    -- pn_retcode := gn_error;
                    RETURN;
                END IF;

                UTL_FILE.fclose (lv_output_file);
            EXCEPTION
                WHEN UTL_FILE.invalid_path
                THEN
                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        UTL_FILE.fclose (lv_output_file);
                    END IF;

                    lv_err_msg   :=
                        'INVALID_PATH: File location or filename was invalid.';
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    -- lv_status:='E';
                    raise_application_error (-20001, lv_err_msg);
                WHEN UTL_FILE.invalid_mode
                THEN
                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        UTL_FILE.fclose (lv_output_file);
                    END IF;

                    lv_err_msg   :=
                        'INVALID_MODE: The open_mode parameter in FOPEN was invalid.';
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    -- lv_status:='E';
                    raise_application_error (-20002, lv_err_msg);
                WHEN UTL_FILE.invalid_filehandle
                THEN
                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        UTL_FILE.fclose (lv_output_file);
                    END IF;

                    lv_err_msg   :=
                        'INVALID_FILEHANDLE: The file handle was invalid.';
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    --lv_status:='E';
                    raise_application_error (-20003, lv_err_msg);
                WHEN UTL_FILE.invalid_operation
                THEN
                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        UTL_FILE.fclose (lv_output_file);
                    END IF;

                    lv_err_msg   :=
                        'INVALID_OPERATION: The file could not be opened or operated on as requested.';
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    -- lv_status:='E';
                    raise_application_error (-20004, lv_err_msg);
                WHEN UTL_FILE.read_error
                THEN
                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        UTL_FILE.fclose (lv_output_file);
                    END IF;

                    lv_err_msg   :=
                        'READ_ERROR: An operating system error occurred during the read operation.';
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    --  lv_status:='E';
                    raise_application_error (-20005, lv_err_msg);
                WHEN UTL_FILE.write_error
                THEN
                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        UTL_FILE.fclose (lv_output_file);
                    END IF;

                    lv_err_msg   :=
                        'WRITE_ERROR: An operating system error occurred during the write operation.';
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    --    lv_status:='E';
                    raise_application_error (-20006, lv_err_msg);
                WHEN UTL_FILE.internal_error
                THEN
                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        UTL_FILE.fclose (lv_output_file);
                    END IF;

                    lv_err_msg   :=
                        'INTERNAL_ERROR: An unspecified error in PL/SQL.';
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    --  lv_status:='E';
                    raise_application_error (-20007, lv_err_msg);
                WHEN UTL_FILE.invalid_filename
                THEN
                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        UTL_FILE.fclose (lv_output_file);
                    END IF;

                    lv_err_msg   :=
                        'INVALID_FILENAME: The filename parameter is invalid.';
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    --    lv_status:='E';
                    raise_application_error (-20008, lv_err_msg);
                WHEN OTHERS
                THEN
                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        UTL_FILE.fclose (lv_output_file);
                    END IF;

                    lv_err_msg   :=
                        'Error while creating or writing the data into the file.';
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    --  lv_status:='E';
                    raise_application_error (-20009, lv_err_msg);
            END;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Exception While Printing MTD AP Report' || SQLERRM);
    END mtd_ap_rep;
END xxd_ap_mtd_report_pkg;
/


GRANT EXECUTE ON APPS.XXD_AP_MTD_REPORT_PKG TO LKAKLOORI
/
