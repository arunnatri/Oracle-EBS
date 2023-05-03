--
-- XXD_GL_SBX_INT_REP_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:50 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_GL_SBX_INT_REP_PKG"
AS
    /***********************************************************************************
      *$header     :                                                                   *
      *                                                                                *
      * AUTHORS    :  Srinath Siricilla                                                *
      *                                                                                *
      * PURPOSE    :  Deckers GL One Source Tax Report                                 *
      *                                                                                *
      * PARAMETERS :                                                                   *
      *                                                                                *
      * DATE       :  08-MAR-2021                                                      *
      *                                                                                *
      * Assumptions:                                                                   *
      *                                                                                *
      *                                                                                *
      * History                                                                        *
      * Vsn     Change Date  Changed By            Change Description                  *
      * -----   -----------  ------------------    ------------------------------------*
      * 1.0     08-MAR-2021  Srinath Siricilla     Initial Creation CCR0009103         *
   * 1.1     08-OCT-2021  Aravind Kannuri       Modified for CCR0009638             *
   * 1.1     12-OCT-2021  Showkath ALi          Modified for CCR0009638             *
      **********************************************************************************/
    PROCEDURE MAIN_PRC (x_retcode OUT NOCOPY VARCHAR2, x_errbuf OUT NOCOPY VARCHAR2, -- pn_org_id        IN            NUMBER,
                                                                                     pv_operating_unit IN VARCHAR2, --1.1
                                                                                                                    pv_company IN VARCHAR2, pv_period_from IN VARCHAR2, pv_period_to IN VARCHAR2
                        , pv_account IN VARCHAR2, pv_status IN VARCHAR2)
    IS
        CURSOR cur_jor IS
            SELECT DISTINCT
                   'AP'
                       transaction_type,
                   gcc.segment1
                       gl_entity_code,
                   gcc.segment3
                       GL_GEO,
                   (SELECT name
                      FROM hr_operating_units
                     WHERE organization_id =
                           get_ou_fnc (gcc.segment1, gcc.segment3))
                       OU,
                   get_ou_vat (gcc.segment1, gcc.segment3)
                       ou_vat_num,
                   NULL
                       vendor_name,
                   NULL
                       vendor_number,
                   gjl.attribute7
                       vendor_country,
                   gjl.attribute8
                       vendor_vat_number,
                   gjl.attribute7
                       bill_to_country,
                   gjs.user_je_source_name
                       document_source,
                   gjc.user_je_category_name
                       document_category,
                   gjh.name,
                   gjh.je_header_id,
                   gjh.creation_date
                       journal_date,
                   --Start Added for 1.1
                   SUBSTR (DECODE (gjl.attribute9, 'I', gjl.reference_1),
                           1,
                           2)
                       tax_country,
                   --End Added for 1.1
                   DECODE (gjl.attribute9, 'I', gjl.reference_1)
                       input_tax_code,
                   DECODE (gjl.attribute9, 'O', gjl.reference_1)
                       output_tax_code,
                   gjl.attribute10
                       line_tax_rate,
                     NVL (
                         (SELECT conversion_rate
                            FROM apps.gl_daily_rates
                           WHERE     conversion_type = 'Corporate'
                                 AND from_currency = gl_data.CURRENCY_CODE
                                 AND to_currency = 'EUR'
                                 AND conversion_date =
                                     TRUNC (gl_data.currency_conversion_date)),
                         1)
                   * NVL (gl_data.sum_amt, 0)
                       eur_journal_total_amt,
                       NVL (
                           (SELECT conversion_rate
                              FROM apps.gl_daily_rates
                             WHERE     conversion_type = 'Corporate'
                                   AND from_currency = gl_data.CURRENCY_CODE
                                   AND to_currency = 'EUR'
                                   AND conversion_date =
                                       TRUNC (
                                           gl_data.currency_conversion_date)),
                           1)
                     * NVL (gl_data.sum_amt, 0)
                   -   NVL (
                           (SELECT conversion_rate
                              FROM apps.gl_daily_rates
                             WHERE     conversion_type = 'Corporate'
                                   AND from_currency = gl_data.CURRENCY_CODE
                                   AND to_currency = 'EUR'
                                   AND conversion_date =
                                       TRUNC (
                                           gl_data.currency_conversion_date)),
                           1)
                     * NVL (
                           (SELECT ROUND (NVL (gjl_sub.entered_dr, 0) - NVL (gjl_sub.entered_cr, 0), 2)
                              FROM apps.gl_je_lines gjl_sub, apps.gl_code_combinations_kfv gcc_sub
                             WHERE     gcc_sub.code_combination_id =
                                       gjl_sub.code_combination_id
                                   AND gjl_sub.je_header_id =
                                       gjl.je_header_id
                                   AND gjl_sub.je_line_num = gjl.je_line_num
                                   AND gcc_sub.segment6 IN ('11901', '11902')),
                           0)
                   -   NVL (
                           (SELECT conversion_rate
                              FROM apps.gl_daily_rates
                             WHERE     conversion_type = 'Corporate'
                                   AND from_currency = gl_data.CURRENCY_CODE
                                   AND to_currency = 'EUR'
                                   AND conversion_date =
                                       TRUNC (
                                           gl_data.currency_conversion_date)),
                           1)
                     * NVL (
                           (SELECT ROUND (NVL (gjl_sub.entered_dr, 0) - NVL (gjl_sub.entered_cr, 0), 2)
                              FROM apps.gl_je_lines gjl_sub, apps.gl_code_combinations_kfv gcc_sub
                             WHERE     gcc_sub.code_combination_id =
                                       gjl_sub.code_combination_id
                                   AND gjl_sub.je_header_id =
                                       gjl.je_header_id
                                   AND gjl_sub.je_line_num = gjl.je_line_num
                                   AND gcc_sub.segment6 IN ('21802')),
                           0)
                       eur_journal_net_amt,
                     --                  NVL (
                     --                     (SELECT conversion_rate
                     --                        FROM apps.gl_daily_rates
                     --                       WHERE     conversion_type = 'Corporate'
                     --                             AND from_currency = gl_data.CURRENCY_CODE
                     --                             AND to_currency = 'EUR'
                     --                             AND conversion_date =
                     --                                    TRUNC (gl_data.currency_conversion_date)),
                     --                     1)
                     --                * NVL (
                     --                     ROUND (
                     --                        NVL (gjl.entered_dr, 0) - NVL (gjl.entered_cr, 0),
                     --                        2),
                     --                     0)
                     --                   eur_journal_net_amt,
                     NVL (
                         (SELECT conversion_rate
                            FROM apps.gl_daily_rates
                           WHERE     conversion_type = 'Corporate'
                                 AND from_currency = gl_data.CURRENCY_CODE
                                 AND to_currency = 'EUR'
                                 AND conversion_date =
                                     TRUNC (gl_data.currency_conversion_date)),
                         1)
                   * NVL (
                         (SELECT ROUND (NVL (gjl_sub.entered_dr, 0) - NVL (gjl_sub.entered_cr, 0), 2)
                            FROM apps.gl_je_lines gjl_sub, apps.gl_code_combinations_kfv gcc_sub
                           WHERE     gcc_sub.code_combination_id =
                                     gjl_sub.code_combination_id
                                 AND gjl_sub.je_header_id = gjl.je_header_id
                                 AND gjl_sub.je_line_num = gjl.je_line_num
                                 AND gcc_sub.segment6 IN ('11901', '11902')),
                         0)
                       eur_journal_input_tax_amt,
                     NVL (
                         (SELECT conversion_rate
                            FROM apps.gl_daily_rates
                           WHERE     conversion_type = 'Corporate'
                                 AND from_currency = gl_data.CURRENCY_CODE
                                 AND to_currency = 'EUR'
                                 AND conversion_date =
                                     TRUNC (gl_data.currency_conversion_date)),
                         1)
                   * NVL (
                         (SELECT ROUND (NVL (gjl_sub.entered_dr, 0) - NVL (gjl_sub.entered_cr, 0), 2)
                            FROM apps.gl_je_lines gjl_sub, apps.gl_code_combinations_kfv gcc_sub
                           WHERE     gcc_sub.code_combination_id =
                                     gjl_sub.code_combination_id
                                 AND gjl_sub.je_header_id = gjl.je_header_id
                                 AND gjl_sub.je_line_num = gjl.je_line_num
                                 AND gcc_sub.segment6 IN ('21802')),
                         0)
                       eur_line_output_tax_amt,
                     NVL (
                         (SELECT conversion_rate
                            FROM apps.gl_daily_rates
                           WHERE     conversion_type = 'Corporate'
                                 AND from_currency = gl_data.CURRENCY_CODE
                                 AND to_currency = 'GBP'
                                 AND conversion_date =
                                     TRUNC (gl_data.currency_conversion_date)),
                         1)
                   * NVL (gl_data.sum_amt, 0)
                       gbp_journal_total_amt,
                       --                  NVL (
                       --                     (SELECT conversion_rate
                       --                        FROM apps.gl_daily_rates
                       --                       WHERE     conversion_type = 'Corporate'
                       --                             AND from_currency = gl_data.CURRENCY_CODE
                       --                             AND to_currency = 'GBP'
                       --                             AND conversion_date =
                       --                                    TRUNC (gl_data.currency_conversion_date)),
                       --                     1)
                       --                * NVL (
                       --                     ROUND (
                       --                        NVL (gjl.entered_dr, 0) - NVL (gjl.entered_cr, 0),
                       --                        2),
                       --                     0)
                       --                   gbp_journal_net_amt,
                       --
                       NVL (
                           (SELECT conversion_rate
                              FROM apps.gl_daily_rates
                             WHERE     conversion_type = 'Corporate'
                                   AND from_currency = gl_data.CURRENCY_CODE
                                   AND to_currency = 'GBP'
                                   AND conversion_date =
                                       TRUNC (
                                           gl_data.currency_conversion_date)),
                           1)
                     * NVL (gl_data.sum_amt, 0)
                   -   NVL (
                           (SELECT conversion_rate
                              FROM apps.gl_daily_rates
                             WHERE     conversion_type = 'Corporate'
                                   AND from_currency = gl_data.CURRENCY_CODE
                                   AND to_currency = 'GBP'
                                   AND conversion_date =
                                       TRUNC (
                                           gl_data.currency_conversion_date)),
                           1)
                     * NVL (
                           (SELECT ROUND (NVL (gjl_sub.entered_dr, 0) - NVL (gjl_sub.entered_cr, 0), 2)
                              FROM apps.gl_je_lines gjl_sub, apps.gl_code_combinations_kfv gcc_sub
                             WHERE     gcc_sub.code_combination_id =
                                       gjl_sub.code_combination_id
                                   AND gjl_sub.je_header_id =
                                       gjl.je_header_id
                                   AND gjl_sub.je_line_num = gjl.je_line_num
                                   AND gcc_sub.segment6 IN ('11901', '11902')),
                           0)
                   -   NVL (
                           (SELECT conversion_rate
                              FROM apps.gl_daily_rates
                             WHERE     conversion_type = 'Corporate'
                                   AND from_currency = gl_data.CURRENCY_CODE
                                   AND to_currency = 'GBP'
                                   AND conversion_date =
                                       TRUNC (
                                           gl_data.currency_conversion_date)),
                           1)
                     * NVL (
                           (SELECT ROUND (NVL (gjl_sub.entered_dr, 0) - NVL (gjl_sub.entered_cr, 0), 2)
                              FROM apps.gl_je_lines gjl_sub, apps.gl_code_combinations_kfv gcc_sub
                             WHERE     gcc_sub.code_combination_id =
                                       gjl_sub.code_combination_id
                                   AND gjl_sub.je_header_id =
                                       gjl.je_header_id
                                   AND gjl_sub.je_line_num = gjl.je_line_num
                                   AND gcc_sub.segment6 IN ('21802')),
                           0)
                       gbp_journal_net_amt,
                     --
                     NVL (
                         (SELECT conversion_rate
                            FROM apps.gl_daily_rates
                           WHERE     conversion_type = 'Corporate'
                                 AND from_currency = gl_data.CURRENCY_CODE
                                 AND to_currency = 'GBP'
                                 AND conversion_date =
                                     TRUNC (gl_data.currency_conversion_date)),
                         1)
                   * NVL (
                         (SELECT ROUND (NVL (gjl_sub.entered_dr, 0) - NVL (gjl_sub.entered_cr, 0), 2)
                            FROM apps.gl_je_lines gjl_sub, apps.gl_code_combinations_kfv gcc_sub
                           WHERE     gcc_sub.code_combination_id =
                                     gjl_sub.code_combination_id
                                 AND gjl_sub.je_header_id = gjl.je_header_id
                                 AND gjl_sub.je_line_num = gjl.je_line_num
                                 AND gcc_sub.segment6 IN ('11901', '11902')),
                         0)
                       gbp_journal_input_tax_amt,
                     NVL (
                         (SELECT conversion_rate
                            FROM apps.gl_daily_rates
                           WHERE     conversion_type = 'Corporate'
                                 AND from_currency = gl_data.CURRENCY_CODE
                                 AND to_currency = 'GBP'
                                 AND conversion_date =
                                     TRUNC (gl_data.currency_conversion_date)),
                         1)
                   * NVL (
                         (SELECT ROUND (NVL (gjl_sub.entered_dr, 0) - NVL (gjl_sub.entered_cr, 0), 2)
                            FROM apps.gl_je_lines gjl_sub, apps.gl_code_combinations_kfv gcc_sub
                           WHERE     gcc_sub.code_combination_id =
                                     gjl_sub.code_combination_id
                                 AND gjl_sub.je_header_id = gjl.je_header_id
                                 AND gjl_sub.je_line_num = gjl.je_line_num
                                 AND gcc_sub.segment6 IN ('21802')),
                         0)
                       gbp_line_output_tax_amt,
                     NVL (
                         (SELECT conversion_rate
                            FROM apps.gl_daily_rates
                           WHERE     conversion_type = 'Corporate'
                                 AND from_currency = gl_data.CURRENCY_CODE
                                 AND to_currency = 'USD'
                                 AND conversion_date =
                                     TRUNC (gl_data.currency_conversion_date)),
                         1)
                   * NVL (gl_data.sum_amt, 0)
                       usd_journal_total_amt,
                       --                  NVL (
                       --                     (SELECT conversion_rate
                       --                        FROM apps.gl_daily_rates
                       --                       WHERE     conversion_type = 'Corporate'
                       --                             AND from_currency = gl_data.CURRENCY_CODE
                       --                             AND to_currency = 'USD'
                       --                             AND conversion_date =
                       --                                    TRUNC (gl_data.currency_conversion_date)),
                       --                     1)
                       --                * NVL (
                       --                     ROUND (
                       --                        NVL (gjl.entered_dr, 0) - NVL (gjl.entered_cr, 0),
                       --                        2),
                       --                     0)
                       --                   usd_journal_net_amt,
                       --
                       NVL (
                           (SELECT conversion_rate
                              FROM apps.gl_daily_rates
                             WHERE     conversion_type = 'Corporate'
                                   AND from_currency = gl_data.CURRENCY_CODE
                                   AND to_currency = 'USD'
                                   AND conversion_date =
                                       TRUNC (
                                           gl_data.currency_conversion_date)),
                           1)
                     * NVL (gl_data.sum_amt, 0)
                   -   NVL (
                           (SELECT conversion_rate
                              FROM apps.gl_daily_rates
                             WHERE     conversion_type = 'Corporate'
                                   AND from_currency = gl_data.CURRENCY_CODE
                                   AND to_currency = 'USD'
                                   AND conversion_date =
                                       TRUNC (
                                           gl_data.currency_conversion_date)),
                           1)
                     * NVL (
                           (SELECT ROUND (NVL (gjl_sub.entered_dr, 0) - NVL (gjl_sub.entered_cr, 0), 2)
                              FROM apps.gl_je_lines gjl_sub, apps.gl_code_combinations_kfv gcc_sub
                             WHERE     gcc_sub.code_combination_id =
                                       gjl_sub.code_combination_id
                                   AND gjl_sub.je_header_id =
                                       gjl.je_header_id
                                   AND gjl_sub.je_line_num = gjl.je_line_num
                                   AND gcc_sub.segment6 IN ('11901', '11902')),
                           0)
                   -   NVL (
                           (SELECT conversion_rate
                              FROM apps.gl_daily_rates
                             WHERE     conversion_type = 'Corporate'
                                   AND from_currency = gl_data.CURRENCY_CODE
                                   AND to_currency = 'USD'
                                   AND conversion_date =
                                       TRUNC (
                                           gl_data.currency_conversion_date)),
                           1)
                     * NVL (
                           (SELECT ROUND (NVL (gjl_sub.entered_dr, 0) - NVL (gjl_sub.entered_cr, 0), 2)
                              FROM apps.gl_je_lines gjl_sub, apps.gl_code_combinations_kfv gcc_sub
                             WHERE     gcc_sub.code_combination_id =
                                       gjl_sub.code_combination_id
                                   AND gjl_sub.je_header_id =
                                       gjl.je_header_id
                                   AND gjl_sub.je_line_num = gjl.je_line_num
                                   AND gcc_sub.segment6 IN ('21802')),
                           0)
                       usd_journal_net_amt,
                     --
                     NVL (
                         (SELECT conversion_rate
                            FROM apps.gl_daily_rates
                           WHERE     conversion_type = 'Corporate'
                                 AND from_currency = gl_data.CURRENCY_CODE
                                 AND to_currency = 'USD'
                                 AND conversion_date =
                                     TRUNC (gl_data.currency_conversion_date)),
                         1)
                   * NVL (
                         (SELECT ROUND (NVL (gjl_sub.entered_dr, 0) - NVL (gjl_sub.entered_cr, 0), 2)
                            FROM apps.gl_je_lines gjl_sub, apps.gl_code_combinations_kfv gcc_sub
                           WHERE     gcc_sub.code_combination_id =
                                     gjl_sub.code_combination_id
                                 AND gjl_sub.je_header_id = gjl.je_header_id
                                 AND gjl_sub.je_line_num = gjl.je_line_num
                                 AND gcc_sub.segment6 IN ('11901', '11902')),
                         0)
                       usd_journal_input_tax_amt,
                     NVL (
                         (SELECT conversion_rate
                            FROM apps.gl_daily_rates
                           WHERE     conversion_type = 'Corporate'
                                 AND from_currency = gl_data.CURRENCY_CODE
                                 AND to_currency = 'USD'
                                 AND conversion_date =
                                     TRUNC (gl_data.currency_conversion_date)),
                         1)
                   * NVL (
                         (SELECT ROUND (NVL (gjl_sub.entered_dr, 0) - NVL (gjl_sub.entered_cr, 0), 2)
                            FROM apps.gl_je_lines gjl_sub, apps.gl_code_combinations_kfv gcc_sub
                           WHERE     gcc_sub.code_combination_id =
                                     gjl_sub.code_combination_id
                                 AND gjl_sub.je_header_id = gjl.je_header_id
                                 AND gjl_sub.je_line_num = gjl.je_line_num
                                 AND gcc_sub.segment6 IN ('21802')),
                         0)
                       usd_line_output_tax_amt,
                   gcc.concatenated_segments
                       gcc_code,
                   gjh.default_effective_date
                       acc_date,
                   gl_data.user_je_source_name
                       parent_je_source,
                   gl_data.je_header_id
                       Source_Header_id,
                   gl_data.name
                       Source_Journal_Name
              FROM apps.gl_je_lines gjl,
                   apps.gl_je_headers gjh,
                   apps.gl_code_combinations_kfv gcc,
                   apps.gl_je_sources gjs,
                   apps.gl_je_categories gjc,
                   --Start Added for 1.1
                   fnd_flex_value_sets ffvs,
                   fnd_flex_values ffv,
                   --End Added for 1.1
                    (  SELECT gjh.currency_code, gjh.currency_conversion_date, gjs.user_je_source_name,
                              gjl.je_header_id, gjl.je_line_num, gjl.attribute2,
                              gjl.attribute3, gjh.name, NVL (ROUND (SUM (NVL (gjl.entered_dr, 0) - NVL (gjl.entered_cr, 0)), 2), 0) sum_amt
                         FROM apps.gl_je_lines gjl, apps.gl_je_headers gjh, apps.gl_je_sources gjs
                        WHERE     1 = 1
                              AND gjh.je_header_id = gjl.je_header_id
                              AND gjh.je_source IN
                                      ('Manual', 'Spreadsheet', 'Cash Management')
                              AND gjh.je_source = gjs.je_source_name
                              AND NVL (gjl.attribute5, 'N') = 'Y'
                     GROUP BY gjh.currency_code, gjh.currency_conversion_date, gjl.je_header_id,
                              gjl.je_line_num, gjl.attribute2, gjl.attribute3,
                              gjs.user_je_source_name, gjh.name) gl_data
             WHERE     1 = 1
                   AND gl_data.je_header_id = gjl.attribute4
                   AND gl_data.je_line_num = gjl.attribute5
                   AND gjh.je_header_id = gjl.je_header_id
                   AND gcc.code_combination_id = gjl.code_combination_id
                   AND gjs.je_source_name = gjh.je_source
                   AND gjh.ledger_id = gjl.ledger_id
                   AND gjs.user_je_source_name = 'One Source'
                   AND gjc.je_category_name = gjh.je_category
                   AND gjc.user_je_category_name = 'Tax Journal'
                   AND gjh.default_effective_date BETWEEN (SELECT start_date
                                                             FROM gl_periods
                                                            WHERE     period_set_name =
                                                                      'DO_FY_CALENDAR'
                                                                  AND period_name =
                                                                      pv_period_from)
                                                      AND (SELECT end_date
                                                             FROM gl_periods
                                                            WHERE     period_set_name =
                                                                      'DO_FY_CALENDAR'
                                                                  AND period_name =
                                                                      pv_period_to)
                   AND gcc.segment1 = NVL (pv_company, gcc.segment1)
                   --                AND gjh.je_header_id = 1681814793
                   AND gcc.segment6 = NVL (pv_account, gcc.segment6)
                   AND gjh.status = NVL (pv_status, gjh.status)
                   --Start Added for 1.1
                   --AND hu.NAME = pv_operating_unit
                   AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                   AND flex_value_set_name = 'XXD_AR_MTD_OU_VS'
                   AND ffv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN NVL (ffv.start_date_active,
                                                    TRUNC (SYSDATE))
                                           AND NVL (ffv.end_date_active,
                                                    TRUNC (SYSDATE))
                   AND ffv.flex_value <> 'ALL EMEA'
                   --AND get_ou_name_fnc(gcc.segment1, gcc.segment3) = ffv.flex_value
                   AND get_ou_name_fnc (gcc.segment1, gcc.segment3) =
                       NVL (
                           DECODE (pv_operating_unit,
                                   'ALL EMEA', ffv.flex_value,
                                   pv_operating_unit),
                           get_ou_name_fnc (gcc.segment1, gcc.segment3))--End Added for 1.1

                                                                        /*AND get_ou_name_fnc (gcc.segment1, gcc.segment3) =
                                                                               NVL (pn_org_id,
                                                                                    get_ou_name_fnc (gcc.segment1, gcc.segment3))*/
                                                                        ;

        lv_ver         VARCHAR2 (32767) := NULL;
        lv_delimiter   VARCHAR2 (1) := '|';
        lv_output      VARCHAR2 (2000);
        lv_line        VARCHAR2 (32767) := NULL;
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            'Start Time: ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

        fnd_file.put_line (fnd_file.LOG, 'Passed Parameters');
        fnd_file.put_line (fnd_file.LOG, '=================');

        fnd_file.put_line (fnd_file.LOG,
                           'Operating Unit Name - ' || pv_operating_unit); --1.1
        fnd_file.put_line (fnd_file.LOG, 'Company - ' || pv_company);
        fnd_file.put_line (fnd_file.LOG, 'Period From - ' || pv_period_from);
        fnd_file.put_line (fnd_file.LOG, 'Period to - ' || pv_period_to);
        fnd_file.put_line (fnd_file.LOG, 'Account - ' || pv_account);
        fnd_file.put_line (fnd_file.LOG, 'Posting Status - ' || pv_status);

        lv_ver      :=
               'TRANSACTION_TYPE'
            || lv_delimiter
            || 'JOURNAL_PARENT_SOURCE'                            -- Added New
            || lv_delimiter
            || 'GL_ENTITY_CODE'
            || lv_delimiter
            || 'OU_NAME'
            || lv_delimiter
            || 'OU_VAT_NUMBER'
            || lv_delimiter
            || 'VENDOR_NAME'
            || lv_delimiter
            || 'VENDOR_NUMBER'
            || lv_delimiter
            || 'VENDOR_COUNTRY'
            || lv_delimiter
            || 'VENDOR_VAT_NUMBER'
            || lv_delimiter
            || 'BILL_TO_COUNTRY'
            || lv_delimiter
            || 'DOCUMENT_SOURCE'
            || lv_delimiter
            || 'DOCUMENT_CATEGORY'
            || lv_delimiter
            || 'SOURCE_JOURNAL_NAME'                             --- Added New
            || lv_delimiter
            || 'SOURCE_JOURNAL_HEADER_ID'                        --- Added New
            || lv_delimiter
            || 'JOURNAL_NAME'
            || lv_delimiter
            || 'TAX_JOURNAL_HEADER_ID'                            -- Added New
            || lv_delimiter
            || 'JOURNAL_DATE'
            || lv_delimiter
            --Start Added for 1.1
            || 'TAX_COUNTRY'
            || lv_delimiter
            --End Added for 1.1
            || 'INPUT_TAX_CODE'
            || lv_delimiter
            || 'OUTPUT_TAX_CODE'
            || lv_delimiter
            || 'LINE_TAX_RATE'
            || lv_delimiter
            || 'EUR_JOURNAL_TOTAL_AMT'
            || lv_delimiter
            || 'EUR_JOURNAL_NET_AMT'
            || lv_delimiter
            || 'EUR_JOURNAL_INPUT_TAX_AMT'
            || lv_delimiter
            || 'EUR_JOURNAL_OUTPUT_TAX_AMT'
            || lv_delimiter
            || 'GBP_JOURNAL_TOTAL_AMT'
            || lv_delimiter
            || 'GBP_JOURNAL_NET_AMT'
            || lv_delimiter
            || 'GBP_JOURNAL_INPUT_TAX_AMT'
            || lv_delimiter
            || 'GBP_JOURNAL_OUTPUT_TAX_AMT'
            || lv_delimiter
            || 'USD_JOURNAL_TOTAL_AMT'
            || lv_delimiter
            || 'USD_JOURNAL_NET_AMT'
            || lv_delimiter
            || 'USD_JOURNAL_INPUT_TAX_AMT'
            || lv_delimiter
            || 'USD_JOURNAL_OUTPUT_TAX_AMT'
            || lv_delimiter
            || 'GL_ACCOUNT_COMBINATION'
            || lv_delimiter
            || 'ACCOUNTING_DATE';

        lv_output   := NULL;
        -- '*** Tax Journals Created as part of One Source ***';
        apps.fnd_file.put_line (apps.fnd_file.output, lv_output);
        apps.fnd_file.put_line (apps.fnd_file.output, lv_ver);

        FOR i IN cur_jor
        LOOP
            BEGIN
                --            apps.fnd_file.put_line (apps.fnd_file.log, 'gl_entity_code - '||i.gl_entity_code);
                --            apps.fnd_file.put_line (apps.fnd_file.log, 'gl_GEO - '||i.gl_GEO);
                --            apps.fnd_file.put_line (apps.fnd_file.log, 'ou_vat_num - '||i.ou_vat_num);
                --            apps.fnd_file.put_line (apps.fnd_file.log, 'vendor_vat_number - '||i.vendor_vat_number);
                lv_delimiter   := '|';
                lv_line        :=
                       remove_junk_char (
                           REPLACE (i.transaction_type, CHR (9), ' '))
                    || lv_delimiter
                    || remove_junk_char (
                           REPLACE (i.parent_je_source, CHR (9), ' ')) -- Added New
                    || lv_delimiter
                    || REPLACE (i.gl_entity_code, CHR (9), ' ')
                    || lv_delimiter
                    || remove_junk_char (REPLACE (i.ou, CHR (9), ' '))
                    || lv_delimiter
                    || remove_junk_char (
                           REPLACE (i.ou_vat_num, CHR (9), ' '))
                    || lv_delimiter
                    || remove_junk_char (
                           REPLACE (i.vendor_name, CHR (9), ' '))
                    || lv_delimiter
                    || REPLACE (i.vendor_number, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.vendor_country, CHR (9), ' ')
                    || lv_delimiter
                    || remove_junk_char (
                           REPLACE (i.vendor_vat_number, CHR (9), ' '))
                    || lv_delimiter
                    || REPLACE (i.bill_to_country, CHR (9), ' ')
                    || lv_delimiter
                    || remove_junk_char (
                           REPLACE (i.document_source, CHR (9), ' '))
                    || lv_delimiter
                    || remove_junk_char (
                           REPLACE (i.document_category, CHR (9), ' '))
                    || lv_delimiter
                    || remove_junk_char (
                           REPLACE (i.source_journal_name, CHR (9), ' ')) -- Added New
                    || lv_delimiter
                    || REPLACE (i.source_header_id, CHR (9), ' ') -- Added New
                    || lv_delimiter
                    || remove_junk_char (REPLACE (i.name, CHR (9), ' '))
                    || lv_delimiter
                    || REPLACE (i.je_header_id, CHR (9), ' ')     -- Added New
                    || lv_delimiter
                    || REPLACE (i.journal_date, CHR (9), ' ')
                    || lv_delimiter
                    --Start Added for 1.1
                    || REPLACE (i.tax_country, CHR (9), ' ')
                    || lv_delimiter
                    --End Added for 1.1
                    || remove_junk_char (
                           REPLACE (i.input_tax_code, CHR (9), ' '))
                    || lv_delimiter
                    || remove_junk_char (
                           REPLACE (i.output_tax_code, CHR (9), ' '))
                    || lv_delimiter
                    || REPLACE (i.line_tax_rate, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.eur_journal_total_amt, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.eur_journal_net_amt, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.eur_journal_input_tax_amt, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.eur_line_output_tax_amt, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.gbp_journal_total_amt, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.gbp_journal_net_amt, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.gbp_journal_input_tax_amt, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.gbp_line_output_tax_amt, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.usd_journal_total_amt, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.usd_journal_net_amt, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.usd_journal_input_tax_amt, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.usd_line_output_tax_amt, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.gcc_code, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.acc_date, CHR (9), ' ');

                apps.fnd_file.put_line (apps.fnd_file.output, lv_line);
            END;
        END LOOP;
    END MAIN_PRC;

    --1.1 changes
    FUNCTION get_ou_name_fnc (pv_comp IN VARCHAR2, pv_cc IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_org_name   VARCHAR2 (500);
    BEGIN
        lv_org_name   := NULL;

        BEGIN
            SELECT hro.name
              INTO lv_org_name
              FROM apps.xle_entity_profiles lep, apps.xle_registrations reg, apps.hr_locations_all hrl,
                   apps.gl_ledgers gl, apps.hr_operating_units hro
             WHERE     lep.transacting_entity_flag = 'Y'
                   AND lep.legal_entity_id = reg.source_id
                   AND reg.source_table = 'XLE_ENTITY_PROFILES'
                   AND hrl.location_id = reg.location_id
                   AND reg.identifying_flag = 'Y'
                   AND hro.set_of_books_id = gl.ledger_id
                   AND lep.legal_entity_id = hro.default_legal_context_id
                   AND lep.legal_entity_identifier = pv_comp;

            FND_FILE.PUT_LINE (FND_FILE.LOG, 'lv_org_name:' || lv_org_name);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_org_name   := NULL;
                FND_FILE.PUT_LINE (FND_FILE.LOG,
                                   'lv_org_name:' || lv_org_name);
        END;

        IF     pv_comp = '500'
           AND pv_cc IN ('502', '504')
           AND lv_org_name IS NULL
        THEN
            lv_org_name   := 'Deckers Macau EMEA OU';
        ELSIF pv_comp = '110'                          --AND ln_org_id IS NULL
        THEN
            lv_org_name   := 'Deckers Europe Ltd OU';
        END IF;

        RETURN lv_org_name;
    END get_ou_name_fnc;

    --1.1 changes end


    FUNCTION get_ou_fnc (pv_comp IN VARCHAR2, pv_cc IN VARCHAR2)
        RETURN NUMBER
    IS
        ln_org_id   NUMBER;
    BEGIN
        ln_org_id   := NULL;

        BEGIN
            SELECT hro.organization_id
              INTO ln_org_id
              FROM apps.xle_entity_profiles lep, apps.xle_registrations reg, apps.hr_locations_all hrl,
                   apps.gl_ledgers gl, apps.hr_operating_units hro
             WHERE     lep.transacting_entity_flag = 'Y'
                   AND lep.legal_entity_id = reg.source_id
                   AND reg.source_table = 'XLE_ENTITY_PROFILES'
                   AND hrl.location_id = reg.location_id
                   AND reg.identifying_flag = 'Y'
                   AND hro.set_of_books_id = gl.ledger_id
                   AND lep.legal_entity_id = hro.default_legal_context_id
                   AND lep.legal_entity_identifier = pv_comp;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_org_id   := NULL;
        END;

        IF pv_comp = '500' AND pv_cc IN ('502', '504') AND ln_org_id IS NULL
        THEN
            ln_org_id   := 953;
        ELSIF pv_comp = '110'                          --AND ln_org_id IS NULL
        THEN
            ln_org_id   := 104;
        END IF;

        RETURN ln_org_id;
    END get_ou_fnc;


    FUNCTION get_ou_vat (pv_company IN VARCHAR2, pv_geo IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_tax_reg_num   VARCHAR2 (100);
    BEGIN
        lv_tax_reg_num   := NULL;

        BEGIN
            SELECT attribute5
              INTO lv_tax_reg_num
              FROM xxcp_cust_data
             WHERE     category_name = 'ONESOURCE GEO VAT MATRIX'
                   AND attribute1 = pv_company
                   AND attribute2 = pv_geo;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_tax_reg_num   := NULL;

                BEGIN
                    SELECT attribute5
                      INTO lv_tax_reg_num
                      FROM xxcp_cust_data
                     WHERE     category_name = 'ONESOURCE GEO VAT MATRIX'
                           AND attribute1 = pv_company;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_tax_reg_num   := NULL;
                END;
        END;

        IF lv_tax_reg_num IS NULL
        THEN
            BEGIN
                SELECT tax_registration_ref
                  INTO lv_tax_reg_num
                  FROM apps.xxcp_tax_registrations
                 WHERE short_code = pv_company;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_tax_reg_num   := NULL;
            END;
        END IF;

        RETURN lv_tax_reg_num;
    END get_ou_vat;

    -- Start Added for 1.1
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
-- End Added for 1.1


END XXD_GL_SBX_INT_REP_PKG;
/
