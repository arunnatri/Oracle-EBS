--
-- XXD_GL_OPEN_RETINV_JOURNAL_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:57 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_GL_OPEN_RETINV_JOURNAL_PKG"
AS
    /****************************************************************************************
       * Package      : XXD_GL_OPEN_RETINV_JOURNAL_PKG
       * Design       : This package will be used to CREATE journal entries for the open retail return inv
       * Notes        :
    * Modification :
       -- ======================================================================================
       -- Date         Version#   Name                    Comments
       -- ======================================================================================
       -- 08-Sep-2021  1.0        Showkath Ali            Initial Version
       *******************************************************************************************/
    -- ======================================================================================
    -- Global Variable decleration
    -- ======================================================================================

    gn_user_id        CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id       CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id         CONSTANT NUMBER := fnd_global.org_id;
    gn_resp_id        CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id   CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_request_id     CONSTANT NUMBER := fnd_global.conc_request_id;
    ex_no_recips               EXCEPTION;
    gn_error          CONSTANT NUMBER := 2;
    gv_delimeter               VARCHAR2 (1) := '|';

    -- ======================================================================================
    -- This procedure is used to create journal
    -- ======================================================================================

    PROCEDURE generate_journal_entry (pn_org_id IN VARCHAR2, pv_period_end_date IN VARCHAR2, pv_order_created_from IN VARCHAR2
                                      , pv_order_created_to IN VARCHAR2, pv_retcode OUT NUMBER, pv_errbuf OUT VARCHAR2)
    AS
        CURSOR get_eligible_records IS
              SELECT org_id, entity_uniq_identifier, account_number,
                     key3, key4, key5,
                     key6, key7, period_end_date,
                     SUM (credit_amount) credit, SUM (debit_amount) debit, currency,
                     warehouse, line_description
                FROM xxdo.xxd_wms_open_ret_ext_postgl_t
               WHERE request_id = gn_request_id AND status IS NULL
            GROUP BY org_id, entity_uniq_identifier, account_number,
                     key3, key4, key5,
                     key6, key7, period_end_date,
                     currency, warehouse, line_description;

        -- Declare Variables

        lv_period_name         VARCHAR2 (30);
        ln_error_count         NUMBER := 0;
        lv_err_msg             VARCHAR2 (32767);
        lv_organization_name   VARCHAR (300);
        lv_batch_name          VARCHAR2 (300);
        lv_batch_desc          VARCHAR2 (300);
        lv_journal_name        VARCHAR2 (300);
        lv_journal_desc        VARCHAR2 (300);
        ln_ledger_id           NUMBER;
        lv_je_source_name      VARCHAR2 (300);
        lv_je_category         VARCHAR2 (300);
        ln_debit_fail_count    NUMBER := 0;
        ln_credit_suc_count    NUMBER := 0;
        ln_credit_fail_count   NUMBER := 0;
        ln_debit_suc_count     NUMBER := 0;
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'Inside generate_journal_entry procedure:');
        fnd_file.put_line (fnd_file.LOG, 'pn_org_id:' || pn_org_id);

        FOR i IN get_eligible_records
        LOOP
            fnd_file.put_line (fnd_file.LOG,
                               '----------------------------------------');

            -- query to fetch period name
            BEGIN
                SELECT period_name
                  INTO lv_period_name
                  FROM gl_periods
                 WHERE     period_set_name = 'DO_FY_CALENDAR'
                       AND i.period_end_date BETWEEN start_date AND end_date;

                fnd_file.put_line (fnd_file.LOG,
                                   'Period_name is:' || lv_period_name);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_period_name   := NULL;
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Failed to fetch Period_name:' || SQLERRM);
                    lv_err_msg       :=
                           lv_err_msg
                        || 'Failed to fetch period name:'
                        || SQLERRM;
                    ln_error_count   := ln_error_count + 1;
            END;

            -- Query to fetch OU Name

            BEGIN
                SELECT name
                  INTO lv_organization_name
                  FROM hr_operating_units
                 WHERE organization_id = i.org_id;

                fnd_file.put_line (
                    fnd_file.LOG,
                    'Organization Name:' || lv_organization_name);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_organization_name   := NULL;
                    lv_err_msg             :=
                           lv_err_msg
                        || 'Failed to fetch organization name:'
                        || SQLERRM;
                    ln_error_count         := ln_error_count + 1;
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Failed to fetch organization name:' || SQLERRM);
            END;

            -- Query to fetch batch name

            BEGIN
                SELECT 'DO Open RTW ' || i.warehouse || '_' || lv_organization_name || '_' || i.entity_uniq_identifier || '_' || i.currency || '_' || lv_period_name || '_' || SYSDATE
                  INTO lv_batch_name
                  FROM DUAL;

                fnd_file.put_line (fnd_file.LOG,
                                   'Batch Name:' || lv_batch_name);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_batch_name    := NULL;
                    lv_err_msg       :=
                           lv_err_msg
                        || 'Failed to fetch batch name:'
                        || SQLERRM;
                    ln_error_count   := ln_error_count + 1;
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg || SQLERRM);
            END;

            --

            -- Query to fetch batch description

            BEGIN
                SELECT 'DO Open RTW ' || i.warehouse || '_' || lv_organization_name || '_' || i.currency || '_' || lv_period_name
                  INTO lv_batch_desc
                  FROM DUAL;

                fnd_file.put_line (fnd_file.LOG,
                                   'Batch Description is:' || lv_batch_desc);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_batch_desc    := NULL;
                    lv_err_msg       :=
                           lv_err_msg
                        || 'Failed to fetch batch name:'
                        || SQLERRM;
                    ln_error_count   := ln_error_count + 1;
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg || SQLERRM);
            END;

            -- Query to fetch Journal Name

            BEGIN
                SELECT 'DO Open RTW ' || i.warehouse || '_' || lv_organization_name || '_' || i.currency || '_' || lv_period_name
                  INTO lv_journal_name
                  FROM DUAL;

                fnd_file.put_line (fnd_file.LOG,
                                   'Journal Name is:' || lv_journal_name);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_journal_name   := NULL;
                    lv_err_msg        :=
                           lv_err_msg
                        || 'Failed to fetch batch name:'
                        || SQLERRM;
                    ln_error_count    := ln_error_count + 1;
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg || SQLERRM);
            END;

            -- Query to fetch Journal Description

            BEGIN
                SELECT 'DO Open RTW ' || i.warehouse || '_' || lv_organization_name || '_' || i.currency || '_' || lv_period_name
                  INTO lv_journal_desc
                  FROM DUAL;

                fnd_file.put_line (
                    fnd_file.LOG,
                    'Journal Description is:' || lv_journal_desc);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_journal_desc   := NULL;
                    lv_err_msg        :=
                           lv_err_msg
                        || 'Failed to fetch batch name:'
                        || SQLERRM;
                    ln_error_count    := ln_error_count + 1;
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg || SQLERRM);
            END;

            -- Query to fetch leger_id from company

            BEGIN
                SELECT ffvl.attribute6
                  INTO ln_ledger_id
                  FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                 WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                       AND fvs.flex_value_set_name = 'DO_GL_COMPANY'
                       AND NVL (TRUNC (ffvl.start_date_active),
                                TRUNC (SYSDATE)) <=
                           TRUNC (SYSDATE)
                       AND NVL (TRUNC (ffvl.end_date_active),
                                TRUNC (SYSDATE)) >=
                           TRUNC (SYSDATE)
                       AND ffvl.enabled_flag = 'Y'
                       AND flex_value = i.entity_uniq_identifier;

                fnd_file.put_line (fnd_file.LOG,
                                   'Ledger id is:' || ln_ledger_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_ledger_id     := NULL;
                    lv_err_msg       :=
                        lv_err_msg || 'Failed to fetch leger_id:' || SQLERRM;
                    ln_error_count   := ln_error_count + 1;
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg || SQLERRM);
            END;

            -- query to fetch Journal source

            BEGIN
                SELECT user_je_source_name
                  INTO lv_je_source_name
                  FROM gl_je_sources
                 WHERE     user_je_source_name = 'DO Open RTW Store to WH'
                       AND language = 'US';

                fnd_file.put_line (fnd_file.LOG,
                                   'Source is:' || lv_je_source_name);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_je_source_name   := NULL;
                    lv_err_msg          :=
                        lv_err_msg || 'Failed to fetch Source:' || SQLERRM;
                    ln_error_count      := ln_error_count + 1;
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg || SQLERRM);
            END;

            -- query to fetch Journal Catogory

            BEGIN
                SELECT user_je_category_name
                  INTO lv_je_category
                  FROM gl_je_categories
                 WHERE     user_je_category_name = 'DO Open RTW Store to WH'
                       AND language = 'US';

                fnd_file.put_line (fnd_file.LOG,
                                   'Category is:' || lv_je_category);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_je_category   := NULL;
                    lv_err_msg       :=
                        lv_err_msg || 'Failed to fetch Category:' || SQLERRM;
                    ln_error_count   := ln_error_count + 1;
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg || SQLERRM);
            END;

            IF ln_error_count > 0
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Validation errors exist...skipping inserting into GL_interface');
                fnd_file.put_line (fnd_file.LOG,
                                   'Error Message:' || lv_err_msg);

                -- Update the error message in custom table
                BEGIN
                    UPDATE xxdo.xxd_wms_open_ret_ext_postgl_t
                       SET status = 'E', error_message = lv_err_msg, last_updated_by = gn_user_id,
                           last_update_date = SYSDATE
                     WHERE     org_id = i.org_id
                           AND entity_uniq_identifier =
                               i.entity_uniq_identifier
                           AND account_number = i.account_number
                           AND key3 = i.key3
                           AND key4 = i.key4
                           AND key5 = i.key5
                           AND key6 = i.key6
                           AND key7 = i.key7
                           AND period_end_date = i.period_end_date
                           AND currency = i.currency
                           AND warehouse = i.warehouse
                           AND line_description = i.line_description;

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Failed to update in custom table:' || SQLERRM);
                END;

                pv_retcode   := 1;
            ELSE
                -- Insert the values of credit record into gl_interface
                IF NVL (i.credit, 0) <> 0
                THEN
                    BEGIN
                        INSERT INTO gl.gl_interface (status, ledger_id, accounting_date, currency_code, date_created, created_by, actual_flag, reference5, --journal description
                                                                                                                                                           entered_cr, user_je_source_name, user_je_category_name, GROUP_ID, reference1, -- batch Name
                                                                                                                                                                                                                                         reference2, -- batch description
                                                                                                                                                                                                                                                     reference4, -- journal_name
                                                                                                                                                                                                                                                                 reference10, -- line desc
                                                                                                                                                                                                                                                                              period_name, segment1, segment2, segment3, segment4, segment5, segment6, segment7
                                                     , segment8)
                             VALUES ('NEW', ln_ledger_id, i.period_end_date,
                                     i.currency, SYSDATE, fnd_global.user_id,
                                     'A', lv_journal_desc, i.credit,
                                     lv_je_source_name, lv_je_category, 99069, --group_id
                                                                               lv_batch_name, --batch_name
                                                                                              lv_batch_desc, lv_journal_name, --journal_name
                                                                                                                              i.line_description, lv_period_name, i.entity_uniq_identifier, i.key3, i.key4, i.key5, i.key6, i.account_number, i.key7
                                     , '1000');

                        COMMIT;
                        ln_credit_suc_count   := ln_credit_suc_count + 1;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               ' Credit Record inserted into gl_interface:'
                            || lv_batch_desc);

                        -- updating the success falg in custom table

                        BEGIN
                            UPDATE xxdo.xxd_wms_open_ret_ext_postgl_t
                               SET status = 'S', last_updated_by = gn_user_id, last_update_date = SYSDATE
                             WHERE     org_id = i.org_id
                                   AND entity_uniq_identifier =
                                       i.entity_uniq_identifier
                                   AND account_number = i.account_number
                                   AND key3 = i.key3
                                   AND key4 = i.key4
                                   AND key5 = i.key5
                                   AND key6 = i.key6
                                   AND key7 = i.key7
                                   AND period_end_date = i.period_end_date
                                   AND currency = i.currency
                                   AND warehouse = i.warehouse
                                   AND line_description = i.line_description;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Failed to update in custom table:'
                                    || SQLERRM);
                        END;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Failed to insert the data in GL Interface:'
                                || SQLERRM);
                            ln_credit_fail_count   :=
                                ln_credit_fail_count + 1;
                    END;
                END IF;

                -- Insert the values of Debit record into gl_interface

                IF NVL (i.debit, 0) <> 0
                THEN
                    BEGIN
                        INSERT INTO gl.gl_interface (status, ledger_id, accounting_date, currency_code, date_created, created_by, actual_flag, reference5, --journal description
                                                                                                                                                           entered_dr, user_je_source_name, user_je_category_name, GROUP_ID, reference1, -- batch Name
                                                                                                                                                                                                                                         reference2, -- batch description
                                                                                                                                                                                                                                                     reference4, -- journal_name
                                                                                                                                                                                                                                                                 reference10, period_name, segment1, segment2, segment3, segment4, segment5, segment6, segment7
                                                     , segment8)
                             VALUES ('NEW', ln_ledger_id, i.period_end_date,
                                     i.currency, SYSDATE, fnd_global.user_id,
                                     'A', lv_journal_desc, i.debit,
                                     lv_je_source_name, lv_je_category, 99069, --group_id
                                                                               lv_batch_name, --batch_name
                                                                                              lv_batch_desc, lv_journal_name, --journal_name
                                                                                                                              i.line_description, lv_period_name, i.entity_uniq_identifier, i.key3, i.key4, i.key5, i.key6, i.account_number, i.key7
                                     , '1000');

                        COMMIT;
                        ln_debit_suc_count   := ln_debit_suc_count + 1;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Debit Record inserted into gl_interface:'
                            || lv_batch_desc);

                        -- updating the success falg in custom table

                        BEGIN
                            UPDATE xxdo.xxd_wms_open_ret_ext_postgl_t
                               SET status = 'S', last_updated_by = gn_user_id, last_update_date = SYSDATE
                             WHERE     org_id = i.org_id
                                   AND entity_uniq_identifier =
                                       i.entity_uniq_identifier
                                   AND account_number = i.account_number
                                   AND key3 = i.key3
                                   AND key4 = i.key4
                                   AND key5 = i.key5
                                   AND key6 = i.key6
                                   AND key7 = i.key7
                                   AND period_end_date = i.period_end_date
                                   AND currency = i.currency
                                   AND warehouse = i.warehouse
                                   AND line_description = i.line_description;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Failed to update in custom table:'
                                    || SQLERRM);
                        END;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Failed to insert the data in GL Interface:'
                                || SQLERRM);
                            ln_debit_fail_count   := ln_debit_fail_count + 1;
                    END;
                END IF;
            END IF;                                    -- if ln_error_count >0
        END LOOP;

        fnd_file.put_line (
            fnd_file.OUTPUT,
            'Open Retail Return Reords Journal creation status:');
        fnd_file.put_line (
            fnd_file.OUTPUT,
            '--------------------------------------------------');
        fnd_file.put_line (
            fnd_file.OUTPUT,
            'Successfully inserted Credit Records:' || ln_credit_suc_count);
        fnd_file.put_line (
            fnd_file.OUTPUT,
            'Successfully inserted Debit Records :' || ln_debit_suc_count);
        fnd_file.put_line (
            fnd_file.OUTPUT,
            'Insertion Failed Credit Records     :' || ln_credit_fail_count);
        fnd_file.put_line (
            fnd_file.OUTPUT,
            'Insertion Failed Debit Records      :' || ln_debit_fail_count);
    END generate_journal_entry;

    -- ======================================================================================
    -- This Function is used to fetch Natural account from order type
    -- ======================================================================================

    FUNCTION get_acct_order_type (p_order_type_id   IN     NUMBER,
                                  p_error_message      OUT VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_cogs_account   VARCHAR2 (20);
    BEGIN
        BEGIN
            SELECT gcc.segment6
              INTO lv_cogs_account
              FROM oe_transaction_types_all otta, gl_code_combinations gcc
             WHERE     transaction_type_id = p_order_type_id
                   AND otta.cost_of_goods_sold_account =
                       gcc.code_combination_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_cogs_account   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Failed to fetch natural account from Order type'
                    || SQLERRM);
                p_error_message   :=
                       'Failed to fetch natural account from order type'
                    || SQLERRM;
        END;

        RETURN lv_cogs_account;
    END;

    -- ======================================================================================
    -- This Function is used to fetch offset account from value set
    -- ======================================================================================

    PROCEDURE get_valueset_natural_acct (p_org_id IN NUMBER, p_error_message OUT VARCHAR2, p_vs_natural_account OUT VARCHAR2, p_vs_brand OUT VARCHAR2, p_vs_channel OUT VARCHAR2, p_vs_costcentre OUT VARCHAR2
                                         , p_vs_intercompany OUT VARCHAR2)
    AS
    BEGIN
        BEGIN
            SELECT ffvl.attribute17, ffvl.attribute25, ffvl.attribute23,
                   ffvl.attribute24, ffvl.attribute26
              INTO p_vs_natural_account, p_vs_brand, p_vs_channel, p_vs_costcentre,
                                       p_vs_intercompany
              FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
             WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                   AND fvs.flex_value_set_name = 'XXD_GL_AAR_OU_SHORTNAME_VS'
                   AND NVL (TRUNC (ffvl.start_date_active), TRUNC (SYSDATE)) <=
                       TRUNC (SYSDATE)
                   AND NVL (TRUNC (ffvl.end_date_active), TRUNC (SYSDATE)) >=
                       TRUNC (SYSDATE)
                   AND ffvl.enabled_flag = 'Y'
                   AND ffvl.attribute1 = p_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_vs_natural_account   := NULL;
                p_vs_brand             := NULL;
                p_vs_channel           := NULL;
                p_vs_costcentre        := NULL;
                p_vs_intercompany      := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Failed to fetch natural account from value set'
                    || SQLERRM);
                p_error_message        :=
                       'Failed to fetch natural account from value set'
                    || SQLERRM;
        END;
    END get_valueset_natural_acct;

    -- ======================================================================================
    -- This procedure is used to fetch code combinations from customer bill to
    -- ======================================================================================

    PROCEDURE fetch_cust_billto_code_comb (p_site_use_id IN NUMBER, p_segment1 OUT VARCHAR2, p_segment2 OUT VARCHAR2, p_segment3 OUT VARCHAR2, p_segment4 OUT VARCHAR2, p_segment5 OUT VARCHAR2, p_segment6 OUT VARCHAR2, p_segment7 OUT VARCHAR2, p_segment8 OUT VARCHAR2
                                           , p_error_message OUT VARCHAR2)
    AS
    BEGIN
        BEGIN
            SELECT gcc.segment1, gcc.segment2, gcc.segment3,
                   gcc.segment4, gcc.segment5, gcc.segment6,
                   gcc.segment7, gcc.segment8
              INTO p_segment1, p_segment2, p_segment3, p_segment4,
                             p_segment5, p_segment6, p_segment7,
                             p_segment8
              FROM hz_cust_site_uses_all uses, gl_code_combinations gcc
             WHERE     gcc.code_combination_id = uses.gl_id_rev
                   AND uses.site_use_id = p_site_use_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_segment1   := NULL;
                p_segment2   := NULL;
                p_segment3   := NULL;
                p_segment4   := NULL;
                p_segment5   := NULL;
                p_segment6   := NULL;
                p_segment7   := NULL;
                p_segment8   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Failed to fetch code combinations for the customer:'
                    || SQLERRM);
        END;
    END fetch_cust_billto_code_comb;

    -- ======================================================================================
    -- This procedure is used to create journal
    -- ======================================================================================

    PROCEDURE insert_records (pn_org_id IN VARCHAR2, pv_period_end_date IN VARCHAR2, pv_order_created_from IN VARCHAR2
                              , pv_order_created_to IN VARCHAR2, pn_retcode OUT NUMBER, pv_errbuf OUT VARCHAR2)
    AS
        CURSOR insert_eligible_records (pn_request_id IN NUMBER)
        IS
            SELECT custom.request_id, ra_nbr, store_location,
                   created, style, color_code,
                   size_code, original_quantity, received_quantity,
                   cancelled_quantity, open_quantity, extd_price,
                   currency, warehouse, brand,
                   cust_acct_num, entity_uniq_identifier, account_number,
                   key3, key4, key5,
                   key6, key7, key8,
                   key9, key10, period_end_date,
                   subledr_rep_bal, subledr_alt_bal, subledr_acc_bal,
                   ooha.org_id, ooha.invoice_to_org_id, ooha.order_type_id
              FROM xxdo.xxd_wms_open_ret_ext_t custom, apps.oe_order_headers_all ooha
             WHERE     ooha.order_number = custom.ra_nbr
                   AND subledr_acc_bal <> 0
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxdo.xxd_wms_open_ret_ext_postgl_t custom_gl
                             WHERE     custom_gl.ra_nbr = custom.ra_nbr
                                   AND NVL (custom_gl.status, 'X') = 'S'
                                   AND custom_gl.period_end_date =
                                       custom.period_end_date)
                   AND (   (    org_id IN
                                    (SELECT attribute1
                                       FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                                      WHERE     fvs.flex_value_set_id =
                                                ffvl.flex_value_set_id
                                            AND fvs.flex_value_set_name =
                                                'XXD_GL_AAR_OU_SHORTNAME_VS'
                                            AND NVL (
                                                    TRUNC (
                                                        ffvl.start_date_active),
                                                    TRUNC (SYSDATE)) <=
                                                TRUNC (SYSDATE)
                                            AND NVL (
                                                    TRUNC (
                                                        ffvl.end_date_active),
                                                    TRUNC (SYSDATE)) >=
                                                TRUNC (SYSDATE)
                                            AND ffvl.enabled_flag = 'Y')
                            AND pn_org_id = 'ALL')
                        OR (ooha.org_id = pn_org_id AND pn_org_id <> 'ALL'))
                   AND custom.period_end_date =
                       NVL (
                           TO_DATE (pv_period_end_date,
                                    'YYYY/MM/DD HH24:MI:SS'),
                           custom.period_end_date)
                   AND TO_DATE (custom.created, 'DD-MON-YYYY') BETWEEN NVL (
                                                                           TO_DATE (
                                                                               pv_order_created_from,
                                                                               'YYYY/MM/DD HH24:MI:SS'),
                                                                           TO_DATE (
                                                                               custom.created,
                                                                               'DD-MON-YYYY'))
                                                                   AND NVL (
                                                                           TO_DATE (
                                                                               pv_order_created_to,
                                                                               'YYYY/MM/DD HH24:MI:SS'),
                                                                           TO_DATE (
                                                                               custom.created,
                                                                               'DD-MON-YYYY'))
                   AND custom.request_id = pn_request_id;

        -- cursor to get max request id
        CURSOR get_max_request IS
            SELECT MAX (custom.request_id)
              FROM xxdo.xxd_wms_open_ret_ext_t custom, apps.oe_order_headers_all ooha
             WHERE     ooha.order_number = custom.ra_nbr
                   AND subledr_acc_bal <> 0
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxdo.xxd_wms_open_ret_ext_postgl_t custom_gl
                             WHERE     custom_gl.ra_nbr = custom.ra_nbr
                                   AND NVL (custom_gl.status, 'X') = 'S'
                                   AND custom_gl.period_end_date =
                                       custom.period_end_date)
                   AND (   (    org_id IN
                                    (SELECT attribute1
                                       FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                                      WHERE     fvs.flex_value_set_id =
                                                ffvl.flex_value_set_id
                                            AND fvs.flex_value_set_name =
                                                'XXD_GL_AAR_OU_SHORTNAME_VS'
                                            AND NVL (
                                                    TRUNC (
                                                        ffvl.start_date_active),
                                                    TRUNC (SYSDATE)) <=
                                                TRUNC (SYSDATE)
                                            AND NVL (
                                                    TRUNC (
                                                        ffvl.end_date_active),
                                                    TRUNC (SYSDATE)) >=
                                                TRUNC (SYSDATE)
                                            AND ffvl.enabled_flag = 'Y')
                            AND pn_org_id = 'ALL')
                        OR (ooha.org_id = pn_org_id AND pn_org_id <> 'ALL'))
                   AND custom.period_end_date =
                       NVL (
                           TO_DATE (pv_period_end_date,
                                    'YYYY/MM/DD HH24:MI:SS'),
                           custom.period_end_date)
                   AND TO_DATE (custom.created, 'DD-MON-YYYY') BETWEEN NVL (
                                                                           TO_DATE (
                                                                               pv_order_created_from,
                                                                               'YYYY/MM/DD HH24:MI:SS'),
                                                                           TO_DATE (
                                                                               custom.created,
                                                                               'DD-MON-YYYY'))
                                                                   AND NVL (
                                                                           TO_DATE (
                                                                               pv_order_created_to,
                                                                               'YYYY/MM/DD HH24:MI:SS'),
                                                                           TO_DATE (
                                                                               custom.created,
                                                                               'DD-MON-YYYY'));


        lv_cust_segment1        gl_code_combinations.segment1%TYPE;
        lv_cust_segment2        gl_code_combinations.segment2%TYPE;
        lv_cust_segment3        gl_code_combinations.segment3%TYPE;
        lv_cust_segment4        gl_code_combinations.segment4%TYPE;
        lv_cust_segment5        gl_code_combinations.segment5%TYPE;
        lv_cust_segment6        gl_code_combinations.segment6%TYPE;
        lv_cust_segment7        gl_code_combinations.segment7%TYPE;
        lv_cust_segment8        gl_code_combinations.segment8%TYPE;
        lv_error_message        VARCHAR2 (4000) := NULL;
        lv_err_msg              VARCHAR2 (32767) := NULL;
        --lv_natural_account     VARCHAR2(50);
        lv_cogs_account         VARCHAR2 (20);
        lv_organization_name    VARCHAR2 (200);
        lv_line_desc            VARCHAR2 (1000);
        ln_cursor_count         NUMBER := 0;
        lv_vs_natural_account   VARCHAR2 (50) := NULL;
        lv_vs_brand             VARCHAR2 (50) := NULL;
        lv_vs_channel           VARCHAR2 (50) := NULL;
        lv_vs_costcentre        VARCHAR2 (50) := NULL;
        lv_vs_intercompany      VARCHAR2 (50) := NULL;
        ln_max_request          NUMBER := 0;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Insert Procedure starts...');

        OPEN get_max_request;

        FETCH get_max_request INTO ln_max_request;

        CLOSE get_max_request;

        fnd_file.put_line (
            fnd_file.LOG,
            'Max Request id in Source table:' || ln_max_request);

        FOR i IN insert_eligible_records (ln_max_request)
        LOOP
            ln_cursor_count    := ln_cursor_count + 1;
            -- Procedure to fetch code combinations from customer billto site
            fetch_cust_billto_code_comb (i.invoice_to_org_id, lv_cust_segment1, lv_cust_segment2, lv_cust_segment3, lv_cust_segment4, lv_cust_segment5, lv_cust_segment6, lv_cust_segment7, lv_cust_segment8
                                         , lv_error_message);

            IF lv_error_message IS NOT NULL
            THEN
                fnd_file.put_line (fnd_file.LOG, lv_error_message);
                pn_retcode   := 1;
            END IF;

            -- PROCEDURE to fetch natural account, brand,channel, cost centre from value set
            lv_error_message   := NULL;

            get_valueset_natural_acct (i.org_id, lv_error_message, lv_vs_natural_account, lv_vs_brand, lv_vs_channel, lv_vs_costcentre
                                       , lv_vs_intercompany);

            IF lv_error_message IS NOT NULL
            THEN
                fnd_file.put_line (fnd_file.LOG, lv_error_message);
            END IF;

            -- Function to fetch natural account from order type
            lv_error_message   := NULL;
            lv_cogs_account    :=
                get_acct_order_type (i.order_type_id, lv_error_message);

            IF lv_error_message IS NOT NULL
            THEN
                fnd_file.put_line (fnd_file.LOG, lv_error_message);
                pn_retcode   := 1;
            END IF;


            -- Query to fetch OU Name
            BEGIN
                SELECT name
                  INTO lv_organization_name
                  FROM hr_operating_units
                 WHERE organization_id = i.org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_organization_name   := NULL;
                    lv_error_message       :=
                        'Failed to fetch the organization name' || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, lv_error_message);
            END;

            -- Query to fetch line description

            BEGIN
                SELECT lv_organization_name || '_' || i.store_location || '_' || i.brand || '_' || SYSDATE
                  INTO lv_line_desc
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_line_desc   := NULL;
                    lv_error_messagE   :=
                        'Failed to fetch line description' || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, lv_error_message);
            END;

            IF SIGN (i.subledr_acc_bal) = 1
            THEN
                --  Inserting Debit line
                IF (i.entity_uniq_identifier IS NULL OR i.account_number IS NULL OR i.key3 IS NULL OR i.key4 IS NULL OR i.key5 IS NULL OR i.key6 IS NULL OR i.key7 IS NULL)
                THEN
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                        'One of the code combination is null in source table, skipping insertion...');
                ELSE
                    BEGIN
                        INSERT INTO xxdo.xxd_wms_open_ret_ext_postgl_t
                             VALUES (i.request_id, i.ra_nbr, i.store_location, i.created, i.style, i.color_code, i.size_code, i.original_quantity, i.received_quantity, i.cancelled_quantity, i.open_quantity, i.extd_price, i.currency, i.warehouse, i.brand, i.cust_acct_num, i.entity_uniq_identifier, i.account_number, i.key3, i.key4, i.key5, i.key6, i.key7, i.key8, i.key9, i.key10, i.period_end_date, i.subledr_rep_bal, i.subledr_alt_bal, i.subledr_acc_bal, SYSDATE, gn_user_id, SYSDATE, gn_user_id, NULL, i.subledr_acc_bal, lv_line_desc, i.invoice_to_org_id, i.order_type_id, gn_request_id, i.org_id, NULL
                                     , 'Source Debit', NULL);

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Failed to insert in custom table:'
                                || SQLERRM);
                            pn_retcode   := 1;
                    END;

                    -- Inserting Credit line (offset entry)

                    BEGIN
                        INSERT INTO xxdo.xxd_wms_open_ret_ext_postgl_t
                             VALUES (i.request_id, i.ra_nbr, i.store_location, i.created, i.style, i.color_code, i.size_code, i.original_quantity, i.received_quantity, i.cancelled_quantity, i.open_quantity, i.extd_price, i.currency, i.warehouse, i.brand, i.cust_acct_num, i.entity_uniq_identifier, NVL (lv_vs_natural_account, lv_cogs_account), NVL (lv_vs_brand, i.key3), i.key4, NVL (lv_vs_channel, i.key5), NVL (lv_vs_costcentre, i.key6), NVL (lv_vs_intercompany, lv_cust_segment7), lv_cust_segment8, i.key9, i.key10, i.period_end_date, i.subledr_rep_bal, i.subledr_alt_bal, i.subledr_acc_bal, SYSDATE, gn_user_id, SYSDATE, gn_user_id, i.subledr_acc_bal, NULL, lv_line_desc, i.invoice_to_org_id, i.order_type_id, gn_request_id, i.org_id, NULL
                                     , 'Offset Credit', NULL);

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Failed to insert in custom table:'
                                || SQLERRM);
                            pn_retcode   := 1;
                    END;
                END IF;
            ELSE                 -- if value is not possitive and its negative
                -- Inserting the credit line
                IF (i.entity_uniq_identifier IS NULL OR i.account_number IS NULL OR i.key3 IS NULL OR i.key4 IS NULL OR i.key5 IS NULL OR i.key6 IS NULL OR i.key7 IS NULL)
                THEN
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                        'One of the code combination is null in source table, skipping insertion...');
                ELSE
                    BEGIN
                        INSERT INTO xxdo.xxd_wms_open_ret_ext_postgl_t
                             VALUES (i.request_id, i.ra_nbr, i.store_location, i.created, i.style, i.color_code, i.size_code, i.original_quantity, i.received_quantity, i.cancelled_quantity, i.open_quantity, i.extd_price, i.currency, i.warehouse, i.brand, i.cust_acct_num, i.entity_uniq_identifier, i.account_number, i.key3, i.key4, i.key5, i.key6, i.key7, i.key8, i.key9, i.key10, i.period_end_date, i.subledr_rep_bal, i.subledr_alt_bal, i.subledr_acc_bal, SYSDATE, gn_user_id, SYSDATE, gn_user_id, i.subledr_acc_bal, NULL, NULL, i.invoice_to_org_id, i.order_type_id, gn_request_id, i.org_id, NULL
                                     , 'Source Credit', NULL);

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Failed to insert in custom table:'
                                || SQLERRM);
                            pn_retcode   := 1;
                    END;

                    -- Inserting debit line--offset entry

                    BEGIN
                        INSERT INTO xxdo.xxd_wms_open_ret_ext_postgl_t
                             VALUES (i.request_id, i.ra_nbr, i.store_location, i.created, i.style, i.color_code, i.size_code, i.original_quantity, i.received_quantity, i.cancelled_quantity, i.open_quantity, i.extd_price, i.currency, i.warehouse, i.brand, i.cust_acct_num, i.entity_uniq_identifier, NVL (lv_vs_natural_account, lv_cogs_account), NVL (lv_vs_brand, i.key3), i.key4, NVL (lv_vs_channel, i.key5), NVL (lv_vs_costcentre, i.key6), NVL (lv_vs_intercompany, lv_cust_segment7), lv_cust_segment8, i.key9, i.key10, i.period_end_date, i.subledr_rep_bal, i.subledr_alt_bal, i.subledr_acc_bal, SYSDATE, gn_user_id, SYSDATE, gn_user_id, NULL, i.subledr_acc_bal, NULL, i.invoice_to_org_id, i.order_type_id, gn_request_id, i.org_id, NULL
                                     , 'Offset Debit', NULL);

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Failed to insert in custom table:'
                                || SQLERRM);
                            pn_retcode   := 1;
                    END;
                END IF;
            END IF;
        END LOOP;

        IF NVL (ln_cursor_count, 0) = 0
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'There are no eligible records with the given combination');
        --pv_count:=0;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'In Exception for insert_records' || SQLERRM);
    END insert_records;

    -- ======================================================================================
    -- This procedure is used to generate the report
    -- ======================================================================================

    PROCEDURE main (pv_errbuf OUT VARCHAR2, pn_retcode OUT NUMBER, pn_org_id IN VARCHAR2
                    , pv_period_end_date IN VARCHAR2, pv_order_created_from IN VARCHAR2, pv_order_created_to IN VARCHAR2)
    AS
        lv_errbuff   VARCHAR2 (4000);
        ln_retcode   NUMBER;
        ln_count     NUMBER;
    BEGIN
        -- Display Report parameters
        fnd_file.put_line (fnd_file.LOG, 'pn_org_id:' || pn_org_id);
        fnd_file.put_line (fnd_file.LOG,
                           'pv_period_end_date:' || pv_period_end_date);
        fnd_file.put_line (fnd_file.LOG,
                           'pv_order_created_from:' || pv_order_created_from);
        fnd_file.put_line (fnd_file.LOG,
                           'pv_order_created_to:' || pv_order_created_to);
        insert_records (pn_org_id, pv_period_end_date, pv_order_created_from,
                        pv_order_created_to, ln_retcode, lv_errbuff);
        pn_retcode   := ln_retcode;
        pv_errbuf    := lv_errbuff;
        --IF NVL(ln_count,0) <> 0 THEN
        generate_journal_entry (pn_org_id,
                                pv_period_end_date,
                                pv_order_created_from,
                                pv_order_created_to,
                                ln_retcode,
                                lv_errbuff);
        --END IF;
        pn_retcode   := ln_retcode;
        pv_errbuf    := lv_errbuff;
    END main;
END xxd_gl_open_retinv_journal_pkg;
/
