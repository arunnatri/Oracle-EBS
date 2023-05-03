--
-- XXD_AP_INVOICE_ALLOCATION_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:49 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AP_INVOICE_ALLOCATION_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_AP_INVOICE_ALLOCATION_PKG
    * Design       : This package will be used in Frieght Allocation Customization
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 08-Aug-2018  1.0        Viswanathan Pandian     Initial Version
    -- 05-Sep-2018  1.0        Tejaswi Gangumalla      Intial Version
    ******************************************************************************************/

    --This procedure is used to update alocation rule to Amount
    PROCEDURE update_allocation_rule (p_invoice_id IN ap_invoices_all.invoice_id%TYPE, pv_error_msg OUT VARCHAR2)
    AS
        CURSOR get_rule_c IS
            SELECT aar.ROWID, aila.line_number chrg_invoice_line_number
              FROM ap_allocation_rules aar, ap_invoice_lines_all aila
             WHERE     aar.invoice_id = aila.invoice_id
                   AND aar.chrg_invoice_line_number = aila.line_number
                   AND aila.line_type_lookup_code = 'FREIGHT'
                   AND aila.amount > 0
                   AND aila.invoice_id = p_invoice_id;

        lcu_rule_rec   get_rule_c%ROWTYPE;
    BEGIN
        OPEN get_rule_c;

        FETCH get_rule_c INTO lcu_rule_rec;

        IF lcu_rule_rec.ROWID IS NOT NULL
        THEN
            ap_allocation_rules_pkg.update_row (
                x_rowid                      => lcu_rule_rec.ROWID,
                x_invoice_id                 => p_invoice_id,
                x_chrg_invoice_line_number   =>
                    lcu_rule_rec.chrg_invoice_line_number,
                x_rule_type                  => 'AMOUNT',
                x_rule_generation_type       => 'USER',
                x_status                     => 'PENDING',
                x_last_updated_by            => fnd_global.user_id,
                x_last_update_date           => SYSDATE,
                x_last_update_login          => fnd_global.login_id,
                x_calling_sequence           => 'FORM');
        END IF;

        CLOSE get_rule_c;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_msg   := SQLERRM;
    END update_allocation_rule;

    --This procedure updates allocation rule lines
    PROCEDURE update_allocation_rule_line (p_invoice_id IN ap_invoices_all.invoice_id%TYPE, pv_error_msg OUT VARCHAR2)
    AS
        CURSOR get_rule_c IS
            SELECT aila.line_number chrg_invoice_line_number, aila.amount freight_amount
              FROM ap_allocation_rules aar, ap_invoice_lines_all aila
             WHERE     aar.invoice_id = aila.invoice_id
                   AND aar.chrg_invoice_line_number = aila.line_number
                   AND aar.rule_type = 'AMOUNT'
                   AND aila.line_type_lookup_code = 'FREIGHT'
                   AND aila.amount > 0
                   AND aila.invoice_id = p_invoice_id;

        CURSOR get_lines_c (p_freight_amount   IN NUMBER,
                            lv_currency_code      VARCHAR2)
        IS
            SELECT line_number to_invoice_line_number, 'Y' allocation_flag, ap_utilities_pkg.ap_round_currency (p_freight_amount * ratio_to_report (amount) OVER (PARTITION BY 1), lv_currency_code) allocation_amount
              FROM ap_invoice_lines_all ail
             WHERE     invoice_id = p_invoice_id
                   AND ail.line_type_lookup_code = 'ITEM'
                   AND (   ail.product_type = 'GOODS'
                        OR (    ail.product_type IS NULL
                            AND EXISTS
                                    (SELECT 1
                                       FROM gl_code_combinations gcc, fnd_flex_value_sets ffvs, fnd_flex_values ffv,
                                            fnd_flex_values_tl ffvt
                                      WHERE     gcc.code_combination_id =
                                                ail.default_dist_ccid
                                            AND ffvs.flex_value_set_id =
                                                ffv.flex_value_set_id
                                            AND ffv.flex_value = gcc.segment6
                                            AND ffv.flex_value_id =
                                                ffvt.flex_value_id
                                            AND ffvt.LANGUAGE =
                                                USERENV ('LANG')
                                            AND flex_value_set_name =
                                                'XXD_FREIGHT_ALLOCATE_GL_VALUES'
                                            AND TRUNC (ffv.start_date_active) <=
                                                TRUNC (SYSDATE)
                                            AND TRUNC (
                                                    NVL (ffv.end_date_active,
                                                         TRUNC (SYSDATE))) >=
                                                TRUNC (SYSDATE)
                                            AND ffv.enabled_flag = 'Y')))
            UNION
            SELECT line_number to_invoice_line_number, 'N' allocation_flag, 0 allocation_amount
              FROM ap_invoice_lines_all ail
             WHERE     invoice_id = p_invoice_id
                   --AND ail.line_type_lookup_code = 'ITEM'
                   AND (   product_type = 'SERVICES'
                        OR (    ail.product_type IS NULL
                            AND NOT EXISTS
                                    (SELECT 1
                                       FROM gl_code_combinations gcc, fnd_flex_value_sets ffvs, fnd_flex_values ffv,
                                            fnd_flex_values_tl ffvt
                                      WHERE     gcc.code_combination_id =
                                                ail.default_dist_ccid
                                            AND ffvs.flex_value_set_id =
                                                ffv.flex_value_set_id
                                            AND ffv.flex_value = gcc.segment6
                                            AND ffv.flex_value_id =
                                                ffvt.flex_value_id
                                            AND ffvt.LANGUAGE =
                                                USERENV ('LANG')
                                            AND flex_value_set_name =
                                                'XXD_FREIGHT_ALLOCATE_GL_VALUES'
                                            AND TRUNC (ffv.start_date_active) <=
                                                TRUNC (SYSDATE)
                                            AND TRUNC (
                                                    NVL (ffv.end_date_active,
                                                         TRUNC (SYSDATE))) >=
                                                TRUNC (SYSDATE)
                                            AND ffv.enabled_flag = 'Y')));

        lc_rowid                    VARCHAR2 (2000);
        lc_rule_error_code          VARCHAR2 (2000);
        lc_rule_line_error_code     VARCHAR2 (2000);
        ln_rule_line_count          NUMBER := 0;
        lb_alloc_rule_line_status   BOOLEAN;
        lv_success                  BOOLEAN := FALSE;
        ln_line_number              NUMBER;
        ln_total_prorated           NUMBER;
        lv_currency_code            VARCHAR2 (10);
        ln_adj_to_inv_line_num      NUMBER;
        ln_adj_amt                  NUMBER;
    BEGIN
        SELECT invoice_currency_code, line_number
          INTO lv_currency_code, ln_line_number
          FROM ap_invoices_all ap, ap_invoice_lines_all ail
         WHERE     ap.invoice_id = p_invoice_id
               AND ap.invoice_id = ail.invoice_id
               AND line_type_lookup_code = 'FREIGHT'
               AND amount > 0;

        FOR i IN get_rule_c
        LOOP
            FOR j IN get_lines_c (i.freight_amount, lv_currency_code)
            LOOP
                lb_alloc_rule_line_status   :=
                    ap_allocation_rules_pkg.allocation_rule_lines (
                        x_invoice_id               => p_invoice_id,
                        x_chrg_invoice_line_number   =>
                            i.chrg_invoice_line_number,
                        x_to_invoice_line_number   => j.to_invoice_line_number,
                        x_allocated_percentage     => NULL,
                        x_allocated_amount         => j.allocation_amount,
                        x_allocation_flag          => j.allocation_flag,
                        x_error_code               => lc_rule_line_error_code);

                IF lb_alloc_rule_line_status
                THEN
                    NULL;
                ELSE
                    pv_error_msg   :=
                        pv_error_msg || ' ' || lc_rule_line_error_code;
                END IF;
            END LOOP;
        END LOOP;

        --Check if allocated amount is equal to invoice freight line amount. If not adjust the difference in amount to MAX charge line number
        BEGIN
            FOR i IN get_rule_c
            LOOP
                SELECT SUM (amount)
                  INTO ln_total_prorated
                  FROM ap_allocation_rule_lines
                 WHERE     invoice_id = p_invoice_id
                       AND chrg_invoice_line_number =
                           i.chrg_invoice_line_number;


                IF ln_total_prorated <> i.freight_amount
                THEN
                    SELECT MAX (arl.to_invoice_line_number)
                      INTO ln_adj_to_inv_line_num
                      FROM ap_allocation_rule_lines arl
                     WHERE     arl.invoice_id = p_invoice_id
                           AND arl.chrg_invoice_line_number =
                               i.chrg_invoice_line_number
                           AND arl.amount <> 0;

                    SELECT amount + (i.freight_amount - ln_total_prorated)
                      INTO ln_adj_amt
                      FROM ap_allocation_rule_lines
                     WHERE     invoice_id = p_invoice_id
                           AND chrg_invoice_line_number =
                               i.chrg_invoice_line_number
                           AND to_invoice_line_number =
                               ln_adj_to_inv_line_num;

                    lb_alloc_rule_line_status   :=
                        ap_allocation_rules_pkg.allocation_rule_lines (
                            x_invoice_id             => p_invoice_id,
                            x_chrg_invoice_line_number   =>
                                i.chrg_invoice_line_number,
                            x_to_invoice_line_number   =>
                                ln_adj_to_inv_line_num,
                            x_allocated_percentage   => NULL,
                            x_allocated_amount       => ln_adj_amt,
                            x_allocation_flag        => 'Y',
                            x_error_code             =>
                                lc_rule_line_error_code);

                    IF lb_alloc_rule_line_status
                    THEN
                        NULL;
                    ELSE
                        pv_error_msg   :=
                            pv_error_msg || ' ' || lc_rule_line_error_code;
                    END IF;
                END IF;
            END LOOP;
        END;

        --Call update_distributuin procedure to create/update invoice distributions for freight line based on freight allocation
        IF pv_error_msg IS NULL
        THEN
            update_distribution (p_invoice_id, ln_line_number, pv_error_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_msg   := SQLERRM;
    END update_allocation_rule_line;

    --This package is used to create proration rule
    PROCEDURE create_allocation (p_invoice_id IN ap_invoices_all.invoice_id%TYPE, pn_inv_charge_line_num IN NUMBER, pv_error_msg OUT VARCHAR2)
    AS
        lv_error_code            VARCHAR2 (2000);
        lv_debug_info            VARCHAR2 (2000);
        lv_debug_context         VARCHAR2 (2000);
        lv_status                BOOLEAN;
        ln_chrg_iv_line_number   NUMBER;
        l_generate_dists         VARCHAR2 (10);
        l_amount_to_prorate      NUMBER;
        l_inv_curr_code          VARCHAR2 (50);
    BEGIN
        lv_status   :=
            ap_allocation_rules_pkg.create_proration_rule (
                p_invoice_id,
                pn_inv_charge_line_num,
                NULL,
                'ALLOCATIONS_RULE',
                lv_error_code,
                lv_debug_info,
                lv_debug_context,
                'APXALLOC');

        IF lv_status
        THEN
            NULL;
        ELSE
            pv_error_msg   := lv_error_code;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_msg   := SQLERRM;
    END create_allocation;

    --This procedure is used to create/update invoice distributions for freight line based on fright allocation
    PROCEDURE update_distribution (p_invoice_id IN ap_invoices_all.invoice_id%TYPE, pn_inv_charge_line_num IN NUMBER, pv_error_msg OUT VARCHAR2)
    IS
        ln_line_number             NUMBER;
        lv_accounting_date         VARCHAR2 (50);
        lv_period_name             VARCHAR2 (50);
        lv_generate_dists          VARCHAR2 (2);
        lv_success                 BOOLEAN := FALSE;
        lv_error_code              VARCHAR2 (4000);
        lv_debug_context           VARCHAR2 (2000);
        lv_msg_application         VARCHAR2 (25);
        lv_msg_data                VARCHAR2 (200);
        lv_curr_calling_sequence   VARCHAR2 (2000);
        lv_debug_info              VARCHAR2 (2000);
        lv_hold_count              NUMBER;
        lv_approval_status         VARCHAR2 (2000);
        lv_funds_return_code       VARCHAR2 (2000);
    BEGIN
        SELECT line_number, accounting_date, period_name,
               generate_dists
          INTO ln_line_number, lv_accounting_date, lv_period_name, lv_generate_dists
          FROM ap_invoice_lines_all
         WHERE     invoice_id = p_invoice_id
               AND line_type_lookup_code = 'FREIGHT'
               AND amount > 0;

        lv_success   :=
            ap_invoice_distributions_pkg.insert_charge_from_alloc (
                x_invoice_id           => p_invoice_id,
                x_line_number          => ln_line_number,
                x_generate_permanent   => 'PERMANENT',
                x_validate_info        => TRUE,
                x_error_code           => lv_error_code,
                x_debug_info           => lv_debug_info,
                x_debug_context        => lv_debug_context,
                x_msg_application      => lv_msg_application,
                x_msg_data             => lv_msg_data,
                x_calling_sequence     => lv_curr_calling_sequence);

        IF (NOT lv_success)
        THEN
            IF (lv_error_code IS NOT NULL)
            THEN
                pv_error_msg   := lv_error_code;
            END IF;
        ELSE
            apps.ap_approval_pkg.approve ('',                   --p_run_option
                                              '',         --p_invoice_batch_id
                                                  '',   --p_begin_invoice_date
                                          '',             --p_end_invoice_date
                                              '',                --p_vendor_id
                                                  '',            --p_pay_group
                                          p_invoice_id,         --p_invoice_id
                                                        '',     --p_entered_by
                                                            '', --p_set_of_books_id
                                          '',                 --p_trace_option
                                              '',                --p_conc_flag
                                                  lv_hold_count, --p_holds_count
                                          lv_approval_status, --p_approval_status
                                                              lv_funds_return_code, --p_funds_return_code
                                                                                    'APPROVE', --p_calling_mode
                                                                                               'Calling From Invoice Validation Hook', --p_calling_sequence
                                                                                                                                       '', --p_debug_switch
                                                                                                                                           ''
                                          ,                 --p_budget_control
                                            ''                      --p_commit
                                              );
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_msg   := SQLERRM;
    END update_distribution;

    --This procedure is used to check if allocated amount for Amount rule is correct or not
    PROCEDURE check_amt_alloc (p_invoice_id IN ap_invoices_all.invoice_id%TYPE, pn_inv_charge_line_num IN NUMBER, pv_currency_code IN VARCHAR2
                               , pn_frt_amount IN NUMBER, pv_alloc_diff OUT VARCHAR2, pv_error_msg OUT VARCHAR2)
    IS
        CURSOR get_lines_c IS
            SELECT line_number to_invoice_line_number, 'Y' allocation_flag, ap_utilities_pkg.ap_round_currency (pn_frt_amount * ratio_to_report (amount) OVER (PARTITION BY 1), pv_currency_code) allocation_amount
              FROM ap_invoice_lines_all ail
             WHERE     invoice_id = p_invoice_id
                   AND ail.line_type_lookup_code = 'ITEM'
                   AND (   ail.product_type = 'GOODS'
                        OR (    ail.product_type IS NULL
                            AND EXISTS
                                    (SELECT 1
                                       FROM gl_code_combinations gcc, fnd_flex_value_sets ffvs, fnd_flex_values ffv,
                                            fnd_flex_values_tl ffvt
                                      WHERE     gcc.code_combination_id =
                                                ail.default_dist_ccid
                                            AND ffvs.flex_value_set_id =
                                                ffv.flex_value_set_id
                                            AND ffv.flex_value = gcc.segment6
                                            AND ffv.flex_value_id =
                                                ffvt.flex_value_id
                                            AND ffvt.LANGUAGE =
                                                USERENV ('LANG')
                                            AND flex_value_set_name =
                                                'XXD_FREIGHT_ALLOCATE_GL_VALUES'
                                            AND TRUNC (ffv.start_date_active) <=
                                                TRUNC (SYSDATE)
                                            AND TRUNC (
                                                    NVL (ffv.end_date_active,
                                                         TRUNC (SYSDATE))) >=
                                                TRUNC (SYSDATE)
                                            AND ffv.enabled_flag = 'Y')))
            UNION
            SELECT line_number to_invoice_line_number, 'N' allocation_flag, 0 allocation_amount
              FROM ap_invoice_lines_all ail
             WHERE     invoice_id = p_invoice_id
                   AND ail.line_type_lookup_code = 'ITEM'
                   AND (   product_type = 'SERVICES'
                        OR (    ail.product_type IS NULL
                            AND NOT EXISTS
                                    (SELECT 1
                                       FROM gl_code_combinations gcc, fnd_flex_value_sets ffvs, fnd_flex_values ffv,
                                            fnd_flex_values_tl ffvt
                                      WHERE     gcc.code_combination_id =
                                                ail.default_dist_ccid
                                            AND ffvs.flex_value_set_id =
                                                ffv.flex_value_set_id
                                            AND ffv.flex_value = gcc.segment6
                                            AND ffv.flex_value_id =
                                                ffvt.flex_value_id
                                            AND ffvt.LANGUAGE =
                                                USERENV ('LANG')
                                            AND flex_value_set_name =
                                                'XXD_FREIGHT_ALLOCATE_GL_VALUES'
                                            AND TRUNC (ffv.start_date_active) <=
                                                TRUNC (SYSDATE)
                                            AND TRUNC (
                                                    NVL (ffv.end_date_active,
                                                         TRUNC (SYSDATE))) >=
                                                TRUNC (SYSDATE)
                                            AND ffv.enabled_flag = 'Y')));

        lv_error_msg             VARCHAR2 (2000);
        --lv_rule_status           VARCHAR2 (50);
        ln_cal_frt_total         NUMBER;
        ln_adj_to_inv_line_num   NUMBER;
        ln_adj_amount            NUMBER;
        ln_actual_alloc_amt      NUMBER;
        ln_alloc_amt             NUMBER;
        ln_count                 NUMBER := 0;
    BEGIN
        BEGIN
            SELECT SUM (allocation_amount)
              INTO ln_cal_frt_total
              FROM (SELECT ap_utilities_pkg.ap_round_currency (pn_frt_amount * ratio_to_report (amount) OVER (PARTITION BY 1), pv_currency_code) allocation_amount
                      FROM ap_invoice_lines_all ail
                     WHERE     invoice_id = p_invoice_id
                           AND ail.line_type_lookup_code = 'ITEM'
                           AND (   ail.product_type = 'GOODS'
                                OR (    ail.product_type IS NULL
                                    AND EXISTS
                                            (SELECT 1
                                               FROM gl_code_combinations gcc, fnd_flex_value_sets ffvs, fnd_flex_values ffv,
                                                    fnd_flex_values_tl ffvt
                                              WHERE     gcc.code_combination_id =
                                                        ail.default_dist_ccid
                                                    AND ffvs.flex_value_set_id =
                                                        ffv.flex_value_set_id
                                                    AND ffv.flex_value =
                                                        gcc.segment6
                                                    AND ffv.flex_value_id =
                                                        ffvt.flex_value_id
                                                    AND ffvt.LANGUAGE =
                                                        USERENV ('LANG')
                                                    AND flex_value_set_name =
                                                        'XXD_FREIGHT_ALLOCATE_GL_VALUES'
                                                    AND TRUNC (
                                                            ffv.start_date_active) <=
                                                        TRUNC (SYSDATE)
                                                    AND TRUNC (
                                                            NVL (
                                                                ffv.end_date_active,
                                                                TRUNC (
                                                                    SYSDATE))) >=
                                                        TRUNC (SYSDATE)
                                                    AND ffv.enabled_flag =
                                                        'Y'))));
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_error_msg   := SQLERRM;
        END;

        IF ln_cal_frt_total <> pn_frt_amount
        THEN
            SELECT MAX (arl.to_invoice_line_number)
              INTO ln_adj_to_inv_line_num
              FROM ap_allocation_rule_lines arl
             WHERE     arl.invoice_id = p_invoice_id
                   AND arl.chrg_invoice_line_number = pn_inv_charge_line_num
                   AND arl.amount <> 0;

            ln_adj_amount   := pn_frt_amount - ln_cal_frt_total;
        ELSE
            ln_adj_amount   := 0;
        END IF;

        FOR i IN get_lines_c
        LOOP
            BEGIN
                SELECT amount
                  INTO ln_alloc_amt
                  FROM ap_allocation_rule_lines
                 WHERE     invoice_id = p_invoice_id
                       AND chrg_invoice_line_number = pn_inv_charge_line_num
                       AND to_invoice_line_number = i.to_invoice_line_number;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_alloc_amt   := 0;
            END;

            IF     ln_adj_amount <> 0
               AND i.to_invoice_line_number = ln_adj_to_inv_line_num
            THEN
                ln_actual_alloc_amt   := i.allocation_amount + ln_adj_amount;
            ELSE
                ln_actual_alloc_amt   := i.allocation_amount;
            END IF;

            IF ln_alloc_amt <> ln_actual_alloc_amt
            THEN
                ln_count   := ln_count + 1;
            END IF;
        END LOOP;

        IF ln_count > 0
        THEN
            pv_alloc_diff   := 'Y';
        ELSE
            pv_alloc_diff   := 'N';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_msg   := SQLERRM;
    END check_amt_alloc;

    --This is the main procedure called by AP_CUSTOM_INV_VALIDATION_PKG
    PROCEDURE main (p_invoice_id   IN     ap_invoices_all.invoice_id%TYPE,
                    pv_error_msg      OUT VARCHAR2)
    IS
        lv_rule_type            VARCHAR2 (100);
        ln_frt_line_num         NUMBER;
        ln_non_trade_flag       VARCHAR2 (2);
        ln_frt_amt              NUMBER;
        lv_alloc_amt            NUMBER;
        ln_org_id               NUMBER;
        ln_trade_vendor_count   NUMBER;
        ln_count                NUMBER := 0;
        lv_frt_manuall_flag     VARCHAR2 (2) := 'N';
        lv_error_msg            VARCHAR2 (2000);
        lv_currency_code        VARCHAR2 (50);
        lv_rule_status          VARCHAR2 (50);
        lv_alloc_diff           VARCHAR2 (2);
    BEGIN
        -- Check If Invoice is for Trade Vendor
        SELECT COUNT (1)
          INTO ln_trade_vendor_count
          FROM ap_invoices_all aia, po_vendors pv
         WHERE     aia.invoice_id = p_invoice_id
               AND pv.vendor_id = aia.vendor_id
               AND pv.vendor_type_lookup_code = 'MANUFACTURER'
               AND DECODE (
                       NVL (pv.receipt_required_flag, 'N'),
                       'Y', DECODE (NVL (pv.inspection_required_flag, 'N'),
                                    'Y', '4-Way',
                                    '3-Way'),
                       '2-Way') =
                   '2-Way';

        IF ln_trade_vendor_count > 0
        THEN
            ln_non_trade_flag   := 'N';
        ELSE
            ln_non_trade_flag   := 'Y';
        END IF;

        --Check if the invoice has frieght line
        BEGIN
            SELECT line_number, amount, ail.org_id,
                   aia.invoice_currency_code
              INTO ln_frt_line_num, ln_frt_amt, ln_org_id, lv_currency_code
              FROM ap_invoice_lines_all ail, ap_invoices_all aia
             WHERE     ail.invoice_id = p_invoice_id
                   AND ail.line_type_lookup_code = 'FREIGHT'
                   AND ail.amount > 0
                   AND ail.invoice_id = aia.invoice_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_frt_line_num   := NULL;
                ln_frt_amt        := NULL;
        END;

        --    If Non trade invoice and there is a freight line proceed
        IF ln_non_trade_flag = 'Y' AND ln_frt_line_num IS NOT NULL
        THEN
            --Get attribute12 from ap_invoices_all to check if freight allocation is manuall  or automatic
            BEGIN
                SELECT attribute12
                  INTO lv_frt_manuall_flag
                  FROM ap_invoices_all
                 WHERE invoice_id = p_invoice_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_frt_manuall_flag   := '';
            END;

            --If attribute12 is null or 'N' freight allocation has to be done else its is manually done
            IF NVL (lv_frt_manuall_flag, 'N') = 'N'
            THEN
                --Setting Environment
                mo_global.init ('SQLAP');
                mo_global.set_policy_context ('S', ln_org_id);
                fnd_request.set_org_id (ln_org_id);

                --Get the rule type and status
                BEGIN
                    SELECT aar.rule_type, aar.status
                      INTO lv_rule_type, lv_rule_status
                      FROM ap_allocation_rules aar, ap_invoice_lines_all aila
                     WHERE     aar.invoice_id = aila.invoice_id
                           AND aar.chrg_invoice_line_number =
                               aila.line_number
                           AND aila.line_type_lookup_code = 'FREIGHT'
                           AND aila.amount > 0
                           AND aila.invoice_id = p_invoice_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_rule_type   := NULL;
                END;

                --If the rule type is null create proration rule and then update the rule to amount and also update rule lines
                IF lv_rule_type IS NULL
                THEN
                    --Call create_allocation procedute to create proration rule
                    create_allocation (p_invoice_id,
                                       ln_frt_line_num,
                                       lv_error_msg);

                    IF lv_error_msg IS NOT NULL
                    THEN
                        pv_error_msg   := pv_error_msg || ' ' || lv_error_msg;
                        lv_error_msg   := NULL;
                    END IF;

                    --Call update_allocation_rule procedute to update rule to Amount
                    update_allocation_rule (p_invoice_id, lv_error_msg);

                    IF lv_error_msg IS NOT NULL
                    THEN
                        pv_error_msg   := pv_error_msg || ' ' || lv_error_msg;
                        lv_error_msg   := NULL;
                    END IF;

                    --Call update_allocation_rule_line to update allocation rule lines
                    update_allocation_rule_line (p_invoice_id, lv_error_msg);

                    IF lv_error_msg IS NOT NULL
                    THEN
                        pv_error_msg   := pv_error_msg || ' ' || lv_error_msg;
                        lv_error_msg   := NULL;
                    END IF;
                END IF;

                --If the rule type is not null and not equal to amount update rule to amount and also update rule lines
                IF lv_rule_type <> 'AMOUNT'
                THEN
                    --Call update_allocation_rule procedure to update rule to Amounnt
                    update_allocation_rule (p_invoice_id, lv_error_msg);

                    IF lv_error_msg IS NOT NULL
                    THEN
                        pv_error_msg   := pv_error_msg || ' ' || lv_error_msg;
                        lv_error_msg   := NULL;
                    END IF;

                    --Call update_allocation_rule_line procedute to update allocation rule lines
                    update_allocation_rule_line (p_invoice_id, lv_error_msg);

                    IF lv_error_msg IS NOT NULL
                    THEN
                        pv_error_msg   := pv_error_msg || ' ' || lv_error_msg;
                        lv_error_msg   := NULL;
                    END IF;
                END IF;

                --If the rule type is amount check if the rule lines have expected allocation if not update rule lines
                IF lv_rule_type = 'AMOUNT'  --AND lv_rule_status <> 'EXECUTED'
                THEN
                    --Call check_amt_alloc to check if allocated amount is correct or not
                    check_amt_alloc (p_invoice_id,
                                     ln_frt_line_num,
                                     lv_currency_code,
                                     ln_frt_amt,
                                     lv_alloc_diff,
                                     lv_error_msg);

                    IF lv_alloc_diff = 'Y'
                    THEN
                        IF lv_rule_status = 'EXECUTED'
                        THEN
                            --Call update_allocation_rule procedure to update rule status to pending
                            update_allocation_rule (p_invoice_id,
                                                    lv_error_msg);

                            IF lv_error_msg IS NOT NULL
                            THEN
                                pv_error_msg   :=
                                    pv_error_msg || ' ' || lv_error_msg;
                                lv_error_msg   := NULL;
                            END IF;
                        END IF;

                        --Call update_allocation_rule_line procedure to update allocation rule lines
                        update_allocation_rule_line (p_invoice_id,
                                                     lv_error_msg);

                        IF lv_error_msg IS NOT NULL
                        THEN
                            pv_error_msg   :=
                                pv_error_msg || ' ' || lv_error_msg;
                            lv_error_msg   := NULL;
                        END IF;
                    END IF;
                END IF;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_msg   := pv_error_msg || ' ' || SQLERRM;
    END main;
END xxd_ap_invoice_allocation_pkg;
/
