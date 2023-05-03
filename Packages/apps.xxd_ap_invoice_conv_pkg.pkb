--
-- XXD_AP_INVOICE_CONV_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:49 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AP_INVOICE_CONV_PKG"
AS
    /*******************************************************************************
    * Program Name : XXD_AP_INVOICE_CONV_PKG
    * Language     : PL/SQL
    * Description  : This package will load invoices data in to Oracle Payable base tables
    *
    * History      :
    *
    * WHO            WHAT              Desc                             WHEN
    * -------------- ---------------------------------------------- ---------------
    * BT Technology Team 1.0                                             17-JUN-2014
    * --------------------------------------------------------------------------- */
    gn_user_id          NUMBER := fnd_global.user_id;
    gn_resp_id          NUMBER := fnd_global.resp_id;
    gn_resp_appl_id     NUMBER := fnd_global.resp_appl_id;
    gn_req_id           NUMBER := fnd_global.conc_request_id;
    gn_sob_id           NUMBER := fnd_profile.VALUE ('GL_SET_OF_BKS_ID');
    gn_org_id           NUMBER := fnd_profile.VALUE ('ORG_ID');
    gn_login_id         NUMBER := fnd_global.login_id;
    gd_sysdate          DATE := SYSDATE;
    gc_code_pointer     VARCHAR2 (500);
    gb_boolean          BOOLEAN;
    gn_inv_process      NUMBER;
    gn_inv_reject       NUMBER;
    gn_dist_processed   NUMBER;
    gn_dist_rejected    NUMBER;
    gn_hold_processed   NUMBER;
    gn_hold_rejected    NUMBER;
    gn_inv_found        NUMBER;
    gn_dist_found       NUMBER;
    gn_hold_found       NUMBER;
    gn_inv_extract      NUMBER;
    gn_dist_extract     NUMBER;
    gn_hold_extract     NUMBER;
    gn_limit            NUMBER := 1000;
    gc_yesflag          VARCHAR2 (1) := 'Y';
    gc_noflag           VARCHAR2 (1) := 'N';
    gc_debug_flag       VARCHAR2 (1) := 'Y';
    gn_gl_date          DATE;

    /****************************************************************************************
          * Procedure : EXTRACT_INVOICE_PROC
          * Synopsis  : This Procedure is called by val_load_main_prc Main procedure
          * Design    : Procedure loads data to staging table for AP Invoice Conversion
          * Notes     :
          * Return Values: None
          * Modification :
          * Date          Developer     Version    Description
          *--------------------------------------------------------------------------------------
          * 07-JUL-2014   Swapna N        1.00       Created
          ****************************************************************************************/

    PROCEDURE extract_invoice_proc
    IS
        TYPE l_invoice_info_type IS TABLE OF xxd_ap_invoice_conv_v%ROWTYPE;

        l_apinv_tbl          l_invoice_info_type;

        CURSOR invoice_c IS
            SELECT *
              FROM xxd_ap_invoice_conv_v xaic
             WHERE /*EXISTS
                      (SELECT 1
                         FROM ap_suppliers sup
                        WHERE xaic.vendor_name = sup.vendor_name)
               AND */
                       NOT EXISTS
                           (SELECT 1
                              FROM XXD_AP_INVOICE_CONV_STG_T
                             WHERE old_invoice_id = xaic.invoice_id)
                   AND validation_status = 'VALIDATED';

        TYPE l_invoice_dist_info_type
            IS TABLE OF xxd_ap_invoice_dist_conv_v%ROWTYPE;

        l_apinv_dist_tbl     l_invoice_dist_info_type;

        CURSOR invoice_dist_c IS
            SELECT *
              FROM xxd_ap_invoice_dist_conv_v r_apinv_dist
             WHERE EXISTS
                       (SELECT 1
                          --Srinivas
                          FROM xxd_ap_invoice_conv_stg_t r_apinvt
                         WHERE     r_apinv_dist.invoice_id =
                                   r_apinvt.old_invoice_id          --Srinivas
                               AND r_apinvt.record_status = 'N'
                               AND r_apinvt.request_id = gn_req_id);

        CURSOR updt_dup_line_num IS
            SELECT record_id, old_invoice_id, ROW_NUMBER () OVER (PARTITION BY old_invoice_id ORDER BY old_invoice_id) new_line_number
              FROM XXD_AP_INVOICE_DIST_CONV_STG_T
             WHERE old_invoice_id IN (  SELECT old_invoice_id
                                          FROM XXD_AP_INVOICE_DIST_CONV_STG_T
                                      GROUP BY old_invoice_id, line_number
                                        HAVING COUNT (1) > 1);

        lcu_invoice_dist_c   invoice_dist_c%ROWTYPE;
        ln_loop_counter      NUMBER;

        --      lc_shipment_num         NUMBER;
        --      ln_po_header_id         NUMBER;
        --      ln_po_line_id           NUMBER;
        --      ln_po_distribution_id   NUMBER;
        --      ln_po_line_loc_id       NUMBER;
        ln_inv_var           NUMBER;
        ln_pay_grp           VARCHAR2 (25);
        ln_pay_method        VARCHAR2 (25);
    BEGIN
        --gc_code_pointer := 'Deleting data from  Header and line staging table';

        --Deleting data from  Header and line staging table

        --EXECUTE IMMEDIATE 'truncate table XXD_CONV.XXD_AP_INVOICE_CONV_STG_T';

        --EXECUTE IMMEDIATE
        --  'truncate table XXD_CONV.XXD_AP_INVOICE_DIST_CONV_STG_T';


        BEGIN
            gc_code_pointer   := 'Deleting data from Invoice Dump table';

            DELETE FROM XXD_CONV.XXD_AP_INVOICE_EXTRACT_T@BT_READ_1206;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'OTHERS Exception while performing delete operation on XXD_AP_INVOICE_EXTRACT_T Table');


                xxd_common_utils.record_error (
                    'APINV',
                    xxd_common_utils.get_org_id,
                    'Deckers AP Invoice Conversion Program',
                    DBMS_UTILITY.format_error_backtrace,
                    gn_user_id,
                    gn_req_id,
                    'Code pointer : ' || gc_code_pointer,
                    'XXD_AP_INVOICE_EXTRACT_T');
        END;

        BEGIN
            gc_code_pointer   := 'Inserting data into Invoice Dump table';

            INSERT INTO xxd_ap_invoice_extract_t@bt_read_1206
                  --Prepayment invoices
                  SELECT ai.invoice_id
                    FROM ap_invoice_distributions_all@bt_read_1206 aid, ap_invoices_all@bt_read_1206 ai
                   WHERE     aid.invoice_id = ai.invoice_id
                         AND ai.invoice_type_lookup_code = 'PREPAYMENT'
                         AND NVL (aid.reversal_flag, 'N') <> 'Y'
                GROUP BY ai.invoice_id
                  HAVING NVL (
                             DECODE (
                                 SIGN (
                                     SUM (
                                           aid.amount
                                         - NVL (aid.prepay_amount_remaining,
                                                aid.amount))),
                                 1, DECODE (
                                        SUM (aid.prepay_amount_remaining),
                                        0, 'Y',
                                        NULL),
                                 NULL),
                             'N') <>
                         'Y'
                UNION
                  --Non PO/PO Open Invoices
                  SELECT aps.invoice_id
                    FROM ap_payment_schedules_all@bt_read_1206 aps, ap_invoice_lines_all@bt_read_1206 aila, ap_invoice_distributions_all@bt_read_1206 aid
                   WHERE     NVL (aps.amount_remaining, 0) <> 0
                         AND aps.invoice_id = aila.invoice_id
                         AND aps.invoice_id = aid.invoice_id
                         AND aila.line_number = aid.invoice_line_number
                --AND aid.po_distribution_id IS NULL -- Commented by BT Technology team on 30-Sep-15
                GROUP BY aps.invoice_id
                UNION
                  --PO Invoices
                  SELECT aila.invoice_id
                    FROM ap_invoice_lines_all@bt_read_1206 aila, apps.po_headers_all pha_1223, po_headers_all@bt_read_1206 pha_1206
                   WHERE     aila.po_header_id = pha_1206.po_header_id
                         AND pha_1206.segment1 = pha_1223.segment1
                GROUP BY aila.invoice_id;

            IF SQL%ROWCOUNT > 1
            THEN
                COMMIT;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'OTHERS Exception while Insert into XXD_AP_INVOICE_EXTRACT_T Table');


                xxd_common_utils.record_error (
                    'APINV',
                    xxd_common_utils.get_org_id,
                    'Deckers AP Invoice Conversion Program',
                    DBMS_UTILITY.format_error_backtrace,
                    gn_user_id,
                    gn_req_id,
                    'Code pointer : ' || gc_code_pointer,
                    'XXD_AP_INVOICE_EXTRACT_T');
        END;


        gc_code_pointer   := 'Insert into   Header  staging table';

        -- Insert records into Invoice Header staging table

        BEGIN
            OPEN invoice_c;

            ln_loop_counter   := 0;

            LOOP
                FETCH invoice_c BULK COLLECT INTO l_apinv_tbl LIMIT gn_limit;



                FORALL lcu_invoice_rec IN 1 .. l_apinv_tbl.COUNT
                    INSERT INTO xxd_ap_invoice_conv_stg_t (old_invoice_id, invoice_num, invoice_type_lookup_code, invoice_date, po_number, vendor_num, vendor_site_code, invoice_amount, invoice_currency_code, exchange_rate, exchange_rate_type, exchange_date, terms_name, description, awt_group_name, attribute_category, attribute1, attribute2, attribute3, attribute4, attribute5, attribute6, attribute7, attribute8, attribute9, attribute10, attribute11, attribute12, attribute13, attribute14, attribute15, global_attribute_category, global_attribute1, global_attribute2, global_attribute3, global_attribute4, global_attribute5, global_attribute6, global_attribute7, global_attribute8, global_attribute9, global_attribute10, global_attribute11, global_attribute12, global_attribute13, global_attribute14, global_attribute15, global_attribute16, global_attribute17, global_attribute18, global_attribute19, global_attribute20, source, payment_cross_rate_type, payment_cross_rate_date, payment_cross_rate, payment_currency_code, doc_category_code, voucher_num, payment_method_code, payment_method_lookup_code, pay_group_lookup_code, payment_status_flag, goods_received_date, invoice_received_date, gl_date, acc_pay_seg1, acc_pay_seg2, acc_pay_seg3, acc_pay_seg4, acc_pay_seg5, amount_applicable_to_discount, terms_date, operating_unit, wfapproval_status, requester_employee_num, old_business_group_id, old_legal_entity_id, set_of_books_id, vendor_name, error_message, record_status, record_id, new_requester_emp_id, new_acctpay_ccid, org_id, last_update_date, last_updated_by, last_updated_login, creation_date, created_by, new_attribute_category, batch_number
                                                           , request_id)
                         VALUES (l_apinv_tbl (lcu_invoice_rec).invoice_id, l_apinv_tbl (lcu_invoice_rec).invoice_num, l_apinv_tbl (lcu_invoice_rec).invoice_type_lookup_code, l_apinv_tbl (lcu_invoice_rec).invoice_date, l_apinv_tbl (lcu_invoice_rec).po_number, l_apinv_tbl (lcu_invoice_rec).vendor_num, l_apinv_tbl (lcu_invoice_rec).vendor_site_code, l_apinv_tbl (lcu_invoice_rec).invoice_amount, l_apinv_tbl (lcu_invoice_rec).invoice_currency_code, l_apinv_tbl (lcu_invoice_rec).exchange_rate, l_apinv_tbl (lcu_invoice_rec).exchange_rate_type, l_apinv_tbl (lcu_invoice_rec).exchange_date, l_apinv_tbl (lcu_invoice_rec).name, l_apinv_tbl (lcu_invoice_rec).description, l_apinv_tbl (lcu_invoice_rec).awt_group_name, l_apinv_tbl (lcu_invoice_rec).attribute_category, l_apinv_tbl (lcu_invoice_rec).attribute1, l_apinv_tbl (lcu_invoice_rec).attribute2, l_apinv_tbl (lcu_invoice_rec).attribute3, l_apinv_tbl (lcu_invoice_rec).attribute4, l_apinv_tbl (lcu_invoice_rec).attribute5, l_apinv_tbl (lcu_invoice_rec).attribute6, l_apinv_tbl (lcu_invoice_rec).attribute7, l_apinv_tbl (lcu_invoice_rec).attribute8, l_apinv_tbl (lcu_invoice_rec).attribute9, l_apinv_tbl (lcu_invoice_rec).attribute10, l_apinv_tbl (lcu_invoice_rec).attribute11, l_apinv_tbl (lcu_invoice_rec).attribute12, l_apinv_tbl (lcu_invoice_rec).attribute13, l_apinv_tbl (lcu_invoice_rec).attribute14, l_apinv_tbl (lcu_invoice_rec).attribute15, l_apinv_tbl (lcu_invoice_rec).global_attribute_category, l_apinv_tbl (lcu_invoice_rec).global_attribute1, l_apinv_tbl (lcu_invoice_rec).global_attribute2, l_apinv_tbl (lcu_invoice_rec).global_attribute3, l_apinv_tbl (lcu_invoice_rec).global_attribute4, l_apinv_tbl (lcu_invoice_rec).global_attribute5, l_apinv_tbl (lcu_invoice_rec).global_attribute6, l_apinv_tbl (lcu_invoice_rec).global_attribute7, l_apinv_tbl (lcu_invoice_rec).global_attribute8, l_apinv_tbl (lcu_invoice_rec).global_attribute9, l_apinv_tbl (lcu_invoice_rec).global_attribute10, l_apinv_tbl (lcu_invoice_rec).global_attribute11, l_apinv_tbl (lcu_invoice_rec).global_attribute12, l_apinv_tbl (lcu_invoice_rec).global_attribute13, l_apinv_tbl (lcu_invoice_rec).global_attribute14, l_apinv_tbl (lcu_invoice_rec).global_attribute15, l_apinv_tbl (lcu_invoice_rec).global_attribute16, l_apinv_tbl (lcu_invoice_rec).global_attribute17, l_apinv_tbl (lcu_invoice_rec).global_attribute18, l_apinv_tbl (lcu_invoice_rec).global_attribute19, l_apinv_tbl (lcu_invoice_rec).global_attribute20, 'CONVERSIONS', --l_apinv_tbl (lcu_invoice_rec).SOURCE,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              l_apinv_tbl (lcu_invoice_rec).payment_cross_rate_type, l_apinv_tbl (lcu_invoice_rec).payment_cross_rate_date, l_apinv_tbl (lcu_invoice_rec).payment_cross_rate, l_apinv_tbl (lcu_invoice_rec).payment_currency_code, l_apinv_tbl (lcu_invoice_rec).doc_category_code, l_apinv_tbl (lcu_invoice_rec).voucher_num, l_apinv_tbl (lcu_invoice_rec).payment_method_code, l_apinv_tbl (lcu_invoice_rec).payment_method_lookup_code, l_apinv_tbl (lcu_invoice_rec).pay_group_lookup_code, l_apinv_tbl (lcu_invoice_rec).payment_status_flag, l_apinv_tbl (lcu_invoice_rec).goods_received_date, l_apinv_tbl (lcu_invoice_rec).invoice_received_date, NVL (gn_gl_date, l_apinv_tbl (lcu_invoice_rec).gl_date), l_apinv_tbl (lcu_invoice_rec).acc_pay_seg1, l_apinv_tbl (lcu_invoice_rec).acc_pay_seg2, l_apinv_tbl (lcu_invoice_rec).acc_pay_seg3, l_apinv_tbl (lcu_invoice_rec).acc_pay_seg4, l_apinv_tbl (lcu_invoice_rec).acc_pay_seg5, l_apinv_tbl (lcu_invoice_rec).amount_applicable_to_discount, l_apinv_tbl (lcu_invoice_rec).terms_date, l_apinv_tbl (lcu_invoice_rec).operating_unit, l_apinv_tbl (lcu_invoice_rec).wfapproval_status, l_apinv_tbl (lcu_invoice_rec).requester_employee_num, l_apinv_tbl (lcu_invoice_rec).old_business_group_id, l_apinv_tbl (lcu_invoice_rec).old_legal_entity_id, gn_sob_id, l_apinv_tbl (lcu_invoice_rec).vendor_name, NULL, 'N', xxd_ap_invoice_conv_stg_s.NEXTVAL, NULL, NULL, NULL, gd_sysdate, gn_user_id, gn_login_id, gd_sysdate, gn_user_id, NULL, --lv_R12_attri,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              NULL
                                 , gn_req_id);



                ln_loop_counter   := ln_loop_counter + 1;

                IF ln_loop_counter = gn_limit
                THEN
                    COMMIT;
                    ln_loop_counter   := 0;
                END IF;

                EXIT WHEN invoice_c%NOTFOUND;
            END LOOP;

            CLOSE invoice_c;

            BEGIN
                fnd_stats.gather_table_stats (
                    UPPER ('XXD_CONV'),
                    UPPER ('XXD_AP_INVOICE_CONV_STG_T'));
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            gc_code_pointer   := 'After insert into Header table';
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'OTHERS Exception while Insert into XXD_AP_INVOICE_CONV_STG_T Table');


                xxd_common_utils.record_error (
                    'APINV',
                    xxd_common_utils.get_org_id,
                    'Deckers AP Invoice Conversion Program',
                    DBMS_UTILITY.format_error_backtrace,
                    gn_user_id,
                    gn_req_id,
                    'Code pointer : ' || gc_code_pointer,
                    'XXD_AP_INVOICE_CONV_STG_T');
        END;

        COMMIT;

        BEGIN
            gc_code_pointer   := 'Insert data into line staging table';

            --Insert data into line staging table

            OPEN invoice_dist_c;

            ln_loop_counter   := 0;

            LOOP
                FETCH invoice_dist_c INTO lcu_invoice_dist_c;

                EXIT WHEN invoice_dist_c%NOTFOUND;


                BEGIN
                    INSERT INTO xxd_ap_invoice_dist_conv_stg_t (
                                    old_invoice_id,
                                    line_number,
                                    dist_line_number,
                                    line_type_lookup_code,
                                    line_group_number,
                                    amount,
                                    dist_amount,
                                    accounting_date,
                                    description,
                                    amount_includes_tax_flag,
                                    tax_code,
                                    final_match_flag,
                                    po_number,
                                    po_line_number,
                                    po_distribution_num,
                                    po_shipment_num,
                                    new_po_header_id,
                                    new_po_line_id,
                                    new_po_distribution_id,
                                    new_line_location_id,
                                    quantity_invoiced,
                                    unit_price,
                                    distribution_ccid_seg1,
                                    distribution_ccid_seg2,
                                    distribution_ccid_seg3,
                                    distribution_ccid_seg4,
                                    awt_group_name,
                                    attribute_category,
                                    attribute1,
                                    attribute2,
                                    attribute3,
                                    attribute4,
                                    attribute5,
                                    attribute6,
                                    attribute7,
                                    attribute8,
                                    attribute9,
                                    attribute10,
                                    attribute11,
                                    attribute12,
                                    attribute13,
                                    attribute14,
                                    attribute15,
                                    global_attribute_category,
                                    global_attribute1,
                                    global_attribute2,
                                    global_attribute3,
                                    global_attribute4,
                                    global_attribute5,
                                    global_attribute6,
                                    global_attribute7,
                                    global_attribute8,
                                    global_attribute9,
                                    global_attribute10,
                                    global_attribute11,
                                    global_attribute12,
                                    global_attribute13,
                                    global_attribute14,
                                    global_attribute15,
                                    global_attribute16,
                                    global_attribute17,
                                    global_attribute18,
                                    global_attribute19,
                                    global_attribute20,
                                    project_number,
                                    task_number,
                                    expenditure_type,
                                    expenditure_item_date,
                                    expenditure_organization_name,
                                    --PROJECT_ACCOUNTING_CONTEXT,
                                    --PA_ADDITION_FLAG,
                                    pa_quantity,
                                    type_1099,
                                    income_tax_region,
                                    assets_tracking_flag,
                                    operating_unit,
                                    reference_1,
                                    reference_2,
                                    --TAX_RECOVERY_RATE,
                                    --TAX_RECOVERY_OVERRIDE_FLAG,
                                    --TAX_RECOVERABLE_FLAG,
                                    --TAX_CODE_OVERRIDE_FLAG,
                                    uom,
                                    cc_reversal_flag,
                                    company_prepaid_invoice_id,
                                    expense_group,
                                    justification,
                                    error_message,
                                    record_status,
                                    record_id,
                                    request_id,
                                    --                         NEW_PO_HEADER_ID,
                                    --                         NEW_LINE_ID,
                                    --                         NEW_LINE_LOCATION_ID,
                                    --                         NEW_DISTRIBUTION_ID,
                                    new_dist_ccid,
                                    last_updated_by,
                                    last_update_date,
                                    last_update_login,
                                    created_by,
                                    creation_date,
                                    new_attribute_category,
                                    new_project_id,
                                    new_task_id,
                                    new_expenditure_type,
                                    new_exp_organization_id,
                                    ussgl_transaction_code,
                                    stat_amount,
                                    price_correction_flag,
                                    new_org_id,
                                    tax_regime_code,
                                    tax,
                                    tax_jurisdiction_code,
                                    tax_status_code,
                                    tax_rate_id,
                                    tax_rate_code,
                                    tax_rate,
                                    tax_code_id,
                                    prorate_across_flag,
                                    ship_to_location_code)
                             VALUES (
                                        lcu_invoice_dist_c.invoice_id,
                                        lcu_invoice_dist_c.line_number,
                                        lcu_invoice_dist_c.dist_line_number,
                                        lcu_invoice_dist_c.line_type_lookup_code,
                                        lcu_invoice_dist_c.line_group_number,
                                        lcu_invoice_dist_c.amount,
                                        lcu_invoice_dist_c.dist_amount,
                                        NVL (
                                            gn_gl_date,
                                            lcu_invoice_dist_c.accounting_date),
                                        lcu_invoice_dist_c.description,
                                        lcu_invoice_dist_c.amount_includes_tax_flag,
                                        lcu_invoice_dist_c.tax_code,
                                        lcu_invoice_dist_c.final_match_flag,
                                        lcu_invoice_dist_c.po_number,
                                        lcu_invoice_dist_c.po_line_number,
                                        lcu_invoice_dist_c.po_distribution_num,
                                        NULL,               --lc_shipment_num,
                                        NULL,               --ln_po_header_id,
                                        NULL,                 --ln_po_line_id,
                                        NULL,         --ln_po_distribution_id,
                                        NULL,             --ln_po_line_loc_id,
                                        lcu_invoice_dist_c.quantity_invoiced,
                                        lcu_invoice_dist_c.unit_price,
                                        lcu_invoice_dist_c.distribution_ccid_seg1,
                                        lcu_invoice_dist_c.distribution_ccid_seg2,
                                        lcu_invoice_dist_c.distribution_ccid_seg3,
                                        lcu_invoice_dist_c.distribution_ccid_seg4,
                                        lcu_invoice_dist_c.awt_group_name,
                                        lcu_invoice_dist_c.attribute_category,
                                        lcu_invoice_dist_c.attribute1,
                                        lcu_invoice_dist_c.attribute2,
                                        lcu_invoice_dist_c.attribute3,
                                        lcu_invoice_dist_c.attribute4,
                                        lcu_invoice_dist_c.attribute5,
                                        lcu_invoice_dist_c.attribute6,
                                        lcu_invoice_dist_c.attribute7,
                                        lcu_invoice_dist_c.attribute8,
                                        lcu_invoice_dist_c.attribute9,
                                        lcu_invoice_dist_c.attribute10,
                                        lcu_invoice_dist_c.attribute11,
                                        lcu_invoice_dist_c.attribute12,
                                        lcu_invoice_dist_c.attribute13,
                                        lcu_invoice_dist_c.attribute14,
                                        lcu_invoice_dist_c.attribute15,
                                        lcu_invoice_dist_c.global_attribute_category,
                                        lcu_invoice_dist_c.global_attribute1,
                                        lcu_invoice_dist_c.global_attribute2,
                                        lcu_invoice_dist_c.global_attribute3,
                                        lcu_invoice_dist_c.global_attribute4,
                                        lcu_invoice_dist_c.global_attribute5,
                                        lcu_invoice_dist_c.global_attribute6,
                                        lcu_invoice_dist_c.global_attribute7,
                                        lcu_invoice_dist_c.global_attribute8,
                                        lcu_invoice_dist_c.global_attribute9,
                                        lcu_invoice_dist_c.global_attribute10,
                                        lcu_invoice_dist_c.global_attribute11,
                                        lcu_invoice_dist_c.global_attribute12,
                                        lcu_invoice_dist_c.global_attribute13,
                                        lcu_invoice_dist_c.global_attribute14,
                                        lcu_invoice_dist_c.global_attribute15,
                                        lcu_invoice_dist_c.global_attribute16,
                                        lcu_invoice_dist_c.global_attribute17,
                                        lcu_invoice_dist_c.global_attribute18,
                                        lcu_invoice_dist_c.global_attribute19,
                                        lcu_invoice_dist_c.global_attribute20,
                                        lcu_invoice_dist_c.project_num,
                                        lcu_invoice_dist_c.task_number,
                                        lcu_invoice_dist_c.expenditure_type,
                                        lcu_invoice_dist_c.expenditure_item_date,
                                        lcu_invoice_dist_c.expenditure_organization_name,
                                        --lcu_invoice_dist_c.PROJECT_ACCOUNTING_CONTEXT,
                                        --lcu_invoice_dist_c.PA_ADDITION_FLAG,
                                        lcu_invoice_dist_c.pa_quantity,
                                        lcu_invoice_dist_c.type_1099,
                                        lcu_invoice_dist_c.income_tax_region,
                                        lcu_invoice_dist_c.assets_tracking_flag,
                                        lcu_invoice_dist_c.operating_unit,
                                        lcu_invoice_dist_c.reference_1,
                                        lcu_invoice_dist_c.reference_2,
                                        -- lcu_invoice_dist_c.TAX_RECOVERY_RATE,
                                        -- lcu_invoice_dist_c.TAX_RECOVERY_OVERRIDE_FLAG,
                                        --lcu_invoice_dist_c.TAX_RECOVERABLE_FLAG,
                                        --lcu_invoice_dist_c.TAX_CODE_OVERRIDE_FLAG,
                                        lcu_invoice_dist_c.uom,
                                        lcu_invoice_dist_c.cc_reversal_flag,
                                        lcu_invoice_dist_c.company_prepaid_invoice_id,
                                        lcu_invoice_dist_c.expense_group,
                                        lcu_invoice_dist_c.justification,
                                        NULL,
                                        'N',
                                        xxd_ap_invoice_dist_conv_stg_s.NEXTVAL,
                                        gn_req_id,
                                        --                       NULL,
                                        --                       NULL,
                                        --                       NULL,
                                        --                       NULL,
                                        NULL,
                                        gn_user_id,
                                        gd_sysdate,
                                        gn_login_id,
                                        gn_user_id,
                                        gd_sysdate,
                                        NULL,                 --lv_R12_attri1,
                                        NULL,
                                        NULL,
                                        NULL,
                                        NULL,
                                        NULL,
                                        NULL,
                                        NULL,
                                        NULL,
                                        lcu_invoice_dist_c.tax_regime_code,
                                        lcu_invoice_dist_c.tax,
                                        lcu_invoice_dist_c.tax_jurisdiction_code,
                                        lcu_invoice_dist_c.tax_status_code,
                                        lcu_invoice_dist_c.tax_rate_id,
                                        lcu_invoice_dist_c.tax_rate_code,
                                        lcu_invoice_dist_c.tax_rate,
                                        lcu_invoice_dist_c.tax_code_id,
                                        lcu_invoice_dist_c.prorate_across_flag,
                                        lcu_invoice_dist_c.ship_to_location_code);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Invoice id ' || lcu_invoice_dist_c.invoice_id);

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Line No  ' || lcu_invoice_dist_c.line_number);


                        fnd_file.put_line (fnd_file.LOG, SQLERRM);


                        xxd_common_utils.record_error (
                            'APINV',
                            xxd_common_utils.get_org_id,
                            'Deckers AP Invoice Conversion Program',
                            DBMS_UTILITY.format_error_backtrace,
                            gn_user_id,
                            gn_req_id,
                            'Code pointer : ' || gc_code_pointer,
                            'XXD_AP_INVOICE_CONV_STG_T');
                END;



                ln_loop_counter   := ln_loop_counter + 1;

                IF ln_loop_counter = gn_limit
                THEN
                    COMMIT;
                    ln_loop_counter   := 0;
                END IF;
            END LOOP;

            COMMIT;

            CLOSE invoice_dist_c;

            FOR rec_updt_dup_line_num IN updt_dup_line_num
            LOOP
                UPDATE XXD_AP_INVOICE_DIST_CONV_STG_T
                   SET line_number = rec_updt_dup_line_num.new_line_number, DIST_LINE_NUMBER = rec_updt_dup_line_num.new_line_number
                 WHERE     old_invoice_id =
                           rec_updt_dup_line_num.old_invoice_id
                       AND record_id = rec_updt_dup_line_num.record_id;
            END LOOP;

            COMMIT;

            BEGIN
                fnd_stats.gather_table_stats (
                    UPPER ('XXD_CONV'),
                    UPPER ('XXD_AP_INVOICE_DIST_CONV_STG_T'));
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            gc_code_pointer   := 'After insert into line staging table';
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'OTHERS Exception while Insert into XXD_AP_INVOICE_DIST_CONV_STG_T Table');



                xxd_common_utils.record_error (
                    'APINV',
                    xxd_common_utils.get_org_id,
                    'Deckers AP Invoice Conversion Program',
                    DBMS_UTILITY.format_error_backtrace,
                    gn_user_id,
                    gn_req_id,
                    'Code pointer : ' || gc_code_pointer,
                    'XXD_AP_INVOICE_CONV_STG_T');
        END;

        COMMIT;



        BEGIN
            SELECT COUNT (*)
              INTO gn_inv_extract
              FROM xxd_ap_invoice_conv_stg_t
             WHERE record_status = 'N';

            SELECT COUNT (*)
              INTO gn_dist_extract
              FROM xxd_ap_invoice_dist_conv_stg_t
             WHERE record_status = 'N';
        END;



        -- Writing counts to output file
        fnd_file.put_line (
            fnd_file.output,
            'S.No                   Entity           Total Records Extracted from 12.0.6 and loaded to 12.2.3 ');
        fnd_file.put_line (
            fnd_file.output,
            '----------------------------------------------------------------------------------------------');
        fnd_file.put_line (
            fnd_file.output,
               '1                    '
            || RPAD ('XXD_AP_INVOICE_CONV_STG_T', 40, ' ')
            || '   '
            || gn_inv_extract);
        fnd_file.put_line (
            fnd_file.output,
               '2                    '
            || RPAD ('XXD_AP_INVOICE_DIST_CONV_STG_T', 40, ' ')
            || '   '
            || gn_dist_extract);
    END extract_invoice_proc;



    /****************************************************************************************
          * Procedure : INTERFACE_LOAD_PRC
          * Synopsis  : This Procedure is called by val_load_main_prc Main procedure
          * Design    : Procedure loads data to interface table for AP Invoice Conversion
          * Notes     :
          * Return Values: None
          * Modification :
          * Date          Developer     Version    Description
          *--------------------------------------------------------------------------------------
          * 07-JUL-2014   Swapna N        1.00       Created
          ****************************************************************************************/
    PROCEDURE interface_load_prc (x_retcode         OUT NUMBER,
                                  x_errbuff         OUT VARCHAR2,
                                  p_batch_low    IN     NUMBER,
                                  p_batch_high   IN     NUMBER,
                                  p_debug        IN     VARCHAR2)
    AS
        CURSOR invoice_c IS
            SELECT acc_pay_seg1, acc_pay_seg2, acc_pay_seg3,
                   acc_pay_seg4, acc_pay_seg5, amount_applicable_to_discount,
                   attribute1, attribute10, attribute11,
                   attribute12, attribute13, attribute14,
                   attribute15, attribute2, attribute3,
                   attribute4, attribute5, attribute6,
                   attribute7, attribute8, attribute9,
                   attribute_category, awt_group_name, batch_number,
                   created_by, creation_date, description,
                   doc_category_code, error_message, exchange_date,
                   exchange_rate, exchange_rate_type, global_attribute1,
                   global_attribute10, global_attribute11, global_attribute12,
                   global_attribute13, global_attribute14, global_attribute15,
                   global_attribute16, global_attribute17, global_attribute18,
                   global_attribute19, global_attribute2, global_attribute20,
                   global_attribute3, global_attribute4, global_attribute5,
                   global_attribute6, global_attribute7, global_attribute8,
                   global_attribute9, global_attribute_category, gl_date,
                   goods_received_date, invoice_amount, invoice_currency_code,
                   invoice_date, invoice_num, invoice_received_date,
                   invoice_type_lookup_code, last_updated_by, last_updated_login,
                   last_update_date, new_acctpay_ccid, new_attribute_category,
                   new_business_group_id, new_coa_id, new_legal_entity_id,
                   new_ou_name, new_requester_emp_id, new_vendor_id,
                   new_vendor_site_id, old_business_group_id, old_invoice_id,
                   old_legal_entity_id, operating_unit, org_id,
                   payment_cross_rate, payment_cross_rate_date, payment_cross_rate_type,
                   payment_currency_code, payment_method_lookup_code, payment_method_code,
                   pay_group_lookup_code, po_number, record_id,
                   record_status, requester_employee_num, request_id,
                   source, terms_date, terms_name,
                   terms_id, vendor_num, vendor_name,
                   vendor_site_code, voucher_num, wfapproval_status,
                   NTILE (10) OVER (ORDER BY old_invoice_id) group_num
              FROM xxd_ap_invoice_conv_stg_t
             WHERE     batch_number BETWEEN p_batch_low AND p_batch_high
                   AND record_status = 'V';


        CURSOR inv_line_c (p_invoice_id NUMBER)
        IS
            SELECT xaid.*
              FROM xxd_ap_invoice_dist_conv_stg_t xaid
             WHERE xaid.old_invoice_id = p_invoice_id;

        lcu_inv_line_c               inv_line_c%ROWTYPE;

        --Srinivas
        CURSOR get_group_line_c (p_invoice_id NUMBER)
        IS
              SELECT old_invoice_id, line_number, new_dist_ccid,
                     line_type_lookup_code, SUM (dist_amount) di_amount
                FROM xxd_ap_invoice_dist_conv_stg_t
               WHERE old_invoice_id = p_invoice_id
            GROUP BY old_invoice_id, line_number, line_type_lookup_code,
                     new_dist_ccid;

        CURSOR get_france_org_id IS
            SELECT organization_id
              FROM hr_operating_units
             WHERE name = 'Deckers France SAS OU';

        -- Start modification on 06-Aug-2015 for Zero Tax
        CURSOR get_zero_tax_code_c (p_org_id NUMBER)
        IS
            SELECT flv.description
              FROM fnd_lookup_values_vl flv, hr_operating_units hou
             WHERE     flv.lookup_type = 'XXDO_OU_ZERO_TAX_MAPPING'
                   AND flv.meaning = hou.name
                   AND hou.organization_id = p_org_id;

        lc_tax_classification_code   VARCHAR2 (240);
        -- End modification on 06-Aug-2015 for Zero Tax

        lcu_get_group_line_c         get_group_line_c%ROWTYPE;


        TYPE invoice_info_type IS TABLE OF invoice_c%ROWTYPE
            INDEX BY BINARY_INTEGER;

        invoice_info_tbl             invoice_info_type;



        TYPE request_id_tab_typ IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        request_id_tab               request_id_tab_typ;


        ln_invoice_id                NUMBER;
        ln_invoice_line_id           NUMBER;
        ln_conc_req_id               NUMBER;
        ln_inv_vald_req_id           NUMBER;
        lb_wait_for_request          BOOLEAN;
        lc_phase                     VARCHAR2 (10);
        lc_status                    VARCHAR2 (10);
        lc_dev_phase                 VARCHAR2 (10);
        lc_dev_status                VARCHAR2 (10);
        lc_message                   VARCHAR2 (500);
        lc_error_message             VARCHAR2 (1000);
        ln_loop_counter              NUMBER;
        --      ln_line_number         NUMBER;
        ln_france_org_id             NUMBER;
    BEGIN
        gc_code_pointer   := 'Start Interface Load process';
        print_log_prc (p_debug, gc_code_pointer);

        --Start Interface Load process

        ln_loop_counter   := 0;


        FOR rec_france_org_id IN get_france_org_id
        LOOP
            ln_france_org_id   := rec_france_org_id.organization_id;
        END LOOP;

        OPEN invoice_c;

        LOOP
            ln_loop_counter   := ln_loop_counter + 1;
            invoice_info_tbl.delete;

            gc_code_pointer   := 'After invoice_info_tbl.delete';
            print_log_prc (p_debug, gc_code_pointer);

            FETCH invoice_c BULK COLLECT INTO invoice_info_tbl LIMIT gn_limit;

            gc_code_pointer   := 'After  BULK COLLECT INTO invoice_info_tbl';
            print_log_prc (p_debug, gc_code_pointer);


            gc_code_pointer   :=
                   'After  BULK COLLECT INTO  invoice_info_tbl.COUNT - '
                || invoice_info_tbl.COUNT;
            print_log_prc (p_debug, gc_code_pointer);



            IF (invoice_info_tbl.COUNT > 0)
            THEN
                FOR lcu_invoice_rec IN 1 .. invoice_info_tbl.COUNT
                LOOP
                    BEGIN
                        SELECT ap_invoices_interface_s.NEXTVAL
                          INTO ln_invoice_id
                          FROM DUAL;

                        -- Start modification on 06-Aug-2015 for Zero Tax
                        lc_tax_classification_code   := NULL;

                        OPEN get_zero_tax_code_c (
                            invoice_info_tbl (lcu_invoice_rec).org_id);

                        FETCH get_zero_tax_code_c
                            INTO lc_tax_classification_code;

                        CLOSE get_zero_tax_code_c;

                        -- End modification on 06-Aug-2015 for Zero Tax

                        gc_code_pointer              :=
                            'Start Insert into  ap_invoices_interface';
                        print_log_prc (p_debug, gc_code_pointer);
                        print_log_prc (
                            p_debug,
                               'invoice_num '
                            || invoice_info_tbl (lcu_invoice_rec).invoice_num);


                        -- Insert data into ap_invoices_interface table

                        INSERT INTO ap_invoices_interface (
                                        invoice_id,
                                        invoice_num,
                                        invoice_date,
                                        description,
                                        invoice_type_lookup_code,
                                        invoice_amount,
                                        invoice_currency_code,
                                        exchange_rate_type,
                                        exchange_rate,
                                        exchange_date,
                                        vendor_id,
                                        vendor_site_id,
                                        org_id,
                                        terms_id,
                                        --payment_method_lookup_code,
                                        payment_method_code,
                                        gl_date,
                                        goods_received_date,
                                        invoice_received_date,
                                        terms_date,
                                        source,
                                        pay_group_lookup_code,
                                        add_tax_to_inv_amt_flag,
                                        calc_tax_during_import_flag,
                                        GROUP_ID,
                                        attribute_category,
                                        attribute1,
                                        attribute2,
                                        attribute3,
                                        attribute4,
                                        attribute5,
                                        attribute6,
                                        attribute7,
                                        attribute8,
                                        attribute9,
                                        attribute10,
                                        attribute11,
                                        attribute12,
                                        attribute13,
                                        attribute14,
                                        attribute15,
                                        request_id,
                                        creation_date,
                                        created_by,
                                        last_update_date,
                                        last_updated_by)
                                 VALUES (
                                            ln_invoice_id,
                                            invoice_info_tbl (
                                                lcu_invoice_rec).invoice_num,
                                            invoice_info_tbl (
                                                lcu_invoice_rec).invoice_date, -- SYSDATE - 182,
                                            invoice_info_tbl (
                                                lcu_invoice_rec).description,
                                            invoice_info_tbl (
                                                lcu_invoice_rec).invoice_type_lookup_code, --'STANDARD',
                                            invoice_info_tbl (
                                                lcu_invoice_rec).invoice_amount,
                                            invoice_info_tbl (
                                                lcu_invoice_rec).invoice_currency_code,
                                            CASE
                                                WHEN invoice_info_tbl (
                                                         lcu_invoice_rec).exchange_rate
                                                         IS NOT NULL
                                                THEN
                                                    'User'
                                                ELSE
                                                    NULL
                                            END,
                                            invoice_info_tbl (
                                                lcu_invoice_rec).exchange_rate,
                                            invoice_info_tbl (
                                                lcu_invoice_rec).exchange_date,
                                            invoice_info_tbl (
                                                lcu_invoice_rec).new_vendor_id,
                                            invoice_info_tbl (
                                                lcu_invoice_rec).new_vendor_site_id,
                                            invoice_info_tbl (
                                                lcu_invoice_rec).org_id,
                                            invoice_info_tbl (
                                                lcu_invoice_rec).terms_id,
                                            --invoice_info_tbl (lcu_invoice_rec).payment_method_lookup_code,
                                            invoice_info_tbl (
                                                lcu_invoice_rec).payment_method_code,
                                            invoice_info_tbl (
                                                lcu_invoice_rec).gl_date, -- SYSDATE - 182,
                                            invoice_info_tbl (
                                                lcu_invoice_rec).goods_received_date,
                                            invoice_info_tbl (
                                                lcu_invoice_rec).invoice_received_date,
                                            invoice_info_tbl (
                                                lcu_invoice_rec).terms_date,
                                            invoice_info_tbl (
                                                lcu_invoice_rec).source,
                                            invoice_info_tbl (
                                                lcu_invoice_rec).pay_group_lookup_code,
                                            'N',
                                            'N',
                                            invoice_info_tbl (
                                                lcu_invoice_rec).group_num,
                                            'Invoice Global Data Elements',
                                            invoice_info_tbl (
                                                lcu_invoice_rec).attribute1,
                                            invoice_info_tbl (
                                                lcu_invoice_rec).attribute2,
                                            invoice_info_tbl (
                                                lcu_invoice_rec).attribute3,
                                            invoice_info_tbl (
                                                lcu_invoice_rec).attribute4,
                                            invoice_info_tbl (
                                                lcu_invoice_rec).attribute5,
                                            invoice_info_tbl (
                                                lcu_invoice_rec).attribute6,
                                            invoice_info_tbl (
                                                lcu_invoice_rec).attribute7,
                                            invoice_info_tbl (
                                                lcu_invoice_rec).attribute8,
                                            invoice_info_tbl (
                                                lcu_invoice_rec).attribute9,
                                            invoice_info_tbl (
                                                lcu_invoice_rec).attribute10,
                                            invoice_info_tbl (
                                                lcu_invoice_rec).attribute11,
                                            invoice_info_tbl (
                                                lcu_invoice_rec).attribute12,
                                            invoice_info_tbl (
                                                lcu_invoice_rec).attribute13,
                                            invoice_info_tbl (
                                                lcu_invoice_rec).attribute14,
                                            invoice_info_tbl (
                                                lcu_invoice_rec).attribute15,
                                            gn_req_id,
                                            gd_sysdate,
                                            gn_user_id,
                                            gd_sysdate,
                                            gn_user_id);
                    END;

                    gc_code_pointer   :=
                        'After Insert into  ap_invoices_interface';
                    print_log_prc (p_debug, gc_code_pointer);

                    IF inv_line_c%ISOPEN
                    THEN
                        CLOSE inv_line_c;
                    END IF;


                    FOR lcu_inv_line_c
                        IN inv_line_c (
                               invoice_info_tbl (lcu_invoice_rec).old_invoice_id)
                    LOOP
                        ---- Insert data into ap_invoice_lines_interface table

                        --                  ln_line_number := ln_line_number + 1;
                        gc_code_pointer   :=
                            'Before Insert into  ap_invoice_lines_interface';
                        print_log_prc (p_debug, gc_code_pointer);
                        print_log_prc (
                            p_debug,
                            'line_number ' || lcu_inv_line_c.line_number);

                        SELECT ap_invoice_lines_interface_s.NEXTVAL
                          INTO ln_invoice_line_id
                          FROM DUAL;


                        INSERT INTO ap_invoice_lines_interface (
                                        invoice_id,
                                        invoice_line_id,
                                        line_number,
                                        line_type_lookup_code,
                                        amount,
                                        --dist_code_concatenated,
                                        org_id,
                                        description,
                                        accounting_date,
                                        creation_date,
                                        created_by,
                                        last_update_date,
                                        last_updated_by,
                                        /*po_number,
                                        po_line_number,
                                        po_distribution_num,
                                        po_shipment_num,*/
                                        po_header_id,
                                        po_line_id,
                                        --po_distribution_id,
                                        po_line_location_id,
                                        quantity_invoiced,
                                        --                            tax_code,
                                        --                            tax_regime_code,
                                        --                            tax,
                                        dist_code_combination_id,
                                        --                            tax_jurisdiction_code,
                                        --                            tax_status_code,
                                        --                            tax_rate_id,
                                        --                            tax_rate_code,
                                        --                            tax_rate,
                                        --                            tax_code_id,
                                        prorate_across_flag,
                                        attribute_category,
                                        attribute1,
                                        attribute2,
                                        attribute3,
                                        attribute4,
                                        attribute5,
                                        attribute6,
                                        attribute7,
                                        attribute8,
                                        attribute9,
                                        attribute10,
                                        attribute11,
                                        attribute12,
                                        attribute13,
                                        attribute14,
                                        attribute15,
                                        ship_to_location_code,
                                        ship_to_location_id,
                                        tax_classification_code)
                             VALUES (ln_invoice_id, ln_invoice_line_id, --ln_line_number, --
                                                                        lcu_inv_line_c.line_number, DECODE (lcu_inv_line_c.line_type_lookup_code, 'TAX', 'MISCELLANEOUS', lcu_inv_line_c.line_type_lookup_code), lcu_inv_line_c.dist_amount, --invoice_line_info_tbl (lcu_inv_line_rec).concatenated_segments,
                                                                                                                                                                                                                                             lcu_inv_line_c.new_org_id, --lcu_inv_line_c.line_desc,
                                                                                                                                                                                                                                                                        lcu_inv_line_c.description, lcu_inv_line_c.accounting_date, gd_sysdate, gn_user_id, gd_sysdate, gn_user_id, /*lcu_inv_line_c.po_number,
                                                                                                                                                                                                                                                                                                                                                                                    lcu_inv_line_c.po_line_number,
                                                                                                                                                                                                                                                                                                                                                                                    lcu_inv_line_c.po_distribution_num,
                                                                                                                                                                                                                                                                                                                                                                                    lcu_inv_line_c.po_shipment_num,*/
                                                                                                                                                                                                                                                                                                                                                                                    lcu_inv_line_c.new_po_header_id, lcu_inv_line_c.new_po_line_id, --lcu_inv_line_c.new_po_distribution_id,
                                                                                                                                                                                                                                                                                                                                                                                                                                                    lcu_inv_line_c.new_line_location_id, lcu_inv_line_c.quantity_invoiced, --                            lcu_inv_line_c.tax_code,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           --                            lcu_inv_line_c.tax_regime_code,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           --                            lcu_inv_line_c.tax,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           lcu_inv_line_c.new_dist_ccid, --                            lcu_inv_line_c.tax_jurisdiction_code,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         --                            lcu_inv_line_c.tax_status_code,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         --                            lcu_inv_line_c.tax_rate_id,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         --                            lcu_inv_line_c.tax_rate_code,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         --                            lcu_inv_line_c.tax_rate,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         --                            lcu_inv_line_c.tax_code_id,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         lcu_inv_line_c.prorate_across_flag, 'Invoice Lines Data Elements', lcu_inv_line_c.attribute1, lcu_inv_line_c.attribute2, lcu_inv_line_c.attribute3, lcu_inv_line_c.attribute4, lcu_inv_line_c.attribute5, lcu_inv_line_c.attribute6, lcu_inv_line_c.attribute7, lcu_inv_line_c.attribute8, lcu_inv_line_c.attribute9, lcu_inv_line_c.attribute10, lcu_inv_line_c.attribute11, lcu_inv_line_c.attribute12, lcu_inv_line_c.attribute13, lcu_inv_line_c.attribute14, lcu_inv_line_c.attribute15, NULL, --lcu_inv_line_c.ship_to_location_code,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             lcu_inv_line_c.ship_to_location_id
                                     , -- Start modification on 06-Aug-2015 for Zero Tax
                                       /*CASE
                                          WHEN lcu_inv_line_c.new_org_id =
                                                  ln_france_org_id
                                          THEN
                                             'FR VAT RT 0'
                                          ELSE
                                             NULL
                                       END*/
                                       lc_tax_classification_code-- End modification on 06-Aug-2015 for Zero Tax
                                                                 );

                        gc_code_pointer   :=
                            'After Insert into  ap_invoice_lines_interface';
                        print_log_prc (p_debug, gc_code_pointer);
                    END LOOP;
                /*
                               OPEN GET_GROUP_LINE_C (invoice_info_tbl (lcu_invoice_rec).old_invoice_id);

                               ln_line_number := 0;

                               LOOP
                                  FETCH GET_GROUP_LINE_C INTO LCU_GET_GROUP_LINE_C;

                                  EXIT WHEN GET_GROUP_LINE_C%NOTFOUND;

                                  OPEN inv_line_c (invoice_info_tbl (lcu_invoice_rec).old_invoice_id);

                                  FETCH inv_line_c INTO lcu_inv_line_c;

                                  CLOSE inv_line_c;

                                  ---- Insert data into ap_invoice_lines_interface table

                                  ln_line_number := ln_line_number + 1;

                                  SELECT ap_invoice_lines_interface_s.NEXTVAL
                                    INTO ln_invoice_line_id
                                    FROM DUAL;


                                  INSERT
                                    INTO ap_invoice_lines_interface (
                                            invoice_id,
                                            invoice_line_id,
                                            line_number,
                                            line_type_lookup_code,
                                            amount,
                                            --dist_code_concatenated,
                                            org_id,
                                            description,
                                            accounting_date,
                                            creation_date,
                                            created_by,
                                            last_update_date,
                                            last_updated_by,
                                            PO_NUMBER,
                                            PO_LINE_NUMBER,
                                            PO_DISTRIBUTION_NUM,
                                            PO_SHIPMENT_NUM,
                                            po_header_id,
                                            po_line_id,
                                            po_distribution_id,
                                            po_line_location_id,
                                            tax_code,
                                            TAX_REGIME_CODE,
                                            tax,
                                            DIST_CODE_COMBINATION_ID,
                                            TAX_JURISDICTION_CODE,
                                            tax_status_code,
                                            TAX_RATE_ID,
                                            TAX_RATE_CODE,
                                            TAX_RATE,
                                            TAX_CODE_ID,
                                            PRORATE_ACROSS_FLAG,
                                            ship_to_location_code)
                                  VALUES (
                                            ln_invoice_id,
                                            ln_invoice_line_id,
                                            ln_line_number,
                                            DECODE (
                                               LCU_GET_GROUP_LINE_C.line_type_lookup_code,
                                               'TAX', 'MISCELLANEOUS',
                                               LCU_GET_GROUP_LINE_C.line_type_lookup_code),
                                            LCU_GET_GROUP_LINE_C.di_amount,
                                            --invoice_line_info_tbl (lcu_inv_line_rec).concatenated_segments,
                                            lcu_inv_line_c.NEW_ORG_ID,
                                            --lcu_inv_line_c.line_desc,
                                            lcu_inv_line_c.description,
                                            lcu_inv_line_c.accounting_date,
                                            gd_sysdate,
                                            gn_user_id,
                                            gd_sysdate,
                                            gn_user_id,
                                            lcu_inv_line_c.PO_NUMBER,
                                            lcu_inv_line_c.PO_LINE_NUMBER,
                                            lcu_inv_line_c.PO_DISTRIBUTION_NUM,
                                            lcu_inv_line_c.PO_SHIPMENT_NUM,
                                            lcu_inv_line_c.new_po_header_id,
                                            lcu_inv_line_c.new_po_line_id,
                                            lcu_inv_line_c.new_po_distribution_id,
                                            lcu_inv_line_c.new_line_location_id,
                                            lcu_inv_line_c.tax_code,
                                            lcu_inv_line_c.tax_regime_code,
                                            lcu_inv_line_c.tax,
                                            LCU_GET_GROUP_LINE_C.NEW_DIST_CCID,
                                            lcu_inv_line_c.TAX_JURISDICTION_CODE,
                                            lcu_inv_line_c.tax_status_code,
                                            lcu_inv_line_c.TAX_RATE_ID,
                                            lcu_inv_line_c.TAX_RATE_CODE,
                                            lcu_inv_line_c.TAX_RATE,
                                            lcu_inv_line_c.TAX_CODE_ID,
                                            lcu_inv_line_c.PRORATE_ACROSS_FLAG,
                                            NULL        --lcu_inv_line_c.ship_to_location_code
                                                );
                               END LOOP;

                               CLOSE GET_GROUP_LINE_C;
                               */
                END LOOP;
            END IF;

            UPDATE xxd_ap_invoice_conv_stg_t xaic
               SET record_status   = 'L'
             WHERE     1 = 1
                   AND record_status = 'V'
                   AND EXISTS
                           (SELECT 1
                              FROM ap_invoices_interface aia
                             WHERE     aia.invoice_num = xaic.invoice_num
                                   AND aia.vendor_id = xaic.new_vendor_id);

            UPDATE xxd_ap_invoice_dist_conv_stg_t xaid
               SET record_status   = 'L'
             WHERE     1 = 1
                   AND record_status = 'V'
                   AND EXISTS
                           (SELECT 1
                              FROM xxd_ap_invoice_conv_stg_t xaic
                             WHERE     xaid.old_invoice_id =
                                       xaic.old_invoice_id
                                   AND xaic.record_status = 'L');


            IF ln_loop_counter = gn_limit
            THEN
                COMMIT;
                ln_loop_counter   := 0;
            END IF;

            EXIT WHEN invoice_c%NOTFOUND;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'OTHERS Exception while Insert into Interface Table');

            fnd_file.put_line (fnd_file.LOG, SQLCODE || ' : ' || SQLERRM);

            xxd_common_utils.record_error (
                'APINV',
                xxd_common_utils.get_org_id,
                'Deckers AP Invoice Conversion Program',
                DBMS_UTILITY.format_error_backtrace,
                gn_user_id,
                gn_req_id,
                'Code pointer : ' || gc_code_pointer,
                'Interface Table');
    END interface_load_prc;



    /******************************************************
            * Procedure: XXD_AP_INVOICE_MAIN_PRC
            *
            * Synopsis: This procedure will call we be called by the concurrent program
            * Design:
            *
            * Notes:
            *
            * PARAMETERS:
            *   OUT: (x_retcode  Number
            *   OUT: x_errbuf  Varchar2
            *   IN    : p_process  varchar2
            *   IN    : p_debug  varchar2
            *
            * Return Values:
            * Modifications:
            *
            ******************************************************/

    PROCEDURE xxd_ap_invoice_main_prc (x_retcode OUT NUMBER, x_errbuf OUT VARCHAR2, p_process IN VARCHAR2
                                       , p_debug IN VARCHAR2, p_batch_size IN NUMBER, p_gl_date IN VARCHAR2)
    IS
        x_errcode                     VARCHAR2 (500);
        x_errmsg                      VARCHAR2 (500);
        lc_debug_flag                 VARCHAR2 (1);
        ln_eligible_records           NUMBER;
        ln_total_valid_records        NUMBER;
        ln_total_error_records        NUMBER;
        ln_total_load_records         NUMBER;
        ln_batch_low                  NUMBER;
        ln_total_batch                NUMBER;
        ln_request_id                 NUMBER;
        lc_phase                      VARCHAR2 (100);
        lc_status                     VARCHAR2 (100);
        lc_dev_phase                  VARCHAR2 (100);
        lc_dev_status                 VARCHAR2 (100);
        lc_message                    VARCHAR2 (100);
        lb_wait_for_request           BOOLEAN := FALSE;
        lb_get_request_status         BOOLEAN := FALSE;
        request_submission_failed     EXCEPTION;
        request_completion_abnormal   EXCEPTION;

        TYPE request_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_req_id                      request_table;
        ln_counter                    NUMBER;
        ln_loop_counter               NUMBER := 0;
    --      CURSOR invoice_org_c
    --      IS
    --         SELECT DISTINCT org_id
    --           FROM ap_invoices_interface
    --          WHERE status = 'REJCTED' OR status IS NULL;
    --
    --      TYPE invoice_info_org_type IS TABLE OF invoice_org_c%ROWTYPE
    --                                       INDEX BY BINARY_INTEGER;

    --invoice_info_org_tbl          invoice_info_org_type;
    BEGIN
        gc_debug_flag   := p_debug;
        gn_gl_date      := fnd_date.canonical_to_date (p_gl_date);
        --gn_gl_date := TO_DATE (p_gl_date, 'RRRR/MM/DD HH24:MI:SS');

        fnd_file.put_line (fnd_file.LOG, 'Params:');


        fnd_file.put_line (fnd_file.LOG, 'PROCESS: ' || p_process);

        fnd_file.put_line (fnd_file.LOG, 'DEBUG: ' || p_debug);
        fnd_file.put_line (fnd_file.LOG, 'BATCH SIZE: ' || p_batch_size);
        fnd_file.put_line (fnd_file.LOG, 'GL_DATE: ' || p_gl_date);

        fnd_file.put_line (fnd_file.LOG, 'GN_GL_DATE: ' || gn_gl_date);



        -- EXTRACT
        IF p_process = 'EXTRACT'
        THEN
            IF p_debug = 'Y'
            THEN
                gc_code_pointer   := 'Calling Extract process  ';
                fnd_file.put_line (fnd_file.LOG,
                                   'Code Pointer: ' || gc_code_pointer);
            END IF;

            -- Calling Extract procedure

            extract_invoice_proc;
        --

        ELSIF p_process = 'VALIDATE'
        THEN
            ln_eligible_records      := 0;
            ln_batch_low             := 0;
            ln_total_batch           := 0;
            ln_total_valid_records   := 0;
            ln_total_error_records   := 0;

            --Checking if there are eligible records in staging table for Validation Interface


            SELECT COUNT (*)
              INTO ln_eligible_records
              FROM xxd_ap_invoice_conv_stg_t
             WHERE record_status IN ('N', 'E');

            IF ln_eligible_records > 0
            THEN
                -- Calling Create bathc Process to create divide recors in the staging table into batches.

                create_batch_prc (x_retcode, x_errbuf, p_batch_size,
                                  p_debug);


                -- Fetching Max Batch Number

                SELECT MAX (batch_number)
                  INTO ln_total_batch
                  FROM xxd_ap_invoice_conv_stg_t
                 WHERE record_status IN ('N', 'E');

                -- Fetching Min Batch Number

                SELECT MIN (batch_number)
                  INTO ln_batch_low
                  FROM xxd_ap_invoice_conv_stg_t
                 WHERE record_status IN ('N', 'E');

                l_req_id.delete;

                -- Looping to launch Validate worker
                ln_loop_counter   := -1;

                FOR l_cnt IN ln_batch_low .. ln_total_batch
                LOOP
                    ln_loop_counter   := ln_loop_counter + 1;

                    -- Check if each batch has eligible recors ,if so launch worker program

                    SELECT COUNT (*)
                      INTO ln_counter
                      FROM xxd_ap_invoice_conv_stg_t
                     WHERE     record_status IN ('N', 'E')
                           AND batch_number = l_cnt;

                    IF ln_counter > 0
                    THEN
                        ln_request_id   :=
                            fnd_request.submit_request (
                                application   => 'XXDCONV',
                                program       =>
                                    'XXD_AP_INVOICE_CONV_VAL_WORK',
                                description   =>
                                    'Deckers AP Invoice Conversion - Validate',
                                start_time    => gd_sysdate,
                                sub_request   => NULL,
                                argument1     => l_cnt,
                                argument2     => l_cnt,
                                argument3     => p_debug);


                        IF ln_request_id > 0
                        THEN
                            COMMIT;
                            l_req_id (ln_loop_counter)   := ln_request_id;
                        ELSE
                            ROLLBACK;
                        END IF;
                    END IF;
                END LOOP;

                --Waits for the Child requests completion
                FOR rec IN l_req_id.FIRST .. l_req_id.LAST
                LOOP
                    BEGIN
                        IF l_req_id (rec) IS NOT NULL
                        THEN
                            LOOP
                                lc_dev_phase    := NULL;
                                lc_dev_status   := NULL;
                                lb_wait_for_request   :=
                                    fnd_concurrent.wait_for_request (
                                        request_id   => l_req_id (rec),
                                        interval     => 1,
                                        max_wait     => 1,
                                        phase        => lc_phase,
                                        status       => lc_status,
                                        dev_phase    => lc_dev_phase,
                                        dev_status   => lc_dev_status,
                                        MESSAGE      => lc_message);

                                IF ((UPPER (lc_dev_phase) = 'COMPLETE') OR (UPPER (lc_phase) = 'COMPLETED'))
                                THEN
                                    EXIT;
                                END IF;
                            END LOOP;
                        ELSE
                            RAISE request_submission_failed;
                        END IF;
                    EXCEPTION
                        WHEN request_submission_failed
                        THEN
                            print_log_prc (
                                p_debug,
                                   'Child Concurrent request submission failed - '
                                || ' XXD_AP_INV_CONV_VAL_WORK - '
                                || ln_request_id
                                || ' - '
                                || SQLERRM);
                        WHEN request_completion_abnormal
                        THEN
                            print_log_prc (
                                p_debug,
                                   'Submitted request completed with error'
                                || ' XXD_AP_INVOICE_CONV_VAL_WORK - '
                                || ln_request_id);
                        WHEN OTHERS
                        THEN
                            print_log_prc (
                                p_debug,
                                   'XXD_AP_INVOICE_CONV_VAL_WORK ERROR: '
                                || SUBSTR (SQLERRM, 0, 240));
                    END;
                END LOOP;

                COMMIT;



                SELECT COUNT (*)
                  INTO ln_total_valid_records
                  FROM xxd_ap_invoice_conv_stg_t
                 WHERE     record_status = 'V'
                       AND batch_number BETWEEN ln_batch_low
                                            AND ln_total_batch;

                SELECT COUNT (*)
                  INTO ln_total_error_records
                  FROM xxd_ap_invoice_conv_stg_t
                 WHERE     record_status = 'E'
                       AND batch_number BETWEEN ln_batch_low
                                            AND ln_total_batch;

                -- Writing count to the output file

                fnd_file.put_line (fnd_file.output, '');
                fnd_file.put_line (
                    fnd_file.output,
                       RPAD ('S No.    Entity', 50)
                    || RPAD ('Total_Records', 20)
                    || RPAD ('Total_Records_Valid', 20)
                    || RPAD ('Total_Records_Error', 20));
                fnd_file.put_line (
                    fnd_file.output,
                    RPAD (
                        '********************************************************************************************************************************',
                        120));
                fnd_file.put_line (
                    fnd_file.output,
                       RPAD ('1  AP Invoices', 50)
                    || RPAD (ln_eligible_records, 20)
                    || RPAD (ln_total_valid_records, 20)
                    || RPAD (ln_total_error_records, 20));
            ELSE
                print_log_prc (
                    p_debug,
                    'No Eligible Records for Validate Found - ' || SQLERRM);
            END IF;
        --LOAD

        ELSIF p_process = 'LOAD'
        THEN
            ln_eligible_records      := 0;
            ln_batch_low             := 0;
            ln_total_batch           := 0;
            ln_total_load_records    := 0;
            ln_total_error_records   := 0;

            --Checking if there are eligible records in staging table for Load

            SELECT COUNT (*)
              INTO ln_eligible_records
              FROM xxd_ap_invoice_conv_stg_t
             WHERE record_status = 'V' AND batch_number IS NOT NULL;

            IF ln_eligible_records > 0
            THEN
                -- Fetching Max Batch Number

                SELECT MAX (batch_number)
                  INTO ln_total_batch
                  FROM xxd_ap_invoice_conv_stg_t
                 WHERE record_status = 'V' AND batch_number IS NOT NULL;

                -- Fetching Min Batch Number

                SELECT MIN (batch_number)
                  INTO ln_batch_low
                  FROM xxd_ap_invoice_conv_stg_t
                 WHERE record_status = 'V' AND batch_number IS NOT NULL;

                l_req_id.delete;

                --Looping though batch number to launch Load worker
                ln_loop_counter   := -1;

                FOR l_cnt IN ln_batch_low .. ln_total_batch
                LOOP
                    ln_loop_counter   := ln_loop_counter + 1;

                    -- Checking if each batch number has eligible records,if so launch load worker

                    SELECT COUNT (*)
                      INTO ln_counter
                      FROM xxd_ap_invoice_conv_stg_t
                     WHERE record_status = 'V' AND batch_number = l_cnt;

                    IF ln_counter > 0
                    THEN
                        ln_request_id   :=
                            fnd_request.submit_request (
                                application   => 'XXDCONV',
                                program       =>
                                    'XXD_AP_INVOICE_CONV_LOAD_WORK',
                                description   =>
                                    'Deckers AP Invoice Conversion - Load',
                                start_time    => gd_sysdate,
                                sub_request   => NULL,
                                argument1     => l_cnt,
                                argument2     => l_cnt,
                                argument3     => p_debug);


                        IF ln_request_id > 0
                        THEN
                            l_req_id (ln_loop_counter)   := ln_request_id;
                            COMMIT;
                        ELSE
                            ROLLBACK;
                        END IF;
                    END IF;
                END LOOP;


                --Waits for the Child requests completion
                FOR rec IN l_req_id.FIRST .. l_req_id.LAST
                LOOP
                    BEGIN
                        IF l_req_id (rec) IS NOT NULL
                        THEN
                            LOOP
                                lc_dev_phase    := NULL;
                                lc_dev_status   := NULL;
                                lb_wait_for_request   :=
                                    fnd_concurrent.wait_for_request (
                                        request_id   => l_req_id (rec),
                                        interval     => 1,
                                        max_wait     => 1,
                                        phase        => lc_phase,
                                        status       => lc_status,
                                        dev_phase    => lc_dev_phase,
                                        dev_status   => lc_dev_status,
                                        MESSAGE      => lc_message);
                                COMMIT;

                                IF ((UPPER (lc_dev_phase) = 'COMPLETE') OR (UPPER (lc_phase) = 'COMPLETED'))
                                THEN
                                    EXIT;
                                END IF;
                            END LOOP;
                        ELSE
                            RAISE request_submission_failed;
                        END IF;
                    EXCEPTION
                        WHEN request_submission_failed
                        THEN
                            print_log_prc (
                                p_debug,
                                   'Child Concurrent request submission failed - '
                                || ' XXD_AP_INVOICE_CONV_LOAD_WORK - '
                                || ln_request_id
                                || ' - '
                                || SQLERRM);
                        WHEN request_completion_abnormal
                        THEN
                            print_log_prc (
                                p_debug,
                                   'Submitted request completed with error'
                                || ' XXD_AP_INVOICE_CONV_LOAD_WORK - '
                                || ln_request_id);
                        WHEN OTHERS
                        THEN
                            print_log_prc (
                                p_debug,
                                   'XXD_AP_INVOICE_CONV_VAL_WORK ERROR:'
                                || SUBSTR (SQLERRM, 0, 240));
                    END;
                END LOOP;


                --            invoice_info_org_tbl.delete;
                --
                --            gc_code_pointer := 'After invoice_info_org_tbl.delete';
                --            print_log_prc (p_debug, gc_code_pointer);
                --
                --            --Fetch Distinct org_id from Interface tables that are not processed or in error.
                --
                --            OPEN invoice_org_c;
                --
                --            FETCH invoice_org_c
                --            BULK COLLECT INTO invoice_info_org_tbl;
                --
                --            CLOSE invoice_org_c;
                --
                --            gc_code_pointer := 'After  BULK COLLECT INTO invoice_info_org_tbl';
                --            print_log_prc (p_debug, gc_code_pointer);
                --
                --
                --            gc_code_pointer :=
                --                  'After  BULK COLLECT INTO  invoice_info_org_tbl.COUNT - '
                --               || invoice_info_org_tbl.COUNT;
                --            print_log_prc (p_debug, gc_code_pointer);

                --If above fetched org_id has count > 1 call import_invoice _from_interface for each org_id

                --            IF (invoice_info_org_tbl.COUNT > 0)
                --            THEN
                --               FOR lcu_invoice_rec IN 1 .. invoice_info_org_tbl.COUNT
                --               LOOP
                --                  import_invoice_from_interface (
                --                     p_org_id       => invoice_info_org_tbl (lcu_invoice_rec).org_id,
                --                     p_debug_flag   => p_debug);
                --
                --                  validate_invoice (
                --                     p_org_id       => invoice_info_org_tbl (lcu_invoice_rec).org_id,
                --                     p_debug_flag   => p_debug);
                --               END LOOP;
                --            END IF;



                SELECT COUNT (*)
                  INTO ln_total_load_records
                  FROM xxd_ap_invoice_conv_stg_t
                 WHERE     record_status = 'V'
                       AND batch_number BETWEEN ln_batch_low
                                            AND ln_total_batch;

                SELECT COUNT (*)
                  INTO ln_total_error_records
                  FROM xxd_ap_invoice_conv_stg_t
                 WHERE                          --book_type_code = p_book_type
                           record_status = 'E'
                       AND batch_number BETWEEN ln_batch_low
                                            AND ln_total_batch;

                --Writing counts to output file

                fnd_file.put_line (fnd_file.output, '');
                fnd_file.put_line (
                    fnd_file.output,
                       RPAD ('S No.    Entity', 50)
                    || RPAD ('Total_Records', 20)
                    || RPAD ('Total_Records_Load', 20)
                    || RPAD ('Total_Records_Error', 20));
                fnd_file.put_line (
                    fnd_file.output,
                    RPAD (
                        '********************************************************************************************************************************',
                        120));
                fnd_file.put_line (
                    fnd_file.output,
                       RPAD ('1     AP Invoices', 50)
                    || RPAD (ln_eligible_records, 20)
                    || RPAD (ln_total_load_records, 20)
                    || RPAD (ln_total_error_records, 20));
            ELSE
                print_log_prc (
                    p_debug,
                    'No Eligible Records for Load Found - ' || SQLERRM);
            END IF;
        ELSE
            fnd_file.put_line (fnd_file.LOG, 'Please select a valid process');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Code Pointer: ' || gc_code_pointer);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Messgae: '
                || 'Unexpected error in AP Invoice Conversion '
                || SUBSTR (1, 250));
            fnd_file.put_line (fnd_file.LOG, '');
            x_retcode   := 2;
            x_errbuf    :=
                'Error Message extract_cust_prc ' || SUBSTR (1, 250);
    END xxd_ap_invoice_main_prc;


    /****************************************************************************************
        * Procedure : VALIDATE_RECORDS_PRC
        * Synopsis  : This Procedure is called by val_load_main_prc Main procedure
        * Design    : Procedure validates data for AP Invoice conversion
        * Notes     :
        * Return Values: None
        * Modification :
        * Date          Developer     Version    Description
        *--------------------------------------------------------------------------------------
        * 07-JUL-2014   Swapna N        1.00       Created
        ****************************************************************************************/

    PROCEDURE validate_records_prc (x_retcode         OUT NUMBER,
                                    x_errbuff         OUT VARCHAR2,
                                    p_batch_low    IN     NUMBER,
                                    p_batch_high   IN     NUMBER,
                                    p_debug        IN     VARCHAR2)
    AS
        CURSOR invoice_c IS
            SELECT *
              FROM xxd_ap_invoice_conv_stg_t xaid
             WHERE     batch_number BETWEEN p_batch_low AND p_batch_high --Srinivas
                   --AND old_invoice_id = 82502222
                   AND record_status IN ('E', 'N')
                   AND EXISTS
                           (SELECT 1
                              FROM xxd_ap_invoice_dist_conv_stg_t
                             WHERE xaid.old_invoice_id = old_invoice_id);

        --      CURSOR chk_valid_inv_c (p_invoice_id NUMBER)    --Added by Ankur Khurana
        --      IS
        --         SELECT old_invoice_id
        --           FROM XXD_AP_INVOICE_CONV_STG_T XAID
        --          WHERE     old_invoice_id = p_invoice_id
        --                AND record_status IN ('E', 'N')
        --                AND EXISTS
        --                       (SELECT 1
        --                          FROM XXD_AP_INVOICE_DIST_CONV_STG_T
        --                         WHERE xaid.old_invoice_id = old_invoice_id);


        CURSOR invoice_line_c (p_invoice_id NUMBER)
        IS
            SELECT *
              FROM xxd_ap_invoice_dist_conv_stg_t
             WHERE     record_status IN ('E', 'N')
                   AND old_invoice_id = p_invoice_id;


        CURSOR invoice_type_c (p_lookup_code VARCHAR2)
        IS
            SELECT lookup_code
              FROM fnd_lookup_values
             WHERE     lookup_type LIKE 'INVOICE TYPE'
                   AND end_date_active IS NULL
                   AND lookup_code = p_lookup_code;



        CURSOR invoice_line_type_c (p_lookup_code VARCHAR2)
        IS
            SELECT DISTINCT lookup_code
              FROM fnd_lookup_values
             WHERE     lookup_type LIKE 'INVOICE LINE TYPE'
                   AND end_date_active IS NULL
                   AND lookup_code = p_lookup_code;



        CURSOR chk_line_c (p_invoice_id NUMBER)
        IS
            SELECT old_invoice_id
              FROM xxd_ap_invoice_dist_conv_stg_t dist
             WHERE dist.old_invoice_id = p_invoice_id;

        CURSOR get_new_payment_details (p_vendor_id        NUMBER,
                                        p_vendor_site_id   NUMBER)
        IS
            SELECT NVL (asa.pay_group_lookup_code, ass.pay_group_lookup_code) pay_group_lookup_code, NVL (ieppm1.payment_method_code, ieppm.payment_method_code) payment_method_code
              FROM ap_suppliers asa, iby_ext_party_pmt_mthds ieppm, iby_external_payees_all iepa,
                   iby_ext_party_pmt_mthds ieppm1, iby_external_payees_all iepa1, ap_supplier_sites_all ass
             WHERE     1 = 1
                   AND asa.vendor_id = ass.vendor_id
                   AND asa.party_id = iepa.payee_party_id
                   AND iepa.ext_payee_id = ieppm.ext_pmt_party_id(+)
                   AND iepa.payment_function = 'PAYABLES_DISB'
                   AND iepa.org_type IS NULL
                   AND asa.party_id = iepa1.payee_party_id
                   AND iepa1.supplier_site_id = ass.vendor_site_id
                   AND iepa1.ext_payee_id = ieppm1.ext_pmt_party_id(+)
                   AND iepa1.payment_function = 'PAYABLES_DISB'
                   AND iepa1.org_type = 'OPERATING_UNIT'
                   AND asa.vendor_id = p_vendor_id
                   AND ass.vendor_site_id = p_vendor_site_id;


        CURSOR chk_invoice_c (p_invoice_num VARCHAR2, p_invoice_id NUMBER)
        IS
            SELECT invoice_num
              --FROM ap_invoices
              FROM ap_invoices_all
             WHERE invoice_num = p_invoice_num AND vendor_id = p_invoice_id;


        CURSOR term_id_c (p_term_name VARCHAR2)
        IS
            SELECT term_id
              FROM ap_terms
             WHERE     UPPER (name) = UPPER (p_term_name)
                   AND enabled_flag = 'Y'
                   AND end_date_active IS NULL;

        CURSOR chk_po_reciepts (po_number         VARCHAR2,
                                po_line_num       NUMBER,
                                po_shipment_num   NUMBER                   --,
                                                        --po_dist_num        NUMBER
                                                        )
        IS
            SELECT poh.po_header_id, pol.po_line_id, pod.po_distribution_id,
                   pll.line_location_id, pll.ship_to_location_id, poh.authorization_status
              FROM po_headers_all poh, po_lines_all pol, po_line_locations_all pll,
                   po_distributions_all pod
             WHERE     1 = 1
                   AND poh.po_header_id = pol.po_header_id
                   AND poh.po_header_id = pll.po_header_id
                   AND poh.po_header_id = pod.po_header_id
                   AND pol.po_line_id = pll.po_line_id
                   AND pll.po_line_id = pod.po_line_id
                   AND pll.line_location_id = pod.line_location_id
                   AND poh.segment1 = po_number
                   AND pol.line_num = po_line_num
                   AND NVL (pll.shipment_num, -1) =
                       NVL (NVL (po_shipment_num, pll.shipment_num), -1);

        ln_shipment_num              NUMBER;
        ln_po_header_id              NUMBER;
        ln_po_line_id                NUMBER;
        ln_po_distribution_id        NUMBER;
        ln_po_line_loc_id            NUMBER;
        ln_ship_to_location_id       NUMBER;
        lc_authorization_status      VARCHAR2 (40);

        CURSOR chk_source_c (p_source VARCHAR2)
        IS
            SELECT lookup_code
              FROM fnd_lookup_values
             WHERE     UPPER (lookup_code) = UPPER (p_source)
                   AND end_date_active IS NULL
                   AND lookup_type = 'SOURCE'
                   AND enabled_flag = 'Y';



        --Start modification by Naveen on 24-Jun-2015
        /*CURSOR vendor_id_c (p_vendor_name VARCHAR2)
        IS
           SELECT vendor_id
             FROM ap_suppliers
            WHERE vendor_name = p_vendor_name;*/
        CURSOR vendor_id_c (p_vendor_num VARCHAR2)
        IS
            SELECT vendor_id
              FROM ap_suppliers
             WHERE segment1 = p_vendor_num;

        --End Modification by Naveen on 24-Jun-2015



        CURSOR vendor_site_id_c (p_vendor_id NUMBER, p_vendor_site_code VARCHAR2, p_org_id NUMBER)
        IS
            SELECT vendor_site_id
              FROM ap_supplier_sites_all
             WHERE     vendor_id = p_vendor_id
                   AND org_id = p_org_id
                   AND vendor_site_code = p_vendor_site_code;



        CURSOR pmt_code_c (p_pmt_code VARCHAR2)
        IS
            SELECT payment_method_code
              FROM iby_payment_methods_vl
             WHERE     UPPER (payment_method_code) = p_pmt_code
                   AND inactive_date IS NULL;



        CURSOR paygrp_code_c (p_pay_grp_lkp_code VARCHAR2)
        IS
            SELECT lookup_code
              FROM fnd_lookup_values_vl
             WHERE     UPPER (lookup_code) = UPPER (p_pay_grp_lkp_code)
                   AND end_date_active IS NULL
                   AND lookup_type = 'PAY GROUP';

        lc_p_pay_grp_lkp_code        VARCHAR2 (100);


        CURSOR chk_period_status_c (p_accounting_date DATE, ln_sob_id NUMBER)
        IS
            SELECT 1
              FROM gl_period_statuses gps, fnd_application_vl fa
             WHERE     set_of_books_id = ln_sob_id
                   AND closing_status = 'O'
                   AND fa.application_id = gps.application_id
                   AND fa.application_short_name = 'SQLAP'
                   AND p_accounting_date BETWEEN start_date AND end_date;

        CURSOR chk_inv (p_invoice_num VARCHAR2, --Start modification by Naveen on 24-Jun-2015
                                                --p_vendor_name    VARCHAR2)
                                                p_vendor_num VARCHAR2)
        --End modification by Naveen on 24-Jun-2015
        IS
            SELECT 1
              FROM ap_invoices_all aia, ap_suppliers sup
             WHERE     aia.invoice_num = p_invoice_num
                   --Start modification by Naveen on 24-Jun-2015
                   --AND sup.vendor_name = p_vendor_name
                   AND sup.segment1 = p_vendor_num
                   --End modification by Naveen on 24-Jun-2015
                   AND aia.vendor_id = sup.vendor_id;

        -- Start modification by BT Technology team on 30-Sep-15
        CURSOR get_liability_company (p_org_id NUMBER)
        IS
            SELECT gcc.segment1
              FROM financials_system_params_all fsp, apps.gl_code_combinations_kfv gcc
             WHERE     fsp.org_id = p_org_id
                   AND fsp.accts_pay_code_combination_id =
                       gcc.code_combination_id;

        CURSOR get_default_distribution (p_org_id NUMBER)
        IS
            SELECT flv.description
              FROM fnd_lookup_values_vl flv, hr_operating_units hou
             WHERE     flv.lookup_type = 'XXD_OU_DEFAULT_CODE_MAPPING'
                   AND flv.meaning = hou.name
                   AND hou.organization_id = p_org_id;

        -- End modification by BT Technology team on 30-Sep-15

        ln_no                        NUMBER;



        TYPE invoice_info_type IS TABLE OF invoice_c%ROWTYPE
            INDEX BY BINARY_INTEGER;

        invoice_info_tbl             invoice_info_type;


        TYPE invoice_line_info_type IS TABLE OF invoice_line_c%ROWTYPE
            INDEX BY BINARY_INTEGER;

        invoice_line_info_tbl        invoice_line_info_type;

        lc_lookup_code               fnd_lookup_values.lookup_code%TYPE;
        lc_line_lookup_code          fnd_lookup_values.lookup_code%TYPE;
        ln_invoice_id                NUMBER;
        ln_vendor_site_id            NUMBER;
        lc_payment_method_code       VARCHAR2 (100);
        lc_payment_method_code_chk   VARCHAR2 (100);
        ln_invoice_num               VARCHAR2 (50);
        lc_source                    VARCHAR2 (100);
        ln_term_id                   NUMBER;
        ln_vendor_id                 NUMBER;
        --ln_indx                  NUMBER;
        lc_recvalidation             VARCHAR2 (1);
        lc_rec_line_validation       VARCHAR2 (1);
        lc_h_err_msg                 VARCHAR2 (1000);
        lc_l_err_msg                 VARCHAR2 (1000);
        lc_error_code                VARCHAR2 (100);
        lc_err_message               VARCHAR2 (1000);
        l_valid_combination          BOOLEAN;
        l_cr_combination             BOOLEAN;
        ln_ccid                      gl_code_combinations.code_combination_id%TYPE;
        -- Start modification by BT Technology team on 30-Sep-15
        lc_liability_company         gl_code_combinations_kfv.segment1%TYPE;
        lc_default_conc_segs         gl_code_combinations_kfv.concatenated_segments%TYPE;
        -- End modification by BT Technology team on 30-Sep-15
        lc_conc_segs                 gl_code_combinations_kfv.concatenated_segments%TYPE;
        p_error_msg1                 VARCHAR2 (2400);
        p_error_msg2                 VARCHAR2 (2400);
        lc_coa_id                    gl_code_combinations_kfv.chart_of_accounts_id%TYPE;
        ln_err_count                 NUMBER;
        ln_line_err_count            NUMBER;
        ln_lines_err_count           NUMBER;
        ln_org_id                    NUMBER;
        lc_org_name                  VARCHAR2 (100);
        lc_new_conc_segs             gl_code_combinations_kfv.concatenated_segments%TYPE;
        ln_sob_id                    NUMBER;
        lc_pay_group                 VARCHAR2 (40);
        lc_supp_pay_group            VARCHAR2 (40);
        lc_supp_pmt_method_code      VARCHAR2 (40);
        ln_inv_chk                   NUMBER;
        lc_encoded_message           VARCHAR2 (4000);
        ln_exchange_rate             xxd_ap_invoice_conv_stg_t.exchange_rate%TYPE;
        lc_exchange_rate_type        xxd_ap_invoice_conv_stg_t.exchange_rate_type%TYPE;
        ld_exchange_date             xxd_ap_invoice_conv_stg_t.exchange_date%TYPE;
        lc_ledger_currency           gl_ledgers.currency_code%TYPE;
    BEGIN
        OPEN invoice_c;

        LOOP
            invoice_info_tbl.delete;

            FETCH invoice_c BULK COLLECT INTO invoice_info_tbl LIMIT gn_limit;



            IF (invoice_info_tbl.COUNT > 0)
            THEN
                FOR lcu_invoice_rec IN 1 .. invoice_info_tbl.COUNT
                LOOP
                    BEGIN
                        ln_err_count                 := 0;

                        print_log_prc (
                            p_debug,
                            'START**********************************************************************************START');

                        gc_code_pointer              :=
                               'Start Invoice Validation for Old Invoice ID : '
                            || invoice_info_tbl (lcu_invoice_rec).old_invoice_id;
                        print_log_prc (p_debug, gc_code_pointer);

                        --Invoice Header Validation
                        gc_code_pointer              :=
                               'Invoice header check for Old Invoice ID : '
                            || invoice_info_tbl (lcu_invoice_rec).old_invoice_id;
                        print_log_prc (p_debug, gc_code_pointer);


                        IF chk_inv%ISOPEN
                        THEN
                            CLOSE chk_inv;
                        END IF;

                        OPEN chk_inv (
                            invoice_info_tbl (lcu_invoice_rec).invoice_num,
                            --Start modification by Naveen on 24-Jun-2015
                            --invoice_info_tbl (lcu_invoice_rec).vendor_name);
                            invoice_info_tbl (lcu_invoice_rec).vendor_num);

                        --End modification by Naveen on 24-Jun-2015

                        ln_inv_chk                   := NULL;

                        FETCH chk_inv INTO ln_inv_chk;

                        CLOSE chk_inv;

                        IF ln_inv_chk IS NOT NULL
                        THEN
                            ln_err_count   := ln_err_count + 1;
                            lc_h_err_msg   :=
                                'Invoice already exists for the given vendor ';

                            print_log_prc (p_debug, lc_h_err_msg);

                            xxd_common_utils.record_error (
                                'APINV',
                                xxd_common_utils.get_org_id,
                                'Deckers AP Invoice Conversion Program',
                                lc_h_err_msg,
                                DBMS_UTILITY.format_error_backtrace,
                                gn_user_id,
                                gn_req_id,
                                'Code pointer : ' || gc_code_pointer,
                                'XXD_AP_INVOICE_CONV_STG_T');
                        END IF;



                        --Invoice type validation
                        gc_code_pointer              := 'Invoice type validation';
                        print_log_prc (p_debug, gc_code_pointer);

                        IF invoice_type_c%ISOPEN
                        THEN
                            CLOSE invoice_type_c;
                        END IF;


                        OPEN invoice_type_c (
                            invoice_info_tbl (lcu_invoice_rec).invoice_type_lookup_code);

                        lc_lookup_code               := NULL;

                        FETCH invoice_type_c INTO lc_lookup_code;

                        CLOSE invoice_type_c;

                        IF lc_lookup_code IS NULL
                        THEN
                            ln_err_count   := ln_err_count + 1;
                            lc_h_err_msg   :=
                                   'Invoice type lookup code validation failed for invoice '
                                || invoice_info_tbl (lcu_invoice_rec).old_invoice_id;

                            print_log_prc (p_debug, lc_h_err_msg);

                            print_log_prc (p_debug, lc_h_err_msg);

                            xxd_common_utils.record_error (
                                'APINV',
                                xxd_common_utils.get_org_id,
                                'Deckers AP Invoice Conversion Program',
                                lc_h_err_msg,
                                DBMS_UTILITY.format_error_backtrace,
                                gn_user_id,
                                gn_req_id,
                                'Code pointer : ' || gc_code_pointer,
                                'XXD_AP_INVOICE_CONV_STG_T');
                        END IF;



                        --Vendor validation

                        gc_code_pointer              := 'Vendor Name validation';
                        print_log_prc (p_debug, gc_code_pointer);
                        ln_vendor_id                 := NULL;

                        IF invoice_info_tbl (lcu_invoice_rec).vendor_name
                               IS NOT NULL
                        THEN
                            IF vendor_id_c%ISOPEN
                            THEN
                                CLOSE vendor_id_c;
                            END IF;

                            --Start modification by Naveen on 24-Jun-2015
                            --OPEN vendor_id_c (invoice_info_tbl (lcu_invoice_rec).vendor_name);
                            OPEN vendor_id_c (
                                invoice_info_tbl (lcu_invoice_rec).vendor_num);

                            --End modification by Naveen on 24-Jun-2015

                            ln_vendor_id   := NULL;

                            FETCH vendor_id_c INTO ln_vendor_id;

                            CLOSE vendor_id_c;

                            IF ln_vendor_id IS NULL
                            THEN
                                ln_err_count   := ln_err_count + 1;
                                lc_h_err_msg   :=
                                    'Vendor validation failed for invoice';

                                print_log_prc (p_debug, lc_h_err_msg);

                                xxd_common_utils.record_error (
                                    'APINV',
                                    xxd_common_utils.get_org_id,
                                    'Deckers AP Invoice Conversion Program',
                                    lc_h_err_msg,
                                    DBMS_UTILITY.format_error_backtrace,
                                    gn_user_id,
                                    gn_req_id,
                                    'Code pointer : ' || gc_code_pointer,
                                    'XXD_AP_INVOICE_CONV_STG_T');
                            END IF;
                        ELSE
                            lc_h_err_msg   := 'Vendor Name is null';
                            print_log_prc (p_debug, lc_h_err_msg);
                            ln_err_count   := ln_err_count + 1;
                        END IF;



                        -- ORG_ID Check
                        ln_org_id                    := NULL;
                        ln_sob_id                    := NULL;
                        -- Start modification by BT Technology team on 30-Sep-15
                        lc_liability_company         := NULL;
                        lc_default_conc_segs         := NULL;
                        -- End modification by BT Technology team on 30-Sep-15

                        get_new_org_id (p_old_org_name => invoice_info_tbl (lcu_invoice_rec).operating_unit, p_debug_flag => p_debug, x_new_org_id => ln_org_id
                                        , x_new_org_name => lc_org_name);

                        print_log_prc (p_debug,
                                       'New ORG Id is :' || ln_org_id);
                        print_log_prc (p_debug,
                                       'New Operating Unit :' || lc_org_name);

                        IF ln_org_id IS NULL
                        THEN
                            ln_err_count   := ln_err_count + 1;
                            lc_h_err_msg   :=
                                'Org ID is not defined for the invoice';

                            print_log_prc (p_debug, lc_h_err_msg);

                            xxd_common_utils.record_error (
                                'APINV',
                                xxd_common_utils.get_org_id,
                                'Deckers AP Invoice Conversion Program',
                                lc_h_err_msg,
                                DBMS_UTILITY.format_error_backtrace,
                                gn_user_id,
                                gn_req_id,
                                'Code pointer : ' || gc_code_pointer,
                                'XXD_AP_INVOICE_CONV_STG_T');
                        ELSE
                            SELECT set_of_books_id
                              INTO ln_sob_id
                              FROM hr_operating_units
                             WHERE organization_id = ln_org_id;

                            -- Start modification by BT Technology team on 30-Sep-15
                            OPEN get_liability_company (ln_org_id);

                            FETCH get_liability_company
                                INTO lc_liability_company;

                            CLOSE get_liability_company;

                            OPEN get_default_distribution (ln_org_id);

                            FETCH get_default_distribution
                                INTO lc_default_conc_segs;

                            CLOSE get_default_distribution;
                        -- End modification by BT Technology team on 30-Sep-15
                        END IF;

                        ln_exchange_rate             := NULL;
                        lc_exchange_rate_type        := NULL;
                        ld_exchange_date             := NULL;
                        lc_ledger_currency           := NULL;

                        IF ln_sob_id IS NOT NULL
                        THEN
                            SELECT currency_code
                              INTO lc_ledger_currency
                              FROM gl_ledgers
                             WHERE ledger_id = ln_sob_id;

                            IF lc_ledger_currency =
                               invoice_info_tbl (lcu_invoice_rec).invoice_currency_code
                            THEN
                                ln_exchange_rate        := NULL;
                                lc_exchange_rate_type   := NULL;
                                ld_exchange_date        := NULL;
                            ELSE
                                ln_exchange_rate   :=
                                    invoice_info_tbl (lcu_invoice_rec).exchange_rate;
                                lc_exchange_rate_type   :=
                                    invoice_info_tbl (lcu_invoice_rec).exchange_rate_type;
                                ld_exchange_date   :=
                                    invoice_info_tbl (lcu_invoice_rec).exchange_date;
                            END IF;
                        ELSE
                            ln_exchange_rate   :=
                                invoice_info_tbl (lcu_invoice_rec).exchange_rate;
                            lc_exchange_rate_type   :=
                                invoice_info_tbl (lcu_invoice_rec).exchange_rate_type;
                            ld_exchange_date   :=
                                invoice_info_tbl (lcu_invoice_rec).exchange_date;
                        END IF;


                        --Vendor site code validation
                        ln_vendor_site_id            := NULL;

                        IF     invoice_info_tbl (lcu_invoice_rec).vendor_site_code
                                   IS NOT NULL
                           AND ln_vendor_id IS NOT NULL
                           AND ln_org_id IS NOT NULL
                        THEN
                            gc_code_pointer     :=
                                'Vendor site code validation';
                            print_log_prc (p_debug, gc_code_pointer);

                            IF vendor_site_id_c%ISOPEN
                            THEN
                                CLOSE vendor_site_id_c;
                            END IF;

                            OPEN vendor_site_id_c (
                                ln_vendor_id,
                                invoice_info_tbl (lcu_invoice_rec).vendor_site_code,
                                ln_org_id);

                            ln_vendor_site_id   := NULL;

                            FETCH vendor_site_id_c INTO ln_vendor_site_id;

                            CLOSE vendor_site_id_c;

                            IF ln_vendor_site_id IS NULL
                            THEN
                                ln_err_count   := ln_err_count + 1;
                                lc_h_err_msg   :=
                                    'Vendor site code validation failed for invoice';

                                print_log_prc (p_debug, lc_h_err_msg);

                                xxd_common_utils.record_error (
                                    'APINV',
                                    xxd_common_utils.get_org_id,
                                    'Deckers AP Invoice Conversion Program',
                                    lc_h_err_msg,
                                    DBMS_UTILITY.format_error_backtrace,
                                    gn_user_id,
                                    gn_req_id,
                                    'Code pointer : ' || gc_code_pointer,
                                    'XXD_AP_INVOICE_CONV_STG_T');
                            END IF;
                        ELSIF invoice_info_tbl (lcu_invoice_rec).vendor_site_code
                                  IS NULL
                        THEN
                            lc_h_err_msg   := 'Vendor site code is null';
                            print_log_prc (p_debug, lc_h_err_msg);
                            ln_err_count   := ln_err_count + 1;
                        END IF;

                        lc_pay_group                 := NULL;
                        lc_payment_method_code       := NULL;
                        lc_supp_pay_group            := NULL;
                        lc_supp_pmt_method_code      := NULL;

                        IF     ln_vendor_site_id IS NOT NULL
                           AND ln_vendor_id IS NOT NULL
                        THEN
                            gc_code_pointer           :=
                                'Payment Method and Paygroup derivation';
                            print_log_prc (p_debug, gc_code_pointer);

                            IF get_new_payment_details%ISOPEN
                            THEN
                                CLOSE get_new_payment_details;
                            END IF;

                            OPEN get_new_payment_details (ln_vendor_id,
                                                          ln_vendor_site_id);

                            lc_pay_group              := NULL;
                            lc_payment_method_code    := NULL;
                            lc_supp_pay_group         := NULL;
                            lc_supp_pmt_method_code   := NULL;

                            FETCH get_new_payment_details
                                INTO lc_supp_pay_group, lc_supp_pmt_method_code;

                            CLOSE get_new_payment_details;

                            IF    lc_supp_pmt_method_code IS NULL
                               OR lc_supp_pay_group IS NULL
                            THEN
                                ln_err_count   := ln_err_count + 1;
                                lc_h_err_msg   :=
                                    'Pay_group or payment_method doesnot exist at either supplier or site level';

                                print_log_prc (p_debug, lc_h_err_msg);

                                xxd_common_utils.record_error (
                                    'APINV',
                                    xxd_common_utils.get_org_id,
                                    'Deckers AP Invoice Conversion Program',
                                    lc_h_err_msg,
                                    DBMS_UTILITY.format_error_backtrace,
                                    gn_user_id,
                                    gn_req_id,
                                    'Code pointer : ' || gc_code_pointer,
                                    'XXD_AP_INVOICE_CONV_STG_T');
                            ELSE
                                IF invoice_info_tbl (lcu_invoice_rec).pay_group_lookup_code =
                                   'COMMISSIONS'
                                THEN
                                    lc_pay_group             := lc_supp_pay_group;
                                    lc_payment_method_code   := 'COMMISSIONS';
                                ELSE
                                    IF UPPER (
                                           invoice_info_tbl (lcu_invoice_rec).payment_method_code) IN
                                           ('ZERO PAYMENT', 'CLEARING')
                                    THEN
                                        lc_pay_group   := lc_supp_pay_group;
                                        lc_payment_method_code   :=
                                            'COMMISSIONS';
                                    ELSIF UPPER (
                                              invoice_info_tbl (
                                                  lcu_invoice_rec).payment_method_code) IN
                                              ('GTNEXUS', 'CHECK')
                                    THEN
                                        lc_pay_group   :=
                                            invoice_info_tbl (
                                                lcu_invoice_rec).payment_method_code;
                                        lc_payment_method_code   :=
                                            invoice_info_tbl (
                                                lcu_invoice_rec).payment_method_code;
                                    ELSIF UPPER (
                                              invoice_info_tbl (
                                                  lcu_invoice_rec).payment_method_code) IN
                                              ('WIRE', 'INTERNATIONAL WIRE', 'ACH PAYMENT',
                                               'EFT')
                                    THEN
                                        lc_pay_group   := lc_supp_pay_group;
                                        lc_payment_method_code   :=
                                            lc_supp_pmt_method_code;
                                    ELSE
                                        lc_pay_group   :=
                                            invoice_info_tbl (
                                                lcu_invoice_rec).pay_group_lookup_code;
                                        lc_payment_method_code   :=
                                            invoice_info_tbl (
                                                lcu_invoice_rec).payment_method_code;
                                    END IF;
                                END IF;

                                IF invoice_info_tbl (lcu_invoice_rec).PAYMENT_STATUS_FLAG =
                                   'Y'
                                THEN
                                    lc_pay_group   := 'CONV_PAID';
                                END IF;
                            END IF;
                        END IF;

                        --  Payment method lookup code validation


                        gc_code_pointer              :=
                            'Payment method lookup code validation';
                        print_log_prc (p_debug, gc_code_pointer);
                        lc_payment_method_code_chk   := NULL;

                        IF lc_payment_method_code IS NOT NULL
                        THEN
                            IF pmt_code_c%ISOPEN
                            THEN
                                CLOSE pmt_code_c;
                            END IF;

                            OPEN pmt_code_c (lc_payment_method_code);

                            lc_payment_method_code_chk   := NULL;

                            FETCH pmt_code_c INTO lc_payment_method_code_chk;

                            CLOSE pmt_code_c;



                            IF lc_payment_method_code_chk IS NULL
                            THEN
                                --                  lc_recvalidation := gc_noflag;
                                ln_err_count   := ln_err_count + 1;
                                lc_h_err_msg   :=
                                    'Payment method lookup code validation for invoice ';

                                print_log_prc (p_debug, lc_h_err_msg);


                                xxd_common_utils.record_error (
                                    'APINV',
                                    xxd_common_utils.get_org_id,
                                    'Deckers AP Invoice Conversion Program',
                                    lc_h_err_msg,
                                    DBMS_UTILITY.format_error_backtrace,
                                    gn_user_id,
                                    gn_req_id,
                                    'Code pointer : ' || gc_code_pointer,
                                    'XXD_AP_INVOICE_CONV_STG_T');
                            END IF;
                        --Srinivas
                        /*ELSE
                           lc_h_err_msg := 'Payment method lookup code is null';
                           ln_err_count := ln_err_count + 1;
                           print_log_prc (p_debug, lc_h_err_msg); */
                        END IF;


                        --Pay group lookup code validation
                        lc_p_pay_grp_lkp_code        := NULL;

                        IF lc_pay_group IS NOT NULL
                        THEN
                            gc_code_pointer         :=
                                'Pay group lookup code validation';
                            print_log_prc (p_debug, gc_code_pointer);

                            IF paygrp_code_c%ISOPEN
                            THEN
                                CLOSE paygrp_code_c;
                            END IF;

                            OPEN paygrp_code_c (lc_pay_group);

                            lc_p_pay_grp_lkp_code   := NULL;

                            FETCH paygrp_code_c INTO lc_p_pay_grp_lkp_code;

                            CLOSE paygrp_code_c;



                            IF lc_p_pay_grp_lkp_code IS NULL
                            THEN
                                --lc_recvalidation := gc_noflag;
                                ln_err_count   := ln_err_count + 1;
                                lc_h_err_msg   :=
                                    'Pay group lookup code validation failed for invoice';

                                print_log_prc (p_debug, lc_h_err_msg);

                                xxd_common_utils.record_error (
                                    'APINV',
                                    xxd_common_utils.get_org_id,
                                    'Deckers AP Invoice Conversion Program',
                                    lc_h_err_msg,
                                    DBMS_UTILITY.format_error_backtrace,
                                    gn_user_id,
                                    gn_req_id,
                                    'Code pointer : ' || gc_code_pointer,
                                    'XXD_AP_INVOICE_CONV_STG_T');
                            --               ELSE
                            --                  lc_recvalidation := gc_yesflag;
                            END IF;
                        /*ELSE
                           lc_h_err_msg := 'Pay group lookup code is null';
                           print_log_prc (p_debug, lc_h_err_msg);
                           ln_err_count := ln_err_count + 1; */
                        END IF;


                        /*         -- Invoice line check
                                 gc_code_pointer := 'Invoice line check';
                                 print_log_prc (p_debug, gc_code_pointer);



                                 OPEN chk_line_c (invoice_info_tbl (lcu_invoice_rec).old_invoice_id);

                                 ln_invoice_id := NULL;


                                 FETCH chk_line_c INTO ln_invoice_id;

                                 CLOSE chk_line_c;

                                 IF ln_invoice_id IS NULL
                                 THEN
                                    ln_err_count := ln_err_count + 1;
                                    lc_h_err_msg :=
                                          'Invoice line does not exist for invoice '
                                       || invoice_info_tbl (lcu_invoice_rec).old_invoice_id;

                                    print_log_prc (p_debug, lc_h_err_msg);

                                    XXD_common_utils.record_error (
                                       'APINV',
                                       XXD_common_utils.get_org_id,
                                       'Deckers AP Invoice Conversion Program',
                                       lc_h_err_msg,
                                       DBMS_UTILITY.format_error_backtrace,
                                       gn_user_id,
                                       gn_req_id,
                                       'Code pointer : ' || gc_code_pointer,
                                       'XXD_AP_INVOICE_CONV_STG_T');
                                 END IF; */



                        -- Invoice check

                        gc_code_pointer              :=
                            'Duplicate Invoice check';
                        print_log_prc (p_debug, gc_code_pointer);

                        OPEN chk_invoice_c (
                            invoice_info_tbl (lcu_invoice_rec).invoice_num,
                            ln_vendor_id);

                        ln_invoice_num               := NULL;

                        FETCH chk_invoice_c INTO ln_invoice_num;

                        CLOSE chk_invoice_c;



                        IF ln_invoice_num IS NOT NULL
                        THEN
                            ln_err_count   := ln_err_count + 1;
                            lc_h_err_msg   := 'Invoice already exists';

                            print_log_prc (p_debug, lc_h_err_msg);

                            xxd_common_utils.record_error (
                                'APINV',
                                xxd_common_utils.get_org_id,
                                'Deckers AP Invoice Conversion Program',
                                lc_h_err_msg,
                                DBMS_UTILITY.format_error_backtrace,
                                gn_user_id,
                                gn_req_id,
                                'Code pointer : ' || gc_code_pointer,
                                'XXD_AP_INVOICE_CONV_STG_T');
                        END IF;

                        gc_code_pointer              := 'Term name check';
                        print_log_prc (p_debug, gc_code_pointer);
                        ln_term_id                   := NULL;


                        IF invoice_info_tbl (lcu_invoice_rec).terms_name
                               IS NOT NULL
                        THEN
                            -- Term check
                            OPEN term_id_c (
                                invoice_info_tbl (lcu_invoice_rec).terms_name);


                            ln_term_id   := NULL;

                            FETCH term_id_c INTO ln_term_id;

                            CLOSE term_id_c;

                            IF ln_term_id IS NULL
                            THEN
                                ln_err_count   := ln_err_count + 1;
                                lc_h_err_msg   :=
                                    'term name not defined for the invoice';

                                print_log_prc (p_debug, lc_h_err_msg);

                                xxd_common_utils.record_error (
                                    'APINV',
                                    xxd_common_utils.get_org_id,
                                    'Deckers AP Invoice Conversion Program',
                                    lc_h_err_msg,
                                    DBMS_UTILITY.format_error_backtrace,
                                    gn_user_id,
                                    gn_req_id,
                                    'Code pointer : ' || gc_code_pointer,
                                    'XXD_AP_INVOICE_CONV_STG_T');
                            END IF;
                        ELSE
                            gc_code_pointer   := 'Term name is null';
                            print_log_prc (p_debug, gc_code_pointer);
                            ln_err_count      := ln_err_count + 1;
                        END IF;


                        --Source check

                        gc_code_pointer              :=
                            'Checking source in the lookup';
                        print_log_prc (p_debug, gc_code_pointer);

                        IF chk_source_c%ISOPEN
                        THEN
                            CLOSE chk_source_c;
                        END IF;

                        OPEN chk_source_c (
                            invoice_info_tbl (lcu_invoice_rec).source);

                        lc_source                    := NULL;

                        FETCH chk_source_c INTO lc_source;

                        CLOSE chk_source_c;

                        IF lc_source IS NULL
                        THEN
                            ln_err_count   := ln_err_count + 1;
                            lc_h_err_msg   :=
                                'Source not defined for the invoice';

                            print_log_prc (p_debug, lc_h_err_msg);

                            xxd_common_utils.record_error (
                                'APINV',
                                xxd_common_utils.get_org_id,
                                'Deckers AP Invoice Conversion Program',
                                lc_h_err_msg,
                                DBMS_UTILITY.format_error_backtrace,
                                gn_user_id,
                                gn_req_id,
                                'Code pointer : ' || gc_code_pointer,
                                'XXD_AP_INVOICE_CONV_STG_T');
                        END IF;



                        --Invoice Lines check

                        IF invoice_line_c%ISOPEN
                        THEN
                            CLOSE invoice_line_c;
                        END IF;

                        gc_code_pointer              := 'Checking Invoice ';
                        print_log_prc (p_debug, gc_code_pointer);


                        OPEN invoice_line_c (
                            invoice_info_tbl (lcu_invoice_rec).old_invoice_id);

                        ln_lines_err_count           := 0;

                        LOOP
                            invoice_line_info_tbl.delete;

                            FETCH invoice_line_c
                                BULK COLLECT INTO invoice_line_info_tbl
                                LIMIT gn_limit;

                            gc_code_pointer   :=
                                   'invoice_line_info_tbl count - '
                                || invoice_line_info_tbl.COUNT;
                            print_log_prc (p_debug, gc_code_pointer);



                            IF (invoice_line_info_tbl.COUNT > 0)
                            THEN
                                FOR lcu_inv_line_rec IN 1 ..
                                                        invoice_line_info_tbl.COUNT
                                LOOP
                                    ln_ccid                   := NULL;
                                    lc_coa_id                 := NULL;
                                    lc_conc_segs              := NULL;
                                    lc_line_lookup_code       := NULL;
                                    lc_new_conc_segs          := NULL;
                                    lc_l_err_msg              := NULL;
                                    ln_line_err_count         := 0;
                                    ln_shipment_num           := NULL;
                                    ln_po_header_id           := NULL;
                                    ln_po_line_id             := NULL;
                                    ln_po_distribution_id     := NULL;
                                    ln_po_line_loc_id         := NULL;
                                    ln_ship_to_location_id    := NULL;
                                    lc_encoded_message        := NULL;
                                    lc_authorization_status   := NULL;

                                    ---Check PO details

                                    IF invoice_line_info_tbl (
                                           lcu_inv_line_rec).po_number
                                           IS NOT NULL
                                    THEN
                                        gc_code_pointer   :=
                                               'PO Recipts verification for '
                                            || invoice_line_info_tbl (
                                                   lcu_inv_line_rec).invoice_num
                                            || ' and line number '
                                            || invoice_line_info_tbl (
                                                   lcu_inv_line_rec).line_number;

                                        print_log_prc (
                                            p_debug,
                                               'PO Recipts verification for '
                                            || invoice_line_info_tbl (
                                                   lcu_inv_line_rec).invoice_num
                                            || ' and line number '
                                            || invoice_line_info_tbl (
                                                   lcu_inv_line_rec).line_number);

                                        IF chk_po_reciepts%ISOPEN
                                        THEN
                                            CLOSE chk_po_reciepts;
                                        END IF;

                                        BEGIN
                                            OPEN chk_po_reciepts (
                                                invoice_line_info_tbl (
                                                    lcu_inv_line_rec).po_number,
                                                invoice_line_info_tbl (
                                                    lcu_inv_line_rec).po_line_number,
                                                invoice_line_info_tbl (
                                                    lcu_inv_line_rec).po_shipment_num --,
                                                                                     --invoice_line_info_tbl (
                                                                                     --  lcu_inv_line_rec).po_distribution_num
                                                                                     );



                                            FETCH chk_po_reciepts
                                                INTO ln_po_header_id, ln_po_line_id, ln_po_distribution_id, ln_po_line_loc_id,
                                                     ln_ship_to_location_id, lc_authorization_status;

                                            IF chk_po_reciepts%NOTFOUND
                                            THEN
                                                ln_line_err_count   :=
                                                    ln_line_err_count + 1;
                                                lc_l_err_msg   :=
                                                    'PO Details not available for the invoice';

                                                print_log_prc (p_debug,
                                                               lc_l_err_msg);

                                                xxd_common_utils.record_error (
                                                    'APINV',
                                                    xxd_common_utils.get_org_id,
                                                    'Deckers AP Invoice Conversion Program',
                                                    lc_l_err_msg,
                                                    DBMS_UTILITY.format_error_backtrace,
                                                    gn_user_id,
                                                    gn_req_id,
                                                       'Code pointer : '
                                                    || gc_code_pointer,
                                                    'XXD_AP_INVOICE_DIST_CONV_STG_T');
                                            END IF;

                                            CLOSE chk_po_reciepts;

                                            IF lc_authorization_status =
                                               'INCOMPLETE'
                                            THEN
                                                ln_line_err_count   :=
                                                    ln_line_err_count + 1;
                                                lc_l_err_msg   :=
                                                    'PO is in incomplete status';

                                                print_log_prc (p_debug,
                                                               lc_l_err_msg);

                                                xxd_common_utils.record_error (
                                                    'APINV',
                                                    xxd_common_utils.get_org_id,
                                                    'Deckers AP Invoice Conversion Program',
                                                    lc_l_err_msg,
                                                    DBMS_UTILITY.format_error_backtrace,
                                                    gn_user_id,
                                                    gn_req_id,
                                                       'Code pointer : '
                                                    || gc_code_pointer,
                                                    'XXD_AP_INVOICE_DIST_CONV_STG_T');
                                            END IF;
                                        EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                                print_log_prc (
                                                    p_debug,
                                                       'PO Recipts verification for '
                                                    || SQLCODE
                                                    || ':'
                                                    || SQLERRM);
                                        END;
                                    END IF;



                                    BEGIN
                                        gc_code_pointer   :=
                                               'Checking Invoice line type lookup code - '
                                            || invoice_line_info_tbl (
                                                   lcu_inv_line_rec).line_type_lookup_code;
                                        print_log_prc (p_debug,
                                                       gc_code_pointer);

                                        IF invoice_line_type_c%ISOPEN
                                        THEN
                                            CLOSE invoice_line_type_c;
                                        END IF;

                                        OPEN invoice_line_type_c (
                                            invoice_line_info_tbl (
                                                lcu_inv_line_rec).line_type_lookup_code);



                                        FETCH invoice_line_type_c
                                            INTO lc_line_lookup_code;

                                        CLOSE invoice_line_type_c;

                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'ln_line_err_count 1 '
                                            || ln_line_err_count);

                                        IF lc_line_lookup_code IS NULL
                                        THEN
                                            ln_line_err_count   :=
                                                ln_line_err_count + 1;


                                            lc_l_err_msg   :=
                                                'Line type code is not defined for the invoice line';
                                            print_log_prc (p_debug,
                                                           lc_l_err_msg);

                                            xxd_common_utils.record_error (
                                                'APINV',
                                                xxd_common_utils.get_org_id,
                                                'Deckers AP Invoice Conversion Program',
                                                lc_l_err_msg,
                                                DBMS_UTILITY.format_error_backtrace,
                                                gn_user_id,
                                                gn_req_id,
                                                   'Code pointer : '
                                                || gc_code_pointer,
                                                'XXD_AP_INVOICE_DIST_CONV_STG_T');
                                        END IF;

                                        --Srinivas
                                        gc_code_pointer   :=
                                               'Checking period status for accounting date '
                                            || invoice_line_info_tbl (
                                                   lcu_inv_line_rec).accounting_date;
                                        print_log_prc (p_debug,
                                                       gc_code_pointer);

                                        IF chk_period_status_c%ISOPEN
                                        THEN
                                            CLOSE chk_period_status_c;
                                        END IF;

                                        OPEN chk_period_status_c (
                                            invoice_line_info_tbl (
                                                lcu_inv_line_rec).accounting_date,
                                            ln_sob_id);


                                        ln_no   := NULL;



                                        FETCH chk_period_status_c INTO ln_no;

                                        CLOSE chk_period_status_c;



                                        IF ln_no IS NULL
                                        THEN
                                            ln_line_err_count   :=
                                                ln_line_err_count + 1;


                                            lc_l_err_msg   :=
                                                   'accounting date '
                                                || invoice_line_info_tbl (
                                                       lcu_inv_line_rec).accounting_date
                                                || ' is not in open period   '
                                                || 'sob '
                                                || ln_sob_id;

                                            print_log_prc (p_debug,
                                                           lc_l_err_msg);

                                            xxd_common_utils.record_error (
                                                'APINV',
                                                xxd_common_utils.get_org_id,
                                                'Deckers AP Invoice Conversion Program',
                                                lc_l_err_msg,
                                                DBMS_UTILITY.format_error_backtrace,
                                                gn_user_id,
                                                gn_req_id,
                                                   'Code pointer : '
                                                || gc_code_pointer,
                                                'XXD_AP_INVOICE_DIST_CONV_STG_T');
                                        END IF;

                                        --Srinivas

                                        -- If line error count is 0 update lines stagigng table with record_status is V - validated
                                        -- Else setting record_status to E - Error for both line and invoice tables

                                        -- `Check CCID

                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'ln_line_err_count 2 '
                                            || ln_line_err_count);
                                        lc_conc_segs   :=
                                               invoice_line_info_tbl (
                                                   lcu_inv_line_rec).distribution_ccid_seg1
                                            || '-'
                                            || invoice_line_info_tbl (
                                                   lcu_inv_line_rec).distribution_ccid_seg2
                                            || '-'
                                            || invoice_line_info_tbl (
                                                   lcu_inv_line_rec).distribution_ccid_seg3
                                            || '-'
                                            || invoice_line_info_tbl (
                                                   lcu_inv_line_rec).distribution_ccid_seg4;

                                        gc_code_pointer   :=
                                               'Checking CCID for  : '
                                            || lc_conc_segs;

                                        print_log_prc (p_debug,
                                                       gc_code_pointer);

                                        IF lc_conc_segs != '---'
                                        THEN
                                            BEGIN
                                                lc_new_conc_segs   :=
                                                    xxd_common_utils.get_gl_code_combination (
                                                        invoice_line_info_tbl (
                                                            lcu_inv_line_rec).distribution_ccid_seg1,
                                                        invoice_line_info_tbl (
                                                            lcu_inv_line_rec).distribution_ccid_seg2,
                                                        invoice_line_info_tbl (
                                                            lcu_inv_line_rec).distribution_ccid_seg3,
                                                        invoice_line_info_tbl (
                                                            lcu_inv_line_rec).distribution_ccid_seg4);

                                                gc_code_pointer   :=
                                                       'Checking CCID lc_new_conc_segs  - '
                                                    || lc_new_conc_segs;
                                                print_log_prc (
                                                    p_debug,
                                                    gc_code_pointer);

                                                fnd_file.put_line (
                                                    fnd_file.LOG,
                                                       'lc_new_conc_segs '
                                                    || lc_new_conc_segs);

                                                fnd_file.put_line (
                                                    fnd_file.LOG,
                                                       'ln_line_err_count 3 '
                                                    || ln_line_err_count);

                                                IF lc_new_conc_segs
                                                       IS NOT NULL
                                                THEN
                                                    ln_ccid   := NULL;

                                                    -- Start modification by BT Technology team on 30-Sep-15
                                                    IF lc_liability_company <>
                                                       SUBSTR (
                                                           lc_new_conc_segs,
                                                           1,
                                                             INSTR (
                                                                 lc_new_conc_segs,
                                                                 '.',
                                                                 1)
                                                           - 1)
                                                    THEN
                                                        lc_new_conc_segs   :=
                                                            NVL (
                                                                lc_default_conc_segs,
                                                                lc_new_conc_segs);
                                                    END IF;

                                                    -- End modification by BT Technology team on 30-Sep-15

                                                    ---------------Check if CCID exits with the above Concatenated Segments---------------
                                                    IF ln_sob_id IS NOT NULL
                                                    THEN
                                                        BEGIN
                                                            SELECT chart_of_accounts_id
                                                              INTO lc_coa_id
                                                              FROM gl_ledgers
                                                             WHERE ledger_id =
                                                                   ln_sob_id; --invoice_info_tbl (lcu_invoice_rec).set_of_books_id;
                                                        EXCEPTION
                                                            WHEN OTHERS
                                                            THEN
                                                                ln_line_err_count   :=
                                                                      ln_line_err_count
                                                                    + 1;
                                                                fnd_file.put_line (
                                                                    fnd_file.LOG,
                                                                       'Exception occured while getting chart of account id '
                                                                    || SQLERRM);

                                                                lc_l_err_msg   :=
                                                                    'Exception occured while getting chart of account id ';
                                                        END;
                                                    ELSE
                                                        gc_code_pointer   :=
                                                            'SOB ID is null';

                                                        lc_l_err_msg   :=
                                                            gc_code_pointer;
                                                        print_log_prc (
                                                            p_debug,
                                                            gc_code_pointer);
                                                    END IF;

                                                    gc_code_pointer   :=
                                                        'Creating the Combination using Fnd_Flex_Ext.get_ccid';
                                                    print_log_prc (
                                                        p_debug,
                                                        gc_code_pointer);


                                                    fnd_file.put_line (
                                                        fnd_file.LOG,
                                                           'ln_line_err_count 5 '
                                                        || ln_line_err_count);

                                                    BEGIN
                                                        ln_ccid   :=
                                                            fnd_flex_ext.get_ccid (
                                                                'SQLGL',
                                                                'GL#',
                                                                lc_coa_id,
                                                                NULL,
                                                                lc_new_conc_segs);
                                                    EXCEPTION
                                                        WHEN OTHERS
                                                        THEN
                                                            ln_ccid   := NULL;
                                                            lc_l_err_msg   :=
                                                                'Fnd_Flex_Ext.get_ccid failed to derive ccid';
                                                    END;

                                                    fnd_file.put_line (
                                                        fnd_file.LOG,
                                                           'ln_line_err_count 6 '
                                                        || ln_line_err_count);
                                                    fnd_file.put_line (
                                                        fnd_file.LOG,
                                                        'ln_ccid ' || ln_ccid);

                                                    IF ln_ccid = 0
                                                    THEN
                                                        -------------Error in creating a combination-----------------
                                                        ln_line_err_count   :=
                                                              ln_line_err_count
                                                            + 1;
                                                        gc_code_pointer   :=
                                                               'Error in creating the combination: '
                                                            || p_error_msg2;
                                                        lc_encoded_message   :=
                                                            fnd_message.get_encoded;
                                                        fnd_message.set_encoded (
                                                            lc_encoded_message);
                                                        lc_l_err_msg   :=
                                                               gc_code_pointer
                                                            || ', '
                                                            || fnd_message.get;
                                                        print_log_prc (
                                                            p_debug,
                                                            gc_code_pointer);
                                                    END IF;
                                                ELSE
                                                    gc_code_pointer   :=
                                                        'Could not derive corresponding mapping segments in 12.2.3';

                                                    lc_l_err_msg   :=
                                                        gc_code_pointer;

                                                    print_log_prc (
                                                        p_debug,
                                                        gc_code_pointer);

                                                    ln_line_err_count   :=
                                                        ln_line_err_count + 1;

                                                    xxd_common_utils.record_error (
                                                        'APINV',
                                                        xxd_common_utils.get_org_id,
                                                        'Deckers AP Invoice Conversion Program',
                                                        lc_l_err_msg,
                                                        DBMS_UTILITY.format_error_backtrace,
                                                        gn_user_id,
                                                        gn_req_id,
                                                           'Code pointer : '
                                                        || gc_code_pointer,
                                                        'XXD_AP_INVOICE_DIST_CONV_STG_T');
                                                END IF;


                                                fnd_file.put_line (
                                                    fnd_file.LOG,
                                                       'ln_line_err_count 7 '
                                                    || ln_line_err_count);
                                            EXCEPTION
                                                WHEN OTHERS
                                                THEN
                                                    ln_line_err_count   :=
                                                        ln_line_err_count + 1;
                                                    fnd_file.put_line (
                                                        fnd_file.LOG,
                                                           SQLCODE
                                                        || ' '
                                                        || SQLERRM
                                                        || ','
                                                        || gc_code_pointer);

                                                    lc_l_err_msg   :=
                                                        SUBSTR (SQLERRM,
                                                                1,
                                                                200);

                                                    xxd_common_utils.record_error (
                                                        'APINV',
                                                        xxd_common_utils.get_org_id,
                                                        'Deckers AP Invoice Conversion Program',
                                                        lc_l_err_msg,
                                                        DBMS_UTILITY.format_error_backtrace,
                                                        gn_user_id,
                                                        gn_req_id,
                                                           'Code pointer : '
                                                        || gc_code_pointer,
                                                        'XXD_AP_INVOICE_DIST_CONV_STG_T');
                                            END;
                                        ELSE
                                            ln_ccid   := NULL;
                                        --                                 lc_l_err_msg :=
                                        --                                    'Segment values for the line are null in 12.0.6';
                                        --                                 ln_line_err_count :=
                                        --                                    ln_line_err_count + ln_line_err_count;
                                        END IF;

                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'ln_line_err_count 8 '
                                            || ln_line_err_count);

                                        IF ln_line_err_count = 0
                                        THEN
                                            print_log_prc (
                                                p_debug,
                                                'Before setting line record status to V');

                                            UPDATE xxd_ap_invoice_dist_conv_stg_t
                                               SET record_status   = 'V',
                                                   error_message   = NULL,
                                                   request_id      =
                                                       gn_req_id,
                                                   last_update_date   =
                                                       gd_sysdate,
                                                   last_updated_by   =
                                                       gn_user_id,
                                                   new_org_id      =
                                                       ln_org_id,
                                                   new_dist_ccid   =
                                                       CASE
                                                           WHEN ln_po_header_id
                                                                    IS NOT NULL
                                                           THEN
                                                               NULL
                                                           ELSE
                                                               ln_ccid
                                                       END,
                                                   new_coa_id      =
                                                       lc_coa_id,
                                                   concatenated_segments   =
                                                       lc_new_conc_segs,
                                                   new_po_header_id   =
                                                       ln_po_header_id,
                                                   new_po_line_id   =
                                                       ln_po_line_id,
                                                   new_po_distribution_id   =
                                                       ln_po_distribution_id,
                                                   new_line_location_id   =
                                                       ln_po_line_loc_id,
                                                   ship_to_location_id   =
                                                       ln_ship_to_location_id,
                                                   ship_to_location_code   =
                                                       CASE
                                                           WHEN ln_po_header_id
                                                                    IS NOT NULL
                                                           THEN
                                                               NULL
                                                           ELSE
                                                               invoice_line_info_tbl (
                                                                   lcu_inv_line_rec).ship_to_location_code
                                                       END
                                             WHERE     old_invoice_id =
                                                       invoice_line_info_tbl (
                                                           lcu_inv_line_rec).old_invoice_id
                                                   AND line_number =
                                                       invoice_line_info_tbl (
                                                           lcu_inv_line_rec).line_number
                                                   AND dist_line_number =
                                                       invoice_line_info_tbl (
                                                           lcu_inv_line_rec).dist_line_number;

                                            COMMIT;
                                            print_log_prc (
                                                p_debug,
                                                'After setting line record status to V');
                                        ELSE
                                            ln_lines_err_count   :=
                                                ln_lines_err_count + 1;
                                            print_log_prc (
                                                p_debug,
                                                'Before setting line record status to E');

                                            UPDATE xxd_ap_invoice_dist_conv_stg_t
                                               SET record_status   = 'E',
                                                   error_message   =
                                                       lc_l_err_msg,
                                                   request_id      =
                                                       gn_req_id,
                                                   last_update_date   =
                                                       gd_sysdate,
                                                   last_updated_by   =
                                                       gn_user_id,
                                                   new_org_id      =
                                                       ln_org_id,
                                                   new_dist_ccid   =
                                                       CASE
                                                           WHEN ln_po_header_id
                                                                    IS NOT NULL
                                                           THEN
                                                               NULL
                                                           ELSE
                                                               ln_ccid
                                                       END,
                                                   new_coa_id      =
                                                       lc_coa_id,
                                                   concatenated_segments   =
                                                       lc_new_conc_segs,
                                                   new_po_header_id   =
                                                       ln_po_header_id,
                                                   new_po_line_id   =
                                                       ln_po_line_id,
                                                   new_po_distribution_id   =
                                                       ln_po_distribution_id,
                                                   new_line_location_id   =
                                                       ln_po_line_loc_id,
                                                   ship_to_location_id   =
                                                       ln_ship_to_location_id,
                                                   ship_to_location_code   =
                                                       CASE
                                                           WHEN ln_po_header_id
                                                                    IS NOT NULL
                                                           THEN
                                                               NULL
                                                           ELSE
                                                               invoice_line_info_tbl (
                                                                   lcu_inv_line_rec).ship_to_location_code
                                                       END
                                             WHERE     old_invoice_id =
                                                       invoice_line_info_tbl (
                                                           lcu_inv_line_rec).old_invoice_id
                                                   AND line_number =
                                                       invoice_line_info_tbl (
                                                           lcu_inv_line_rec).line_number;



                                            COMMIT;
                                            print_log_prc (
                                                p_debug,
                                                'After setting line record status to E');
                                        END IF;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            lc_error_code   := SQLCODE;
                                            lc_err_message   :=
                                                SUBSTR (SQLERRM, 1, 250);
                                            xxd_common_utils.record_error (
                                                'APINV',
                                                xxd_common_utils.get_org_id,
                                                'Deckers AP Invoice Conversion Program',
                                                lc_l_err_msg,
                                                DBMS_UTILITY.format_error_backtrace,
                                                gn_user_id,
                                                gn_req_id,
                                                lc_err_message,
                                                   'Code pointer : '
                                                || gc_code_pointer);
                                    END;
                                END LOOP;
                            END IF;



                            EXIT WHEN invoice_line_c%NOTFOUND;
                        END LOOP;

                        gc_code_pointer              :=
                               'END Checking Invoice ln_line_err_count : '
                            || ln_line_err_count;
                        print_log_prc (p_debug, gc_code_pointer);
                        print_log_prc (
                            p_debug,
                               'ln_err_count = '
                            || ln_err_count
                            || ' and ln_line_err_count ='
                            || ln_line_err_count);

                        -- If line error count is 0 update lines stagigng table with record_status is V - validated
                        -- Else setting record_status to E - Error for both line and invoice tables
                        IF ln_err_count = 0 AND ln_lines_err_count = 0
                        THEN
                            print_log_prc (
                                p_debug,
                                'Before setting invoice record status to V');

                            UPDATE xxd_ap_invoice_conv_stg_t
                               SET record_status = 'V', error_message = NULL, new_vendor_id = ln_vendor_id,
                                   new_vendor_site_id = ln_vendor_site_id, terms_id = ln_term_id, pay_group_lookup_code = NVL (lc_pay_group, invoice_info_tbl (lcu_invoice_rec).pay_group_lookup_code),
                                   payment_method_code = NVL (lc_payment_method_code, invoice_info_tbl (lcu_invoice_rec).payment_method_code), request_id = gn_req_id, last_update_date = gd_sysdate,
                                   last_updated_by = gn_user_id, org_id = ln_org_id, exchange_rate = ln_exchange_rate,
                                   exchange_rate_type = lc_exchange_rate_type, exchange_date = ld_exchange_date
                             WHERE old_invoice_id =
                                   invoice_info_tbl (lcu_invoice_rec).old_invoice_id;

                            COMMIT;
                            print_log_prc (
                                p_debug,
                                'After setting invoice record status to V');
                        END IF;

                        IF ln_err_count <> 0
                        THEN
                            print_log_prc (
                                p_debug,
                                'Before setting invoice record status to E');

                            UPDATE xxd_ap_invoice_conv_stg_t
                               SET record_status = 'E', error_message = lc_h_err_msg, new_vendor_id = ln_vendor_id,
                                   new_vendor_site_id = ln_vendor_site_id, terms_id = ln_term_id, pay_group_lookup_code = NVL (lc_pay_group, invoice_info_tbl (lcu_invoice_rec).pay_group_lookup_code),
                                   payment_method_code = NVL (lc_payment_method_code, invoice_info_tbl (lcu_invoice_rec).payment_method_code), request_id = gn_req_id, last_update_date = gd_sysdate,
                                   last_updated_by = gn_user_id, org_id = ln_org_id, exchange_rate = ln_exchange_rate,
                                   exchange_rate_type = lc_exchange_rate_type, exchange_date = ld_exchange_date
                             WHERE old_invoice_id =
                                   invoice_info_tbl (lcu_invoice_rec).old_invoice_id;

                            UPDATE xxd_ap_invoice_dist_conv_stg_t
                               SET record_status = 'E', error_message = 'Header Validation falied : ' || error_message, request_id = gn_req_id,
                                   last_update_date = gd_sysdate, last_updated_by = gn_user_id
                             WHERE old_invoice_id =
                                   invoice_info_tbl (lcu_invoice_rec).old_invoice_id;


                            COMMIT;
                            print_log_prc (
                                p_debug,
                                'After setting invoice record status to E');
                        END IF;

                        IF ln_err_count = 0 AND ln_lines_err_count <> 0
                        THEN
                            print_log_prc (
                                p_debug,
                                'Before setting invoice record status to E');

                            UPDATE xxd_ap_invoice_conv_stg_t
                               SET record_status = 'E', error_message = 'Child record failed for validation', request_id = gn_req_id,
                                   last_update_date = gd_sysdate, last_updated_by = gn_user_id, org_id = ln_org_id,
                                   exchange_rate = ln_exchange_rate, exchange_rate_type = lc_exchange_rate_type, exchange_date = ld_exchange_date
                             WHERE old_invoice_id =
                                   invoice_info_tbl (lcu_invoice_rec).old_invoice_id;

                            UPDATE xxd_ap_invoice_dist_conv_stg_t
                               SET record_status = 'E', error_message = 'Other Invoice Lines failed in validation', request_id = gn_req_id,
                                   last_update_date = gd_sysdate, last_updated_by = gn_user_id
                             WHERE     old_invoice_id =
                                       invoice_info_tbl (lcu_invoice_rec).old_invoice_id
                                   AND record_status <> 'E';



                            COMMIT;
                            print_log_prc (
                                p_debug,
                                'After setting invoice record status to E');
                        END IF;

                        print_log_prc (
                            p_debug,
                            'END**********************************************************************************END');
                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lc_error_code    := SQLCODE;
                            lc_err_message   := SUBSTR (SQLERRM, 1, 250);

                            xxd_common_utils.record_error (
                                'APINV',
                                xxd_common_utils.get_org_id,
                                'Deckers AP Invoice Conversion Program',
                                lc_err_message,
                                DBMS_UTILITY.format_error_backtrace,
                                gn_user_id,
                                gn_req_id,
                                lc_err_message,
                                'Code pointer : ' || gc_code_pointer);
                    END;
                END LOOP;
            END IF;

            EXIT WHEN invoice_c%NOTFOUND;
        END LOOP;

        BEGIN
            SELECT COUNT (*)
              INTO gn_inv_extract
              FROM xxd_ap_invoice_conv_stg_t
             WHERE     record_status = 'V'
                   AND batch_number BETWEEN p_batch_low AND p_batch_high;

            SELECT COUNT (*)
              INTO gn_dist_extract
              FROM xxd_ap_invoice_dist_conv_stg_t
             WHERE     record_status = 'V'
                   AND old_invoice_id IN
                           (SELECT old_invoice_id
                              FROM xxd_ap_invoice_conv_stg_t
                             WHERE     record_status = 'V'
                                   AND batch_number BETWEEN p_batch_low
                                                        AND p_batch_high);
        END;

        -- Writing Counts to output file.

        fnd_file.put_line (
            fnd_file.output,
            'Deckers AP Invoice Conversion Program for Validation');
        fnd_file.put_line (
            fnd_file.output,
            '-------------------------------------------------');

        fnd_file.put_line (
            fnd_file.output,
               'Total no records validated in XXD_AP_INVOICE_CONV_STG_T Table '
            || gn_inv_extract);
        fnd_file.put_line (
            fnd_file.output,
               'Total no records validated in XXD_AP_INVOICE_DIST_CONV_STG_T Table '
            || gn_dist_extract);

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            IF invoice_c%ISOPEN
            THEN
                CLOSE invoice_c;
            END IF;

            IF invoice_line_c%ISOPEN
            THEN
                CLOSE invoice_line_c;
            END IF;

            IF invoice_type_c%ISOPEN
            THEN
                CLOSE invoice_type_c;
            END IF;


            lc_err_message   :=
                   'Unexpected error occured in the procedure Validate while processing :'
                || SUBSTR (SQLERRM, 1, 250);
            fnd_file.put_line (fnd_file.LOG,
                               ' Code Pointer: ' || gc_code_pointer);
            fnd_file.put_line (fnd_file.LOG,
                               ' Error Message : ' || lc_err_message);

            xxd_common_utils.record_error (
                'APINV',
                xxd_common_utils.get_org_id,
                'Deckers AP Invoice Conversion Program',
                lc_err_message,
                DBMS_UTILITY.format_error_backtrace,
                gn_user_id,
                gn_req_id,
                'Code pointer : ' || gc_code_pointer);
    END validate_records_prc;


    /****************************************************************************************
        * Procedure : CREATE_BATCH_PRC
        * Synopsis  : This Procedure shall create batch Processes
        * Design    : Program input p_batch_size is considered to divide records and batch number is assigned
        * Notes     :
        * Return Values: None
        * Modification :
        * Date          Developer     Version    Description
        *--------------------------------------------------------------------------------------
        * 07-JUL-2014   Swapna N        1.00       Created
        ****************************************************************************************/


    PROCEDURE create_batch_prc (x_retcode OUT NUMBER, x_errbuff OUT VARCHAR2, p_batch_size IN NUMBER
                                , p_debug IN VARCHAR2)
    AS
        /* Variable Declaration*/
        ln_count          NUMBER;
        ln_batch_count    NUMBER;
        ln_batch_number   NUMBER;
        ln_first_rec      NUMBER;
        ln_last_rec       NUMBER;
        ln_end_rec        NUMBER;
    BEGIN
        ln_count         := 0;
        ln_batch_count   := 1;
        ln_first_rec     := 1;
        ln_last_rec      := 1;
        ln_end_rec       := 1;

        --Getting count of records and min and max record_id's.

        SELECT COUNT (record_id), MIN (record_id), MAX (record_id)
          INTO ln_count, ln_first_rec, ln_last_rec
          FROM xxd_ap_invoice_conv_stg_t
         WHERE record_status IN ('N', 'E') AND batch_number IS NULL;


        --Caluclating number of batches based on record count and batch size

        SELECT CEIL (ln_count / p_batch_size) INTO ln_batch_count FROM DUAL;

        IF ln_batch_count <= 1
        THEN
            ln_batch_count   := 1;
        END IF;

        FOR lcu_batch_rec IN 1 .. ln_batch_count
        LOOP
            IF lcu_batch_rec <> 1
            THEN
                ln_first_rec   := ln_first_rec + p_batch_size;
            END IF;

            ln_end_rec        := (ln_first_rec + (p_batch_size - 1));

            IF lcu_batch_rec = ln_batch_count
            THEN
                ln_end_rec   := ln_last_rec;
            END IF;

            ln_batch_number   := xxd_ap_invoice_conv_batch_s.NEXTVAL;

            -- Updating staging tables record with corresponding batch number.

            BEGIN
                UPDATE xxd_ap_invoice_conv_stg_t
                   SET batch_number = ln_batch_number, last_update_date = gd_sysdate, last_updated_by = gn_user_id
                 WHERE     record_status IN ('N', 'E') --AND batch_number IS NULL
                       AND record_id BETWEEN ln_first_rec AND ln_end_rec;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    print_log_prc (
                        p_debug,
                        'Error while updating batch_number: ' || SQLERRM);
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log_prc (
                p_debug,
                   'Error in XXD_AP_INVOICE_CONV_PKG.create_batch_prc: '
                || SQLERRM);
    END create_batch_prc;


    /****************************************************************************************
             * Procedure : PRINT_LOG_PRC
             * Synopsis  : This Procedure shall write to the concurrent program log file
             * Design    : Program input debug flag is 'Y' then the procedure shall write the message
             *             input to concurrent program log file
             * Notes     :
             * Return Values: None
             * Modification :
             * Date          Developer     Version    Description
             *--------------------------------------------------------------------------------------
             * 07-JUL-2014   Swapna N        1.00       Created
             ****************************************************************************************/

    PROCEDURE print_log_prc (p_debug_flag IN VARCHAR2, p_message IN VARCHAR2)
    AS
    BEGIN
        IF p_debug_flag = 'Y'
        THEN
            fnd_file.put_line (apps.fnd_file.LOG, p_message);
        END IF;
    END print_log_prc;

    /****************************************************************************************
             * Procedure : GET_NEW_ORG_ID
             * Synopsis  : This Procedure shall provide the new org_id for given 12.0 operating_unit name
             * Design    : Program input old_operating_unit_name is passed
             * Notes     :
             * Return Values: None
             * Modification :
             * Date          Developer     Version    Description
             *--------------------------------------------------------------------------------------
             * 07-JUL-2014   Swapna N        1.00       Created
             ****************************************************************************************/

    PROCEDURE get_new_org_id (p_old_org_name IN VARCHAR2, p_debug_flag IN VARCHAR2, x_new_org_id OUT NUMBER
                              , x_new_org_name OUT VARCHAR2)
    IS
        lc_attribute2    VARCHAR2 (1000);
        lc_error_code    VARCHAR2 (1000);
        lc_error_msg     VARCHAR2 (1000);
        lc_attribute1    VARCHAR2 (1000);
        xc_meaning       VARCHAR2 (1000);
        xc_description   VARCHAR2 (1000);
        xc_lookup_code   VARCHAR2 (1000);
        ln_org_id        NUMBER;

        CURSOR org_id_c (p_org_name VARCHAR2)
        IS
            SELECT organization_id
              FROM hr_operating_units
             WHERE name = p_org_name;
    BEGIN
        xc_meaning       := p_old_org_name;

        print_log_prc (p_debug_flag, 'p_old_org_name : ' || p_old_org_name);

        --Passing old operating unit name to fetch corresponding new operating_unit name

        xxd_common_utils.get_mapping_value (
            p_lookup_type    => 'XXD_1206_OU_MAPPING',
            px_lookup_code   => xc_lookup_code,
            px_meaning       => xc_meaning,
            px_description   => xc_description,
            x_attribute1     => lc_attribute1,
            x_attribute2     => lc_attribute2,
            x_error_code     => lc_error_code,
            x_error_msg      => lc_error_msg);

        print_log_prc (p_debug_flag, 'lc_attribute1 : ' || lc_attribute1);

        x_new_org_name   := lc_attribute1;

        -- Calling cursor to fetch Org_id for a given operating_unit name.

        OPEN org_id_c (lc_attribute1);

        ln_org_id        := NULL;

        FETCH org_id_c INTO ln_org_id;

        CLOSE org_id_c;

        x_new_org_id     := ln_org_id;
    END get_new_org_id;

    /****************************************************************************************
             * Procedure : IMPORT_INVOICE_FROM_INTERFACE
             * Synopsis  : This Procedure shall provide the  org_id  to launch Payabales Open Interface program
             * Design    :
             * Notes     :
             * Return Values: None
             * Modification :
             * Date          Developer     Version    Description
             *--------------------------------------------------------------------------------------
             * 07-JUL-2014   Swapna N        1.00       Created
             ****************************************************************************************/


    /*
       PROCEDURE import_invoice_from_interface (p_org_id       IN NUMBER,
                                                p_debug_flag   IN VARCHAR2)
       IS
          CURSOR invoice_source_c
          IS
             SELECT DISTINCT source
               FROM ap_invoices_interface
              WHERE org_id = p_org_id;

          TYPE invoice_info_source_type IS TABLE OF invoice_source_c%ROWTYPE
                                              INDEX BY BINARY_INTEGER;

          invoice_info_source_tbl   invoice_info_source_type;

          TYPE request_id_tab_typ IS TABLE OF NUMBER
                                        INDEX BY BINARY_INTEGER;

          request_id_tab            request_id_tab_typ;
          ln_inv_vald_req_id        NUMBER;
          ln_conc_req_id            NUMBER;
          ln_inv_vald_req_id        NUMBER;
          lb_wait_for_request       BOOLEAN;
          lc_phase                  VARCHAR2 (10);
          lc_status                 VARCHAR2 (10);
          lc_dev_phase              VARCHAR2 (10);
          lc_dev_status             VARCHAR2 (10);
          lc_message                VARCHAR2 (500);
          lc_error_message          VARCHAR2 (1000);
       BEGIN
          print_log_prc (p_debug_flag, 'p_org_id is  : ' || p_org_id);

          gc_code_pointer := 'fetch distinct source';
          print_log_prc (p_debug_flag, gc_code_pointer);

          mo_global.set_policy_context ('S', p_org_id);

          -- Get Distinct source for giving operating unit from invoice interface table

          OPEN invoice_source_c;

          gc_code_pointer :=
             'fetch distinct source count - ' || invoice_info_source_tbl.COUNT;
          print_log_prc (p_debug_flag, gc_code_pointer);

          invoice_info_source_tbl.delete;

          FETCH invoice_source_c
          BULK COLLECT INTO invoice_info_source_tbl;

          gc_code_pointer :=
             'fetch distinct source count - ' || invoice_info_source_tbl.COUNT;
          print_log_prc (p_debug_flag, gc_code_pointer);

          -- Loop to launch payables open interface program for each source

          FOR lcu_inv_src_rec IN 1 .. invoice_info_source_tbl.COUNT
          LOOP
             ln_conc_req_id :=
                fnd_request.submit_request (
                   'SQLAP',
                   'APXIIMPT',
                   NULL,
                   NULL,
                   FALSE,
                   p_org_id,
                   invoice_info_source_tbl (lcu_inv_src_rec).source,     -- Source
                   NULL,                                               -- Group ID
                   'N/A', --'Conversion for source ' || i_inv_source.source ||'-'||i_inv_source.org_id||'-'||gn_Conc_request_id, -- Batch
                   NULL,                                              -- Hold Code
                   NULL,                                            -- Hold Reason
                   TO_CHAR (gd_sysdate, 'YYYY/MM/DD HH24:MI:SS'),       -- GL Date
                   'N',                                                   -- Purge
                   'N',
                   'Y',
                   'N',
                   1000,
                   gn_user_id,
                   0);

             request_id_tab (lcu_inv_src_rec) := ln_conc_req_id;

             IF ln_conc_req_id = 0
             THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'Sub-request failed to submit: Retcode-' || 1);
                RETURN;
             ELSE
                request_id_tab (request_id_tab.COUNT + 1) := ln_conc_req_id;
                fnd_file.put_line (
                   fnd_file.LOG,
                      'Sub-request for process'
                   || '1 is '
                   || TO_CHAR (ln_conc_req_id));
             END IF;

             COMMIT;
          END LOOP;


          --Waiting for child program to complete
          FOR rec IN request_id_tab.FIRST .. request_id_tab.LAST
          LOOP
             IF request_id_tab (rec) IS NOT NULL
             THEN
                LOOP
                   lc_dev_phase := NULL;
                   lc_dev_status := NULL;
                   lb_wait_for_request :=
                      fnd_concurrent.wait_for_request (
                         request_id   => request_id_tab (rec), --ln_concurrent_request_id
                         interval     => 5,
                         phase        => lc_phase,
                         status       => lc_status,
                         dev_phase    => lc_dev_phase,
                         dev_status   => lc_dev_status,
                         MESSAGE      => lc_message);

                   IF (   (UPPER (lc_dev_phase) = 'COMPLETE')
                       OR (UPPER (lc_phase) = 'COMPLETED'))
                   THEN
                      EXIT;
                   END IF;
                END LOOP;
             END IF;
          END LOOP;

          gc_code_pointer := 'Updating record status in staging tables ';



          --Updating record status in staging tables

          UPDATE xxd_ap_invoice_conv_stg_t xaic
             SET record_status = 'P'
           WHERE     1 = 1
                 AND EXISTS
                        (SELECT 1
                           FROM ap_invoices_all aia
                          WHERE     aia.invoice_num = xaic.invoice_num
                                AND aia.vendor_id = xaic.new_vendor_id);

          UPDATE xxd_ap_invoice_dist_conv_stg_t xaid
             SET record_status = 'P'
           WHERE     1 = 1
                 AND EXISTS
                        (SELECT 1
                           FROM xxd_ap_invoice_conv_stg_t xaic
                          WHERE     xaid.old_invoice_id = xaic.old_invoice_id
                                AND xaic.record_status = 'P');



          BEGIN
             SELECT COUNT (*)
               INTO gn_inv_extract
               FROM xxd_ap_invoice_conv_stg_t
              WHERE record_status = 'P';

             SELECT COUNT (*)
               INTO gn_dist_extract
               FROM xxd_ap_invoice_dist_conv_stg_t
              WHERE record_status = 'P';
          END;


          --Writing counts to output file

          fnd_file.put_line (fnd_file.output,
                             'Deckers AP Invoice Conversion Program for Import');
          fnd_file.put_line (fnd_file.output,
                             '-------------------------------------------------');

          fnd_file.put_line (
             fnd_file.output,
                'Total no records Processed in  XXD_AP_INVOICE_CONV_STG_T Table '
             || gn_inv_extract);
          fnd_file.put_line (
             fnd_file.output,
                'Total no records Processed in  XXD_AP_INVOICE_DIST_CONV_STG_T Table '
             || gn_dist_extract);
       EXCEPTION
          WHEN OTHERS
          THEN
             lc_error_message :=
                   'Unexpected error occured in the procedure interface_load_prc while processing :'
                || SUBSTR (SQLERRM, 1, 250);
             fnd_file.put_line (fnd_file.LOG,
                                ' Code Pointer: ' || gc_code_pointer);
             fnd_file.put_line (fnd_file.LOG,
                                ' Error Message : ' || lc_error_message);

             xxd_common_utils.record_error (
                'APINV',
                xxd_common_utils.get_org_id,
                'Deckers AP Invoice Conversion Program',
                lc_error_message,
                DBMS_UTILITY.format_error_backtrace,
                gn_user_id,
                gn_req_id,
                'Code pointer : ' || gc_code_pointer);
       END import_invoice_from_interface;*/

    /****************************************************************************************
        * Procedure : VALIDATE_INVOICE
        * Synopsis  : This Procedure will validate invoices created from open interface import
        * Design    :
        * Notes     :
        * Return Values: None
        * Modification :
        * Date          Developer     Version    Description
        *--------------------------------------------------------------------------------------
        * 07-JUL-2014   Swapna N        1.00       Created
        ****************************************************************************************/

    /*   PROCEDURE validate_invoice (p_org_id IN NUMBER, p_debug_flag IN VARCHAR2)
       IS
          CURSOR val_inv_c
          IS
             SELECT DISTINCT
                    aba.batch_name batch_name,
                    stg.org_id org_id,
                    aba.batch_id batch_id
               FROM apps.ap_invoices_all aia,
                    apps.ap_batches_all aba,
                    xxd_conv.xxd_ap_invoice_conv_stg_t stg
              WHERE     aia.batch_id = aba.batch_id
                    AND aia.invoice_num = stg.invoice_num
                    AND stg.record_status = 'P';

          TYPE invoice_val_type IS TABLE OF val_inv_c%ROWTYPE
                                      INDEX BY BINARY_INTEGER;

          invoice_val_tbl       invoice_val_type;

          TYPE request_id_tab_typ IS TABLE OF NUMBER
                                        INDEX BY BINARY_INTEGER;


          request_id_tab        request_id_tab_typ;

          ln_inv_vald_req_id    NUMBER;
          ln_conc_req_id        NUMBER;
          ln_inv_vald_req_id    NUMBER;
          lb_wait_for_request   BOOLEAN;
          lc_phase              VARCHAR2 (10);
          lc_status             VARCHAR2 (10);
          lc_dev_phase          VARCHAR2 (10);
          lc_dev_status         VARCHAR2 (10);
          lc_message            VARCHAR2 (500);
          lc_error_message      VARCHAR2 (1000);
       BEGIN
          invoice_val_tbl.delete;

          gc_code_pointer := 'After invoice_val_tbl.delete';
          print_log_prc (p_debug_flag, gc_code_pointer);

          OPEN val_inv_c;

          invoice_val_tbl.delete;

          FETCH val_inv_c
          BULK COLLECT INTO invoice_val_tbl;

          CLOSE val_inv_c;

          gc_code_pointer := 'After  BULK COLLECT INTO invoice_val_tbl';
          print_log_prc (p_debug_flag, gc_code_pointer);


          gc_code_pointer :=
                'After  BULK COLLECT INTO  invoice_val_tbl.COUNT - '
             || invoice_val_tbl.COUNT;
          print_log_prc (p_debug_flag, gc_code_pointer);

          request_id_tab.delete;

          -- Launching Invoice Validation in loop for distinct batch_name,batch_id and org_id from staging tbales for the invoices that got created in Ap_invoices_all table

          IF (invoice_val_tbl.COUNT > 0)
          THEN
             FOR lcu_invoice_rec IN 1 .. invoice_val_tbl.COUNT
             LOOP
                ln_conc_req_id :=
                   fnd_request.submit_request (
                      'SQLAP',
                      'APPRVL',
                      'Invoice Validation',
                      NULL,
                      FALSE,
                      invoice_val_tbl (lcu_invoice_rec).org_id,
                      'All',
                      invoice_val_tbl (lcu_invoice_rec).batch_id,
                      NULL,
                      NULL,
                      NULL,
                      NULL,
                      NULL,
                      NULL,
                      NULL                                                  --'N',
                                                                            --1000
                      );

                request_id_tab (lcu_invoice_rec) := ln_conc_req_id;

                IF ln_conc_req_id = 0
                THEN
                   fnd_file.put_line (
                      fnd_file.LOG,
                      'Sub-request failed to submit: Retcode-' || 1);
                   RETURN;
                ELSE
                   request_id_tab (request_id_tab.COUNT + 1) := ln_conc_req_id;
                   fnd_file.put_line (
                      fnd_file.LOG,
                         'Sub-request for process'
                      || '1 is '
                      || TO_CHAR (ln_conc_req_id));
                END IF;

                COMMIT;
             END LOOP;


             FOR rec IN request_id_tab.FIRST .. request_id_tab.LAST
             LOOP
                IF request_id_tab (rec) IS NOT NULL
                THEN
                   LOOP
                      lc_dev_phase := NULL;
                      lc_dev_status := NULL;
                      lb_wait_for_request :=
                         fnd_concurrent.wait_for_request (
                            request_id   => request_id_tab (rec), --ln_concurrent_request_id
                            interval     => 5,
                            phase        => lc_phase,
                            status       => lc_status,
                            dev_phase    => lc_dev_phase,
                            dev_status   => lc_dev_status,
                            MESSAGE      => lc_message);

                      IF (   (UPPER (lc_dev_phase) = 'COMPLETE')
                          OR (UPPER (lc_phase) = 'COMPLETED'))
                      THEN
                         EXIT;
                      END IF;
                   END LOOP;
                END IF;
             END LOOP;

             gc_code_pointer := 'Updating record status in staging tables ';

             --Updating record status in staging tables

             UPDATE xxd_ap_invoice_conv_stg_t xaic
                SET record_status = 'INV_VAL'
              WHERE     1 = 1
                    AND EXISTS
                           (SELECT 1
                              FROM ap_invoices_all aia
                             WHERE     aia.vendor_id = xaic.new_vendor_id
                                   AND aia.invoice_num = xaic.invoice_num
                                   AND apps.ap_invoices_pkg.get_approval_status (
                                          aia.invoice_id,
                                          aia.invoice_amount,
                                          aia.payment_status_flag,
                                          aia.invoice_type_lookup_code) = 'V');

             UPDATE xxd_ap_invoice_conv_stg_t xaid
                SET record_status = 'INV_VAL'
              WHERE     1 = 1
                    AND EXISTS
                           (SELECT 1
                              FROM xxd_ap_invoice_conv_stg_t xaic
                             WHERE     xaid.old_invoice_id = xaic.old_invoice_id
                                   AND xaic.record_status = 'INV_VAL');
          END IF;

          BEGIN
             SELECT COUNT (*)
               INTO gn_inv_extract
               FROM xxd_ap_invoice_conv_stg_t
              WHERE record_status = 'INV_VAL';

             SELECT COUNT (*)
               INTO gn_dist_extract
               FROM xxd_ap_invoice_conv_stg_t
              WHERE record_status = 'INV_VAL';
          END;

          --Writing counts to output file

          fnd_file.put_line (fnd_file.output,
                             'Deckers AP Invoice Conversion Program for Import');
          fnd_file.put_line (fnd_file.output,
                             '-------------------------------------------------');

          fnd_file.put_line (
             fnd_file.output,
                'Total no records Processed in  XXD_AP_1099_INV_CONV_STG_T Table '
             || gn_inv_extract);
          fnd_file.put_line (
             fnd_file.output,
                'Total no records Processed in  XXD_AP_1099_DIST_CONV_STG_T Table '
             || gn_dist_extract);
       EXCEPTION
          WHEN OTHERS
          THEN
             lc_error_message :=
                   'Unexpected error occured in the procedure VALIDATE_INVOICE while processing :'
                || SUBSTR (SQLERRM, 1, 250);
             fnd_file.put_line (fnd_file.LOG,
                                ' Code Pointer: ' || gc_code_pointer);
             fnd_file.put_line (fnd_file.LOG,
                                ' Error Message : ' || lc_error_message);

             xxd_common_utils.record_error (
                'APINV',
                xxd_common_utils.get_org_id,
                'Deckers AP Invoice Conversion Program',
                lc_error_message,
                DBMS_UTILITY.format_error_backtrace,
                gn_req_id,
                gn_req_id,
                'Unexpected error occured in the procedure VALIDATE_INVOICE while processing ');
       END validate_invoice;
    */
    PROCEDURE release_holds (x_retcode OUT NUMBER, x_errbuf OUT VARCHAR2)
    IS
        v_hold_cnt     NUMBER := NULL;
        v_apprvl_sts   ap_invoices.wfapproval_status%TYPE := NULL;
        v_user_id      NUMBER := fnd_global.user_id;
        v_resp_id      NUMBER := fnd_global.resp_id;

        CURSOR lcu_distinct_orgs IS
              SELECT org_id
                FROM ap_holds hld
               WHERE     HOLD_LOOKUP_CODE IS NOT NULL
                     AND RELEASE_LOOKUP_CODE IS NULL
                     AND EXISTS
                             (SELECT 1
                                FROM ap_invoices_all aia
                               WHERE     hld.invoice_id = aia.invoice_id
                                     AND aia.source = 'CONVERSIONS')
            GROUP BY org_id;

        CURSOR lcu_inv_on_hold (p_org_id NUMBER)
        IS
            SELECT DISTINCT invoice_id
              FROM ap_holds hld
             WHERE     HOLD_LOOKUP_CODE IS NOT NULL
                   AND RELEASE_LOOKUP_CODE IS NULL
                   AND EXISTS
                           (SELECT 1
                              FROM ap_invoices_all aia
                             WHERE     hld.invoice_id = aia.invoice_id
                                   AND aia.source = 'CONVERSIONS')
                   AND org_id = p_org_id;
    BEGIN
        FOR rec_distinct_orgs IN lcu_distinct_orgs
        LOOP
            BEGIN
                mo_global.set_policy_context ('S', rec_distinct_orgs.org_id);
            END;


            FOR lr_rec IN lcu_inv_on_hold (rec_distinct_orgs.org_id)
            LOOP
                v_hold_cnt     := NULL;
                v_apprvl_sts   := NULL;

                FND_FILE.put_line (
                    FND_FILE.LOG,
                    'Releasing Hold for : ' || lr_rec.invoice_id);


                ap_holds_pkg.quick_release (x_invoice_id => lr_rec.invoice_id, x_hold_lookup_code => 'QTY ORD', x_release_lookup_code => 'HOLDS QUICK RELEASED', x_release_reason => 'Holds Released', x_responsibility_id => v_resp_id, x_last_updated_by => v_user_id, x_last_update_date => SYSDATE, x_holds_count => v_hold_cnt, x_approval_status_lookup_code => v_apprvl_sts
                                            , x_calling_sequence => NULL --'xxap_invoice_util_pkg.release_holds'
                                                                        );

                FND_FILE.put_line (
                    FND_FILE.LOG,
                       'Hold count = '
                    || v_hold_cnt
                    || ', Approval Status:'
                    || v_apprvl_sts);
            END LOOP;
        END LOOP;

        COMMIT;
        x_retcode   := 0;
        x_errbuf    := 'Hold released successfully';
    EXCEPTION
        WHEN OTHERS
        THEN
            x_retcode   := 1;
            x_errbuf    := 'Oracle Exception:' || SUBSTR (SQLERRM, 1, 500);
            FND_FILE.put_line (
                FND_FILE.LOG,
                'Oracle Exception:' || SUBSTR (SQLERRM, 1, 500));
    END release_holds;
END xxd_ap_invoice_conv_pkg;
/
