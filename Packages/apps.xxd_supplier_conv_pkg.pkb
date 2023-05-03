--
-- XXD_SUPPLIER_CONV_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:10 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_SUPPLIER_CONV_PKG"
AS                                                                      --2500
    /* $Header: XX_SUPPLIER_CONV_PKG.pks 120.2.12010000.2 2014/06/5 09:44:58 PwCSDC ship

      -- Purpose : This package is used to import AP Supplier/Site/Contact/Banks/Branches and Account
      -- Public function and procedures
    ***************************************************************************************
      Program    : XXD_SUPPLIER_CONV_PKG
      Author     :
      Owner      : APPS
      Modifications:
      -------------------------------------------------------------------------------
      Date           version    Author          Description
      -------------  ------- ----------     -----------------------------------------
      5-Jun-2014    1.0     BT Technology team   Initial Version
      1-Apr-2015    1.1     BT Technology team   Modification
      22-Apr-2015   1.2     BT Tech team -       Purchasing and Pay site flag default enable
      16-Jun-2015   1.3     BT Technology team   UAT Changes/ Added Columns for Supplier Contacts
      24-Jul-2015   1.4     BT Technology team   Added Bank account type while creating account
    ***************************************************************************************/
    gn_supp_reject               NUMBER;
    gn_supp_process              NUMBER;
    gn_supp_bank_rejected        NUMBER;
    gn_supp_bank_processed       NUMBER;
    gn_site_rejected             NUMBER;
    gn_site_processed            NUMBER;
    gn_contact_processed         NUMBER;
    gn_contact_rejected          NUMBER;
    gn_sup_site_bank_rejected    NUMBER;
    gn_sup_site_bank_processed   NUMBER;
    gn_supplier_found            NUMBER;
    gn_sites_found               NUMBER;
    gn_contacts_found            NUMBER;
    gn_supp_bank_found           NUMBER;
    gn_site_bank_found           NUMBER;
    gn_conc_request_id           NUMBER := fnd_global.conc_request_id;
    gn_sup_reject_l              NUMBER;
    gn_supp_process_l            NUMBER;
    gn_supp_bank_reject_l        NUMBER;
    gn_supp_bank_process_l       NUMBER;
    gn_site_reject_l             NUMBER;
    gn_site_process_l            NUMBER;
    gn_contact_process_l         NUMBER;
    gn_contact_reject_l          NUMBER;
    gn_sup_site_bank_reject_l    NUMBER;
    gn_sup_site_bank_process_l   NUMBER;
    gn_sup_found_l               NUMBER;
    gn_sites_found_l             NUMBER;
    gn_cont_found_l              NUMBER;
    gn_supp_bank_found_l         NUMBER;
    gn_site_bank_found_l         NUMBER;
    gn_sup_bank_found_l          NUMBER;
    gn_supp_extract_cnt          NUMBER;
    gn_site_extract_cnt          NUMBER;
    gn_cont_extract_cnt          NUMBER;
    gn_bank_extract_cnt          NUMBER;
    gc_user_name                 VARCHAR2 (30);
    gc_dbname                    VARCHAR2 (30);
    gc_extract_only              VARCHAR2 (30) := 'EXTRACT';
    gc_validate_only             VARCHAR2 (30) := 'VALIDATE';
    gc_load_only                 VARCHAR2 (30) := 'LOAD';
    gc_process_status            VARCHAR2 (2) := 'P';
    gc_error_status              VARCHAR2 (2) := 'E';
    gc_validate_status           VARCHAR2 (2) := 'V';
    gn_suc_const                 NUMBER (2) := 1;
    gn_err_const                 NUMBER (2) := 2;
    gc_pay_group                 VARCHAR2 (30) := 'CHECK';
    gc_pay_method                VARCHAR2 (30) := 'CHECK';
    gc_notif_method              VARCHAR2 (30) := 'PRINT';
    gc_email                     VARCHAR2 (30) := 'EMAIL';
    gc_match_option              VARCHAR2 (2) := 'P';

    PROCEDURE log_records (p_debug VARCHAR2, p_message VARCHAR2)
    IS
        cnt   NUMBER := 0;
    BEGIN
        IF p_debug = 'Y'
        THEN
            fnd_file.put_line (fnd_file.LOG, p_message);
        END IF;
    END log_records;

    PROCEDURE extract_r1206_supplier_info (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, p_debug IN VARCHAR2)
    IS
        CURSOR c_supp_r1206 IS
            SELECT *
              FROM xxd_ap_suppliers_conv_v aps
             WHERE     1 = 1
                   --                AND SEGMENT1 IN ('9446', '12618', '2', '9358')
                   AND NOT EXISTS
                           (SELECT 1
                              FROM ap_suppliers ap
                             WHERE aps.segment1 = ap.segment1);

        --                AND ROWNUM <= 100;


        CURSOR c_sup_site_1206 IS
            SELECT *
              FROM xxd_ap_supplier_sites_conv_v a
             WHERE     1 = 1
                   AND EXISTS
                           (SELECT 1
                              FROM XXD_AP_SUPPLIERS_CNV_STG_T b
                             WHERE b.old_vendor_id = a.vendor_id);


        CURSOR c_sup_site_cont_1206 IS
            SELECT *
              FROM xxd_ap_supplier_cont_conv_v a
             WHERE     1 = 1
                   AND EXISTS
                           (SELECT 1
                              FROM XXD_AP_SUPPLIERS_CNV_STG_T b
                             WHERE b.old_vendor_id = a.vendor_id);

        CURSOR c_sup_bank_1206 IS
            SELECT * FROM xxd_conv.xxd_ap_supplier_bank_1206_v;

        lc_r12seg1              VARCHAR2 (30);
        lc_r12seg2              VARCHAR2 (10);
        lc_r12seg3              VARCHAR2 (10);
        lc_r12seg4              VARCHAR2 (10);
        lc_r12seg5              VARCHAR2 (10);
        lc_r12seg6              VARCHAR2 (10);
        lc_r12seg7              VARCHAR2 (10);
        lc_r12seg8              VARCHAR2 (10);
        lc_return_status        VARCHAR2 (3);
        lc_err_msg              VARCHAR2 (2000);
        lc_err_msg1             VARCHAR2 (2000);
        ln_acctpay_ccid_r12     NUMBER;
        ln_prepay_ccid_r12      NUMBER;
        ln_futurepay_ccid_r12   NUMBER;
        lc_set_of_book_name     VARCHAR2 (30);
        ln_coa_id               NUMBER;
        ln_sob_id               NUMBER;
        --Supplier Variables
        ---------------------------
        lc_attribute3           VARCHAR2 (150);
        lc_attribute4           VARCHAR2 (150);
        lc_attribute5           VARCHAR2 (150);
        lc_attribute6           VARCHAR2 (150);
        lc_attribute7           VARCHAR2 (150);
        lc_attribute8           VARCHAR2 (150);
        lc_attribute9           VARCHAR2 (150);
        lc_attribute10          VARCHAR2 (150);
        lc_attribute14          VARCHAR2 (150);
        --Supplier Site Variables
        -------------------------
        ln_org_id               NUMBER;
        lc_new_ou               VARCHAR2 (30);
        --Supplier Site Contact Variables
        ---------------------------------
        ln_cont_org_id          NUMBER;
        lc_cont_new_ou          VARCHAR2 (30);
    BEGIN
        --Truncate/Backup Supplier Stagging Records
        -------------------------------------------
        BEGIN
            --Truncate Stagging Table
            -------------------------
            EXECUTE IMMEDIATE 'TRUNCATE TABLE xxd_conv.XXD_AP_SUPPLIERS_CNV_STG_T';

            --Rakesh - Check Schema Name

            EXECUTE IMMEDIATE 'TRUNCATE TABLE xxd_conv.XXD_AP_SUP_SITES_CNV_STG_T';

            --Rakesh - Check Schema Name

            EXECUTE IMMEDIATE 'TRUNCATE TABLE xxd_conv.XXD_AP_SUP_SITE_CON_CNV_STG_T';
        --Rakesh - Check Schema Name
        EXCEPTION
            WHEN OTHERS
            THEN
                log_records (
                    p_debug,
                       'OTHERS Exception While Truncating Supplier Data- '
                    || SQLCODE
                    || ' - '
                    || SQLERRM);
                xxd_common_utils.record_error ('AP', xxd_common_utils.get_org_id, 'XXD AP Conv Supplier Extract Program', 'OTHERS Exception While Truncating Supplier Data-  ' || SUBSTR ('Error: ' || TO_CHAR (SQLCODE) || ':-' || SQLERRM, 1, 499), DBMS_UTILITY.format_error_backtrace, fnd_profile.VALUE ('USER_ID')
                                               , gn_conc_request_id);
        END;

        -- Insert Records into Supplier Stagging Table
        ----------------------------------------------
        FOR rec IN c_supp_r1206
        LOOP
            log_records (p_debug, ' ');
            log_records (p_debug,
                         'Extract Data For Supplier- ' || rec.vendor_name);
            log_records (p_debug, ' ');

            BEGIN
                INSERT INTO XXD_AP_SUPPLIERS_CNV_STG_T ( -- Rakesh - Check Schema Name
                                old_vendor_id,
                                vendor_name,
                                vendor_name_alt,
                                segment1,
                                summary_flag,
                                enabled_flag,
                                employee_number,
                                vendor_type_lookup_code,
                                customer_num,
                                one_time_flag,
                                min_order_amount,
                                ship_to_location_code,
                                bill_to_location_code,
                                ship_via_lookup_code,
                                freight_terms_lookup_code,
                                fob_lookup_code,
                                terms_name,
                                set_of_books_id,
                                always_take_disc_flag,
                                pay_date_basis_lookup_code,
                                pay_group_lookup_code,
                                payment_priority,
                                invoice_currency_code,
                                payment_currency_code,
                                invoice_amount_limit,
                                hold_all_payments_flag,
                                hold_future_payments_flag,
                                hold_reason,
                                distribution_set_name,   --distribution_set_id
                                acctpay_ccid_segment1,
                                acctpay_ccid_segment2,
                                acctpay_ccid_segment3,
                                acctpay_ccid_segment4,
                                acctpay_ccid_segment5,
                                acctpay_ccid_r12,
                                prepay_ccid_segment1,
                                prepay_ccid_segment2,
                                prepay_ccid_segment3,
                                prepay_ccid_segment4,
                                prepay_ccid_segment5,
                                prepay_ccid_r12,
                                num_1099,
                                type_1099,
                                organization_type_lookup_code,
                                vat_code,
                                start_date_active,
                                end_date_active,
                                minority_group_lookup_code,
                                payment_method_lookup_code,
                                women_owned_flag,
                                small_business_flag,
                                standard_industry_class,
                                hold_flag,
                                purchasing_hold_reason,
                                hold_by_employee_number,         -- hold_by id
                                hold_date,
                                terms_date_basis,
                                inspection_required_flag,
                                receipt_required_flag,
                                qty_rcv_tolerance,
                                qty_rcv_exception_code,
                                enforce_ship_to_location_code,
                                days_early_receipt_allowed,
                                days_late_receipt_allowed,
                                receipt_days_exception_code,
                                receiving_routing_id,
                                allow_substitute_receipts_flag,
                                allow_unordered_receipts_flag,
                                hold_unmatched_invoices_flag,
                                exclusive_payment_flag,
                                auto_tax_calc_flag,
                                auto_tax_calc_override,
                                amount_includes_tax_flag,
                                tax_verification_date,
                                name_control,
                                state_reportable_flag,
                                federal_reportable_flag,
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
                                vat_registration_num,
                                auto_calculate_interest_flag,
                                exclude_freight_from_discount,
                                tax_reporting_name,
                                allow_awt_flag,
                                awt_group_name,
                                edi_transaction_handling,
                                edi_payment_method,
                                edi_payment_format,
                                edi_remittance_method,
                                edi_remittance_instruction,
                                bank_charge_bearer,
                                match_option,
                                future_pay_ccid_segment1,
                                future_pay_ccid_segment2,
                                future_pay_ccid_segment3,
                                future_pay_ccid_segment4,
                                future_pay_ccid_segment5,
                                futurepay_ccid_r12,
                                create_debit_memo_flag,
                                offset_tax_flag,
                                error_message,
                                record_id,
                                last_update_login,
                                creation_date,
                                created_by,
                                last_update_date,
                                last_updated_by,
                                record_status,
                                bank_account_name,
                                bank_account_num,
                                bank_account_type,
                                bank_branch_type,
                                bank_num,
                                bank_number,
                                check_digits,
                                bank_record_status,
                                bank_error_message,
                                bus_class_record_status,
                                bus_class_error_message,
                                bank_currency_code,
                                iban_number,
                                bk_bank_account_type,
                                multi_currency_flag,
                                bank_account_name_alt,
                                description,
                                agency_location_code,
                                inactive_date,
                                remittance_email,
                                remit_advice_delivery_method)
                         VALUES (
                                    rec.vendor_id,
                                    rec.vendor_name,
                                    rec.vendor_name_alt,
                                    rec.segment1,
                                    rec.summary_flag,
                                    rec.enabled_flag,
                                    rec.employee_number,
                                    rec.vendor_type_lookup_code,
                                    rec.customer_num,
                                    rec.one_time_flag,
                                    rec.min_order_amount,
                                    rec.ship_to_location_code,
                                    rec.bill_to_location_code,
                                    rec.ship_via_lookup_code,
                                    rec.freight_terms_lookup_code,
                                    rec.fob_lookup_code,
                                    rec.term_name,
                                    rec.set_of_books_id,
                                    rec.always_take_disc_flag,
                                    rec.pay_date_basis_lookup_code,
                                    -- Changes added the check of  null Change for BT conversion 01-04-2015
                                    DECODE (rec.bank_account_num,
                                            NULL, gc_pay_group,
                                            rec.pay_group_lookup_code),
                                    -- rec.pay_group_lookup_code,
                                    rec.payment_priority,
                                    rec.invoice_currency_code,
                                    rec.payment_currency_code,
                                    rec.invoice_amount_limit,
                                    rec.hold_all_payments_flag,
                                    rec.hold_future_payments_flag,
                                    rec.hold_reason,
                                    rec.distribution_set_name,
                                    rec.acctpay_ccid_segment1,
                                    rec.acctpay_ccid_segment2,
                                    rec.acctpay_ccid_segment3,
                                    rec.acctpay_ccid_segment4,
                                    rec.acctpay_ccid_segment5,
                                    ln_acctpay_ccid_r12,
                                    rec.prepay_ccid_segment1,
                                    rec.prepay_ccid_segment2,
                                    rec.prepay_ccid_segment3,
                                    rec.prepay_ccid_segment4,
                                    rec.prepay_ccid_segment5,
                                    ln_prepay_ccid_r12,
                                    rec.num_1099,
                                    rec.type_1099,
                                    rec.organization_type_lookup_code,
                                    rec.vat_code,
                                    rec.start_date_active,
                                    rec.end_date_active,
                                    rec.minority_group_lookup_code,
                                    -- Chang added the check of  null Change for BT conversion 01-04-2015
                                    /* DECODE (rec.bank_account_num,
                                             NULL, gc_pay_method,
                                             rec.payment_method_lookup_code),*/
                                    rec.payment_method_lookup_code, --Modified on 16-Apr-205
                                    -- rec.payment_method_lookup_code,
                                    rec.women_owned_flag,
                                    rec.small_business_flag,
                                    rec.standard_industry_class,
                                    rec.hold_flag,
                                    rec.purchasing_hold_reason,
                                    rec.hold_by_employee_num,
                                    rec.hold_date,
                                    rec.terms_date_basis,
                                    -- Meenakshi Changes done as a part of BT Transformaton 02-04-2015
                                    /*    DECODE (rec.vendor_type_lookup_code,
                                                'MANUFACTURER', 'N','Y')rec.inspection_required_flag,
                                                'N'),*/
                                    'N',
                                    /* DECODE (rec.vendor_type_lookup_code,
                                             'MANUFACTURER', rec.receipt_required_flag,
                                             'Y'),*/
                                    DECODE (rec.vendor_type_lookup_code,
                                            'MANUFACTURER', 'N',
                                            'Y'),
                                    --  rec.inspection_required_flag,
                                    -- rec.receipt_required_flag,
                                    rec.qty_rcv_tolerance,
                                    rec.qty_rcv_exception_code,
                                    rec.enforce_ship_to_location_code,
                                    rec.days_early_receipt_allowed,
                                    rec.days_late_receipt_allowed,
                                    rec.receipt_days_exception_code,
                                    rec.receiving_routing_id,
                                    rec.allow_substitute_receipts_flag,
                                    rec.allow_unordered_receipts_flag,
                                    rec.hold_unmatched_invoices_flag,
                                    rec.exclusive_payment_flag,
                                    rec.auto_tax_calc_flag,
                                    rec.auto_tax_calc_override,
                                    rec.amount_includes_tax_flag,
                                    rec.tax_verification_date,
                                    rec.name_control,
                                    rec.state_reportable_flag,
                                    rec.federal_reportable_flag,
                                    rec.attribute_category,
                                    --rec.attribute1,
                                    NULL,
                                    --Start Changes for BT Conversion Dated 05-DEC-2014
                                    --                         rec.attribute2,
                                    DECODE (rec.attribute2, 'G', 'Y', 'N'),
                                    --End Changes for BT Conversion Dated 05-DEC-2014
                                    rec.attribute3,
                                    rec.attribute4,
                                    rec.attribute5,
                                    rec.attribute6,
                                    rec.attribute7,
                                    rec.attribute8,
                                    rec.attribute9,
                                    rec.attribute10,
                                    rec.attribute11,
                                    rec.attribute12,
                                    rec.attribute13,
                                    rec.attribute14,
                                    rec.attribute15,
                                    gn_conc_request_id,      --rec.REQUEST_ID,
                                    rec.vat_registration_num,
                                    rec.auto_calculate_interest_flag,
                                    rec.exclude_freight_from_discount,
                                    rec.tax_reporting_name,
                                    rec.allow_awt_flag,
                                    rec.awg_group_name,
                                    rec.edi_transaction_handling,
                                    rec.edi_payment_method,
                                    rec.edi_payment_format,
                                    rec.edi_remittance_method,
                                    rec.edi_remittance_instruction,
                                    rec.bank_charge_bearer,
                                    -- Meenakshi Changes done for BT Conversion 01-04-2015
                                    gc_match_option,
                                    -- rec.match_option,
                                    rec.future_pay_ccid_segment1,
                                    rec.future_pay_ccid_segment2,
                                    rec.future_pay_ccid_segment3,
                                    rec.future_pay_ccid_segment4,
                                    rec.future_pay_ccid_segment5,
                                    ln_futurepay_ccid_r12,
                                    rec.create_debit_memo_flag,
                                    rec.offset_tax_flag,
                                    NULL,
                                    --            rec.ERROR_MESSAGE,
                                    xxd_ap_suppliers_cnv_stg_s.NEXTVAL,
                                    fnd_global.login_id, -- rec.LAST_UPDATE_LOGIN,
                                    SYSDATE,              --rec.CREATION_DATE,
                                    fnd_global.user_id,
                                    --rec.CREATED_BY,
                                    SYSDATE,           --rec.LAST_UPDATE_DATE,
                                    fnd_global.user_id, --rec.LAST_UPDATED_BY,
                                    'N',                      --RECORD_STATUS,
                                    rec.bank_account_name,
                                    rec.bank_account_num,
                                    rec.bank_account_type,
                                    rec.bank_branch_type,
                                    rec.bank_num,
                                    rec.bank_number,
                                    rec.check_digits,
                                    'N',             --rec.BANK_RECORD_STATUS,
                                    NULL, --             rec.BANK_ERROR_MESSAGE,
                                    'N',        --rec.BUS_CLASS_RECORD_STATUS,
                                    NULL, --             rec.BUS_CLASS_ERROR_MESSAGE,
                                    rec.bank_currency_code,
                                    rec.iban_number,
                                    rec.bk_bank_account_type,
                                    rec.multi_currency_flag,
                                    rec.bank_account_name_alt,
                                    rec.description,
                                    rec.agency_location_code,
                                    rec.inactive_date,
                                    rec.remit_advice_email, --Added by BT Team on 24/07/2015 1.4
                                    rec.remit_advice_delivery_method); --Added by BT Team on 24/07/2015 1.4
            EXCEPTION
                WHEN OTHERS
                THEN
                    log_records (
                        p_debug,
                           'OTHERS Exception- While inserting Record into Stagging Table- XXD_SUPPLIER_CONV_STG-  '
                        || SQLCODE
                        || '- '
                        || SQLERRM);
                    xxd_common_utils.record_error (
                        'AP',
                        xxd_common_utils.get_org_id,
                        'XXD AP Conv Supplier Extract Program',
                           'OTHERS Exception- While inserting Record into Stagging Table- XXD_SUPPLIER_CONV_STG-  '
                        || SUBSTR (
                                  'Error: '
                               || TO_CHAR (SQLCODE)
                               || ':-'
                               || SQLERRM,
                               1,
                               499),
                        DBMS_UTILITY.format_error_backtrace,
                        fnd_profile.VALUE ('USER_ID'),
                        gn_conc_request_id,
                        rec.segment1,
                        rec.vendor_id);
            END;

            COMMIT;
        END LOOP;

        -- Insert Records into Supplier Site Stagging Table
        ---------------------------------------------------
        FOR rec_ss IN c_sup_site_1206
        LOOP
            log_records (
                p_debug,
                   'Extract Data For SupplierID/Site- '
                || rec_ss.vendor_id
                || '/'
                || rec_ss.vendor_site_code);
            log_records (
                p_debug,
                '------------------------------------------------------------------------------------ ');
            ln_acctpay_ccid_r12     := NULL;
            ln_prepay_ccid_r12      := NULL;
            ln_futurepay_ccid_r12   := NULL;
            /*
             IF rec_ss.operating_unit_name IS NOT NULL
             THEN
                BEGIN
                   fnd_file.put_line (fnd_file.LOG,
                                      'pvadrevu ' || rec_ss.operating_unit_name
                                     );


                 GET_ORG_ID(rec_ss.operating_unit_name,ln_org_id,lc_new_ou);
                 fnd_file.put_line (fnd_file.LOG, 'pvadrevu new OU Name' || lc_new_ou);
                 IF ln_org_id IS NULL THEN
                    lc_new_ou := NULL;
                    ln_org_id := NULL;
                    log_records (p_debug,
                                'NO_DATA_FOUND- New OU/OU_ID Validation '
                                 || rec_ss.operating_unit_name
                                );
                    xxd_common_utils.record_error
                                  ('AP',
                                   xxd_common_utils.get_org_id,
                                  'XXD AP Conv Supplier Extract Program',
                                   'NO_DATA_FOUND- New OU/OU_ID Validation  '
                                  || SUBSTR (   'Error: '
                                             || TO_CHAR (SQLCODE)
                                             || ':-'
                                             || SQLERRM,
                                                1,
                                                499
                                               ),
                                   DBMS_UTILITY.format_error_backtrace,
                                   fnd_profile.VALUE ('USER_ID'),
                                   gn_conc_request_id,
                                   NULL,
                                   rec_ss.vendor_id,
                                   rec_ss.vendor_site_code
                                    );
                 END IF;
                EXCEPTION
                   WHEN OTHERS
                   THEN
                      log_records (p_debug,
                                      'OTHERS Exception- New OU Validation '
                                   || rec_ss.operating_unit_name
                                  );
                      xxd_common_utils.record_error
                                       ('AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Conv Supplier Extract Program',
                                         'OTHERS Exception- New OU Validation  '
                                        || SUBSTR (   'Error: '
                                                   || TO_CHAR (SQLCODE)
                                                   || ':-'
                                                   || SQLERRM,
                                                   1,
                                                   499
                                                  ),
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        NULL,
                                        rec_ss.vendor_id,
                                        rec_ss.vendor_site_code
                                       );
                END;
             ELSE
                lc_new_ou := NULL;
             END IF;
            */
            ln_org_id               := NULL;
            lc_new_ou               := NULL;

            BEGIN
                INSERT INTO xxd_ap_sup_sites_cnv_stg_t (
                                vendor_site_code,
                                vendor_site_code_alt,
                                last_update_date,
                                last_updated_by,
                                last_update_login,
                                creation_date,
                                created_by,
                                purchasing_site_flag,
                                rfq_only_site_flag,
                                pay_site_flag,
                                attention_ar_flag,
                                address_line1,
                                address_lines_alt,
                                address_line2,
                                address_line3,
                                city,
                                state,
                                zip,
                                province,
                                country,
                                area_code,
                                phone,
                                customer_num,
                                ship_to_location_code,
                                bill_to_location_code,
                                ship_via_lookup_code,
                                freight_terms_lookup_code,
                                fob_lookup_code,
                                inactive_date,
                                fax,
                                fax_area_code,
                                telex,
                                payment_method_lookup_code,
                                terms_date_basis,
                                vat_code,
                                distribution_set_name,
                                acctpay_ccid_segment1,
                                acctpay_ccid_segment2,
                                acctpay_ccid_segment3,
                                acctpay_ccid_segment4,
                                acctpay_ccid_segment5,
                                acctpay_ccid_r12,
                                prepay_ccid_segment1,
                                prepay_ccid_segment2,
                                prepay_ccid_segment3,
                                prepay_ccid_segment4,
                                prepay_ccid_segment5,
                                prepay_ccid_r12,
                                pay_group_lookup_code,
                                payment_priority,
                                terms_name,
                                invoice_amount_limit,
                                pay_date_basis_lookup_code,
                                always_take_disc_flag,
                                invoice_currency_code,
                                payment_currency_code,
                                hold_all_payments_flag,
                                hold_future_payments_flag,
                                hold_reason,
                                hold_unmatched_invoices_flag,
                                ap_tax_rounding_rule,
                                auto_tax_calc_flag,
                                auto_tax_calc_override,
                                amount_includes_tax_flag,
                                exclusive_payment_flag,
                                tax_reporting_site_flag,
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
                                exclude_freight_from_discount,
                                vat_registration_num,
                                org_id,
                                old_operating_unit_name,
                                new_operating_unit_name,
                                address_line4,
                                county,
                                address_style,
                                LANGUAGE,
                                allow_awt_flag,
                                awt_group_name,
                                edi_transaction_handling,
                                edi_id_number,
                                edi_payment_method,
                                edi_payment_format,
                                edi_remittance_method,
                                bank_charge_bearer,
                                edi_remittance_instruction,
                                pay_on_code,
                                default_pay_site_name,
                                pay_on_receipt_summary_code,
                                tp_header_id,
                                ece_tp_location_code,
                                pcard_site_flag,
                                match_option,
                                country_of_origin_code,
                                future_pay_ccid_segment1,
                                future_pay_ccid_segment2,
                                future_pay_ccid_segment3,
                                future_pay_ccid_segment4,
                                future_pay_ccid_segment5,
                                futurepay_ccid_r12,
                                create_debit_memo_flag,
                                offset_tax_flag,
                                supplier_notif_method,
                                email_address,
                                remittance_email,
                                primary_pay_site_flag,
                                shipping_control,
                                duns_number,
                                tolerance_name,
                                old_vendor_id,
                                gapless_inv_num_flag,
                                selling_company_identifier,
                                old_vendor_site_id,
                                error_message,
                                record_id,
                                record_status,
                                bank_account_name,
                                bank_account_num,
                                bank_account_type,
                                bank_branch_type,
                                bank_num,
                                bank_number,
                                check_digits,
                                request_id,
                                bank_record_status,
                                bank_error_message,
                                bank_currency_code,
                                iban_number,
                                bk_bank_account_type,
                                multi_currency_flag,
                                bank_account_name_alt,
                                description,
                                agency_location_code,
                                remit_advice_delivery_method) --Added by BT Team on 24/07/2015 1.4
                     VALUES (rec_ss.vendor_site_code, rec_ss.vendor_site_code_alt, SYSDATE, fnd_global.user_id, fnd_global.login_id, SYSDATE, fnd_global.user_id, rec_ss.purchasing_site_flag, rec_ss.rfq_only_site_flag, rec_ss.pay_site_flag, rec_ss.attention_ar_flag, /* COMMENTED BY SREYRUV ON 26-AUG-2014
                                                                                                                                                                                                                                                                          DECODE (ln_org_id,
                                                                                                                                                                                                                                                                                   81, rec_ss.address_line1,
                                                                                                                                                                                                                                                                                   DECODE (rec_ss.vendor_site_code,
                                                                                                                                                                                                                                                                                           'HOME', rec_ss.address_line1,
                                                                                                                                                                                                                                                                                           NVL (rec_ss.address_line1,
                                                                                                                                                                                                                                                                                                rec_ss.vendor_site_code
                                                                                                                                                                                                                                                                                               )
                                                                                                                                                                                                                                                                                          )
                                                                                                                                                                                                                                                                                  ),
                                                                                                                                                                                                                                                                            */
                                                                                                                                                                                                                                                                          rec_ss.address_line1, rec_ss.address_lines_alt, rec_ss.address_line2, rec_ss.address_line3, rec_ss.city, rec_ss.state, rec_ss.zip, rec_ss.province, NVL (rec_ss.country, 'US'), rec_ss.area_code, rec_ss.phone, rec_ss.customer_num, rec_ss.ship_to_location_code, rec_ss.bill_to_location_code, rec_ss.ship_via_lookup_code, rec_ss.freight_terms_lookup_code, rec_ss.fob_lookup_code, rec_ss.inactive_date, rec_ss.fax, rec_ss.fax_area_code, rec_ss.telex, rec_ss.payment_method_lookup_code, rec_ss.terms_date_basis, rec_ss.vat_code, rec_ss.distribution_set_name, rec_ss.acctpay_ccid_segment1, rec_ss.acctpay_ccid_segment2, rec_ss.acctpay_ccid_segment3, rec_ss.acctpay_ccid_segment4, rec_ss.acctpay_ccid_segment5, ln_acctpay_ccid_r12, -- meenakshi replaced pre payment ccid with null Changes done for BT conversion 01-04-2015
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              NULL, --rec_ss.prepay_ccid_segment1,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    NULL, --rec_ss.prepay_ccid_segment2,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          NULL, --rec_ss.prepay_ccid_segment3,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                NULL, --rec_ss.prepay_ccid_segment4,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      NULL, --rec_ss.prepay_ccid_segment5,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            NULL, --ln_prepay_ccid_r12,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  rec_ss.pay_group_lookup_code, rec_ss.payment_priority, rec_ss.term_name, rec_ss.invoice_amount_limit, rec_ss.pay_date_basis_lookup_code, rec_ss.always_take_disc_flag, rec_ss.invoice_currency_code, rec_ss.payment_currency_code, rec_ss.hold_all_payments_flag, rec_ss.hold_future_payments_flag, rec_ss.hold_reason, rec_ss.hold_unmatched_invoices_flag, rec_ss.ap_tax_rounding_rule, rec_ss.auto_tax_calc_flag, rec_ss.auto_tax_calc_override, rec_ss.amount_includes_tax_flag, rec_ss.exclusive_payment_flag, rec_ss.tax_reporting_site_flag, rec_ss.attribute_category, rec_ss.attribute1, rec_ss.attribute2, rec_ss.attribute3, rec_ss.attribute4, rec_ss.attribute5, rec_ss.attribute6, rec_ss.attribute7, rec_ss.attribute8, rec_ss.attribute9, rec_ss.attribute10, rec_ss.attribute11, rec_ss.attribute12, rec_ss.attribute13, rec_ss.attribute14, rec_ss.attribute15, rec_ss.exclude_freight_from_discount, rec_ss.vat_registration_num, ln_org_id, rec_ss.operating_unit_name, lc_new_ou, rec_ss.address_line4, rec_ss.county, rec_ss.address_style, rec_ss.LANGUAGE, rec_ss.allow_awt_flag, rec_ss.awg_group_name, rec_ss.edi_transaction_handling, rec_ss.edi_id_number, rec_ss.edi_payment_method, rec_ss.edi_payment_format, rec_ss.edi_remittance_method, rec_ss.bank_charge_bearer, rec_ss.edi_remittance_instruction, rec_ss.pay_on_code, rec_ss.default_pay_site_name, rec_ss.pay_on_receipt_summary_code, rec_ss.tp_header_id, rec_ss.ece_tp_location_code, rec_ss.pcard_site_flag, -- Meenakshi Changes done for BT Conversion 01-04-2015
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            gc_match_option, --   rec_ss.match_option,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             rec_ss.country_of_origin_code, rec_ss.future_pay_ccid_segment1, rec_ss.future_pay_ccid_segment2, rec_ss.future_pay_ccid_segment3, rec_ss.future_pay_ccid_segment4, rec_ss.future_pay_ccid_segment5, ln_futurepay_ccid_r12, rec_ss.create_debit_memo_flag, rec_ss.offset_tax_flag, -- meenakshi Changes done for BT conversion 01-04-2015
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               DECODE (rec_ss.email_address, NULL, gc_notif_method, gc_email), -- rec_ss.supplier_notif_method,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               rec_ss.remit_advice_email, rec_ss.attribute9, rec_ss.primary_pay_site_flag, rec_ss.shipping_control, rec_ss.duns_number, rec_ss.tolerance_name, rec_ss.vendor_id, rec_ss.gapless_inv_num_flag, rec_ss.selling_company_identifier, rec_ss.vendor_site_id, NULL, xxd_ap_sup_sites_cnv_stg_s.NEXTVAL, 'N', NVL (rec_ss.bank_account_name, rec_ss.bank_account_name_abaa), NVL (rec_ss.bank_account_num, rec_ss.bank_account_num_abaa), NVL (rec_ss.bank_account_type, rec_ss.bank_account_type_abaa), rec_ss.bank_branch_type, NVL (rec_ss.bank_num, rec_ss.bank_num_abb), rec_ss.bank_number, rec_ss.check_digits, gn_conc_request_id, 'N', NULL, rec_ss.bank_currency_code, rec_ss.iban_number, rec_ss.bk_bank_account_type, rec_ss.multi_currency_flag, rec_ss.bank_account_name_alt, rec_ss.description, rec_ss.agency_location_code
                             , rec_ss.remit_advice_delivery_method); --Added by BT Team on 24/07/2015 1.4
            EXCEPTION
                WHEN OTHERS
                THEN
                    log_records (
                        p_debug,
                           'OTHERS Exception- While inserting rec_ssord into Stagging Table- XXD_SUPPLIER_SITE_CONV_STG-  '
                        || SQLCODE
                        || '- '
                        || SQLERRM);
                    xxd_common_utils.record_error (
                        'AP',
                        xxd_common_utils.get_org_id,
                        'XXD AP Conv Supplier Extract Program',
                           'OTHERS Exception- While inserting rec_ssord into Stagging Table- XXD_SUPPLIER_SITE_CONV_STG- '
                        || SUBSTR (
                                  'Error: '
                               || TO_CHAR (SQLCODE)
                               || ':-'
                               || SQLERRM,
                               1,
                               499),
                        fnd_profile.VALUE ('USER_ID'),
                        gn_conc_request_id,
                        NULL,
                        rec_ss.vendor_id,
                        rec_ss.vendor_site_code);
            END;

            COMMIT;
        END LOOP;

        --Insert Records to Supplier Site Contact Stagging Table
        --------------------------------------------------------
        FOR rec_ssc IN c_sup_site_cont_1206
        LOOP
            log_records (p_debug, ' ');
            log_records (
                p_debug,
                   'Extract Data For SiteID/Code/Contact- '
                || rec_ssc.vendor_site_id
                || '/'
                || rec_ssc.vendor_site_code
                || '/'
                || rec_ssc.first_name
                || ','
                || rec_ssc.last_name);
            log_records (
                p_debug,
                '----------------------------------------------------------------------------------------------------------------------------------------- ');

            /*  IF rec_ssc.operating_unit_name IS NOT NULL
             THEN
                BEGIN
                  SELECT organization_id, NAME
                     INTO ln_cont_org_id, lc_cont_new_ou
                     FROM hr_operating_units
                    WHERE UPPER (NAME) =
                             (SELECT UPPER (attribute1)
                                FROM fnd_lookup_values
                               WHERE lookup_type = 'XXD_1206_OU_MAPPING'
                                 AND LANGUAGE = 'US'
                                 AND UPPER (meaning) =
                                               UPPER (rec_ssc.operating_unit_name));
    */

            /* GET_ORG_ID(rec_ssc.operating_unit_name,ln_cont_org_id,lc_cont_new_ou);
                  fnd_file.put_line (fnd_file.LOG, 'newOrg id at contact level' || ln_cont_org_id);
                  IF ln_cont_org_id IS NULL THEN
                      log_records
                                (p_debug,
                                    'NO_DATA_FOUND Exception- New OU Validation- '
                                 || rec_ssc.operating_unit_name
                                );
                       lc_cont_new_ou := NULL;
                       ln_cont_org_id := NULL;
                       xxd_common_utils.record_error
                                 ('AP',
                                  xxd_common_utils.get_org_id,
                                  'XXD AP Conv Supplier Extract Program',
                                      'NO_DATA_FOUND Exception- New OU Validation- '
                                  || SUBSTR (   'Error: '
                                             || TO_CHAR (SQLCODE)
                                             || ':-'
                                             || SQLERRM,
                                             1,
                                             499
                                            ),
                                  DBMS_UTILITY.format_error_backtrace,
                                  fnd_profile.VALUE ('USER_ID'),
                                  gn_conc_request_id,
                                  NULL,
                                  NULL,
                                  rec_ssc.vendor_site_code,
                                  rec_ssc.vendor_contact_id
                                 );
                  END IF;
                 EXCEPTION
                    WHEN OTHERS
                    THEN
                       log_records
                             (p_debug,
                                 'OTHERS Exception- New OU_NAME/OU_ID Validation '
                              || rec_ssc.operating_unit_name
                             );
                       xxd_common_utils.record_error
                              ('AP',
                               xxd_common_utils.get_org_id,
                               'XXD AP Conv Supplier Extract Program',
                                  'OTHERS Exception- New OU_NAME/OU_ID Validation '
                               || SUBSTR (   'Error: '
                                          || TO_CHAR (SQLCODE)
                                          || ':-'
                                          || SQLERRM,
                                          1,
                                          499
                                         ),
                               DBMS_UTILITY.format_error_backtrace,
                               fnd_profile.VALUE ('USER_ID'),
                               gn_conc_request_id,
                               NULL,
                               NULL,
                               rec_ssc.vendor_site_code,
                               rec_ssc.vendor_contact_id
                              );
                 END;
              ELSE
                 log_records (p_debug,
                                 'OLD operating Unit is null '
                              || rec_ssc.operating_unit_name
                             );
                 lc_cont_new_ou := NULL;
              END IF;
              */
            ln_cont_org_id   := NULL;
            lc_cont_new_ou   := NULL;

            BEGIN
                INSERT INTO xxd_conv.xxd_ap_sup_site_con_cnv_stg_t (
                                OLD_VENDOR_ID,
                                old_vendor_site_id,
                                vendor_site_code,
                                org_id,
                                old_operating_unit_name,
                                new_operating_unit_name,
                                inactive_date,
                                first_name,
                                middle_name,
                                last_name,
                                prefix,
                                title,
                                mail_stop,
                                area_code,
                                phone,
                                contact_name_alt,
                                first_name_alt,
                                last_name_alt,
                                department,
                                email_address,
                                url,
                                alt_area_code,
                                alt_phone,
                                fax_area_code,
                                fax,
                                old_vendor_contact_id,
                                error_message,
                                record_id,
                                last_update_login,
                                creation_date,
                                created_by,
                                last_update_date,
                                last_updated_by,
                                record_status,
                                request_id,
                                vendor_number, --Start Added BY BT Technology Team ON 16-Jun-2015 1.3
                                phone_area_code,
                                phone_extension,
                                phone_line_type,
                                raw_phone_number,
                                transposed_phone_number --End Added BY BT Technology Team ON 16-Jun-2015 1.3
                                                       )
                         VALUES (rec_ssc.VENDOR_ID,
                                 rec_ssc.vendor_site_id,
                                 rec_ssc.vendor_site_code,
                                 ln_cont_org_id,
                                 rec_ssc.operating_unit_name,
                                 lc_cont_new_ou,
                                 rec_ssc.inactive_date,
                                 rec_ssc.first_name,
                                 rec_ssc.middle_name,
                                 rec_ssc.last_name,
                                 rec_ssc.prefix,
                                 rec_ssc.title,
                                 rec_ssc.mail_stop,
                                 rec_ssc.area_code,
                                 rec_ssc.phone,
                                 rec_ssc.contact_name_alt,
                                 rec_ssc.first_name_alt,
                                 rec_ssc.last_name_alt,
                                 rec_ssc.department,
                                 rec_ssc.email_address,
                                 rec_ssc.url,
                                 rec_ssc.alt_area_code,
                                 rec_ssc.alt_phone,
                                 rec_ssc.fax_area_code,
                                 rec_ssc.fax,
                                 rec_ssc.vendor_contact_id,
                                 NULL,
                                 xxd_ap_sup_site_con_cnv_stg_s.NEXTVAL,
                                 fnd_global.login_id,
                                 SYSDATE,
                                 fnd_global.user_id,
                                 SYSDATE,
                                 fnd_global.user_id,
                                 'N',
                                 gn_conc_request_id,
                                 rec_ssc.vendor_number, --Added BY BT Technology Team ON 16-Jun-2015 1.3
                                 rec_ssc.phone_area_code,
                                 rec_ssc.phone_extension,
                                 rec_ssc.phone_line_type,
                                 rec_ssc.raw_phone_number,
                                 rec_ssc.transposed_phone_number --End Added BY BT Technology Team ON 16-Jun-2015 1.3
                                                                );
            EXCEPTION
                WHEN OTHERS
                THEN
                    log_records (
                        p_debug,
                           'OTHERS Exception- While inserting record into Stagging Table- XXD_SUP_SITE_CONT_CONV_STG-  '
                        || SQLCODE
                        || '- '
                        || SQLERRM);
                    xxd_common_utils.record_error (
                        'AP',
                        xxd_common_utils.get_org_id,
                        'XXD AP Conv Supplier Extract Program',
                           'OTHERS Exception- While inserting record into Stagging Table- XXD_SUP_SITE_CONT_CONV_STG- '
                        || SUBSTR (
                                  'Error: '
                               || TO_CHAR (SQLCODE)
                               || ':-'
                               || SQLERRM,
                               1,
                               499),
                        DBMS_UTILITY.format_error_backtrace,
                        fnd_profile.VALUE ('USER_ID'),
                        gn_conc_request_id,
                        NULL,
                        NULL,
                        rec_ssc.vendor_site_code,
                        rec_ssc.vendor_contact_id);
            END;

            COMMIT;
        END LOOP;

        FOR rec_sup_bank IN c_sup_bank_1206
        LOOP
            log_records (p_debug, ' ');
            log_records (
                p_debug,
                   'Extract Data For Supplier Bank '
                || rec_sup_bank.payee_name
                || '/'
                || rec_sup_bank.bank_name
                || '/'
                || rec_sup_bank.branch_name
                || ','
                || rec_sup_bank.bank_account_num);
            log_records (
                p_debug,
                '----------------------------------------------------------------------------------------------------------------------------------------- ');

            INSERT INTO xxd_ap_sup_bank_cnv_stg_t (bank_name, bank_number, branch_name, bank_account_name, bank_account_num, bank_account_type, iban_number, multi_currency_allowed_flag, branch_number, branch_type, payee_name, vendor_site_code, old_vendor_id, old_vendor_site_id, vendor_name, currency_code, country, assignment_level, error_message, record_id, last_update_login, creation_date, created_by, last_update_date, last_updated_by, record_status, request_id, -- Added by BT Team on 4/26
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    bank_branch_type, start_date, foreign_payment_use_flag, eft_swift_code, check_digits, alternate_account_name, bank_code, bank_branch_name_alt, bank_acct_desc, short_acct_name, account_suffix, bank_name_alt
                                                   , branch_description --End of addition by BT Team on 4/26
                                                                       )
                 VALUES (rec_sup_bank.bank_name, rec_sup_bank.bank_number, rec_sup_bank.branch_name, rec_sup_bank.bank_account_name, rec_sup_bank.bank_account_num, rec_sup_bank.bank_account_type, rec_sup_bank.iban_number, rec_sup_bank.multi_currency_allowed_flag, rec_sup_bank.branch_number, rec_sup_bank.branch_type, rec_sup_bank.payee_name, rec_sup_bank.vendor_site_code, rec_sup_bank.old_vendor_id, rec_sup_bank.old_vendor_site_id, rec_sup_bank.vendor_name, rec_sup_bank.currency_code, rec_sup_bank.country, rec_sup_bank.assignment_level, NULL, xxd_ap_sup_site_con_cnv_stg_s.NEXTVAL, fnd_global.login_id, SYSDATE, fnd_global.user_id, SYSDATE, fnd_global.user_id, 'N', gn_conc_request_id -- Added by BT Team on 4/26
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 , rec_sup_bank.bank_branch_type, rec_sup_bank.start_date, rec_sup_bank.foreign_payment_use_flag, rec_sup_bank.eft_swift_code, rec_sup_bank.check_digits, rec_sup_bank.alternate_account_name, rec_sup_bank.bank_code, rec_sup_bank.bank_branch_name_alt, rec_sup_bank.bank_acct_desc, rec_sup_bank.short_acct_name, rec_sup_bank.account_suffix, rec_sup_bank.bank_name_alt
                         , rec_sup_bank.branch_description --End of addition by BT Team on 4/26
                                                          );
        END LOOP;


        UPDATE XXD_AP_SUPPLIERS_CNV_STG_T
           SET vendor_type_lookup_code   = 'CONSULTANT'
         WHERE vendor_type_lookup_code = 'TEMP';

        UPDATE XXD_AP_SUPPLIERS_CNV_STG_T
           SET vendor_type_lookup_code   = ''
         WHERE vendor_type_lookup_code = 'PROMO';


        COMMIT;

        BEGIN
            SELECT COUNT (*)
              INTO gn_supp_extract_cnt
              FROM xxd_ap_suppliers_cnv_stg_t
             WHERE record_status = 'N';

            SELECT COUNT (*)
              INTO gn_site_extract_cnt
              FROM xxd_ap_sup_sites_cnv_stg_t
             WHERE record_status = 'N';

            SELECT COUNT (*)
              INTO gn_cont_extract_cnt
              FROM xxd_conv.xxd_ap_sup_site_con_cnv_stg_t
             WHERE record_status = 'N';

            SELECT COUNT (*)
              INTO gn_bank_extract_cnt
              FROM xxd_ap_sup_bank_cnv_stg_t
             WHERE record_status = 'N';
        END;


        fnd_file.put_line (
            fnd_file.output,
            'XXD AP Supplier R12.0.6 to R12.2.3 extract program');
        fnd_file.put_line (
            fnd_file.output,
            'Run Date: ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
        fnd_file.put_line (fnd_file.output, 'Executed By: ' || gc_user_name);
        fnd_file.put_line (fnd_file.output,
                           'Process Mode: ' || gc_extract_only);
        fnd_file.put_line (fnd_file.output, 'Instance Name: ' || gc_dbname);
        fnd_file.put_line (
            fnd_file.output,
            'S.No                   Entity           Total Records Extracted from 12.0.6 and loaded to 12.2.3 ');
        fnd_file.put_line (
            fnd_file.output,
            '----------------------------------------------------------------------------------------------');
        fnd_file.put_line (
            fnd_file.output,
               '1                    '
            || RPAD ('Suppliers', 20, ' ')
            || '   '
            || gn_supp_extract_cnt);
        fnd_file.put_line (
            fnd_file.output,
               '2                    '
            || RPAD ('Supplier Sites', 20, ' ')
            || '   '
            || gn_site_extract_cnt);
        fnd_file.put_line (
            fnd_file.output,
               '3                    '
            || RPAD ('Supplier Contacts', 20, ' ')
            || '   '
            || gn_cont_extract_cnt);
        fnd_file.put_line (
            fnd_file.output,
               '4                    '
            || RPAD ('Supplier Bank', 20, ' ')
            || '   '
            || gn_bank_extract_cnt);
    END;

    PROCEDURE validate_supplier_info (p_errbuf OUT VARCHAR2, p_retcode OUT NUMBER, p_process_mode IN VARCHAR2
                                      , p_debug IN VARCHAR2)
    IS
        --Rakesh Remove later if not required
        -- To handle multiple sites with same address
        CURSOR c_dup_site_addresses IS
              SELECT old_vendor_id, address_line1, address_lines_alt,
                     address_line2, address_line3, city,
                     state, zip, country,
                     COUNT (1) x
                FROM xxd_ap_sup_sites_cnv_stg_t
               WHERE     record_status IN ('N', 'E')
                     AND attribute8 IS NULL
                     AND NVL (error_message, 'x') NOT LIKE
                             '%duplicate site entry for%'
            GROUP BY old_vendor_id, address_line1, address_lines_alt,
                     address_line2, address_line3, city,
                     state, zip, country
              HAVING COUNT (1) > 1;

        CURSOR c_dup_site_add_sites (p_old_vendor_id       NUMBER,
                                     p_address_line1       VARCHAR2,
                                     p_address_lines_alt   VARCHAR2,
                                     p_address_line2       VARCHAR2,
                                     p_address_line3       VARCHAR2,
                                     p_city                VARCHAR2,
                                     p_state               VARCHAR2,
                                     p_zip                 VARCHAR2,
                                     p_country             VARCHAR2)
        IS
            SELECT old_vendor_id, old_vendor_site_id, vendor_site_code,
                   address_line1
              FROM xxd_ap_sup_sites_cnv_stg_t
             WHERE     old_vendor_id = p_old_vendor_id
                   AND address_line1 = p_address_line1
                   AND address_lines_alt = p_address_lines_alt
                   AND address_line2 = p_address_line2
                   AND address_line3 = p_address_line3
                   AND city = p_city
                   AND state = p_state
                   AND zip = p_zip
                   AND country = p_country
                   AND record_status IN ('N', 'E');

        --  Cursors to Validate record's  in Stagging Tables
        ------------------------------------------------------
        CURSOR c_supp_stg IS
            SELECT *
              FROM xxd_ap_suppliers_cnv_stg_t
             WHERE record_status IN ('N', 'E')
            -- AND vendor_id = 3126 --Srinivas
            UNION
            SELECT *
              FROM xxd_ap_suppliers_cnv_stg_t sup
             WHERE     old_vendor_id IN
                           (SELECT old_vendor_id
                              FROM xxd_ap_sup_sites_cnv_stg_t site
                             WHERE site.record_status = 'E')
                   AND record_status NOT IN ('N', 'E');

        CURSOR c_sup_sites (p_vendor_id NUMBER)
        IS
            SELECT *
              FROM xxd_ap_sup_sites_cnv_stg_t
             WHERE     old_vendor_id = p_vendor_id
                   AND record_status IN ('N', 'E');

        --AND new_operating_unit_name IS NOT NULL; -- Rakesh for initial testing
        CURSOR c_ss_contact (p_vendor_id NUMBER)
        IS
            SELECT *
              FROM xxd_conv.xxd_ap_sup_site_con_cnv_stg_t
             WHERE old_vendor_id = p_vendor_id;

        CURSOR c_bank IS
            SELECT *
              FROM xxd_ap_sup_bank_cnv_stg_t
             WHERE     record_status IN ('N', 'E')
                   AND bank_account_num IS NOT NULL;

        --  Cursor's to insert record  into Interface Tables
        -----------------------------------------------------
        CURSOR sup_ins_cur IS
            SELECT sup.*
              FROM xxd_ap_suppliers_cnv_stg_t sup
             WHERE sup.record_status = 'V'
            UNION
            SELECT *
              FROM xxd_ap_suppliers_cnv_stg_t sup
             WHERE     old_vendor_id IN
                           (SELECT old_vendor_id
                              FROM xxd_ap_sup_sites_cnv_stg_t site
                             WHERE site.record_status = 'V')
                   AND record_status NOT IN ('V');

        CURSOR sup_bank_ins_cur (p_vendor_name VARCHAR2)
        IS
            SELECT sup_bank.*
              FROM xxd_ap_suppliers_cnv_stg_t sup_bank
             WHERE     sup_bank.bank_record_status = 'V'
                   AND UPPER (sup_bank.vendor_name) = UPPER (p_vendor_name);

        CURSOR site_ins_c (p_vendor_id NUMBER)
        IS
            SELECT site.*
              FROM xxd_ap_sup_sites_cnv_stg_t site
             WHERE     site.record_status IN ('V')
                   AND site.old_vendor_id = p_vendor_id;

        CURSOR site_bank_ins_c (p_vendor_site_id     NUMBER,
                                p_vendor_site_code   VARCHAR2)
        IS
            SELECT site_bank.*
              FROM xxd_ap_sup_sites_cnv_stg_t site_bank
             WHERE     site_bank.bank_record_status IN ('V')
                   AND site_bank.vendor_site_code = p_vendor_site_code
                   AND site_bank.old_vendor_site_id = p_vendor_site_id;

        --      CURSOR cont_ins_c (
        --         p_vendor_site_id      NUMBER,
        --         p_vendor_site_code    VARCHAR2)
        CURSOR cont_ins_c (p_vendor_id NUMBER)
        IS
            SELECT con.*
              FROM xxd_conv.xxd_ap_sup_site_con_cnv_stg_t con
             WHERE     con.record_status = 'V'
                   --                AND con.vendor_site_code = p_vendor_site_code
                   AND con.old_vendor_id = p_vendor_id;



        CURSOR get_country_c (p_org_id NUMBER)
        IS
            SELECT DISTINCT hrl.country
              FROM xle_entity_profiles lep, xle_registrations reg, hr_locations_all hrl,
                   hz_parties hzp, fnd_territories_vl ter, hr_operating_units hro,
                   hr_organization_units hou, gl_legal_entities_bsvs glev
             WHERE     lep.transacting_entity_flag = 'Y'
                   AND lep.party_id = hzp.party_id
                   AND lep.legal_entity_id = reg.source_id
                   AND reg.source_table = 'XLE_ENTITY_PROFILES'
                   AND hrl.location_id = reg.location_id
                   AND reg.identifying_flag = 'Y'
                   AND ter.territory_code = hrl.country
                   AND lep.legal_entity_id = hro.default_legal_context_id
                   AND hou.organization_id = hro.organization_id
                   AND glev.legal_entity_id = lep.legal_entity_id
                   --and lep.NAME='Deckers Outdoor Corporation'
                   AND hou.organization_id = p_org_id;

        lc_country                      VARCHAR2 (100);

        CURSOR Get_attribute4 (p_vendor_num VARCHAR2, p_site_code VARCHAR2)
        IS
            SELECT ATTRIBUTE4
              FROM XXD_CONV.XXD_VENDOR_NUM_T
             WHERE     vendor_num = p_vendor_num
                   AND vendor_site_code = p_site_code;

        lc1_attribute4                  VARCHAR2 (100);

        CURSOR get_pay_grp_c (p_le VARCHAR2, p_type VARCHAR2)
        IS
            SELECT PAY_GROUP
              FROM XXD_CONV.XXD_PAYGROUP_T
             WHERE LE = p_le AND TYPE = p_type;

        lc_paygrp                       VARCHAR2 (100);

        CURSOR get_euro_country_c (p_country VARCHAR2)
        IS
            SELECT LOOKUP_CODE
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXDO_EU_COUNTIRES'
                   AND language = 'US'
                   AND LOOKUP_CODE = p_country;

        lc_LOOKUP_CODE                  VARCHAR2 (30);

        CURSOR get_payment_method_c (p_pay_meth_code VARCHAR2)
        IS
            SELECT DESCRIPTION
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXDO_PAYMENT_METHOD_MAPPING'
                   AND language = 'US'
                   AND MEANING = p_pay_meth_code;

        CURSOR Get_bank_account_c (p_old_vendor_id NUMBER)
        IS
            SELECT BANK_ACCOUNT_NUM
              FROM XXD_AP_SUP_BANK_CNV_STG_T
             WHERE OLD_VENDOR_ID = p_old_vendor_id;

        lc_bank_account_num             VARCHAR2 (1000);

        CURSOR get_site_bank_account_c (p_old_vendor_id   NUMBER,
                                        p_vendor_code     VARCHAR2)
        IS
            SELECT BANK_ACCOUNT_NUM
              FROM XXD_AP_SUP_BANK_CNV_STG_T
             WHERE     OLD_VENDOR_ID = p_old_vendor_id
                   AND vendor_site_code = p_vendor_code
                   AND ASSIGNMENT_LEVEL = 'SS';

        lc_site_bank_account_num        VARCHAR2 (1000);


        lc_desc                         VARCHAR2 (100);

        lc_pay_meth_code_c              VARCHAR2 (100);
        lc_PAYMENT_METHOD_LOOKUP_CODE   VARCHAR2 (1000);
        lc_site_pay_mthd_CODE           VARCHAR2 (1000);
        -- Supplier variables
        --------------------
        ln_employee_id                  NUMBER;
        ln_hold_emp_id                  NUMBER;
        lc_supp_err_flag                VARCHAR2 (2) := 'N';
        lc_supp_err_msg                 VARCHAR2 (2000);
        lc_ven_type_lookup_code         VARCHAR2 (30);
        lc_pay_group_code               VARCHAR2 (30);
        ln_ship_location_id             NUMBER;
        ln_bill_location_id             NUMBER;
        lc_ship_via                     VARCHAR2 (30);
        lc_freight_term                 VARCHAR2 (30);
        lc_fob                          VARCHAR2 (30);
        lc_term_name                    VARCHAR2 (30);
        lc_bank_exist                   VARCHAR2 (3);
        ln_term_id                      NUMBER;
        lc_auto_tax_calc_flag1          VARCHAR2 (2);
        ln_awt_group_id                 NUMBER;
        ln_sob_id                       NUMBER;
        ln_org_id                       NUMBER;
        lc_new_ou                       VARCHAR2 (50);
        --Supplier bank Variables
        ---------------------------
        lc_sup_bank_country_code        VARCHAR2 (3);
        lc_supp_bank_err                VARCHAR2 (2) := 'N';
        lc_supp_bank_err_details        VARCHAR2 (2000);
        lc_bank_exists                  VARCHAR2 (2);
        ln_bank_id                      NUMBER;
        ln_branch_id                    NUMBER;
        --Supplier Site Variables
        ---------------------------
        lc_pay_method_code              VARCHAR2 (30);
        lc_distribut_set_name           VARCHAR2 (50);
        ln_site_ship_location_id        NUMBER;
        ln_site_bill_location_id        NUMBER;
        lc_site_ship_via                VARCHAR2 (30);
        --Lv_term_name               VARCHAR2 (30);
        ln_sit_term_id                  NUMBER;
        lc_site_fob                     VARCHAR2 (30);
        lc_site_freight_term            VARCHAR2 (30);
        lc_site_pay_group_code          VARCHAR2 (30);
        lc_tolerance_name               VARCHAR2 (255);
        lc_sup_site_err_flag            VARCHAR2 (2);
        lc_sup_site_err_msg             VARCHAR2 (2000);
        ln_dup_count_org_id             NUMBER;
        lc_auto_tax_calc_flag           VARCHAR2 (2);
        --Supplier site contact Variables
        ----------------------------------
        lc_cont_err_flag                VARCHAR2 (2);
        lc_cont_err_msg                 VARCHAR2 (2000);
        ln_contact_id                   NUMBER;
        --Supplier Site Bank Variables
        ------------------------------------
        lc_site_bank_country_code       VARCHAR2 (30);
        lc_site_bank_exists             VARCHAR2 (2);
        lc_site_bank_err                VARCHAR2 (2);
        lc_site_bank_err_details        VARCHAR2 (2000);
        ln_bank_id1                     NUMBER;
        ln_branch_id1                   NUMBER;
        ln_acct_party_id                NUMBER;
        --Load record variables
        ---------------------------
        lc_err_flag                     VARCHAR2 (2) := 'N';
        lc_error_msg                    VARCHAR2 (2000);
        ln_vendor_id                    NUMBER;
        ln_supplier_int_id              NUMBER;
        ln_site_id                      NUMBER;
        --Business CLassification Variables
        -------------------------------------
        lc_bus_err_flag2                VARCHAR2 (2);
        lc_bus_err_flag3                VARCHAR2 (2);
        lc_bus_err_flag4                VARCHAR2 (2);
        lc_bus_err_flag5                VARCHAR2 (2);
        lc_bus_err_flag6                VARCHAR2 (2);
        lc_bus_err_flag7                VARCHAR2 (2);
        lc_bus_err_flag8                VARCHAR2 (2);
        lc_bus_err_flag9                VARCHAR2 (2);
        lc_bus_err_flag10               VARCHAR2 (2);
        lc_ship_code                    VARCHAR2 (500);
        lc_bill_code                    VARCHAR2 (500);
    BEGIN
        IF p_process_mode = 'V'
        THEN
            BEGIN
                SELECT 'Y'
                  INTO lc_bus_err_flag2
                  FROM apps.fnd_lookup_values_vl
                 WHERE     lookup_type = 'POS_BUSINESS_CLASSIFICATIONS'
                       AND enabled_flag = 'Y'
                       AND end_date_active IS NULL
                       AND lookup_code = 'BUSINESS_SIZE(L)';
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_retcode   := 1;
                    log_records (
                        p_debug,
                           'BUSINESS_SIZE(L) is not defined/invalid- '
                        || SQLERRM);
            END;

            BEGIN
                SELECT 'Y'
                  INTO lc_bus_err_flag3
                  FROM apps.fnd_lookup_values_vl
                 WHERE     lookup_type = 'POS_BUSINESS_CLASSIFICATIONS'
                       AND enabled_flag = 'Y'
                       AND end_date_active IS NULL
                       AND lookup_code = 'BUSINESS_SIZE(S)';
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_retcode   := 1;
                    log_records (
                        p_debug,
                           'BUSINESS_SIZE(S) is not defined/invalid- '
                        || SQLERRM);
            END;

            BEGIN
                SELECT 'Y'
                  INTO lc_bus_err_flag4
                  FROM apps.fnd_lookup_values_vl
                 WHERE     lookup_type = 'POS_BUSINESS_CLASSIFICATIONS'
                       AND enabled_flag = 'Y'
                       AND end_date_active IS NULL
                       AND lookup_code = 'HUBZONE_SMALL_BUSINESS';
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_retcode   := 1;
                    log_records (
                        p_debug,
                           'HUBZONE_SMALL_BUSINESS is not defined/invalid- '
                        || SQLERRM);
            END;

            BEGIN
                SELECT 'Y'
                  INTO lc_bus_err_flag5
                  FROM apps.fnd_lookup_values_vl
                 WHERE     lookup_type = 'POS_BUSINESS_CLASSIFICATIONS'
                       AND enabled_flag = 'Y'
                       AND end_date_active IS NULL
                       AND lookup_code = 'MINORITY_OWNED';
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_retcode   := 1;
                    log_records (
                        p_debug,
                        'MINORITY_OWNED is not defined/invalid- ' || SQLERRM);
            END;

            BEGIN
                SELECT 'Y'
                  INTO lc_bus_err_flag6
                  FROM apps.fnd_lookup_values_vl
                 WHERE     lookup_type = 'POS_BUSINESS_CLASSIFICATIONS'
                       AND enabled_flag = 'Y'
                       AND end_date_active IS NULL
                       AND lookup_code = 'SERVICE_DISABLED_VETERAN';
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_retcode   := 1;
                    log_records (
                        p_debug,
                           'SERVICE_DISABLED_VETERAN is not defined/invalid- '
                        || SQLERRM);
            END;

            BEGIN
                SELECT 'Y'
                  INTO lc_bus_err_flag7
                  FROM apps.fnd_lookup_values_vl
                 WHERE     lookup_type = 'POS_BUSINESS_CLASSIFICATIONS'
                       AND enabled_flag = 'Y'
                       AND end_date_active IS NULL
                       AND lookup_code = 'SMALL_DISADVANTAGED';
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_retcode   := 1;
                    log_records (
                        p_debug,
                           'SMALL_DISADVANTAGED is not defined/invalid- '
                        || SQLERRM);
            END;

            BEGIN
                SELECT 'Y'
                  INTO lc_bus_err_flag8
                  FROM apps.fnd_lookup_values_vl
                 WHERE     lookup_type = 'POS_BUSINESS_CLASSIFICATIONS'
                       AND enabled_flag = 'Y'
                       AND end_date_active IS NULL
                       AND lookup_code = 'VETERAN_OWNED';
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_retcode   := 1;
                    log_records (
                        p_debug,
                        'VETERAN_OWNED is not defined/invalid- ' || SQLERRM);
            END;

            BEGIN
                SELECT 'Y'
                  INTO lc_bus_err_flag9
                  FROM apps.fnd_lookup_values_vl
                 WHERE     lookup_type = 'POS_BUSINESS_CLASSIFICATIONS'
                       AND enabled_flag = 'Y'
                       AND end_date_active IS NULL
                       AND lookup_code = 'WOMEN_OWNED';
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_retcode   := 1;
                    log_records (
                        p_debug,
                        'WOMEN_OWNED is not defined/invalid- ' || SQLERRM);
            END;

            BEGIN
                SELECT 'Y'
                  INTO lc_bus_err_flag10
                  FROM apps.fnd_lookup_values_vl
                 WHERE     lookup_type = 'POS_BUSINESS_CLASSIFICATIONS'
                       AND enabled_flag = 'Y'
                       AND end_date_active IS NULL
                       AND lookup_code = 'DISABLED_PERSON';
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_retcode   := 1;
                    log_records (
                        p_debug,
                           'DISABLED_PERSON(PD) is not defined/invalid- '
                        || SQLERRM);
            END;

            IF    NVL (lc_bus_err_flag2, 'N') = 'Y'
               OR NVL (lc_bus_err_flag3, 'N') = 'Y'
               OR NVL (lc_bus_err_flag4, 'N') = 'Y'
               OR NVL (lc_bus_err_flag5, 'N') = 'Y'
               OR NVL (lc_bus_err_flag6, 'N') = 'Y'
               OR NVL (lc_bus_err_flag7, 'N') = 'Y'
               OR NVL (lc_bus_err_flag8, 'N') = 'Y'
               OR NVL (lc_bus_err_flag9, 'N') = 'Y'
               OR NVL (lc_bus_err_flag10, 'N') = 'Y'
            THEN
                --Count the Supplier/Sites/Contacts/Bank Records from Stagging Table to Validate
                ----------------------------------------------------------------------------------
                SELECT COUNT (*)
                  INTO gn_supplier_found
                  FROM xxd_ap_suppliers_cnv_stg_t
                 WHERE record_status IN ('N', 'E');

                SELECT COUNT (*)
                  INTO gn_sites_found
                  FROM xxd_ap_sup_sites_cnv_stg_t
                 WHERE record_status IN ('N', 'E');

                SELECT COUNT (*)
                  INTO gn_contacts_found
                  FROM xxd_conv.xxd_ap_sup_site_con_cnv_stg_t
                 WHERE record_status IN ('N', 'E');

                SELECT COUNT (*)
                  INTO gn_supp_bank_found
                  FROM xxd_ap_suppliers_cnv_stg_t
                 WHERE     bank_record_status IN ('N', 'E')
                       AND bank_account_num IS NOT NULL;

                SELECT COUNT (*)
                  INTO gn_site_bank_found
                  FROM xxd_ap_sup_sites_cnv_stg_t
                 WHERE record_status IN ('N', 'E');

                --Iniatialize the Global Variables to 0
                ---------------------------------------
                gn_supp_reject               := 0;
                gn_supp_process              := 0;
                gn_supp_bank_rejected        := 0;
                gn_supp_bank_processed       := 0;
                gn_site_rejected             := 0;
                gn_site_processed            := 0;
                gn_contact_processed         := 0;
                gn_contact_rejected          := 0;
                gn_sup_site_bank_rejected    := 0;
                gn_sup_site_bank_processed   := 0;

                --         gv_supplier_found := 0;
                --         gv_sites_found := 0;
                --         gv_contacts_found := 0;
                --         gv_supp_bank_found := 0;
                --         gv_site_bank_found := 0;

                --Supplier Loop Starts



                ------------------------
                FOR sup_rec IN c_supp_stg
                LOOP
                    --lv_Supp_err_msg := NULL;
                    ln_employee_id                  := NULL;
                    ln_hold_emp_id                  := NULL;
                    lc_supp_err_flag                := NULL;
                    lc_supp_err_msg                 := NULL;
                    lc_ven_type_lookup_code         := NULL;
                    lc_pay_group_code               := NULL;
                    ln_ship_location_id             := NULL;
                    ln_bill_location_id             := NULL;
                    lc_ship_via                     := NULL;
                    lc_freight_term                 := NULL;
                    lc_fob                          := NULL;
                    lc_term_name                    := NULL;
                    lc_bank_exist                   := NULL;
                    lc_PAYMENT_METHOD_LOOKUP_CODE   := NULL;



                    IF sup_rec.record_status IN ('N', 'E')
                    THEN
                        ln_employee_id            := NULL;

                        IF sup_rec.employee_number IS NOT NULL
                        THEN
                            BEGIN
                                SELECT papf.person_id
                                  INTO ln_employee_id
                                  FROM per_all_people_f papf
                                 WHERE     TRIM (employee_number) =
                                           TRIM (sup_rec.employee_number)
                                       AND SYSDATE BETWEEN effective_start_date
                                                       AND effective_end_date;
                            -- AND person_type_id = 6;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    log_records (
                                        p_debug,
                                           'NO_DATA_FOUND Exception- Employee Number Does not Exists- '
                                        || sup_rec.employee_number);
                                    ln_employee_id     := NULL;
                                    lc_supp_err_flag   := 'Y';
                                    lc_supp_err_msg    :=
                                           lc_supp_err_msg
                                        || ' \ '
                                        || 'Employee Number '
                                        || sup_rec.employee_number
                                        || ' does not Exists for supplier '
                                        || sup_rec.vendor_name;
                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Conv Validate and Load',
                                           'NO_DATA_FOUND Exception- Employee Number Does not Exists- '
                                        || SUBSTR (
                                                  'Error: '
                                               || TO_CHAR (SQLCODE)
                                               || ':-'
                                               || SQLERRM,
                                               1,
                                               499),
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id);
                                WHEN OTHERS
                                THEN
                                    log_records (
                                        p_debug,
                                           'OTHERS Exception- Employee Number Validation- '
                                        || sup_rec.employee_number);
                                    lc_supp_err_flag   := 'Y';
                                    lc_supp_err_msg    :=
                                           lc_supp_err_msg
                                        || '\'
                                        || 'Supplier Employee Number Validation  for supplier'
                                        || sup_rec.vendor_name
                                        || ' Error no-'
                                        || SUBSTR (
                                               (SQLCODE || '-' || SQLERRM),
                                               1,
                                               100);
                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Conv Validate and Load',
                                           'OTHERS Exception- Employee Number Validation- '
                                        || SUBSTR (
                                                  'Error: '
                                               || TO_CHAR (SQLCODE)
                                               || ':-'
                                               || SQLERRM,
                                               1,
                                               499),
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id);
                            END;
                        END IF;

                        log_records (
                            p_debug,
                               'Employee_ID- '
                            || ln_employee_id
                            || 'For VENDOR_NAME- '
                            || sup_rec.vendor_name);

                        --'

                        lc_ven_type_lookup_code   := NULL;

                        IF sup_rec.vendor_type_lookup_code IS NOT NULL
                        THEN
                            BEGIN
                                SELECT lookup_code
                                  INTO lc_ven_type_lookup_code
                                  FROM fnd_lookup_values_vl flv, fnd_application_vl fav
                                 WHERE     lookup_type = 'VENDOR TYPE'
                                       AND flv.end_date_active IS NULL
                                       AND flv.view_application_id =
                                           fav.application_id
                                       AND APPLICATION_SHORT_NAME = 'PO'
                                       AND UPPER (lookup_code) =
                                           UPPER (
                                               sup_rec.vendor_type_lookup_code);
                            --                                      (SELECT UPPER (value_r1223)
                            --                                         FROM XXD_R1206_R1223_VALUE_MAP
                            --                                        WHERE     UPPER (value_r1206) =
                            --                                                     UPPER (
                            --                                                        sup_rec.VENDOR_TYPE_LOOKUP_CODE)
                            --                                              AND lookup_code =
                            --                                                     'VENDOR_TYPE_LOOKUP_CODE');
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    lc_supp_err_flag   := 'Y';
                                    lc_supp_err_msg    :=
                                           lc_supp_err_msg
                                        || ' \ '
                                        || 'Vendor Lookup Code -'
                                        || sup_rec.vendor_type_lookup_code
                                        || ' does not Exists for supplier '
                                        || sup_rec.vendor_name;
                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Conv Validate and Load',
                                           'No data found for Vendor Lookup Code '
                                        || SUBSTR (
                                                  'Error: '
                                               || TO_CHAR (SQLCODE)
                                               || ':-'
                                               || SQLERRM,
                                               1,
                                               499),
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id);
                                WHEN OTHERS
                                THEN
                                    lc_supp_err_flag   := 'Y';
                                    lc_supp_err_msg    :=
                                           lc_supp_err_msg
                                        || '\'
                                        || 'Supplier Vendor Lookup Code Validation'
                                        || 'failed for the Lookup Code -'
                                        || sup_rec.vendor_type_lookup_code
                                        || ' for supplier '
                                        || sup_rec.vendor_name
                                        || ' Error no-'
                                        || SUBSTR (
                                               (SQLCODE || '-' || SQLERRM),
                                               1,
                                               100);
                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Conv Validate and Load',
                                           'When Others exception for Vendor Lookup Code '
                                        || SUBSTR (
                                                  'Error: '
                                               || TO_CHAR (SQLCODE)
                                               || ':-'
                                               || SQLERRM,
                                               1,
                                               499),
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id);
                            END;
                        END IF;

                        IF     lc_ven_type_lookup_code = 'EMPLOYEE'
                           AND sup_rec.employee_number IS NULL
                        THEN
                            lc_supp_err_flag   := 'Y';
                            lc_supp_err_msg    :=
                                   lc_supp_err_msg
                                || ' \ '
                                || 'Employee Number cannot be null for Vendor type EMPLOYEE -'
                                || sup_rec.vendor_name;
                        END IF;

                        lc_ship_code              := NULL; --Added by Commented for UAT

                        IF sup_rec.ship_to_location_code IS NOT NULL
                        THEN
                            BEGIN
                                --lc_ship_code := NULL; --Commented for UAT

                                SELECT location_id, flv.description
                                  INTO ln_ship_location_id, lc_ship_code
                                  FROM hr_locations_all hla --Code modification on 05-MAR-2015
                                                           , fnd_lookup_values flv
                                 WHERE     UPPER (hla.location_code) =
                                           UPPER (flv.description)
                                       AND UPPER (flv.meaning) =
                                           UPPER (
                                               sup_rec.ship_to_location_code)
                                       AND lookup_type =
                                           'XXDO_CONV_LOCATION_MAPPING'
                                       AND language = 'US' --Code modification on 05-MAR-2015
                                                          ;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    lc_supp_err_flag   := 'Y';
                                    lc_supp_err_msg    :=
                                           lc_supp_err_msg
                                        || ' \ '
                                        || 'SHIP_TO_LOCATION_CODE -'
                                        || sup_rec.ship_to_location_code
                                        || ' does not Exists for supplier '
                                        || sup_rec.vendor_name;
                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Conv Validate and Load',
                                           'Ship to Location does not exist '
                                        || sup_rec.vendor_name
                                        || SUBSTR (
                                                  'Error: '
                                               || TO_CHAR (SQLCODE)
                                               || ':-'
                                               || SQLERRM,
                                               1,
                                               499),
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id);
                                WHEN OTHERS
                                THEN
                                    lc_supp_err_flag   := 'Y';
                                    lc_supp_err_msg    :=
                                           lc_supp_err_msg
                                        || '\'
                                        || 'Supplier ShipTo Location Code Validation'
                                        || 'failed for the Lookup Code -'
                                        || sup_rec.ship_to_location_code
                                        || ' for supplier '
                                        || sup_rec.vendor_name
                                        || ' Error no-'
                                        || SUBSTR (
                                               (SQLCODE || '-' || SQLERRM),
                                               1,
                                               100);
                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Conv Validate and Load',
                                           'When others exception for Ship to Location of supplier '
                                        || sup_rec.vendor_name
                                        || SUBSTR (
                                                  'Error: '
                                               || TO_CHAR (SQLCODE)
                                               || ':-'
                                               || SQLERRM,
                                               1,
                                               499),
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id);
                            END;
                        ELSE
                            NULL;
                        END IF;

                        lc_bill_code              := NULL;

                        IF sup_rec.bill_to_location_code IS NOT NULL
                        THEN
                            BEGIN
                                --lc_bill_code := NULL;

                                SELECT location_id, flv.description
                                  INTO ln_bill_location_id, lc_bill_code
                                  FROM hr_locations_all hla --Code modification on 05-MAR-2015
                                                           , fnd_lookup_values flv
                                 WHERE     UPPER (hla.location_code) =
                                           UPPER (flv.description)
                                       AND UPPER (flv.meaning) =
                                           UPPER (
                                               sup_rec.bill_to_location_code)
                                       AND lookup_type =
                                           'XXDO_CONV_LOCATION_MAPPING'
                                       AND language = 'US' --Code modification on 05-MAR-2015
                                                          ;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    lc_supp_err_flag   := 'Y';
                                    lc_supp_err_msg    :=
                                           lc_supp_err_msg
                                        || ' \ '
                                        || 'BILL_TO_LOCATION_CODE -'
                                        || sup_rec.bill_to_location_code
                                        || ' does not Exists for supplier '
                                        || sup_rec.vendor_name;
                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Conv Validate and Load',
                                           'No Data Found for Bill to Location of supplier '
                                        || sup_rec.vendor_name
                                        || SUBSTR (
                                                  'Error: '
                                               || TO_CHAR (SQLCODE)
                                               || ':-'
                                               || SQLERRM,
                                               1,
                                               499),
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id);
                                WHEN OTHERS
                                THEN
                                    lc_supp_err_flag   := 'Y';
                                    lc_supp_err_msg    :=
                                           lc_supp_err_msg
                                        || '\'
                                        || 'Supplier BillTo Location Code Validation'
                                        || 'failed for the Lookup Code -'
                                        || sup_rec.bill_to_location_code
                                        || ' for supplier '
                                        || sup_rec.vendor_name
                                        || ' Error no-'
                                        || SUBSTR (
                                               (SQLCODE || '-' || SQLERRM),
                                               1,
                                               100);
                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Conv Validate and Load',
                                           'When others exception for Bill to Location of supplier '
                                        || sup_rec.vendor_name
                                        || SUBSTR (
                                                  'Error: '
                                               || TO_CHAR (SQLCODE)
                                               || ':-'
                                               || SQLERRM,
                                               1,
                                               499),
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id);
                            END;
                        ELSE
                            NULL;
                        END IF;



                        /*       IF sup_rec.ship_via_lookup_code IS NOT NULL
                               THEN
                                  BEGIN
                                     SELECT DISTINCT 'Y'
                                       INTO lc_ship_via
                                       FROM fnd_lookup_values flv,
                                            wsh_carrier_ship_methods wcsm
                                      WHERE     flv.lookup_code = wcsm.ship_method_code
                                            AND flv.lookup_type = 'SHIP_METHOD'
                                            AND end_date_active IS NULL
                                            AND UPPER (wcsm.freight_code) =
                                                   UPPER (sup_rec.ship_via_lookup_code)
                                            AND wcsm.enabled_flag = 'Y';
                                  EXCEPTION
                                     WHEN NO_DATA_FOUND
                                     THEN
                                        lc_supp_err_flag := 'Y';
                                        lc_supp_err_msg :=
                                              lc_supp_err_msg
                                           || ' \ '
                                           || 'SHIP_VIA_LOOKUP_CODE -'
                                           || sup_rec.ship_via_lookup_code
                                           || ' does not Exists for supplier '
                                           || sup_rec.vendor_name;
                                        xxd_common_utils.record_error (
                                           'AP',
                                           xxd_common_utils.get_org_id,
                                           'XXD AP Supplier Conv Validate and Load',
                                              'No Data Found for Ship Via Lookup of supplier '
                                           || sup_rec.vendor_name
                                           || SUBSTR (
                                                    'Error: '
                                                 || TO_CHAR (SQLCODE)
                                                 || ':-'
                                                 || SQLERRM,
                                                 1,
                                                 499),
                                           DBMS_UTILITY.format_error_backtrace,
                                           fnd_profile.VALUE ('USER_ID'),
                                           gn_conc_request_id,
                                           sup_rec.segment1,
                                           sup_rec.old_vendor_id);
                                     WHEN OTHERS
                                     THEN
                                        lc_supp_err_flag := 'Y';
                                        lc_supp_err_msg :=
                                              lc_supp_err_msg
                                           || '\'
                                           || 'Supplier SHIP_VIA_LOOKUP_CODE Validation'
                                           || 'failed for the Lookup Code -'
                                           || sup_rec.ship_via_lookup_code
                                           || ' for supplier '
                                           || sup_rec.vendor_name
                                           || ' Error no-'
                                           || SUBSTR ( (SQLCODE || '-' || SQLERRM),
                                                      1,
                                                      100);
                                        xxd_common_utils.record_error (
                                           'AP',
                                           xxd_common_utils.get_org_id,
                                           'XXD AP Supplier Conv Validate and Load',
                                              'When others exception for Ship Via Lookup of supplier '
                                           || sup_rec.vendor_name
                                           || SUBSTR (
                                                    'Error: '
                                                 || TO_CHAR (SQLCODE)
                                                 || ':-'
                                                 || SQLERRM,
                                                 1,
                                                 499),
                                           DBMS_UTILITY.format_error_backtrace,
                                           fnd_profile.VALUE ('USER_ID'),
                                           gn_conc_request_id,
                                           sup_rec.segment1,
                                           sup_rec.old_vendor_id);
                                  END;
                               ELSE
                                  NULL;
                               END IF; */


                        IF sup_rec.freight_terms_lookup_code IS NOT NULL
                        THEN
                            BEGIN
                                SELECT lookup_code
                                  INTO lc_freight_term
                                  FROM fnd_lookup_values_vl
                                 WHERE     UPPER (lookup_code) =
                                           UPPER (
                                               sup_rec.freight_terms_lookup_code)
                                       AND lookup_type = 'FREIGHT TERMS'
                                       AND end_date_active IS NULL;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    lc_supp_err_flag   := 'Y';
                                    lc_supp_err_msg    :=
                                           lc_supp_err_msg
                                        || ' \ '
                                        || 'FREIGHT_TERMS_LOOKUP_CODE  -'
                                        || sup_rec.freight_terms_lookup_code
                                        || ' does not Exists for supplier '
                                        || sup_rec.vendor_name;
                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Conv Validate and Load',
                                           'No Data found for Freight Terms Lookup code of supplier '
                                        || sup_rec.vendor_name
                                        || SUBSTR (
                                                  'Error: '
                                               || TO_CHAR (SQLCODE)
                                               || ':-'
                                               || SQLERRM,
                                               1,
                                               499),
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id);
                                WHEN OTHERS
                                THEN
                                    lc_supp_err_flag   := 'Y';
                                    lc_supp_err_msg    :=
                                           lc_supp_err_msg
                                        || '\'
                                        || 'Supplier FREIGHT_TERMS_LOOKUP_CODE  Validation'
                                        || 'failed for the Lookup Code -'
                                        || sup_rec.freight_terms_lookup_code
                                        || ' for supplier '
                                        || sup_rec.vendor_name
                                        || ' Error no-'
                                        || SUBSTR (
                                               (SQLCODE || '-' || SQLERRM),
                                               1,
                                               100);
                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Conv Validate and Load',
                                           'When others exception for Freight Terms Lookup code of supplier '
                                        || sup_rec.vendor_name
                                        || SUBSTR (
                                                  'Error: '
                                               || TO_CHAR (SQLCODE)
                                               || ':-'
                                               || SQLERRM,
                                               1,
                                               499),
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id);
                            END;
                        ELSE
                            NULL;
                        END IF;

                        IF sup_rec.fob_lookup_code IS NOT NULL
                        THEN
                            BEGIN
                                SELECT lookup_code
                                  INTO lc_fob
                                  FROM fnd_lookup_values_vl
                                 WHERE     UPPER (lookup_code) =
                                           UPPER (sup_rec.fob_lookup_code)
                                       AND lookup_type = 'FOB'
                                       AND end_date_active IS NULL
                                       AND view_application_id = 201;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    lc_supp_err_flag   := 'Y';
                                    lc_supp_err_msg    :=
                                           lc_supp_err_msg
                                        || ' \ '
                                        || 'FOB_LOOKUP_CODE   -'
                                        || sup_rec.fob_lookup_code
                                        || ' does not Exists for supplier '
                                        || sup_rec.vendor_name;
                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Conv Validate and Load',
                                           'No Data Found for FOB Lookup code of supplier '
                                        || sup_rec.vendor_name
                                        || SUBSTR (
                                                  'Error: '
                                               || TO_CHAR (SQLCODE)
                                               || ':-'
                                               || SQLERRM,
                                               1,
                                               499),
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id);
                                WHEN OTHERS
                                THEN
                                    lc_supp_err_flag   := 'Y';
                                    lc_supp_err_msg    :=
                                           lc_supp_err_msg
                                        || '\'
                                        || 'Supplier FOB_LOOKUP_CODE   Validation'
                                        || 'failed for the Lookup Code -'
                                        || sup_rec.fob_lookup_code
                                        || ' for supplier '
                                        || sup_rec.vendor_name
                                        || ' Error no-'
                                        || SUBSTR (
                                               (SQLCODE || '-' || SQLERRM),
                                               1,
                                               100);
                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Conv Validate and Load',
                                           'When Others exception for FOB Lookup code of supplier '
                                        || sup_rec.vendor_name
                                        || SUBSTR (
                                                  'Error: '
                                               || TO_CHAR (SQLCODE)
                                               || ':-'
                                               || SQLERRM,
                                               1,
                                               499),
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id);
                            END;
                        ELSE
                            NULL;
                        END IF;

                        ln_term_id                := NULL; -- Added by BT team on 4/26

                        IF sup_rec.terms_name IS NOT NULL
                        THEN
                            BEGIN
                                SELECT NAME, term_id
                                  INTO lc_term_name, ln_term_id
                                  FROM ap_terms
                                 WHERE UPPER (NAME) =
                                       UPPER (sup_rec.terms_name);
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    lc_supp_err_flag   := 'Y';
                                    lc_supp_err_msg    :=
                                           lc_supp_err_msg
                                        || ' \ '
                                        || 'TERMS_NAME   -'
                                        || sup_rec.terms_name
                                        || ' does not Exists for supplier '
                                        || sup_rec.vendor_name;
                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Conv Validate and Load',
                                           'No Data Found for Terms Name of supplier: '
                                        || sup_rec.vendor_name
                                        || SUBSTR (
                                                  'Error: '
                                               || TO_CHAR (SQLCODE)
                                               || ':-'
                                               || SQLERRM,
                                               1,
                                               499),
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id);
                                WHEN OTHERS
                                THEN
                                    lc_supp_err_flag   := 'Y';
                                    lc_supp_err_msg    :=
                                           lc_supp_err_msg
                                        || '\'
                                        || 'Supplier TERMS_NAME   Validation'
                                        || 'failed for the Term -'
                                        || sup_rec.terms_name
                                        || ' for supplier '
                                        || sup_rec.vendor_name
                                        || ' Error no-'
                                        || SUBSTR (
                                               (SQLCODE || '-' || SQLERRM),
                                               1,
                                               100);
                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Conv Validate and Load',
                                           'When others exception for Terms Name of supplier: '
                                        || sup_rec.vendor_name
                                        || SUBSTR (
                                                  'Error: '
                                               || TO_CHAR (SQLCODE)
                                               || ':-'
                                               || SQLERRM,
                                               1,
                                               499),
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id);
                            END;
                        ELSE
                            NULL;
                        END IF;

                        IF sup_rec.pay_group_lookup_code IS NOT NULL
                        THEN
                            BEGIN
                                SELECT lookup_code
                                  INTO lc_pay_group_code
                                  FROM fnd_lookup_values_vl
                                 WHERE     UPPER (lookup_code) =
                                           UPPER (
                                               sup_rec.pay_group_lookup_code)
                                       AND lookup_type = 'PAY GROUP'
                                       AND end_date_active IS NULL;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    BEGIN
                                        SELECT lookup_code
                                          INTO lc_pay_group_code
                                          FROM fnd_lookup_values_vl
                                         WHERE     lookup_type = 'PAY GROUP'
                                               AND end_date_active IS NULL
                                               AND lookup_code =
                                                   sup_rec.pay_group_lookup_code;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            lc_supp_err_flag   := 'Y';
                                            lc_supp_err_msg    :=
                                                   lc_supp_err_msg
                                                || ' \ '
                                                || 'PAY_GROUP_LOOKUP_CODE    -'
                                                || sup_rec.pay_group_lookup_code
                                                || ' does not Exists for supplier '
                                                || sup_rec.vendor_name;
                                            xxd_common_utils.record_error (
                                                'AP',
                                                xxd_common_utils.get_org_id,
                                                'XXD AP Supplier Conv Validate and Load',
                                                   'When others exception for PAY_GROUP_LOOKUP_CODE of supplier: '
                                                || sup_rec.vendor_name
                                                || SUBSTR (
                                                          'Error: '
                                                       || TO_CHAR (SQLCODE)
                                                       || ':-'
                                                       || SQLERRM,
                                                       1,
                                                       499),
                                                DBMS_UTILITY.format_error_backtrace,
                                                fnd_profile.VALUE ('USER_ID'),
                                                gn_conc_request_id,
                                                sup_rec.segment1,
                                                sup_rec.old_vendor_id);
                                    END;
                                WHEN OTHERS
                                THEN
                                    lc_supp_err_flag   := 'Y';
                                    lc_supp_err_msg    :=
                                           lc_supp_err_msg
                                        || '\'
                                        || 'Supplier PAY_GROUP_LOOKUP_CODE Validation'
                                        || 'failed for the Lookup Code -'
                                        || sup_rec.pay_group_lookup_code
                                        || ' for supplier '
                                        || sup_rec.vendor_name
                                        || ' Error no-'
                                        || SUBSTR (
                                               (SQLCODE || '-' || SQLERRM),
                                               1,
                                               100);
                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Conv Validate and Load',
                                           'When others exception for Supplier PAY_GROUP_LOOKUP_CODE Validation of supplier: '
                                        || sup_rec.vendor_name
                                        || SUBSTR (
                                                  'Error: '
                                               || TO_CHAR (SQLCODE)
                                               || ':-'
                                               || SQLERRM,
                                               1,
                                               499),
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id);
                            END;
                        ELSE
                            NULL;
                        END IF;

                        ln_awt_group_id           := NULL; -- Added by BT team on 4/26

                        IF sup_rec.awt_group_name IS NOT NULL
                        THEN
                            BEGIN
                                SELECT GROUP_ID
                                  INTO ln_awt_group_id
                                  FROM ap_awt_groups
                                 WHERE UPPER (NAME) =
                                       UPPER (sup_rec.awt_group_name);
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    lc_supp_err_flag   := 'Y';
                                    lc_supp_err_msg    :=
                                           lc_supp_err_msg
                                        || ' \ '
                                        || 'AWT_GROUP_NAME    -'
                                        || sup_rec.awt_group_name
                                        || ' does not Exists for supplier '
                                        || sup_rec.vendor_name;
                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Conv Validate and Load',
                                           'No data found for AWT_GROUP_NAME of supplier: '
                                        || sup_rec.vendor_name
                                        || SUBSTR (
                                                  'Error: '
                                               || TO_CHAR (SQLCODE)
                                               || ':-'
                                               || SQLERRM,
                                               1,
                                               499),
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id);
                                WHEN OTHERS
                                THEN
                                    lc_supp_err_flag   := 'Y';
                                    lc_supp_err_msg    :=
                                           lc_supp_err_msg
                                        || '\'
                                        || 'Supplier AWT_GROUP_NAME Validation'
                                        || 'failed for the Code -'
                                        || sup_rec.awt_group_name
                                        || ' for supplier '
                                        || sup_rec.vendor_name
                                        || ' Error no-'
                                        || SUBSTR (
                                               (SQLCODE || '-' || SQLERRM),
                                               1,
                                               100);
                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Conv Validate and Load',
                                           'When others exception for AWT_GROUP_NAME of supplier: '
                                        || sup_rec.vendor_name
                                        || SUBSTR (
                                                  'Error: '
                                               || TO_CHAR (SQLCODE)
                                               || ':-'
                                               || SQLERRM,
                                               1,
                                               499),
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id);
                            END;
                        END IF;



                        IF sup_rec.bank_num IS NOT NULL
                        THEN
                            BEGIN
                                SELECT COUNT (*)
                                  INTO lc_bank_exist
                                  FROM ce_bank_branches_v
                                 WHERE     bank_number = sup_rec.bank_num
                                       AND bank_institution_type = 'BANK'
                                       AND end_date IS NULL;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    lc_supp_err_flag   := 'Y';
                                    lc_supp_err_msg    :=
                                           lc_supp_err_msg
                                        || ' \ '
                                        || 'BANK_NUM -'
                                        || sup_rec.bank_num
                                        || ' does not Exists for supplier '
                                        || sup_rec.vendor_name;
                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Conv Validate and Load',
                                           'No data found for AWT_GROUP_NAME of supplier: '
                                        || sup_rec.vendor_name
                                        || SUBSTR (
                                                  'Error: '
                                               || TO_CHAR (SQLCODE)
                                               || ':-'
                                               || SQLERRM,
                                               1,
                                               499),
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id);
                                WHEN OTHERS
                                THEN
                                    lc_supp_err_flag   := 'Y';
                                    lc_supp_err_msg    :=
                                           lc_supp_err_msg
                                        || '\'
                                        || 'Supplier BANK_NUM Validation'
                                        || 'failed -'
                                        || sup_rec.bank_num
                                        || ' for supplier '
                                        || sup_rec.vendor_name
                                        || ' Error no-'
                                        || SUBSTR (
                                               (SQLCODE || '-' || SQLERRM),
                                               1,
                                               100);
                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Conv Validate ',
                                           'When others exception in BANK_NUM Validation for supplier: '
                                        || sup_rec.vendor_name
                                        || SUBSTR (
                                                  'Error: '
                                               || TO_CHAR (SQLCODE)
                                               || ':-'
                                               || SQLERRM,
                                               1,
                                               499),
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id);
                            END;
                        ELSE
                            NULL;
                        END IF;


                        ln_sob_id                 := NULL; -- Added by BT team on 4/26

                        IF sup_rec.set_of_books_id IS NOT NULL
                        THEN
                            BEGIN
                                ln_sob_id   := NULL;

                                SELECT ledger_id
                                  INTO ln_sob_id
                                  FROM gl_ledgers
                                 WHERE UPPER (NAME) =
                                       (SELECT UPPER (attribute1)
                                          FROM fnd_lookup_values flv, fnd_application_tl ft
                                         WHERE     lookup_type =
                                                   'XXD_1206_LEDGER_MAPPING'
                                               AND flv.LANGUAGE = 'US'
                                               AND flv.view_application_id =
                                                   ft.application_id
                                               AND APPLICATION_NAME =
                                                   'Application Utilities'
                                               AND ft.LANGUAGE = 'US'
                                               --AND ATTRIBUTE_CATEGORY = 'XXD_1206_LEDGER_MAPPING'
                                               AND lookup_code =
                                                   sup_rec.set_of_books_id);
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    lc_supp_err_flag   := 'Y';
                                    ln_sob_id          := NULL;
                                    log_records (
                                        p_debug,
                                           'NO_DATA_FOUND- Set Of Book Validation '
                                        || sup_rec.set_of_books_id);
                                    lc_supp_err_msg    :=
                                           lc_supp_err_msg
                                        || '\'
                                        || 'Supplier Set of Book Validation'
                                        || 'failed -'
                                        || sup_rec.set_of_books_id
                                        || ' for supplier '
                                        || sup_rec.vendor_name
                                        || ' Error no-'
                                        || SUBSTR (
                                               (SQLCODE || '-' || SQLERRM),
                                               1,
                                               100);

                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Conv Validate ',
                                           'NO_DATA_FOUND- Set Of Book Validation  '
                                        || SUBSTR (
                                                  'Error: '
                                               || TO_CHAR (SQLCODE)
                                               || ':-'
                                               || SQLERRM,
                                               1,
                                               499),
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id);
                                WHEN OTHERS
                                THEN
                                    lc_supp_err_flag   := 'Y';
                                    log_records (
                                        p_debug,
                                           'OTHERS Exception- Set Of Book Validation '
                                        || sup_rec.set_of_books_id);

                                    lc_supp_err_msg    :=
                                           lc_supp_err_msg
                                        || '\'
                                        || 'OTHERS Exception- Set Of Book Validation'
                                        || 'failed -'
                                        || sup_rec.set_of_books_id
                                        || ' for supplier '
                                        || sup_rec.vendor_name
                                        || ' Error no-'
                                        || SUBSTR (
                                               (SQLCODE || '-' || SQLERRM),
                                               1,
                                               100);

                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Conv Validate ',
                                           'OTHERS Exception- Set Of Book Validation  '
                                        || SUBSTR (
                                                  'Error: '
                                               || TO_CHAR (SQLCODE)
                                               || ':-'
                                               || SQLERRM,
                                               1,
                                               499),
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id);
                            END;
                        END IF;



                        --      IF sup_rec.stg.hold_by_employee_number IS NOT NULL
                        --      THEN
                        --         BEGIN
                        --            SELECT papf.person_id
                        --              INTO lv_HOLD_EMP_ID
                        --              FROM per_all_people_f papf
                        --             WHERE employee_number = sup_rec.stg.hold_by_employee_number;
                        --         EXCEPTION
                        --            WHEN NO_DATA_FOUND
                        --            THEN
                        --               fnd_file.put_line(fnd_file.log,
                        --                     'NO_DATA_FOUND Exception-Hold by Employee ID Validation- '
                        --                  || sup_rec.stg.employee_number);
                        --               lv_HOLD_EMP_ID := NULL;
                        --            WHEN OTHERS
                        --            THEN
                        --               fnd_file.put_line(fnd_file.log,
                        --                     'OTHERS Exception-Hold by Employee ID Validation- '
                        --                  || sup_rec.stg.employee_number);
                        --         END;
                        --      ELSE
                        --         lv_HOLD_EMP_ID := NULL;
                        --      END IF;
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'sup_rec.PAYMENT_METHOD_LOOKUP_CODE ' || sup_rec.PAYMENT_METHOD_LOOKUP_CODE);

                        --Modified on 15=APr-2015
                        OPEN Get_bank_account_c (sup_rec.OLD_VENDOR_ID);

                        lc_bank_account_num       := NULL;

                        FETCH Get_bank_account_c INTO lc_bank_account_num;

                        CLOSE Get_bank_account_c;

                        IF lc_bank_account_num IS NOT NULL
                        THEN
                            lc_PAYMENT_METHOD_LOOKUP_CODE   := 'EFT';
                        ELSE
                            /*  OPEN get_payment_method_c(sup_rec.PAYMENT_METHOD_LOOKUP_CODE);

                              lc_desc := NULL;

                              FETCH get_payment_method_c INTO lc_desc;

                              CLOSE get_payment_method_c;

                              IF lc_desc = 'Electronic'
                              THEN
                                 lc_PAYMENT_METHOD_LOOKUP_CODE := 'EFT';

                              END IF; */
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'sup_rec.PAYMENT_METHOD_LOOKUP_CODE '
                                || sup_rec.PAYMENT_METHOD_LOOKUP_CODE);


                            IF sup_rec.PAYMENT_METHOD_LOOKUP_CODE = 'WIRE'
                            THEN
                                fnd_file.put_line (fnd_file.LOG, 'Test1000');
                                lc_PAYMENT_METHOD_LOOKUP_CODE   := 'WIRE';
                            ELSIF sup_rec.PAYMENT_METHOD_LOOKUP_CODE =
                                  'CHECK'
                            THEN
                                fnd_file.put_line (fnd_file.LOG, 'Test2000');
                                lc_PAYMENT_METHOD_LOOKUP_CODE   := 'CHECK';
                            --lc_pay_group_code := 'CHECK';
                            ELSE
                                fnd_file.put_line (fnd_file.LOG, 'Test3000');

                                OPEN get_payment_method_c (
                                    sup_rec.PAYMENT_METHOD_LOOKUP_CODE);

                                lc_PAYMENT_METHOD_LOOKUP_CODE   := NULL;

                                FETCH get_payment_method_c
                                    INTO lc_PAYMENT_METHOD_LOOKUP_CODE;

                                CLOSE get_payment_method_c;
                            END IF;
                        END IF;

                        fnd_file.put_line (
                            fnd_file.LOG,
                               'lc_PAYMENT_METHOD_LOOKUP_CODE '
                            || lc_PAYMENT_METHOD_LOOKUP_CODE);

                        --Modified on 15=APr-2015


                        /*     IF sup_rec.attribute2 = 'Y'
                                  THEN
                                     lc_PAYMENT_METHOD_LOOKUP_CODE :=
                                        sup_rec.PAYMENT_METHOD_LOOKUP_CODE;
                                     lc_pay_group_code := sup_rec.pay_group_lookup_code;
                                  END IF; */
                        lc_pay_group_code         := NULL; --Modified on 15-APR-2015



                        IF sup_rec.pay_group_lookup_code = 'COMMISSIONS'
                        THEN
                            lc_PAYMENT_METHOD_LOOKUP_CODE   := 'Commissions';
                        END IF;



                        IF NVL (lc_supp_err_flag, 'N') = 'Y'
                        THEN
                            UPDATE xxd_ap_suppliers_cnv_stg_t
                               SET record_status = 'E', error_message = SUBSTR (lc_supp_err_msg, 1, 1999), last_update_login = fnd_global.login_id,
                                   creation_date = SYSDATE, created_by = fnd_global.user_id, last_update_date = SYSDATE,
                                   last_updated_by = fnd_global.user_id, request_id = gn_conc_request_id, vendor_type_lookup_code = lc_ven_type_lookup_code,
                                   pay_group_lookup_code = lc_pay_group_code, PAYMENT_METHOD_LOOKUP_CODE = lc_PAYMENT_METHOD_LOOKUP_CODE, emp_id = ln_employee_id,
                                   set_of_books_id = ln_sob_id, BILL_TO_LOCATION_ID = ln_bill_location_id
                             WHERE old_vendor_id = sup_rec.old_vendor_id;

                            --ROWID = sup_rec.rid;

                            UPDATE xxd_ap_sup_sites_cnv_stg_t
                               SET record_status = 'E', error_message = 'Validation Failed in Supplier', last_update_login = fnd_global.login_id,
                                   creation_date = SYSDATE, created_by = fnd_global.user_id, last_update_date = SYSDATE,
                                   last_updated_by = fnd_global.user_id, request_id = gn_conc_request_id
                             WHERE old_vendor_id = sup_rec.old_vendor_id;

                            gn_supp_reject   := gn_supp_reject + 1;
                        --gv_site_rejected := gv_site_rejected + 1;
                        ELSE
                            BEGIN
                                UPDATE xxd_ap_suppliers_cnv_stg_t
                                   SET record_status = 'V', error_message = NULL, vendor_type_lookup_code = lc_ven_type_lookup_code,
                                       pay_group_lookup_code = lc_pay_group_code, PAYMENT_METHOD_LOOKUP_CODE = lc_PAYMENT_METHOD_LOOKUP_CODE, emp_id = ln_employee_id,
                                       last_update_login = fnd_global.login_id, creation_date = SYSDATE, set_of_books_id = ln_sob_id,
                                       created_by = fnd_global.user_id, last_update_date = SYSDATE, last_updated_by = fnd_global.user_id,
                                       request_id = gn_conc_request_id, BILL_TO_LOCATION_ID = ln_bill_location_id, --Modified on 18-JAN-2015
                                                                                                                   BILL_TO_LOCATION_code = lc_bill_code,
                                       ship_TO_LOCATION_code = lc_ship_code
                                 WHERE old_vendor_id = sup_rec.old_vendor_id;


                                -- ROWID = sup_rec.rid;

                                UPDATE xxd_ap_sup_sites_cnv_stg_t
                                   SET error_message = NULL, last_update_login = fnd_global.login_id, creation_date = SYSDATE,
                                       created_by = fnd_global.user_id, last_update_date = SYSDATE, last_updated_by = fnd_global.user_id,
                                       request_id = gn_conc_request_id
                                 WHERE old_vendor_id = sup_rec.old_vendor_id;

                                UPDATE xxd_conv.xxd_ap_sup_site_con_cnv_stg_t
                                   SET error_message = NULL, last_update_login = fnd_global.login_id, creation_date = SYSDATE,
                                       created_by = fnd_global.user_id, last_update_date = SYSDATE, last_updated_by = fnd_global.user_id,
                                       request_id = gn_conc_request_id
                                 WHERE old_vendor_site_id IN
                                           (SELECT old_vendor_site_id
                                              FROM xxd_ap_sup_sites_cnv_stg_t
                                             WHERE old_vendor_id =
                                                   sup_rec.old_vendor_id);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    log_records (
                                        p_debug,
                                           'Exception in  Valid Update Statement- '
                                        || sup_rec.old_vendor_id);
                            END;

                            gn_supp_process   := gn_supp_process + 1;
                            --END IF;
                            COMMIT;
                        END IF;
                    END IF;

                    --Supplier Site Contact Loop Starts
                    -------------------------------------
                    FOR contact_rec IN c_ss_contact (sup_rec.old_vendor_id)
                    LOOP
                        lc_cont_err_flag   := NULL;
                        lc_cont_err_msg    := NULL;

                        IF contact_rec.first_name IS NULL
                        THEN
                            lc_cont_err_flag   := 'Y';
                            lc_cont_err_msg    :=
                                   lc_cont_err_msg
                                || '\Contact First Name'
                                || 'Cannot be null For the supplier/Site '
                                || sup_rec.vendor_name
                                || '/'
                                || sup_rec.SEGMENT1;

                            xxd_common_utils.record_error (
                                'AP',
                                xxd_common_utils.get_org_id,
                                'XXD AP Supplier Site Contact Conv Validate ',
                                   'Contact First Name'
                                || 'Cannot be null For the supplier/Site '
                                || sup_rec.vendor_name
                                || '/'
                                || sup_rec.SEGMENT1,
                                DBMS_UTILITY.format_error_backtrace,
                                fnd_profile.VALUE ('USER_ID'),
                                gn_conc_request_id,
                                sup_rec.segment1,
                                sup_rec.old_vendor_id,
                                sup_rec.SEGMENT1,
                                contact_rec.old_vendor_contact_id);
                        END IF;


                        IF contact_rec.last_name IS NULL
                        THEN
                            lc_cont_err_flag   := 'Y';
                            lc_cont_err_msg    :=
                                   lc_cont_err_msg
                                || '\Contact Last Name'
                                || 'Cannot be null for the supplier/Site/First name'
                                || sup_rec.vendor_name
                                || '/'
                                || sup_rec.segment1
                                || '/'
                                || contact_rec.first_name;

                            xxd_common_utils.record_error (
                                'AP',
                                xxd_common_utils.get_org_id,
                                'XXD AP Supplier Site Contact Conv Validate ',
                                   'Contact Last Name'
                                || 'Cannot be null for the supplier/Site/First name'
                                || sup_rec.vendor_name
                                || '/'
                                || sup_rec.segment1
                                || '/'
                                || contact_rec.first_name,
                                DBMS_UTILITY.format_error_backtrace,
                                fnd_profile.VALUE ('USER_ID'),
                                gn_conc_request_id,
                                sup_rec.segment1,
                                sup_rec.old_vendor_id,
                                sup_rec.segment1,
                                contact_rec.old_vendor_contact_id);
                        END IF;

                        IF contact_rec.old_operating_unit_name IS NOT NULL
                        THEN
                            lc_new_ou   := NULL;
                            ln_org_id   := NULL;
                            GET_ORG_ID (contact_rec.old_operating_unit_name,
                                        ln_org_id,
                                        lc_new_ou);

                            IF ln_org_id IS NULL
                            THEN
                                lc_new_ou   := NULL;
                                ln_org_id   := NULL;
                                log_records (
                                    p_debug,
                                       'NO_DATA_FOUND- New OU/OU_ID Validation '
                                    || contact_rec.old_operating_unit_name);

                                --                              lc_sup_site_err_flag := 'Y';
                                lc_sup_site_err_msg   :=
                                       lc_sup_site_err_msg
                                    || ' \ '
                                    || 'Mapping is not avaiable for the OLD OU  -'
                                    || contact_rec.old_operating_unit_name
                                    || contact_rec.vendor_site_code;

                                xxd_common_utils.record_error (
                                    'AP',
                                    xxd_common_utils.get_org_id,
                                    'XXD AP Supplier Site Contact Conv Validate ',
                                       'Mapping is not avaiable for the OLD OU  -'
                                    || contact_rec.old_operating_unit_name,
                                    DBMS_UTILITY.format_error_backtrace,
                                    fnd_profile.VALUE ('USER_ID'),
                                    gn_conc_request_id,
                                    sup_rec.segment1,
                                    sup_rec.old_vendor_id,
                                    sup_rec.segment1,
                                    contact_rec.old_vendor_contact_id);
                            END IF;
                        END IF;

                        IF    NVL (lc_cont_err_flag, 'N') = 'Y'
                           --                           OR NVL (lc_sup_site_err_flag, 'N') = 'Y'
                           OR NVL (lc_supp_err_flag, 'N') = 'Y'
                        THEN
                            UPDATE xxd_conv.xxd_ap_sup_site_con_cnv_stg_t
                               SET record_status = 'E', error_message = SUBSTR (lc_cont_err_msg, 1, 1000), last_update_login = fnd_global.login_id,
                                   last_update_date = SYSDATE, last_updated_by = fnd_global.user_id, request_id = gn_conc_request_id
                             WHERE old_vendor_contact_id =
                                   contact_rec.old_vendor_contact_id;

                            gn_contact_rejected   := gn_contact_rejected + 1;
                        /*
                        UPDATE XXD_SUPPLIER_CONV_STG
                           SET record_status = 'E',
                               error_message =
                                  'Validation Failed in Contacts',
                               LAST_Update_Login = FND_GLOBAL.LOGIN_ID,
                               Last_update_date = SYSDATE,
                               Last_updated_by = FND_GLOBAL.USER_ID,
                               request_id = gv_Conc_request_id
                         WHERE old_vendor_id = sup_rec.old_vendor_id;

                        UPDATE XXD_SUPPLIER_SITE_CONV_STG
                           SET record_status = 'E',
                               error_message =
                                  'Validation Failed in Contacts',
                               LAST_Update_Login = FND_GLOBAL.LOGIN_ID,
                               Last_update_date = SYSDATE,
                               Last_updated_by = FND_GLOBAL.USER_ID,
                               request_id = gv_Conc_request_id
                         WHERE old_vendor_site_id =
                                  contact_rec.old_vendor_site_id;
                    */
                        ELSE
                            UPDATE xxd_conv.xxd_ap_sup_site_con_cnv_stg_t
                               SET record_status = 'V', error_message = NULL, last_update_login = fnd_global.login_id,
                                   last_update_date = SYSDATE, last_updated_by = fnd_global.user_id, request_id = gn_conc_request_id,
                                   new_operating_unit_name = lc_new_ou, org_id = ln_org_id
                             WHERE old_vendor_contact_id =
                                   contact_rec.old_vendor_contact_id;

                            gn_contact_processed   :=
                                gn_contact_processed + 1;
                        END IF;
                    END LOOP;

                    --'Supplier Site Contact Loop End
                    -----------------------------------

                    --Supplier Site  Loop Starts
                    ----------------------------
                    FOR site_rec IN c_sup_sites (sup_rec.old_vendor_id)
                    LOOP
                        lc_pay_method_code         := NULL;
                        lc_distribut_set_name      := NULL;
                        ln_site_ship_location_id   := NULL;
                        ln_site_bill_location_id   := NULL;
                        lc_site_ship_via           := NULL;
                        --Lv_term_name               VARCHAR2 (30);
                        ln_term_id                 := NULL;
                        lc_site_fob                := NULL;
                        lc_site_freight_term       := NULL;
                        lc_site_pay_group_code     := NULL;
                        lc_tolerance_name          := NULL;
                        lc_sup_site_err_flag       := NULL;
                        lc_sup_site_err_msg        := NULL;
                        ln_dup_count_org_id        := NULL;

                        --lc_site_pay_mthd_CODE

                        IF site_rec.vendor_site_code IS NULL
                        THEN
                            lc_sup_site_err_flag   := 'Y';
                            lc_sup_site_err_msg    :=
                                   lc_sup_site_err_msg
                                || '\'
                                || 'Site_name is NULL';
                            xxd_common_utils.record_error (
                                'AP',
                                xxd_common_utils.get_org_id,
                                'XXD AP Supplier Site Conv Validate ',
                                   'Vendor Site Code is Null: '
                                || sup_rec.vendor_name
                                || SUBSTR (
                                          'Error: '
                                       || TO_CHAR (SQLCODE)
                                       || ':-'
                                       || SQLERRM,
                                       1,
                                       499),
                                DBMS_UTILITY.format_error_backtrace,
                                fnd_profile.VALUE ('USER_ID'),
                                gn_conc_request_id,
                                sup_rec.segment1,
                                sup_rec.old_vendor_id,
                                site_rec.vendor_site_code);
                        END IF;

                        --Commented as part of BT Changes after conversion run dated 17-DEC-2014
                        /*         IF     site_rec.address_line1 IS NULL
                                    AND site_rec.vendor_site_code != 'HOME'
                                 THEN
                                    lc_sup_site_err_flag := 'Y';
                                    lc_sup_site_err_msg :=
                                       lc_sup_site_err_msg || '\' || 'Site Address is NULL';

                                    xxd_common_utils.record_error (
                                       'AP',
                                       xxd_common_utils.get_org_id,
                                       'XXD AP Supplier Site Conv Validate ',
                                          'Site Address is Null: '
                                       || sup_rec.vendor_name
                                       || SUBSTR (
                                                'Error: '
                                             || TO_CHAR (SQLCODE)
                                             || ':-'
                                             || SQLERRM,
                                             1,
                                             499),
                                       DBMS_UTILITY.format_error_backtrace,
                                       fnd_profile.VALUE ('USER_ID'),
                                       gn_conc_request_id,
                                       sup_rec.segment1,
                                       sup_rec.old_vendor_id,
                                       site_rec.vendor_site_code);
                                 END IF; */
                        --Commented as part of BT Changes after conversion run dated 17-DEC-2014

                        BEGIN
                            SELECT COUNT (*)
                              INTO ln_dup_count_org_id
                              FROM xxd_ap_sup_sites_cnv_stg_t
                             WHERE     old_vendor_id = sup_rec.old_vendor_id
                                   AND UPPER (vendor_site_code) =
                                       UPPER (site_rec.vendor_site_code)
                                   AND UPPER (new_operating_unit_name) =
                                       UPPER (
                                           site_rec.new_operating_unit_name);

                            --AND org_id = site_rec.org_id;-- uncomment once org_id is not null column
                            IF ln_dup_count_org_id > 1
                            THEN
                                lc_sup_site_err_flag   := 'Y';
                                lc_sup_site_err_msg    :=
                                       lc_sup_site_err_msg
                                    || 'duplicate site entry for'
                                    || sup_rec.vendor_name
                                    || '/'
                                    || site_rec.vendor_site_code
                                    || '/'
                                    || site_rec.org_id;

                                xxd_common_utils.record_error (
                                    'AP',
                                    xxd_common_utils.get_org_id,
                                    'XXD AP Supplier Site Conv Validate ',
                                       'Site Address is Null: '
                                    || sup_rec.vendor_name
                                    || 'duplicate site entry for'
                                    || sup_rec.vendor_name
                                    || '/'
                                    || site_rec.vendor_site_code
                                    || '/'
                                    || site_rec.org_id,
                                    DBMS_UTILITY.format_error_backtrace,
                                    fnd_profile.VALUE ('USER_ID'),
                                    gn_conc_request_id,
                                    sup_rec.segment1,
                                    sup_rec.old_vendor_id,
                                    site_rec.vendor_site_code);
                            END IF;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lc_sup_site_err_flag   := 'Y';
                                lc_sup_site_err_msg    :=
                                       lc_sup_site_err_msg
                                    || '\OTHERS Exception Duplicate SITE Check- '
                                    || SQLERRM;

                                xxd_common_utils.record_error (
                                    'AP',
                                    xxd_common_utils.get_org_id,
                                    'XXD AP Supplier Site Conv Validate ',
                                       'OTHERS Exception Duplicate SITE Check- '
                                    || SQLERRM,
                                    DBMS_UTILITY.format_error_backtrace,
                                    fnd_profile.VALUE ('USER_ID'),
                                    gn_conc_request_id,
                                    sup_rec.segment1,
                                    sup_rec.old_vendor_id,
                                    site_rec.vendor_site_code);
                        END;


                        lc_ship_code               := NULL; -- Added the code by BT team on 4/26

                        -- Supplier Site Validation starts
                        ------------------------------------
                        IF site_rec.ship_to_location_code IS NOT NULL
                        THEN
                            BEGIN
                                /* SELECT location_id
                                   INTO ln_site_ship_location_id
                                   FROM hr_locations_all
                                  WHERE UPPER (location_code) =
                                           UPPER (site_rec.ship_to_location_code); */
                                --                        lc_ship_code := NULL; -- Commented the code by BT team on 4/26


                                SELECT location_id, flv.description
                                  INTO ln_site_ship_location_id, lc_ship_code
                                  FROM hr_locations_all hla --Code modification on 05-MAR-2015
                                                           , fnd_lookup_values flv
                                 WHERE     UPPER (hla.location_code) =
                                           UPPER (flv.description)
                                       AND UPPER (flv.meaning) =
                                           UPPER (
                                               site_rec.ship_to_location_code)
                                       AND lookup_type =
                                           'XXDO_CONV_LOCATION_MAPPING'
                                       AND language = 'US';
                            --Code modification on 05-MAR-2015

                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    lc_sup_site_err_flag   := 'Y';
                                    lc_sup_site_err_msg    :=
                                           lc_sup_site_err_msg
                                        || ' \ '
                                        || 'SHIP_TO_LOCATION_CODE -'
                                        || site_rec.ship_to_location_code
                                        || ' does not Exists for Supplier Site Site '
                                        || site_rec.vendor_site_code;

                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Site Conv Validate ',
                                           'SHIP_TO_LOCATION_CODE -'
                                        || site_rec.ship_to_location_code
                                        || ' does not Exists for Supplier Site Site '
                                        || site_rec.vendor_site_code,
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id,
                                        site_rec.vendor_site_code);
                                WHEN OTHERS
                                THEN
                                    lc_sup_site_err_flag   := 'Y';
                                    lc_sup_site_err_msg    :=
                                           lc_sup_site_err_msg
                                        || '\'
                                        || 'Supplier Site ShipTo Location Code Validation'
                                        || 'failed for the Lookup Code -'
                                        || site_rec.ship_to_location_code
                                        || ' for Supplier Site '
                                        || site_rec.vendor_site_code
                                        || ' Error no-'
                                        || SUBSTR (
                                               (SQLCODE || '-' || SQLERRM),
                                               1,
                                               100);

                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Site Conv Validate ',
                                           'Supplier Site ShipTo Location Code Validation'
                                        || 'failed for the Lookup Code -'
                                        || site_rec.ship_to_location_code
                                        || ' for Supplier Site '
                                        || site_rec.vendor_site_code
                                        || ' Error no-',
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id,
                                        site_rec.vendor_site_code);
                            END;
                        ELSE
                            NULL;
                        END IF;



                        IF site_rec.bill_to_location_code IS NOT NULL
                        THEN
                            BEGIN
                                /*   SELECT location_id
                                     INTO ln_site_bill_location_id
                                     FROM hr_locations_all
                                    WHERE UPPER (location_code) =
                                             UPPER (site_rec.bill_to_location_code); */
                                lc_bill_code   := NULL;

                                SELECT location_id, flv.description
                                  INTO ln_site_bill_location_id, lc_bill_code
                                  FROM hr_locations_all hla --Code modification on 05-MAR-2015
                                                           , fnd_lookup_values flv
                                 WHERE     UPPER (hla.location_code) =
                                           UPPER (flv.description)
                                       AND UPPER (flv.meaning) =
                                           UPPER (
                                               site_rec.bill_to_location_code)
                                       AND lookup_type =
                                           'XXDO_CONV_LOCATION_MAPPING'
                                       AND language = 'US';
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    lc_sup_site_err_flag   := 'Y';
                                    lc_sup_site_err_msg    :=
                                           lc_sup_site_err_msg
                                        || ' \ '
                                        || 'BILL_TO_LOCATION_CODE -'
                                        || site_rec.bill_to_location_code
                                        || ' does not Exists for Supplier Site '
                                        || site_rec.vendor_site_code;

                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Site Conv Validate ',
                                           'BILL_TO_LOCATION_CODE -'
                                        || site_rec.bill_to_location_code
                                        || ' does not Exists for Supplier Site '
                                        || site_rec.vendor_site_code,
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id,
                                        site_rec.vendor_site_code);
                                WHEN OTHERS
                                THEN
                                    lc_sup_site_err_flag   := 'Y';
                                    lc_sup_site_err_msg    :=
                                           lc_sup_site_err_msg
                                        || '\'
                                        || 'Supplier Site BillTo Location Code Validation'
                                        || 'failed for the Lookup Code -'
                                        || site_rec.bill_to_location_code
                                        || ' for Supplier Site '
                                        || site_rec.vendor_site_code
                                        || ' Error no-'
                                        || SUBSTR (
                                               (SQLCODE || '-' || SQLERRM),
                                               1,
                                               100);

                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Site Conv Validate ',
                                           'Supplier Site BillTo Location Code Validation'
                                        || 'failed for the Lookup Code -'
                                        || site_rec.bill_to_location_code
                                        || ' for Supplier Site '
                                        || site_rec.vendor_site_code
                                        || ' Error no-'
                                        || SUBSTR (
                                               (SQLCODE || '-' || SQLERRM),
                                               1,
                                               100),
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id,
                                        site_rec.vendor_site_code);
                            END;
                        ELSE
                            NULL;
                        END IF;



                        IF site_rec.ship_via_lookup_code IS NOT NULL
                        THEN
                            BEGIN
                                SELECT DISTINCT 'Y'
                                  INTO lc_site_ship_via
                                  FROM fnd_lookup_values flv, wsh_carrier_ship_methods wcsm
                                 WHERE     flv.lookup_code =
                                           wcsm.ship_method_code
                                       AND flv.lookup_type = 'SHIP_METHOD'
                                       AND end_date_active IS NULL
                                       AND UPPER (wcsm.freight_code) =
                                           UPPER (
                                               site_rec.ship_via_lookup_code)
                                       AND wcsm.enabled_flag = 'Y';
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    lc_sup_site_err_flag   := 'Y';
                                    lc_sup_site_err_msg    :=
                                           lc_sup_site_err_msg
                                        || ' \ '
                                        || 'SHIP_VIA_LOOKUP_CODE -'
                                        || site_rec.ship_via_lookup_code
                                        || ' does not Exists for Supplier Site '
                                        || site_rec.vendor_site_code;

                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Site Conv Validate ',
                                           'SHIP_VIA_LOOKUP_CODE -'
                                        || site_rec.ship_via_lookup_code
                                        || ' does not Exists for Supplier Site '
                                        || site_rec.vendor_site_code,
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id,
                                        site_rec.vendor_site_code);
                                WHEN OTHERS
                                THEN
                                    lc_sup_site_err_flag   := 'Y';
                                    lc_sup_site_err_msg    :=
                                           lc_sup_site_err_msg
                                        || '\'
                                        || 'Supplier Site SHIP_VIA_LOOKUP_CODE Validation'
                                        || 'failed for the Lookup Code -'
                                        || site_rec.ship_via_lookup_code
                                        || ' for Supplier Site '
                                        || site_rec.vendor_site_code
                                        || ' Error no-'
                                        || SUBSTR (
                                               (SQLCODE || '-' || SQLERRM),
                                               1,
                                               100);


                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Site Conv Validate ',
                                           'Supplier Site SHIP_VIA_LOOKUP_CODE Validation'
                                        || 'failed for the Lookup Code -'
                                        || site_rec.ship_via_lookup_code
                                        || ' for Supplier Site '
                                        || site_rec.vendor_site_code
                                        || ' Error no-'
                                        || SUBSTR (
                                               (SQLCODE || '-' || SQLERRM),
                                               1,
                                               100),
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id,
                                        site_rec.vendor_site_code);
                            END;
                        ELSE
                            NULL;
                        END IF;



                        IF site_rec.freight_terms_lookup_code IS NOT NULL
                        THEN
                            BEGIN
                                SELECT lookup_code
                                  INTO lc_site_freight_term
                                  FROM fnd_lookup_values_vl
                                 WHERE     UPPER (lookup_code) =
                                           UPPER (
                                               site_rec.freight_terms_lookup_code)
                                       AND lookup_type = 'FREIGHT TERMS'
                                       AND end_date_active IS NULL;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    lc_sup_site_err_flag   := 'Y';
                                    lc_sup_site_err_msg    :=
                                           lc_sup_site_err_msg
                                        || ' \ '
                                        || 'FREIGHT_TERMS_LOOKUP_CODE  -'
                                        || site_rec.freight_terms_lookup_code
                                        || ' does not Exists for Supplier Site '
                                        || site_rec.vendor_site_code;

                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Site Conv Validate ',
                                           'FREIGHT_TERMS_LOOKUP_CODE  -'
                                        || site_rec.freight_terms_lookup_code
                                        || ' does not Exists for Supplier Site '
                                        || site_rec.vendor_site_code,
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id,
                                        site_rec.vendor_site_code);
                                WHEN OTHERS
                                THEN
                                    lc_sup_site_err_flag   := 'Y';
                                    lc_sup_site_err_msg    :=
                                           lc_sup_site_err_msg
                                        || '\'
                                        || 'Supplier Site FREIGHT_TERMS_LOOKUP_CODE  Validation'
                                        || 'failed for the Lookup Code -'
                                        || site_rec.freight_terms_lookup_code
                                        || ' for Supplier Site '
                                        || site_rec.vendor_site_code
                                        || ' Error no-'
                                        || SUBSTR (
                                               (SQLCODE || '-' || SQLERRM),
                                               1,
                                               100);

                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Site Conv Validate ',
                                           'Supplier Site FREIGHT_TERMS_LOOKUP_CODE  Validation'
                                        || 'failed for the Lookup Code -'
                                        || site_rec.freight_terms_lookup_code
                                        || ' for Supplier Site '
                                        || site_rec.vendor_site_code
                                        || ' Error no-'
                                        || SUBSTR (
                                               (SQLCODE || '-' || SQLERRM),
                                               1,
                                               100),
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id,
                                        site_rec.vendor_site_code);
                            END;
                        ELSE
                            NULL;
                        END IF;



                        IF site_rec.fob_lookup_code IS NOT NULL
                        THEN
                            BEGIN
                                SELECT lookup_code
                                  INTO lc_site_fob
                                  FROM fnd_lookup_values_vl
                                 WHERE     UPPER (lookup_code) =
                                           UPPER (site_rec.fob_lookup_code)
                                       AND lookup_type = 'FOB'
                                       AND end_date_active IS NULL
                                       AND view_application_id = 201;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    lc_sup_site_err_flag   := 'Y';
                                    lc_sup_site_err_msg    :=
                                           lc_sup_site_err_msg
                                        || ' \ '
                                        || 'FOB_LOOKUP_CODE   -'
                                        || site_rec.fob_lookup_code
                                        || ' does not Exists for Supplier Site '
                                        || site_rec.vendor_site_code;

                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Site Conv Validate ',
                                           'FOB_LOOKUP_CODE   -'
                                        || site_rec.fob_lookup_code
                                        || ' does not Exists for Supplier Site '
                                        || site_rec.vendor_site_code,
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id,
                                        site_rec.vendor_site_code);
                                WHEN OTHERS
                                THEN
                                    lc_sup_site_err_flag   := 'Y';
                                    lc_sup_site_err_msg    :=
                                           lc_sup_site_err_msg
                                        || '\'
                                        || 'Supplier Site FOB_LOOKUP_CODE   Validation'
                                        || 'failed for the Lookup Code -'
                                        || site_rec.fob_lookup_code
                                        || ' for Supplier Site '
                                        || site_rec.vendor_site_code
                                        || ' Error no-'
                                        || SUBSTR (
                                               (SQLCODE || '-' || SQLERRM),
                                               1,
                                               100);

                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Site Conv Validate ',
                                           'Supplier Site FOB_LOOKUP_CODE   Validation'
                                        || 'failed for the Lookup Code -'
                                        || site_rec.fob_lookup_code
                                        || ' for Supplier Site '
                                        || site_rec.vendor_site_code
                                        || ' Error no-'
                                        || SUBSTR (
                                               (SQLCODE || '-' || SQLERRM),
                                               1,
                                               100),
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id,
                                        site_rec.vendor_site_code);
                            END;
                        ELSE
                            NULL;
                        END IF;



                        IF site_rec.terms_name IS NOT NULL
                        THEN
                            BEGIN
                                SELECT term_id
                                  INTO ln_term_id
                                  FROM ap_terms
                                 WHERE UPPER (NAME) =
                                       UPPER (site_rec.terms_name);
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    lc_sup_site_err_flag   := 'Y';
                                    lc_sup_site_err_msg    :=
                                           lc_sup_site_err_msg
                                        || ' \ '
                                        || 'TERMS_NAME   -'
                                        || site_rec.terms_name
                                        || ' does not Exists for Supplier Site '
                                        || site_rec.vendor_site_code;

                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Site Conv Validate ',
                                           'TERMS_NAME   -'
                                        || site_rec.terms_name
                                        || ' does not Exists for Supplier Site '
                                        || site_rec.vendor_site_code,
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id,
                                        site_rec.vendor_site_code);
                                WHEN OTHERS
                                THEN
                                    lc_sup_site_err_flag   := 'Y';
                                    lc_sup_site_err_msg    :=
                                           lc_sup_site_err_msg
                                        || '\'
                                        || 'Supplier Site TERMS_NAME   Validation'
                                        || 'failed for the Term -'
                                        || site_rec.terms_name
                                        || ' for Supplier Site '
                                        || site_rec.vendor_site_code
                                        || ' Error no-'
                                        || SUBSTR (
                                               (SQLCODE || '-' || SQLERRM),
                                               1,
                                               100);

                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Site Conv Validate ',
                                           'Supplier Site TERMS_NAME   Validation'
                                        || 'failed for the Term -'
                                        || site_rec.terms_name
                                        || ' for Supplier Site '
                                        || site_rec.vendor_site_code
                                        || ' Error no-'
                                        || SUBSTR (
                                               (SQLCODE || '-' || SQLERRM),
                                               1,
                                               100),
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id,
                                        site_rec.vendor_site_code);
                            END;
                        ELSE
                            NULL;
                        END IF;



                        IF site_rec.payment_method_lookup_code IS NOT NULL
                        THEN
                            OPEN get_payment_method_c (
                                site_rec.payment_method_lookup_code);

                            lc_pay_method_code   := NULL;

                            FETCH get_payment_method_c
                                INTO lc_pay_method_code;

                            CLOSE get_payment_method_c;

                            IF lc_pay_method_code IS NULL
                            THEN
                                BEGIN
                                    SELECT payment_method_code
                                      INTO lc_pay_method_code
                                      FROM iby_payment_methods_vl --FND_LOOKUP_VALUES_vl
                                     WHERE     UPPER (payment_method_code) =
                                               UPPER (
                                                   site_rec.payment_method_lookup_code)
                                           AND inactive_date IS NULL;
                                EXCEPTION
                                    WHEN NO_DATA_FOUND
                                    THEN
                                        lc_sup_site_err_flag   := 'Y';
                                        lc_sup_site_err_msg    :=
                                               lc_sup_site_err_msg
                                            || ' \ '
                                            || 'PAYMENT_METHOD_LOOKUP_CODE    -'
                                            || site_rec.payment_method_lookup_code
                                            || ' does not Exists for Supplier Site '
                                            || site_rec.vendor_site_code;

                                        xxd_common_utils.record_error (
                                            'AP',
                                            xxd_common_utils.get_org_id,
                                            'XXD AP Supplier Site Conv Validate ',
                                               'PAYMENT_METHOD_LOOKUP_CODE    -'
                                            || site_rec.payment_method_lookup_code
                                            || ' does not Exists for Supplier Site '
                                            || site_rec.vendor_site_code,
                                            DBMS_UTILITY.format_error_backtrace,
                                            fnd_profile.VALUE ('USER_ID'),
                                            gn_conc_request_id,
                                            sup_rec.segment1,
                                            sup_rec.old_vendor_id,
                                            site_rec.vendor_site_code);
                                    WHEN OTHERS
                                    THEN
                                        lc_sup_site_err_flag   := 'Y';
                                        lc_sup_site_err_msg    :=
                                               lc_sup_site_err_msg
                                            || '\'
                                            || 'Supplier Site PAYMENT_METHOD_LOOKUP_CODE Validation'
                                            || 'failed for the Lookup Code -'
                                            || site_rec.payment_method_lookup_code
                                            || ' for Supplier Site '
                                            || site_rec.vendor_site_code
                                            || ' Error no-'
                                            || SUBSTR (
                                                   (SQLCODE || '-' || SQLERRM),
                                                   1,
                                                   100);

                                        xxd_common_utils.record_error (
                                            'AP',
                                            xxd_common_utils.get_org_id,
                                            'XXD AP Supplier Site Conv Validate ',
                                               'Supplier Site PAYMENT_METHOD_LOOKUP_CODE Validation'
                                            || 'failed for the Lookup Code -'
                                            || site_rec.payment_method_lookup_code
                                            || ' for Supplier Site '
                                            || site_rec.vendor_site_code
                                            || ' Error no-'
                                            || SUBSTR (
                                                   (SQLCODE || '-' || SQLERRM),
                                                   1,
                                                   100),
                                            DBMS_UTILITY.format_error_backtrace,
                                            fnd_profile.VALUE ('USER_ID'),
                                            gn_conc_request_id,
                                            sup_rec.segment1,
                                            sup_rec.old_vendor_id,
                                            site_rec.vendor_site_code);
                                END;
                            END IF;
                        ELSE
                            NULL;
                        END IF;

                        --IF site_rec.payment_method_lookup_code--Start Modified on 07-Apr-2015 by Srinivas



                        IF site_rec.distribution_set_name IS NOT NULL
                        THEN
                            BEGIN
                                lc_distribut_set_name   := NULL;

                                SELECT distribution_set_name
                                  INTO lc_distribut_set_name
                                  FROM ap_distribution_sets_all
                                 WHERE UPPER (distribution_set_name) =
                                       UPPER (site_rec.distribution_set_name);
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    lc_distribut_set_name   := NULL;
                                WHEN OTHERS
                                THEN
                                    lc_sup_site_err_flag   := 'Y';
                                    lc_sup_site_err_msg    :=
                                           lc_sup_site_err_msg
                                        || '\'
                                        || 'Supplier Site DISTRIBUTION_SET_NAME Validation'
                                        || 'failed for the Lookup Code -'
                                        || site_rec.distribution_set_name
                                        || ' for Supplier Site '
                                        || site_rec.vendor_site_code
                                        || ' Error no-'
                                        || SUBSTR (
                                               (SQLCODE || '-' || SQLERRM),
                                               1,
                                               100);

                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Site Conv Validate ',
                                           'Supplier Site DISTRIBUTION_SET_NAME Validation'
                                        || 'failed for the Lookup Code -'
                                        || site_rec.distribution_set_name
                                        || ' for Supplier Site '
                                        || site_rec.vendor_site_code
                                        || ' Error no-'
                                        || SUBSTR (
                                               (SQLCODE || '-' || SQLERRM),
                                               1,
                                               100),
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id,
                                        site_rec.vendor_site_code);
                            END;
                        ELSE
                            NULL;
                        END IF;

                        --End Modified on 07-Apr-2015 by Srinivas

                        IF site_rec.tolerance_name IS NOT NULL
                        THEN
                            BEGIN
                                SELECT tolerance_name
                                  INTO lc_tolerance_name
                                  FROM ap_tolerances at, fnd_lookup_values flv --, ap_tolerances ats
                                 WHERE     flv.lookup_type =
                                           'XXDO_CONV_TOLERANCE_MAPPING'
                                       AND UPPER (flv.meaning) =
                                           UPPER (site_rec.tolerance_name)
                                       AND UPPER (at.tolerance_name) =
                                           UPPER (flv.Description)
                                       AND language = 'US';
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    BEGIN
                                        SELECT tolerance_name
                                          INTO lc_tolerance_name
                                          FROM ap_tolerances
                                         WHERE UPPER (tolerance_name) =
                                               UPPER (
                                                   site_rec.tolerance_name);
                                    EXCEPTION
                                        WHEN NO_DATA_FOUND
                                        THEN
                                            lc_sup_site_err_flag   := 'Y';
                                            lc_sup_site_err_msg    :=
                                                   lc_sup_site_err_msg
                                                || ' \ '
                                                || 'TOLERANCE_NAME   -'
                                                || site_rec.tolerance_name
                                                || ' does not Exists for Supplier Site '
                                                || site_rec.vendor_site_code;

                                            xxd_common_utils.record_error (
                                                'AP',
                                                xxd_common_utils.get_org_id,
                                                'XXD AP Supplier Site Conv Validate ',
                                                   'TOLERANCE_NAME   -'
                                                || site_rec.tolerance_name
                                                || ' does not Exists for Supplier Site '
                                                || site_rec.vendor_site_code,
                                                DBMS_UTILITY.format_error_backtrace,
                                                fnd_profile.VALUE ('USER_ID'),
                                                gn_conc_request_id,
                                                sup_rec.segment1,
                                                sup_rec.old_vendor_id,
                                                site_rec.vendor_site_code);
                                    END;
                                WHEN OTHERS
                                THEN
                                    lc_sup_site_err_flag   := 'Y';
                                    lc_sup_site_err_msg    :=
                                           lc_sup_site_err_msg
                                        || '\'
                                        || 'Supplier Site TOLERANCE_NAME Validation'
                                        || 'failed - '
                                        || site_rec.tolerance_name
                                        || ' for Supplier Site '
                                        || site_rec.vendor_site_code
                                        || ' Error no-'
                                        || SUBSTR (
                                               (SQLCODE || '-' || SQLERRM),
                                               1,
                                               100);

                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Site Conv Validate ',
                                           'Supplier Site TOLERANCE_NAME Validation'
                                        || 'failed - '
                                        || site_rec.tolerance_name
                                        || ' for Supplier Site '
                                        || site_rec.vendor_site_code
                                        || ' Error no-'
                                        || SUBSTR (
                                               (SQLCODE || '-' || SQLERRM),
                                               1,
                                               100),
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_rec.segment1,
                                        sup_rec.old_vendor_id,
                                        site_rec.vendor_site_code);
                            END;
                        ELSE
                            NULL;
                        END IF;

                        IF site_rec.old_operating_unit_name IS NOT NULL
                        THEN
                            lc_new_ou   := NULL;
                            ln_org_id   := NULL;
                            GET_ORG_ID (site_rec.old_operating_unit_name,
                                        ln_org_id,
                                        lc_new_ou);

                            IF ln_org_id IS NULL
                            THEN
                                lc_new_ou              := NULL;
                                ln_org_id              := NULL;
                                log_records (
                                    p_debug,
                                       'NO_DATA_FOUND- New OU/OU_ID Validation '
                                    || site_rec.old_operating_unit_name);

                                lc_sup_site_err_flag   := 'Y';
                                lc_sup_site_err_msg    :=
                                       lc_sup_site_err_msg
                                    || ' \ '
                                    || 'Mapping is not avaiable for the OLD OU  -'
                                    || site_rec.old_operating_unit_name
                                    || site_rec.vendor_site_code;

                                xxd_common_utils.record_error (
                                    'AP',
                                    xxd_common_utils.get_org_id,
                                    'XXD AP Supplier Site Conv Validate ',
                                       'Mapping is not avaiable for the OLD OU  - '
                                    || site_rec.old_operating_unit_name,
                                    DBMS_UTILITY.format_error_backtrace,
                                    fnd_profile.VALUE ('USER_ID'),
                                    gn_conc_request_id,
                                    sup_rec.segment1,
                                    sup_rec.old_vendor_id,
                                    site_rec.vendor_site_code);
                            END IF;
                        END IF;



                        lc_pay_method_code         := NULL;

                        --Modified on 15=APr-2015
                        OPEN Get_bank_account_c (sup_rec.old_vendor_id);

                        lc_bank_account_num        := NULL;

                        FETCH Get_bank_account_c INTO lc_bank_account_num;

                        CLOSE Get_bank_account_c;

                        OPEN get_site_bank_account_c (
                            sup_rec.old_vendor_id,
                            site_rec.vendor_site_code);

                        lc_site_bank_account_num   := NULL;

                        FETCH get_site_bank_account_c
                            INTO lc_site_bank_account_num;

                        CLOSE get_site_bank_account_c;

                        IF    lc_bank_account_num IS NOT NULL
                           OR lc_site_bank_account_num IS NOT NULL
                        THEN
                            fnd_file.put_line (fnd_file.LOG, 'Test1');
                            lc_pay_method_code   := 'EFT';
                        ELSE
                            /*  OPEN get_payment_method_c(sup_rec.PAYMENT_METHOD_LOOKUP_CODE);

                              lc_desc := NULL;

                              FETCH get_payment_method_c INTO lc_desc;

                              CLOSE get_payment_method_c;

                              IF lc_desc = 'Electronic'
                              THEN
                                 lc_PAYMENT_METHOD_LOOKUP_CODE := 'EFT';

                              END IF; */

                            IF site_rec.PAYMENT_METHOD_LOOKUP_CODE = 'WIRE'
                            THEN
                                lc_pay_method_code   := 'WIRE';
                            ELSIF site_rec.PAYMENT_METHOD_LOOKUP_CODE =
                                  'CHECK'
                            THEN
                                lc_pay_method_code       := 'CHECK';
                                lc_site_pay_group_code   := 'CHECK';
                            ELSIF site_rec.PAYMENT_METHOD_LOOKUP_CODE IS NULL
                            THEN
                                lc_pay_method_code   :=
                                    lc_PAYMENT_METHOD_LOOKUP_CODE;

                                IF lc_pay_method_code = 'CHECK'
                                THEN
                                    lc_site_pay_group_code   := 'CHECK';
                                END IF;
                            ELSE
                                OPEN get_payment_method_c (
                                    site_rec.PAYMENT_METHOD_LOOKUP_CODE);

                                lc_pay_method_code   := NULL;

                                FETCH get_payment_method_c
                                    INTO lc_pay_method_code;

                                CLOSE get_payment_method_c;
                            END IF;
                        END IF;


                        -- Changes by BT Team on 4/25/15
                        --                  IF lc_pay_method_code <> 'CHECK'
                        IF NVL (lc_pay_method_code, 'X') <> 'CHECK'
                        -- End of changes by BT Team on 4/25/15
                        THEN                         --Modified on 15-Apr-2015
                            --Pay group Logic



                            OPEN get_country_c (ln_org_id);

                            FETCH get_country_c INTO lc_country;

                            CLOSE get_country_c;

                            fnd_file.put_line (fnd_file.LOG,
                                               'Country ' || lc_country);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Site Country ' || site_rec.country);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Site code ' || site_rec.vendor_site_code);


                            IF lc_country = site_rec.country
                            THEN
                                OPEN get_pay_grp_c (lc_country, 'DOMESTIC');

                                lc_site_pay_group_code   := NULL;

                                FETCH get_pay_grp_c
                                    INTO lc_site_pay_group_code;

                                CLOSE get_pay_grp_c;
                            ELSE
                                OPEN get_euro_country_c (site_rec.country);

                                lc_LOOKUP_CODE   := NULL;

                                FETCH get_euro_country_c INTO lc_LOOKUP_CODE;

                                CLOSE get_euro_country_c;

                                IF lc_LOOKUP_CODE IS NOT NULL
                                THEN
                                    OPEN get_pay_grp_c (lc_country, 'EURO');

                                    lc_paygrp   := NULL;

                                    FETCH get_pay_grp_c
                                        INTO lc_site_pay_group_code;

                                    CLOSE get_pay_grp_c;

                                    IF lc_paygrp IS NULL
                                    THEN
                                        OPEN get_pay_grp_c (lc_country,
                                                            'FOREIGN');

                                        lc_paygrp   := NULL;

                                        FETCH get_pay_grp_c
                                            INTO lc_site_pay_group_code;

                                        CLOSE get_pay_grp_c;
                                    END IF;
                                ELSE
                                    OPEN get_pay_grp_c (lc_country,
                                                        'FOREIGN');

                                    lc_paygrp   := NULL;

                                    FETCH get_pay_grp_c
                                        INTO lc_site_pay_group_code;

                                    CLOSE get_pay_grp_c;
                                END IF;
                            END IF;

                            site_rec.pay_group_lookup_code   :=
                                lc_site_pay_group_code;
                        END IF;


                        OPEN get_attribute4 (sup_rec.SEGMENT1,
                                             site_rec.vendor_site_code);

                        lc1_attribute4             := NULL;

                        FETCH get_attribute4 INTO lc1_attribute4;

                        CLOSE Get_attribute4;

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'lc1_attribute4 ' || lc1_attribute4);

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'lc_paygrp ' || lc_site_pay_group_code);

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'OPERATING_UNIT_NAME ' || site_rec.OLD_OPERATING_UNIT_NAME);



                        fnd_file.put_line (
                            fnd_file.LOG,
                            'pay_group_lookup_code ' || site_rec.pay_group_lookup_code);

                        --Modified on 13-APR-2015
                        /*        IF site_rec.pay_group_lookup_code IS NOT NULL
                                --          IF lc_paygrp IS NOT NULL
                                THEN
                                   BEGIN
                                      SELECT lookup_code
                                        INTO lc_site_pay_group_code
                                        FROM fnd_lookup_values_vl
                                       WHERE     UPPER (lookup_code) =
                                                    UPPER (site_rec.pay_group_lookup_code)
                                             AND lookup_type = 'PAY GROUP'
                                             AND end_date_active IS NULL;
                                   EXCEPTION
                                      WHEN NO_DATA_FOUND
                                      THEN
                                         BEGIN
                                            SELECT lookup_code
                                              INTO lc_site_pay_group_code
                                              FROM fnd_lookup_values_vl
                                             WHERE     lookup_type = 'PAY GROUP'
                                                   AND end_date_active IS NULL
                                                   AND lookup_code =
                                                          site_rec.pay_group_lookup_code;
                                         EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                               lc_sup_site_err_flag := 'Y';
                                               lc_sup_site_err_msg :=
                                                     lc_sup_site_err_msg
                                                  || ' \ '
                                                  || 'PAY_GROUP_LOOKUP_CODE    -'
                                                  || site_rec.pay_group_lookup_code
                                                  || ' does not Exists for Supplier Site '
                                                  || site_rec.vendor_site_code;

                                               xxd_common_utils.record_error (
                                                  'AP',
                                                  xxd_common_utils.get_org_id,
                                                  'XXD AP Supplier Site Conv Validate ',
                                                     'PAY_GROUP_LOOKUP_CODE    -'
                                                  || site_rec.pay_group_lookup_code
                                                  || ' does not Exists for Supplier Site '
                                                  || site_rec.vendor_site_code,
                                                  DBMS_UTILITY.format_error_backtrace,
                                                  fnd_profile.VALUE ('USER_ID'),
                                                  gn_conc_request_id,
                                                  sup_rec.segment1,
                                                  sup_rec.old_vendor_id,
                                                  site_rec.vendor_site_code);
                                         END;
                                      WHEN OTHERS
                                      THEN
                                         lc_sup_site_err_flag := 'Y';
                                         lc_sup_site_err_msg :=
                                               lc_sup_site_err_msg
                                            || '\'
                                            || 'Supplier Site PAY_GROUP_LOOKUP_CODE Validation'
                                            || 'failed for the Lookup Code -'
                                            || site_rec.pay_group_lookup_code
                                            || ' for Supplier Site '
                                            || site_rec.vendor_site_code
                                            || ' Error no-'
                                            || SUBSTR ( (SQLCODE || '-' || SQLERRM),
                                                       1,
                                                       100);

                                         xxd_common_utils.record_error (
                                            'AP',
                                            xxd_common_utils.get_org_id,
                                            'XXD AP Supplier Site Conv Validate ',
                                               'Supplier Site PAY_GROUP_LOOKUP_CODE Validation'
                                            || 'failed for the Lookup Code -'
                                            || site_rec.pay_group_lookup_code
                                            || ' for Supplier Site '
                                            || site_rec.vendor_site_code
                                            || ' Error no-'
                                            || SUBSTR ( (SQLCODE || '-' || SQLERRM),
                                                       1,
                                                       100),
                                            DBMS_UTILITY.format_error_backtrace,
                                            fnd_profile.VALUE ('USER_ID'),
                                            gn_conc_request_id,
                                            sup_rec.segment1,
                                            sup_rec.old_vendor_id,
                                            site_rec.vendor_site_code);
                                   END;
                                ELSE
                                   NULL;
                                END IF; */

                        /* IF site_rec.pay_group_lookup_code = 'COMMISSIONS'
                         THEN
                            lc_pay_method_code := 'Commissions';
                         END IF; */

                        --End Modified on 13-APR-2015


                        fnd_file.put_line (
                            fnd_file.LOG,
                            'pay_group_lookup_code ' || site_rec.pay_group_lookup_code);

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'attribute2 ' || sup_rec.attribute2);

                        /*   IF sup_rec.attribute2 = 'Y'
                           THEN
                              lc_pay_method_code := site_rec.PAYMENT_METHOD_LOOKUP_CODE;
                              lc_site_pay_group_code := site_rec.pay_group_lookup_code;
                           END IF;*/

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'lc_sup_site_err_flag ' || lc_sup_site_err_flag);

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'lc_supp_err_flag ' || lc_supp_err_flag);

                        IF     site_rec.PAYMENT_METHOD_LOOKUP_CODE IS NULL
                           AND NVL (lc_pay_method_code, 'XX') =
                               NVL (lc_PAYMENT_METHOD_LOOKUP_CODE, 'XX')
                        THEN
                            lc_pay_method_code   := NULL;
                        END IF;

                        IF site_rec.pay_group_lookup_code = 'COMMISSIONS'
                        THEN
                            lc_PAYMENT_METHOD_LOOKUP_CODE   := 'Commissions';
                        END IF;

                        ------------------------------------------
                        -- Supplier Sites Validation Ends
                        IF    NVL (lc_sup_site_err_flag, 'N') = 'Y'
                           OR NVL (lc_supp_err_flag, 'N') = 'Y'
                        THEN
                            UPDATE xxd_ap_sup_sites_cnv_stg_t
                               SET record_status = 'E', error_message = error_message || SUBSTR (lc_sup_site_err_msg, 1, 1000), last_update_login = fnd_global.login_id,
                                   creation_date = SYSDATE, created_by = fnd_global.user_id, last_update_date = SYSDATE,
                                   pay_group_lookup_code = lc_site_pay_group_code, PAYMENT_METHOD_LOOKUP_CODE = lc_pay_method_code, last_updated_by = fnd_global.user_id,
                                   request_id = gn_conc_request_id
                             WHERE     old_vendor_id = site_rec.old_vendor_id
                                   AND old_vendor_site_id =
                                       site_rec.old_vendor_site_id;

                            gn_site_rejected   := gn_site_rejected + 1;

                            UPDATE xxd_conv.xxd_ap_sup_site_con_cnv_stg_t
                               SET record_status = 'E', error_message = 'Validation Failed in Sites', last_update_login = fnd_global.login_id,
                                   last_update_date = SYSDATE, --pay_group_lookup_code = lc_site_pay_group_code,
                                                               --PAYMENT_METHOD_LOOKUP_CODE = lc_pay_method_code,
                                                               last_updated_by = fnd_global.user_id, request_id = gn_conc_request_id
                             WHERE     old_vendor_site_id =
                                       site_rec.old_vendor_site_id
                                   AND vendor_site_code =
                                       site_rec.vendor_site_code;

                            UPDATE xxd_ap_suppliers_cnv_stg_t
                               SET record_status = 'E', error_message = 'Validation Failed in Sites', last_update_login = fnd_global.login_id,
                                   last_update_date = SYSDATE, pay_group_lookup_code = lc_site_pay_group_code, PAYMENT_METHOD_LOOKUP_CODE = lc_pay_method_code,
                                   last_updated_by = fnd_global.user_id, request_id = gn_conc_request_id
                             WHERE     old_vendor_id = site_rec.old_vendor_id
                                   AND record_status = 'V';
                        ELSE
                            UPDATE xxd_ap_sup_sites_cnv_stg_t
                               SET record_status = 'V', error_message = NULL, tolerance_name = lc_tolerance_name,
                                   pay_group_lookup_code = lc_site_pay_group_code, last_update_login = fnd_global.login_id, PAYMENT_METHOD_LOOKUP_CODE = lc_pay_method_code,
                                   last_update_date = SYSDATE, last_updated_by = fnd_global.user_id, request_id = gn_conc_request_id,
                                   new_operating_unit_name = lc_new_ou, -- Added on 4/23
                                                                        distribution_set_name = lc_distribut_set_name, -- End of addition on 4/23
                                                                                                                       --attribute4 = lc1_attribute4,
                                                                                                                       attribute5 = lc1_attribute4,
                                   BILL_TO_LOCATION_code = lc_bill_code, ship_TO_LOCATION_code = lc_ship_code, org_id = ln_org_id
                             WHERE old_vendor_site_id =
                                   site_rec.old_vendor_site_id;


                            /*      IF sup_rec.attribute2 = 'N'
                                THEN

                                UPDATE xxd_ap_sup_sites_cnv_stg_t set pay_group_lookup_code = 'CHECK'
                                 where PAYMENT_METHOD_LOOKUP_CODE = 'CHECK';

                                 END IF; */



                            gn_site_processed   := gn_site_processed + 1;
                        END IF;
                    END LOOP;
                END LOOP;

                -- Bank Loop Starts
                --------------------------------
                FOR site_bank_rec IN c_bank
                LOOP
                    lc_site_bank_country_code   := NULL;
                    lc_site_bank_exists         := NULL;
                    lc_site_bank_err            := NULL;
                    lc_site_bank_err_details    := NULL;

                    IF site_bank_rec.country IS NOT NULL
                    THEN
                        BEGIN
                            SELECT territory_code
                              INTO lc_site_bank_country_code
                              FROM fnd_territories_vl
                             WHERE UPPER (territory_code) =
                                   UPPER (site_bank_rec.country);
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lc_site_bank_err   := 'Y';
                                lc_site_bank_err_details   :=
                                       lc_site_bank_err_details
                                    || '\ '
                                    || 'Country for Supplier Not Defined- '
                                    || site_bank_rec.payee_name
                                    || '/'
                                    || site_bank_rec.country;

                                xxd_common_utils.record_error (
                                    'AP',
                                    xxd_common_utils.get_org_id,
                                    'XXD AP Supplier Bank Conv Validate ',
                                       'Country for Supplier Not Defined- '
                                    || site_bank_rec.payee_name
                                    || '/'
                                    || site_bank_rec.country,
                                    DBMS_UTILITY.format_error_backtrace,
                                    fnd_profile.VALUE ('USER_ID'),
                                    gn_conc_request_id,
                                    site_bank_rec.bank_account_num,
                                    site_bank_rec.old_vendor_id,
                                    site_bank_rec.vendor_site_code,
                                    NULL);
                            WHEN OTHERS
                            THEN
                                lc_site_bank_err   := 'Y';
                                lc_site_bank_err_details   :=
                                       lc_site_bank_err_details
                                    || '\ '
                                    || 'Country Exception failed in Supplier Site Bank assigment '
                                    || 'for Supplier Site- '
                                    || site_bank_rec.vendor_site_code
                                    || '/'
                                    || site_bank_rec.country
                                    || ' Error no -'
                                    || SUBSTR (SQLERRM, 1, 100);

                                xxd_common_utils.record_error (
                                    'AP',
                                    xxd_common_utils.get_org_id,
                                    'XXD AP Supplier Bank Conv Validate ',
                                       'Country Exception failed in Supplier Site Bank assigment '
                                    || 'for Supplier Site- '
                                    || site_bank_rec.vendor_site_code
                                    || '/'
                                    || site_bank_rec.country
                                    || ' Error no -'
                                    || SUBSTR (SQLERRM, 1, 100),
                                    DBMS_UTILITY.format_error_backtrace,
                                    fnd_profile.VALUE ('USER_ID'),
                                    gn_conc_request_id,
                                    site_bank_rec.bank_account_num,
                                    site_bank_rec.old_vendor_id,
                                    site_bank_rec.vendor_site_code,
                                    NULL);
                        END;
                    ELSE
                        log_records (
                            p_debug,
                               'Country Code is null for Supplier - '
                            || site_bank_rec.vendor_site_code
                            || ' and OLD_VEND_SITE_ID- '
                            || site_bank_rec.old_vendor_id);

                        xxd_common_utils.record_error (
                            'AP',
                            xxd_common_utils.get_org_id,
                            'XXD AP Supplier Bank Conv Validate ',
                               'Country Code is null for Supplier - '
                            || site_bank_rec.vendor_site_code
                            || ' and OLD_VEND_SITE_ID- '
                            || site_bank_rec.old_vendor_id,
                            DBMS_UTILITY.format_error_backtrace,
                            fnd_profile.VALUE ('USER_ID'),
                            gn_conc_request_id,
                            site_bank_rec.bank_account_num,
                            site_bank_rec.old_vendor_id,
                            site_bank_rec.vendor_site_code,
                            NULL);
                    END IF;

                    IF    NVL (lc_cont_err_flag, 'N') = 'Y'
                       OR NVL (lc_sup_site_err_flag, 'N') = 'Y'
                       OR NVL (lc_supp_err_flag, 'N') = 'Y'
                       OR NVL (lc_site_bank_err, 'N') = 'Y'
                    THEN
                        gn_sup_site_bank_rejected   :=
                            gn_sup_site_bank_rejected + 1;

                        UPDATE xxd_ap_sup_bank_cnv_stg_t
                           SET record_status = 'E', error_message = SUBSTR (lc_site_bank_err_details, 1, 1999), last_update_login = fnd_global.login_id,
                               last_update_date = SYSDATE, last_updated_by = fnd_global.user_id, request_id = gn_conc_request_id
                         WHERE old_vendor_id = site_bank_rec.old_vendor_id;

                        COMMIT;
                    ELSE
                        UPDATE xxd_ap_sup_bank_cnv_stg_t
                           SET record_status = 'V', error_message = NULL, last_update_login = fnd_global.login_id,
                               last_update_date = SYSDATE, last_updated_by = fnd_global.user_id, request_id = gn_conc_request_id
                         WHERE old_vendor_id = site_bank_rec.old_vendor_id;

                        gn_sup_site_bank_processed   :=
                            gn_sup_site_bank_processed + 1;
                    END IF;

                    COMMIT;
                END LOOP;

                ----------------------------------
                --Supplier Site bank Loop End
                BEGIN
                    UPDATE xxd_ap_suppliers_cnv_stg_t sup
                       SET record_status = 'V', error_message = NULL
                     WHERE     error_message LIKE '%Validation Failed in %'
                           AND EXISTS
                                   (SELECT 1
                                      FROM xxd_ap_sup_sites_cnv_stg_t site
                                     WHERE     site.old_vendor_id =
                                               sup.old_vendor_id
                                           AND site.record_status = 'V');

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        log_records (
                            p_debug,
                            'Error in updating the stage table.' || SQLERRM);
                END;

                /*    Commented By Sryeruv as below updation should be clinet specific
                    FOR i_dup_site_addresses IN c_dup_site_addresses
                    LOOP
                       FOR i_dup_site_add_sites IN
                          c_dup_site_add_sites
                                             (i_dup_site_addresses.old_vendor_id,
                                              i_dup_site_addresses.address_line1,
                                              i_dup_site_addresses.address_lines_alt,
                                              i_dup_site_addresses.address_line2,
                                              i_dup_site_addresses.address_line3,
                                              i_dup_site_addresses.city,
                                              i_dup_site_addresses.state,
                                              i_dup_site_addresses.zip,
                                              i_dup_site_addresses.country
                                             )
                       LOOP
                          BEGIN
                             UPDATE xxd_ap_sup_sites_cnv_stg_t
                                SET attribute8 = address_line1,
                                    address_line1 =
                                            vendor_site_code || ' - ' || address_line1
                              WHERE old_vendor_site_id =
                                               i_dup_site_add_sites.old_vendor_site_id;
                          EXCEPTION
                             WHEN OTHERS
                             THEN
                                log_records
                                   (p_debug,
                                       'Error in updating duplicate address for old vendor site id:'
                                    || i_dup_site_add_sites.old_vendor_site_id
                                    || ' - '
                                    || SQLERRM
                                   );
                          END;
                       END LOOP;
                    END LOOP;
                    */

                --Write into output of Validate Mode
                -----------------------------------------------------
                fnd_file.put_line (
                    fnd_file.output,
                    'XXD AP Supplier data Validate and Load program');
                fnd_file.put_line (
                    fnd_file.output,
                       'Run Date: '
                    || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
                fnd_file.put_line (fnd_file.output,
                                   'Executed By: ' || gc_user_name);
                fnd_file.put_line (fnd_file.output,
                                   'Process Mode: ' || gc_validate_only);
                fnd_file.put_line (fnd_file.output,
                                   'Instance Name: ' || gc_dbname);
                fnd_file.put_line (fnd_file.output, '');
            /*       fnd_file.put_line (fnd_file.output,
                                          RPAD ('S No.    Entity', 50)
                                       || RPAD ('Total_Records_Valid', 20)
                                       || RPAD ('Total_Records_Error', 20)
                                       || RPAD ('Total_Records', 20)
                                      );
                    fnd_file.put_line
                       (fnd_file.output,
                        RPAD
                           ('--------------------------------------------------------------------------------------------------------------------------',
                            120
                           )
                       );
                    fnd_file.put_line (fnd_file.output,
                                          RPAD ('1       Suppliers', 50)
                                       || RPAD (gn_supp_process, 20)
                                       || RPAD (gn_supp_reject, 20)
                                       || RPAD (gn_supplier_found, 20)
                                      );
                    fnd_file.put_line (fnd_file.output,
                                          RPAD ('2       Supplier Sites', 50)
                                       || RPAD (gn_site_processed, 20)
                                       || RPAD (gn_site_rejected, 20)
                                       || RPAD (gn_sites_found, 20)
                                      );
                    fnd_file.put_line (fnd_file.output,
                                          RPAD ('3       Supplier Contacts', 50)
                                       || RPAD (gn_contact_processed, 20)
                                       || RPAD (gn_contact_rejected, 20)
                                       || RPAD (gn_contacts_found, 20)
                                      );
                    fnd_file.put_line (fnd_file.output,
                                          RPAD ('3       Supplier Banks', 50)
                                       || RPAD (gn_sup_site_bank_processed, 20)
                                       || RPAD (gn_sup_site_bank_rejected, 20)
                                       || RPAD (gn_site_bank_found, 20)
                                      );
                   */
            END IF;
        ELSE        -- Rakesh -- If Validate 'AND' Load then remove this else.
            --begin
            --Count the Supplier/Sites/Contacts/Bank Records from Stagging Table for Loading
            -------------------------------------------------------------------------------
            SELECT COUNT (*)
              INTO gn_sup_found_l
              FROM xxd_ap_suppliers_cnv_stg_t
             WHERE record_status = 'V';

            SELECT COUNT (*)
              INTO gn_sites_found_l
              FROM xxd_ap_sup_sites_cnv_stg_t
             WHERE record_status = 'V';

            SELECT COUNT (*)
              INTO gn_cont_found_l
              FROM xxd_conv.xxd_ap_sup_site_con_cnv_stg_t
             WHERE record_status = 'V';

            SELECT COUNT (*)
              INTO gn_sup_bank_found_l
              FROM xxd_ap_suppliers_cnv_stg_t
             WHERE bank_record_status = 'V' AND record_status = 'V';

            gn_sup_reject_l              := 0;
            gn_supp_process_l            := 0;
            gn_supp_bank_reject_l        := 0;
            gn_supp_bank_process_l       := 0;
            gn_site_reject_l             := 0;
            gn_site_process_l            := 0;
            gn_contact_process_l         := 0;
            gn_contact_reject_l          := 0;
            gn_sup_site_bank_reject_l    := 0;
            gn_sup_site_bank_process_l   := 0;

            FOR sup_ins_rec IN sup_ins_cur
            LOOP
                lc_supp_err_flag     := NULL;
                lc_supp_err_msg      := NULL;
                ln_vendor_id         := NULL;
                ln_supplier_int_id   := NULL;

                fnd_file.put_line (fnd_file.LOG, 'Test1');

                BEGIN
                    SELECT vendor_id
                      INTO ln_vendor_id
                      FROM ap_suppliers
                     WHERE segment1 = sup_ins_rec.segment1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_vendor_id   := NULL;
                END;

                fnd_file.put_line (fnd_file.LOG, 'Test2');

                IF ln_vendor_id IS NOT NULL
                THEN
                    --   lv_Supp_err_flag := 'Y';
                    lc_supp_err_msg   :=
                        'Vendor Already Exists in the system. No need to Import.';
                    fnd_file.put_line (fnd_file.LOG, 'Test3');
                ELSE
                    SELECT ap_suppliers_int_s.NEXTVAL
                      INTO ln_supplier_int_id
                      FROM DUAL;

                    IF    sup_ins_rec.vat_code IN
                              ('7%', 'Non Tax', 'Non Taxable')
                       OR sup_ins_rec.vat_code IS NOT NULL
                    THEN
                        lc_auto_tax_calc_flag1   := 'N';
                        sup_ins_rec.vat_code     := NULL;
                    ELSE
                        lc_auto_tax_calc_flag1   :=
                            sup_ins_rec.auto_tax_calc_flag;
                    END IF;

                    fnd_file.put_line (fnd_file.LOG, 'Test3');

                    BEGIN
                        --SAVEPOINT supplier_int;
                        --               fnd_file.put_line (
                        --                  fnd_file.LOG,
                        --                     'Employee_ID- '||lv_employee_id || 'For VENDOR_NAME- '|| sup_ins_rec.VENDOR_NAME);
                        INSERT INTO ap.ap_suppliers_int (
                                        vendor_interface_id,
                                        last_update_date,
                                        last_updated_by,
                                        vendor_name,
                                        vendor_name_alt,
                                        segment1,
                                        summary_flag,
                                        enabled_flag,
                                        last_update_login,
                                        creation_date,
                                        created_by,
                                        employee_id,
                                        vendor_type_lookup_code,
                                        customer_num,
                                        one_time_flag,
                                        min_order_amount,
                                        ship_to_location_id,
                                        ship_to_location_code,
                                        bill_to_location_id,
                                        bill_to_location_code,
                                        ship_via_lookup_code,
                                        freight_terms_lookup_code,
                                        fob_lookup_code,
                                        terms_id,
                                        terms_name,
                                        set_of_books_id,
                                        always_take_disc_flag,
                                        pay_date_basis_lookup_code,
                                        pay_group_lookup_code,
                                        payment_priority,
                                        invoice_currency_code,
                                        payment_currency_code,
                                        invoice_amount_limit,
                                        hold_all_payments_flag,
                                        hold_future_payments_flag,
                                        hold_reason,
                                        distribution_set_id,
                                        distribution_set_name,
                                        accts_pay_code_combination_id,
                                        prepay_code_combination_id, --NULL Srinivas 1
                                        num_1099,
                                        type_1099,
                                        organization_type_lookup_code,
                                        vat_code,
                                        start_date_active,
                                        end_date_active,
                                        --Commented for BT Changes after conversion run on 17-DEC-2014
                                        --minority_group_lookup_code,
                                        --Commented for BT Changes after conversion run on 17-DEC-2014
                                        payment_method_lookup_code,
                                        women_owned_flag,
                                        small_business_flag,
                                        standard_industry_class,
                                        hold_flag,
                                        purchasing_hold_reason,
                                        hold_by,
                                        hold_date,
                                        terms_date_basis,
                                        inspection_required_flag,
                                        receipt_required_flag,
                                        qty_rcv_tolerance,
                                        qty_rcv_exception_code,
                                        enforce_ship_to_location_code,
                                        days_early_receipt_allowed,
                                        days_late_receipt_allowed,
                                        receipt_days_exception_code,
                                        receiving_routing_id,
                                        allow_substitute_receipts_flag,
                                        allow_unordered_receipts_flag,
                                        hold_unmatched_invoices_flag,
                                        exclusive_payment_flag,
                                        auto_tax_calc_flag,
                                        auto_tax_calc_override,
                                        amount_includes_tax_flag,
                                        tax_verification_date,
                                        name_control,
                                        state_reportable_flag,
                                        federal_reportable_flag,
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
                                        program_application_id,
                                        program_id,
                                        program_update_date,
                                        vat_registration_num,
                                        auto_calculate_interest_flag,
                                        exclude_freight_from_discount,
                                        tax_reporting_name,
                                        allow_awt_flag,
                                        awt_group_id,
                                        awt_group_name,
                                        edi_transaction_handling,
                                        edi_payment_method,
                                        edi_payment_format,
                                        edi_remittance_method,
                                        edi_remittance_instruction,
                                        bank_charge_bearer,
                                        match_option,
                                        future_dated_payment_ccid,
                                        create_debit_memo_flag,
                                        offset_tax_flag,
                                        party_orig_system,
                                        party_orig_system_reference,
                                        remittance_email, --Added by BT Team on 24/07/2015 1.4
                                        supplier_notif_method) --Added by BT Team on 24/07/2015 1.4
                                 VALUES (
                                            ln_supplier_int_id,
                                            --ap_suppliers_int_s.NEXTVAL,
                                            SYSDATE,
                                            fnd_global.user_id,
                                            sup_ins_rec.vendor_name,
                                            sup_ins_rec.vendor_name_alt,
                                            sup_ins_rec.segment1,
                                            sup_ins_rec.summary_flag,
                                            sup_ins_rec.enabled_flag,
                                            fnd_global.login_id,
                                            SYSDATE,
                                            fnd_global.user_id,
                                            sup_ins_rec.emp_id,
                                            sup_ins_rec.vendor_type_lookup_code,
                                            sup_ins_rec.customer_num,
                                            sup_ins_rec.one_time_flag,
                                            sup_ins_rec.min_order_amount,
                                            ln_ship_location_id,
                                            sup_ins_rec.ship_to_location_code,
                                            --Modified for 18-JAN-2015
                                            --                          ln_bill_location_id,
                                            sup_ins_rec.BILL_TO_LOCATION_id,
                                            --Modified for 18-JAN-2015
                                            sup_ins_rec.bill_to_location_code,
                                            sup_ins_rec.ship_via_lookup_code,
                                            sup_ins_rec.freight_terms_lookup_code,
                                            sup_ins_rec.fob_lookup_code,
                                            ln_term_id,
                                            sup_ins_rec.terms_name,
                                            sup_ins_rec.set_of_books_id,
                                            sup_ins_rec.always_take_disc_flag,
                                            sup_ins_rec.pay_date_basis_lookup_code,
                                            sup_ins_rec.pay_group_lookup_code,
                                            sup_ins_rec.payment_priority,
                                            sup_ins_rec.invoice_currency_code,
                                            --Modified for 18-JAN-2015
                                            --sup_ins_rec.payment_currency_code,
                                            NVL (
                                                sup_ins_rec.payment_currency_code,
                                                sup_ins_rec.invoice_currency_code),
                                            --Modified for 18-JAN-2015
                                            sup_ins_rec.invoice_amount_limit,
                                            sup_ins_rec.hold_all_payments_flag,
                                            sup_ins_rec.hold_future_payments_flag,
                                            sup_ins_rec.hold_reason,
                                            NULL,
                                            sup_ins_rec.distribution_set_name,
                                            sup_ins_rec.acctpay_ccid_r12,
                                            sup_ins_rec.prepay_ccid_r12,
                                            sup_ins_rec.num_1099,
                                            sup_ins_rec.type_1099,
                                            sup_ins_rec.organization_type_lookup_code,
                                            sup_ins_rec.vat_code,
                                            sup_ins_rec.start_date_active,
                                            sup_ins_rec.end_date_active,
                                            --Commented for BT Changes after conversion run on 17-DEC-2014
                                            --sup_ins_rec.attribute6,
                                            --Commented for BT Changes after conversion run on 17-DEC-2014
                                            -- sup_ins_rec.MINORITY_GROUP_LOOKUP_CODE,
                                            sup_ins_rec.payment_method_lookup_code,
                                            sup_ins_rec.attribute7,
                                            --sup_ins_rec.WOMEN_OWNED_FLAG,
                                            sup_ins_rec.small_business_flag,
                                            sup_ins_rec.standard_industry_class,
                                            sup_ins_rec.hold_flag,
                                            sup_ins_rec.purchasing_hold_reason,
                                            --BT Changes after conversion run on 17-JAN-2015
                                            --sup_ins_rec.hold_by_employee_number,
                                            NULL,
                                            --BT Changes after conversion run on 17-JAN-2015
                                            sup_ins_rec.hold_date,
                                            sup_ins_rec.terms_date_basis,
                                            sup_ins_rec.inspection_required_flag,
                                            sup_ins_rec.receipt_required_flag,
                                            sup_ins_rec.qty_rcv_tolerance,
                                            sup_ins_rec.qty_rcv_exception_code,
                                            sup_ins_rec.enforce_ship_to_location_code,
                                            sup_ins_rec.days_early_receipt_allowed,
                                            sup_ins_rec.days_late_receipt_allowed,
                                            sup_ins_rec.receipt_days_exception_code,
                                            3, --sup_ins_rec.receiving_routing_id,-- Added BY BT Technology Team ON 16-Jun-2015 1.3
                                            sup_ins_rec.allow_substitute_receipts_flag,
                                            sup_ins_rec.allow_unordered_receipts_flag,
                                            sup_ins_rec.hold_unmatched_invoices_flag,
                                            sup_ins_rec.exclusive_payment_flag,
                                            lc_auto_tax_calc_flag1,
                                            --sup_ins_rec.AUTO_TAX_CALC_FLAG,
                                            sup_ins_rec.auto_tax_calc_override,
                                            sup_ins_rec.amount_includes_tax_flag,
                                            sup_ins_rec.tax_verification_date,
                                            sup_ins_rec.name_control,
                                            sup_ins_rec.state_reportable_flag,
                                            sup_ins_rec.federal_reportable_flag,
                                            --Modified on 15-Apr-2015
                                            --sup_ins_rec.attribute_category,
                                            'Supplier Data Elements',
                                            --Modified on 15-Apr-2015
                                            sup_ins_rec.attribute1,
                                            --Start changes for BT Dated 08-DEC-2014
                                            sup_ins_rec.attribute2,
                                            --'N',
                                            --End changes for BT Dated 08-DEC-2014
                                            --NULL,
                                            --Start changes for BT Dated 08-DEC-2014
                                            sup_ins_rec.ATTRIBUTE3,
                                            --NULL,
                                            sup_ins_rec.ATTRIBUTE4,
                                            --NULL,
                                            sup_ins_rec.ATTRIBUTE5,
                                            --NULL,
                                            sup_ins_rec.ATTRIBUTE6,
                                            --NULL,
                                            sup_ins_rec.ATTRIBUTE7,
                                            --NULL,
                                            sup_ins_rec.ATTRIBUTE8,
                                            --NULL,
                                            sup_ins_rec.ATTRIBUTE9,
                                            --NULL,
                                            sup_ins_rec.ATTRIBUTE10,
                                            --End  changes for BT Dated 08-DEC-2014
                                            sup_ins_rec.attribute11,
                                            sup_ins_rec.attribute12,
                                            sup_ins_rec.attribute13,
                                            NULL,
                                            --sup_ins_rec.ATTRIBUTE14,
                                            sup_ins_rec.old_vendor_id, --sup_ins_rec.attribute15,
                                            sup_ins_rec.request_id,
                                            NULL,
                                            NULL,
                                            SYSDATE,
                                            sup_ins_rec.vat_registration_num,
                                            sup_ins_rec.auto_calculate_interest_flag,
                                            sup_ins_rec.exclude_freight_from_discount,
                                            sup_ins_rec.tax_reporting_name,
                                            sup_ins_rec.allow_awt_flag,
                                            ln_awt_group_id,
                                            sup_ins_rec.awt_group_name,
                                            sup_ins_rec.edi_transaction_handling,
                                            sup_ins_rec.edi_payment_method,
                                            sup_ins_rec.edi_payment_format,
                                            sup_ins_rec.edi_remittance_method,
                                            sup_ins_rec.edi_remittance_instruction,
                                            sup_ins_rec.bank_charge_bearer,
                                            sup_ins_rec.match_option,
                                            sup_ins_rec.futurepay_ccid_r12,
                                            sup_ins_rec.create_debit_memo_flag,
                                            sup_ins_rec.offset_tax_flag,
                                            'Oracle R12.0.3',
                                            sup_ins_rec.old_vendor_id,
                                            sup_ins_rec.remittance_email, --Added by BT Team on 24/07/2015 1.4
                                            sup_ins_rec.remit_advice_delivery_method); --Added by BT Team on 24/07/2015 1.4

                        fnd_file.put_line (fnd_file.LOG, 'Test4');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lc_supp_err_flag   := 'Y';
                            lc_supp_err_msg    :=
                                   lc_supp_err_msg
                                || '\Error While Insert in AP_SUPPLIERS_INT for Supplier- '
                                || sup_ins_rec.vendor_name
                                || ' - '
                                || SQLERRM;
                            log_records (
                                p_debug,
                                   'Error while inserting the record into the suppliers interface table ,AP_SUPPLIERS_INT for the supplier name:'
                                || sup_ins_rec.vendor_name
                                || lc_supp_err_msg);

                            xxd_common_utils.record_error (
                                'AP',
                                xxd_common_utils.get_org_id,
                                'XXD AP Supplier Conv Load ',
                                'Error While Insert in AP_SUPPLIERS_INT for Supplier- ',
                                DBMS_UTILITY.format_error_backtrace,
                                fnd_profile.VALUE ('USER_ID'),
                                gn_conc_request_id,
                                sup_ins_rec.segment1,
                                sup_ins_rec.old_vendor_id);
                    END;
                END IF;

                IF NVL (lc_supp_err_flag, 'N') = 'Y' AND ln_vendor_id IS NULL
                THEN
                    --ROLLBACK;
                    UPDATE xxd_ap_sup_sites_cnv_stg_t
                       SET record_status = 'E', error_message = 'Load Failed in Supplier Interface', last_update_login = fnd_global.login_id,
                           creation_date = SYSDATE, created_by = fnd_global.user_id, last_update_date = SYSDATE,
                           last_updated_by = fnd_global.user_id, request_id = gn_conc_request_id
                     WHERE old_vendor_id = sup_ins_rec.old_vendor_id;

                    UPDATE xxd_ap_suppliers_cnv_stg_t
                       SET record_status = 'E', error_message = SUBSTR (lc_supp_err_msg, 1, 2000), last_update_login = fnd_global.login_id,
                           creation_date = SYSDATE, created_by = fnd_global.user_id, last_update_date = SYSDATE,
                           last_updated_by = fnd_global.user_id, request_id = gn_conc_request_id
                     WHERE old_vendor_id = sup_ins_rec.old_vendor_id;

                    gn_sup_reject_l   := gn_sup_reject_l + 1;
                ELSE
                    IF     NVL (lc_supp_err_flag, 'N') = 'Y'
                       AND ln_vendor_id IS NOT NULL
                    THEN
                        UPDATE xxd_ap_suppliers_cnv_stg_t
                           SET record_status = 'E', error_message = SUBSTR (lc_supp_err_msg, 1, 2000), last_update_login = fnd_global.login_id,
                               creation_date = SYSDATE, created_by = fnd_global.user_id, last_update_date = SYSDATE,
                               last_updated_by = fnd_global.user_id, request_id = gn_conc_request_id
                         WHERE     old_vendor_id = sup_ins_rec.old_vendor_id
                               AND record_status NOT IN ('P');

                        gn_sup_reject_l   := gn_sup_reject_l + 1;
                    ELSE
                        UPDATE xxd_ap_suppliers_cnv_stg_t
                           SET record_status = 'P', last_update_login = fnd_global.login_id, creation_date = SYSDATE,
                               created_by = fnd_global.user_id, last_update_date = SYSDATE, last_updated_by = fnd_global.user_id,
                               request_id = gn_conc_request_id
                         WHERE     old_vendor_id = sup_ins_rec.old_vendor_id
                               AND record_status NOT IN ('P');

                        gn_supp_process_l   := gn_supp_process_l + 1;
                    END IF;



                    --END IF;
                    FOR site_ins_r IN site_ins_c (sup_ins_rec.old_vendor_id)
                    LOOP
                        lc_sup_site_err_flag   := NULL;
                        lc_sup_site_err_msg    := NULL;
                        ln_site_id             := NULL;

                        BEGIN
                            SELECT aps.vendor_site_id
                              INTO ln_site_id
                              FROM ap_suppliers ap, ap_supplier_sites_all aps
                             WHERE     ap.vendor_id = aps.vendor_id
                                   AND aps.vendor_site_code =
                                       site_ins_r.vendor_site_code
                                   AND aps.org_id = site_ins_r.org_id
                                   AND ap.segment1 = sup_ins_rec.segment1;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ln_site_id   := NULL;
                        END;

                        IF ln_site_id IS NOT NULL
                        THEN
                            lc_sup_site_err_flag   := 'Y';
                            lc_sup_site_err_msg    :=
                                   'VENDOR_SITE_CODE Already Exists for Vendor- '
                                || sup_ins_rec.vendor_name
                                || ' in the system. No need to Import.';

                            xxd_common_utils.record_error (
                                'AP',
                                xxd_common_utils.get_org_id,
                                'XXD AP Supplier Site Conv Load ',
                                   'VENDOR_SITE_CODE Already Exists for Vendor- '
                                || sup_ins_rec.vendor_name
                                || ' in the system. No need to Import.',
                                DBMS_UTILITY.format_error_backtrace,
                                fnd_profile.VALUE ('USER_ID'),
                                gn_conc_request_id,
                                sup_ins_rec.segment1,
                                sup_ins_rec.old_vendor_id,
                                site_ins_r.vendor_site_code);
                        ELSE
                            IF    site_ins_r.vat_code IN
                                      ('7%', 'Non Tax', 'Non Taxable')
                               OR site_ins_r.vat_code IS NOT NULL
                            THEN
                                lc_auto_tax_calc_flag   := 'N';
                                site_ins_r.vat_code     := NULL;
                            ELSE
                                lc_auto_tax_calc_flag   :=
                                    site_ins_r.auto_tax_calc_flag;
                            END IF;

                            -- Added BY BT Technology Team ON 16-Jun-2015 1.3
                            IF sup_ins_rec.vendor_type_lookup_code =
                               'MANUFACTURER'
                            THEN
                                site_ins_r.supplier_notif_method   := 'NONE';
                            END IF;


                            -- Insert into Supplier sites Interface

                            BEGIN
                                INSERT INTO ap_supplier_sites_int (
                                                vendor_interface_id,
                                                vendor_id,
                                                vendor_site_interface_id,
                                                vendor_site_code,
                                                vendor_site_code_alt,
                                                last_update_date,
                                                last_updated_by,
                                                last_update_login,
                                                creation_date,
                                                created_by,
                                                purchasing_site_flag,
                                                rfq_only_site_flag,
                                                pay_site_flag,
                                                attention_ar_flag,
                                                address_line1,
                                                address_lines_alt,
                                                address_line2,
                                                address_line3,
                                                city,
                                                state,
                                                zip,
                                                province,
                                                country,
                                                area_code,
                                                phone,
                                                customer_num,
                                                --SHIP_TO_LOCATION_ID
                                                ship_to_location_code,
                                                --BILL_TO_LOCATION_ID
                                                bill_to_location_code,
                                                ship_via_lookup_code,
                                                freight_terms_lookup_code,
                                                fob_lookup_code,
                                                inactive_date,
                                                fax,
                                                fax_area_code,
                                                telex,
                                                payment_method_lookup_code,
                                                terms_date_basis,
                                                vat_code,
                                                --DISTRIBUTION_SET_ID,
                                                distribution_set_name,
                                                accts_pay_code_combination_id,
                                                prepay_code_combination_id,
                                                pay_group_lookup_code,
                                                payment_priority,
                                                --TERMS_ID
                                                terms_name,
                                                invoice_amount_limit,
                                                pay_date_basis_lookup_code,
                                                always_take_disc_flag,
                                                invoice_currency_code,
                                                payment_currency_code,
                                                hold_all_payments_flag,
                                                hold_future_payments_flag,
                                                hold_reason,
                                                hold_unmatched_invoices_flag,
                                                ap_tax_rounding_rule,
                                                auto_tax_calc_flag,
                                                auto_tax_calc_override,
                                                amount_includes_tax_flag,
                                                exclusive_payment_flag,
                                                tax_reporting_site_flag,
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
                                                exclude_freight_from_discount,
                                                vat_registration_num,
                                                org_id,
                                                --OPERATING_UNIT_NAME
                                                address_line4,
                                                county,
                                                address_style,
                                                LANGUAGE,
                                                allow_awt_flag,
                                                awt_group_name,
                                                edi_transaction_handling,
                                                edi_id_number,
                                                edi_payment_method,
                                                edi_payment_format,
                                                edi_remittance_method,
                                                bank_charge_bearer,
                                                edi_remittance_instruction,
                                                pay_on_code,
                                                default_pay_site_id,
                                                pay_on_receipt_summary_code,
                                                tp_header_id,
                                                ece_tp_location_code,
                                                pcard_site_flag,
                                                match_option,
                                                country_of_origin_code,
                                                future_dated_payment_ccid,
                                                create_debit_memo_flag,
                                                offset_tax_flag,
                                                supplier_notif_method,
                                                email_address,
                                                remittance_email,
                                                primary_pay_site_flag,
                                                shipping_control,
                                                duns_number,
                                                tolerance_name,
                                                supplier_site_orig_system,
                                                sup_site_orig_system_reference,
                                                remit_advice_delivery_method, --Added by BT Team on 24/07/2015 1.4
                                                party_site_name)
                                         VALUES (
                                                    ln_supplier_int_id,
                                                    --ap_suppliers_int_s.CURRVAL,
                                                    ln_vendor_id,
                                                    ap_supplier_sites_int_s.NEXTVAL,
                                                    site_ins_r.vendor_site_code,
                                                    site_ins_r.vendor_site_code_alt,
                                                    SYSDATE,
                                                    fnd_global.user_id,
                                                    fnd_global.login_id,
                                                    SYSDATE,
                                                    fnd_global.user_id,
                                                    -- Commented by BT Team on 4/24 as part of UAT Testing changes
                                                    --                                  site_ins_r.purchasing_site_flag,
                                                    'Y',
                                                    site_ins_r.rfq_only_site_flag,
                                                    -- Commented by BT Team on 4/24 as part of UAT Testing changes
                                                    --                                  site_ins_r.pay_site_flag,
                                                    'Y',
                                                    site_ins_r.attention_ar_flag,
                                                    site_ins_r.address_line1,
                                                    site_ins_r.address_lines_alt,
                                                    site_ins_r.address_line2,
                                                    site_ins_r.address_line3,
                                                    site_ins_r.city,
                                                    site_ins_r.state,
                                                    site_ins_r.zip,
                                                    site_ins_r.province,
                                                    site_ins_r.country,
                                                    site_ins_r.area_code,
                                                    site_ins_r.phone,
                                                    site_ins_r.customer_num,
                                                    site_ins_r.ship_to_location_code,
                                                    site_ins_r.bill_to_location_code,
                                                    site_ins_r.ship_via_lookup_code,
                                                    site_ins_r.freight_terms_lookup_code,
                                                    site_ins_r.fob_lookup_code,
                                                    site_ins_r.inactive_date,
                                                    site_ins_r.fax,
                                                    site_ins_r.fax_area_code,
                                                    site_ins_r.telex,
                                                    --Start modification for BT Change dated 03-DEC-2014
                                                    --site_ins_r.payment_method_lookup_code,
                                                    NVL2 (
                                                        site_ins_r.attribute15,
                                                        'EFT',
                                                        site_ins_r.payment_method_lookup_code),
                                                    --End modification for BT Change dated 03-DEC-2014
                                                    site_ins_r.terms_date_basis,
                                                    site_ins_r.vat_code,
                                                    site_ins_r.distribution_set_name,
                                                    site_ins_r.acctpay_ccid_r12,
                                                    site_ins_r.prepay_ccid_r12,
                                                    --Start modification for BT Change dated 03-DEC-2014
                                                    --site_ins_r.pay_group_lookup_code,
                                                    NVL2 (
                                                        site_ins_r.attribute15,
                                                        site_ins_r.attribute15,
                                                        site_ins_r.pay_group_lookup_code),
                                                    --End modification for BT Change dated 03-DEC-2014
                                                    site_ins_r.payment_priority,
                                                    site_ins_r.terms_name,
                                                    site_ins_r.invoice_amount_limit,
                                                    site_ins_r.pay_date_basis_lookup_code,
                                                    site_ins_r.always_take_disc_flag,
                                                    site_ins_r.invoice_currency_code,
                                                    site_ins_r.payment_currency_code,
                                                    site_ins_r.hold_all_payments_flag,
                                                    site_ins_r.hold_future_payments_flag,
                                                    site_ins_r.hold_reason,
                                                    site_ins_r.hold_unmatched_invoices_flag,
                                                    site_ins_r.ap_tax_rounding_rule,
                                                    lc_auto_tax_calc_flag,
                                                    --site_ins_r.AUTO_TAX_CALC_FLAG,
                                                    site_ins_r.auto_tax_calc_override,
                                                    site_ins_r.amount_includes_tax_flag,
                                                    site_ins_r.exclusive_payment_flag,
                                                    site_ins_r.tax_reporting_site_flag,
                                                    --Modified on 15-Apr-2015
                                                    --site_ins_r.attribute_category,
                                                    'Supplier Data Elements',
                                                    --Modified on 15-Apr-2015
                                                    site_ins_r.attribute1,
                                                    site_ins_r.attribute2,
                                                    site_ins_r.attribute3,
                                                    site_ins_r.attribute4,
                                                    site_ins_r.attribute5,
                                                    site_ins_r.attribute6,
                                                    site_ins_r.attribute7,
                                                    site_ins_r.attribute8,
                                                    site_ins_r.attribute9,
                                                    site_ins_r.attribute10,
                                                    site_ins_r.attribute11,
                                                    site_ins_r.attribute12,
                                                    site_ins_r.attribute13,
                                                    --Start modification for BT Change dated 03-DEC-2014
                                                    --site_ins_r.attribute14,
                                                    site_ins_r.old_vendor_site_id, -- site_ins_r.attribute14,
                                                    site_ins_r.attribute15,
                                                    --Start modification for BT Change dated 03-DEC-2014
                                                    site_ins_r.exclude_freight_from_discount,
                                                    site_ins_r.vat_registration_num,
                                                    site_ins_r.org_id,
                                                    site_ins_r.address_line4,
                                                    site_ins_r.county,
                                                    site_ins_r.address_style,
                                                    site_ins_r.LANGUAGE,
                                                    site_ins_r.allow_awt_flag,
                                                    site_ins_r.awt_group_name,
                                                    site_ins_r.edi_transaction_handling,
                                                    site_ins_r.edi_id_number,
                                                    site_ins_r.edi_payment_method,
                                                    site_ins_r.edi_payment_format,
                                                    site_ins_r.edi_remittance_method,
                                                    site_ins_r.bank_charge_bearer,
                                                    site_ins_r.edi_remittance_instruction,
                                                    site_ins_r.pay_on_code,
                                                    site_ins_r.default_pay_site_name,
                                                    site_ins_r.pay_on_receipt_summary_code,
                                                    site_ins_r.tp_header_id,
                                                    site_ins_r.ece_tp_location_code,
                                                    site_ins_r.pcard_site_flag,
                                                    site_ins_r.match_option,
                                                    site_ins_r.country_of_origin_code,
                                                    site_ins_r.futurepay_ccid_r12,
                                                    site_ins_r.create_debit_memo_flag,
                                                    site_ins_r.offset_tax_flag,
                                                    site_ins_r.supplier_notif_method,
                                                    site_ins_r.email_address,
                                                    site_ins_r.remittance_email,
                                                    site_ins_r.primary_pay_site_flag,
                                                    site_ins_r.shipping_control,
                                                    site_ins_r.duns_number,
                                                    site_ins_r.tolerance_name,
                                                    'Oracle R12.0.3',
                                                    site_ins_r.old_vendor_site_id,
                                                    -- Meenakshi change done for BT Conversion 01-04-2015
                                                    site_ins_r.remit_advice_delivery_method, --Added by BT Team on 24/07/2015 1.4
                                                    --site_ins_r.supplier_notif_method,      --commented by BT Team on 24/07/2015 1.4
                                                    site_ins_r.vendor_site_code);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    log_records (
                                        p_debug,
                                           'Error while inserting the record into the Supplier Site interface table , AP_SUPPLIER_SITES_INT :'
                                        || ' for the Supplier Name/Supplier Site Code- '
                                        || sup_ins_rec.vendor_name
                                        || '/'
                                        || site_ins_r.vendor_site_code);
                                    lc_sup_site_err_flag   := 'Y';
                                    lc_sup_site_err_msg    :=
                                           lc_sup_site_err_msg
                                        || '\Error While Insert in AP_SUPPLIER_SITES_INT for Supplier- '
                                        || sup_ins_rec.vendor_name
                                        || ' and Site Code- '
                                        || site_ins_r.vendor_site_code
                                        || '-'
                                        || SQLERRM;

                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Site Conv Load ',
                                           'Error While Insert in AP_SUPPLIER_SITES_INT for Supplier- '
                                        || SUBSTR (SQLERRM, 1, 2500),
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_ins_rec.segment1,
                                        sup_ins_rec.old_vendor_id,
                                        site_ins_r.vendor_site_code);


                                    DELETE FROM
                                        ap_suppliers_int
                                          WHERE party_orig_system_reference =
                                                site_ins_r.old_vendor_id;
                            END;
                        END IF;

                        IF    (NVL (lc_sup_site_err_flag, 'N') = 'Y' AND ln_site_id IS NULL)
                           OR (NVL (lc_supp_err_flag, 'N') = 'Y' AND ln_vendor_id IS NULL)
                        THEN
                            --ROLLBACK TO supplier_int;
                            UPDATE xxd_ap_sup_sites_cnv_stg_t
                               SET record_status = 'E', error_message = SUBSTR (lc_sup_site_err_msg, 1, 1999), last_update_login = fnd_global.login_id,
                                   creation_date = SYSDATE, created_by = fnd_global.user_id, last_update_date = SYSDATE,
                                   last_updated_by = fnd_global.user_id, request_id = gn_conc_request_id
                             WHERE old_vendor_site_id =
                                   site_ins_r.old_vendor_site_id;

                            gn_site_reject_l   := gn_site_reject_l + 1;

                            UPDATE xxd_conv.xxd_ap_sup_site_con_cnv_stg_t
                               SET record_status = 'E', error_message = 'Load Failed in Supplier Site Interface', last_update_login = fnd_global.login_id,
                                   creation_date = SYSDATE, created_by = fnd_global.user_id, last_update_date = SYSDATE,
                                   last_updated_by = fnd_global.user_id, request_id = gn_conc_request_id
                             WHERE old_vendor_site_id =
                                   site_ins_r.old_vendor_site_id;

                            UPDATE xxd_ap_suppliers_cnv_stg_t
                               SET record_status = 'E', error_message = 'Load Failed in Supplier Site Interface', last_update_login = fnd_global.login_id,
                                   creation_date = SYSDATE, created_by = fnd_global.user_id, last_update_date = SYSDATE,
                                   last_updated_by = fnd_global.user_id, request_id = gn_conc_request_id
                             WHERE     old_vendor_id =
                                       site_ins_r.old_vendor_id
                                   AND record_status NOT IN ('P');
                        ELSE
                            IF    (NVL (lc_sup_site_err_flag, 'N') = 'Y' AND ln_site_id IS NOT NULL)
                               OR (NVL (lc_supp_err_flag, 'N') = 'Y' AND ln_vendor_id IS NULL)
                            THEN
                                UPDATE xxd_ap_sup_sites_cnv_stg_t
                                   SET record_status = 'E', error_message = SUBSTR (lc_sup_site_err_msg, 1, 1999), last_update_login = fnd_global.login_id,
                                       creation_date = SYSDATE, created_by = fnd_global.user_id, last_update_date = SYSDATE,
                                       last_updated_by = fnd_global.user_id, request_id = gn_conc_request_id
                                 WHERE old_vendor_site_id =
                                       site_ins_r.old_vendor_site_id;

                                gn_site_reject_l   := gn_site_reject_l + 1;

                                UPDATE xxd_conv.xxd_ap_sup_site_con_cnv_stg_t
                                   SET record_status = 'E', error_message = 'Load Failed in Supplier Site Interface', last_update_login = fnd_global.login_id,
                                       creation_date = SYSDATE, created_by = fnd_global.user_id, last_update_date = SYSDATE,
                                       last_updated_by = fnd_global.user_id, request_id = gn_conc_request_id
                                 WHERE old_vendor_site_id =
                                       site_ins_r.old_vendor_site_id;

                                UPDATE xxd_ap_suppliers_cnv_stg_t
                                   SET record_status = 'E', error_message = 'Load Failed in Supplier Site Interface', last_update_login = fnd_global.login_id,
                                       creation_date = SYSDATE, created_by = fnd_global.user_id, last_update_date = SYSDATE,
                                       last_updated_by = fnd_global.user_id, request_id = gn_conc_request_id
                                 WHERE     old_vendor_id =
                                           site_ins_r.old_vendor_id
                                       AND record_status NOT IN ('P');
                            ELSE
                                UPDATE xxd_ap_sup_sites_cnv_stg_t
                                   SET record_status = 'P', last_update_login = fnd_global.login_id, creation_date = SYSDATE,
                                       created_by = fnd_global.user_id, last_update_date = SYSDATE, last_updated_by = fnd_global.user_id,
                                       request_id = gn_conc_request_id
                                 WHERE old_vendor_site_id =
                                       site_ins_r.old_vendor_site_id;

                                gn_site_process_l   := gn_site_process_l + 1;
                            END IF;
                        END IF;
                    END LOOP;                                 -- Supplier Site

                    -- Start Loop for Supplier Contacts
                    FOR cont_ins_r IN cont_ins_c (sup_ins_rec.old_vendor_id)
                    LOOP
                        lc_cont_err_flag   := NULL;
                        lc_cont_err_msg    := NULL;
                        ln_contact_id      := NULL;

                        BEGIN
                            SELECT cont.vendor_contact_id
                              INTO ln_contact_id
                              FROM ap_suppliers sup, po_vendor_contacts cont
                             WHERE     --                                   sup.vendor_id = sup_ins_rec.vendor_id
                                       --                                     AND
                                       sup.segment1 = sup_ins_rec.segment1
                                   AND NVL (sup_ins_rec.inactive_date,
                                            SYSDATE) >=
                                       SYSDATE
                                   AND UPPER (cont.last_name) =
                                       UPPER (cont_ins_r.last_name)
                                   AND UPPER (cont.first_name) =
                                       UPPER (cont_ins_r.first_name);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ln_contact_id   := NULL;
                        END;

                        IF ln_contact_id IS NOT NULL
                        THEN
                            lc_cont_err_flag   := 'Y';
                            lc_cont_err_msg    :=
                                   lc_cont_err_msg
                                || 'Vendor SIte Contact ALready Exists- ';

                            xxd_common_utils.record_error ('AP', xxd_common_utils.get_org_id, 'XXD AP Supplier Contact Conv Load ', 'Vendor SIte Contact ALready Exists No need to Load - ', DBMS_UTILITY.format_error_backtrace, fnd_profile.VALUE ('USER_ID'), gn_conc_request_id, sup_ins_rec.segment1, sup_ins_rec.old_vendor_id
                                                           , NULL);
                        ELSE
                            BEGIN
                                INSERT INTO ap_sup_site_contact_int (
                                                vendor_site_code,
                                                org_id,
                                                inactive_date,
                                                first_name,
                                                middle_name,
                                                last_name,
                                                prefix,
                                                title,
                                                mail_stop,
                                                area_code,
                                                phone,
                                                contact_name_alt,
                                                first_name_alt,
                                                last_name_alt,
                                                department,
                                                email_address,
                                                --     URL,
                                                alt_area_code,
                                                alt_phone,
                                                fax_area_code,
                                                fax,
                                                vendor_interface_id,
                                                vendor_contact_interface_id,
                                                contact_orig_system,
                                                contact_orig_system_reference,
                                                last_update_login,
                                                creation_date,
                                                created_by,
                                                last_update_date,
                                                last_updated_by)
                                     VALUES (NULL, --cont_ins_r.vendor_site_code,
                                                   cont_ins_r.org_id, cont_ins_r.inactive_date, cont_ins_r.first_name, cont_ins_r.middle_name, cont_ins_r.last_name, cont_ins_r.prefix, cont_ins_r.title, cont_ins_r.url, --MAIL_STOP,
                                                                                                                                                                                                                          cont_ins_r.area_code, cont_ins_r.phone, cont_ins_r.contact_name_alt, cont_ins_r.first_name_alt, cont_ins_r.last_name_alt, cont_ins_r.department, cont_ins_r.email_address, --   cont_ins_r.URL,
                                                                                                                                                                                                                                                                                                                                                                                                     cont_ins_r.alt_area_code, cont_ins_r.alt_phone, cont_ins_r.fax_area_code, cont_ins_r.fax, ln_supplier_int_id, --ap_suppliers_int_s.CURRVAL,  rakesh
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   ap_sup_site_contact_int_s.NEXTVAL, 'Oracle R12.0.3', cont_ins_r.old_vendor_contact_id, fnd_global.login_id, SYSDATE, fnd_global.user_id
                                             , SYSDATE, fnd_global.user_id);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Error while inserting the record into the Supplier Site Contact interface table , AP_SUP_SITE_CONTACT_INT :'
                                        || ' for the Site:'
                                        || NULL); -- site_ins_r.vendor_site_code);
                                    lc_cont_err_flag   := 'Y';
                                    lc_cont_err_msg    :=
                                           lc_cont_err_msg
                                        || '\Error While Insert in AP_SUP_SITE_CONTACT_INT for Supplier- '
                                        || sup_ins_rec.vendor_name
                                        || ' and Site Code- '
                                        || NULL  --site_ins_r.vendor_site_code
                                        || ' and Contact- '
                                        || cont_ins_r.first_name
                                        || ','
                                        || cont_ins_r.last_name
                                        || '- '
                                        || SQLERRM;

                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Contact Conv Load ',
                                           'Error While Insert in AP_SUP_SITE_CONTACT_INT for Supplier- '
                                        || SUBSTR (SQLERRM, 1, 2500),
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        sup_ins_rec.segment1,
                                        sup_ins_rec.old_vendor_id,
                                        --                                       site_ins_r.vendor_site_code,
                                        cont_ins_r.old_vendor_contact_id);

                                    DELETE FROM
                                        ap_supplier_sites_int b
                                          WHERE party_orig_system_reference =
                                                cont_ins_r.old_vendor_site_id;

                                    DELETE FROM
                                        ap_suppliers_int a
                                          WHERE a.vendor_interface_id =
                                                (SELECT b.vendor_interface_id
                                                   FROM ap_supplier_sites_int b
                                                  WHERE b.party_orig_system_reference =
                                                        cont_ins_r.old_vendor_site_id);
                            END;
                        END IF;

                        IF    NVL (lc_cont_err_flag, 'N') = 'Y'
                           OR NVL (lc_sup_site_err_flag, 'N') = 'Y'
                           OR (NVL (lc_supp_err_flag, 'N') = 'Y' AND ln_vendor_id IS NULL)
                        THEN
                            --    ROLLBACK TO supplier_int;
                            UPDATE xxd_conv.xxd_ap_sup_site_con_cnv_stg_t
                               SET record_status = 'E', error_message = SUBSTR (lc_cont_err_msg, 1, 2000), last_update_login = fnd_global.login_id,
                                   creation_date = SYSDATE, created_by = fnd_global.user_id, last_update_date = SYSDATE,
                                   last_updated_by = fnd_global.user_id, request_id = gn_conc_request_id
                             WHERE old_vendor_contact_id =
                                   cont_ins_r.old_vendor_contact_id;

                            gn_contact_reject_l   := gn_contact_reject_l + 1;

                            UPDATE xxd_ap_sup_sites_cnv_stg_t
                               SET record_status = 'E', error_message = 'Load Failed in Supplier Contact Interface', last_update_login = fnd_global.login_id,
                                   creation_date = SYSDATE, created_by = fnd_global.user_id, last_update_date = SYSDATE,
                                   last_updated_by = fnd_global.user_id, request_id = gn_conc_request_id
                             WHERE old_vendor_site_id =
                                   cont_ins_r.old_vendor_site_id;

                            UPDATE xxd_ap_suppliers_cnv_stg_t
                               SET record_status = 'E', error_message = 'Load Failed in Supplier Contact Interface', last_update_login = fnd_global.login_id,
                                   creation_date = SYSDATE, created_by = fnd_global.user_id, last_update_date = SYSDATE,
                                   last_updated_by = fnd_global.user_id, request_id = gn_conc_request_id
                             WHERE     old_vendor_id =
                                       sup_ins_rec.old_vendor_id
                                   AND record_status NOT IN ('P');
                        ELSE
                            UPDATE xxd_conv.xxd_ap_sup_site_con_cnv_stg_t
                               SET record_status = 'P', last_update_login = fnd_global.login_id, creation_date = SYSDATE,
                                   created_by = fnd_global.user_id, last_update_date = SYSDATE, last_updated_by = fnd_global.user_id,
                                   request_id = gn_conc_request_id
                             WHERE old_vendor_contact_id =
                                   cont_ins_r.old_vendor_contact_id;

                            gn_contact_process_l   :=
                                gn_contact_process_l + 1;
                            COMMIT;
                        END IF;
                    END LOOP;                              -- Supplier Contact
                --               end if;
                END IF;
            END LOOP;                                              -- Supplier

            --Write into output of Load Mode
            -----------------------------------------------------
            fnd_file.put_line (
                fnd_file.output,
                'XXD AP Supplier data Validate and Load program');
            fnd_file.put_line (
                fnd_file.output,
                'Run Date: ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
            fnd_file.put_line (fnd_file.output,
                               'Executed By: ' || gc_user_name);
            fnd_file.put_line (fnd_file.output,
                               'Process Mode: ' || gc_load_only);
            fnd_file.put_line (fnd_file.output,
                               'Instance Name: ' || gc_dbname);
            fnd_file.put_line (fnd_file.output, '');
            fnd_file.put_line (
                fnd_file.output,
                '----------------------------------------------------------------------------------------------');
            fnd_file.put_line (
                fnd_file.output,
                   RPAD ('S No.    Entity', 50)
                || RPAD ('Total_Records_load', 20)
                || RPAD ('Total_Records_Error', 20)
                || RPAD ('Total_Records', 20));
            fnd_file.put_line (
                fnd_file.output,
                '----------------------------------------------------------------------------------------------');
            fnd_file.put_line (
                fnd_file.output,
                   RPAD ('1       Suppliers', 50)
                || RPAD (gn_supp_process_l, 20)
                || RPAD (gn_sup_reject_l, 20)
                || RPAD (gn_sup_found_l, 20));
            fnd_file.put_line (
                fnd_file.output,
                   RPAD ('2       Supplier Sites', 50)
                || RPAD (gn_site_process_l, 20)
                || RPAD (gn_site_reject_l, 20)
                || RPAD (gn_sites_found_l, 20));
            fnd_file.put_line (
                fnd_file.output,
                   RPAD ('3       Supplier Contacts', 50)
                || RPAD (gn_contact_process_l, 20)
                || RPAD (gn_contact_reject_l, 20)
                || RPAD (gn_cont_found_l, 20));
            fnd_file.put_line (
                fnd_file.output,
                   RPAD ('4       Supplier Banks', 50)
                || RPAD (gn_supp_bank_process_l, 20)
                || RPAD (gn_supp_bank_reject_l, 20)
                || RPAD (gn_supp_bank_found_l, 20));
            fnd_file.put_line (
                fnd_file.output,
                   RPAD ('3       Supplier Site Banks', 50)
                || RPAD (gn_sup_site_bank_process_l, 20)
                || RPAD (gn_sup_site_bank_reject_l, 20)
                || RPAD (gn_site_bank_found_l, 20));
        END IF;
    --end;
    END validate_supplier_info;

    PROCEDURE supp_bank_acct (x_errbuf       OUT VARCHAR2,
                              x_retcode      OUT NUMBER,
                              p_debug     IN     VARCHAR2)
    IS
        CURSOR c_ssb IS
            SELECT *
              FROM xxd_ap_sup_bank_cnv_stg_t
             WHERE record_status = 'V';

        CURSOR c_update_cont_id IS
            SELECT vendor_contact_id, mail_stop
              FROM po_vendor_contacts
             WHERE mail_stop IS NOT NULL AND attribute1 IS NULL;

        CURSOR c_update_dup_addr IS
            SELECT assa.vendor_site_id, assa.vendor_site_code, assa.address_line1,
                   assa.attribute8, hps.party_site_name, hl.location_id
              FROM ap_supplier_sites_all assa, hz_party_sites hps, hz_locations hl
             WHERE     assa.party_site_id = hps.party_site_id
                   AND hps.location_id = hl.location_id
                   AND assa.attribute8 IS NOT NULL;

        bank_new                iby_ext_bankacct_pub.extbank_rec_type;
        branch_new              iby_ext_bankacct_pub.extbankbranch_rec_type;
        account_new             iby_ext_bankacct_pub.extbankacct_rec_type;
        p_assignment_attribs    iby_fndcpt_setup_pub.pmtinstrassignment_rec_type;
        p_instrument            iby_fndcpt_setup_pub.pmtinstrument_rec_type;
        p_payee                 iby_disbursement_setup_pub.payeecontext_rec_type;
        ln_sob_id               NUMBER;
        ln_vendor_id            NUMBER;
        ln_vendor_site_id       NUMBER;
        ln_bank_acct_id         NUMBER;
        ln_acct_use_id          NUMBER;
        ln_cnt                  NUMBER;
        ln_cnt1                 NUMBER;
        lc_flag                 VARCHAR2 (2);
        lc_err_msg              VARCHAR2 (2000);
        lc_ssb_rej              NUMBER;
        ln_bank_id              NUMBER;
        ln_branch_id            NUMBER;
        ln_acct_id              NUMBER;
        lc_return_status        VARCHAR2 (100);
        ld_end_date             DATE;
        ld_start_date           DATE;
        ln_assign_id            NUMBER;
        l_response              iby_fndcpt_common_pub.result_rec_type;
        lc_bank_name            VARCHAR2 (240);
        lc_bank_number          VARCHAR2 (240);
        lc_branch_name          VARCHAR2 (240);
        lc_branch_number        VARCHAR2 (240);
        lc_acct_number          VARCHAR2 (240);
        lc_acct_name            VARCHAR2 (240);
        lc_currency             VARCHAR2 (240);
        lc_country_code         VARCHAR2 (240);
        lc_association_level    VARCHAR2 (20);
        ln_supplier_site_id     NUMBER;
        ln_party_site_id        NUMBER;
        lc_org_type             VARCHAR2 (20);
        lc_vendor_type          VARCHAR2 (30);
        ld_creation_date        DATE := SYSDATE;
        ld_last_update_date     DATE := SYSDATE;
        ln_created_by           NUMBER := TO_NUMBER (fnd_global.user_id);
        ln_last_updated_by      NUMBER := TO_NUMBER (fnd_global.user_id);
        ln_last_update_login    NUMBER := TO_NUMBER (fnd_global.login_id);
        lc_start_date_time      VARCHAR2 (30);
        lc_end_date_time        VARCHAR2 (30);
        ln_new_count            NUMBER;
        ln_success_count        NUMBER := 0;
        ln_error_count          NUMBER := 0;
        lc_error_description    VARCHAR2 (2000);
        ln_request_id           NUMBER;
        ln_count                NUMBER := 0;
        ln_emp_id               NUMBER;
        ln_sql_err              NUMBER;
        ln_org_id               NUMBER;
        ln_party_id             NUMBER;
        lc_branch_type          VARCHAR2 (10);
        ln_msg_count            NUMBER;
        lc_msg_data             VARCHAR2 (2000);
        /*-- Count Variables --*/
        ln_bank_count           NUMBER := 0;
        ln_branch_count         NUMBER := 0;
        ln_bank_account_count   NUMBER := 0;
        lb_err_status           BOOLEAN := FALSE;
        lb_warning_chk          BOOLEAN := FALSE;
        /* ---------Declare retcode variables --------- */
        ln_retcode_success      NUMBER := 0;
        ln_retcode_warning      NUMBER := 1;
        ln_retcode_error        NUMBER := 2;
        lv_acct_own_id          NUMBER;
    BEGIN
        ln_cnt       := 0;
        ln_cnt1      := 0;
        lc_ssb_rej   := 0;

        FOR r_ssb IN c_ssb
        LOOP
            BEGIN
                /* Assign values to variables */
                lc_flag                := NULL;
                lc_err_msg             := NULL;
                ln_party_id            := NULL;
                lc_vendor_type         := NULL;
                lc_bank_name           := r_ssb.bank_name;
                lc_bank_number         := r_ssb.bank_number;                --
                lc_branch_name         := r_ssb.branch_name;
                lc_branch_number       := r_ssb.branch_number;
                lc_acct_number         := r_ssb.bank_account_num;
                lc_acct_name           := r_ssb.bank_account_name;          --
                lc_currency            := r_ssb.currency_code;              --
                lc_country_code        := r_ssb.country;
                ln_supplier_site_id    := NULL;
                ln_party_site_id       := NULL;
                ln_org_id              := NULL;
                lc_association_level   := NULL;
                lc_org_type            := NULL;
                ln_bank_id             := NULL;
                ln_branch_id           := NULL;
                ln_acct_id             := NULL;
                lc_return_status       := NULL;
                ln_msg_count           := NULL;
                lc_msg_data            := NULL;
                ld_end_date            := NULL;
                ld_start_date          := NULL;
                ln_assign_id           := NULL;
                fnd_msg_pub.initialize;
                lb_err_status          := FALSE; /* Set error status flag to False */
                log_records (
                    p_debug,
                       'Supplier Site Bank Account Creation for BRANCH_NUMBER/BANK_ACCOUNT_NUM- '
                    || r_ssb.bank_name
                    || '/'
                    || r_ssb.bank_account_num);
                log_records (
                    p_debug,
                    '--------------------------------------------------------------------------------------------------');

                BEGIN
                    /* SELECT pv.party_id
                       INTO ln_party_id
                       FROM po_vendors pv
                      WHERE UPPER (pv.vendor_name) = UPPER (r_ssb.payee_name);
                   */
                    ln_party_id   := NULL;

                    SELECT pv.party_id
                      INTO ln_party_id
                      FROM ap_suppliers pv
                     WHERE attribute15 = r_ssb.old_vendor_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        log_records (p_debug,
                                     'Vendor doesnt exists' || SQLERRM);
                        lb_err_status   := TRUE;

                        xxd_common_utils.record_error ('AP', xxd_common_utils.get_org_id, 'XXD AP Supplier Bank Conv Import ', 'Vendor doesnt exists' || SUBSTR (SQLERRM, 1, 2500), DBMS_UTILITY.format_error_backtrace, fnd_profile.VALUE ('USER_ID'), gn_conc_request_id, r_ssb.bank_account_num, r_ssb.bank_account_name
                                                       , r_ssb.old_vendor_id);
                END;

                IF r_ssb.old_vendor_site_id IS NOT NULL
                THEN
                    BEGIN
                        ln_supplier_site_id   := NULL;
                        ln_party_site_id      := NULL;
                        ln_org_id             := NULL;

                        SELECT vendor_site_id, party_site_id, org_id
                          INTO ln_supplier_site_id, ln_party_site_id, ln_org_id
                          FROM ap_supplier_sites_all
                         WHERE attribute14 = r_ssb.old_vendor_site_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            log_records (
                                p_debug,
                                'Vendor site doesnt exists' || SQLERRM);
                            lb_err_status   := TRUE;

                            xxd_common_utils.record_error (
                                'AP',
                                xxd_common_utils.get_org_id,
                                'XXD AP Supplier Bank Conv Import ',
                                   'Vendor site doesnt exists'
                                || SUBSTR (SQLERRM, 1, 2500),
                                DBMS_UTILITY.format_error_backtrace,
                                fnd_profile.VALUE ('USER_ID'),
                                gn_conc_request_id,
                                r_ssb.bank_account_num,
                                r_ssb.bank_account_name,
                                r_ssb.old_vendor_id,
                                r_ssb.vendor_site_code);
                    END;
                END IF;

                IF lb_err_status = FALSE
                THEN                                        --Added By Sryeruv
                    BEGIN
                        iby_ext_bankacct_pub.check_bank_exist (
                            1.0,
                            fnd_api.g_false,
                            lc_country_code,
                            lc_bank_name,
                            lc_bank_number,
                            lc_return_status,
                            ln_msg_count,
                            lc_msg_data,
                            ln_bank_id,
                            ld_end_date,
                            l_response);
                        /* --- Error handling --- */
                        lc_return_status   := lc_return_status;
                        ln_msg_count       := ln_msg_count;
                        lc_msg_data        := lc_msg_data;

                        IF lc_return_status <> fnd_api.g_ret_sts_success
                        THEN
                            log_records (
                                p_debug,
                                   'Error 4 - Error while checking Bank for Vendor '
                                || r_ssb.payee_name
                                || ', Record '
                                || r_ssb.record_id);
                            lb_err_status   := TRUE;

                            IF ln_msg_count > 0
                            THEN
                                lc_msg_data   := NULL;

                                FOR i IN 1 .. ln_msg_count
                                LOOP
                                    lc_msg_data   := fnd_msg_pub.get (i, 'F');
                                    log_records (
                                        p_debug,
                                           'Error 4.'
                                        || i
                                        || ' - '
                                        || lc_msg_data);
                                END LOOP;

                                xxd_common_utils.record_error (
                                    'AP',
                                    xxd_common_utils.get_org_id,
                                    'XXD AP Supplier Bank Conv Import ',
                                       'Error 4 - Error while checking Bank for Vendor - '
                                    || lc_msg_data,
                                    DBMS_UTILITY.format_error_backtrace,
                                    fnd_profile.VALUE ('USER_ID'),
                                    gn_conc_request_id,
                                    r_ssb.bank_account_num,
                                    r_ssb.bank_account_name,
                                    r_ssb.old_vendor_id,
                                    r_ssb.vendor_site_code);
                            END IF;
                        END IF;

                        IF (ln_bank_id IS NULL) AND (lb_err_status = FALSE)
                        THEN
                            /* Assign variables to Bank_New record type variable */
                            bank_new.bank_name          := r_ssb.bank_name;
                            -- Change by BT Team on 4/27
                            -- bank_new.bank_alt_name := r_ssb.bank_name;
                            bank_new.bank_alt_name      := r_ssb.bank_name_alt;
                            -- End of changes by BT Team on 4/27
                            bank_new.bank_number        := r_ssb.bank_number;
                            bank_new.institution_type   := 'BANK';
                            --'r_ssb.institution_type;
                            bank_new.country_code       := r_ssb.country;
                            iby_ext_bankacct_pub.create_ext_bank (
                                1.0,
                                fnd_api.g_false,
                                bank_new,
                                ln_bank_id,
                                lc_return_status,
                                ln_msg_count,
                                lc_msg_data,
                                l_response);
                            /* --- Error handling --- */
                            lc_return_status            := lc_return_status;
                            ln_msg_count                := ln_msg_count;
                            lc_msg_data                 := lc_msg_data;

                            IF lc_return_status <> fnd_api.g_ret_sts_success
                            THEN
                                log_records (
                                    p_debug,
                                       'Error 5 - Error while creating Bank for Vendor '
                                    || r_ssb.payee_name
                                    || ', Record '
                                    || r_ssb.record_id);
                                lb_err_status   := TRUE;

                                IF ln_msg_count > 0
                                THEN
                                    lc_msg_data   := NULL;

                                    FOR i IN 1 .. ln_msg_count
                                    LOOP
                                        lc_msg_data   :=
                                            fnd_msg_pub.get (i, 'F');
                                        log_records (
                                            p_debug,
                                               'Error 5.'
                                            || i
                                            || ' - '
                                            || lc_msg_data);
                                    END LOOP;

                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Bank Conv Import ',
                                           'Error while creating Bank for Vendor - '
                                        || lc_msg_data,
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        r_ssb.bank_account_num,
                                        r_ssb.bank_account_name,
                                        r_ssb.old_vendor_id,
                                        r_ssb.vendor_site_code);
                                END IF;
                            ELSIF lc_return_status =
                                  fnd_api.g_ret_sts_success
                            THEN
                                log_records (
                                    p_debug,
                                       'Bank created for Vendor '
                                    || r_ssb.payee_name
                                    || ', Record '
                                    || r_ssb.record_id);
                                log_records (p_debug,
                                             'Bank ID : ' || ln_bank_id);
                                ln_bank_count   := ln_bank_count + 1;
                            END IF;
                        ELSE
                            log_records (
                                p_debug,
                                   'This is Existing Bank ID : '
                                || ln_bank_id
                                || ' for Vendor '
                                || r_ssb.payee_name
                                || ', Record '
                                || r_ssb.record_id);
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lc_error_description   :=
                                   SQLCODE
                                || ' : '
                                || SQLERRM
                                || ' for Vendor '
                                || r_ssb.payee_name
                                || ', Record '
                                || r_ssb.record_id;
                            x_retcode        := ln_retcode_warning;
                            lb_err_status    := TRUE;
                            lb_warning_chk   := TRUE;
                            log_records (
                                p_debug,
                                'Error 6 - ' || lc_error_description);

                            xxd_common_utils.record_error (
                                'AP',
                                xxd_common_utils.get_org_id,
                                'XXD AP Supplier Bank Conv Import ',
                                   'When Other Exception error - '
                                || lc_error_description,
                                DBMS_UTILITY.format_error_backtrace,
                                fnd_profile.VALUE ('USER_ID'),
                                gn_conc_request_id,
                                r_ssb.bank_account_num,
                                r_ssb.bank_account_name,
                                r_ssb.old_vendor_id,
                                r_ssb.vendor_site_code);
                    END;
                END IF;                             --IF lb_err_status = FALSE

                /* --- Bank Branch --- */
                log_records (p_debug, 'BankId - ' || ln_bank_id);

                -- log_records (p_debug, 'BankStatus - ' || lb_err_status);
                IF (ln_bank_id IS NOT NULL) AND (lb_err_status = FALSE)
                THEN
                    iby_ext_bankacct_pub.check_ext_bank_branch_exist (
                        1.0,
                        fnd_api.g_false,
                        ln_bank_id,
                        lc_branch_name,
                        lc_branch_number,
                        lc_return_status,
                        ln_msg_count,
                        lc_msg_data,
                        ln_branch_id,
                        ld_end_date,
                        l_response);
                    /* --- Error handling --- */
                    lc_return_status   := lc_return_status;
                    ln_msg_count       := ln_msg_count;
                    lc_msg_data        := lc_msg_data;

                    log_records (
                        p_debug,
                        ' Branch checking condition - ' || fnd_api.g_ret_sts_success);

                    IF lc_return_status <> fnd_api.g_ret_sts_success
                    THEN
                        log_records (
                            p_debug,
                               'Error 7 - Error while checking Bank Branch for Vendor '
                            || r_ssb.payee_name
                            || ', Record '
                            || r_ssb.record_id);
                        lb_err_status   := TRUE;

                        IF ln_msg_count > 0
                        THEN
                            lc_msg_data   := NULL;

                            FOR i IN 1 .. ln_msg_count
                            LOOP
                                lc_msg_data   := fnd_msg_pub.get (i, 'F');
                                log_records (
                                    p_debug,
                                    'Error 7.' || i || ' - ' || lc_msg_data);
                            END LOOP;

                            xxd_common_utils.record_error (
                                'AP',
                                xxd_common_utils.get_org_id,
                                'XXD AP Supplier Bank Conv Import ',
                                   'Error while checking Bank Branch for Vendor - '
                                || lc_msg_data,
                                DBMS_UTILITY.format_error_backtrace,
                                fnd_profile.VALUE ('USER_ID'),
                                gn_conc_request_id,
                                r_ssb.bank_account_num,
                                r_ssb.bank_account_name,
                                r_ssb.old_vendor_id,
                                r_ssb.vendor_site_code);
                        END IF;
                    END IF;

                    log_records (p_debug, 'Branch id - ' || ln_branch_id);

                    --    log_records (p_debug, 'Branch  err status - ' || lb_err_status);
                    IF (ln_branch_id IS NULL) AND (lb_err_status = FALSE)
                    THEN
                        -- Derive Bank Branch type

                        /* Assign variables to Branch_New record type variable */
                        branch_new.branch_number   := r_ssb.branch_number;
                        branch_new.branch_name     := r_ssb.branch_name;
                        --                              Branch_New.alternate_branch_name  :=    r_ssb.bank_branch_name_alt;
                        --                              Branch_New.bic                          :=    r_ssb.bic;
                        branch_new.bank_party_id   := ln_bank_id;
                        -- Changes made by BT Team on 4/26
                        branch_new.branch_type     := r_ssb.bank_branch_type;
                        branch_new.bic             := r_ssb.eft_swift_code;
                        branch_new.description     :=
                            r_ssb.branch_description;
                        branch_new.alternate_branch_name   :=
                            r_ssb.bank_branch_name_alt;
                        -- End of changes made by BT Team on 4/26
                        log_records (p_debug,
                                     ' Branch Name - ' || r_ssb.branch_name);

                        BEGIN
                            iby_ext_bankacct_pub.create_ext_bank_branch (
                                1.0,
                                fnd_api.g_false,
                                branch_new,
                                ln_branch_id,
                                lc_return_status,
                                ln_msg_count,
                                lc_msg_data,
                                l_response);
                            /* --- Error handling --- */
                            lc_return_status   := lc_return_status;
                            ln_msg_count       := ln_msg_count;
                            lc_msg_data        := lc_msg_data;
                            log_records (
                                p_debug,
                                   ' While creating branch status - '
                                || lc_return_status);

                            IF lc_return_status <> fnd_api.g_ret_sts_success
                            THEN
                                log_records (
                                    p_debug,
                                       'Error 9 - Error while creating Bank Branch for Vendor '
                                    || r_ssb.payee_name
                                    || ', Record '
                                    || r_ssb.record_id);
                                lb_err_status   := TRUE;

                                IF ln_msg_count > 0
                                THEN
                                    lc_msg_data   := NULL;

                                    FOR i IN 1 .. ln_msg_count
                                    LOOP
                                        lc_msg_data   :=
                                            fnd_msg_pub.get (i, 'F');
                                        log_records (
                                            p_debug,
                                               'Error 9.'
                                            || i
                                            || ' - '
                                            || lc_msg_data);
                                    END LOOP;

                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Bank Conv Import ',
                                           'Error while creating Bank Branch for Vendor - '
                                        || lc_msg_data,
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        r_ssb.bank_account_num,
                                        r_ssb.bank_account_name,
                                        r_ssb.old_vendor_id,
                                        r_ssb.vendor_site_code);
                                END IF;
                            ELSIF lc_return_status =
                                  fnd_api.g_ret_sts_success
                            THEN
                                log_records (
                                    p_debug,
                                       'Bank Branch created for Vendor '
                                    || r_ssb.payee_name
                                    || ', Record '
                                    || r_ssb.record_id);
                                log_records (p_debug,
                                             'Branch ID : ' || ln_branch_id);
                                ln_branch_count   := ln_branch_count + 1;
                            END IF;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lc_error_description   :=
                                       SQLCODE
                                    || ' : '
                                    || SQLERRM
                                    || ' for Vendor '
                                    || r_ssb.payee_name
                                    || ', Record '
                                    || r_ssb.record_id;
                                x_retcode        := ln_retcode_warning;
                                lb_err_status    := TRUE;
                                lb_warning_chk   := TRUE;
                                log_records (
                                    p_debug,
                                    'Error 10 - ' || lc_error_description);
                                xxd_common_utils.record_error (
                                    'AP',
                                    xxd_common_utils.get_org_id,
                                    'XXD AP Supplier Bank Conv Import ',
                                       'When other exception error  - '
                                    || lc_error_description,
                                    DBMS_UTILITY.format_error_backtrace,
                                    fnd_profile.VALUE ('USER_ID'),
                                    gn_conc_request_id,
                                    r_ssb.bank_account_num,
                                    r_ssb.bank_account_name,
                                    r_ssb.old_vendor_id,
                                    r_ssb.vendor_site_code);
                        END;
                    ELSE
                        log_records (
                            p_debug,
                               'This is Existing Branch : '
                            || ln_branch_id
                            || ' for Vendor '
                            || r_ssb.payee_name
                            || ', Record '
                            || r_ssb.record_id);
                    END IF;
                ELSE
                    log_records (
                        p_debug,
                           'Error 11 - No Bank Exists for Vendor '
                        || r_ssb.payee_name
                        || ', Record '
                        || r_ssb.record_id);
                END IF;

                /* --- Bank Account --- */
                IF (ln_branch_id IS NOT NULL) AND (lb_err_status = FALSE)
                THEN
                    iby_ext_bankacct_pub.check_ext_acct_exist (
                        1.0,
                        fnd_api.g_false,
                        ln_bank_id,
                        ln_branch_id,
                        lc_acct_number,
                        lc_acct_name,
                        lc_currency,
                        lc_country_code,
                        ln_acct_id,
                        ld_start_date,
                        ld_end_date,
                        lc_return_status,
                        ln_msg_count,
                        lc_msg_data,
                        l_response);
                    /* --- Error handling --- */
                    lc_return_status   := lc_return_status;
                    ln_msg_count       := ln_msg_count;
                    lc_msg_data        := lc_msg_data;

                    IF lc_return_status <> fnd_api.g_ret_sts_success
                    THEN
                        log_records (
                            p_debug,
                               'Error 12 - Error while checking Bank Account for Vendor '
                            || r_ssb.payee_name
                            || ', Record '
                            || r_ssb.record_id);
                        lb_err_status   := TRUE;

                        IF ln_msg_count > 0
                        THEN
                            lc_msg_data   := NULL;

                            FOR i IN 1 .. ln_msg_count
                            LOOP
                                lc_msg_data   := fnd_msg_pub.get (i, 'F');
                                log_records (
                                    p_debug,
                                    'Error 12.' || i || ' - ' || lc_msg_data);
                            END LOOP;

                            xxd_common_utils.record_error (
                                'AP',
                                xxd_common_utils.get_org_id,
                                'XXD AP Supplier Bank Conv Import ',
                                   'Error while checking Bank Account for Vendor  - '
                                || lc_msg_data,
                                DBMS_UTILITY.format_error_backtrace,
                                fnd_profile.VALUE ('USER_ID'),
                                gn_conc_request_id,
                                r_ssb.bank_account_num,
                                r_ssb.bank_account_name,
                                r_ssb.old_vendor_id,
                                r_ssb.vendor_site_code);
                        END IF;
                    END IF;

                    IF (ln_acct_id IS NULL) AND (lb_err_status = FALSE)
                    THEN
                        BEGIN
                            log_records (
                                p_debug,
                                   'Creating Ext Acct '
                                || ln_bank_id
                                || '-'
                                || ln_branch_id
                                || '-'
                                || ln_party_id);
                            /* Assign variables to Account_New record type variable */
                            account_new.country_code                  := r_ssb.country;
                            account_new.bank_account_name             :=
                                r_ssb.bank_account_name;
                            account_new.bank_account_num              :=
                                r_ssb.bank_account_num;
                            --lc_association_level := r_ssb.assignment_level;
                            account_new.currency                      :=
                                r_ssb.currency_code;
                            --account_new.iban := r_ssb.iban_number;
                            account_new.iban                          := NULL;
                            account_new.multi_currency_allowed_flag   :=
                                r_ssb.multi_currency_allowed_flag;
                            account_new.acct_type                     :=
                                r_ssb.bank_account_type; --Added by BT Team on 24/07/2015 1.4
                            account_new.branch_id                     :=
                                ln_branch_id;
                            account_new.bank_id                       :=
                                ln_bank_id;
                            account_new.acct_owner_party_id           :=
                                ln_party_id;
                            account_new.status                        := 'A';
                            account_new.end_date                      := NULL;
                            -- Changes made by BT Team on 4/26
                            --                     account_new.start_date := SYSDATE;
                            account_new.start_date                    :=
                                r_ssb.start_date;
                            account_new.foreign_payment_use_flag      := 'Y'; --r_ssb.foreign_payment_use_flag; --Added BY BT Technology Team ON 16-Jun-2015 1.3
                            account_new.check_digits                  :=
                                r_ssb.check_digits;
                            account_new.alternate_acct_name           :=
                                r_ssb.alternate_account_name;
                            --                      account_new.bank_code := r_ssb.bank_code;
                            account_new.description                   :=
                                r_ssb.bank_acct_desc;
                            account_new.short_acct_name               :=
                                r_ssb.short_acct_name;
                            account_new.acct_suffix                   :=
                                r_ssb.account_suffix;
                            --End of changes made by BT Team on 4/26
                            account_new.object_version_number         := 1;

                            IBY_EXT_BANKACCT_PUB.create_ext_bank_acct (
                                1.0,
                                fnd_api.g_false,
                                account_new,
                                ln_acct_id,
                                lc_return_status,
                                ln_msg_count,
                                lc_msg_data,
                                l_response);
                            /* --- Error handling --- */
                            lc_return_status                          :=
                                lc_return_status;
                            ln_msg_count                              :=
                                ln_msg_count;
                            lc_msg_data                               :=
                                lc_msg_data;

                            IF lc_return_status <> fnd_api.g_ret_sts_success
                            THEN
                                log_records (
                                    p_debug,
                                       'Error 13 - Error while creating Bank Account for Vendor '
                                    || r_ssb.payee_name
                                    || ', Record '
                                    || r_ssb.record_id);
                                lb_err_status   := TRUE;

                                IF ln_msg_count > 0
                                THEN
                                    lc_msg_data   := NULL;

                                    FOR i IN 1 .. ln_msg_count
                                    LOOP
                                        lc_msg_data   :=
                                            fnd_msg_pub.get (i, 'F');
                                        log_records (
                                            p_debug,
                                               'Error 13.'
                                            || i
                                            || ' - '
                                            || lc_msg_data);
                                    END LOOP;

                                    xxd_common_utils.record_error (
                                        'AP',
                                        xxd_common_utils.get_org_id,
                                        'XXD AP Supplier Bank Conv Import ',
                                           'Error while creating Bank Account for Vendor   - '
                                        || lc_msg_data,
                                        DBMS_UTILITY.format_error_backtrace,
                                        fnd_profile.VALUE ('USER_ID'),
                                        gn_conc_request_id,
                                        r_ssb.bank_account_num,
                                        r_ssb.bank_account_name,
                                        r_ssb.old_vendor_id,
                                        r_ssb.vendor_site_code);
                                END IF;
                            ELSIF lc_return_status =
                                  fnd_api.g_ret_sts_success
                            THEN
                                log_records (
                                    p_debug,
                                       'Bank Account '
                                    || r_ssb.bank_account_num
                                    || ' successfully created for Vendor '
                                    || r_ssb.payee_name
                                    || ', Record '
                                    || r_ssb.record_id);
                                ln_bank_account_count   :=
                                    ln_bank_account_count + 1;
                            END IF;

                            /* Assign Local variables for payment instrument */
                            IF lb_err_status = FALSE
                            THEN
                                /* Assign variables to p_payee record type variable */
                                log_records (
                                    p_debug,
                                    'Assigning Account to Supplier ' || r_ssb.payee_name);

                                p_payee.party_id                  := ln_party_id;
                                p_payee.payment_function          := 'PAYABLES_DISB';
                                p_payee.supplier_site_id          :=
                                    ln_supplier_site_id;
                                --Site with org id and type
                                p_payee.party_site_id             :=
                                    ln_party_site_id;               -- Address
                                p_payee.org_id                    := ln_org_id;
                                --p_payee.org_type := lc_org_type;       --Commented by BT Technology Team on 27-Apr-2015 for assignment correction
                                p_payee.org_type                  :=
                                    'OPERATING_UNIT'; --Added by BT Technology Team on 27-Apr-2015 for assignment correction
                                p_instrument.instrument_type      :=
                                    'BANKACCOUNT';
                                p_instrument.instrument_id        := ln_acct_id;
                                p_assignment_attribs.instrument   :=
                                    p_instrument;
                                p_assignment_attribs.priority     := 1;
                                -- Changes made by BT Team on 4/26
                                p_assignment_attribs.start_date   :=
                                    r_ssb.start_date;
                                -- End of changes made by BT Team on 4/26
                                iby_disbursement_setup_pub.set_payee_instr_assignment (
                                    1.0,
                                    fnd_api.g_false,
                                    fnd_api.g_true,
                                    lc_return_status,
                                    ln_msg_count,
                                    lc_msg_data,
                                    p_payee,
                                    p_assignment_attribs,
                                    ln_assign_id,
                                    l_response);
                                /* --- Error handling --- */
                                lc_return_status                  :=
                                    lc_return_status;
                                ln_msg_count                      :=
                                    ln_msg_count;
                                lc_msg_data                       :=
                                    lc_msg_data;

                                IF lc_return_status <>
                                   fnd_api.g_ret_sts_success
                                THEN
                                    log_records (
                                        p_debug,
                                           'Error 14 - Error while assigning Account to Supplier for Vendor '
                                        || r_ssb.payee_name
                                        || ', Record '
                                        || r_ssb.record_id);
                                    lb_err_status   := TRUE;

                                    IF ln_msg_count > 0
                                    THEN
                                        lc_msg_data   := NULL;

                                        FOR i IN 1 .. ln_msg_count
                                        LOOP
                                            lc_msg_data   :=
                                                fnd_msg_pub.get (i, 'F');
                                            log_records (
                                                p_debug,
                                                   'Error 14.'
                                                || i
                                                || ' - '
                                                || lc_msg_data);
                                        END LOOP;

                                        xxd_common_utils.record_error (
                                            'AP',
                                            xxd_common_utils.get_org_id,
                                            'XXD AP Supplier Bank Conv Import ',
                                               'Error while assigning Account to Supplier for Vendor   - '
                                            || lc_msg_data,
                                            DBMS_UTILITY.format_error_backtrace,
                                            fnd_profile.VALUE ('USER_ID'),
                                            gn_conc_request_id,
                                            r_ssb.bank_account_num,
                                            r_ssb.bank_account_name,
                                            r_ssb.old_vendor_id,
                                            r_ssb.vendor_site_code);
                                    END IF;
                                ELSIF lc_return_status =
                                      fnd_api.g_ret_sts_success
                                THEN
                                    log_records (
                                        p_debug,
                                           'Bank Account '
                                        || r_ssb.bank_account_num
                                        || ' assigned for Vendor '
                                        || r_ssb.payee_name
                                        || ', Record '
                                        || r_ssb.record_id);
                                    COMMIT;
                                END IF;
                            END IF;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lc_error_description   :=
                                       SQLCODE
                                    || ' : '
                                    || SQLERRM
                                    || ' for Vendor '
                                    || r_ssb.payee_name
                                    || ', Record '
                                    || r_ssb.record_id;
                                x_retcode        := ln_retcode_warning;
                                lb_err_status    := TRUE;
                                lb_warning_chk   := TRUE;
                                log_records (
                                    p_debug,
                                    'Error 15 - ' || lc_error_description);
                                xxd_common_utils.record_error (
                                    'AP',
                                    xxd_common_utils.get_org_id,
                                    'XXD AP Supplier Bank Conv Import ',
                                       'When other exception at the creation of bank account   - '
                                    || lc_error_description,
                                    DBMS_UTILITY.format_error_backtrace,
                                    fnd_profile.VALUE ('USER_ID'),
                                    gn_conc_request_id,
                                    r_ssb.bank_account_num,
                                    r_ssb.bank_account_name,
                                    r_ssb.old_vendor_id,
                                    r_ssb.vendor_site_code);
                        END;
                    ELSE
                        log_records (
                            p_debug,
                               'This is Existing Account : '
                            || ln_acct_id
                            || ' for Vendor '
                            || r_ssb.payee_name
                            || ', Record '
                            || r_ssb.record_id);
                        xxd_common_utils.record_error (
                            'AP',
                            xxd_common_utils.get_org_id,
                            'XXD AP Supplier Bank Conv Import ',
                               'This is Existing Account : '
                            || ln_acct_id
                            || ' for Vendor '
                            || r_ssb.payee_name
                            || ', Record '
                            || r_ssb.record_id,
                            DBMS_UTILITY.format_error_backtrace,
                            fnd_profile.VALUE ('USER_ID'),
                            gn_conc_request_id,
                            r_ssb.bank_account_num,
                            r_ssb.bank_account_name,
                            r_ssb.old_vendor_id,
                            r_ssb.vendor_site_code);
                    END IF;
                ELSE
                    log_records (
                        p_debug,
                           'No Branch Exists for Vendor '
                        || r_ssb.payee_name
                        || ', Record '
                        || r_ssb.record_id);
                    xxd_common_utils.record_error (
                        'AP',
                        xxd_common_utils.get_org_id,
                        'XXD AP Supplier Bank Conv Import ',
                           'No Branch Exists for Vendor '
                        || r_ssb.payee_name
                        || ', Record '
                        || r_ssb.record_id,
                        DBMS_UTILITY.format_error_backtrace,
                        fnd_profile.VALUE ('USER_ID'),
                        gn_conc_request_id,
                        r_ssb.bank_account_num,
                        r_ssb.bank_account_name,
                        r_ssb.old_vendor_id,
                        r_ssb.vendor_site_code);
                END IF;

                IF lb_err_status = FALSE
                THEN
                    UPDATE xxd_ap_sup_bank_cnv_stg_t
                       SET record_status = 'P', last_updated_by = ln_last_updated_by, last_update_date = ld_last_update_date,
                           last_update_login = ln_last_update_login
                     WHERE record_id = r_ssb.record_id;
                ELSE
                    UPDATE xxd_ap_sup_bank_cnv_stg_t
                       SET record_status = 'E', error_message = 'Bank Account Creation Failed, Pls see Log', last_updated_by = ln_last_updated_by,
                           last_update_date = ld_last_update_date, last_update_login = ln_last_update_login
                     WHERE record_id = r_ssb.record_id;
                END IF;

                COMMIT;
            END;
        END LOOP;

        /* fnd_file.put_line
            (fnd_file.output,
             '**************************************************************************************************'
            );
         fnd_file.put_line (fnd_file.output,
                               'Total Number of  Bank Account Created-  '
                            || ln_bank_count
                           );
         fnd_file.put_line (fnd_file.output,
                               'Total Number of Bank Branch Created-  '
                            || ln_branch_count
                           );
         fnd_file.put_line (fnd_file.output,
                               'Total Number of Bank Account Created-  '
                            || ln_bank_account_count
                           );
         fnd_file.put_line
            (fnd_file.output,
             '**************************************************************************************************'
            );
          */
        print_processing_summary (p_debug, 'Bank', x_retcode);
    END supp_bank_acct;

    PROCEDURE main (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, p_mode IN VARCHAR2
                    , p_debug IN VARCHAR2)
    IS
    BEGIN
        SELECT user_name
          INTO gc_user_name
          FROM fnd_user
         WHERE user_id = fnd_profile.VALUE ('USER_ID');

        SELECT instance_name INTO gc_dbname FROM v$instance@bt_read_1206;

        IF p_mode = gc_extract_only
        THEN
            extract_r1206_supplier_info (x_errbuf, x_retcode, p_debug);
        ELSIF p_mode = gc_validate_only
        THEN
            validate_supplier_info (x_errbuf, x_retcode, 'V',
                                    p_debug);
            print_processing_summary (p_debug, gc_validate_only, x_retcode);
        ELSIF p_mode = gc_load_only
        THEN
            validate_supplier_info (x_errbuf, x_retcode, 'L',
                                    p_debug);
            print_processing_summary (p_debug, gc_load_only, x_errbuf);
        END IF;
    END;

    PROCEDURE GET_ORG_ID (p_org_name   IN            VARCHAR2,
                          x_org_id        OUT NOCOPY NUMBER,
                          x_org_name      OUT NOCOPY VARCHAR2)
    -- +===================================================================+

    -- | Name  : GET_ORG_ID                                                |
    -- | Description      : This procedure  is used to get                 |
    -- |                    org id from EBS                                |
    -- |                                                                   |
    -- | Parameters : p_org_name,p_request_id,p_inter_head_id              |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_org_id                                                |
    -- |                                                                   |
    -- +===================================================================+
    IS
        px_lookup_code   VARCHAR2 (250);
        px_meaning       VARCHAR2 (250);        -- internal name of old entity
        px_description   VARCHAR2 (250);             -- name of the old entity
        x_attribute1     VARCHAR2 (250);     -- corresponding new 12.2.3 value
        x_attribute2     VARCHAR2 (250);
        x_error_code     VARCHAR2 (250);
        x_error_msg      VARCHAR (250);
    BEGIN
        px_meaning   := p_org_name;
        apps.XXD_COMMON_UTILS.get_mapping_value (
            p_lookup_type    => 'XXD_1206_OU_MAPPING', -- Lookup type for mapping
            px_lookup_code   => px_lookup_code, -- Would generally be id of 12.0.6. eg: org_id
            px_meaning       => px_meaning,     -- internal name of old entity
            px_description   => px_description,      -- name of the old entity
            x_attribute1     => x_attribute1, -- corresponding new 12.2.3 value
            x_attribute2     => x_attribute2,
            x_error_code     => x_error_code,
            x_error_msg      => x_error_msg);

        IF x_attribute1 IS NOT NULL
        THEN
            x_org_name   := x_attribute1;

            SELECT organization_id
              INTO x_org_id
              FROM hr_operating_units
             WHERE UPPER (NAME) = UPPER (x_attribute1);
        ELSE
            x_org_id     := NULL;
            x_org_name   := NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'AP',
                xxd_common_utils.get_org_id,
                'XXD Open Purchase Orders Conversion Program',
                --      SQLCODE,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                fnd_profile.VALUE ('USER_ID'),
                gn_conc_request_id,
                'GET_ORG_ID',
                p_org_name,
                'Exception to GET_ORG_ID Procedure' || SQLERRM);

            x_org_id     := NULL;
            x_org_name   := NULL;
    END GET_ORG_ID;

    PROCEDURE print_processing_summary (p_debug IN VARCHAR2, p_mode IN VARCHAR2, x_ret_code OUT NUMBER)
    IS
        -- Supplier Count
        ln_process_cnt         NUMBER := 0;
        ln_error_cnt           NUMBER := 0;
        ln_validate_cnt        NUMBER := 0;
        ln_total               NUMBER := 0;

        --Supplier Site Count
        ln_line_process_cnt    NUMBER := 0;
        ln_line_error_cnt      NUMBER := 0;
        ln_line_validate_cnt   NUMBER := 0;
        ln_line_total          NUMBER := 0;

        --Supplier Contact Count
        ln_cnt_process_cnt     NUMBER := 0;
        ln_cnt_error_cnt       NUMBER := 0;
        ln_cnt_validate_cnt    NUMBER := 0;
        ln_cnt_total           NUMBER := 0;

        --Supplier Contact Count
        ln_bank_process_cnt    NUMBER := 0;
        ln_bank_error_cnt      NUMBER := 0;
        ln_bank_validate_cnt   NUMBER := 0;
        ln_bank_total          NUMBER := 0;
    BEGIN
        x_ret_code   := gn_suc_const;

        ---------------------------------------------------------------
        --Fetch the summary details from the staging table
        ----------------------------------------------------------------
        SELECT COUNT (DECODE (record_status, gc_process_status, gc_process_status)), COUNT (DECODE (record_status, gc_error_status, gc_error_status)), COUNT (DECODE (record_status, gc_validate_status, gc_validate_status)),
               COUNT (1)
          INTO ln_process_cnt, ln_error_cnt, ln_validate_cnt, ln_total
          FROM xxd_ap_suppliers_cnv_stg_t
         WHERE request_id = gn_conc_request_id;

        SELECT COUNT (DECODE (record_status, gc_process_status, gc_process_status)), COUNT (DECODE (record_status, gc_error_status, gc_error_status)), COUNT (DECODE (record_status, gc_validate_status, gc_validate_status)),
               COUNT (1)
          INTO ln_line_process_cnt, ln_line_error_cnt, ln_line_validate_cnt, ln_line_total
          FROM xxd_ap_sup_sites_cnv_stg_t
         WHERE request_id = gn_conc_request_id;

        SELECT COUNT (DECODE (record_status, gc_process_status, gc_process_status)), COUNT (DECODE (record_status, gc_error_status, gc_error_status)), COUNT (DECODE (record_status, gc_validate_status, gc_validate_status)),
               COUNT (1)
          INTO ln_cnt_process_cnt, ln_cnt_error_cnt, ln_cnt_validate_cnt, ln_cnt_total
          FROM xxd_conv.xxd_ap_sup_site_con_cnv_stg_t
         WHERE request_id = gn_conc_request_id;

        SELECT COUNT (DECODE (record_status, gc_process_status, gc_process_status)), COUNT (DECODE (record_status, gc_error_status, gc_error_status)), COUNT (DECODE (record_status, gc_validate_status, gc_validate_status)),
               COUNT (1)
          INTO ln_bank_process_cnt, ln_bank_error_cnt, ln_bank_validate_cnt, ln_bank_total
          FROM xxd_ap_sup_bank_cnv_stg_t
         WHERE request_id = gn_conc_request_id;

        IF p_mode <> 'Bank'
        THEN
            log_records (
                p_debug,
                   'Processed  => '
                || ln_process_cnt
                || ' Error      => '
                || ln_error_cnt
                || ' Valid      => '
                || ln_validate_cnt
                || ' Total      => '
                || ln_total);


            fnd_file.put_line (
                fnd_file.output,
                '*************************************************************************************');
            fnd_file.put_line (
                fnd_file.output,
                '************************Summary Report***********************************************');
            fnd_file.put_line (
                fnd_file.output,
                '*************************************************************************************');
            fnd_file.put_line (fnd_file.output, '  ');
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of Supplier Records to '
                || p_mode
                || '                      : '
                || ln_total);
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of Supplier Records Successfully Validated               : '
                || ln_validate_cnt);
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of Supplier Records Successfully Processed               : '
                || ln_process_cnt);
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of Supplier Records In Error                             : '
                || ln_error_cnt);


            ------------------Supplier Sites------------------------

            fnd_file.put_line (
                fnd_file.output,
                '*************************************************************************************');
            fnd_file.put_line (fnd_file.output, '  ');
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of Supplier Line Records to '
                || p_mode
                || '                      : '
                || ln_line_total);
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of Supplier Line Records Successfully Validated                : '
                || ln_line_validate_cnt);
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of Supplier Line Records Successfully Processed                : '
                || ln_line_process_cnt);
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of Supplier Line Records In Error                              : '
                || ln_line_error_cnt);

            ---------------------------Supplier Contacts-------------------------------------------

            fnd_file.put_line (
                fnd_file.output,
                '*************************************************************************************');
            fnd_file.put_line (fnd_file.output, '  ');
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of Supplier Contact Records to '
                || p_mode
                || '                       : '
                || ln_cnt_total);
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of Supplier Contact Records Successfully Validated               : '
                || ln_cnt_validate_cnt);
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of Supplier Contact Records Successfully Processed               : '
                || ln_cnt_process_cnt);
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of Supplier Contact Records In Error                              : '
                || ln_cnt_error_cnt);

            -------------------------------Supplier Bank Validate-------------------------------------------

            fnd_file.put_line (
                fnd_file.output,
                '*************************************************************************************');
            fnd_file.put_line (fnd_file.output, '  ');
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of Supplier Bank Records to '
                || p_mode
                || '                         : '
                || ln_bank_total);
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of Supplier Bank Records Successfully Validated                   : '
                || ln_bank_validate_cnt);
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of Supplier Bank Records In Error                                 : '
                || ln_bank_error_cnt);

            fnd_file.put_line (
                fnd_file.output,
                '***************************************************************************************');

            fnd_file.put_line (fnd_file.output, '');
            fnd_file.put_line (fnd_file.output, '');
            fnd_file.put_line (fnd_file.output, '');
            fnd_file.put_line (fnd_file.output, '');
            fnd_file.put_line (fnd_file.output, '');
            fnd_file.put_line (fnd_file.output, '');
            fnd_file.put_line (
                fnd_file.output,
                   RPAD ('Object Name', 20, ' ')
                || '  '
                || RPAD ('1203 Supplier/Bank Acct Number', 20, ' ')
                || '  '
                || RPAD ('1203 Supplier Id', 20, ' ')
                || '  '
                || RPAD ('1203 Supplier Site Code', 20, ' ')
                || '  '
                || RPAD ('1203 Supplier Contact Id', 20, ' ')
                || '  '
                || RPAD ('Error Message', 500, ' '));
        ELSE
            -------------------------------Supplier Bank Import -------------------------------------------

            fnd_file.put_line (
                fnd_file.output,
                '*************************************************************************************');
            fnd_file.put_line (fnd_file.output, '  ');
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of Supplier Bank Records to import                                  : '
                || ln_bank_total);
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of Supplier Bank Records Successfully Import                         : '
                || ln_bank_process_cnt);
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of Supplier Bank Records In Error                                    : '
                || ln_bank_error_cnt);


            fnd_file.put_line (
                fnd_file.output,
                '***************************************************************************************');

            fnd_file.put_line (fnd_file.output, '');
            fnd_file.put_line (fnd_file.output, '');
            fnd_file.put_line (fnd_file.output, '');
            fnd_file.put_line (fnd_file.output, '');
            fnd_file.put_line (fnd_file.output, '');
            fnd_file.put_line (fnd_file.output, '');
            fnd_file.put_line (
                fnd_file.output,
                   RPAD ('Object Name', 20, ' ')
                || '  '
                || RPAD ('Bank Acct Number', 20, ' ')
                || '  '
                || RPAD ('Bank Acct Name ', 20, ' ')
                || '  '
                || RPAD ('1203 Supplier Id', 20, ' ')
                || '  '
                || RPAD ('1203 Supplier Site Code', 20, ' ')
                || '  '
                || RPAD ('Error Message', 500, ' '));
        END IF;

        fnd_file.put_line (
            fnd_file.output,
               RPAD ('--', 20, '-')
            || '  '
            || RPAD ('--', 20, '-')
            || '  '
            || RPAD ('--', 20, '-')
            || '  '
            || RPAD ('--', 20, '-')
            || '  '
            || RPAD ('--', 20, '-')
            || '  '
            || RPAD ('--', 500, '-'));

        FOR error_in IN (SELECT OBJECT_NAME, ERROR_MESSAGE, USEFUL_INFO1,
                                USEFUL_INFO2, USEFUL_INFO3, USEFUL_INFO4
                           FROM XXD_ERROR_LOG_T
                          WHERE REQUEST_ID = gn_conc_request_id)
        LOOP
            fnd_file.put_line (
                fnd_file.output,
                   RPAD (error_in.OBJECT_NAME, 20, ' ')
                || '  '
                || RPAD (error_in.USEFUL_INFO1, 20, ' ')
                || '  '
                || RPAD (NVL (error_in.USEFUL_INFO2, ' '), 20, ' ')
                || '  '
                || RPAD (NVL (error_in.USEFUL_INFO3, ' '), 20, ' ')
                || '  '
                || RPAD (NVL (error_in.USEFUL_INFO4, ' '), 20, ' ')
                || '  '
                || RPAD (error_in.ERROR_MESSAGE, 500, ' '));
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code   := gn_err_const;
            log_records (
                p_debug,
                   SUBSTR (SQLERRM, 1, 150)
                || ' Exception in print_processing_summary procedure ');
    END print_processing_summary;
END XXD_SUPPLIER_CONV_PKG;
/
