--
-- XXD_AR_CREATE_ADJUSTMENTS  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:32 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AR_CREATE_ADJUSTMENTS"
AS
    /****************************************************************************************
     * Package      : XXD_AR_CREATE_ADJUSTMENTS
     * Design       : This package will be used for tax rounding error in EBS over/under charging customers / AR - Program to Create Adjustment entries related to eComm Rounding Issues
     * Notes        :
     * Modification :
     -- ======================================================================================
     -- Date         Version#   Name                    Comments
     -- ======================================================================================
     -- 08-Aug-2020  1.0        Tejaswi Gangumalla      Initial Version
     -- 02-Aug-2021  1.1        Jayarajan A K           Modified for CCR0009263 for handling exchange order scenario
     -- 18-Oct-2021  1.2        Jayarajan A K           Modified for CCR0009263 to create CM adjustment as LINE instead of TAX
     -- 27-Apr-2022  1.3        Jayarajan A K           CCR0009853: Open AR Lines leaving penny balances(tax rounding issue)
     ******************************************************************************************/

    gn_conc_request_id   NUMBER := fnd_global.conc_request_id;
    gn_user_id           NUMBER := fnd_global.user_id;

    PROCEDURE msg (MESSAGE VARCHAR2, debug_level NUMBER:= 100)
    IS
    BEGIN
        fnd_file.put_line (fnd_file.LOG, MESSAGE);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN;
    END msg;

    --Start changes v1.1
    FUNCTION check_exchange_type (p_order_type IN VARCHAR2)
        RETURN BOOLEAN
    IS
        ln_count   NUMBER;
    BEGIN
        SELECT COUNT (1)
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

    --End changes v1.1

    PROCEDURE insert_data
    AS
        lv_sql_stamtment   LONG;
        lv_msg             VARCHAR2 (2000);
        lv_where           VARCHAR2 (2000);
        lv_where1          VARCHAR2 (2000);
        lv_where2          VARCHAR2 (2000);
    BEGIN
        IF pn_trx_number IS NOT NULL
        THEN
            lv_where1   := 'and rct.trx_number=' || pn_trx_number;
        END IF;

        IF pv_gl_date_from IS NOT NULL AND pv_gl_date_to IS NOT NULL
        THEN
            lv_where2   :=
                   ' AND TRUNC (aps.gl_date) BETWEEN fnd_date.canonical_to_date ( '''
                || pv_gl_date_from
                || ''' )  AND fnd_date.canonical_to_date ( '''
                || pv_gl_date_to
                || ''' ) ';
        END IF;

        IF pv_date_from IS NOT NULL AND pv_date_to IS NOT NULL
        THEN
            lv_where   :=
                   ' AND TRUNC (rct.trx_date ) BETWEEN fnd_date.canonical_to_date ( '''
                || pv_date_from
                || ''' )  AND fnd_date.canonical_to_date ( '''
                || pv_date_to
                || ''' ) ';
        END IF;

        lv_sql_stamtment   :=
               'INSERT INTO xxdo.xxd_ar_create_adjustments_stg (SELECT *
      FROM (SELECT'
            || ''''
            || 'CM'
            || ''''
            || ' inv_type,xopd.payment_type,xopd.payment_date,  order_number,
                     cust_po_number, customer_number, invoice_to_org_id,
                     ship_to_org_id, exchange_order_type, a.header_id,
                     line_grp_id, status_code, pgc_trans_num, customer_trx_id,
                     trx_number,'
            || ''''
            || ''''
            || ' adj_activity_name, trx_type_name, TYPE,
                     SUM (om_line_total) om_line_total,
                     SUM (inv_line_total) inv_line_total,xopd.payment_amount,amount_due_original,amount_due_remaining,
                     NVL (xopd.unapplied_amount,xopd.payment_amount) bal_amount,
                      ABS (amount_due_remaining)
                               - NVL (xopd.unapplied_amount,
                                      xopd.payment_amount
                                     ) diff,
                      SUM (om_line_total)-SUM (inv_line_total) inv_diff,'
            || ''''
            || ''''
            || ' adj_num,'
            || ''''
            || ''''
            || '
                       adj_date,'
            || ''''
            || 'N'
            || ''''
            || ','
            || ''''
            || ''''
            || ','
            || gn_conc_request_id
            || ','
            || gn_user_id
            || ','
            || ''''
            || SYSDATE
            || ''''
            || '
                FROM (SELECT   ooh.order_number,
                               ott.attribute13 exchange_order_type,
                               ool.header_id,
                               hca.account_number customer_number,
                               ooh.ship_to_org_id, ool.line_id,
                               ooh.cust_po_number,-- xopd.payment_type,
                               aps.amount_due_original,
                               aps.amount_due_remaining,
                               ool.attribute18 line_grp_id,
                               ool.attribute20 status_code,
                               ool.attribute16 pgc_trans_num,
                               ool.invoice_to_org_id, rctl.customer_trx_id,
                               rct.trx_number,
                               rta.NAME adj_activity_name,
                               rctt.NAME trx_type_name, rctt.TYPE,
                                 (ool.ordered_quantity
                                  * ool.unit_selling_price
                                 )
                               + (NVL (DECODE (zxr.inclusive_tax_flag,'
            || ''''
            || 'Y'
            || ''''
            || ', 0,
                                               opa_tax.adjusted_amount
                                              ),
                                       0
                                      )
                                 ) om_line_total,
                               ABS
                                  (SUM (  rctl.extended_amount
                                        + NVL (rctl_tax.extended_amount, 0)
                                       ))
																																		inv_line_total
                               --xopd.payment_amount
                          FROM oe_order_lines_all ool,
                               oe_order_headers_all ooh,
                               oe_transaction_types_all ott,
                               oe_price_adjustments opa_tax,
                               zx_rates_b zxr,
                               ra_customer_trx_lines_all rctl,
                               ra_customer_trx_lines_all rctl_tax,
                               ra_customer_trx_all rct,
                               ra_cust_trx_types_all rctt,
                               ar_receivables_trx_all rta,
                               hz_cust_accounts hca,
                               apps.ar_payment_schedules_all aps
                               --xxdoec_order_payment_details xopd
                         WHERE ool.attribute17 ='
            || ''''
            || 'S'
            || ''''
            || '
                           AND ool.line_category_code ='
            || ''''
            || 'RETURN'
            || ''''
            || '
                           AND ooh.header_id = ool.header_id
                           AND ott.transaction_type_id = ooh.order_type_id
                           AND opa_tax.line_id(+) = ool.line_id
                           AND rctt.TYPE ='
            || ''''
            || 'CM'
            || ''''
            || '                     --modified
                           AND opa_tax.list_line_type_code(+) ='
            || ''''
            || 'TAX'
            || ''''
            || '
                           AND zxr.tax_rate_id(+) = opa_tax.tax_rate_id
                           AND rctl.interface_line_context(+) ='
            || ''''
            || 'ORDER ENTRY'
            || ''''
            || '
                           AND rctl.line_type(+) ='
            || ''''
            || 'LINE'
            || ''''
            || '
                           AND aps.customer_trx_id = rct.customer_trx_id
                           AND rctl.interface_line_attribute6(+) = ool.line_id
                           AND rctl.org_id(+) = ool.org_id
                           AND rctl_tax.line_type(+) = '
            || ''''
            || 'TAX'
            || ''''
            || '
                           AND rctl_tax.customer_trx_id(+) =
                                                          rctl.customer_trx_id
                           AND rctl_tax.link_to_cust_trx_line_id(+) =
                                                     rctl.customer_trx_line_id
                           AND rct.customer_trx_id(+) = rctl.customer_trx_id
                           AND rctt.cust_trx_type_id(+) = rct.cust_trx_type_id
                           AND rctt.org_id(+) = rct.org_id
                           AND hca.cust_account_id = ooh.sold_to_org_id
                           AND rta.receivables_trx_id(+) =
                                                   TO_NUMBER (rctt.attribute2)
                           AND rta.org_id(+) = rctt.org_id    
                           AND rct.org_id ='
            || p_org_id
            || lv_where
            || lv_where1
            || lv_where2
            || '
                      GROUP BY ooh.order_number,
                               ott.attribute13,
                               ool.header_id,
                               ool.line_id,
                               ool.attribute18,
                               ool.attribute20,
                               ool.attribute16,
                               ool.invoice_to_org_id,
                               aps.amount_due_original,
                               aps.amount_due_remaining,
                               rctl.customer_trx_id,
                               rct.trx_number,
                               ooh.cust_po_number,
                               ooh.ship_to_org_id,
                               hca.account_number,                           
                               rta.NAME,
                               rctt.NAME,
                               rctt.TYPE,
                                 (ool.ordered_quantity
                                  * ool.unit_selling_price
                                 )
                               + (NVL (DECODE (zxr.inclusive_tax_flag,'
            || ''''
            || 'Y'
            || ''''
            || ', 0,
                                               opa_tax.adjusted_amount
                                              ),
                                       0
                                      )
                                 ))a,
 (select trunc(payment_date) payment_date,sum(payment_amount)payment_amount,line_group_id,sum(unapplied_amount) unapplied_amount,header_id,
   LISTAGG(
       payment_type,'
            || ''''
            || ','
            || ''''
            || '
    ) WITHIN GROUP(
    ORDER BY
        payment_type
    ) payment_type
from 
xxdo.xxdoec_order_payment_details
where header_id=header_id
and line_group_id=line_group_id
and status = ''OP''  --v1.3 Added
group by trunc(payment_date),line_group_id,header_id) xopd
where xopd.header_id(+)=a.header_id
and xopd.line_group_id(+)=a.line_grp_id                                 
            GROUP BY order_number,
                     exchange_order_type,
                     a.header_id,
                     customer_number,
                     line_grp_id,
                     status_code,
                     ship_to_org_id,
                     pgc_trans_num,
                     xopd.payment_type,
                     xopd.payment_date,
                     customer_trx_id,
                     trx_number,
                     invoice_to_org_id,
                     cust_po_number,
                     amount_due_original,
                               amount_due_remaining,
                     NVL (xopd.unapplied_amount,xopd.payment_amount),          
                     xopd.payment_amount,
                     adj_activity_name,
                      ABS (amount_due_remaining)
                               - NVL (xopd.unapplied_amount,
                                      xopd.payment_amount
                                     ),
                     trx_type_name,
                     TYPE                     
                     )                     
     WHERE inv_diff<>0
       and inv_diff between -1 and 1
       and amount_due_remaining<>0)
UNION
    SELECT *
      FROM (SELECT '
            || ''''
            || 'INV'
            || ''''
            || ' inv_type,xopd.payment_type,xopd.payment_date, order_number,
                     cust_po_number, customer_number, invoice_to_org_id,
                     ship_to_org_id, exchange_order_type, a.header_id,
                     line_grp_id, status_code, pgc_trans_num, customer_trx_id,
                     trx_number,'
            || ''''
            || ''''
            || ' adj_activity_name,'
            || ''''
            || ''''
            || ' trx_type_name,'
            || ''''
            || ''''
            || ' TYPE, SUM (om_line_total) om_line_total,
                     SUM (inv_line_total) inv_line_total,xopd.payment_amount,amount_due_original,amount_due_remaining,
                     NVL (xopd.unapplied_amount,xopd.payment_amount) bal_amount,
                       ABS (amount_due_remaining)
                               - NVL (xopd.unapplied_amount,
                                      xopd.payment_amount
                                     ) diff,
                     SUM (om_line_total)-SUM (inv_line_total) inv_diff,'
            || ''''
            || ''''
            || 'adj_num ,'
            || ''''
            || ''''
            || 'adj_date ,'
            || ''''
            || 'N'
            || ''''
            || ','
            || ''''
            || ''''
            || ','
            || gn_conc_request_id
            || ','
            || gn_user_id
            || ','
            || ''''
            || SYSDATE
            || ''''
            || '
                FROM (SELECT   ool.header_id, ooh.order_number, ool.line_id,
                               ooh.cust_po_number,
                                ool.sold_to_org_id,
                               ooh.ship_to_org_id,
                               hca.account_number customer_number,
                               ool.invoice_to_org_id,
                               aps.amount_due_original,
                               aps.amount_due_remaining,    
                               ott.attribute13 exchange_order_type,
                               ool.attribute18 line_grp_id,
                               ool.attribute20 status_code,
                               ool.attribute16 pgc_trans_num,
                               rctl.customer_trx_id, rct.trx_number,
                                 (ool.ordered_quantity
                                  * ool.unit_selling_price
                                 )
                               + (NVL (DECODE (zxr.inclusive_tax_flag,'
            || ''''
            || 'Y'
            || ''''
            || ', 0,
                                               opa_tax.adjusted_amount
                                              ),
                                       0
                                      )
                                 ) om_line_total,
                               SUM
                                  (  rctl.extended_amount
                                   + NVL (rctl_tax.extended_amount, 0)
                                  ) inv_line_total
                          FROM oe_order_lines_all ool,
                               oe_price_adjustments opa_tax,
                               zx_rates_b zxr,
                               ra_customer_trx_all rct,
                               ra_customer_trx_lines_all rctl,
                               ra_customer_trx_lines_all rctl_tax,
                               oe_order_headers_all ooh,
                               oe_transaction_types_all ott,
                               hz_cust_accounts hca,
                               apps.ar_payment_schedules_all aps
                         WHERE 1 = 1
                           AND ool.line_category_code ='
            || ''''
            || 'ORDER'
            || ''''
            || '
                           AND opa_tax.line_id(+) = ool.line_id
                           AND opa_tax.list_line_type_code(+) = '
            || ''''
            || 'TAX'
            || ''''
            || '
                           AND zxr.tax_rate_id(+) = opa_tax.tax_rate_id
                           AND rctl.interface_line_context(+) = '
            || ''''
            || 'ORDER ENTRY'
            || ''''
            || '
                           AND rctl.interface_line_attribute6(+) = ool.line_id
                           AND rctl_tax.line_type(+) = '
            || ''''
            || 'TAX'
            || ''''
            || '
                           AND aps.customer_trx_id = rct.customer_trx_id
                           AND hca.cust_account_id = ooh.sold_to_org_id
                           AND rctl_tax.customer_trx_id(+) =
                                                          rctl.customer_trx_id
                           AND rctl_tax.link_to_cust_trx_line_id(+) =
                                                     rctl.customer_trx_line_id
                           --    AND ool.header_id = NVL (p_header_id, ool.header_id)
                           AND ooh.header_id = ool.header_id
                           AND ott.transaction_type_id = ooh.order_type_id
                           AND ott.attribute13 NOT IN ('
            || ''''
            || 'PP'
            || ''''
            || ','
            || ''''
            || 'PE'
            || ''''
            || ')
                           AND rct.customer_trx_id = rctl.customer_trx_id
                           AND rct.org_id ='
            || p_org_id
            || lv_where
            || lv_where1
            || lv_where2
            || '
                      GROUP BY ool.header_id,
                               ool.line_id,
                               ool.sold_to_org_id,
                               ool.invoice_to_org_id,
                               ool.attribute18,
                               ool.attribute20,
                               ool.attribute16,
                               ooh.ship_to_org_id,
                               rctl.customer_trx_id,
                               rct.trx_number,
                                aps.amount_due_remaining,    
                               aps.amount_due_original,  
                               hca.account_number,
                               ooh.cust_po_number,
                               ooh.order_number,
                               ott.attribute13,
                                 (ool.ordered_quantity
                                  * ool.unit_selling_price
                                 )
                               + (NVL (DECODE (zxr.inclusive_tax_flag,'
            || ''''
            || 'Y'
            || ''''
            || ', 0,
                                               opa_tax.adjusted_amount
                                              ),
                                       0
                                      )
                                 ))a,
                     (select trunc(payment_date) payment_date,sum(payment_amount)payment_amount,line_group_id,sum(unapplied_amount) unapplied_amount,header_id,
   LISTAGG(
       payment_type,'
            || ''''
            || ','
            || ''''
            || '
    ) WITHIN GROUP(
    ORDER BY
        payment_type
    ) payment_type
from 
xxdo.xxdoec_order_payment_details
where header_id=header_id
and line_group_id=line_group_id
and status = ''OP''  --v1.3 Added
group by trunc(payment_date),line_group_id,header_id) xopd
where xopd.header_id(+)=a.header_id --v1.1
and xopd.line_group_id(+)=a.line_grp_id --v1.1
            GROUP BY            
            a.header_id,                             
                     sold_to_org_id,
                     invoice_to_org_id,
                     line_grp_id,
                     xopd.payment_date,
                     status_code,
                     ship_to_org_id,
                     pgc_trans_num,
                     customer_trx_id,
                     customer_number,
                     cust_po_number,
                     amount_due_original,
                               amount_due_remaining,
                     exchange_order_type,                        
                     trx_number,
                     xopd.payment_type,
                    NVL (xopd.unapplied_amount,xopd.payment_amount) ,
                     order_number,
                     payment_amount
                     )
     WHERE  inv_diff<>0
       and inv_diff between -1 and 1
       and amount_due_remaining<>0';
        msg (lv_sql_stamtment);

        EXECUTE IMMEDIATE lv_sql_stamtment;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_msg   := SQLERRM;
            msg ('Exception in insert_data: ' || lv_msg);
    END insert_data;

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
    EXCEPTION
        WHEN OTHERS
        THEN
            x_receipt_method_id   := NULL;
    END get_receipt_method;

    PROCEDURE create_inv_adju_transaction
    AS
        CURSOR c_order_lines IS
            SELECT *
              FROM xxdo.xxd_ar_create_adjustments_stg
             WHERE     inv_type = 'INV'
                   AND status = 'N'
                   AND request_id = gn_conc_request_id;

        CURSOR c_frt_charges (c_header_id     IN NUMBER,
                              c_line_grp_id   IN VARCHAR2)
        IS
            SELECT SUM (opa.adjusted_amount) om_frt_amount, SUM (rctl_frt.extended_amount + NVL (rctl_frt_tax.extended_amount, 0)) inv_frt_total
              FROM oe_order_lines_all ool, oe_price_adjustments opa, ra_customer_trx_lines_all rctl_frt,
                   ra_customer_trx_lines_all rctl_frt_tax
             WHERE     1 = 1
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

        CURSOR c_inv_balance (c_inv_trx_id IN NUMBER)
        IS
            SELECT SUM (ABS (amount_due_remaining))
              FROM apps.ar_payment_schedules_all aps
             WHERE customer_trx_id = c_inv_trx_id;

        CURSOR c_inv_bal (c_inv_trx_id IN NUMBER)
        IS
            SELECT ABS (SUM (aps.amount_due_remaining)), ABS (SUM (aps.amount_line_items_remaining)) + ABS (SUM (aps.tax_remaining))
              FROM ar_payment_schedules_all aps
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

        l_om_frt_total           NUMBER;
        l_inv_frt_total          NUMBER;
        l_rtn_status             VARCHAR2 (5);
        l_receipt_method_id      NUMBER;
        l_bank_account_id        NUMBER;
        l_bank_branch_id         NUMBER;
        l_adj_activity           VARCHAR2 (2000);
        l_pmt_status             VARCHAR2 (20);
        l_apply_amt              NUMBER;
        l_adj_id                 NUMBER;
        l_adj_number             NUMBER;
        l_err_msg                VARCHAR2 (2000);
        l_error_msg              VARCHAR2 (2000);
        l_inv_new_balance        NUMBER;
        l_inv_new_line_balance   NUMBER;
        l_batch_id               NUMBER;
        l_batch_name             VARCHAR2 (2000);
        l_receipt_number         NUMBER;
        l_cash_receipt_id        NUMBER;
        l_inv_balance            NUMBER;
        cb_params_rec            c_cb_params%ROWTYPE;
        lv_reason_code           VARCHAR2 (100);
        ln_adj_status            VARCHAR2 (3);
        --Start changes v1.1
        ld_gl_date               DATE := TRUNC (SYSDATE);
        ld_next_period_dt        DATE := TRUNC (SYSDATE);
        ld_batch_date            DATE := TRUNC (SYSDATE);
        --End changes v1.1
        ln_adj_amount            NUMBER;
    BEGIN
        SELECT ffv.flex_value
          INTO lv_reason_code
          FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv, fnd_flex_values_tl ffvt
         WHERE     ffvs.flex_value_set_id = ffv.flex_value_set_id
               AND ffv.flex_value_id = ffvt.flex_value_id
               AND ffvt.LANGUAGE = USERENV ('LANG')
               AND flex_value_set_name = 'XXD_AR_AJUST_REASON_CODE';

        FOR c_ccr IN c_order_lines
        LOOP
            BEGIN
                l_om_frt_total    := 0;
                l_inv_frt_total   := 0;

                OPEN c_frt_charges (c_ccr.header_id, c_ccr.line_grp_id);

                FETCH c_frt_charges INTO l_om_frt_total, l_inv_frt_total;

                CLOSE c_frt_charges;

                l_inv_frt_total   := NVL (l_inv_frt_total, l_om_frt_total);

                IF l_inv_frt_total > l_om_frt_total
                THEN
                    l_inv_frt_total   := l_om_frt_total;
                END IF;

                IF (c_ccr.om_line_total + NVL (l_om_frt_total, 0)) = 0
                THEN
                    UPDATE xxdo.xxd_ar_create_adjustments_stg
                       SET status = 'E', error_message = 'Some of the Order Lines are not invoiced yet'
                     WHERE     trx_number = c_ccr.trx_number
                           AND customer_trx_id = c_ccr.customer_trx_id
                           AND request_id = gn_conc_request_id;

                    COMMIT;
                ELSE
                    l_rtn_status   := fnd_api.g_ret_sts_success;

                    OPEN c_inv_balance (c_ccr.customer_trx_id);

                    FETCH c_inv_balance INTO l_inv_balance;

                    CLOSE c_inv_balance;

                    IF l_inv_balance > 0
                    THEN
                        cb_params_rec   := NULL;

                        -- create Receipt Batch
                        OPEN c_cb_params (c_ccr.header_id);

                        FETCH c_cb_params INTO cb_params_rec;

                        CLOSE c_cb_params;

                        --
                        get_receipt_method (cb_params_rec.ar_receipt_class_id, REGEXP_SUBSTR (c_ccr.payment_type, '[^,]+'), --c_ccr.payment_type,     --Need to update
                                                                                                                            cb_params_rec.website_id, cb_params_rec.transactional_curr_code, l_receipt_method_id, l_bank_account_id
                                            , l_bank_branch_id);

                        -- Added New
                        IF l_receipt_method_id IS NOT NULL
                        THEN
                            BEGIN
                                SELECT NAME
                                  INTO l_adj_activity
                                  FROM ar_receivables_trx_all
                                 WHERE     attribute4 =
                                           TO_CHAR (l_receipt_method_id)
                                       AND SYSDATE BETWEEN NVL (
                                                               start_date_active,
                                                               SYSDATE)
                                                       AND NVL (
                                                               end_date_active,
                                                               SYSDATE)
                                       AND TYPE = 'ADJUST';
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_adj_activity   := NULL;
                            END;
                        END IF;

                        -- End of Change

                        --Start changes v1.1
                        BEGIN
                            IF check_exchange_type (
                                   NVL (c_ccr.exchange_order_type, '~'))
                            THEN
                                SELECT fvv.attribute2
                                  INTO l_adj_activity
                                  FROM fnd_flex_value_sets fvs, fnd_flex_values_vl fvv
                                 WHERE     fvs.flex_value_set_id =
                                           fvv.flex_value_set_id
                                       AND fvs.flex_value_set_name =
                                           'XXDO_VALUES_TAX_ROUNDING_REC'
                                       AND fvv.enabled_flag = 'Y'
                                       AND fvv.attribute1 =
                                           (SELECT name
                                              FROM hr_operating_units
                                             WHERE organization_id = p_org_id)
                                       AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                       fvv.start_date_active,
                                                                         SYSDATE
                                                                       - 1)
                                                               AND NVL (
                                                                       fvv.end_date_active,
                                                                         SYSDATE
                                                                       + 1);
                            END IF;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_adj_activity   := NULL;
                                msg (
                                       'Error occured for header '
                                    || c_ccr.header_id
                                    || ' while deriving the Activity for exchange order',
                                    100);
                        END;

                        BEGIN
                            SELECT aps.gl_date
                              INTO ld_gl_date
                              FROM ar_payment_schedules_all aps
                             WHERE     aps.customer_trx_id =
                                       c_ccr.customer_trx_id
                                   AND ROWNUM = 1;

                            SELECT MIN (start_date)
                              INTO ld_next_period_dt
                              FROM gl_period_statuses gps
                             WHERE     set_of_books_id =
                                       (SELECT set_of_books_id
                                          FROM ra_customer_trx_all rct
                                         WHERE rct.customer_trx_id =
                                               c_ccr.customer_trx_id)
                                   AND closing_Status = 'O'
                                   AND application_id = 222;

                            IF ld_gl_date < ld_next_period_dt
                            THEN
                                ld_batch_date   := ld_next_period_dt;
                            ELSE
                                ld_batch_date   := ld_gl_date;
                            END IF;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ld_batch_date   := TRUNC (SYSDATE);
                                msg (
                                       'Error occured for invoice: '
                                    || c_ccr.trx_number
                                    || ' while fetching the batch date',
                                    100);
                        END;

                        --End changes v1.1

                        IF l_adj_activity IS NULL
                        THEN
                            msg (
                                   'Unable to find the adjustment activity for receipt method id '
                                || c_ccr.payment_type,        --Need to update
                                100);
                            l_pmt_status   := fnd_api.g_ret_sts_error;
                        ELSE
                            -- Begin Changes v1.3
                            ln_adj_amount   := 0;

                            BEGIN
                                SELECT SUM (amount)
                                  INTO ln_adj_amount
                                  FROM ar_adjustments_all
                                 WHERE     customer_trx_id =
                                           c_ccr.customer_trx_id
                                       AND TYPE = 'TAX'
                                       AND reason_code = lv_reason_code;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    ln_adj_amount   := 0;
                            END;

                            msg ('Adjustment Amount' || ln_adj_amount, 100);
                            -- End Changes v1.3
                            -- First create adjsutment to make sure payment amount and invoice balance are same
                            l_apply_amt     :=
                                  c_ccr.om_line_total
                                - NVL (c_ccr.inv_line_total, 0);
                            msg (
                                   'Amount used for Adjustment is  '
                                || l_apply_amt,
                                --c_opd.payment_type,
                                100);

                            IF l_apply_amt BETWEEN -1 AND 1
                            THEN
                                IF NVL (ln_adj_amount, 0) = 0      -- Add v1.3
                                THEN                               -- Add v1.3
                                    mo_global.init ('AR');
                                    mo_global.set_policy_context ('S',
                                                                  p_org_id);
                                    do_ar_utils.create_adjustment_trans (
                                        p_customer_trx_id   =>
                                            c_ccr.customer_trx_id,
                                        p_activity_name   => l_adj_activity,
                                        p_type            => 'TAX', --'INVOICE',
                                        p_amount          => l_apply_amt * 1,
                                        p_reason_code     => lv_reason_code,
                                        p_gl_date         => ld_batch_date, --SYSDATE,  --v1.1
                                        p_adj_date        => ld_batch_date, --SYSDATE,  --v1.1
                                        p_comments        =>
                                               'Invoice# '
                                            || c_ccr.trx_number
                                            || ' is adjusted to match Payment Amount ',
                                        p_auto_commit     => 'N',
                                        x_adj_id          => l_adj_id,
                                        x_adj_number      => l_adj_number,
                                        x_error_msg       => l_err_msg);
                                END IF;                            -- Add v1.3

                                IF l_err_msg IS NOT NULL
                                THEN
                                    l_pmt_status   := fnd_api.g_ret_sts_error;
                                    l_rtn_status   := fnd_api.g_ret_sts_error;

                                    UPDATE xxdo.xxd_ar_create_adjustments_stg
                                       SET status = 'E', error_message = 'Unable to create Adjustment for Invoice' || l_err_msg --v1.2
                                     WHERE     trx_number = c_ccr.trx_number
                                           AND customer_trx_id =
                                               c_ccr.customer_trx_id
                                           AND request_id =
                                               gn_conc_request_id;
                                END IF;

                                -- After adj. is succesful the create receipt batch and transaction with Invoice balance now
                                IF l_rtn_status = fnd_api.g_ret_sts_success
                                THEN
                                    OPEN c_inv_bal (c_ccr.customer_trx_id);

                                    FETCH c_inv_bal INTO l_inv_new_balance, l_inv_new_line_balance;

                                    CLOSE c_inv_bal;

                                    OPEN c_inv_balance (
                                        c_ccr.customer_trx_id);

                                    CLOSE c_inv_balance;

                                    BEGIN
                                        SELECT status
                                          INTO ln_adj_status
                                          FROM ar_adjustments_all
                                         WHERE adjustment_number =
                                               l_adj_number;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            ln_adj_status   := 'E';
                                    END;

                                    IF       c_ccr.om_line_total
                                           - c_ccr.inv_line_total
                                           - l_apply_amt =
                                           0
                                       AND ln_adj_status = 'A'
                                    THEN
                                        -- for freight, doesn't come under line_total, so inv_balance is included of freight total
                                        -- so matching OM line total with Inv line total instead of Inv balance
                                        --Start changes v1.1
                                        --l_apply_amt := l_inv_new_balance;
                                        l_apply_amt   :=
                                            LEAST (NVL (c_ccr.bal_amount, 0),
                                                   l_inv_new_balance);

                                        IF l_apply_amt <> 0
                                        THEN
                                            ld_batch_date   :=
                                                NVL (c_ccr.payment_date,
                                                     TRUNC (SYSDATE));

                                            IF ld_batch_date <
                                               ld_next_period_dt
                                            THEN
                                                ld_batch_date   :=
                                                    ld_next_period_dt;
                                            END IF;

                                            --End changes v1.1
                                            -- Create Receipt Batch
                                            do_ar_utils.create_receipt_batch_trans (
                                                p_company         =>
                                                    cb_params_rec.company_name,
                                                p_batch_source_id   =>
                                                    cb_params_rec.ar_batch_source_id,
                                                p_bank_branch_id   =>
                                                    NVL (
                                                        l_bank_branch_id,
                                                        cb_params_rec.ar_bank_branch_id),
                                                p_batch_type      =>
                                                    cb_params_rec.ar_batch_type,
                                                p_currency_code   =>
                                                    cb_params_rec.transactional_curr_code,
                                                p_bank_account_id   =>
                                                    NVL (
                                                        l_bank_account_id,
                                                        cb_params_rec.ar_bank_account_id),
                                                p_batch_date      =>
                                                    ld_batch_date, --SYSDATE,   --v1.1
                                                --c_opd.payment_date,
                                                p_receipt_class_id   =>
                                                    cb_params_rec.ar_receipt_class_id,
                                                p_control_count   => 1,
                                                p_gl_date         =>
                                                    ld_batch_date, --SYSDATE,   --v1.1
                                                -- Modified from c_opd.payment_dat to sysdate
                                                p_receipt_method_id   =>
                                                    NVL (
                                                        l_receipt_method_id,
                                                        cb_params_rec.ar_receipt_method_id),
                                                p_control_amount   =>
                                                    l_apply_amt, --l_inv_new_balance, --v1.1
                                                --Invoice amount is adjusted to match the payment amount
                                                p_deposit_date    =>
                                                    ld_batch_date, --SYSDATE,   --v1.1
                                                --c_opd.payment_date,
                                                p_comments        =>
                                                       'Order# '
                                                    || cb_params_rec.order_number
                                                    || 'Line Grp ID: '
                                                    || c_ccr.line_grp_id,
                                                p_auto_commit     => 'N',
                                                x_batch_id        =>
                                                    l_batch_id,
                                                x_batch_name      =>
                                                    l_batch_name,
                                                x_error_msg       =>
                                                    l_error_msg);

                                            -- COMMIT;  --v1.3 Commented

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
                                                    p_receipt_amt     =>
                                                        l_apply_amt, --l_inv_new_balance, --v1.1
                                                    -- Should be payment amount
                                                    p_transaction_num   =>
                                                        c_ccr.trx_number,
                                                    --c_opd.pg_reference_num,
                                                    --       p_payment_server_order_num   => c_opd.pg_reference_num,
                                                    p_customer_number   =>
                                                        cb_params_rec.customer_number,
                                                    p_customer_name   => NULL,
                                                    p_comments        =>
                                                           'Order# '
                                                        || cb_params_rec.order_number
                                                        || 'Line Grp ID: '
                                                        || c_ccr.line_grp_id,
                                                    --     || 'PG Ref: '
                                                    --     || c_opd.pg_reference_num,
                                                    p_currency_code   =>
                                                        cb_params_rec.transactional_curr_code,
                                                    p_location        => NULL,
                                                    p_auto_commit     => 'N',
                                                    x_cash_receipt_id   =>
                                                        l_cash_receipt_id,
                                                    x_error_msg       =>
                                                        l_error_msg);

                                                -- COMMIT; --v1.3 Commented

                                                IF NVL (l_cash_receipt_id,
                                                        -200) =
                                                   -200
                                                THEN
                                                    msg (
                                                           'Unable to create Cash Receipt for the amount '
                                                        || l_inv_new_balance,
                                                        100);
                                                    msg (
                                                           'Error Message: '
                                                        || l_error_msg,
                                                        100);
                                                    l_pmt_status   :=
                                                        fnd_api.g_ret_sts_error;

                                                    UPDATE xxdo.xxd_ar_create_adjustments_stg
                                                       SET status = 'E', error_message = 'Unable to create Cash Receipt ' || l_error_msg
                                                     WHERE     trx_number =
                                                               c_ccr.trx_number
                                                           AND customer_trx_id =
                                                               c_ccr.customer_trx_id
                                                           AND request_id =
                                                               gn_conc_request_id;
                                                ELSE
                                                    msg (
                                                           'Successfully created Cash Receipt for the amount '
                                                        || l_inv_new_balance,
                                                        100);
                                                    msg (
                                                           'Cash Receipt ID: '
                                                        || l_cash_receipt_id,
                                                        100);

                                                    UPDATE ar_cash_receipts_all
                                                       -- Added by Madhav for ENHC0011797
                                                       SET attribute14 = 'DISCOVER'
                                                     ---Need to update
                                                     --  Added by Madhav for ENHC0011797
                                                     WHERE cash_receipt_id =
                                                           l_cash_receipt_id;

                                                    --Added by Madhav for ENHC0011797
                                                    l_error_msg   := NULL;
                                                    -- Apply cash to Invoice
                                                    do_ar_utils.apply_transaction_trans (
                                                        p_cash_receipt_id   =>
                                                            l_cash_receipt_id,
                                                        p_customer_trx_id   =>
                                                            c_ccr.customer_trx_id,
                                                        p_trx_number    => NULL,
                                                        p_applied_amt   =>
                                                            l_apply_amt, --l_inv_new_balance, --v1.1
                                                        --l_apply_amt, -- apply here the Invoice amount
                                                        p_discount      => NULL,
                                                        p_auto_commit   => 'N',
                                                        x_error_msg     =>
                                                            l_error_msg);

                                                    -- COMMIT;  --v1.3 Commented

                                                    IF l_error_msg IS NULL
                                                    THEN
                                                        msg (
                                                               'Successfully Applied Amount: '
                                                            || l_inv_balance
                                                            || 'to Invoice ID: '
                                                            || c_ccr.customer_trx_id,
                                                            100);
                                                        l_pmt_status   :=
                                                            fnd_api.g_ret_sts_success;

                                                        --Start Changes v1.3
                                                        UPDATE xxdoec_order_payment_details
                                                           SET unapplied_amount = c_ccr.bal_amount - l_apply_amt, status = DECODE (SIGN (c_ccr.bal_amount - l_apply_amt), 0, 'CL', 'OP')
                                                         WHERE     header_id =
                                                                   c_ccr.header_id
                                                               AND line_group_id =
                                                                   c_ccr.line_grp_id;

                                                        --End Changes v1.3

                                                        UPDATE xxdo.xxd_ar_create_adjustments_stg
                                                           SET status = 'S', adjustment_number = l_adj_number, adjusted_date = SYSDATE
                                                         WHERE     trx_number =
                                                                   c_ccr.trx_number
                                                               AND customer_trx_id =
                                                                   c_ccr.customer_trx_id
                                                               AND request_id =
                                                                   gn_conc_request_id;

                                                        COMMIT;
                                                    ELSE
                                                        ROLLBACK; --v1.3 Added
                                                        l_pmt_status   :=
                                                            fnd_api.g_ret_sts_error;

                                                        UPDATE xxdo.xxd_ar_create_adjustments_stg
                                                           SET status = 'E', error_message = l_error_msg --v1.2
                                                         WHERE     trx_number =
                                                                   c_ccr.trx_number
                                                               AND customer_trx_id =
                                                                   c_ccr.customer_trx_id
                                                               AND request_id =
                                                                   gn_conc_request_id;

                                                        COMMIT;
                                                    END IF; -- Cash Receipt App success
                                                END IF; -- Cash Receipt success
                                            ELSE
                                                ROLLBACK;         --v1.3 Added
                                                msg (
                                                    'Unable to create Cash Receipt Batch ',
                                                    100);
                                                msg (
                                                       'Error Message: '
                                                    || l_error_msg,
                                                    100);
                                                l_pmt_status   :=
                                                    fnd_api.g_ret_sts_error;

                                                UPDATE xxdo.xxd_ar_create_adjustments_stg
                                                   SET status = 'E', error_message = l_error_msg --v1.2
                                                 WHERE     trx_number =
                                                           c_ccr.trx_number
                                                       AND customer_trx_id =
                                                           c_ccr.customer_trx_id
                                                       AND request_id =
                                                           gn_conc_request_id;

                                                COMMIT;
                                            END IF;   -- Receipt Batch success
                                        --Start changes v1.1
                                        ELSE
                                            UPDATE xxdo.xxd_ar_create_adjustments_stg
                                               SET status = 'S', adjustment_number = l_adj_number, adjusted_date = SYSDATE
                                             WHERE     trx_number =
                                                       c_ccr.trx_number
                                                   AND customer_trx_id =
                                                       c_ccr.customer_trx_id
                                                   AND request_id =
                                                       gn_conc_request_id;

                                            COMMIT;
                                        END IF; --End l_apply_amt <> 0 condition
                                    --End changes v1.1
                                    ELSE
                                        ROLLBACK;                 --v1.3 Added

                                        UPDATE xxdo.xxd_ar_create_adjustments_stg
                                           SET status = 'E', error_message = 'After Adjustment, Invoice balance and OM total are not matching, please check if this has been already adjusted'
                                         WHERE     trx_number =
                                                   c_ccr.trx_number
                                               AND customer_trx_id =
                                                   c_ccr.customer_trx_id
                                               AND request_id =
                                                   gn_conc_request_id;

                                        COMMIT;
                                    END IF;
                                END IF;
                            END IF;                     -- cb_params_rec found

                            --
                            IF l_pmt_status = fnd_api.g_ret_sts_success
                            THEN
                                --  msg('c_opd.payment_id ' ||c_opd.payment_id );
                                OPEN c_inv_bal (c_ccr.customer_trx_id);

                                FETCH c_inv_bal INTO l_inv_new_balance, l_inv_new_line_balance;

                                CLOSE c_inv_bal;

                                IF l_inv_new_balance = 0
                                THEN
                                    UPDATE oe_order_lines_all ool
                                       SET ool.attribute20 = 'CCR', ool.attribute19 = 'APPLIED', ool.attribute17 = fnd_api.g_ret_sts_success
                                     WHERE     ool.attribute20 =
                                               c_ccr.status_code
                                           AND ool.header_id =
                                               c_ccr.header_id
                                           AND ool.attribute18 =
                                               c_ccr.line_grp_id
                                           AND EXISTS
                                                   (SELECT 1
                                                      FROM ra_customer_trx_lines_all rctl
                                                     WHERE     rctl.customer_trx_id =
                                                               c_ccr.customer_trx_id
                                                           AND rctl.interface_line_context =
                                                               'ORDER ENTRY'
                                                           AND rctl.interface_line_attribute6 =
                                                               TO_CHAR (
                                                                   ool.line_id));

                                    /*Begin Changes v1.3
                                                               UPDATE xxdoec_order_payment_details
                                             --Start changes v1.1
                                                                --SET unapplied_amount = 0,
                                                                  SET unapplied_amount = c_ccr.bal_amount - l_apply_amt,
                                             --End changes v1.1
                                                                      status =
                                                                         DECODE (SIGN (  c_ccr.bal_amount --c_ccr.payment_amount --v1.1
                                                                                       - l_apply_amt
                                                                                      ),
                                                                                 0, 'CL',
                                                                                 'OP'
                                                                                )
                                                                WHERE header_id = c_ccr.header_id
                                                                  AND line_group_id = c_ccr.line_grp_id;
                                    End Changes v1.3 */

                                    COMMIT;
                                ELSE
                                    -- x_retcode := 1;
                                    ROLLBACK;
                                END IF;
                            END IF;
                        END IF;
                    ELSE
                        ROLLBACK;                                 --v1.3 Added

                        UPDATE xxdo.xxd_ar_create_adjustments_stg
                           SET status = 'E', error_message = ' Invoice balance is already Zero, No need of any adjsutments'
                         WHERE     trx_number = c_ccr.trx_number
                               AND customer_trx_id = c_ccr.customer_trx_id;

                        COMMIT;
                    END IF;                       -- invoice balance > 0 check
                END IF;                             -- Order lines Total match
            EXCEPTION
                WHEN OTHERS
                THEN
                    --   x_retcode := 1;
                    l_err_msg   :=
                           'Unexpected Error occured while processing Order Header ID: '
                        || c_ccr.header_id
                        || 'Lines Group ID: '
                        || c_ccr.line_grp_id;
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_err_msg   := SQLERRM;
            msg ('Exception in create_inv_adju_transaction:' || l_err_msg);
    END create_inv_adju_transaction;

    PROCEDURE create_cm_adju_transaction
    AS
        CURSOR c_order_lines IS
            SELECT *
              FROM xxdo.xxd_ar_create_adjustments_stg
             WHERE     inv_type = 'CM'
                   AND status = 'N'
                   AND request_id = gn_conc_request_id;

        CURSOR c_cm_balance (c_cm_trx_id IN NUMBER)
        IS
            SELECT ABS (SUM (aps.amount_due_remaining)) cm_balance, ABS (SUM (aps.amount_line_items_remaining)) cm_line_balance, ABS (SUM (aps.tax_remaining)) cm_tax_balance
              FROM ar_payment_schedules_all aps
             WHERE customer_trx_id = c_cm_trx_id;

        --Start changes v1.1
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

        l_apply_amt         NUMBER;
        l_app_status        VARCHAR2 (1);
        l_rec_appl_id       NUMBER;
        ld_gl_date          DATE := TRUNC (SYSDATE);
        ld_next_period_dt   DATE := TRUNC (SYSDATE);
        ld_batch_date       DATE := TRUNC (SYSDATE);
        --End changes v1.1

        l_cm_balance        NUMBER;
        l_cm_line_balance   NUMBER;
        l_cm_tax_balance    NUMBER;
        l_adj_id            NUMBER;
        l_adj_number        NUMBER;
        l_err_msg           VARCHAR2 (2000);
        ln_var_amount       NUMBER;
        lv_activity         VARCHAR2 (2000);
        lv_adj_activity     VARCHAR2 (2000);
        lv_var_amount       NUMBER;
        l_adj_status        VARCHAR2 (200);
        p_gl_adj_date       DATE := TRUNC (SYSDATE);
        lv_reason_code      VARCHAR2 (100);
        ln_adj_amount       NUMBER;
    BEGIN
        SELECT ffv.flex_value
          INTO lv_reason_code
          FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv, fnd_flex_values_tl ffvt
         WHERE     ffvs.flex_value_set_id = ffv.flex_value_set_id
               AND ffv.flex_value_id = ffvt.flex_value_id
               AND ffvt.LANGUAGE = USERENV ('LANG')
               AND flex_value_set_name = 'XXD_AR_AJUST_REASON_CODE';

        FOR c_cma IN c_order_lines
        LOOP
            BEGIN
                msg (
                       'Header ID: '
                    || c_cma.header_id
                    || ' Lines Group ID: '
                    || c_cma.line_grp_id
                    || ' Customer TRX ID: '
                    || c_cma.customer_trx_id
                    || ' Exchange Order Type: '
                    || c_cma.exchange_order_type,
                    100);
                msg (
                       'Order Lines Total: '
                    || c_cma.om_line_total
                    || ' CM Lines Total: '
                    || c_cma.inv_line_total,
                    100);

                --Start changes v1.1
                BEGIN
                    SELECT aps.gl_date
                      INTO ld_gl_date
                      FROM ar_payment_schedules_all aps
                     WHERE     aps.customer_trx_id = c_cma.customer_trx_id
                           AND ROWNUM = 1;

                    SELECT MIN (start_date)
                      INTO ld_next_period_dt
                      FROM gl_period_statuses gps
                     WHERE     set_of_books_id =
                               (SELECT set_of_books_id
                                  FROM ra_customer_trx_all rct
                                 WHERE rct.customer_trx_id =
                                       c_cma.customer_trx_id)
                           AND closing_Status = 'O'
                           AND application_id = 222;

                    IF ld_gl_date < ld_next_period_dt
                    THEN
                        ld_batch_date   := ld_next_period_dt;
                    ELSE
                        ld_batch_date   := ld_gl_date;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ld_batch_date   := TRUNC (SYSDATE);
                        msg (
                               'Error occured for CM: '
                            || c_cma.trx_number
                            || ' while fetching the batch date',
                            100);
                END;

                IF check_exchange_type (NVL (c_cma.exchange_order_type, '~'))
                THEN
                    BEGIN
                        SELECT fvv.attribute2
                          INTO lv_adj_activity
                          FROM fnd_flex_value_sets fvs, fnd_flex_values_vl fvv
                         WHERE     fvs.flex_value_set_id =
                                   fvv.flex_value_set_id
                               AND fvs.flex_value_set_name =
                                   'XXDO_VALUES_TAX_ROUNDING_REC'
                               AND fvv.enabled_flag = 'Y'
                               AND fvv.attribute1 =
                                   (SELECT name
                                      FROM hr_operating_units
                                     WHERE organization_id = p_org_id)
                               AND TRUNC (SYSDATE) BETWEEN NVL (
                                                               fvv.start_date_active,
                                                               SYSDATE - 1)
                                                       AND NVL (
                                                               fvv.end_date_active,
                                                               SYSDATE + 1);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_adj_activity   := NULL;
                            msg (
                                   'Error occured for header '
                                || c_cma.header_id
                                || ' while deriving the Activity for exchange order',
                                100);
                    END;
                ELSE
                    --End changes v1.1

                    BEGIN                                           --modified
                        lv_adj_activity   := NULL;

                        SELECT DISTINCT art.NAME
                          INTO lv_adj_activity
                          FROM ar_cash_receipts_all acra, apps.ar_receivables_trx_all art, apps.ar_receivable_applications_all araa,
                               ra_customer_trx_all rta
                         WHERE     1 = 1    --acra.CASH_RECEIPT_ID = '3523350'
                               AND acra.receipt_method_id = art.attribute4
                               AND araa.cash_receipt_id =
                                   acra.cash_receipt_id
                               AND rta.org_id = p_org_id
                               AND rta.interface_header_attribute1 IN
                                       (SELECT DISTINCT
                                               TO_CHAR (oha.order_number)
                                          FROM apps.oe_order_lines_all oola, oe_order_headers_all oha
                                         WHERE     oola.header_id =
                                                   c_cma.header_id
                                               AND oha.header_id =
                                                   oola.reference_header_id)
                               AND applied_customer_trx_id =
                                   rta.customer_trx_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            BEGIN
                                SELECT art.NAME
                                  INTO lv_activity
                                  FROM apps.xxdoec_country_brand_params cbp, oe_order_headers_all ooh, hz_cust_accounts hca,
                                       hr_operating_units hou, ar_receivables_trx_all art
                                 WHERE     ooh.header_id = c_cma.header_id
                                       AND hca.cust_account_id =
                                           ooh.sold_to_org_id
                                       AND hou.organization_id =
                                           ooh.sold_from_org_id
                                       AND cbp.website_id = hca.attribute18
                                       AND art.attribute4 =
                                           TO_CHAR (ar_receipt_method_id)
                                       AND SYSDATE BETWEEN NVL (
                                                               start_date_active,
                                                               SYSDATE)
                                                       AND NVL (
                                                               end_date_active,
                                                               SYSDATE);

                                lv_adj_activity   := lv_activity;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    msg (
                                           'Still Exception occured for header '
                                        || c_cma.header_id
                                        || ' while deriving the Activity ',
                                        100);
                            END;
                    END;
                END IF;                                                 --v1.1

                OPEN c_cm_balance (c_cma.customer_trx_id);

                FETCH c_cm_balance INTO l_cm_balance, l_cm_line_balance, l_cm_tax_balance;

                CLOSE c_cm_balance;

                IF l_cm_balance <> 0
                THEN
                    --
                    IF lv_adj_activity IS NOT NULL                  --modified
                    THEN
                        --                IF ABS (c_cma.om_line_total - NVL (c_cma.cm_line_total, 0)) >=
                        --                   lv_var_amount
                        IF ABS (
                                 c_cma.om_line_total
                               - NVL (c_cma.inv_line_total, 0)) =
                           0
                        THEN
                            msg ('Run the Regular Program...', 100);
                        ELSE
                            lv_var_amount   :=
                                  ABS (c_cma.om_line_total)
                                - ABS (NVL (c_cma.inv_line_total, 0));

                            OPEN c_cm_balance (c_cma.customer_trx_id);

                            FETCH c_cm_balance INTO l_cm_balance, l_cm_line_balance, l_cm_tax_balance;

                            CLOSE c_cm_balance;

                            -- Begin Changes v1.3
                            ln_adj_amount   := 0;

                            BEGIN
                                SELECT SUM (amount)
                                  INTO ln_adj_amount
                                  FROM ar_adjustments_all
                                 WHERE     customer_trx_id =
                                           c_cma.customer_trx_id
                                       AND TYPE = 'LINE'
                                       AND reason_code = lv_reason_code;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    ln_adj_amount   := 0;
                            END;

                            IF NVL (ln_adj_amount, 0) = 0
                            THEN
                                -- End Changes v1.3
                                mo_global.init ('AR');
                                mo_global.set_policy_context ('S', p_org_id);
                                -- Create Adjustment
                                do_ar_utils.create_adjustment_trans (
                                    p_customer_trx_id   =>
                                        c_cma.customer_trx_id,
                                    -- p_activity_name     => 'EU-UGG-eCommerce Sales',
                                    p_activity_name   => lv_adj_activity,
                                    p_type            => 'LINE', --'TAX',  --v1.2
                                    p_amount          => -1 * lv_var_amount,
                                    p_reason_code     => lv_reason_code,
                                    p_gl_date         => ld_batch_date, --p_gl_adj_date,  --v1.1,
                                    p_adj_date        => ld_batch_date, --p_gl_adj_date,  --v1.1,
                                    p_comments        =>
                                        'Transaction# ' || c_cma.trx_number,
                                    p_auto_commit     => 'N',
                                    x_adj_id          => l_adj_id,
                                    x_adj_number      => l_adj_number,
                                    x_error_msg       => l_err_msg);
                            -- COMMIT;  --v1.3 Commented
                            -- Begin Changes v1.3
                            ELSE
                                l_err_msg   :=
                                    'Adjustment has already been Created';
                            END IF;

                            -- End Changes v1.3
                            IF l_err_msg IS NOT NULL
                            THEN
                                ROLLBACK;                         --v1.3 Added
                                l_adj_status   := fnd_api.g_ret_sts_error;

                                UPDATE xxdo.xxd_ar_create_adjustments_stg
                                   SET status = 'E', error_message = l_err_msg
                                 WHERE     trx_number = c_cma.trx_number
                                       AND customer_trx_id =
                                           c_cma.customer_trx_id
                                       AND request_id = gn_conc_request_id;

                                COMMIT;
                            ELSE
                                COMMIT;                           --v1.3 Added
                                l_adj_status   := fnd_api.g_ret_sts_success;
                                msg (
                                       'Successfully created Adjustment#: '
                                    || l_adj_number
                                    || ' for TRX Number at Tax level #: '
                                    || c_cma.trx_number
                                    || ' for Amount:'
                                    || lv_var_amount,
                                    100);

                                --                END IF;
                                OPEN c_cm_balance (c_cma.customer_trx_id);

                                FETCH c_cm_balance INTO l_cm_balance, l_cm_line_balance, l_cm_tax_balance;

                                CLOSE c_cm_balance;

                                IF ABS (
                                         c_cma.om_line_total
                                       - NVL (l_cm_balance, 0)) =
                                   0
                                THEN
                                    --Start changes v1.1
                                    --Apply the CM to Invoice in case of exchanges
                                    BEGIN
                                        IF check_exchange_type (
                                               NVL (
                                                   c_cma.exchange_order_type,
                                                   '~'))
                                        THEN
                                            -- apply CM to invoice(s) of the same order
                                            FOR c_inv
                                                IN c_order_invoice (
                                                       c_cma.order_number)
                                            LOOP
                                                l_apply_amt   :=
                                                    LEAST (l_cm_balance,
                                                           c_inv.inv_balance);

                                                BEGIN
                                                    SELECT aps.gl_date
                                                      INTO ld_gl_date
                                                      FROM ar_payment_schedules_all aps
                                                     WHERE     aps.customer_trx_id =
                                                               c_inv.customer_trx_id
                                                           AND ROWNUM = 1;

                                                    IF ld_gl_date >
                                                       ld_batch_date
                                                    THEN
                                                        ld_batch_date   :=
                                                            ld_gl_date; --MAX(INV/CM GL date)
                                                    END IF;
                                                EXCEPTION
                                                    WHEN OTHERS
                                                    THEN
                                                        msg (
                                                               'Error occured for Inv Id: '
                                                            || c_inv.customer_trx_id
                                                            || ' while fetching the GL date',
                                                            100);
                                                END;

                                                do_ar_utils.apply_credit_memo_to_invoice (
                                                    p_customer_id      =>
                                                        c_inv.bill_to_customer_id,
                                                    p_bill_to_site_id   =>
                                                        c_inv.bill_to_site_use_id,
                                                    p_cm_cust_trx_id   =>
                                                        c_cma.customer_trx_id,
                                                    p_inv_cust_trx_id   =>
                                                        c_inv.customer_trx_id,
                                                    p_amount_to_apply   =>
                                                        l_apply_amt,
                                                    p_application_date   =>
                                                        ld_batch_date, --TRUNC (SYSDATE),  --v1.1,
                                                    p_module           => NULL,
                                                    p_module_version   => NULL,
                                                    x_ret_stat         =>
                                                        l_app_status,
                                                    x_rec_application_id   =>
                                                        l_rec_appl_id,
                                                    x_error_msg        =>
                                                        l_err_msg);

                                                IF l_err_msg IS NOT NULL
                                                THEN
                                                    --Start changes v1.3
                                                    ROLLBACK;

                                                    UPDATE xxdo.xxd_ar_create_adjustments_stg
                                                       SET status = 'E', error_message = l_err_msg
                                                     WHERE     trx_number =
                                                               c_cma.trx_number
                                                           AND customer_trx_id =
                                                               c_cma.customer_trx_id
                                                           AND request_id =
                                                               gn_conc_request_id;

                                                    --End changes v1.3

                                                    msg (
                                                           'Unable to apply CM to Invoice ID: '
                                                        || c_cma.customer_trx_id,
                                                        100);
                                                    msg (
                                                           'Error Message: '
                                                        || l_err_msg,
                                                        100);
                                                    l_adj_status   :=
                                                        fnd_api.g_ret_sts_error;
                                                ELSE
                                                    msg (
                                                           'CM applied status: '
                                                        || l_app_status,
                                                        100);
                                                    msg (
                                                           'Successfully applied CM to Invoice ID: '
                                                        || c_cma.customer_trx_id,
                                                        100);

                                                    l_adj_status   :=
                                                        fnd_api.g_ret_sts_success;

                                                    IF l_apply_amt =
                                                       c_inv.inv_balance
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

                                                        COMMIT;   --v1.3 Added
                                                    END IF; --l_apply_amt check

                                                    l_cm_balance   :=
                                                          l_cm_balance
                                                        - l_apply_amt;

                                                    IF l_cm_balance = 0
                                                    THEN
                                                        EXIT;
                                                    END IF; --l_cm_balance check
                                                END IF;      --l_err_msg check
                                            END LOOP;         -- Invoices loop
                                        END IF;   -- exchange order type check
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            l_err_msg   := SQLERRM;
                                            msg (
                                                   'Exception in apply_credit_memo_to_invoice: '
                                                || l_err_msg);
                                    END;

                                    IF     NVL (c_cma.bal_amount, 0) <> 0
                                       AND l_cm_balance <> 0
                                    THEN
                                        --lv_var_amount := c_cma.om_line_total;
                                        lv_var_amount   :=
                                            LEAST (c_cma.bal_amount,
                                                   l_cm_balance);

                                        ld_batch_date   :=
                                            NVL (c_cma.payment_date,
                                                 TRUNC (SYSDATE));

                                        IF ld_batch_date < ld_next_period_dt
                                        THEN
                                            ld_batch_date   :=
                                                ld_next_period_dt;
                                        END IF;

                                        --End changes v1.1

                                        do_ar_utils.create_adjustment_trans (
                                            p_customer_trx_id   =>
                                                c_cma.customer_trx_id,
                                            p_activity_name   =>
                                                lv_adj_activity,
                                            p_type          => 'INVOICE',
                                            p_amount        => lv_var_amount,
                                            p_reason_code   => 'CB-CRME',
                                            p_gl_date       => ld_batch_date, --p_gl_adj_date,  --v1.1,
                                            p_adj_date      => ld_batch_date, --p_gl_adj_date,  --v1.1,
                                            p_comments      =>
                                                'Transaction# ' || c_cma.trx_number,
                                            p_auto_commit   => 'N',
                                            x_adj_id        => l_adj_id,
                                            x_adj_number    => l_adj_number,
                                            x_error_msg     => l_err_msg);

                                        --COMMIT;  --v1.3 Commented

                                        IF l_err_msg IS NOT NULL
                                        THEN
                                            ROLLBACK;             --v1.3 Added
                                            l_adj_status   :=
                                                fnd_api.g_ret_sts_error;

                                            UPDATE xxdo.xxd_ar_create_adjustments_stg
                                               SET status = 'E', error_message = l_err_msg
                                             WHERE     trx_number =
                                                       c_cma.trx_number
                                                   AND customer_trx_id =
                                                       c_cma.customer_trx_id
                                                   AND request_id =
                                                       gn_conc_request_id;

                                            COMMIT;
                                        ELSE
                                            l_adj_status   :=
                                                fnd_api.g_ret_sts_success;
                                        --Start changes v1.1
                                        /*
                                        UPDATE xxdo.xxd_ar_create_adjustments_stg
                                           SET status = 'S',
                                               adjustment_number = l_adj_number,
                                               adjusted_date = SYSDATE
                                         WHERE trx_number = c_cma.trx_number
                                           AND customer_trx_id = c_cma.customer_trx_id
                                           AND request_id = gn_conc_request_id;

                                        COMMIT;
                   */
                                        --End changes v1.1
                                        END IF;

                                        --Start changes v1.1

                                        UPDATE xxdoec_order_payment_details
                                           SET unapplied_amount = c_cma.bal_amount - lv_var_amount, status = DECODE (SIGN (c_cma.bal_amount - lv_var_amount), 0, 'CL', 'OP')
                                         WHERE     header_id =
                                                   c_cma.header_id
                                               AND line_group_id =
                                                   c_cma.line_grp_id;

                                        COMMIT;                   --v1.3 Added

                                        l_cm_balance   :=
                                            l_cm_balance - lv_var_amount;
                                    END IF;

                                    IF l_cm_balance = 0
                                    --IF l_adj_status = fnd_api.g_ret_sts_success
                                    --End changes v1.1
                                    THEN
                                        UPDATE oe_order_lines_all ool
                                           SET ool.attribute20 = 'CMA', ool.attribute19 = 'ADJUSTED', ool.attribute17 = fnd_api.g_ret_sts_success
                                         WHERE     ool.attribute20 =
                                                   c_cma.status_code
                                               AND ool.header_id =
                                                   c_cma.header_id
                                               AND ool.attribute18 =
                                                   c_cma.line_grp_id
                                               AND EXISTS
                                                       (SELECT 1
                                                          FROM ra_customer_trx_lines_all rctl
                                                         WHERE     rctl.customer_trx_id =
                                                                   c_cma.customer_trx_id
                                                               AND rctl.interface_line_context =
                                                                   'ORDER ENTRY'
                                                               AND rctl.interface_line_attribute6 =
                                                                   ool.line_id);

                                        --Start changes v1.1
                                        /*
                                          UPDATE xxdoec_order_payment_details
                                             SET unapplied_amount = 0,
                                                 status = 'CL'
                                           WHERE header_id = c_cma.header_id
                                             AND line_group_id = c_cma.line_grp_id; */
                                        --End changes v1.1

                                        COMMIT;
                                    END IF;
                                ELSE
                                    ROLLBACK;                     --v1.3 Added

                                    UPDATE xxdo.xxd_ar_create_adjustments_stg
                                       SET status = 'E', error_message = 'There is some issue while balancing CM amount with OM Amount'
                                     WHERE     trx_number = c_cma.trx_number
                                           AND customer_trx_id =
                                               c_cma.customer_trx_id
                                           AND request_id =
                                               gn_conc_request_id;

                                    COMMIT;
                                END IF;

                                --Start changes v1.1
                                IF l_adj_status = fnd_api.g_ret_sts_success
                                THEN
                                    UPDATE xxdo.xxd_ar_create_adjustments_stg
                                       SET status = 'S', adjustment_number = l_adj_number, adjusted_date = SYSDATE
                                     WHERE     trx_number = c_cma.trx_number
                                           AND customer_trx_id =
                                               c_cma.customer_trx_id
                                           AND request_id =
                                               gn_conc_request_id;

                                    COMMIT;
                                END IF;                   --l_adj_status check
                            --End changes v1.1

                            END IF;                     -- OM, CM totals match
                        END IF;
                    END IF;                        -- END IF FOR lv_adjustment
                ELSE
                    ROLLBACK;                                     --v1.3 Added

                    UPDATE xxdo.xxd_ar_create_adjustments_stg
                       SET status = 'E', error_message = 'CM balance is zero, then no need to create any adjustment activity'
                     WHERE     trx_number = c_cma.trx_number
                           AND customer_trx_id = c_cma.customer_trx_id
                           AND request_id = gn_conc_request_id;

                    COMMIT;
                END IF;                       -- only when balance is not zero
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_err_msg   :=
                           'Unexpected Error occured while processing Order Header ID: '
                        || c_cma.header_id
                        || ' Lines Group ID: '
                        || c_cma.line_grp_id
                        || ' TRX Number: '
                        || c_cma.trx_number
                        || SQLERRM;
                    ROLLBACK;
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_err_msg   := SQLERRM;
            msg ('Exception in create_cm_adju_transaction:' || l_err_msg);
    END create_cm_adju_transaction;

    FUNCTION before_report
        RETURN BOOLEAN
    AS
        lv_msg     VARCHAR2 (2000);
        lv_trunc   VARCHAR2 (2000);
    BEGIN
        --delete 6 months old data
        DELETE FROM xxdo.xxd_ar_create_adjustments_stg
              WHERE TRUNC (creation_date) < ADD_MONTHS (TRUNC (SYSDATE), -6);

        COMMIT;

        --calling insert_data to insert eligible records into staging table
        insert_data ();

        --If only reort_mode ='N' then process the records
        IF NVL (pv_report_mode, 'N') = 'N'
        THEN
            --create_cm_adju_transaction (); --v1.1
            create_inv_adju_transaction ();
            create_cm_adju_transaction ();                              --v1.1
        END IF;

        COMMIT;
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_msg   := SQLERRM;
            RETURN TRUE;
    END before_report;
END xxd_ar_create_adjustments;
/
