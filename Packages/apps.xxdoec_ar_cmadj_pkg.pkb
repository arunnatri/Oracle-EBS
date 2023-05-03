--
-- XXDOEC_AR_CMADJ_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:08 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOEC_AR_CMADJ_PKG"
AS
    /******************************************************************************************************
    * Program Name : XXDOEC_AR_RECEIPT_PKG
    * Description  :
    *
    * History      :
    *
    * ===============================================================================
    * Who                   Version    Comments                          When
    * ===============================================================================
    * BT Technology Team    1.1        Updated for BT                         05-JAN-2015
    * BT Technology Team    1.2        INFOSYS                                CCR0004339 - EBS changes for?eCommerce?Loyalty program.
    * Srinath Siricilla     1.3        Sunera Technologies                    CCR0005991 - Japan DW PhaseII
    * Madhav Dhurjaty       1.4        Changes for CCR0007547                 03-OCT-2018
    ******************************************************************************************************/

    PROCEDURE msg (MESSAGE VARCHAR2, debug_level NUMBER:= 100, p_runnum NUMBER:= -1
                   , p_header_id NUMBER:= -1, p_category VARCHAR2:= 'I')
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, MESSAGE);

        INSERT INTO xxdo.xxdoec_process_order_log
                 VALUES (xxdo.xxdoec_seq_process_order.NEXTVAL,
                         MESSAGE,
                         CURRENT_TIMESTAMP);

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END msg;

    PROCEDURE get_receipt_method (p_receipt_class_id IN NUMBER, p_do_pmt_type IN VARCHAR2, p_website_id IN VARCHAR2, p_currency_code IN VARCHAR2, x_receipt_method_id OUT NUMBER, x_bank_account_id OUT NUMBER
                                  , x_bank_branch_id OUT NUMBER)
    IS
        CURSOR c_receipt_method (c_receipt_class_id IN NUMBER, c_do_pmt_type IN VARCHAR2, c_website_id IN VARCHAR2
                                 , c_currency_code IN VARCHAR2)
        IS
            SELECT arm.receipt_method_id, bau.bank_account_id, cba.bank_branch_id
              FROM ar_receipt_methods arm, ar_receipt_method_accounts_all arma, ce_bank_acct_uses_all bau,
                   ce_bank_accounts cba
             WHERE     arm.receipt_class_id = c_receipt_class_id
                   AND arm.attribute2 = c_do_pmt_type
                   AND NVL (arm.attribute4, 'N') = 'N'
                   AND NVL (arm.attribute1, c_website_id) = c_website_id
                   AND SYSDATE BETWEEN NVL (arm.start_date, SYSDATE)
                                   AND NVL (arm.end_date, SYSDATE)
                   AND arma.receipt_method_id = arm.receipt_method_id
                   AND bau.bank_acct_use_id = arma.remit_bank_acct_use_id
                   AND cba.bank_account_id = bau.bank_account_id
                   AND NVL (cba.currency_code, c_currency_code) =
                       c_currency_code
                   AND cba.account_classification = 'INTERNAL';
    BEGIN
        OPEN c_receipt_method (p_receipt_class_id, p_do_pmt_type, p_website_id
                               , p_currency_code);

        FETCH c_receipt_method INTO x_receipt_method_id, x_bank_account_id, x_bank_branch_id;

        IF c_receipt_method%NOTFOUND
        THEN
            CLOSE c_receipt_method;

            x_receipt_method_id   := NULL;
            x_bank_account_id     := NULL;
            x_bank_branch_id      := NULL;
        ELSE
            CLOSE c_receipt_method;
        END IF;
    END get_receipt_method;

    /*FUNCTION check_COD_Order (p_header_id IN NUMBER)
    RETURN BOOLEAN
    IS
    lv_order_method  VARCHAR2(100);
    BEGIN
       NULL;
       SELECT 'COD'
         INTO  lv_order_method
         FROM  apps.oe_order_lines ool
        WHERE  ool.header_id = p_header_id
          AND  EXISTS (SELECT  1
                         FROM  apps.oe_price_adjustments opa
                        WHERE  list_line_type_code = 'FREIGHT_CHARGE'
                          AND  charge_type_code= 'CODCHARGE'
                          AND  opa.line_id = ool.line_id);
       RETURN TRUE;
    EXCEPTION
    WHEN OTHERS
    THEN
       NULL;
       RETURN FALSE;
    END;*/
    /*--Added for CCR0007547 --Start*/
    FUNCTION check_exchange_type (p_order_type IN VARCHAR2)
        RETURN BOOLEAN
    IS
        ln_count   NUMBER;
    BEGIN
        SELECT COUNT (1)                  --v.flex_value "Exchange Order Type"
          INTO ln_count
          FROM apps.fnd_flex_value_sets s, apps.fnd_flex_values_vl v
         WHERE     1 = 1
               AND s.flex_value_set_id = v.flex_value_set_id
               AND s.flex_value_set_name = 'XXDO_ORDER_TYPE_PURPOSE'
               AND v.enabled_flag = 'Y'
               AND NVL (v.attribute2, 'N') = 'Y'
               AND v.flex_value = p_order_type;

        IF ln_count > 0
        THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN FALSE;
    END check_exchange_type;

    FUNCTION check_payment_type (p_receipt_type IN VARCHAR2)
        RETURN BOOLEAN
    IS
        ln_count   NUMBER;
    BEGIN
        SELECT COUNT (1)                         --v.flex_value "Receipt Type"
          INTO ln_count
          FROM apps.fnd_flex_value_sets s, apps.fnd_flex_values_vl v
         WHERE     1 = 1
               AND s.flex_value_set_id = v.flex_value_set_id
               AND s.flex_value_set_name = 'XXDO_ECOMM_RECPT_TYPE'
               AND v.enabled_flag = 'Y'
               AND NVL (v.attribute2, 'N') = 'Y'
               AND v.flex_value = p_receipt_type;

        IF ln_count > 0
        THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN FALSE;
    END check_payment_type;

    /*--Added for CCR0007547 --End*/

    FUNCTION get_activity_name (p_rct_method        IN VARCHAR2,
                                p_ret_reason_code   IN VARCHAR2) -- Added as a part of CCR0005991 Changes
        RETURN VARCHAR2
    IS
        l_Rece_act_name   VARCHAR2 (100);
    BEGIN
        SELECT NAME
          INTO l_rece_act_name
          FROM ar_receivables_trx
         WHERE     attribute4 = TO_CHAR (p_rct_method)
               AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                               AND NVL (end_date_active, SYSDATE);

        RETURN l_rece_act_name;
    EXCEPTION
        -- Start of CCR0005991 Changes
        WHEN TOO_MANY_ROWS
        THEN
            BEGIN
                SELECT art.name
                  INTO l_rece_act_name
                  FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffv, apps.fnd_lookup_values flv,
                       apps.ar_receivables_trx art
                 WHERE     ffvs.flex_value_set_name = 'XXDO_COD_REJECTION'
                       AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                       AND flv.lookup_type = 'CREDIT_MEMO_REASON'
                       AND flv.meaning = ffv.flex_value
                       AND flv.language = 'US'
                       AND ffv.description = art.name
                       AND flv.lookup_code = p_ret_reason_code;

                RETURN l_rece_act_name;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_rece_act_name   := 'JP COD Refund Adjust - JPY';
                    RETURN l_rece_act_name;
                WHEN OTHERS
                THEN
                    l_rece_act_name   := NULL;
                    RETURN l_rece_act_name;
            END;
        -- End of CCR0005991 Changes
        WHEN OTHERS
        THEN
            l_rece_act_name   := NULL;
            RETURN l_rece_act_name;
    END get_activity_name;

    -- Start of CCR0005991 Changes

    FUNCTION get_order_line_total (p_header_id IN NUMBER, p_line_group_id IN NUMBER, p_customer_trx_id IN NUMBER)
        RETURN NUMBER
    IS
        l_Total   NUMBER := 0;

        CURSOR C1 (p_header_id         NUMBER,
                   p_line_group_id     NUMBER,
                   p_customer_trx_id   NUMBER)
        IS
              /*SELECT
                SUM(NVL(Ordered_Quantity,0)* NVL(unit_selling_price,0))
                Line_details_total,
                Line_Category_Code
              FROM
                oe_order_lines
              WHERE
                1                         =1
              AND header_id               =p_header_id
              AND attribute18             = TO_CHAR(p_line_group_id)
              AND NVL(cancelled_flag,'N') ='N'
              GROUP BY
                line_category_code;*/
              SELECT SUM (NVL (ool.Ordered_Quantity, 0) * NVL (ool.unit_selling_price, 0) + NVL (ool.tax_value, 0)) /*+ SUM (
                                                                                                                                 NVL (
                                                                                                                                    DECODE (zxr.inclusive_tax_flag,
                                                                                                                                            'Y', 0,
                                                                                                                                            opa_tax.adjusted_amount),
                                                                                                                                    0))*/
                                                                                                                    Line_details_total, ool.Line_Category_Code
                FROM apps.oe_order_lines ool
               WHERE     1 = 1
                     AND ool.header_id = p_header_id
                     AND ool.attribute18 = TO_CHAR (p_line_group_id)
                     AND NVL (ool.cancelled_flag, 'N') = 'N'
                     AND EXISTS
                             (SELECT 1
                                FROM apps.ra_customer_trx_lines rctl
                               WHERE     1 = 1
                                     AND rctl.customer_trx_id =
                                         p_customer_trx_id
                                     AND rctl.interface_line_context(+) =
                                         'ORDER ENTRY'
                                     AND rctl.interface_line_attribute6(+) =
                                         TO_CHAR (ool.line_id))
            GROUP BY ool.line_category_code;
    BEGIN
        FOR Lines IN C1 (p_header_id, p_line_group_id, p_customer_trx_id)
        LOOP
            IF lines.line_category_code <> 'RETURN'
            THEN
                l_Total   := l_Total + lines.line_details_total;
            ELSIF lines.line_category_code = 'RETURN'
            THEN
                l_total   := l_total - lines.line_details_total;
            END IF;
        END LOOP;

        RETURN (l_total);
    EXCEPTION
        WHEN OTHERS
        THEN
            l_total   := 0;
            fnd_file.put_line (fnd_file.LOG,
                               'No Data Rows : ' || SUBSTR (SQLERRM, 1, 200));
            RETURN (l_total);
    END get_order_line_total;

    FUNCTION get_trx_line_total (p_header_id IN NUMBER, p_line_group_id IN NUMBER, p_customer_trx_id IN NUMBER)
        RETURN NUMBER
    IS
        p_inv_total   NUMBER := 0;
    BEGIN
        SELECT SUM (rctl.extended_amount + NVL (rctl_tax.extended_amount, 0))
          INTO p_inv_total
          FROM ra_customer_trx_lines rctl, ra_customer_trx_lines rctl_tax, oe_order_lines ool
         WHERE     1 = 1
               AND rctl.interface_line_context(+) = 'ORDER ENTRY'
               AND rctl_tax.line_type(+) = 'TAX'
               AND rctl_tax.customer_trx_id(+) = rctl.customer_trx_id
               AND rctl_tax.link_to_cust_trx_line_id(+) =
                   rctl.customer_trx_line_id
               AND rctl.interface_line_attribute6(+) = TO_CHAR (ool.line_id)
               AND ool.attribute18 = p_line_group_id
               AND ool.header_id = p_header_id
               AND rctl.customer_trx_id = p_customer_trx_id;

        RETURN p_inv_total;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_inv_total   := 0;
            RETURN p_inv_total;
    END get_trx_line_total;

    /*FUNCTION calc_order_total(p_header_id IN NUMBER)
    RETURN NUMBER
    IS
    p_subtotal NUMBER  := 0;
    p_discount NUMBER  := 0;
    p_charges  NUMBER  := 0;
    p_tax      NUMBER  := 0;
    p_total    NUMBER  := 0;
    BEGIN
       apps.oe_oe_totals_summary.order_totals (p_header_id,
                                                p_subtotal,
                                                p_discount,
                                                p_charges,
                                                p_tax);
       --p_total := NVL(p_subtotal,0)+NVL(p_discount,0)+NVL(p_tax,0);
       p_total := NVL(p_subtotal,0)+NVL(p_tax,0);
       RETURN p_total;
    EXCEPTION
    WHEN OTHERS
    THEN
       p_total := 0;
       RETURN p_total;
    END calc_order_total;

    FUNCTION get_trx_total(p_header_id IN NUMBER)
    RETURN NUMBER
    IS
    p_inv_total NUMBER := 0;
    BEGIN
       SELECT  SUM (rctl.extended_amount + NVL (rctl_tax.extended_amount, 0))
         INTO  p_inv_total
         FROM  ra_customer_trx_lines rctl,
               ra_customer_trx_lines rctl_tax,
               oe_order_lines ool
        WHERE  1=1
          AND rctl.interface_line_context(+) = 'ORDER ENTRY'
          AND rctl_tax.line_type(+) = 'TAX'
          AND rctl_tax.customer_trx_id(+) = rctl.customer_trx_id
          AND rctl_tax.link_to_cust_trx_line_id(+) = rctl.customer_trx_line_id
          AND rctl.interface_line_attribute6(+) = TO_CHAR (ool.line_id)
          AND ool.header_id = p_header_id;
       RETURN p_inv_total;
    EXCEPTION
    WHEN OTHERS
    THEN
       p_inv_total := 0;
       RETURN p_inv_total;
    END get_trx_total;*/

    -- End of CCR0005991 Changes

    PROCEDURE create_cm_adjustment (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, p_header_id IN NUMBER)
    IS
        CURSOR c_order_lines IS
              SELECT ooh.order_number, ott.attribute13 exchange_order_type, ool.header_id,
                     ool.attribute18 line_grp_id, ool.attribute20 status_code, ool.attribute16 pgc_trans_num,
                     rctl.customer_trx_id, rct.trx_number, rta.NAME adj_activity_name,
                     rctt.NAME trx_type_name, SUM (ool.ordered_quantity * ool.unit_selling_price) + SUM (NVL (DECODE (zxr.inclusive_tax_flag, 'Y', 0, opa_tax.adjusted_amount), 0)) om_line_total, ABS (SUM (rctl.extended_amount + NVL (rctl_tax.extended_amount, 0))) cm_line_total,
                     ool.return_reason_code Ret_reason_code -- Added for Japan DW PhaseII
                FROM oe_order_lines ool, oe_order_headers ooh, oe_transaction_types ott,
                     oe_price_adjustments opa_tax, zx_rates_b zxr, ra_customer_trx_lines rctl,
                     ra_customer_trx_lines rctl_tax, ra_customer_trx rct, ra_cust_trx_types rctt,
                     ar_receivables_trx rta
               WHERE     ool.attribute20 = 'CHB'
                     AND ool.attribute19 = 'SUCCESS'
                     AND ool.attribute17 = 'S'
                     AND ool.line_category_code = 'RETURN'
                     AND ooh.header_id = ool.header_id
                     AND ott.transaction_type_id = ooh.order_type_id
                     AND opa_tax.line_id(+) = ool.line_id
                     AND opa_tax.list_line_type_code(+) = 'TAX'
                     AND zxr.tax_rate_id(+) = opa_tax.tax_rate_id
                     AND rctl.interface_line_context(+) = 'ORDER ENTRY'
                     AND rctl.line_type(+) = 'LINE'
                     AND rctl.interface_line_attribute6(+) =
                         TO_CHAR (ool.line_id)
                     AND rctl.org_id(+) = ool.org_id
                     AND rctl_tax.line_type(+) = 'TAX'
                     AND rctl_tax.customer_trx_id(+) = rctl.customer_trx_id
                     AND rctl_tax.link_to_cust_trx_line_id(+) =
                         rctl.customer_trx_line_id
                     AND rct.customer_trx_id(+) = rctl.customer_trx_id
                     AND rctt.cust_trx_type_id(+) = rct.cust_trx_type_id
                     AND rctt.org_id(+) = rct.org_id
                     AND rta.receivables_trx_id(+) =
                         TO_NUMBER (rctt.attribute2)
                     AND rta.org_id(+) = rctt.org_id
                     AND ool.header_id = NVL (p_header_id, ool.header_id)
            GROUP BY ooh.order_number, ott.attribute13, ool.header_id,
                     ool.attribute18, ool.attribute20, ool.attribute16,
                     ool.return_reason_code,     -- Added for Japan DW PhaseII
                                             rctl.customer_trx_id, rct.trx_number,
                     rta.NAME, rctt.NAME;

        CURSOR c_order_payments (c_header_id     IN NUMBER,
                                 c_line_grp_id   IN VARCHAR2)
        IS
            SELECT payment_id,
                   payment_trx_id,
                   payment_type,
                   NVL (unapplied_amount, payment_amount) payment_amount,
                   payment_date,
                   pg_reference_num,
                   (SELECT DECODE (SIGN (pt.product_selling_price_total + ftt.freight_charge_total + ftt.freight_discount_total + ftt.gift_wrap_total + ftt.tax_total_no_vat),  -1, 'CHB',  1, 'PGC',  'NOP')
                      FROM xxdoec_oe_order_product_totals pt, xxdoec_oe_order_frt_tax_totals ftt
                     WHERE     pt.header_id = c_header_id
                           AND pt.attribute18 = c_line_grp_id
                           AND ftt.header_id = c_header_id
                           AND ftt.attribute18 = c_line_grp_id) payment_action
              FROM xxdoec_order_payment_details
             WHERE     status = 'OP'
                   /*--Commented for CCR0007547 -- Start*/
                   --AND payment_type IN
                   --       ('CC', 'PP', 'GC', 'SC', 'AD', 'RM', 'RC','COD')     -- COD Added as Part of Japana DW PhaseII
                   /*--Commented for CCR0007547 -- End*/
                   /*--Added for CCR0007547 -- Start*/
                   AND payment_type IN
                           (SELECT v.flex_value "Create_CM_ADJ"
                              FROM apps.fnd_flex_value_sets s, apps.fnd_flex_values_vl v
                             WHERE     1 = 1
                                   AND s.flex_value_set_id =
                                       v.flex_value_set_id
                                   AND s.flex_value_set_name =
                                       'XXDO_ECOMM_RECPT_TYPE'
                                   AND v.enabled_flag = 'Y'
                                   AND NVL (v.attribute2, 'N') = 'Y')
                   /*--Added for CCR0007547 -- End*/
                   --Added this based on the UAT package change with comment-- ----added tansaction types RM and RC by showkath on 18-AUG-15> --W.r.t Version 1.2
                   AND header_id = c_header_id
                   AND line_group_id = c_line_grp_id;

        --
        CURSOR c_cb_params (c_order_header_id IN NUMBER)
        IS
            SELECT cbp.ar_batch_source_id, cbp.ar_bank_branch_id, cbp.ar_bank_account_id,
                   cbp.ar_batch_type, cbp.ar_receipt_class_id, cbp.ar_receipt_method_id,
                   ooh.transactional_curr_code, hca.account_number customer_number, hou.NAME company_name,
                   cbp.website_id, ooh.order_number
              FROM xxdoec_country_brand_params cbp, oe_order_headers_all ooh, hz_cust_accounts hca,
                   hr_operating_units hou
             WHERE     ooh.header_id = c_order_header_id
                   AND hca.cust_account_id = ooh.sold_to_org_id
                   AND hou.organization_id = ooh.sold_from_org_id
                   AND cbp.website_id = hca.attribute18;

        --
        CURSOR c_order_invoice (c_order_number IN NUMBER)
        IS
              SELECT rct.customer_trx_id, rct.bill_to_customer_id, rct.bill_to_site_use_id,
                     SUM (aps.amount_due_remaining) inv_balance
                FROM ra_customer_trx rct, ra_cust_trx_types rctt, ar_payment_schedules aps
               WHERE     rct.interface_header_context = 'ORDER ENTRY'
                     AND rct.interface_header_attribute1 =
                         TO_CHAR (c_order_number)
                     AND rctt.cust_trx_type_id = rct.cust_trx_type_id
                     AND rctt.TYPE = 'INV'
                     AND aps.customer_trx_id = rct.customer_trx_id
            GROUP BY rct.customer_trx_id, rct.bill_to_customer_id, rct.bill_to_site_use_id
              HAVING SUM (aps.amount_due_remaining) > 0;

        CURSOR c_cm_balance (c_cm_trx_id IN NUMBER)
        IS
            SELECT ABS (SUM (aps.amount_due_remaining)) cm_balance, ABS (SUM (aps.amount_line_items_remaining)) cm_line_balance, ABS (SUM (aps.tax_remaining)) cm_tax_balance
              FROM ar_payment_schedules aps
             WHERE customer_trx_id = c_cm_trx_id;

        CURSOR c_adj_activity (c_receipt_method_id IN NUMBER)
        IS
            SELECT NAME
              FROM ar_receivables_trx
             WHERE     attribute4 = TO_CHAR (c_receipt_method_id)
                   AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                                   AND NVL (end_date_active, SYSDATE);

        l_cm_balance          NUMBER;
        l_cm_line_balance     NUMBER;
        l_cm_tax_balance      NUMBER;
        -- Added for CCR0005991 Change
        l_om_line_total       NUMBER;
        l_cm_line_total       NUMBER;
        -- End of CCR0005991 Change
        l_apply_amt           NUMBER;
        l_adj_amt             NUMBER;
        l_adj_activity        VARCHAR2 (120) := NULL; --Added this based on the UAT package change with comment---- Initialized the variable by showkath. --W.r.t Version 1.2
        l_adj_type            VARCHAR2 (40);
        l_rec_appl_id         NUMBER;
        l_adj_id              NUMBER;
        l_adj_number          NUMBER;
        l_err_msg             VARCHAR2 (2000);
        l_pmt_status          VARCHAR2 (1);
        l_adj_status          VARCHAR2 (1);
        l_app_status          VARCHAR2 (1);
        ex_mis_adj_name       EXCEPTION;
        l_payment_amount      NUMBER := 0;
        --
        cb_params_rec         c_cb_params%ROWTYPE;
        l_receipt_method_id   NUMBER;
        l_bank_account_id     NUMBER;
        l_bank_branch_id      NUMBER;

        --Added this based on the UAT package change with comment----- Added by showkath to fix the partial adjustment issue --W.r.t Version 1.2

        -- private procedure
        PROCEDURE msg (MESSAGE VARCHAR2, debug_level NUMBER:= 100)
        IS
        BEGIN
            fnd_file.put_line (fnd_file.LOG, MESSAGE);
            DBMS_OUTPUT.put_line (MESSAGE);
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END msg;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Start of the Program');

        FOR c_cma IN c_order_lines
        LOOP
            BEGIN
                -- Added for CCR0005991 Change
                l_om_line_total   := 0;
                l_cm_line_total   := 0;

                -- End of CCR0005991 Change

                -- Added for CCR0005991 Change
                /*BEGIN
                SELECT  xxdoec_ar_receipt_pkg.calc_order_total(c_cma.header_id)
                  INTO  l_om_line_total
                  FROM  dual;
                EXCEPTION
                WHEN OTHERS
                THEN
                  l_om_line_total := 0;
                END;

                BEGIN
                SELECT  xxdoec_ar_receipt_pkg.get_trx_total(c_cma.header_id)
                  INTO  l_cm_line_total
                  FROM  dual;
                EXCEPTION
                WHEN OTHERS
                THEN
                  l_cm_line_total := 0;
                END;*/

                BEGIN
                    SELECT xxdoec_ar_cmadj_pkg.get_order_line_total (c_cma.header_id, c_cma.line_grp_id, c_cma.customer_trx_id)
                      INTO l_om_line_total
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_om_line_total   := 0;
                END;

                BEGIN
                    SELECT xxdoec_ar_cmadj_pkg.get_trx_line_total (c_cma.header_id, c_cma.line_grp_id, c_cma.customer_trx_id)
                      INTO l_cm_line_total
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_cm_line_total   := 0;
                END;

                -- End of CCR0005991 Change

                msg (
                       ' Header ID: '
                    || c_cma.header_id
                    || ' New Invoice Line Total: '
                    || l_cm_line_total
                    || ' New Order Line Total: '
                    || l_om_line_total,
                    100);


                msg (
                       ' Header ID: '
                    || c_cma.header_id
                    || ' Lines Group ID: '
                    || c_cma.line_grp_id
                    || ' Credit Memo ID: '
                    || c_cma.customer_trx_id
                    || ' Exchange Order Type: '
                    || c_cma.exchange_order_type,
                    100);

                /*msg (
                      ' Order Lines Total: '
                   || c_cma.om_line_total
                   || ' CM Lines Total: '
                   || c_cma.cm_line_total,
                   100);*/

                --
                /*IF c_cma.om_line_total <> NVL (c_cma.cm_line_total, 0)
                THEN
                   msg (
                      'Some or All of the Return Order Lines are not invoiced yet...',
                      100);*/
                IF l_om_line_total <> NVL (l_cm_line_total, 0)
                THEN
                    msg (
                        'Some or All of the Return Order Lines are not invoiced yet...',
                        100);
                ELSE
                    l_adj_status   := fnd_api.g_ret_sts_success;

                    OPEN c_cm_balance (c_cma.customer_trx_id);

                    FETCH c_cm_balance INTO l_cm_balance, l_cm_line_balance, l_cm_tax_balance;

                    CLOSE c_cm_balance;

                    IF l_cm_balance > 0
                    THEN
                        /*--Commented for CCR0007547 --Start*/
                        --IF NVL (c_cma.exchange_order_type, '~') IN
                        --      ('EE', 'AE', 'RE', 'RR', 'PE')
                        /*--Commented for CCR0007547 --End*/
                        /*--Added for CCR0007547 --Start*/
                        IF check_exchange_type (
                               NVL (c_cma.exchange_order_type, '~'))
                        /*--Added for CCR0007547 --End*/
                        THEN
                            -- apply CM to invoice(s) of the same order
                            FOR c_inv IN c_order_invoice (c_cma.order_number)
                            LOOP
                                l_apply_amt   :=
                                    LEAST (l_cm_balance, c_inv.inv_balance);
                                do_ar_utils.apply_credit_memo_to_invoice (
                                    p_customer_id          =>
                                        c_inv.bill_to_customer_id,
                                    p_bill_to_site_id      =>
                                        c_inv.bill_to_site_use_id,
                                    p_cm_cust_trx_id       =>
                                        c_cma.customer_trx_id,
                                    p_inv_cust_trx_id      =>
                                        c_inv.customer_trx_id,
                                    p_amount_to_apply      => l_apply_amt,
                                    p_application_date     => TRUNC (SYSDATE),
                                    p_module               => NULL,
                                    p_module_version       => NULL,
                                    x_ret_stat             => l_app_status,
                                    x_rec_application_id   => l_rec_appl_id,
                                    x_error_msg            => l_err_msg);

                                IF l_err_msg IS NOT NULL
                                THEN
                                    msg (
                                           'Unable to apply CM to Invoice ID: '
                                        || c_cma.customer_trx_id,
                                        100);
                                    msg ('Error Message: ' || l_err_msg, 100);
                                    l_adj_status   := fnd_api.g_ret_sts_error;
                                ELSE
                                    msg (
                                           'Successfully applied CM to Invoice ID: '
                                        || c_cma.customer_trx_id,
                                        100);

                                    IF l_apply_amt = c_inv.inv_balance
                                    THEN
                                        UPDATE oe_order_lines_all ool
                                           SET ool.attribute20 = 'CM', ool.attribute19 = 'APPLIED', ool.attribute17 = fnd_api.g_ret_sts_success
                                         WHERE     ool.header_id =
                                                   c_cma.header_id
                                               AND ool.attribute18 =
                                                   c_cma.line_grp_id
                                               AND EXISTS
                                                       (SELECT 1
                                                          FROM ra_customer_trx_lines_all rctl
                                                         WHERE     rctl.customer_trx_id =
                                                                   c_inv.customer_trx_id
                                                               AND rctl.interface_line_context =
                                                                   'ORDER ENTRY'
                                                               AND rctl.interface_line_attribute6 =
                                                                   TO_CHAR (
                                                                       ool.line_id));
                                    END IF;

                                    l_cm_balance   :=
                                        l_cm_balance - l_apply_amt;

                                    IF l_cm_balance = 0
                                    THEN
                                        EXIT;
                                    END IF;
                                END IF;
                            END LOOP;                         -- Invoices loop
                        END IF;                   -- exchange order type check

                        -- Loop through Payment details
                        FOR c_opd
                            IN c_order_payments (c_cma.header_id,
                                                 c_cma.line_grp_id)
                        LOOP
                            /*Commented for CCR0007547 -- Start*/
                            --IF c_opd.payment_type IN
                            --      ('CC', 'PP', 'GC', 'SC', 'AD', 'RM', 'RC','COD')     -- COD Added as Part of Japana DW PhaseII
                            --Added this based on the UAT package change with comment---- added transaction types RM and RC by showkath on 18-AUG-15 --W.r.t Version 1.2
                            /*Commented for CCR0007547 -- End*/
                            /*Added for CCR0007547 -- End*/
                            IF     check_payment_type (c_opd.payment_type)
                               /*Added for CCR0007547 -- End*/
                               AND c_opd.payment_action = 'CHB'
                            THEN
                                msg (
                                       'Payment Type: '
                                    || c_opd.payment_type
                                    || ' Amount: '
                                    || c_opd.payment_amount,
                                    100);
                                l_pmt_status       := fnd_api.g_ret_sts_success;
                                l_err_msg          := NULL;
                                l_adj_amt          :=
                                    LEAST (c_opd.payment_amount,
                                           l_cm_balance);



                                l_adj_activity     := NULL; --Added this based on the UAT package change with comment---- Initialized the variable by showkath. --W.r.t Version 1.2

                                -- derive adjustment activity based on Receipt Method ID

                                cb_params_rec      := NULL;

                                -- create Receipt Batch
                                OPEN c_cb_params (c_cma.header_id);

                                FETCH c_cb_params INTO cb_params_rec;

                                CLOSE c_cb_params;

                                --
                                get_receipt_method (cb_params_rec.ar_receipt_class_id, c_opd.payment_type, cb_params_rec.website_id, cb_params_rec.transactional_curr_code, l_receipt_method_id, l_bank_account_id
                                                    , l_bank_branch_id);

                                BEGIN
                                    SELECT XXDOEC_AR_CMADJ_PKG.get_activity_name (l_receipt_method_id, c_cma.Ret_reason_code)
                                      INTO l_adj_activity
                                      FROM DUAL;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        l_adj_activity   := NULL;
                                END;

                                /*OPEN c_adj_activity (l_receipt_method_id);

                                FETCH c_adj_activity INTO l_adj_activity;

                                CLOSE c_adj_activity;*/

                                l_adj_activity     :=
                                    NVL (l_adj_activity,
                                         c_cma.adj_activity_name);

                                --
                                IF l_adj_activity IS NULL
                                THEN
                                    msg (
                                           'Adjustment Activity Name Setup for Payment Type '
                                        || c_opd.payment_type
                                        || ' is missing - Unable to create Adjustment',
                                        100);
                                    RAISE ex_mis_adj_name;
                                END IF;

                                --Added this based on the UAT package change with comment--
                                --
                                l_payment_amount   := 0;
                                -- Added by showkath to fix the partial adjustment bug --W.r.t Version 1.2
                                l_payment_amount   := c_opd.payment_amount;

                                -- Added by showkath to fix the partial adjustment bug --W.r.t Version 1.2

                                WHILE (l_payment_amount > 0)
                                LOOP
                                    -- Added by showkath to fix the partial adjustment bug
                                    --IF l_cm_balance = c_opd.payment_amount -- commented by showkath to fix partial adj issue --W.r.t Version 1.2
                                    IF l_cm_balance = l_payment_amount -- added by showkath to fix partial adj issue --W.r.t Version 1.2
                                    THEN
                                        l_adj_type   := 'INVOICE';
                                        l_adj_amt    :=
                                            --LEAST (l_cm_balance, c_opd.payment_amount);-- commented by showkath to fix partial adj issue --W.r.t Version 1.2
                                             LEAST (l_cm_balance,
                                                    l_payment_amount); -- added by showkath to fix partial adj issue  --W.r.t Version 1.2
                                    ELSIF l_cm_tax_balance > 0
                                    THEN
                                        l_adj_type   := 'TAX';
                                        l_adj_amt    :=
                                            LEAST (l_cm_tax_balance, --c_opd.payment_amount -- commented by showkath to fix partial adj issue --W.r.t Version 1.2
                                                   l_payment_amount -- added by showkath to fix partial adj issue --W.r.t Version 1.2
                                                                   );
                                    --Added this based on the UAT package change with comment--
                                    ELSIF l_cm_line_balance > 0
                                    THEN
                                        l_adj_type   := 'LINE';
                                        l_adj_amt    :=
                                            LEAST (l_cm_line_balance, --c_opd.payment_amount --Added this based on the UAT package change with comment---- commented by showkath to fix partial adj issue --W.r.t Version 1.2
                                                   l_payment_amount --Added this based on the UAT package change with comment---- added by showkath to fix partial adj issue --W.r.t Version 1.2
                                                                   );
                                    END IF;

                                    -- Create Adjustment
                                    do_ar_utils.create_adjustment_trans (
                                        p_customer_trx_id   =>
                                            c_cma.customer_trx_id,
                                        p_activity_name   => l_adj_activity,
                                        p_type            => l_adj_type,
                                        p_amount          => l_adj_amt,
                                        p_reason_code     => 'CB-CRME',
                                        p_gl_date         =>
                                            c_opd.payment_date,
                                        p_adj_date        =>
                                            c_opd.payment_date,
                                        p_comments        =>
                                               'Credit Memo# '
                                            || c_cma.trx_number
                                            || ' Refund. PG Ref: '
                                            || c_opd.pg_reference_num,
                                        p_auto_commit     => 'N',
                                        x_adj_id          => l_adj_id,
                                        x_adj_number      => l_adj_number,
                                        x_error_msg       => l_err_msg);

                                    IF l_err_msg IS NOT NULL
                                    THEN
                                        msg (
                                               'Unable to create Adjustment for Credit Memo #: '
                                            || c_cma.trx_number,
                                            100);
                                        msg ('Error Message: ' || l_err_msg,
                                             100);
                                        l_pmt_status   :=
                                            fnd_api.g_ret_sts_error;
                                        EXIT;
                                    ELSE
                                        l_cm_balance   :=
                                            l_cm_balance - l_adj_amt;

                                        IF l_adj_type = 'TAX'
                                        THEN
                                            l_cm_tax_balance   :=
                                                l_cm_tax_balance - l_adj_amt;
                                        ELSIF l_adj_type = 'LINE'
                                        THEN
                                            l_cm_line_balance   :=
                                                l_cm_line_balance - l_adj_amt;
                                        END IF;

                                        msg (
                                               'Successfully created Adjustment#: '
                                            || l_adj_number
                                            || ' for Credit Memo #: '
                                            || c_cma.trx_number,
                                            100);
                                    END IF;              -- adjustment success

                                    --
                                    IF l_pmt_status =
                                       fnd_api.g_ret_sts_success
                                    THEN
                                        UPDATE xxdoec_order_payment_details
                                           --Added this based on the UAT package change with comment----- Modified by showkath to fix the partial adjustment bug --W.r.t Version 1.2
                                           SET unapplied_amount = --c_opd.payment_amount - l_adj_amt, -- commented by showkath to fix partial adj issue --W.r.t Version 1.2
                                                                  l_payment_amount - l_adj_amt, -- added by showkath to fix partial payment issue --W.r.t Version 1.2
                                                                                                status = DECODE (SIGN ( --c_opd.payment_amount -- commented by showkath to fix partial adj issue --W.r.t Version 1.2
                                                                                                                       l_payment_amount -- added by showkath to fix partial payment issue --W.r.t Version 1.2
                                                                                                                                        - l_adj_amt), 0, 'CL', 'OP')
                                         WHERE payment_id = c_opd.payment_id;

                                        l_payment_amount   :=
                                            l_payment_amount - l_adj_amt; -- added by showkath to fix partial payment issue --W.r.t Version 1.2
                                    ELSE
                                        l_adj_status   :=
                                            fnd_api.g_ret_sts_error;
                                    END IF;

                                    --
                                    IF (l_cm_balance = 0 OR l_payment_amount = 0)
                                    -- added by showkath to fix the partial adjustment bug --W.r.t Version 1.2
                                    THEN
                                        EXIT;
                                    END IF;
                                --
                                END LOOP;
                            --Added this based on the UAT package change with comment---- Modified by showkath to fix the partial adjustment bug --W.r.t Version 1.2

                            END IF;              -- payment type, Action check

                            IF l_cm_balance = 0
                            THEN
                                EXIT;
                            END IF;
                        END LOOP;                             -- Payments loop
                    END IF;                           -- CM balance zero check

                    --
                    IF l_adj_status = fnd_api.g_ret_sts_success
                    THEN
                        IF l_cm_balance = 0
                        THEN
                            UPDATE oe_order_lines_all ool
                               SET ool.attribute20 = 'CMA', ool.attribute19 = 'ADJUSTED', ool.attribute17 = fnd_api.g_ret_sts_success
                             WHERE     ool.attribute20 = c_cma.status_code
                                   AND ool.header_id = c_cma.header_id
                                   AND ool.attribute18 = c_cma.line_grp_id
                                   AND EXISTS
                                           (SELECT 1
                                              FROM ra_customer_trx_lines_all rctl
                                             WHERE     rctl.customer_trx_id =
                                                       c_cma.customer_trx_id
                                                   AND rctl.interface_line_context =
                                                       'ORDER ENTRY'
                                                   AND rctl.interface_line_attribute6 =
                                                       TO_CHAR (ool.line_id));

                            msg (
                                   'Successfully Processed Credit Memo#: '
                                || c_cma.trx_number,
                                100);
                        ELSE
                            msg (
                                   'Credit Memo#: '
                                || c_cma.trx_number
                                || ' has a balance of $'
                                || l_cm_balance,
                                100);
                        END IF;

                        COMMIT;
                    ELSE
                        msg (
                            'Unable to Process Credit Memo#: ' || c_cma.trx_number,
                            100);
                        ROLLBACK;
                    END IF;
                END IF;                                 -- OM, CM totals match
            EXCEPTION
                WHEN ex_mis_adj_name
                THEN
                    x_retcode   := 1;
                    x_errbuf    := 'Please setup Adjustment Activity Name';
                    ROLLBACK;
                WHEN OTHERS
                THEN
                    x_retcode   := 1;
                    x_errbuf    :=
                           'Unexpected Error occured while processing Order Header ID: '
                        || c_cma.header_id
                        || ' Lines Group ID: '
                        || c_cma.line_grp_id
                        || SQLERRM;
                    ROLLBACK;
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_retcode   := 2;
            x_errbuf    := 'Unexpected Error occured ' || SQLERRM;
    END create_cm_adjustment;
END XXDOEC_AR_CMADJ_PKG;
/
