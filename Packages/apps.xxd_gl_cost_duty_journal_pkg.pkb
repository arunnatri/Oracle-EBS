--
-- XXD_GL_COST_DUTY_JOURNAL_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:15 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_GL_COST_DUTY_JOURNAL_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_GL_COST_DUTY_JOURNAL_PKG
    * Design       : This package is used for creating GL Journals for the manual refunds
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 05-Jun-2019  1.0        Viswanathan Pandian     Initial version for Deckers Macau Project CCR0007979
    -- 06-JUL-2020  1.1        Srinath Siricilla       Added for CCR0008782
    ******************************************************************************************/
    gn_user_id      NUMBER := fnd_global.user_id;
    gn_login_id     NUMBER := fnd_global.login_id;
    gn_request_id   NUMBER := fnd_global.conc_request_id;
    gd_sysdate      DATE := SYSDATE;
    gc_mode         VARCHAR2 (10);

    -- Start of Change for CCR0008782
    -- ======================================================================================
    -- This Function will get the required credit and debit code combinations
    -- ======================================================================================

    FUNCTION get_code_combination (pn_inventory_item_id IN NUMBER, pn_organization_id IN NUMBER, pv_account_comb IN VARCHAR2)
        RETURN NUMBER
    IS
        lv_brand_seg   VARCHAR2 (100);
        ln_ccid        NUMBER;
    BEGIN
        BEGIN
            lv_brand_seg   := NULL;
            ln_ccid        := NULL;

            SELECT gcc.segment2
              INTO lv_brand_seg
              FROM apps.mtl_system_items_b msib, apps.gl_code_combinations gcc
             WHERE     gcc.code_combination_id = msib.cost_of_sales_account
                   AND msib.inventory_item_id = pn_inventory_item_id
                   AND msib.organization_id = pn_organization_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                RETURN NULL;
        END;

        IF lv_brand_seg IS NOT NULL AND pv_account_comb IS NOT NULL
        THEN
            BEGIN
                SELECT code_combination_id
                  INTO ln_ccid
                  FROM apps.gl_code_combinations
                 WHERE     segment1 = REGEXP_SUBSTR (pv_account_comb, '\d+', 1
                                                     , 1)
                       AND segment2 = lv_brand_seg
                       AND segment3 = REGEXP_SUBSTR (pv_account_comb, '\d+', 1
                                                     , 3)
                       AND segment4 = REGEXP_SUBSTR (pv_account_comb, '\d+', 1
                                                     , 4)
                       AND segment5 = REGEXP_SUBSTR (pv_account_comb, '\d+', 1
                                                     , 5)
                       AND segment6 = REGEXP_SUBSTR (pv_account_comb, '\d+', 1
                                                     , 6)
                       AND segment7 = REGEXP_SUBSTR (pv_account_comb, '\d+', 1
                                                     , 7)
                       AND segment8 = REGEXP_SUBSTR (pv_account_comb, '\d+', 1
                                                     , 8)
                       AND enabled_flag = 'Y';

                RETURN ln_ccid;
            EXCEPTION
                WHEN OTHERS
                THEN
                    RETURN NULL;
            END;
        ELSE
            RETURN NULL;
        END IF;
    END;

    -- End of Chnage for CCR0008782

    -- ======================================================================================
    -- This procedure will insert data into the staging table
    -- ======================================================================================
    PROCEDURE populate_staging (p_ou_org_id IN hr_operating_units.organization_id%TYPE, p_inventory_org_id IN mtl_parameters.organization_id%TYPE, p_trx_creation_date_from IN VARCHAR2, p_trx_creation_date_to IN VARCHAR2, p_trx_date_from IN VARCHAR2, p_trx_date_to IN VARCHAR2, p_trx_id_from IN mtl_material_transactions.transaction_id%TYPE, p_trx_id_to IN mtl_material_transactions.transaction_id%TYPE, p_source IN gl_interface.user_je_source_name%TYPE, p_category IN gl_interface.user_je_category_name%TYPE, p_rate_type IN gl_interface.user_currency_conversion_type%TYPE, x_ret_status OUT NOCOPY VARCHAR2
                                , x_ret_msg OUT NOCOPY VARCHAR2)
    IS
        --Get MMT Data
        CURSOR get_data IS
            SELECT mmt.organization_id
                       inv_org_id,
                   mp.organization_code
                       inv_org_code,
                   ood.operating_unit
                       operating_unit_id,
                   (SELECT hou.name
                      FROM hr_operating_units hou
                     WHERE hou.organization_id = ood.operating_unit)
                       operating_unit_name,
                   gl.ledger_id,
                   gl.name
                       ledger_name,
                   gl.currency_code
                       ledger_currency_code,
                   p_source
                       user_je_source_name,
                   (SELECT je_source_name
                      FROM gl_je_sources
                     WHERE user_je_source_name = p_source)
                       je_source_name,
                   p_category
                       user_je_category_name,
                   (SELECT je_category_name
                      FROM gl_je_categories
                     WHERE user_je_category_name = p_category)
                       je_category_name,
                   NVL (mmt.currency_code, gl.currency_code)
                       trx_currency_code,
                   mmt.transaction_date
                       accounting_date,
                   mmt.transaction_date
                       currency_conversion_date,
                   p_rate_type
                       user_currency_conversion_type,
                   (TO_NUMBER (mmt.attribute11) * ABS (mmt.transaction_quantity))
                       entered_cr,
                   (TO_NUMBER (mmt.attribute11) * ABS (mmt.transaction_quantity))
                       entered_dr,
                   -- Start of Change for CCR0008782
                   get_code_combination (mmt.inventory_item_id,
                                         mmt.organization_id,
                                         ffv1.attribute2)
                       credit_ccid,
                   get_code_combination (mmt.inventory_item_id,
                                         mmt.organization_id,
                                         ffv1.attribute1)
                       debit_ccid,
                   --                ffv1.attribute2 credit_concatenated_segments,
                   --                (SELECT code_combination_id
                   --                   FROM gl_code_combinations_kfv
                   --                  WHERE concatenated_segments = ffv1.attribute2)
                   --                   credit_ccid,
                   --                ffv1.attribute1 debit_concatenated_segments,
                   --                (SELECT code_combination_id
                   --                   FROM gl_code_combinations_kfv
                   --                  WHERE concatenated_segments = ffv1.attribute1)
                   --                   debit_ccid,
                   -- End of Change
                   'MMT Transaction ID ' || mmt.transaction_id
                       reference10_line_description,
                   mmt.transaction_id
                       reference21,
                   mmt.transaction_id
                       mmt_transaction_id,
                   mmt.transaction_date
                       mmt_transaction_date,
                   mmt.creation_date
                       mmt_creation_date,
                   mtt.transaction_type_name
                       mmt_transaction_type_name,
                   mmt.transaction_type_id
                       mmt_transaction_type_id,
                   TO_NUMBER (mmt.attribute11)
                       duty,
                   ABS (mmt.transaction_quantity)
                       mmt_transaction_quantity,
                   ord_dtls.order_number,
                   ord_dtls.order_line_num,
                   ord_dtls.ordered_item
              FROM mtl_parameters mp,
                   org_organization_definitions ood,
                   gl_ledgers gl,
                   mtl_material_transactions mmt,
                   mtl_transaction_types mtt,
                   fnd_flex_values ffv1,
                   fnd_flex_value_sets ffvs1,
                   fnd_flex_values ffv2,
                   fnd_flex_value_sets ffvs2,
                   (SELECT ooha.org_id, ooha.order_number, oola.line_id,
                           oola.line_number || '.' || oola.shipment_number order_line_num, oola.ordered_item
                      FROM oe_order_headers_all ooha, oe_order_lines_all oola
                     WHERE ooha.header_id = oola.header_id) ord_dtls
             WHERE     mp.organization_id = ood.organization_id
                   AND ood.set_of_books_id = gl.ledger_id
                   AND mmt.organization_id = mp.organization_id
                   AND mmt.transaction_type_id = mtt.transaction_type_id
                   AND ffv1.flex_value_set_id = ffvs1.flex_value_set_id
                   AND ffvs1.flex_value_set_name = 'XXD_CST_TRX_TYPE_LISTING'
                   AND ffv1.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (
                                                       ffv1.start_date_active,
                                                       SYSDATE))
                                           AND TRUNC (
                                                   NVL (ffv1.end_date_active,
                                                        SYSDATE))
                   AND TO_NUMBER (ffv1.flex_value) = mmt.transaction_type_id
                   AND ffvs2.flex_value_set_name = 'XXDO_CST_INV_ORG_LISTING'
                   AND ffv2.flex_value_set_id = ffvs2.flex_value_set_id
                   AND ffv2.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (
                                                       ffv2.start_date_active,
                                                       SYSDATE))
                                           AND TRUNC (
                                                   NVL (ffv2.end_date_active,
                                                        SYSDATE))
                   AND ffv1.parent_flex_value_low = ffv2.flex_value
                   AND ffv1.parent_flex_value_low = mp.organization_code
                   AND mmt.trx_source_line_id = ord_dtls.line_id(+)
                   --Duty Paid Flag
                   AND ((mmt.attribute12 IS NOT NULL AND mmt.attribute12 = 'N') OR (mmt.attribute12 IS NULL AND 1 = 2))
                   --Duty Suppressed Amount
                   AND ((mmt.attribute11 IS NOT NULL AND TO_NUMBER (mmt.attribute11) > 0) OR (mmt.attribute11 IS NULL AND 1 = 2))
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxdo.xxd_gl_cost_duty_journal_t xgcd
                             WHERE     xgcd.mmt_transaction_id =
                                       mmt.transaction_id
                                   AND xgcd.record_status = 'P')
                   --Input Parameters
                   --Operating Unit
                   AND ((p_ou_org_id IS NOT NULL AND ood.operating_unit = p_ou_org_id) OR (p_ou_org_id IS NULL AND 1 = 1))
                   --Inventory Org
                   AND ((p_inventory_org_id IS NOT NULL AND mmt.organization_id = p_inventory_org_id) OR (p_inventory_org_id IS NULL AND 1 = 1))
                   --Transaction Creation Date
                   AND ((p_trx_creation_date_from IS NOT NULL AND p_trx_creation_date_to IS NOT NULL AND mmt.creation_date > fnd_date.canonical_to_date (p_trx_creation_date_from) - 1 AND mmt.creation_date < fnd_date.canonical_to_date (p_trx_creation_date_to) + 1) OR ((p_trx_creation_date_from IS NULL OR p_trx_creation_date_to IS NULL) AND 1 = 1))
                   --Transaction Date
                   AND ((p_trx_date_from IS NOT NULL AND p_trx_date_to IS NOT NULL AND mmt.transaction_date > fnd_date.canonical_to_date (p_trx_date_from) - 1 AND mmt.transaction_date < fnd_date.canonical_to_date (p_trx_date_to) + 1) OR ((p_trx_date_from IS NULL OR p_trx_date_to IS NULL) AND 1 = 1))
                   --Transaction ID
                   AND ((p_trx_id_from IS NOT NULL AND p_trx_id_to IS NOT NULL AND mmt.transaction_id >= p_trx_id_from AND mmt.transaction_id <= p_trx_id_to) OR ((p_trx_id_from IS NULL OR p_trx_id_to IS NULL) AND 1 = 1));

        ln_count             NUMBER := 0;
        lv_credit_segments   VARCHAR2 (100) := NULL;
        lv_debit_segments    VARCHAR2 (100) := NULL;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Populate Staging Table');

        FOR data_rec IN get_data
        LOOP
            -- Start of Change for CCR0008782

            lv_debit_segments    := NULL;
            lv_credit_segments   := NULL;

            IF data_rec.credit_ccid IS NOT NULL
            THEN
                BEGIN
                    SELECT concatenated_segments
                      INTO lv_credit_segments
                      FROM apps.gl_code_combinations_kfv
                     WHERE     code_combination_id = data_rec.credit_ccid
                           AND enabled_flag = 'Y';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_credit_segments   := NULL;
                END;
            END IF;

            IF data_rec.debit_ccid IS NOT NULL
            THEN
                BEGIN
                    SELECT concatenated_segments
                      INTO lv_debit_segments
                      FROM apps.gl_code_combinations_kfv
                     WHERE     code_combination_id = data_rec.debit_ccid
                           AND enabled_flag = 'Y';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_debit_segments   := NULL;
                END;
            END IF;

            -- End of Change for CCR0008782

            ln_count             := ln_count + 1;

            INSERT INTO xxdo.xxd_gl_cost_duty_journal_t (
                            inv_org_id,
                            inv_org_code,
                            operating_unit_id,
                            operating_unit_name,
                            ledger_id,
                            ledger_name,
                            ledger_currency_code,
                            user_je_source_name,
                            je_source_name,
                            user_je_category_name,
                            je_category_name,
                            trx_currency_code,
                            accounting_date,
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
                            mmt_transaction_id,
                            mmt_transaction_date,
                            mmt_creation_date,
                            mmt_transaction_type_name,
                            mmt_transaction_type_id,
                            duty,
                            mmt_transaction_quantity,
                            order_number,
                            order_line_num,
                            ordered_item,
                            program_mode,
                            record_status,
                            error_message,
                            request_id,
                            created_by,
                            creation_date,
                            last_updated_by,
                            last_update_date,
                            last_update_login)
                 VALUES (data_rec.inv_org_id, data_rec.inv_org_code, data_rec.operating_unit_id, data_rec.operating_unit_name, data_rec.ledger_id, data_rec.ledger_name, data_rec.ledger_currency_code, data_rec.user_je_source_name, data_rec.je_source_name, data_rec.user_je_category_name, data_rec.je_category_name, data_rec.trx_currency_code, data_rec.accounting_date, data_rec.currency_conversion_date, data_rec.user_currency_conversion_type, data_rec.entered_cr, data_rec.entered_dr, --data_rec.credit_concatenated_segments,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     lv_credit_segments, data_rec.credit_ccid, --data_rec.debit_concatenated_segments,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               lv_debit_segments, data_rec.debit_ccid, data_rec.reference10_line_description, data_rec.reference21, data_rec.mmt_transaction_id, data_rec.mmt_transaction_date, data_rec.mmt_creation_date, data_rec.mmt_transaction_type_name, data_rec.mmt_transaction_type_id, data_rec.duty, data_rec.mmt_transaction_quantity, data_rec.order_number, data_rec.order_line_num, data_rec.ordered_item, gc_mode, DECODE (gc_mode, 'Final', 'N', 'R'), NULL, gn_request_id, gn_user_id, gd_sysdate
                         , gn_user_id, gd_sysdate, gn_login_id);

            -- Start of Change CCR0008782

            IF data_rec.debit_ccid IS NULL OR data_rec.credit_ccid IS NULL
            THEN
                UPDATE xxdo.xxd_gl_cost_duty_journal_t
                   SET record_status = 'E', error_message = error_message || ' - ' || ' Credit CCID or DEBIT CCID is Null. Please review '
                 WHERE mmt_transaction_id = data_rec.mmt_transaction_id;
            END IF;
        -- End of Change CCR0008782

        END LOOP;

        fnd_file.put_line (fnd_file.LOG,
                           'Staging Table Record Count: ' || ln_count);

        x_ret_status   := 'S';
        x_ret_msg      := NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
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
            SELECT ROWID, ledger_id, accounting_date,
                   trx_currency_code, creation_date, created_by,
                   ledger_currency_code, currency_conversion_date, user_currency_conversion_type,
                   reference10_line_description, reference21, credit_ccid,
                   entered_cr, debit_ccid, entered_dr,
                   user_je_source_name, user_je_category_name
              FROM xxdo.xxd_gl_cost_duty_journal_t
             WHERE request_id = gn_request_id AND record_status = 'N';

        ln_count   NUMBER := 0;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Populate GL Interface');

        FOR valid_data_rec IN get_valid_data
        LOOP
            ln_count   := ln_count + 1;

            -- Credit
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
                                valid_data_rec.trx_currency_code,
                                valid_data_rec.creation_date,
                                valid_data_rec.created_by,
                                'A',
                                CASE
                                    WHEN valid_data_rec.ledger_currency_code <>
                                         valid_data_rec.trx_currency_code
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
                                         valid_data_rec.trx_currency_code
                                    THEN
                                        valid_data_rec.user_currency_conversion_type
                                    ELSE
                                        NULL
                                END);

            -- Debit
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
                                valid_data_rec.trx_currency_code,
                                valid_data_rec.creation_date,
                                valid_data_rec.created_by,
                                'A',
                                CASE
                                    WHEN valid_data_rec.ledger_currency_code <>
                                         valid_data_rec.trx_currency_code
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
                                         valid_data_rec.trx_currency_code
                                    THEN
                                        valid_data_rec.user_currency_conversion_type
                                    ELSE
                                        NULL
                                END);

            UPDATE xxdo.xxd_gl_cost_duty_journal_t
               SET record_status   = 'P'
             WHERE ROWID = valid_data_rec.ROWID;
        END LOOP;

        fnd_file.put_line (fnd_file.LOG,
                           'GL_INTERFACE Record Count: ' || ln_count * 2);
        x_ret_status   := 'S';
        x_ret_msg      := NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            x_ret_status   := 'E';
            x_ret_msg      := SQLERRM;
            fnd_file.put_line (fnd_file.LOG,
                               'Error in POPULATE_GL_INT:' || SQLERRM);
    END populate_gl_int;

    -- ======================================================================================
    -- This procedure will be called from the concurrent program
    -- ======================================================================================
    PROCEDURE main (x_retcode OUT NOCOPY VARCHAR2, x_errbuf OUT NOCOPY VARCHAR2, p_ou_org_id IN hr_operating_units.organization_id%TYPE, p_inventory_org_id IN mtl_parameters.organization_id%TYPE, p_trx_creation_date_from IN VARCHAR2, p_trx_creation_date_to IN VARCHAR2, p_trx_date_from IN VARCHAR2, p_trx_date_to IN VARCHAR2, p_trx_id_from IN mtl_material_transactions.transaction_id%TYPE, p_trx_id_to IN mtl_material_transactions.transaction_id%TYPE, p_source IN gl_interface.user_je_source_name%TYPE, p_category IN gl_interface.user_je_category_name%TYPE
                    , p_rate_type IN gl_interface.user_currency_conversion_type%TYPE, p_mode IN VARCHAR2)
    IS
        CURSOR get_data IS
            SELECT DECODE (COUNT (1), 0, 0, 1)
              FROM xxdo.xxd_gl_cost_duty_journal_t
             WHERE request_id = gn_request_id;

        lc_ret_status    VARCHAR2 (30);
        lc_ret_msg       VARCHAR2 (4000);
        ln_request_id    NUMBER;
        ln_count         NUMBER := 0;
        lb_flag          BOOLEAN;
        ex_ins_staging   EXCEPTION;
        ex_pop_gl_int    EXCEPTION;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Start MAIN');
        fnd_file.put_line (
            fnd_file.LOG,
            'Start Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        gc_mode   := p_mode;

        --Populate Data into Staging table
        populate_staging (p_ou_org_id => p_ou_org_id, p_inventory_org_id => p_inventory_org_id, p_trx_creation_date_from => p_trx_creation_date_from, p_trx_creation_date_to => p_trx_creation_date_to, p_trx_date_from => p_trx_date_from, p_trx_date_to => p_trx_date_to, p_trx_id_from => p_trx_id_from, p_trx_id_to => p_trx_id_to, p_source => p_source, p_category => p_category, p_rate_type => p_rate_type, x_ret_status => lc_ret_status
                          , x_ret_msg => lc_ret_msg);

        IF lc_ret_status = 'E'
        THEN
            RAISE ex_ins_staging;
        END IF;

        IF p_mode = 'Final'
        THEN
            --Populate valid data into GL_INTERFACE
            populate_gl_int (x_ret_status   => lc_ret_status,
                             x_ret_msg      => lc_ret_msg);

            IF lc_ret_status = 'E'
            THEN
                RAISE ex_pop_gl_int;
            END IF;
        ELSE
            fnd_file.put_line (
                fnd_file.LOG,
                'For Draft mode, Skipping GL_INTERFACE insert');
        END IF;

        --Submit Report
        FOR i IN get_data
        LOOP
            lb_flag   :=
                fnd_request.add_layout (
                    template_appl_name   => 'XXDO',
                    template_code        => 'XXD_GL_COST_DUTY_JOUR_REP',
                    template_language    => 'en',
                    template_territory   => '00',
                    output_format        => 'EXCEL');
            ln_request_id   :=
                fnd_request.submit_request (
                    application   => 'XXDO',
                    program       => 'XXD_GL_COST_DUTY_JOUR_REP',
                    argument1     => p_ou_org_id,
                    argument2     => p_inventory_org_id,
                    argument3     => p_trx_creation_date_from,
                    argument4     => p_trx_creation_date_to,
                    argument5     => p_trx_date_from,
                    argument6     => p_trx_date_to,
                    argument7     => p_trx_id_from,
                    argument8     => p_trx_id_to,
                    argument9     => gn_request_id);
            COMMIT;
        END LOOP;

        --Delete Report Data
        DELETE xxdo.xxd_gl_cost_duty_journal_t
         WHERE     request_id = gn_request_id
               AND record_status = 'R'
               AND creation_date < SYSDATE - 30;

        fnd_file.put_line (
            fnd_file.LOG,
            'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        fnd_file.put_line (fnd_file.LOG, 'End MAIN');
    EXCEPTION
        WHEN ex_ins_staging
        THEN
            ROLLBACK;
            x_retcode   := '1';
            x_errbuf    := lc_ret_msg;
            fnd_file.put_line (
                fnd_file.LOG,
                'Error Populating data into Staging:' || lc_ret_msg);

            UPDATE xxdo.xxd_gl_cost_duty_journal_t
               SET record_status = 'E', error_message = x_errbuf
             WHERE request_id = gn_request_id;
        WHEN ex_pop_gl_int
        THEN
            ROLLBACK;
            x_retcode   := '1';
            x_errbuf    := lc_ret_msg;
            fnd_file.put_line (
                fnd_file.LOG,
                'Error Populating GL_INTERFACE table:' || lc_ret_msg);

            UPDATE xxdo.xxd_gl_cost_duty_journal_t
               SET record_status = 'E', error_message = x_errbuf
             WHERE request_id = gn_request_id;
        WHEN OTHERS
        THEN
            ROLLBACK;
            x_retcode   := '2';
            x_errbuf    := SQLERRM;
            fnd_file.put_line (fnd_file.LOG, 'Error in MAIN:' || SQLERRM);

            UPDATE xxdo.xxd_gl_cost_duty_journal_t
               SET record_status = 'E', error_message = x_errbuf
             WHERE request_id = gn_request_id;
    END main;
END xxd_gl_cost_duty_journal_pkg;
/
