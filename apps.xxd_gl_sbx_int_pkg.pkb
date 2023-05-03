--
-- XXD_GL_SBX_INT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:51 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_GL_SBX_INT_PKG"
AS
    /***********************************************************************************
      *$header     :                                                                   *
      *                                                                                *
      * AUTHORS    :  Srinath Siricilla                                                *
      *                                                                                *
      * PURPOSE    :  Deckers GL One Source Tax Creation                               *
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
      **********************************************************************************/

    PROCEDURE print_log (pv_msg IN VARCHAR2, pv_time IN VARCHAR2 DEFAULT 'N')
    IS
        lv_proc_name    VARCHAR2 (30) := 'PRINT_LOG';
        lv_msg          VARCHAR2 (4000);
        lv_time_stamp   VARCHAR2 (20)
                            := TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS');
    BEGIN
        IF pv_time = 'Y'
        THEN
            lv_msg   := pv_msg || '. Timestamp: ' || lv_time_stamp;
        ELSE
            lv_msg   := pv_msg;
        END IF;

        IF gn_user_id = -1
        THEN
            DBMS_OUTPUT.put_line (lv_msg);
        ELSE
            fnd_file.put_line (fnd_file.LOG, lv_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Unable to print log:' || SQLERRM);
    END print_log;

    ----
    ----
    --Write messages into output file
    --Parameters
    --PV_MSG        Message to be printed
    --PV_TIME       Print timestamp or not. Default is NO.

    PROCEDURE print_out (pv_msg IN VARCHAR2, pv_time IN VARCHAR2 DEFAULT 'N')
    IS
        lv_proc_name    VARCHAR2 (30) := 'PRINT_OUT';
        lv_msg          VARCHAR2 (4000);
        lv_time_stamp   VARCHAR2 (20)
                            := TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS');
    BEGIN
        IF pv_time = 'Y'
        THEN
            lv_msg   := pv_msg || '. Timestamp: ' || lv_time_stamp;
        ELSE
            lv_msg   := pv_msg;
        END IF;

        IF gn_user_id = -1
        THEN
            DBMS_OUTPUT.put_line (lv_msg);
        ELSE
            fnd_file.put_line (fnd_file.output, lv_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Unable to print output:' || SQLERRM);
    END print_out;

    PROCEDURE debug_log_prc (p_batch_id    NUMBER,
                             p_procedure   VARCHAR2,
                             p_location    VARCHAR2,
                             p_message     VARCHAR2,
                             p_severity    VARCHAR2 DEFAULT 0)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        IF g_debug_level IS NOT NULL AND g_debug_level IN ('ALL', 'USER')
        THEN
            INSERT INTO sabrix_log (log_date, instance_name, batch_id,
                                    log_id, document_num, procedure_name,
                                    location, severity, MESSAGE,
                                    extended_message)
                 VALUES (SYSDATE, sabrix_log_pkg.g_instance_name, p_batch_id,
                         sabrix_log_id_seq.NEXTVAL, sabrix_log_pkg.g_invoice_number, p_procedure, p_location, p_severity, SUBSTR (p_message, 1, 4000)
                         , NULL);

            COMMIT;
        END IF;
    END debug_log_prc;

    FUNCTION get_tax_code_new (i_batch_id IN NUMBER, i_invoice_id IN NUMBER, i_line_id IN NUMBER
                               , x_ret_msg OUT VARCHAR2)
        RETURN VARCHAR2
    IS
        --NO_RATE_CODE          EXCEPTION;

        CURSOR c_results IS
              SELECT i.user_element_attribute45 internal_organization_id, ltx.ROWID tx_rowid, ltx.*
                FROM sabrix_line_tax ltx, sabrix_line l, sabrix_invoice_out i
               WHERE     ltx.batch_id = i_batch_id -- You should have a batch id, pass that to the function
                     AND i.invoice_id = i_invoice_id
                     AND l.line_id = i_line_id
                     AND i.batch_id = ltx.batch_id
                     AND i.invoice_id = ltx.invoice_id
                     AND l.batch_id = ltx.batch_id
                     AND l.invoice_id = ltx.invoice_id
                     AND l.line_id = ltx.line_id
                     AND ltx.taxable_country = g_country_code
            ORDER BY ltx.batch_id, ltx.invoice_id, ltx.line_id,
                     ltx.line_tax_id;

        l_prev_line_id        sabrix_line_tax.line_id%TYPE;
        l_authority_mapping   sabrix_tax.t_authority_mapping;
        l_empty_auth_map      sabrix_tax.t_authority_mapping;
        l_tax_code            sabrix_authority_mapping.tax_flow%TYPE;
        l_erp_tax_code        sabrix_line_tax.erp_tax_code%TYPE;
    BEGIN
        x_ret_msg        := NULL;
        l_prev_line_id   := -1;

        FOR tl IN c_results
        LOOP
            IF tl.line_id <> l_prev_line_id
            THEN
                l_authority_mapping   := l_empty_auth_map;
            END IF;

            l_prev_line_id   := tl.line_id;

            --         l_erp_tax_code :=
            --            NVL (tl.erp_tax_code,
            --                 sabrix_tax.Oracle_tax_code (tl.line_comment));

            --         IF sabrix_tax.g_tce_acct_level = 'EXTENDED'
            --         THEN
            --            l_erp_tax_code :=
            --               sabrix_tax.GetTaxCodeExtensions (
            --                  p_tax_code        => l_erp_tax_code,
            --                  p_is_exempt       => tl.is_exempt,
            --                  p_tax_type        => tl.tax_type,
            --                  p_tax_rate_code   => tl.tax_rate_code -- this is not the erp tax code
            --                                                       ,
            --                  p_tax_direction   => tl.tax_direction);
            --         END IF;

            BEGIN
                l_tax_code   :=
                    sabrix_tax.get_authority_mapping (
                        i_regime_code          => g_sabrix_regime -- global variable which you got in 1st step -- SBX_REGIME_NL
                                                                 ,
                        i_uuid                 => tl.authority_uuid,
                        i_authority_name       => tl.authority_name,
                        i_erp_tax_code         => l_erp_tax_code,
                        i_direction            => tl.tax_direction,
                        i_workflow             => 'P2P',
                        i_organization_id      => tl.internal_organization_id,
                        i_starting_date        => g_starting_date -- global variable which you got in 1st step
                                                                 ,
                        i_tax_date             => tl.tax_determination_date,
                        io_authority_mapping   => l_authority_mapping);
                RETURN l_tax_code;
            EXCEPTION
                WHEN OTHERS                                     --NO_RATE_CODE
                THEN
                    x_ret_msg   :=
                           'EXCEPTION(NO_RATE_CODE):ERP Tax Code['
                        || tl.erp_tax_code
                        || '];Operating Unit['
                        || tl.internal_organization_id
                        || '];Authority Name['
                        || SUBSTR (tl.authority_name, 1, 100)
                        || '];UUID['
                        || tl.authority_uuid
                        || ']';
                    print_log (x_ret_msg); -- replace with your print log procedure
                    --raise NO_RATE_CODE;
                    RETURN NULL;
            END;
        END LOOP;
    END get_tax_code_new;

    FUNCTION get_ledger (p_seg_val IN VARCHAR2, x_ledger_id OUT NUMBER, x_ledger_name OUT VARCHAR2
                         , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT DISTINCT ledger_id, ledger_name
          INTO x_ledger_id, x_ledger_name
          FROM xle_le_ou_ledger_v
         WHERE legal_entity_identifier = p_seg_val;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                ' No Ledger found for the Balancing Segment: ' || p_seg_val;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' Multiple Ledgers found for Balancing Segment: '
                || p_seg_val;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                ' Exception found for Balancing Segment: ' || SQLERRM;
            RETURN FALSE;
    END get_ledger;

    PROCEDURE update_prc (p_batch_id IN NUMBER)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;

        lv_db_name   VARCHAR2 (10);
    BEGIN
        lv_db_name     := NULL;

        gv_location    := 'update_inv';
        gv_procedure   := 'update_inv_prc';

        BEGIN
            SELECT name INTO lv_db_name FROM v$database;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_db_name   := 'NONPROD';
        END;

        debug_log_prc (p_batch_id, 'update_inv', 'update_inv_prc',
                       'upd start with db as - ' || lv_db_name);

        UPDATE sabrix_invoice
           SET (username, password)   =
                   (SELECT flvv.description username, flvv.tag pwd
                      FROM fnd_lookup_values_vl flvv
                     WHERE     flvv.lookup_type = 'XXD_AR_SBX_CONN_DTLS_LKP'
                           AND flvv.lookup_code =
                               DECODE (lv_db_name,
                                       'EBSPROD', 'EBSPROD',
                                       'NONPROD')
                           AND flvv.enabled_flag = 'Y'
                           AND TRUNC (SYSDATE) BETWEEN NVL (
                                                           flvv.start_date_active,
                                                           TRUNC (SYSDATE))
                                                   AND NVL (
                                                           flvv.end_date_active,
                                                           TRUNC (SYSDATE))) --      UPDATE sabrix_invoice
         WHERE batch_id = p_batch_id;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_log_prc (p_batch_id, gv_procedure, gv_location,
                           'Error updating inv' || SQLERRM);
    END update_prc;

    FUNCTION get_cntry_geo_fnc (pv_geo IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_country   VARCHAR2 (100);
    BEGIN
        lv_country   := NULL;

        SELECT ffvl.description
          INTO lv_country
          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
         WHERE     1 = 1
               AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
               AND ffvl.enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (ffvl.start_date_active, SYSDATE)
                               AND NVL (ffvl.end_date_active, SYSDATE + 1)
               AND ffvs.flex_value_set_name = 'XXD_SBX_VAT_GEO_CNTRY_VS'
               AND ffvl.flex_value = pv_geo;

        RETURN lv_country;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_cntry_geo_fnc;


    PROCEDURE insert_data (x_ret_msg OUT NOCOPY VARCHAR2, x_ret_code OUT NOCOPY VARCHAR2, pn_ledger_id IN NUMBER, pv_period_name IN VARCHAR2, pv_source IN VARCHAR2, pv_category IN VARCHAR2
                           , pv_journal_name IN VARCHAR2)
    IS
        CURSOR cur_jor_hdr IS
            SELECT gjh.*
              FROM apps.gl_je_headers gjh, apps.gl_je_sources gjs, apps.gl_je_categories gjc
             WHERE     1 = 1
                   AND gjh.ledger_id = pn_ledger_id
                   AND gjh.period_name = pv_period_name
                   AND gjs.je_source_name = gjh.je_source
                   AND gjs.je_source_name =
                       NVL (pv_source, gjs.je_source_name)
                   AND gjc.je_category_name = gjh.je_category
                   AND gjc.je_category_name =
                       NVL (pv_category, gjc.je_category_name)
                   AND gjh.name = NVL (pv_journal_name, gjh.name)
                   AND gjh.status = 'P'
                   --AND gjh.je_header_id IN (1681823986, 1681826984)
                   --AND gjh.je_header_id = 1681810792 --1681808788;--1681801788;--1681807788;--1681801788;
                   AND EXISTS
                           (SELECT 1
                              FROM apps.gl_je_lines gjl
                             WHERE     gjl.je_header_id = gjh.je_header_id
                                   AND gjl.context = 'Manual Journal'
                                   AND NVL (gjl.attribute4, 'N') = 'Y'
                                   AND NVL (gjl.attribute5, 'N') IN
                                           ('N', 'E'));

        CURSOR cur_man_jor_line (p_je_header_id IN NUMBER)
        IS
            SELECT gcc.segment3 geo, gcc.segment6 nat_acc, get_cntry_geo_fnc (gcc.segment3) bt_country,
                   NVL (gjl.attribute3, get_cntry_geo_fnc (gcc.segment3)) country, --get_ledger (gcc.segment1) ledger_id,
                                                                                   gjl.*
              FROM apps.gl_je_lines gjl, apps.gl_code_combinations gcc
             WHERE     1 = 1
                   AND gjl.je_header_id = p_je_header_id
                   AND gjl.context = 'Manual Journal'
                   AND NVL (gjl.attribute4, 'N') = 'Y'
                   AND NVL (gjl.attribute5, 'N') IN ('N', 'E')
                   AND gcc.code_combination_id = gjl.code_combination_id;

        CURSOR cur_cm_jor_hdr IS
              SELECT gjh.je_header_id, gjh.currency_code, gjh.running_total_accounted_dr,
                     gjh.running_total_dr, gjh.default_effective_date, csh.statement_date,
                     gjh.ledger_id, gjh.je_category
                FROM apps.gl_je_lines gjl, apps.gl_je_headers gjh, apps.gl_je_sources gjs,
                     apps.gl_je_categories gjc, apps.gl_import_references gir, apps.xla_ae_lines xal,
                     apps.xla_ae_headers xah, apps.ce_cashflow_acct_h hist, apps.ce_statement_lines csl,
                     apps.ce_statement_headers csh, apps.ce_cashflows ccf, apps.ce_transaction_codes ctc,
                     apps.ce_je_mappings cjm, apps.gl_code_combinations gcc
               WHERE     1 = 1
                     AND gir.je_header_id = gjl.je_header_id
                     AND gjh.je_header_id = gjl.je_header_id
                     --                  AND gjh.je_source IN ('Cash Management')
                     AND gjh.name = NVL (pv_journal_name, gjh.name)
                     AND gjh.ledger_id = pn_ledger_id
                     AND gjh.period_name = pv_period_name
                     AND gjs.je_source_name = gjh.je_source
                     AND gjs.je_source_name =
                         NVL (pv_source, gjs.je_source_name)
                     AND gjc.je_category_name = gjh.je_category
                     AND gjc.je_category_name =
                         NVL (pv_category, gjc.je_category_name)
                     AND gir.je_line_num = gjl.je_line_num
                     AND gjl.code_combination_id = gcc.code_combination_id
                     AND gir.gl_sl_link_id = xal.gl_sl_link_id
                     AND gjh.status = 'P'
                     AND xal.ae_header_id = xah.ae_header_id
                     AND hist.event_id = xah.event_id
                     --AND xal.accounting_class_code <> 'CASH'
                     AND csl.cashflow_id = hist.cashflow_id
                     AND hist.cashflow_id = ccf.cashflow_id
                     AND csh.statement_header_id = csl.statement_header_id
                     AND ctc.trx_code = csl.trx_code
                     AND ctc.bank_account_id = csh.bank_account_id
                     AND csl.trx_text LIKE cjm.SEARCH_STRING_TXT
                     AND cjm.trx_code_id = ctc.transaction_code_id
                     AND ctc.bank_account_id = cjm.bank_account_id
                     AND gcc.code_combination_id = cjm.gl_account_ccid
                     AND NVL (gjl.attribute5, 'N') IN ('N', 'E')
                     AND cjm.reference_txt IS NOT NULL
            --                     AND gir.je_header_id = 1680886985               --1680887070
            GROUP BY gjh.je_header_id, gjh.currency_code, gjh.running_total_accounted_dr,
                     gjh.running_total_dr, gjh.default_effective_date, csh.statement_date,
                     gjh.ledger_id, gjh.je_category;

        CURSOR cur_cm_jor_dtls (pn_header_id IN NUMBER, pd_stat_date IN DATE)
        IS
            SELECT gcc.segment3 geo,
                   gcc.segment6 nat_acc,
                   REGEXP_SUBSTR (cjm.reference_txt, '[^.]+', 1,
                                  2) vat_reg_num,
                   NVL (REGEXP_SUBSTR (cjm.reference_txt, '[^.]+', 1,
                                       1),
                        get_cntry_geo_fnc (gcc.segment3)) country,
                   get_cntry_geo_fnc (gcc.segment3) bt_country,
                   gjl.*
              FROM apps.gl_je_lines gjl, apps.gl_import_references gir, apps.xla_ae_lines xal,
                   apps.xla_ae_headers xah, apps.ce_cashflow_acct_h hist, apps.ce_statement_lines csl,
                   apps.ce_statement_headers csh, apps.ce_cashflows ccf, apps.ce_transaction_codes ctc,
                   apps.ce_je_mappings cjm, apps.gl_code_combinations gcc
             WHERE     1 = 1
                   AND gir.je_header_id = gjl.je_header_id
                   AND gir.je_line_num = gjl.je_line_num
                   AND gjl.code_combination_id = gcc.code_combination_id
                   AND gir.gl_sl_link_id = xal.gl_sl_link_id
                   AND xal.ae_header_id = xah.ae_header_id
                   AND hist.event_id = xah.event_id
                   --AND xal.accounting_class_code <> 'CASH'
                   AND csl.cashflow_id = hist.cashflow_id
                   AND hist.cashflow_id = ccf.cashflow_id
                   AND csh.statement_header_id = csl.statement_header_id
                   AND ctc.trx_code = csl.trx_code
                   AND ctc.bank_account_id = csh.bank_account_id
                   AND csl.trx_text LIKE cjm.search_string_txt
                   --   AND cjm.SEARCH_STRING_TXT like csl.trx_text
                   AND cjm.trx_code_id = ctc.transaction_code_id
                   AND ctc.bank_account_id = cjm.bank_account_id
                   AND cjm.reference_txt IS NOT NULL
                   AND gcc.code_combination_id = cjm.gl_account_ccid
                   AND NVL (gjl.attribute5, 'N') IN ('N', 'E')
                   AND gir.je_header_id = pn_header_id
                   AND csh.statement_date = pd_stat_date;

        --                AND gir.je_header_id = 1680886985;               --1680887070;

        --      CURSOR cur_tax_call (
        --         pn_je_header_id IN NUMBER)
        --      IS
        --         SELECT DISTINCT batch_id
        --           FROM apps.sabrix_invoice
        --          WHERE     invoice_number = TO_CHAR (pn_je_header_id)
        --                AND calling_system_number = 101;

        --AND user_element_attribute3 IS NULL;

        ln_seq               NUMBER;
        ln_appl_id           NUMBER;
        lv_db_name           VARCHAR2 (20);
        ln_org_id            NUMBER;
        lv_seg1              gl_code_combinations.segment1%TYPE;
        lv_seg2              gl_code_combinations.segment2%TYPE;
        ln_err_count         NUMBER;
        lv_message_text      VARCHAR2 (2000);
        lv_comp_identifier   VARCHAR2 (100);
        ln_test              VARCHAR2 (100);
    BEGIN
        ln_seq               := NULL;
        ln_appl_id           := NULL;
        lv_db_name           := NULL;
        lv_seg1              := NULL;
        lv_seg2              := NULL;
        ln_err_count         := 0;
        lv_message_text      := NULL;
        lv_comp_identifier   := NULL;
        ln_test              := NULL;

        BEGIN
            SELECT application_id
              INTO ln_appl_id
              FROM apps.fnd_application
             WHERE 1 = 1 AND application_short_name = 'SQLGL';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_appl_id   := NULL;
        END;

        print_log ('Application ID - ' || ln_appl_id);
        print_log ('Application HOST Identifier - ' || gv_host);

        BEGIN
            SELECT name
              INTO lv_db_name
              FROM v$database
             WHERE 1 = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_db_name   := NULL;
        END;

        print_log ('DB Name - ' || ln_appl_id);

        Print_log (' Set the Connection Details');

        sabrix_config.setConnection ('IntegrationP2P');

        print_log (
               ' Get the Connection details sabrix_config.getConnectionCalcUrl - '
            || sabrix_config.getConnectionCalcUrl);



        IF pv_source IN ('Manual', 'Spreadsheet')
        THEN
            print_log ('Source Name is  - ' || pv_source);

            FOR hdr IN cur_jor_hdr
            LOOP
                ln_seq               := NULL;
                lv_seg1              := NULL;
                lv_seg2              := NULL;
                ln_org_id            := NULL;
                lv_comp_identifier   := NULL;
                ln_test              := NULL;

                SELECT SABRIX_BATCH_SEQ.NEXTVAL INTO ln_seq FROM DUAL;

                print_log ('Journal Header ID is  - ' || hdr.je_header_id);

                print_log ('Sabrix Sequence is  - ' || ln_seq);

                --- Whether this can be a part of multiple GEO's associated with 500

                BEGIN
                    SELECT gcc.segment1, gcc.segment3
                      INTO lv_seg1, lv_seg2
                      FROM apps.gl_je_lines gjl, apps.gl_code_combinations gcc
                     WHERE     gjl.je_header_id = hdr.je_header_id
                           AND gjl.code_combination_id =
                               gcc.code_combination_id
                           AND gjl.ledger_id = hdr.ledger_id
                           AND ROWNUM = 1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_seg1   := NULL;
                        lv_seg2   := NULL;
                END;

                print_log (
                    'Derived Company based on Ledger is   - ' || lv_seg1);

                IF lv_seg1 IS NOT NULL AND lv_seg1 = '110'
                THEN
                    ln_org_id   := 104;
                ELSIF lv_seg1 IS NOT NULL AND lv_seg1 <> '500'
                THEN
                    -- Fetch the OU based on the Company
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
                               AND lep.legal_entity_id =
                                   hro.default_legal_context_id
                               AND lep.legal_entity_identifier = lv_seg1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_org_id   := NULL;
                    END;
                ELSIF lv_seg1 = '500' AND lv_seg2 IN ('502', '504')
                THEN
                    ln_org_id   := 953;
                END IF;

                print_log (
                       'Derived Operating Unit based on Company is   - '
                    || ln_org_id);

                lv_comp_identifier   := gv_host || lv_seg1;

                print_log (
                    'External HOST Identifier - ' || lv_comp_identifier);

                BEGIN
                    INSERT INTO apps.sabrix_invoice (
                                    batch_id,
                                    invoice_id,
                                    creation_date,
                                    calling_system_number,
                                    host_system,
                                    external_company_id,
                                    merchant_role,
                                    calculation_direction,
                                    currency_code,
                                    gross_amount,
                                    invoice_date,
                                    invoice_number,
                                    is_audited,
                                    transaction_type,
                                    is_audit_update,
                                    unique_invoice_number,
                                    user_element_attribute1,
                                    user_element_attribute2,
                                    user_element_attribute45,
                                    user_element_attribute49)
                         VALUES (ln_seq, gn_invoice_id, gv_date,
                                 ln_appl_id, lv_db_name, lv_seg1, --lv_comp_identifier,--lv_seg1,                     --lv_comp_identifier,
                                 gv_merch_role, gv_calc_dir, hdr.currency_code, hdr.running_total_dr, hdr.default_effective_date, hdr.je_header_id, gv_audit_flag, gv_trx_type, gv_audit_flag, hdr.je_header_id, hdr.je_category, gv_journal
                                 , ln_org_id, ln_appl_id);

                    print_log ('Data Insertion into Sabrix Invoice is Done');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        print_log (
                               'Exception While Data Insertion into Sabrix Invoice for Manual Source- '
                            || SQLERRM);
                END;

                FOR line IN cur_man_jor_line (hdr.je_header_id)
                LOOP
                    UPDATE apps.gl_je_lines
                       SET attribute7   = gn_conc_request_id
                     WHERE     je_header_id = hdr.je_header_id
                           AND je_line_num = line.je_line_num;

                    COMMIT;

                    BEGIN
                        print_log (
                            'Start of Data Insertion into Sabrix Line');

                        INSERT INTO sabrix_line (batch_id, invoice_id, line_id, creation_date, bt_country, bp_country, gross_amount, inclusive_tax_fully_inclusive, line_number, product_code, quantity, sp_country, sf_country, st_country, su_country, transaction_type, gross_plus_tax, unique_line_number, unit_of_measure, user_element_attribute1, user_element_attribute2
                                                 , user_element_attribute3)
                             VALUES (ln_seq, gn_invoice_id, line.je_line_num,
                                     gv_date, line.bt_country, line.bt_country, NVL (line.entered_dr, line.entered_cr), gv_tax_flag, line.je_line_num, line.nat_acc, gn_qty, line.country, --NVL (line.attribute3, line.country),
                                                                                                                                                                                           line.country, --NVL (line.attribute3, line.country),
                                                                                                                                                                                                         line.bt_country, line.bt_country, gv_trx_type, NVL (line.entered_dr, line.entered_cr), line.je_line_num, gv_uom, hdr.je_header_id, line.je_line_num
                                     , line.nat_acc);

                        print_log ('Data Insertion into Sabrix Line is Done');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            print_log (
                                   'Exception While Data Insertion into Sabrix Line for Manual Source - '
                                || SQLERRM);
                    END;

                    BEGIN
                        print_log (
                            'Start of Data Insertion into Sabrix Registration');

                        INSERT INTO sabrix_registration (batch_id,
                                                         invoice_id,
                                                         line_id,
                                                         merchant_role,
                                                         creation_date,
                                                         registration_number)
                             VALUES (ln_seq, gn_invoice_id, line.je_line_num,
                                     'S', gv_date, line.attribute2 -- Line DFF has to be set
                                                                  );

                        print_log (
                            'Data Insertion into Sabrix Registration is Done');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            print_log (
                                   'Exception While Data Insertion into Sabrix Registration for Manual Source - '
                                || SQLERRM);
                    END;

                    COMMIT;

                    update_prc (ln_seq);

                    ln_test           := NULL;

                    print_log (
                        'Tetsing the External Company ID Recorded before Tax call and after Insert');

                    BEGIN
                        SELECT external_company_id
                          INTO ln_test
                          FROM apps.sabrix_invoice
                         WHERE batch_id = ln_seq;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            NULL;
                            print_log (
                                'Tetsing the External Company IS NULL Exception before tax call');
                    END;

                    print_log (
                           'Tetsing the External Company ID Recorded before Tax call and after Insert value is - '
                        || ln_test);


                    print_log ('Start of Tax Call');

                    print_log (
                           'Tax call for Batch ID  - '
                        || ln_seq
                        || ' With JE_HEADER_ID as - '
                        || hdr.je_header_id);

                    sabrix_adapter.calculate (ln_seq);

                    ln_err_count      := 0;

                    lv_message_text   := NULL;

                    BEGIN
                        SELECT COUNT (1), MESSAGE_TEXT
                          INTO ln_err_count, lv_message_text
                          FROM sabrix_message
                         WHERE     batch_id = ln_seq
                               AND Severity = 2
                               AND ROWNUM = 1; -- Check this, if there can be multiple severity error messages
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_err_count   := 0;
                    END;

                    IF ln_err_count = 0
                    THEN
                        BEGIN
                            print_log (
                                   'Tax call for Batch ID  - '
                                || ln_seq
                                || ' With JE_HEADER_ID as - '
                                || hdr.je_header_id);

                            process_gl_data_prc (ln_seq,
                                                 x_ret_msg,
                                                 x_ret_code);
                        END;
                    ELSE
                        UPDATE apps.gl_je_lines
                           SET attribute5 = 'E', attribute6 = SUBSTR (lv_message_text, 1, 150)
                         WHERE     je_header_id = hdr.je_header_id
                               AND je_line_num = line.je_line_num
                               AND attribute7 = gn_conc_request_id;

                        print_log (
                               'Please check Sabrix_message Error of Sev2 with batch id - '
                            || ln_seq);
                    END IF;
                END LOOP;

                /*update_prc (ln_seq);

                ln_test := NULL;

                print_log (
                   'Tetsing the External Company ID Recorded before Tax call and after Insert');

                BEGIN
                   SELECT external_company_id
                     INTO ln_test
                     FROM apps.sabrix_invoice
                    WHERE batch_id = ln_seq;
                EXCEPTION
                   WHEN OTHERS
                   THEN
                      NULL;
                      print_log (
                         'Tetsing the External Company IS NULL Exception before tax call');
                END;

                print_log (
                      'Tetsing the External Company ID Recorded before Tax call and after Insert value is - '
                   || ln_test);


                print_log ('Start of Tax Call');

                print_log ('Tax call for Batch ID  - '|| ln_seq|| ' With JE_HEADER_ID as - '|| hdr.je_header_id);

                sabrix_adapter.calculate (ln_seq);

                ln_err_count := 0;

                BEGIN
                   SELECT COUNT (1),message_text
                     INTO ln_err_count,lv_message_text
                     FROM sabrix_message
                    WHERE batch_id = ln_seq AND Severity = 2
                      AND rownum = 1; -- Check this, if there can be multiple severity error messages
                EXCEPTION
                   WHEN OTHERS
                   THEN
                      ln_err_count := 0;
                END;

                IF ln_err_count = 0
                THEN
                   BEGIN
                      print_log (
                            'Tax call for Batch ID  - '
                         || ln_seq
                         || ' With JE_HEADER_ID as - '
                         || hdr.je_header_id);
                      process_gl_data_prc (ln_seq, x_ret_msg, x_ret_code);
                   END;
                ELSE

                   UPDATE   apps.gl_je_lines
                      SET   attribute5 = 'E',
                            attribute6 = SUBSTR(lv_message_text,1,150)
                    WHERE   je_header_id = hdr.je_header_id;
                   print_log (
                         'Please check Sabrix_message Error of Sev2 with batch id - '
                      || ln_seq);
                --
                --                BEGIN
                --                    UPDATE sabrix_invoice
                --                       SET user_element_attribute3 = 'E'
                --                     WHERE batch_id = btch.batch_id;
                --                COMMIT;
                --                END;


                END IF; */

                --            BEGIN
                --                UPDATE apps.gl_je_lines
                --                  SET  attribute5 = 'Y'
                --                 WHERE je_header_id = cm_line.je_header_id
                --                   AND je_line_num = cm_line.je_line_num;
                --
                --               END;
                --
                --               COMMIT;

                print_log ('End of Tax call and Insertion into Interface');

                print_log (
                    'Tetsing the External Company ID Recorded After Tax call and after Insert');

                ln_test              := NULL;

                BEGIN
                    SELECT external_company_id
                      INTO ln_test
                      FROM apps.sabrix_invoice
                     WHERE batch_id = ln_seq;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                        print_log (
                            'Tetsing the External Company IS NULL Exception After tax call');
                END;

                print_log (
                       'Tetsing the External Company ID Recorded After Tax call and after Insert value is - '
                    || ln_test);
            END LOOP;
        ELSIF pv_source = 'Cash Management'
        THEN
            print_log ('Source Name is  - ' || pv_source);

            FOR cm_hdr IN cur_cm_jor_hdr
            LOOP
                ln_seq               := NULL;
                lv_seg1              := NULL;
                lv_seg2              := NULL;
                ln_org_id            := NULL;
                lv_comp_identifier   := NULL;

                SELECT SABRIX_BATCH_SEQ.NEXTVAL INTO ln_seq FROM DUAL;

                print_log (
                    'CM Journal Header ID is  - ' || cm_hdr.je_header_id);

                print_log ('CM Sabrix Sequence is  - ' || ln_seq);

                BEGIN
                    SELECT gcc.segment1, gcc.segment3
                      INTO lv_seg1, lv_seg2
                      FROM apps.gl_je_lines gjl, apps.gl_code_combinations gcc
                     WHERE     gjl.je_header_id = cm_hdr.je_header_id
                           AND gjl.code_combination_id =
                               gcc.code_combination_id
                           AND gjl.ledger_id = cm_hdr.ledger_id
                           AND ROWNUM = 1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_seg1   := NULL;
                        lv_seg2   := NULL;
                END;

                print_log (
                    'CM Derived Company based on Ledger is   - ' || lv_seg1);

                IF lv_seg1 IS NOT NULL AND lv_seg1 = '110'
                THEN
                    ln_org_id   := 104;
                ELSIF lv_seg1 IS NOT NULL AND lv_seg1 <> '500'
                THEN
                    -- Fetch the OU based on the Company
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
                               AND lep.legal_entity_id =
                                   hro.default_legal_context_id
                               AND lep.legal_entity_identifier = lv_seg1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_org_id   := NULL;
                    END;
                ELSIF lv_seg1 = '500' AND lv_seg2 IN ('502', '504')
                THEN
                    ln_org_id   := 953;
                END IF;

                print_log (
                       'CM Derived Operating Unit based on Company is   - '
                    || ln_org_id);

                lv_comp_identifier   := gv_host || lv_seg1;

                print_log (
                    'CM External HOST Identifier - ' || lv_comp_identifier);

                --                IF lv_seg1 IS NOT NULL AND lv_seg1 <> '500'
                --                THEN
                --                    -- Fetch the OU based on the Company
                --                    BEGIN
                --                        SELECT hro.organization_id
                --                          INTO ln_org_id
                --                          FROM apps.xle_entity_profiles  lep,
                --                               apps.xle_registrations    reg,
                --                               apps.hr_locations_all     hrl,
                --                               apps.gl_ledgers           gl,
                --                               apps.hr_operating_units   hro
                --                         WHERE     lep.transacting_entity_flag = 'Y'
                --                               AND lep.legal_entity_id = reg.source_id
                --                               AND reg.source_table = 'XLE_ENTITY_PROFILES'
                --                               AND hrl.location_id = reg.location_id
                --                               AND reg.identifying_flag = 'Y'
                --                               AND hro.set_of_books_id = gl.ledger_id
                --                               AND lep.legal_entity_id =
                --                                   hro.default_legal_context_id
                --                               AND lep.legal_entity_identifier = lv_seg1;
                --                    EXCEPTION
                --                        WHEN OTHERS
                --                        THEN
                --                            ln_org_id := NULL;
                --                    END;
                --                ELSIF lv_seg1 = '500' AND lv_seg2 IN ('502', '504')
                --                THEN
                --                    ln_org_id := 953;
                --                END IF;

                BEGIN
                    INSERT INTO apps.sabrix_invoice (
                                    batch_id,
                                    invoice_id,
                                    creation_date,
                                    calling_system_number,
                                    host_system,
                                    external_company_id,
                                    merchant_role,
                                    calculation_direction,
                                    currency_code,
                                    gross_amount,
                                    invoice_date,
                                    invoice_number,
                                    is_audited,
                                    transaction_type,
                                    is_audit_update,
                                    unique_invoice_number,
                                    user_element_attribute1,
                                    user_element_attribute2,
                                    user_element_attribute45,
                                    user_element_attribute49)
                         VALUES (ln_seq, gn_invoice_id, gv_date,
                                 ln_appl_id, lv_db_name, lv_seg1, --lv_comp_identifier,--lv_seg1,                        --gv_host || lv_seg1,
                                 gv_merch_role, gv_calc_dir, cm_hdr.currency_code, cm_hdr.running_total_dr, cm_hdr.statement_date, cm_hdr.je_header_id, gv_audit_flag, gv_trx_type, gv_audit_flag, cm_hdr.je_header_id, cm_hdr.je_category, gv_journal
                                 , ln_org_id, ln_appl_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        print_log (
                               'Exception While Data Insertion into Sabrix Invoice for CM Source - '
                            || SQLERRM);
                END;

                FOR cm_line
                    IN cur_cm_jor_dtls (cm_hdr.je_header_id,
                                        cm_hdr.statement_date)
                LOOP
                    UPDATE apps.gl_je_lines
                       SET attribute7   = gn_conc_request_id
                     WHERE     je_header_id = cm_hdr.je_header_id
                           AND je_line_num = cm_line.je_line_num;

                    COMMIT;

                    BEGIN
                        print_log (
                            'Start of Data Insertion into Sabrix Line');

                        INSERT INTO sabrix_line (
                                        batch_id,
                                        invoice_id,
                                        line_id,
                                        creation_date,
                                        bt_country,
                                        bp_country,
                                        gross_amount,
                                        inclusive_tax_fully_inclusive,
                                        line_number,
                                        product_code,
                                        quantity,
                                        sp_country,
                                        sf_country,
                                        st_country,
                                        su_country,
                                        transaction_type,
                                        gross_plus_tax,
                                        unique_line_number,
                                        unit_of_measure,
                                        user_element_attribute1,
                                        user_element_attribute2,
                                        user_element_attribute3,
                                        user_element_attribute4)
                             VALUES (ln_seq, gn_invoice_id, cm_line.je_line_num, gv_date, cm_line.bt_country, cm_line.bt_country, NVL (cm_line.entered_dr, cm_line.entered_cr), gv_tax_flag, cm_line.je_line_num, cm_line.nat_acc, gn_qty, cm_line.country, cm_line.country, cm_line.bt_country, cm_line.bt_country, gv_trx_type, NVL (cm_line.entered_dr, cm_line.entered_cr), cm_line.je_line_num, gv_uom, cm_hdr.je_header_id, cm_line.je_line_num
                                     , cm_line.nat_acc, ln_org_id);

                        print_log (
                            'CM Data Insertion into Sabrix Line is Done');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            print_log (
                                   'Exception While Data Insertion into Sabrix line for CM Source - '
                                || SQLERRM);
                    END;

                    BEGIN
                        print_log (
                            'CM Start of Data Insertion into Sabrix Registration');

                        INSERT INTO sabrix_registration (batch_id,
                                                         invoice_id,
                                                         line_id,
                                                         merchant_role,
                                                         creation_date,
                                                         registration_number)
                             VALUES (ln_seq, gn_invoice_id, cm_line.je_line_num
                                     , 'S', gv_date, cm_line.vat_reg_num -- Line DFF has to be set
                                                                        );

                        print_log (
                            'CM Data Insertion into Sabrix Registration is Done');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            print_log (
                                   'Exception While Data Insertion into Sabrix Registration for CM Source - '
                                || SQLERRM);
                    END;

                    COMMIT;

                    update_prc (ln_seq);

                    print_log ('Start of Tax Call for CM');

                    print_log (
                           'Tax call for CM Batch ID  - '
                        || ln_seq
                        || ' With JE_HEADER_ID as - '
                        || cm_hdr.je_header_id);

                    --            tax_call_prc (ln_seq);

                    sabrix_adapter.calculate (ln_seq);

                    ln_err_count      := 0;

                    lv_message_text   := NULL;

                    BEGIN
                        SELECT COUNT (1), MESSAGE_TEXT
                          INTO ln_err_count, lv_message_text
                          FROM sabrix_message
                         WHERE     batch_id = ln_seq
                               AND Severity = 2
                               AND ROWNUM = 1; -- Check this, if there can be multiple severity error messages
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_err_count   := 0;
                    END;

                    IF ln_err_count = 0
                    THEN
                        BEGIN
                            print_log (
                                   'Tax call for Batch ID  - '
                                || ln_seq
                                || ' With JE_HEADER_ID as - '
                                || cm_hdr.je_header_id);

                            process_gl_data_prc (ln_seq,
                                                 x_ret_msg,
                                                 x_ret_code);
                        END;
                    --               BEGIN
                    --                UPDATE apps.gl_je_lines
                    --                  SET  attribute5 = 'Y'
                    --                 WHERE je_header_id = cm_line.je_header_id
                    --                   AND je_line_num = cm_line.je_line_num;
                    --
                    --               END;
                    --
                    --               COMMIT;

                    ELSE
                        print_log (
                               'Please check Sabrix_message Error of Sev2 with batch id - '
                            || ln_seq);

                        UPDATE apps.gl_je_lines
                           SET attribute5 = 'E', attribute6 = SUBSTR (lv_message_text, 1, 150)
                         WHERE     je_header_id = cm_hdr.je_header_id
                               AND je_line_num = cm_line.je_line_num
                               AND attribute7 = gn_conc_request_id;

                        print_log (
                               'Please check Sabrix_message Error of Sev2 with batch id - '
                            || ln_seq);
                    END IF;
                END LOOP;

                /*COMMIT;

                update_prc (ln_seq);

                print_log ('Start of Tax Call for CM');

                print_log (
                      'Tax call for CM Batch ID  - '
                   || ln_seq
                   || ' With JE_HEADER_ID as - '
                   || cm_hdr.je_header_id);

                --            tax_call_prc (ln_seq);

                sabrix_adapter.calculate (ln_seq);

                ln_err_count := 0;

                BEGIN
                   SELECT COUNT (1)
                     INTO ln_err_count
                     FROM sabrix_message
                    WHERE batch_id = ln_seq AND Severity = 2;
                EXCEPTION
                   WHEN OTHERS
                   THEN
                      ln_err_count := 0;
                END;

                IF ln_err_count = 0
                THEN
                   BEGIN
                      print_log (
                            'Tax call for Batch ID  - '
                         || ln_seq
                         || ' With JE_HEADER_ID as - '
                         || cm_hdr.je_header_id);
                      process_gl_data_prc (ln_seq, x_ret_msg, x_ret_code);
                   END;
                --               BEGIN
                --                UPDATE apps.gl_je_lines
                --                  SET  attribute5 = 'Y'
                --                 WHERE je_header_id = cm_line.je_header_id
                --                   AND je_line_num = cm_line.je_line_num;
                --
                --               END;
                --
                --               COMMIT;

                ELSE
                   print_log (
                         'Please check Sabrix_message Error of Sev2 with batch id - '
                      || ln_seq);
                --
                --                BEGIN
                --                    UPDATE sabrix_invoice
                --                       SET user_element_attribute3 = 'E'
                --                     WHERE batch_id = btch.batch_id;
                --                COMMIT;
                --                END;


                END IF; */

                print_log ('End of Tax call and Insertion into Interface');
            END LOOP;
        END IF;

        print_log ('End of the Program');
    END;

    PROCEDURE tax_call_prc (pn_batch_id IN NUMBER)
    IS
        CURSOR cur_batch IS
              SELECT batch_id
                FROM sabrix_invoice
               WHERE 1 = 1 AND batch_id = pn_batch_id
            --  AND user_element_attribute3 IS NULL
            GROUP BY batch_id
            ORDER BY batch_id DESC;
    BEGIN
        FOR btch IN cur_batch
        LOOP
            sabrix_adapter.calculate (btch.batch_id);
        END LOOP;
    END;

    PROCEDURE MAIN_PRC (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, pn_ledger_id IN VARCHAR2, pv_period_name IN VARCHAR2, pv_source IN VARCHAR2, pv_category IN VARCHAR2
                        , pv_journal_name IN VARCHAR2)
    IS
        l_ret_code      VARCHAR2 (10);
        l_err_msg       VARCHAR2 (4000);
        ex_insert_stg   EXCEPTION;
    BEGIN
        print_log (' Start of the Program ');

        insert_data (l_err_msg, l_ret_code, pn_ledger_id,
                     pv_period_name, pv_source, pv_category,
                     pv_journal_name);

        IF l_ret_code = '2'
        THEN
            RAISE ex_insert_stg;
        END IF;

        print_log (' Staging is complete now display only :' || l_err_msg);

        display_output;
    EXCEPTION
        WHEN ex_insert_stg
        THEN
            errbuf    := l_err_msg;
            retcode   := l_ret_code;
            print_log (' Error Inserting data into Staging:' || l_err_msg);
        WHEN OTHERS
        THEN
            print_log (' Exception in Main - ' || SQLERRM);
    END;

    FUNCTION get_tax_ccid (pv_tax_code   IN     VARCHAR2,
                           pn_org_id     IN     NUMBER,
                           x_tax_ccid       OUT NUMBER)
        RETURN BOOLEAN
    IS
    BEGIN
        x_tax_ccid   := NULL;

        SELECT tax_account_ccid
          INTO x_tax_ccid
          FROM zx_rates_vl zxr, zx_accounts b, hr_operating_units hou
         WHERE     b.internal_organization_id = hou.organization_id
               AND hou.organization_id = pn_org_id
               AND b.tax_account_entity_code = 'RATES'
               AND b.tax_account_entity_id = zxr.tax_rate_id
               AND zxr.active_flag = 'Y'
               AND zxr.tax_rate_code = pv_tax_code
               AND SYSDATE BETWEEN zxr.effective_from
                               AND NVL (zxr.effective_to, SYSDATE);

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_tax_ccid   := NULL;
            RETURN FALSE;
    END;

    FUNCTION get_code_comb (p_ccid   IN     NUMBER,
                            x_seg1      OUT VARCHAR2,
                            x_seg2      OUT VARCHAR2,
                            x_seg3      OUT VARCHAR2,
                            x_seg4      OUT VARCHAR2,
                            x_seg5      OUT VARCHAR2,
                            x_seg6      OUT VARCHAR2,
                            x_seg7      OUT VARCHAR2,
                            x_seg8      OUT VARCHAR2                       --,
                                                    --x_ret_msg      OUT VARCHAR2
                                                    )
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT segment1, segment2, segment3,
               segment4, segment5, segment6,
               segment7, segment8
          INTO x_seg1, x_seg2, x_seg3, x_seg4,
                     x_seg5, x_seg6, x_seg7,
                     x_seg8
          FROM apps.gl_code_combinations_kfv
         WHERE     1 = 1
               AND NVL (enabled_flag, 'N') = 'Y'
               AND code_combination_id = p_ccid;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_seg1   := NULL;
            x_seg2   := NULL;
            x_seg3   := NULL;
            x_seg4   := NULL;
            x_seg5   := NULL;
            x_seg6   := NULL;
            x_seg7   := NULL;
            x_seg8   := NULL;
            --x_ret_msg := ' Please check the Code Combination provided ' || p_ccid;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            --         x_ret_msg :=
            --            ' Multiple Code Combinations exist with same the same set';
            x_seg1   := NULL;
            x_seg2   := NULL;
            x_seg3   := NULL;
            x_seg4   := NULL;
            x_seg5   := NULL;
            x_seg6   := NULL;
            x_seg7   := NULL;
            x_seg8   := NULL;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            --         x_ret_msg := ' ' || 'Invalid Code Combination: ' || SQLERRM;
            x_seg1   := NULL;
            x_seg2   := NULL;
            x_seg3   := NULL;
            x_seg4   := NULL;
            x_seg5   := NULL;
            x_seg6   := NULL;
            x_seg7   := NULL;
            x_seg8   := NULL;

            RETURN FALSE;
    END get_code_comb;

    FUNCTION get_tax_code (pv_tax_code IN VARCHAR2, x_tax_code OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        x_tax_code   := NULL;

        SELECT tax_flow
          INTO x_tax_code
          FROM sabrix_authority_mapping
         WHERE     1 = 1
               AND workflow = 'P2P'
               AND direction = 'I'
               AND erp_tax_code = pv_tax_code;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_tax_code   := NULL;
            RETURN FALSE;
    END;

    PROCEDURE display_output
    IS
        CURSOR output_cur IS
            SELECT gjh.je_header_id, gjl.je_line_num, led.name led_name,
                   gjh.period_name, --                   gjh.default_effective_date,
                                    --                   gjl.description,
                                    --                   gjl.attribute2,
                                    --                   gjl.attribute3,
                                    --                   gjl.attribute4,
                                    gjl.attribute5, gjl.attribute6,
                   gjl.attribute7
              FROM apps.gl_je_headers gjh, apps.gl_je_lines gjl, apps.gl_ledgers led
             WHERE     gjh.je_header_id = gjl.je_header_id
                   AND gjh.ledger_id = led.ledger_id
                   AND NVL (gjl.attribute5, 'N') IS NOT NULL
                   AND gjl.attribute7 = TO_CHAR (gn_conc_request_id);
    BEGIN
        print_out (
               RPAD ('JE_HEADER_ID', '20')
            || CHR (9)
            || RPAD ('JE_LINE_NUM', '15')
            || CHR (9)
            || RPAD ('LEDGER_NAME', '30')
            || CHR (9)
            || RPAD ('PERIOD_NAME', '15')
            || CHR (9)
            || RPAD ('PROCESS_FLAG', '15')
            || CHR (9)
            || RPAD ('REQUEST_ID', '15')
            || CHR (9)
            || 'ERROR');

        FOR i IN output_cur
        LOOP
            print_out (
                   RPAD (i.JE_HEADER_ID, '20')
                || CHR (9)
                || RPAD (i.JE_LINE_NUM, '15')
                || CHR (9)
                || RPAD (i.LED_NAME, '30')
                || CHR (9)
                || RPAD (i.PERIOD_NAME, '15')
                || CHR (9)
                || RPAD (i.ATTRIBUTE5, '15')
                || CHR (9)
                || RPAD (i.ATTRIBUTE7, '15')
                || CHR (9)
                || i.ATTRIBUTE6);
        END LOOP;
    END;



    PROCEDURE process_gl_data_prc (pn_batch_id IN NUMBER, x_ret_msg OUT NOCOPY VARCHAR2, x_ret_code OUT NOCOPY VARCHAR2)
    IS
        CURSOR cur_process IS
            SELECT sl.user_element_attribute1, sl.user_element_attribute2, sl.user_element_attribute3,
                   sl.user_element_attribute4, si.user_element_attribute45 org_id, sl.bt_country,
                   sl.sf_country, sr.registration_number, gcc.segment1,
                   gcc.segment2, gcc.segment3, gcc.segment4,
                   gcc.segment5, gcc.segment6, gcc.segment7,
                   gcc.segment8, gcc.code_combination_id, gjl.entered_dr,
                   gjl.entered_cr, gjl.ledger_id, gjl.je_header_id,
                   gjl.je_line_num, --slt.authority_uuid,
                                    --slt.erp_tax_code,
                                    --slt.tax_direction,
                                    slt.*
              FROM sabrix_line_tax slt, sabrix_line sl, apps.gl_je_lines gjl,
                   apps.gl_code_combinations gcc, apps.sabrix_invoice si, apps.sabrix_registration sr
             WHERE     1 = 1
                   AND sl.batch_id = slt.batch_id
                   AND sl.line_id = slt.line_id
                   AND si.batch_id = sl.batch_id
                   AND slt.batch_id = pn_batch_id
                   AND sr.batch_id = sl.batch_id
                   AND sr.line_id = gjl.je_line_num
                   AND gjl.je_header_id = sl.user_element_attribute1
                   AND gjl.je_line_num = sl.user_element_attribute2
                   AND gjl.code_combination_id = gcc.code_combination_id
                   AND gjl.attribute7 = gn_conc_request_id;

        lb_boolean    BOOLEAN := NULL;
        ln_tax_ccid   NUMBER := NULL;
        lv_tax_code   VARCHAR2 (100) := NULL;
        lv_seg1       VARCHAR2 (10) := NULL;
        lv_seg2       VARCHAR2 (10) := NULL;
        lv_seg3       VARCHAR2 (10) := NULL;
        lv_seg4       VARCHAR2 (10) := NULL;
        lv_seg5       VARCHAR2 (10) := NULL;
        lv_seg6       VARCHAR2 (10) := NULL;
        lv_seg7       VARCHAR2 (10) := NULL;
        lv_seg8       VARCHAR2 (10) := NULL;
        lb_ins_ret    BOOLEAN := NULL;
        lv_ret_msg    VARCHAR2 (1000) := NULL;
    BEGIN
        lv_ret_msg   := NULL;

        /*sabrix_tax.g_tce_acct_level :=
            NVL (fnd_profile.value_specific ('SABRIX_TAX_ACCOUNTING_LEVEL'),
                 'BASIC');


        IF sabrix_tax.g_tce_acct_level = 'EXTENDED'
        THEN
            sabrix_tax.g_tce_tax_rate :=
                NVL (
                    fnd_profile.value_specific (
                        'SABRIX_TAX_EXTENSION_RATE_CODE'),
                    'N');

            sabrix_tax.g_tce_tax_type :=
                NVL (
                    fnd_profile.value_specific (
                        'SABRIX_TAX_EXTENSION_TAX_TYPE'),
                    'N');

            sabrix_tax.g_tce_exempt :=
                fnd_profile.value_specific ('SABRIX_TAX_EXTENSION_EXEMPT');

            sabrix_tax.g_tce_tax_dir :=
                NVL (
                    fnd_profile.value_specific (
                        'SABRIX_TAX_EXTENSION_TAX_DIR'),
                    'N');

            sabrix_tax.g_tce_delim :=
                fnd_profile.value_specific ('SABRIX_TAX_EXTENSION_DELIMITER');

            IF    sabrix_tax.g_tce_delim = '<no delimiter>'
               OR sabrix_tax.g_tce_delim = 'NULL'
            THEN
                sabrix_tax.g_tce_delim := '';
            END IF;
        END IF; */



        FOR gl_data IN cur_process
        LOOP
            print_log (
                   'Start of Entry to process data into GL for batch ID'
                || gl_data.batch_id);

            lb_boolean   := NULL;
            lb_ins_ret   := NULL;
            lv_seg1      := NULL;
            lv_seg2      := NULL;
            lv_seg3      := NULL;
            lv_seg4      := NULL;
            lv_seg5      := NULL;
            lv_seg6      := NULL;
            lv_seg7      := NULL;
            lv_seg8      := NULL;
            lv_ret_msg   := NULL;

            BEGIN
                BEGIN
                    SELECT tax_regime_code, effective_from, country_code
                      INTO g_sabrix_regime, g_starting_date, g_country_code
                      FROM zx_regimes_b
                     WHERE     tax_regime_code LIKE 'SBX_REGIME%' -- must to add for Sabrix regimes
                           AND country_code = gl_data.bt_country; --gl_data.sf_country;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        g_sabrix_regime   := NULL;
                        g_starting_date   := NULL;
                        g_country_code    := NULL;
                END;

                --            lb_boolean := NULL;
                --            ln_tax_ccid := NULL;
                --            lb_boolean :=
                --               get_tax_code (pv_tax_code   => gl_data.erp_tax_code,
                --                             x_tax_code    => lv_tax_code);

                print_log (
                       'Value Passed in - authority_uuid'
                    || gl_data.authority_uuid
                    || CHR (9)
                    || 'erp_tax_code - '
                    || gl_data.erp_tax_code
                    || CHR (9)
                    || 'tax_direction - '
                    || gl_data.tax_direction
                    || CHR (9)
                    || 'g_sabrix_regime - '
                    || g_sabrix_regime
                    || CHR (9)
                    || 'org_id - '
                    || gl_data.org_id);

                BEGIN
                    SELECT DISTINCT acc.tax_account_ccid
                      INTO ln_tax_ccid
                      FROM sabrix_authority_mapping sam, zx_rates_b rt, zx_accounts acc
                     WHERE     NVL (sam.uuid, 'x') =
                               NVL (gl_data.authority_uuid, 'x')
                           AND sam.erp_tax_code = gl_data.erp_tax_code
                           AND NVL (sam.direction, 'x') =
                               NVL (gl_data.tax_direction, 'x')
                           AND sam.workflow = 'P2P'
                           AND rt.tax = sam.tax_flow
                           AND rt.tax_regime_code = g_sabrix_regime
                           AND rt.active_flag = 'Y'
                           AND acc.tax_account_entity_id = rt.tax_rate_id
                           AND acc.internal_organization_id = gl_data.org_id
                           AND acc.tax_account_entity_code = 'RATES';

                    lb_boolean   := TRUE;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_tax_ccid   := NULL;
                        lb_boolean    := FALSE;
                END;

                print_log ('Tax CCID fetched is - ' || ln_tax_ccid);

                IF ln_tax_ccid IS NOT NULL AND lb_boolean = TRUE
                THEN
                    lb_boolean   := NULL;
                    lb_boolean   :=
                        get_code_comb (p_ccid   => ln_tax_ccid,
                                       x_seg1   => lv_seg1,
                                       x_seg2   => lv_seg2,
                                       x_seg3   => lv_seg3,
                                       x_seg4   => lv_seg4,
                                       x_seg5   => lv_seg5,
                                       x_seg6   => lv_seg6,
                                       x_seg7   => lv_seg7,
                                       x_seg8   => lv_seg8);
                    print_log ('Derived Tax CCID segment6 is - ' || lv_seg6);
                ELSE
                    NULL;
                    lb_boolean   := FALSE;
                --                  x_ret_code := '2';
                --                  x_ret_msg :=
                --                        'Tax CCID derived is NULL or Invalid for Tax Code - '
                --                     || lv_tax_code;
                --- If the Tax derived is NULL then error out and dont progress anything
                END IF;



                --            lv_tax_code :=
                --               get_tax_code_new (gl_data.batch_id,
                --                                 gl_data.invoice_id,
                --                                 gl_data.line_id,
                --                                 lv_ret_msg);

                --            print_log ('Tax code fetched is - ' || lv_tax_code);

                IF ln_tax_ccid IS NOT NULL           --lv_tax_code IS NOT NULL
                THEN
                    --ln_tax_ccid := NULL;
                    --lb_boolean := NULL;

                    --               lb_boolean :=
                    --                  get_tax_ccid (
                    --                     pv_tax_code   => lv_tax_code,
                    --                     pn_org_id     => gl_data.user_element_attribute45,
                    --                     x_tax_ccid    => ln_tax_ccid);

                    print_log ('Tax CCID fetched is - ' || ln_tax_ccid);

                    --               IF ln_tax_ccid IS NOT NULL AND lb_boolean = TRUE
                    --               THEN
                    --                  lb_boolean := NULL;
                    --                  lb_boolean :=
                    --                     get_code_comb (p_ccid   => ln_tax_ccid,
                    --                                    x_seg1   => lv_seg1,
                    --                                    x_seg2   => lv_seg2,
                    --                                    x_seg3   => lv_seg3,
                    --                                    x_seg4   => lv_seg4,
                    --                                    x_seg5   => lv_seg5,
                    --                                    x_seg6   => lv_seg6,
                    --                                    x_seg7   => lv_seg7,
                    --                                    x_seg8   => lv_seg8);
                    --                  print_log ('Derived Tax CCID segment6 is - ' || lv_seg6);
                    --               ELSE
                    --                  NULL;
                    --               --                  x_ret_code := '2';
                    --               --                  x_ret_msg :=
                    --               --                        'Tax CCID derived is NULL or Invalid for Tax Code - '
                    --               --                     || lv_tax_code;
                    --               --- If the Tax derived is NULL then error out and dont progress anything
                    --               END IF;

                    IF lb_boolean = FALSE
                    THEN
                        print_log (
                               ' Tax CCID derived is Invalid with je_header_id - '
                            || gl_data.je_header_id
                            || ' and Line Num is - '
                            || gl_data.je_line_num);

                        UPDATE apps.gl_je_lines
                           SET attribute5 = 'E', attribute6 = SUBSTR (lv_ret_msg || '-' || lv_ret_msg, 1, 150)
                         WHERE     je_header_id = gl_data.je_header_id
                               AND je_line_num = gl_data.je_line_num
                               AND attribute7 = gn_conc_request_id;
                    --                  x_ret_code := '2';
                    --                  x_ret_msg :=
                    --                     'Tax CCID derived is NULL or Invalid - ' || ln_tax_ccid;
                    END IF;
                ELSE
                    print_log (
                        'Tax code derived is NULL, So capture Tax Error Message');

                    UPDATE apps.gl_je_lines
                       SET attribute5 = 'E', attribute6 = SUBSTR (lv_ret_msg || '-' || lv_ret_msg, 1, 150)
                     WHERE     je_header_id = gl_data.je_header_id
                           AND je_line_num = gl_data.je_line_num
                           AND attribute7 = gn_conc_request_id;
                --               x_ret_code := '2';
                --               x_ret_msg :=
                --                     'Tax code derived is NULL, Exit the Process  - '
                --                  || gl_data.erp_tax_code;
                END IF;
            END;

            IF lb_boolean = TRUE
            THEN
                IF NVL (gl_data.entered_dr, 0) > 0
                THEN
                    print_log (
                        ' Now Insert Data into GL_Interface for Positive');

                    lb_ins_ret   := NULL;
                    lv_ret_msg   := NULL;

                    BEGIN
                        INSERT INTO gl_interface (
                                        accounting_date,
                                        actual_flag,
                                        attribute4,
                                        attribute5,
                                        attribute6,
                                        code_combination_id,
                                        created_by,
                                        currency_code,
                                        date_created,
                                        entered_cr,
                                        entered_dr,
                                        ledger_id,
                                        reference10,
                                        reference21,
                                        reference22,
                                        reference23,                   -- CCID
                                        reference6,
                                        attribute7,               -- Added New
                                        attribute8,               -- Added New
                                        attribute9,               -- Added New
                                        attribute10,              -- Added New
                                        segment1,
                                        segment2,
                                        segment3,
                                        segment4,
                                        segment5,
                                        segment6,
                                        segment7,
                                        segment8,
                                        set_of_books_id,
                                        status,
                                        user_je_source_name,
                                        user_je_category_name,
                                        user_currency_conversion_type,
                                        currency_conversion_date)
                             VALUES (gl_data.creation_date, 'A', gl_data.user_element_attribute1, --gl_data.user_element_attribute1,
                                                                                                  gl_data.user_element_attribute2, --gl_data.user_element_attribute2,
                                                                                                                                   gl_data.user_element_attribute2, --gl_data.user_element_attribute3, -- Check again
                                                                                                                                                                    ln_tax_ccid, --gl_data.code_combination_id,-- Check
                                                                                                                                                                                 gn_user_id, --fnd_user.login_id,
                                                                                                                                                                                             gl_data.authority_currency_code, gv_date, DECODE (gl_data.tax_direction, 'O', DECODE (gl_data.is_exempt, 'Y', gl_data.exempt_amount, gl_data.tax_amount), NULL), --DECODE(gl_data.is_exempt,'Y',gl_data.exempt_amount,gl_data.tax_amount), --How to know whether the tax result is Exempt or Not
                                                                                                                                                                                                                                                                                                                                                              DECODE (gl_data.tax_direction, 'I', DECODE (gl_data.is_exempt, 'Y', gl_data.exempt_amount, gl_data.tax_amount), NULL), -- How to know whether the tax result is Exempt or Not
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     gl_data.ledger_id, -- Ledger_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        'Journal Line Created by Sabrix', -- Line Desc
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          gl_data.erp_tax_code, NVL (gl_data.seller_registration, 'Not Registered'), ln_tax_ccid, --gl_data.code_combination_id,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  'Journal Name - ' || TO_CHAR (SYSDATE, 'DDMMRRRR'), -- Journal Name
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      gl_data.bt_country, -- Added New
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          gl_data.registration_number, -- Added New
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       gl_data.tax_direction, -- Added New
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              gl_data.tax_rate, lv_seg1, lv_seg2, lv_seg3, lv_seg4, lv_seg5, lv_seg6, lv_seg7, lv_seg8, gl_data.ledger_id, -- Set of Books ID
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           'NEW', 'One Source', 'Tax Journal'
                                     , 'Corporate', gl_data.creation_date);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lb_ins_ret   := FALSE;
                            lv_ret_msg   :=
                                   lv_ret_msg
                                || ' - '
                                || SUBSTR (SQLERRM, 1, 200);
                    END;

                    BEGIN
                        INSERT INTO gl_interface (
                                        accounting_date,
                                        actual_flag,
                                        attribute4,
                                        attribute5,
                                        attribute6,
                                        code_combination_id,
                                        created_by,
                                        currency_code,
                                        date_created,
                                        entered_cr,
                                        entered_dr,
                                        ledger_id,
                                        reference10,
                                        reference21,
                                        reference22,
                                        reference23,                   -- CCID
                                        reference6,
                                        attribute7,               -- Added New
                                        attribute8,               -- Added New
                                        attribute9,               -- Added New
                                        attribute10,              -- Added New
                                        segment1,
                                        segment2,
                                        segment3,
                                        segment4,
                                        segment5,
                                        segment6,
                                        segment7,
                                        segment8,
                                        set_of_books_id,
                                        status,
                                        user_je_source_name,
                                        user_je_category_name,
                                        user_currency_conversion_type,
                                        currency_conversion_date)
                             VALUES (gl_data.creation_date, 'A', gl_data.user_element_attribute1, --gl_data.user_element_attribute1,
                                                                                                  gl_data.user_element_attribute2, --gl_data.user_element_attribute2,
                                                                                                                                   gl_data.user_element_attribute2, --gl_data.user_element_attribute3, -- Check again
                                                                                                                                                                    gl_data.code_combination_id, -- Check
                                                                                                                                                                                                 gn_user_id, --fnd_user.login_id,
                                                                                                                                                                                                             gl_data.authority_currency_code, gv_date, DECODE (gl_data.tax_direction, 'I', DECODE (gl_data.is_exempt, 'Y', gl_data.exempt_amount, gl_data.tax_amount), NULL), --How to know whether the tax result is Exempt or Not
                                                                                                                                                                                                                                                                                                                                                                              DECODE (gl_data.tax_direction, 'O', DECODE (gl_data.is_exempt, 'Y', gl_data.exempt_amount, gl_data.tax_amount), NULL), -- How to know whether the tax result is Exempt or Not
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     gl_data.ledger_id, -- Ledger_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        'Journal Line Created by Sabrix', -- Line Desc
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          gl_data.erp_tax_code, NVL (gl_data.seller_registration, 'Not Registered'), gl_data.code_combination_id, --gl_data.code_combination_id,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  'Journal Name - ' || TO_CHAR (SYSDATE, 'DDMMRRRR'), -- Journal Name
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      gl_data.bt_country, -- Added New
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          gl_data.registration_number, -- Added New
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       gl_data.tax_direction, -- Added New
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              gl_data.tax_rate, -- Added New
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                gl_data.segment1, gl_data.segment2, gl_data.segment3, gl_data.segment4, gl_data.segment5, gl_data.segment6, gl_data.segment7, gl_data.segment8, gl_data.ledger_id, -- Set of Books ID
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   'NEW', 'One Source', 'Tax Journal'
                                     , 'Corporate', gl_data.creation_date);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            NULL;
                            lb_ins_ret   := FALSE;
                            lv_ret_msg   :=
                                   lv_ret_msg
                                || ' - '
                                || SUBSTR (SQLERRM, 1, 200);
                    END;
                ELSIF NVL (gl_data.entered_cr, 0) > 0
                THEN
                    lb_ins_ret   := NULL;
                    print_log (
                        ' Now Insert Data into GL_Interface for Negative');

                    BEGIN
                        INSERT INTO gl_interface (
                                        accounting_date,
                                        actual_flag,
                                        attribute4,
                                        attribute5,
                                        attribute6,
                                        code_combination_id,
                                        created_by,
                                        currency_code,
                                        date_created,
                                        entered_cr,
                                        entered_dr,
                                        ledger_id,
                                        reference10,
                                        reference21,
                                        reference22,
                                        reference23,                   -- CCID
                                        reference6,
                                        attribute7,               -- Added New
                                        attribute8,               -- Added New
                                        attribute9,               -- Added New
                                        attribute10,              -- Added New
                                        segment1,
                                        segment2,
                                        segment3,
                                        segment4,
                                        segment5,
                                        segment6,
                                        segment7,
                                        segment8,
                                        set_of_books_id,
                                        status,
                                        user_je_source_name,
                                        user_je_category_name,
                                        user_currency_conversion_type,
                                        currency_conversion_date)
                             VALUES (gl_data.creation_date, 'A', gl_data.user_element_attribute1, --gl_data.user_element_attribute1,
                                                                                                  gl_data.user_element_attribute2, --gl_data.user_element_attribute2,
                                                                                                                                   gl_data.user_element_attribute2, --gl_data.user_element_attribute3, -- Check again
                                                                                                                                                                    ln_tax_ccid, --gl_data.code_combination_id,-- Check
                                                                                                                                                                                 gn_user_id, --fnd_user.login_id,
                                                                                                                                                                                             gl_data.authority_currency_code, gv_date, DECODE (gl_data.tax_direction, 'I', DECODE (gl_data.is_exempt, 'Y', gl_data.exempt_amount, gl_data.tax_amount), NULL), --DECODE(gl_data.is_exempt,'Y',gl_data.exempt_amount,gl_data.tax_amount), --How to know whether the tax result is Exempt or Not
                                                                                                                                                                                                                                                                                                                                                              DECODE (gl_data.tax_direction, 'O', DECODE (gl_data.is_exempt, 'Y', gl_data.exempt_amount, gl_data.tax_amount), NULL), -- How to know whether the tax result is Exempt or Not
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     gl_data.ledger_id, -- Ledger_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        'Journal Line Created by Sabrix', -- Line Desc
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          gl_data.erp_tax_code, NVL (gl_data.seller_registration, 'Not Registered'), ln_tax_ccid, --gl_data.code_combination_id,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  'Journal Name - ' || TO_CHAR (SYSDATE, 'DDMMRRRR'), -- Journal Name
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      gl_data.bt_country, -- Added New
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          gl_data.registration_number, -- Added New
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       gl_data.tax_direction, -- Added New
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              gl_data.tax_rate, -- Added New
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                lv_seg1, lv_seg2, lv_seg3, lv_seg4, lv_seg5, lv_seg6, lv_seg7, lv_seg8, gl_data.ledger_id, -- Set of Books ID
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           'NEW', 'One Source', 'Tax Journal'
                                     , 'Corporate', gl_data.creation_date);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            NULL;
                            lb_ins_ret   := FALSE;
                            lv_ret_msg   :=
                                   lv_ret_msg
                                || ' - '
                                || SUBSTR (SQLERRM, 1, 200);
                    END;

                    BEGIN
                        INSERT INTO gl_interface (
                                        accounting_date,
                                        actual_flag,
                                        attribute4,
                                        attribute5,
                                        attribute6,
                                        code_combination_id,
                                        created_by,
                                        currency_code,
                                        date_created,
                                        entered_cr,
                                        entered_dr,
                                        ledger_id,
                                        reference10,
                                        reference21,
                                        reference22,
                                        reference23,                   -- CCID
                                        reference6,
                                        attribute7,               -- Added New
                                        attribute8,               -- Added New
                                        attribute9,               -- Added New
                                        attribute10,              -- Added New
                                        segment1,
                                        segment2,
                                        segment3,
                                        segment4,
                                        segment5,
                                        segment6,
                                        segment7,
                                        segment8,
                                        set_of_books_id,
                                        status,
                                        user_je_source_name,
                                        user_je_category_name,
                                        user_currency_conversion_type,
                                        currency_conversion_date)
                             VALUES (gl_data.creation_date, 'A', gl_data.user_element_attribute1, --gl_data.user_element_attribute1,
                                                                                                  gl_data.user_element_attribute2, --gl_data.user_element_attribute2,
                                                                                                                                   gl_data.user_element_attribute2, --gl_data.user_element_attribute3, -- Check again
                                                                                                                                                                    gl_data.code_combination_id, -- Check
                                                                                                                                                                                                 gn_user_id, --fnd_user.login_id,
                                                                                                                                                                                                             gl_data.authority_currency_code, gv_date, DECODE (gl_data.tax_direction, 'O', DECODE (gl_data.is_exempt, 'Y', gl_data.exempt_amount, gl_data.tax_amount), NULL), --How to know whether the tax result is Exempt or Not
                                                                                                                                                                                                                                                                                                                                                                              DECODE (gl_data.tax_direction, 'I', DECODE (gl_data.is_exempt, 'Y', gl_data.exempt_amount, gl_data.tax_amount), NULL), -- How to know whether the tax result is Exempt or Not
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     gl_data.ledger_id, -- Ledger_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        'Journal Line Created by Sabrix', -- Line Desc
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          gl_data.erp_tax_code, NVL (gl_data.seller_registration, 'Not Registered'), gl_data.code_combination_id, --gl_data.code_combination_id,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  'Journal Name - ' || TO_CHAR (SYSDATE, 'DDMMRRRR'), -- Journal Name
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      gl_data.bt_country, -- Added New
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          gl_data.registration_number, -- Added New
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       gl_data.tax_direction, -- Added New
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              gl_data.tax_rate, -- Added New
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                gl_data.segment1, gl_data.segment2, gl_data.segment3, gl_data.segment4, gl_data.segment5, gl_data.segment6, gl_data.segment7, gl_data.segment8, gl_data.ledger_id, -- Set of Books ID
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   'NEW', 'One Source', 'Tax Journal'
                                     , 'Corporate', gl_data.creation_date);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            NULL;
                            lb_ins_ret   := FALSE;
                            lv_ret_msg   :=
                                   lv_ret_msg
                                || ' - '
                                || SUBSTR (SQLERRM, 1, 200);
                    END;
                END IF;

                IF lb_ins_ret IS NULL
                THEN
                    UPDATE apps.gl_je_lines
                       SET attribute5   = 'Y'
                     WHERE     je_header_id = gl_data.je_header_id
                           AND je_line_num = gl_data.je_line_num
                           AND attribute7 = gn_conc_request_id;
                --AND context = 'Manual Journal';
                ELSIF lb_ins_ret = FALSE
                THEN
                    UPDATE apps.gl_je_lines
                       SET attribute5 = 'E', attribute6 = SUBSTR (lv_ret_msg || '-' || lv_ret_msg, 1, 150)
                     WHERE     je_header_id = gl_data.je_header_id
                           AND je_line_num = gl_data.je_line_num
                           AND attribute7 = gn_conc_request_id;
                --               x_ret_code := '2';
                --               x_ret_msg :=
                --                     'Exception Occured while Inserting Data into GL Interface and Error is - '
                --                  || SUBSTR (lv_ret_msg, 1, 200);
                END IF;

                COMMIT;
            END IF;
        --         IF lb_ins_ret = TRUE
        --         THEN
        --            COMMIT;
        --         ELSE
        --            ROLLBACK;
        --         END IF;

        END LOOP;

        COMMIT;
    END;
END XXD_GL_SBX_INT_PKG;
/
