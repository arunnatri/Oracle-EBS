--
-- XXDOEC_AR_RECEIPT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:06 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOEC_AR_RECEIPT_PKG"
AS
    /***********************************************************************************************
    * Program Name : XXDOEC_AR_RECEIPT_PKG                                                         *
    * Description  :                                                                               *
    *                                                                                              *
    * History      :                                                                               *
    *                                                                                              *
    * ===============================================================================              *
    * Who                   Version    Comments                                  When              *
    * ===============================================================================              *
    * BT Technology Team    1.1        Updated for BT                            05-JAN-2015       *
    * BT Technology Team    1.2        INFOSYS CCR0004339 - EBS changes for                        *
    *                                  eCommerce Loyalty program.                                  *
    * Infosys               1.3        Changes to invoice and order freight                        *
    *                                  amount derivation logic as part of                          *
    *                                  CCR0006807                                                  *
    * Srinath Siricilla     1.4        Japan DW PhaseII Changes - CCR0005991                       *
    * Madhav Dhurjaty       1.5        Quad Pay - New payment terms - CCR0007547                   *
    * Srinath Siricilla     1.6        CCR0007824                                13-FEB-2019       *
    * Damodara Gupta        1.7        CCR0009853                                27-APR-2022       *
    ***********************************************************************************************/

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

    /*--Added for CCR0007547 --Start*/
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
               AND NVL (v.attribute1, 'N') = 'Y'
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

    -- Start of CCR0005991 Changes
    FUNCTION calc_order_total (p_header_id IN NUMBER)
        RETURN NUMBER
    IS
        p_subtotal   NUMBER := 0;
        p_discount   NUMBER := 0;
        p_charges    NUMBER := 0;
        p_tax        NUMBER := 0;
        p_total      NUMBER := 0;
    BEGIN
        apps.oe_oe_totals_summary.order_totals (p_header_id, p_subtotal, p_discount
                                                , p_charges, p_tax);
        --p_total := NVL(p_subtotal,0)+NVL(p_discount,0)+NVL(p_tax,0);
        p_total   := NVL (p_subtotal, 0) + NVL (p_tax, 0);
        RETURN p_total;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_total   := 0;
            RETURN p_total;
    END calc_order_total;

    FUNCTION get_order_line_total (p_header_id IN NUMBER, p_line_group_id IN NUMBER, p_customer_trx_id IN NUMBER)
        RETURN NUMBER
    IS
        l_Total   NUMBER := 0;

        CURSOR line_total_cur (p_header_id         NUMBER,
                               p_line_group_id     NUMBER,
                               p_customer_trx_id   NUMBER)
        IS
              /*SELECT SUM(NVL(Ordered_Quantity,0)* NVL(unit_selling_price,0))
                     Line_details_total,
                     Line_Category_Code
                FROM apps.oe_order_lines
               WHERE 1=1
                 AND header_id               =p_header_id
                 AND attribute18             = TO_CHAR(p_line_group_id)
                 AND NVL(cancelled_flag,'N') ='N'
            GROUP BY line_category_code; */

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
        FOR Lines
            IN line_total_cur (p_header_id,
                               p_line_group_id,
                               p_customer_trx_id)
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
        SELECT SUM (val)
          INTO p_inv_total
          FROM (SELECT SUM (NVL (rctla.extended_amount, 0) + NVL (rctl_tax.extended_amount, 0)) val
                  FROM apps.oe_price_adjustments opa, apps.ra_customer_trx_lines rctla, apps.ra_customer_trx_lines rctl_tax
                 WHERE     TO_CHAR (opa.price_adjustment_id) =
                           rctla.interface_line_attribute6
                       AND rctl_tax.line_type(+) = 'TAX'
                       AND opa.list_line_type_code = 'FREIGHT_CHARGE'
                       AND rctla.interface_line_context(+) = 'ORDER ENTRY'
                       AND rctl_tax.customer_trx_id = rctla.customer_trx_id
                       AND rctla.customer_trx_line_id =
                           rctl_tax.link_to_cust_trx_line_id
                       AND rctla.customer_trx_id = p_customer_trx_id
                       AND EXISTS
                               (SELECT 1
                                  FROM apps.oe_order_lines oola
                                 WHERE     1 = 1
                                       AND oola.line_id = opa.line_id
                                       -- AND oola.attribute18 = p_line_group_id Commented as part of change 1.6
                                       AND oola.attribute18 =
                                           TO_CHAR (p_line_group_id) -- Added as part of change 1.6
                                       AND oola.header_id = p_header_id)
                       AND EXISTS
                               (SELECT 1
                                  FROM apps.mtl_system_items msi
                                 WHERE     msi.inventory_item_id =
                                           rctla.inventory_item_id
                                       AND msi.segment1 = 'FRT-NA-NA')
                UNION ALL
                SELECT SUM (NVL (rctl.extended_amount, 0) + NVL (rctl_tax.extended_amount, 0))
                  FROM apps.ra_customer_trx_lines rctl, apps.ra_customer_trx_lines rctl_tax, apps.oe_order_lines ool
                 WHERE     1 = 1
                       AND rctl.interface_line_context(+) = 'ORDER ENTRY'
                       AND rctl_tax.line_type(+) = 'TAX'
                       AND rctl_tax.customer_trx_id(+) = rctl.customer_trx_id
                       AND rctl_tax.link_to_cust_trx_line_id(+) =
                           rctl.customer_trx_line_id
                       AND rctl.interface_line_attribute6(+) =
                           TO_CHAR (ool.line_id)
                       -- AND ool.attribute18 = p_line_group_id Commented as part of change 1.6
                       AND ool.attribute18 = TO_CHAR (p_line_group_id) -- Added as part of change 1.6
                       AND ool.header_id = p_header_id
                       AND rctl.customer_trx_id = p_customer_trx_id);

        /*SELECT  SUM (rctl.extended_amount + NVL (rctl_tax.extended_amount, 0))
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
        AND ool.attribute18 = p_line_group_id
        AND ool.header_id = p_header_id;*/
        RETURN p_inv_total;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_inv_total   := 0;
            RETURN p_inv_total;
    END get_trx_line_total;

    FUNCTION check_freight_line (p_customer_trx_id IN NUMBER)
        RETURN BOOLEAN
    IS
        V_boolean   BOOLEAN;
        ln_count    NUMBER;
    BEGIN
        SELECT COUNT (1)
          INTO ln_count
          FROM apps.ra_customer_trx_lines_all
         WHERE     customer_trx_id = p_customer_trx_id
               AND LINE_TYPE = 'FREIGHT'
               AND interface_line_context(+) = 'ORDER ENTRY';

        IF ln_count > 0
        THEN
            V_boolean   := TRUE;
        ELSE
            v_boolean   := FALSE;
        END IF;

        RETURN v_boolean;
    END;

    /*
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
    END get_trx_total;
    */

    -- End of CCR0005991 Changes

    PROCEDURE create_cash_receipt (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, p_header_id IN NUMBER)
    IS
        CURSOR c_order_lines IS
              SELECT ool.header_id, ool.sold_to_org_id, ool.invoice_to_org_id,
                     ool.attribute18 line_grp_id, ool.attribute20 status_code, ool.attribute16 pgc_trans_num,
                     rctl.customer_trx_id, SUM (ool.ordered_quantity * ool.unit_selling_price) + SUM (NVL (DECODE (zxr.inclusive_tax_flag, 'Y', 0, opa_tax.adjusted_amount), 0)) om_line_total, SUM (rctl.extended_amount + NVL (rctl_tax.extended_amount, 0)) inv_line_total
                FROM oe_order_lines ool, oe_price_adjustments opa_tax, zx_rates_b zxr,
                     ra_customer_trx_lines rctl, ra_customer_trx_lines rctl_tax, oe_order_headers ooh,
                     oe_transaction_types ott
               WHERE     ool.attribute20 = 'PGC'
                     AND ool.attribute19 = 'SUCCESS'
                     AND ool.attribute17 = 'S'
                     AND ool.line_category_code = 'ORDER'
                     AND opa_tax.line_id(+) = ool.line_id
                     AND opa_tax.list_line_type_code(+) = 'TAX'
                     AND zxr.tax_rate_id(+) = opa_tax.tax_rate_id
                     AND rctl.interface_line_context(+) = 'ORDER ENTRY'
                     AND rctl.interface_line_attribute6(+) =
                         TO_CHAR (ool.line_id)
                     AND rctl_tax.line_type(+) = 'TAX'
                     AND rctl_tax.customer_trx_id(+) = rctl.customer_trx_id
                     AND rctl_tax.link_to_cust_trx_line_id(+) =
                         rctl.customer_trx_line_id
                     AND ool.header_id = NVL (p_header_id, ool.header_id)
                     AND ooh.header_id = ool.header_id
                     AND ott.transaction_type_id = ooh.order_type_id
                     --AND ott.attribute13 NOT IN ('PP', 'PE')   --Commented for CCR0007547
                     /*--Added for CCR0007547 --Start*/
                     AND ott.attribute13 NOT IN
                             (SELECT v.flex_value      --"Excluded_Order_Type"
                                FROM apps.fnd_flex_value_sets s, apps.fnd_flex_values_vl v
                               WHERE     1 = 1
                                     AND s.flex_value_set_id =
                                         v.flex_value_set_id
                                     AND s.flex_value_set_name =
                                         'XXDO_ORDER_TYPE_PURPOSE'
                                     AND v.enabled_flag = 'Y'
                                     AND NVL (v.attribute1, 'N') = 'Y')
            /*--Added for CCR0007547 --End*/
            GROUP BY ool.header_id, ool.sold_to_org_id, ool.invoice_to_org_id,
                     ool.attribute18, ool.attribute20, ool.attribute16,
                     rctl.customer_trx_id;

        /*Start of change as part of verison 1.3  */
        /*
        CURSOR c_frt_charges (
           c_header_id     IN NUMBER,
           c_line_grp_id   IN VARCHAR2)
        IS
           SELECT SUM (opa.adjusted_amount) om_frt_amount,
                  SUM (
                     rctl_frt.extended_amount
                     + NVL (rctl_frt_tax.extended_amount, 0))
                     inv_frt_total
             FROM oe_order_lines ool,
                  oe_price_adjustments opa,
                  ra_customer_trx_lines rctl_frt,
                  ra_customer_trx_lines rctl_frt_tax
            WHERE     ool.attribute20 = 'PGC'
                  AND ool.attribute19 = 'SUCCESS'
                  AND ool.attribute17 = 'S'
                  AND ool.line_category_code = 'ORDER'
                  AND opa.list_line_type_code = 'FREIGHT_CHARGE'
                  AND opa.line_id = ool.line_id
                  AND rctl_frt.interface_line_context(+) = 'ORDER ENTRY'
                  AND rctl_frt.interface_line_attribute6(+) =
                         TO_CHAR (opa.price_adjustment_id)
                  AND rctl_frt_tax.line_type(+) = 'TAX'
                  AND rctl_frt_tax.customer_trx_id(+) =
                         rctl_frt.customer_trx_id
                  AND rctl_frt_tax.link_to_cust_trx_line_id(+) =
                         rctl_frt.customer_trx_line_id
                  AND ool.header_id = c_header_id
                  AND ool.attribute18 = c_line_grp_id;
                  */

        CURSOR c_ord_frt_charges (c_header_id IN NUMBER, c_line_grp_id IN VARCHAR2, c_cust_trx_id IN NUMBER)
        IS
            SELECT SUM (opa.adjusted_amount) om_frt_amount
              FROM -- oe_order_headers ooha,  -- Modified for 1.3 on 22-FEB-2018
                   oe_order_lines ool, oe_price_adjustments opa            --,
             --   ra_customer_trx rct,  -- Modified for 1.3 on 22-FEB-2018
             --   ra_customer_trx_lines rctl  -- Modified for 1.3 on 22-FEB-2018
             WHERE     ool.attribute20 = 'PGC'
                   AND ool.attribute19 = 'SUCCESS'
                   AND ool.attribute17 = 'S'
                   AND ool.line_category_code = 'ORDER'
                   AND opa.list_line_type_code = 'FREIGHT_CHARGE'
                   AND opa.line_id = ool.line_id
                   AND ool.line_id IN
                           (SELECT interface_line_attribute6
                              FROM ra_customer_trx_lines_all rctl
                             WHERE rctl.customer_trx_id = c_cust_trx_id)
                   --   AND TO_CHAR(rct.interface_header_attribute1)=TO_CHAR(ooha.order_number) -- Modified for 1.3 on 22-FEB-2018
                   --   AND rct.customer_trx_id                     =rctl.customer_trx_id -- Modified for 1.3 on 22-FEB-2018
                   --   AND RCTL.SALES_ORDER_LINE                   =OOL.LINE_NUMBER -- Modified for 1.3 on 22-FEB-2018
                   --   AND rct.customer_trx_id                     =c_cust_trx_id -- Modified for 1.3 on 22-FEB-2018
                   AND ool.header_id = c_header_id
                   --   AND ool.attribute18                         = c_line_grp_id;  -- Commented as part of Change 1.6
                   AND ool.attribute18 = TO_CHAR (c_line_grp_id); -- Modified as part of Change 1.6

        CURSOR c_inv_frt_charges (c_cust_trx_id IN NUMBER)
        IS
            SELECT SUM (rctl_frt.extended_amount + NVL (rctl_frt_tax.extended_amount, 0)) inv_frt_total
              FROM ra_customer_trx_lines rctl_frt, ra_customer_trx_lines rctl_frt_tax
             WHERE     rctl_frt.customer_trx_id = c_cust_trx_id
                   AND rctl_frt.LINE_TYPE = 'FREIGHT'
                   AND rctl_frt.interface_line_context(+) = 'ORDER ENTRY'
                   AND rctl_frt_tax.line_type(+) = 'TAX'
                   AND rctl_frt_tax.customer_trx_id(+) =
                       rctl_frt.customer_trx_id
                   AND rctl_frt_tax.link_to_cust_trx_line_id(+) =
                       rctl_frt.customer_trx_line_id;

        /*End of change as part of verison 1.3  */


        CURSOR c_order_payments (c_header_id     IN NUMBER,
                                 c_line_grp_id   IN VARCHAR2)
        IS
            SELECT payment_id,
                   payment_trx_id,
                   payment_type,
                   NVL (unapplied_amount, payment_amount)
                       payment_amount,
                   payment_date,
                   pg_reference_num,
                   (SELECT DECODE (SIGN (pt.product_selling_price_total + ftt.freight_charge_total + ftt.freight_discount_total + ftt.gift_wrap_total + ftt.tax_total_no_vat),  -1, 'CHB',  1, 'PGC',  'NOP')
                      FROM xxdoec_oe_order_product_totals pt, xxdoec_oe_order_frt_tax_totals ftt
                     WHERE     pt.header_id = c_header_id
                           AND pt.attribute18 = c_line_grp_id
                           AND ftt.header_id = c_header_id
                           AND ftt.attribute18 = c_line_grp_id)
                       payment_action,
                   payment_tender_type       --Added by Madhav for ENHC0011797
              FROM xxdoec_order_payment_details
             WHERE     status = 'OP'
                   /*--Commented for CCR0007547 --Start*/
                   --AND payment_type IN
                   --       ('CC', 'PP', 'GC', 'SC', 'CP', 'AD', 'RM', 'RC','COD') -- Added COD as a part of CCR0005991 Change
                   /*--Commented for CCR0007547 --End*/
                   /*--Added for CCR0007547 --Start*/
                   AND payment_type IN
                           (SELECT v.flex_value       --"Create_Cash_Receipts"
                              FROM apps.fnd_flex_value_sets s, apps.fnd_flex_values_vl v
                             WHERE     1 = 1
                                   AND s.flex_value_set_id =
                                       v.flex_value_set_id
                                   AND s.flex_value_set_name =
                                       'XXDO_ECOMM_RECPT_TYPE'
                                   AND v.enabled_flag = 'Y'
                                   AND NVL (v.attribute1, 'N') = 'Y')
                   /*--Added for CCR0007547 --End*/
                   --Added this based on the UAT package change with comment---- added transaction types RM and RC by showkath on 18-AUG-15 --W.r.t Version 1.2
                   AND header_id = c_header_id
                   AND line_group_id = c_line_grp_id
                   AND payment_amount <> 0;

        CURSOR c_inv_balance (c_inv_trx_id IN NUMBER)
        IS
            SELECT SUM (ABS (amount_due_remaining))
              FROM apps.ar_payment_schedules aps
             WHERE customer_trx_id = c_inv_trx_id;

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

        l_om_frt_total        NUMBER;
        l_inv_frt_total       NUMBER;
        -- Added for CCR0005991 Change
        l_om_line_total       NUMBER;
        l_inv_line_total      NUMBER;
        -- End of CCR0005991 Change
        l_inv_balance         NUMBER;
        l_apply_amt           NUMBER;
        l_receipt_method_id   NUMBER;
        l_bank_account_id     NUMBER;
        l_bank_branch_id      NUMBER;
        l_batch_id            NUMBER;
        l_cash_receipt_id     NUMBER;
        l_receipt_number      VARCHAR2 (30);
        l_batch_name          VARCHAR2 (120);
        l_error_msg           VARCHAR2 (2000);
        l_pmt_status          VARCHAR2 (1);
        l_rtn_status          VARCHAR2 (1);
        cb_params_rec         c_cb_params%ROWTYPE;
        l_debug               NUMBER := 0;
        l_rc                  NUMBER := 0;
        v_boolean1            BOOLEAN;
        dcdlog                dcdlog_type
            := dcdlog_type (p_code => -10035, p_application => g_application, p_logeventtype => 4
                            , p_tracelevel => 2, p_debug => 0); -- Start off by logging metric.

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
        dcdlog.addparameter ('Start',
                             TO_CHAR (CURRENT_TIMESTAMP),
                             'TIMESTAMP');
        fnd_file.put_line (fnd_file.LOG, 'Start of the Program');
        l_rc   := dcdlog.loginsert ();

        FOR c_ccr IN c_order_lines
        LOOP
            BEGIN
                fnd_file.put_line (fnd_file.LOG, 'Order lines loop');
                fnd_file.put_line (fnd_file.LOG, 'Status - ' || l_rtn_status);
                -- Added for CCR0005991 Change
                l_om_line_total    := 0;
                l_inv_line_total   := 0;

                /*
                BEGIN
                SELECT  xxdoec_ar_receipt_pkg.calc_order_total(c_ccr.header_id)
                  INTO  l_om_line_total
                  FROM  dual;
                EXCEPTION
                WHEN OTHERS
                THEN
                  l_om_line_total := 0;
                END;

                BEGIN
                SELECT  xxdoec_ar_receipt_pkg.get_trx_total(c_ccr.header_id)
                  INTO  l_inv_line_total
                  FROM  dual;
                EXCEPTION
                WHEN OTHERS
                THEN
                  l_inv_line_total := 0;
                END; */

                BEGIN
                    SELECT xxdoec_ar_receipt_pkg.get_order_line_total (c_ccr.header_id, c_ccr.line_grp_id, c_ccr.customer_trx_id)
                      INTO l_om_line_total
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_om_line_total   := 0;
                END;

                BEGIN
                    SELECT xxdoec_ar_receipt_pkg.get_trx_line_total (c_ccr.header_id, c_ccr.line_grp_id, c_ccr.customer_trx_id)
                      INTO l_inv_line_total
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_inv_line_total   := 0;
                END;

                msg (
                       ' Header ID: '
                    || c_ccr.header_id
                    || ' New Invoice Line Total: '
                    || l_inv_line_total
                    || ' New Order Line Total: '
                    || l_om_line_total,
                    100);

                -- End of CCR0005991 Change

                l_inv_frt_total    := 0;
                l_om_frt_total     := 0;

                /*Start of change as part of verison 1.3  */
                /*
                OPEN c_frt_charges (c_ccr.header_id, c_ccr.line_grp_id);

                FETCH c_frt_charges
                INTO l_om_frt_total, l_inv_frt_total;

                CLOSE c_frt_charges;
                */

                OPEN c_ord_frt_charges (c_ccr.header_id,
                                        c_ccr.line_grp_id,
                                        c_ccr.customer_trx_id);

                FETCH c_ord_frt_charges INTO l_om_frt_total;

                CLOSE c_ord_frt_charges;

                OPEN c_inv_frt_charges (c_ccr.customer_trx_id);

                FETCH c_inv_frt_charges INTO l_inv_frt_total;

                CLOSE c_inv_frt_charges;

                /*End of change as part of verison 1.3  */

                -- Added for CCR0005991 Change

                IF check_freight_line (c_ccr.customer_trx_id)
                THEN
                    l_inv_frt_total   :=
                        NVL (l_inv_frt_total, l_om_frt_total);
                ELSE
                    l_inv_frt_total   := l_inv_frt_total;
                END IF;

                -- End of CCR0005991 Change

                IF l_inv_frt_total > l_om_frt_total
                THEN
                    l_inv_frt_total   := l_om_frt_total;
                END IF;

                msg (
                       ' Header ID: '
                    || c_ccr.header_id
                    || ' Lines Group ID: '
                    || c_ccr.line_grp_id
                    || ' Invoice ID: '
                    || c_ccr.customer_trx_id,
                    100);

                /*msg (
                      'Order Lines Total: '
                   || c_ccr.om_line_total
                   || ' Order Freight Total: '
                   || l_om_frt_total,
                   100);
                msg (
                      'Invoice Lines Total: '
                   || c_ccr.inv_line_total
                   || ' Invoice Freight Total: '
                   || l_inv_frt_total,
                   100);*/

                msg (
                       ' Order Lines Total: '
                    || l_om_line_total
                    || ' Order Freight Total: '
                    || l_om_frt_total,
                    100);

                msg (
                       ' Invoice Lines Total: '
                    || l_inv_line_total
                    || ' Invoice Freight Total: '
                    || l_inv_frt_total,
                    100);

                --- Start of CCR0005991 Change
                /*IF (c_ccr.om_line_total + NVL (l_om_frt_total, 0))
                   - (NVL (c_ccr.inv_line_total, 0) + NVL (l_inv_frt_total, 0)) NOT BETWEEN -0.1
                                                                                        AND 0.1*/
                -- IF (l_om_line_total + NVL (l_om_frt_total, 0))
                -- - (NVL (l_inv_line_total, 0) + NVL (l_inv_frt_total, 0)) NOT BETWEEN -0.1
                -- AND 0.1
                --- End of CCR0005991 Change
                -- Begin Changes v1.7
                IF   (l_om_line_total + NVL (l_om_frt_total, 0))
                   - (NVL (l_inv_line_total, 0) + NVL (l_inv_frt_total, 0)) NOT BETWEEN -1
                                                                                    AND 1
                -- End Changes v1.7

                THEN
                    msg ('Some of the Order Lines are not invoiced yet', 100);
                ELSE
                    l_rtn_status   := fnd_api.g_ret_sts_success;

                    OPEN c_inv_balance (c_ccr.customer_trx_id);

                    FETCH c_inv_balance INTO l_inv_balance;

                    CLOSE c_inv_balance;

                    /*l_inv_balance :=
                       LEAST (l_inv_balance,
                              (c_ccr.inv_line_total + NVL (l_inv_frt_total, 0)));*/

                    -- Begin Commented Changes v1.7

                    /*l_inv_balance :=
                        LEAST (l_inv_balance,
                               (l_inv_line_total + NVL (l_inv_frt_total, 0)));*/

                    -- End Commented Changes v1.7

                    msg ('Invoice balance is : ' || l_inv_balance, 100);

                    IF l_inv_balance > 0
                    THEN
                        -- loop through OM Payment details
                        FOR c_opd
                            IN c_order_payments (c_ccr.header_id,
                                                 c_ccr.line_grp_id)
                        LOOP
                            /*Commented for CCR0007547 - Start*/
                            --IF c_opd.payment_type IN
                            --      ('CC', 'PP', 'GC', 'SC', 'CP', 'AD', 'RM', 'RC','COD') -- Added COD as a part of CCR0005991 Change
                            --Added this based on the UAT package change with comment---- added transaction types RM and RC by showkath on 18-AUG-15 --W.r.t Version 1.2
                            /*Commented for CCR0007547 - End*/
                            /*Added for CCR0007547 - Start*/
                            IF     check_payment_type (c_opd.payment_type)
                               /*Added for CCR0007547 - End*/
                               AND c_opd.payment_action = 'PGC'
                            THEN
                                msg (
                                       ' Payment Type: '
                                    || c_opd.payment_type
                                    || ' Payment Action: '
                                    || c_opd.payment_action
                                    || ' Amount: '
                                    || c_opd.payment_amount,
                                    100);
                                l_pmt_status    := fnd_api.g_ret_sts_success;
                                l_error_msg     := NULL;
                                l_apply_amt     :=
                                    LEAST (c_opd.payment_amount,
                                           l_inv_balance);
                                cb_params_rec   := NULL;

                                -- create Receipt Batch
                                OPEN c_cb_params (c_ccr.header_id);

                                FETCH c_cb_params INTO cb_params_rec;

                                CLOSE c_cb_params;

                                --
                                get_receipt_method (cb_params_rec.ar_receipt_class_id, c_opd.payment_type, cb_params_rec.website_id, cb_params_rec.transactional_curr_code, l_receipt_method_id, l_bank_account_id
                                                    , l_bank_branch_id);

                                --
                                IF l_receipt_method_id IS NULL
                                THEN
                                    msg (
                                           'Unable to find the Receipt Method for Payment Type '
                                        || c_opd.payment_type,
                                        100);
                                    l_pmt_status   := fnd_api.g_ret_sts_error;
                                ELSE
                                    -- Create Receipt Batch
                                    do_ar_utils.create_receipt_batch_trans (
                                        p_company          =>
                                            cb_params_rec.company_name,
                                        p_batch_source_id   =>
                                            cb_params_rec.ar_batch_source_id,
                                        p_bank_branch_id   =>
                                            NVL (
                                                l_bank_branch_id,
                                                cb_params_rec.ar_bank_branch_id),
                                        p_batch_type       =>
                                            cb_params_rec.ar_batch_type,
                                        p_currency_code    =>
                                            cb_params_rec.transactional_curr_code,
                                        p_bank_account_id   =>
                                            NVL (
                                                l_bank_account_id,
                                                cb_params_rec.ar_bank_account_id),
                                        p_batch_date       => c_opd.payment_date,
                                        p_receipt_class_id   =>
                                            cb_params_rec.ar_receipt_class_id,
                                        p_control_count    => 1,
                                        p_gl_date          =>
                                            c_opd.payment_date,
                                        p_receipt_method_id   =>
                                            NVL (
                                                l_receipt_method_id,
                                                cb_params_rec.ar_receipt_method_id),
                                        p_control_amount   => l_apply_amt,
                                        p_deposit_date     =>
                                            c_opd.payment_date,
                                        p_comments         =>
                                               'Order# '
                                            || cb_params_rec.order_number
                                            || ' Line Grp ID: '
                                            || c_ccr.line_grp_id,
                                        p_auto_commit      => 'N',
                                        x_batch_id         => l_batch_id,
                                        x_batch_name       => l_batch_name,
                                        x_error_msg        => l_error_msg);


                                    IF l_batch_id <> -1
                                    THEN
                                        -- create receipt
                                        SELECT xxdo.xxdoec_cash_receipts_s.NEXTVAL
                                          INTO l_receipt_number
                                          FROM DUAL;

                                        l_error_msg   := NULL;
                                        do_ar_utils.create_receipt_trans (
                                            p_batch_id        => l_batch_id,
                                            p_receipt_number   =>
                                                l_receipt_number,
                                            p_receipt_amt     => l_apply_amt,
                                            p_transaction_num   =>
                                                c_opd.pg_reference_num,
                                            p_payment_server_order_num   =>
                                                c_opd.pg_reference_num,
                                            p_customer_number   =>
                                                cb_params_rec.customer_number,
                                            p_customer_name   => NULL,
                                            p_comments        =>
                                                   'Order# '
                                                || cb_params_rec.order_number
                                                || ' Line Grp ID: '
                                                || c_ccr.line_grp_id
                                                || 'PG Ref: '
                                                || c_opd.pg_reference_num,
                                            p_currency_code   =>
                                                cb_params_rec.transactional_curr_code,
                                            p_location        => NULL,
                                            p_auto_commit     => 'N',
                                            x_cash_receipt_id   =>
                                                l_cash_receipt_id,
                                            x_error_msg       => l_error_msg);


                                        IF NVL (l_cash_receipt_id, -200) =
                                           -200
                                        THEN
                                            msg (
                                                   'Unable to create Cash Receipt for the amount '
                                                || l_apply_amt,
                                                100);

                                            l_pmt_status   :=
                                                fnd_api.g_ret_sts_error;
                                        ELSE
                                            msg (
                                                   'Successfully created Cash Receipt for the amount '
                                                || l_apply_amt,
                                                100);
                                            msg (
                                                   'Cash Receipt ID: '
                                                || l_cash_receipt_id,
                                                100);

                                            BEGIN
                                                UPDATE ar_cash_receipts_all
                                                   --Added by Madhav for ENHC0011797
                                                   SET attribute14 = c_opd.payment_tender_type
                                                 --Added by Madhav for ENHC0011797
                                                 WHERE cash_receipt_id =
                                                       l_cash_receipt_id;
                                            EXCEPTION
                                                WHEN OTHERS
                                                THEN
                                                    NULL;
                                                    msg (
                                                           'Exception updating cash receipts  '
                                                        || SUBSTR (SQLERRM,
                                                                   1,
                                                                   200),
                                                        100);
                                            END;

                                            --Added by Madhav for ENHC0011797
                                            l_error_msg   := NULL;
                                            -- Apply cash to Invoice
                                            do_ar_utils.apply_transaction_trans (
                                                p_cash_receipt_id   =>
                                                    l_cash_receipt_id,
                                                p_customer_trx_id   =>
                                                    c_ccr.customer_trx_id,
                                                p_trx_number    => NULL,
                                                p_applied_amt   => l_apply_amt,
                                                p_discount      => NULL,
                                                p_auto_commit   => 'N',
                                                x_error_msg     => l_error_msg);

                                            IF l_error_msg IS NULL
                                            THEN
                                                msg (
                                                       'Successfully Applied Amount: '
                                                    || l_apply_amt
                                                    || ' to Invoice ID: '
                                                    || c_ccr.customer_trx_id,
                                                    100);
                                            ELSE
                                                msg (
                                                       'Unable to Apply Cash Receipt to Invoice ID: '
                                                    || c_ccr.customer_trx_id,
                                                    100);
                                                l_pmt_status   :=
                                                    fnd_api.g_ret_sts_error;
                                            END IF; -- Cash Receipt App success
                                        END IF;        -- Cash Receipt success
                                    ELSE
                                        msg (
                                            'Unable to create Cash Receipt Batch ',
                                            100);
                                        l_pmt_status   :=
                                            fnd_api.g_ret_sts_error;
                                    END IF;           -- Receipt Batch success
                                END IF;                 -- cb_params_rec found

                                --
                                IF l_pmt_status = fnd_api.g_ret_sts_success
                                THEN
                                    BEGIN
                                        UPDATE xxdoec_order_payment_details
                                           SET unapplied_amount = c_opd.payment_amount - l_apply_amt, status = DECODE (SIGN (c_opd.payment_amount - l_apply_amt), 0, 'CL', 'OP')
                                         WHERE payment_id = c_opd.payment_id;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            NULL;
                                            msg (
                                                   'Exception while update payment order custom table : '
                                                || SUBSTR (SQLERRM, 1, 200),
                                                100);
                                    END;

                                    l_inv_balance   :=
                                        l_inv_balance - l_apply_amt;

                                    IF l_inv_balance <= 0
                                    THEN
                                        EXIT;
                                    END IF;
                                ELSE
                                    l_rtn_status   := fnd_api.g_ret_sts_error;
                                    msg (
                                           'Error in else clause : '
                                        || SUBSTR (SQLERRM, 1, 200),
                                        100);
                                END IF;
                            END IF;                      -- payment_type check
                        END LOOP;                      -- Payment details loop
                    END IF;                       -- invoice balance > 0 check

                    IF     l_rtn_status = fnd_api.g_ret_sts_success
                       AND l_inv_balance = 0
                    THEN
                        BEGIN
                            UPDATE oe_order_lines_all ool
                               SET ool.attribute20 = 'CCR', ool.attribute19 = 'APPLIED', ool.attribute17 = fnd_api.g_ret_sts_success
                             WHERE     ool.attribute20 = c_ccr.status_code
                                   AND ool.header_id = c_ccr.header_id
                                   AND ool.attribute18 = c_ccr.line_grp_id
                                   AND EXISTS
                                           (SELECT 1
                                              FROM ra_customer_trx_lines_all rctl
                                             WHERE     rctl.customer_trx_id =
                                                       c_ccr.customer_trx_id
                                                   AND rctl.interface_line_context =
                                                       'ORDER ENTRY'
                                                   AND rctl.interface_line_attribute6 =
                                                       TO_CHAR (ool.line_id));
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                NULL;
                                msg (
                                       'Exception while updating Order lines table : '
                                    || SUBSTR (SQLERRM, 1, 200),
                                    100);
                        END;

                        COMMIT;
                    ELSE
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Warning Error Message is : '
                            || SUBSTR (SQLERRM, 1, 200));
                        x_retcode   := 1;
                        ROLLBACK;
                    END IF;
                END IF;                             -- Order lines Total match

                dcdlog.changecode (p_code => -10035, p_application => g_application, p_logeventtype => 4
                                   , p_tracelevel => 2, p_debug => l_debug);
                dcdlog.addparameter ('End',
                                     TO_CHAR (CURRENT_TIMESTAMP),
                                     'TIMESTAMP');
                l_rc               := dcdlog.loginsert ();

                IF (l_rc <> 1)
                THEN
                    msg (dcdlog.l_message);
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_retcode   := 1;
                    x_errbuf    :=
                           'Unexpected Error occured while processing Order Header ID: '
                        || c_ccr.header_id
                        || ' Lines Group ID: '
                        || c_ccr.line_grp_id
                        || SQLERRM;
                    msg ('x_errbuf info is : ' || x_errbuf, 100);
                    dcdlog.changecode (p_code => -10034, p_application => g_application, p_logeventtype => 1
                                       , p_tracelevel => 1, p_debug => l_debug);
                    dcdlog.addparameter ('c_ccr.header_id',
                                         TO_CHAR (c_ccr.header_id),
                                         'NUMBER');
                    dcdlog.addparameter ('c_ccr.line_grp_id',
                                         TO_CHAR (c_ccr.line_grp_id),
                                         'NUMBER');
                    dcdlog.addparameter ('SQLERRM', SQLERRM, 'VARCHAR2');
                    l_rc        := dcdlog.loginsert ();

                    IF (l_rc <> 1)
                    THEN
                        msg (dcdlog.l_message);
                    END IF;
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_retcode   := 2;
            x_errbuf    := 'Unexpected Error occured ' || SQLERRM;
            msg ('x_errbuf info is : ' || x_errbuf, 100);
            dcdlog.changecode (p_code => -10034, p_application => g_application, p_logeventtype => 1
                               , p_tracelevel => 1, p_debug => l_debug);
            dcdlog.addparameter ('SQLERRM', SQLERRM, 'VARCHAR2');
            l_rc        := dcdlog.loginsert ();

            IF (l_rc <> 1)
            THEN
                msg (dcdlog.l_message);
                msg ('Last l_rc value : ' || dcdlog.l_message, 100);
            END IF;
    END create_cash_receipt;
END XXDOEC_AR_RECEIPT_PKG;
/
