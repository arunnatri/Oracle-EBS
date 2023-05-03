--
-- XXDO_AP_INVOICE_HOLD_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:33 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_AP_INVOICE_HOLD_PKG"
AS
    /*********************************************************************************************
    **
    NAME:       XXDO_AP_INVOICE_HOLD_PKG
    PURPOSE:    This package contains procedures for Invoice Hold Extract
    REVISIONS:
    Ver        Date            Author                      Description
    ---------  ----------     ---------------           -----------------------------------------
    1.0        10/11/2016      Infosys                  1. Created this package.
    1.1        10-Aug-2018     Viswanathan Pandian      Updated for CCR0007172
    1.2        27-Oct-2020     Viswanathan Pandian      Updated for MTD Project CCR0008507
    1.3        04-Feb-2021     Srinath Siricilla/       Updated for CCR0009257
                               Viswanathan Pandian
    *********************************************************************************************/
    --Global Varialble
    -- Start commenting for CCR0009257
    --g_num_org_id    NUMBER;
    --g_num_resp_id   NUMBER;
    -- End commenting for CCR0009257

    PROCEDURE main (p_out_var_errbuf       OUT VARCHAR2,
                    p_out_var_retcode      OUT NUMBER,
                    -- Start of Change for CCR0009257
                    p_region            IN     VARCHAR2,
                    p_org_id            IN     NUMBER,
                    p_hold_name         IN     VARCHAR2,
                    p_tax_holds_only    IN     VARCHAR2)
    -- End of Change for CCR0009257
    AS
        --Cursor to fetch the invoices on hold
        CURSOR c_inv_hold IS
              SELECT aha.hold_lookup_code
                         hold_name,
                     aba.batch_name,
                     hou.name,
                     pv.vendor_name,
                     aia.invoice_num,
                     aia.invoice_date,
                     aia.invoice_amount,
                     aia.creation_date
                         invoice_creation_date,
                     apsa.due_date,
                     (SELECT MAX (xla.creation_date)
                        FROM ap_invoice_distributions_all aida, xla_events xla, xla.xla_transaction_entities xte,
                             fnd_application fa
                       WHERE     aida.accounting_event_id = xla.event_id
                             AND xte.application_id = fa.application_id
                             AND xte.application_id = xla.application_id
                             AND xte.entity_code = 'AP_INVOICES'
                             AND fa.application_short_name = 'SQLAP'
                             AND xte.source_id_int_1 = aida.invoice_id
                             AND aida.invoice_id = aia.invoice_id)
                         validation_date,
                     'Needs Revalidation'
                         approval_status,
                     att.name
                         terms_name,
                     pha.segment1,
                     (SELECT papf.full_name
                        FROM per_all_people_f papf, po_distributions_all pda, ap_invoice_distributions_all apda,
                             po_headers_all pha1
                       WHERE     apda.invoice_id = aia.invoice_id
                             AND apda.po_distribution_id =
                                 pda.po_distribution_id
                             AND papf.person_id = pda.deliver_to_person_id
                             AND pha1.segment1 = pha.segment1
                             AND ROWNUM = 1)
                         AS requestor,
                     (SELECT DISTINCT papf.full_name
                        FROM ap_invoice_distributions_all aida, po_distributions_all pda, po_req_distributions_all prda,
                             po_requisition_lines_all prla, po_requisition_headers_all prha, per_all_people_f papf,
                             po_headers_all pha2
                       WHERE     aida.po_distribution_id =
                                 pda.po_distribution_id
                             AND aida.invoice_id = aia.invoice_id
                             AND pda.req_distribution_id = prda.distribution_id
                             AND prda.requisition_line_id =
                                 prla.requisition_line_id
                             AND prha.requisition_header_id =
                                 prla.requisition_header_id
                             AND prha.preparer_id = papf.person_id
                             AND pha2.po_header_id = pda.po_header_id
                             AND pha2.segment1 = pha.segment1
                             AND SYSDATE BETWEEN NVL (
                                                     papf.effective_start_date,
                                                     SYSDATE)
                                             AND NVL (papf.effective_end_date,
                                                      SYSDATE))
                         preparer,
                     -- Start changes for 1.1
                     -- aia.description,
                     REPLACE (aia.description, CHR (9), '')
                         description,
                     -- End changes for 1.1
                     SUM (pll.quantity_billed)
                         quantity_billed,
                     SUM (pll.quantity_received)
                         quantity_received,
                     NVL (TO_CHAR (aia.doc_sequence_value), aia.voucher_num)
                         voucher_number,
                     DECODE (aia.invoice_currency_code,
                             gll.currency_code, aia.invoice_amount,
                             aia.base_amount)
                         orginal_amount,
                     (SELECT SUM (DECODE (aia.payment_currency_code, gll.currency_code, apsa.amount_remaining, DECODE (fcv.minimum_accountable_unit, NULL, ROUND (((DECODE (aia.payment_cross_rate_type, 'EMU FIXED', 1 / aia.payment_cross_rate, aia.exchange_rate)) * NVL (apsa.amount_remaining, 0)), fcv.precision), ROUND (((DECODE (aia.payment_cross_rate_type, 'EMU FIXED', 1 / aia.payment_cross_rate, aia.exchange_rate)) * NVL (apsa.amount_remaining, 0)) / fcv.minimum_accountable_unit) * fcv.minimum_accountable_unit)))
                        FROM ap_payment_schedules_all s1
                       WHERE s1.invoice_id(+) = aia.invoice_id)
                         amount_remaining,
                     -- Start changes for 1.1
                     DECODE (
                         ap_invoices_utility_pkg.get_posting_status (
                             aia.invoice_id),
                         'Y', 'Yes',
                         'No')
                         accounting_status,
                     (SELECT DECODE (COUNT (1), 0, NULL, 'Resent for Tax hold approval due to Invoice Changes') comments
                        FROM ap_holds_all aha_tax
                       WHERE     aha_tax.invoice_id = aia.invoice_id
                             AND aha_tax.release_lookup_code IS NOT NULL
                             AND EXISTS
                                     (SELECT 1
                                        FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
                                       WHERE     ffvs.flex_value_set_name =
                                                 'XXD_AP_INVOICE_VERTEX_HOLDS'
                                             AND ffvs.flex_value_set_id =
                                                 ffv.flex_value_set_id
                                             AND ffv.enabled_flag = 'Y'
                                             AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                             ffv.start_date_active,
                                                                             TRUNC (
                                                                                 SYSDATE))
                                                                     AND NVL (
                                                                             ffv.end_date_active,
                                                                             TRUNC (
                                                                                 SYSDATE))
                                             AND aha_tax.hold_lookup_code =
                                                 ffv.flex_value
                                             AND ffv.flex_value =
                                                 aha.hold_lookup_code))
                         comments,
                     -- End changes for 1.1
                     -- Start of Change for CCR0009257
                     NVL (
                         (SELECT 'Y'
                            FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
                           WHERE     ffvs.flex_value_set_id =
                                     ffv.flex_value_set_id
                                 AND ffv.enabled_flag = 'Y'
                                 AND TRUNC (NVL (end_date_active, SYSDATE)) >=
                                     TRUNC (SYSDATE)
                                 AND ffvs.flex_value_set_name = 'XXD_MTD_OU_VS'
                                 AND ffv.flex_value = hou.name),
                         'N')
                         mtd_ou_flag,
                     pha.po_header_id,
                     aia.invoice_id,
                     (SELECT vat_registration_num
                        FROM ap_supplier_sites_all apsa
                       WHERE apsa.vendor_site_id = aia.vendor_site_id)
                         vat_num,
                     -- End of Change for CCR0009257
                     -- Start changes for 1.2
                     NVL (MIN (aia.attribute1), 0)
                         vendor_charged_tax,
                     NVL (
                         (SELECT SUM (aila.amount)
                            FROM ap_invoice_lines_all aila
                           WHERE     aila.invoice_id = aia.invoice_id
                                 AND aila.line_type_lookup_code = 'TAX'),
                         0)
                         onesource_calculated_tax_amt
                -- End changes for 1.2
                FROM hz_parties hp, ap_invoices_all aia, ap_holds_all aha,
                     ap_suppliers pv, ap_terms att, ap_batches_all aba,
                     hr_operating_units hou, ap_payment_schedules_all apsa, fnd_currencies_vl fcv,
                     po_line_locations_all pll, po_headers_all pha, gl_ledgers gll
               WHERE     hp.party_id = aia.party_id
                     AND aia.invoice_id = aha.invoice_id
                     AND aia.org_id = aha.org_id
                     AND aha.release_lookup_code IS NULL
                     AND apsa.invoice_id(+) = aia.invoice_id
                     AND apsa.org_id(+) = aia.org_id
                     AND pv.vendor_id(+) = aia.vendor_id
                     AND att.term_id = aia.terms_id
                     AND aba.batch_id(+) = aia.batch_id
                     AND hou.organization_id = aia.org_id
                     AND gll.currency_code = fcv.currency_code
                     AND gll.ledger_id = hou.set_of_books_id
                     AND pll.line_location_id(+) = aha.line_location_id
                     AND pha.po_header_id(+) = pll.po_header_id
                     -- Start of Change for CCR0009257
                     --AND hou.organization_id =
                     --    NVL (g_num_org_id, hou.organization_id)
                     -- Region and OU
                     AND (   (    p_region IS NOT NULL
                              AND p_region <> 'All'
                              AND EXISTS
                                      (SELECT 1
                                         FROM fnd_flex_values ffv1, fnd_flex_value_sets ffvs1, fnd_flex_values ffv2,
                                              fnd_flex_value_sets ffvs2
                                        WHERE     1 = 1
                                              AND ffv1.flex_value_set_id =
                                                  ffvs1.flex_value_set_id
                                              AND ffvs1.flex_value_set_name =
                                                  'XXDO_REGION_OU_MAPPING'
                                              AND ffv1.enabled_flag = 'Y'
                                              AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                              NVL (
                                                                                  ffv1.start_date_active,
                                                                                  SYSDATE))
                                                                      AND TRUNC (
                                                                              NVL (
                                                                                  ffv1.end_date_active,
                                                                                  SYSDATE))
                                              AND ffvs2.flex_value_set_name =
                                                  'XXDO_REGION_NAME'
                                              AND ffv2.flex_value_set_id =
                                                  ffvs2.flex_value_set_id
                                              AND ffv2.enabled_flag = 'Y'
                                              AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                              NVL (
                                                                                  ffv2.start_date_active,
                                                                                  SYSDATE))
                                                                      AND TRUNC (
                                                                              NVL (
                                                                                  ffv2.end_date_active,
                                                                                  SYSDATE))
                                              AND ffv1.parent_flex_value_low =
                                                  ffv2.flex_value
                                              AND ffv2.flex_value = p_region
                                              AND hou.organization_id =
                                                  TO_NUMBER (ffv1.flex_value)
                                              AND ((p_org_id IS NOT NULL AND hou.organization_id = p_org_id) OR (p_org_id IS NULL AND 1 = 1))))
                          OR ((p_region IS NULL OR p_region = 'All') AND 1 = 1))
                     -- Hold Name
                     AND ((p_hold_name IS NOT NULL AND aha.hold_lookup_code = p_hold_name) OR (p_hold_name IS NULL AND 1 = 1))
                     -- Tax Holds Only
                     AND (   (    p_tax_holds_only IS NOT NULL
                              AND p_tax_holds_only = 'Y'
                              AND 'Y' =
                                  CASE
                                      WHEN (SELECT COUNT (1)
                                              FROM ap_holds_all aha_tax
                                             WHERE     aha_tax.invoice_id =
                                                       aia.invoice_id
                                                   AND aha_tax.release_lookup_code
                                                           IS NULL
                                                   AND NOT EXISTS
                                                           (SELECT 1
                                                              FROM fnd_flex_values ffv, fnd_flex_value_sets ffvs
                                                             WHERE     1 = 1
                                                                   AND ffv.flex_value_set_id =
                                                                       ffvs.flex_value_set_id
                                                                   AND ffvs.flex_value_set_name =
                                                                       'XXDO_TAX_HOLD_LISTING'
                                                                   AND ffv.enabled_flag =
                                                                       'Y'
                                                                   AND TRUNC (
                                                                           SYSDATE) BETWEEN TRUNC (
                                                                                                NVL (
                                                                                                    ffv.start_date_active,
                                                                                                    SYSDATE))
                                                                                        AND TRUNC (
                                                                                                NVL (
                                                                                                    ffv.end_date_active,
                                                                                                    SYSDATE))
                                                                   AND aha_tax.hold_lookup_code =
                                                                       ffv.flex_value)) =
                                           0
                                      THEN
                                          'Y'
                                      ELSE
                                          'N'
                                  END)
                          OR ((p_tax_holds_only IS NULL OR p_tax_holds_only = 'N') AND 1 = 1))
            -- End of Change for CCR0009257
            GROUP BY aha.hold_lookup_code, aba.batch_name, hou.name,
                     pv.vendor_name, aia.invoice_id, aia.invoice_num,
                     aia.invoice_date, aia.invoice_amount, aia.creation_date,
                     apsa.due_date, att.name, pha.segment1,
                     -- Start of Change for CCR0009257
                     pha.po_header_id, aia.vendor_site_id, -- End of Change for CCR0009257
                                                           aia.description,
                     NVL (TO_CHAR (aia.doc_sequence_value), aia.voucher_num), DECODE (aia.invoice_currency_code, gll.currency_code, aia.invoice_amount, aia.base_amount), aia.payment_currency_code,
                     gll.currency_code, apsa.amount_remaining, fcv.minimum_accountable_unit,
                     aia.payment_cross_rate_type, aia.payment_cross_rate, aia.exchange_rate,
                     fcv.precision
            UNION
              SELECT 'PAYMENT HOLD'
                         hold_name,
                     aba.batch_name,
                     hou.name,
                     pv.vendor_name,
                     aia.invoice_num,
                     aia.invoice_date,
                     aia.invoice_amount,
                     aia.creation_date
                         invoice_creation_date,
                     apsa.due_date,
                     (SELECT MAX (xla.creation_date)
                        FROM ap_invoice_distributions_all aida, xla_events xla, xla.xla_transaction_entities xte,
                             fnd_application fa
                       WHERE     aida.accounting_event_id = xla.event_id
                             AND xte.application_id = fa.application_id
                             AND xte.application_id = xla.application_id
                             AND xte.entity_code = 'AP_INVOICES'
                             AND fa.application_short_name = 'SQLAP'
                             AND xte.source_id_int_1 = aida.invoice_id
                             AND aida.invoice_id = aia.invoice_id)
                         validation_date,
                     'Needs Revalidation'
                         approval_status,
                     att.name
                         terms_name,
                     pha.segment1,
                     (SELECT papf.full_name
                        FROM per_all_people_f papf, po_distributions_all pda, ap_invoice_distributions_all apda,
                             po_headers_all pha1
                       WHERE     apda.invoice_id = aia.invoice_id
                             AND apda.po_distribution_id =
                                 pda.po_distribution_id
                             AND papf.person_id = pda.deliver_to_person_id
                             AND pha1.segment1 = pha.segment1
                             AND ROWNUM = 1)
                         AS requestor,
                     (SELECT DISTINCT papf.full_name
                        FROM ap_invoice_distributions_all aida, po_distributions_all pda, po_req_distributions_all prda,
                             po_requisition_lines_all prla, po_requisition_headers_all prha, per_all_people_f papf,
                             po_headers_all pha2
                       WHERE     aida.po_distribution_id =
                                 pda.po_distribution_id
                             AND aida.invoice_id = aia.invoice_id
                             AND pda.req_distribution_id = prda.distribution_id
                             AND prda.requisition_line_id =
                                 prla.requisition_line_id
                             AND prha.requisition_header_id =
                                 prla.requisition_header_id
                             AND prha.preparer_id = papf.person_id
                             AND pha2.po_header_id = pda.po_header_id
                             AND pha2.segment1 = pha.segment1
                             AND SYSDATE BETWEEN NVL (
                                                     papf.effective_start_date,
                                                     SYSDATE)
                                             AND NVL (papf.effective_end_date,
                                                      SYSDATE))
                         preparer,
                     aia.description,
                     SUM (pll.quantity_billed)
                         quantity_billed,
                     SUM (pll.quantity_received)
                         quantity_received,
                     NVL (TO_CHAR (aia.doc_sequence_value), aia.voucher_num)
                         voucher_number,
                     DECODE (aia.invoice_currency_code,
                             gll.currency_code, aia.invoice_amount,
                             aia.base_amount)
                         orginal_amount,
                     (SELECT SUM (DECODE (aia.payment_currency_code, gll.currency_code, apsa.amount_remaining, DECODE (fcv.minimum_accountable_unit, NULL, ROUND (((DECODE (aia.payment_cross_rate_type, 'EMU FIXED', 1 / aia.payment_cross_rate, aia.exchange_rate)) * NVL (apsa.amount_remaining, 0)), fcv.precision), ROUND (((DECODE (aia.payment_cross_rate_type, 'EMU FIXED', 1 / aia.payment_cross_rate, aia.exchange_rate)) * NVL (apsa.amount_remaining, 0)) / fcv.minimum_accountable_unit) * fcv.minimum_accountable_unit)))
                        FROM ap_payment_schedules_all s1
                       WHERE s1.invoice_id(+) = aia.invoice_id)
                         amount_remaining,
                     -- Start changes for 1.1
                     DECODE (
                         ap_invoices_utility_pkg.get_posting_status (
                             aia.invoice_id),
                         'Y', 'Yes',
                         'No')
                         accounting_status,
                     NULL
                         comments,
                     -- End changes for 1.1
                     -- Start of Change for CCR0009257
                     NVL (
                         (SELECT 'Y'
                            FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
                           WHERE     ffvs.flex_value_set_id =
                                     ffv.flex_value_set_id
                                 AND ffv.enabled_flag = 'Y'
                                 AND TRUNC (NVL (end_date_active, SYSDATE)) >=
                                     TRUNC (SYSDATE)
                                 AND ffvs.flex_value_set_name = 'XXD_MTD_OU_VS'
                                 AND ffv.flex_value = hou.name),
                         'N')
                         mtd_ou_flag,
                     pha.po_header_id,
                     aia.invoice_id,
                     (SELECT vat_registration_num
                        FROM ap_supplier_sites_all apsa
                       WHERE apsa.vendor_site_id = aia.vendor_site_id)
                         vat_num,
                     -- End of Change for CCR0009257
                     -- Start changes for 1.2
                     NVL (MIN (aia.attribute1), 0)
                         vendor_charged_tax,
                     NVL (
                         (SELECT SUM (aila.amount)
                            FROM ap_invoice_lines_all aila
                           WHERE     aila.invoice_id = aia.invoice_id
                                 AND aila.line_type_lookup_code = 'TAX'),
                         0)
                         onesource_calculated_tax_amt
                -- End changes for 1.2
                FROM hz_parties hp, ap_invoices_all aia, ap_holds_all aha,
                     ap_suppliers pv, ap_terms att, ap_batches_all aba,
                     hr_operating_units hou, ap_payment_schedules_all apsa, fnd_currencies_vl fcv,
                     po_line_locations_all pll, po_headers_all pha, gl_ledgers gll
               WHERE     hp.party_id = aia.party_id
                     AND aha.invoice_id(+) = aia.invoice_id
                     AND aha.release_lookup_code(+) IS NULL
                     AND apsa.invoice_id = aia.invoice_id
                     AND apsa.hold_flag = 'Y'
                     AND apsa.org_id = aia.org_id
                     AND pv.vendor_id(+) = aia.vendor_id
                     AND att.term_id = aia.terms_id
                     AND aba.batch_id(+) = aia.batch_id
                     AND hou.organization_id = aia.org_id
                     AND gll.currency_code = fcv.currency_code
                     AND gll.ledger_id = hou.set_of_books_id
                     AND pll.line_location_id(+) = aha.line_location_id
                     AND pha.po_header_id(+) = pll.po_header_id
                     -- Start of Change for CCR0009257
                     --AND hou.organization_id =
                     --    NVL (g_num_org_id, hou.organization_id)
                     -- Region and OU
                     AND (   (    p_region IS NOT NULL
                              AND p_region <> 'All'
                              AND EXISTS
                                      (SELECT 1
                                         FROM fnd_flex_values ffv1, fnd_flex_value_sets ffvs1, fnd_flex_values ffv2,
                                              fnd_flex_value_sets ffvs2
                                        WHERE     1 = 1
                                              AND ffv1.flex_value_set_id =
                                                  ffvs1.flex_value_set_id
                                              AND ffvs1.flex_value_set_name =
                                                  'XXDO_REGION_OU_MAPPING'
                                              AND ffv1.enabled_flag = 'Y'
                                              AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                              NVL (
                                                                                  ffv1.start_date_active,
                                                                                  SYSDATE))
                                                                      AND TRUNC (
                                                                              NVL (
                                                                                  ffv1.end_date_active,
                                                                                  SYSDATE))
                                              AND ffvs2.flex_value_set_name =
                                                  'XXDO_REGION_NAME'
                                              AND ffv2.flex_value_set_id =
                                                  ffvs2.flex_value_set_id
                                              AND ffv2.enabled_flag = 'Y'
                                              AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                              NVL (
                                                                                  ffv2.start_date_active,
                                                                                  SYSDATE))
                                                                      AND TRUNC (
                                                                              NVL (
                                                                                  ffv2.end_date_active,
                                                                                  SYSDATE))
                                              AND ffv1.parent_flex_value_low =
                                                  ffv2.flex_value
                                              AND ffv2.flex_value = p_region
                                              AND hou.organization_id =
                                                  TO_NUMBER (ffv1.flex_value)
                                              AND ((p_org_id IS NOT NULL AND hou.organization_id = p_org_id) OR (p_org_id IS NULL AND 1 = 1))))
                          OR ((p_region IS NULL OR p_region = 'All') AND 1 = 1))
                     -- Hold Name
                     AND ((p_hold_name IS NOT NULL AND aha.hold_lookup_code = p_hold_name) OR (p_hold_name IS NULL AND 1 = 1))
                     -- Tax Holds Only
                     AND ((p_tax_holds_only IS NOT NULL AND p_tax_holds_only = 'Y' AND 1 = 2) -- Payment holds are not needed for this parameter
                                                                                              OR ((p_tax_holds_only IS NULL OR p_tax_holds_only = 'N') AND 1 = 1))
            -- End of Change for CCR0009257
            GROUP BY aba.batch_name, hou.name, pv.vendor_name,
                     aia.invoice_id, aia.invoice_num, aia.invoice_date,
                     aia.invoice_amount, aia.creation_date, apsa.due_date,
                     att.name, pha.segment1, -- Start of Change for CCR0009257
                                             pha.po_header_id,
                     aia.vendor_site_id, -- End of Change for CCR0009257
                                         aia.description, NVL (TO_CHAR (aia.doc_sequence_value), aia.voucher_num),
                     DECODE (aia.invoice_currency_code, gll.currency_code, aia.invoice_amount, aia.base_amount), aia.payment_currency_code, gll.currency_code,
                     apsa.amount_remaining, fcv.minimum_accountable_unit, aia.payment_cross_rate_type,
                     aia.payment_cross_rate, aia.exchange_rate, fcv.precision
            -- Start of Change for CCR0009257
            -- ORDER BY 1, 3, 5;
            ORDER BY name, invoice_num, hold_name;

        -- End of Change for CCR0009257

        --Local Variable Declaration
        lv_hdata_record    VARCHAR2 (32767);
        -- Start of Change for CCR0009257
        -- lv_global_flag    VARCHAR2 (1);
        -- lv_resp_name      VARCHAR2 (100);
        -- lc_onesource_org_flag   VARCHAR2 (1);                     -- Added for 1.2
        ln_po_tax_amt      NUMBER;
        lc_po_category     VARCHAR2 (4000);
        lc_po_item_type    VARCHAR2 (4000);
        lc_tax_rate_code   VARCHAR2 (4000);
    -- End of Change for CCR0009257
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Begin Main procedure');
        -- Start commenting for CCR0009257
        /*lv_global_flag := 'N';
        lv_resp_name := NULL;
        g_num_org_id := mo_global.get_current_org_id;
        g_num_resp_id := fnd_global.resp_id;

        BEGIN
          SELECT responsibility_name, 'Y'
            INTO lv_resp_name, lv_global_flag
            FROM fnd_responsibility_tl
           WHERE     responsibility_id = g_num_resp_id
                 AND responsibility_name LIKE '%Payables%Global%'
                 AND language = 'US';
        EXCEPTION
          WHEN OTHERS
          THEN
            lv_resp_name := NULL;
            lv_global_flag := 'N';
        END;

        --Set org_id as NULL if it is a global responsibility
        IF lv_global_flag = 'Y'
        THEN
          fnd_file.put_line (fnd_file.LOG,
                             'Responsibility Name        - ' || lv_resp_name);
          g_num_org_id := NULL;
        ELSE
          fnd_file.put_line (
            fnd_file.LOG,
               'Operating Unit Name        - '
            || mo_global.get_ou_name (g_num_org_id));

        -- Start changes for 1.2

        SELECT DECODE (COUNT (1), 0, 'N', 'Y')
          INTO lc_onesource_org_flag
          FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
         WHERE     ffvs.flex_value_set_id = ffv.flex_value_set_id
               AND ffv.enabled_flag = 'Y'
               AND TRUNC (NVL (end_date_active, SYSDATE)) >= TRUNC (SYSDATE)
               AND ffvs.flex_value_set_name = 'XXD_MTD_OU_VS'
               AND ffv.flex_value = mo_global.get_ou_name (g_num_org_id);
        -- End changes for 1.2
        END IF;*/
        -- End commenting for CCR0009257

        -- Add Header Columns to the output file
        fnd_file.put_line (
            fnd_file.output,
               'HOLD_NAME'
            || CHR (9)
            || 'BATCH_NAME'
            || CHR (9)
            || 'OPERTING_UNIT'
            || CHR (9)
            || 'VENDOR_NAME'
            || CHR (9)
            || 'INVOICE_NUMBER'
            || CHR (9)
            || 'INVOICE_DATE'
            || CHR (9)
            || 'INVOICE_AMOUNT'
            || CHR (9)
            || 'INVOICE_CREATION_DATE'
            || CHR (9)
            || 'INVOICE_STATUS'
            || CHR (9)
            || 'DUE_DATE'
            || CHR (9)
            || 'VALIDATION_DATE'
            || CHR (9)
            || 'TERM_NAME'
            || CHR (9)
            || 'PO_NUMBER'
            || CHR (9)
            || 'PREPARER'
            || CHR (9)
            || 'REQUESTOR'
            || CHR (9)
            || 'DESCRIPTION'
            || CHR (9)
            || 'QUANTITY_BILLED'
            || CHR (9)
            || 'QUANTITY_RECEIVED'
            || CHR (9)
            || 'VOUCHER_NUMBER'
            || CHR (9)
            || 'ORIGINAL_AMOUNT'
            || CHR (9)
            || 'AMOUNT_REMAINING'
            -- Start changes for 1.1
            || CHR (9)
            || 'ACCOUNTING_STATUS'
            || CHR (9)
            || 'COMMENTS'
            -- End changes for 1.1
            -- Start changes for 1.2
            || CHR (9)
            || 'ONESOURCE_TAX_VARIANCE_HOLD'
            || CHR (9)
            || 'VENDOR_CHARGED_TAX'
            || CHR (9)
            || 'ONESOURCE_CALCULATED_TAX_AMT'
            -- End changes for 1.2
            -- Start of Change for CCR0009257
            || CHR (9)
            || 'PO_TAX_AMOUNT'
            || CHR (9)
            || 'PO_CATEGORY'
            || CHR (9)
            || 'PO_ITEM_TYPE'
            || CHR (9)
            || 'VAT_NUM'
            || CHR (9)
            || 'TAX_RATE_CODES');

        -- End of Change for CCR0009257

        --Loop to write the extract to the output file
        FOR rec_inv_hold IN c_inv_hold
        LOOP
            -- Start of Change for CCR0009257
            BEGIN
                ln_po_tax_amt      := NULL;
                lc_po_category     := NULL;
                lc_po_item_type    := NULL;
                lc_tax_rate_code   := NULL;

                -- PO Tax Amount
                SELECT SUM (zl.tax_amt)
                  INTO ln_po_tax_amt
                  FROM zx_lines zl, ap_invoice_lines_all aila
                 WHERE     zl.trx_id = aila.po_header_id
                       AND zl.trx_line_id = aila.po_line_location_id
                       AND zl.internal_organization_id = aila.org_id
                       AND aila.discarded_flag = 'N'
                       AND aila.invoice_id = rec_inv_hold.invoice_id;

                -- Show the first PO Line's Category first and so on
                -- And show only the distinct categories
                SELECT LISTAGG (seq || ': ' || category_name, '. ') WITHIN GROUP (ORDER BY seq)
                  INTO lc_po_category
                  FROM (SELECT category_name, RANK () OVER (ORDER BY line_num) seq
                          FROM (  SELECT mck.concatenated_segments category_name, MIN (pla.line_num) line_num
                                    FROM mtl_categories_kfv mck, po_lines_all pla
                                   WHERE     pla.category_id = mck.category_id
                                         AND pla.po_header_id =
                                             rec_inv_hold.po_header_id
                                GROUP BY mck.concatenated_segments
                                ORDER BY line_num));

                -- Show the first Invoice Line's product type first and so on
                -- And show only the distinct product types
                SELECT LISTAGG (seq || ': ' || product_type, '. ') WITHIN GROUP (ORDER BY seq)
                  INTO lc_po_item_type
                  FROM (SELECT product_type, RANK () OVER (ORDER BY line_number) seq
                          FROM (  SELECT NVL (aila.product_type, 'GOODS') product_type, MIN (aila.line_number) AS line_number
                                    FROM ap_invoice_lines_all aila
                                   WHERE     aila.line_type_lookup_code =
                                             'ITEM'
                                         AND aila.po_header_id IS NOT NULL
                                         AND aila.invoice_id =
                                             rec_inv_hold.invoice_id
                                GROUP BY NVL (aila.product_type, 'GOODS')
                                ORDER BY line_number));

                -- Show the first Invoice Line's tax rate code first and so on
                -- And show only the distinct tax rate codes
                SELECT LISTAGG (seq || ': ' || tax_rate_code, '. ') WITHIN GROUP (ORDER BY seq)
                  INTO lc_tax_rate_code
                  FROM (SELECT tax_rate_code, RANK () OVER (ORDER BY line_number) seq
                          FROM (  SELECT aila.tax_rate_code, MIN (aila.line_number) AS line_number
                                    FROM ap_invoice_lines_all aila
                                   WHERE     aila.line_type_lookup_code = 'TAX'
                                         AND aila.invoice_id =
                                             rec_inv_hold.invoice_id
                                GROUP BY aila.tax_rate_code
                                ORDER BY line_number));
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Exception in deriving addl values ::' || SQLERRM);
            END;

            -- End of Change for CCR0009257
            lv_hdata_record   :=
                   rec_inv_hold.hold_name
                || CHR (9)
                || rec_inv_hold.batch_name
                || CHR (9)
                || rec_inv_hold.name
                || CHR (9)
                || rec_inv_hold.vendor_name
                || CHR (9)
                || rec_inv_hold.invoice_num
                || CHR (9)
                || rec_inv_hold.invoice_date
                || CHR (9)
                || rec_inv_hold.invoice_amount
                || CHR (9)
                || rec_inv_hold.invoice_creation_date
                || CHR (9)
                || rec_inv_hold.approval_status
                || CHR (9)
                || rec_inv_hold.due_date
                || CHR (9)
                || rec_inv_hold.validation_date
                || CHR (9)
                || rec_inv_hold.terms_name
                || CHR (9)
                || rec_inv_hold.segment1
                || CHR (9)
                || rec_inv_hold.preparer
                || CHR (9)
                || rec_inv_hold.requestor
                || CHR (9)
                || rec_inv_hold.description
                || CHR (9)
                || rec_inv_hold.quantity_billed
                || CHR (9)
                || rec_inv_hold.quantity_received
                || CHR (9)
                || rec_inv_hold.voucher_number
                || CHR (9)
                || rec_inv_hold.orginal_amount
                || CHR (9)
                || rec_inv_hold.amount_remaining
                -- Start changes for 1.1
                || CHR (9)
                || rec_inv_hold.accounting_status
                || CHR (9)
                || rec_inv_hold.comments
                -- End changes for 1.1
                -- Start changes for 1.2
                || CHR (9)
                || CASE
                       WHEN rec_inv_hold.mtd_ou_flag = 'Y' --lc_onesource_org_flag = 'Y' -- Commented and Added as per CCR0009257
                       THEN
                           CASE
                               WHEN rec_inv_hold.vendor_charged_tax <>
                                    rec_inv_hold.onesource_calculated_tax_amt
                               THEN
                                   'Y'
                               ELSE
                                   'N'
                           END
                       ELSE
                           NULL
                   END
                || CHR (9)
                || CASE
                       WHEN rec_inv_hold.mtd_ou_flag = 'Y' --lc_onesource_org_flag = 'Y' -- Commented and Added as per CCR0009257
                       THEN
                           rec_inv_hold.vendor_charged_tax
                       ELSE
                           NULL
                   END
                || CHR (9)
                || CASE
                       WHEN rec_inv_hold.mtd_ou_flag = 'Y' --lc_onesource_org_flag = 'Y' -- Commented and Added as per CCR0009257
                       THEN
                           rec_inv_hold.onesource_calculated_tax_amt
                       ELSE
                           NULL
                   END
                -- End changes for 1.2
                -- Start of Change for CCR0009257
                || CHR (9)
                || ln_po_tax_amt
                || CHR (9)
                || lc_po_category
                || CHR (9)
                || lc_po_item_type
                || CHR (9)
                || rec_inv_hold.vat_num
                || CHR (9)
                || lc_tax_rate_code;
            -- End of Change for CCR0009257
            fnd_file.put_line (fnd_file.output, lv_hdata_record);
        END LOOP;

        fnd_file.put_line (fnd_file.LOG, 'End of Main procedure');
    --
    --
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Exception in main procedure ::' || SQLERRM);
    END main;
END xxdo_ap_invoice_hold_pkg;
/
