--
-- XXDOAR_SUPP_BNK_DTLS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:13 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOAR_SUPP_BNK_DTLS_PKG"
AS
    PROCEDURE main (errbuf OUT VARCHAR2, retcode OUT VARCHAR2)
    AS
    BEGIN
        owa_sylk_apps.show (
            p_query    =>
                'SELECT  pv.segment1 supplier_num, hp.party_name AS supplier_name,
                hp.party_number AS registry_id,
                pv.end_date_active inactive_date,
                DECODE
                    (SIGN (SYSDATE - NVL (pv.start_date_active, SYSDATE - 1)),
                     -1, ''INACTIVE'',
                     DECODE (SIGN (  NVL (pv.end_date_active, SYSDATE + 1)
                                   - SYSDATE
                                  ),
                             -1, ''INACTIVE'',
                             DECODE (pv.enabled_flag,
                                     ''N'', ''INACTIVE'',
                                     ''ACTIVE''
                                    )
                            )
                    ) active_inactive,
                hp.known_as AS alias_name,
                hp.organization_name_phonetic AS alternate_supplier_name,
                flv.meaning ven_type, 
                flv1.meaning org_type,
                parent.segment1 parent_sup_num,
                parent.vendor_name parent_sup_name,
                pv.one_time_flag one_time,
                pv.attribute1 vendor_code,
                pv.attribute2 tlo_enabled,
                pv.attribute5 comm_creation,
                pv.attribute6 ex_comm,
                pv.customer_num customer_number,
                pv.attribute4 ven_upd_cmnts,
                hzpuiorganizationprofileseo1.gsa_indicator_flag federal_agency,
                hzpuiorganizationprofileseo1.jgzz_fiscal_code tax_payer_id,
                hzpuiorganizationprofileseo1.tax_reference tax_reg_num,
                (select max(fad.creation_date) creation_date from apps.fnd_attached_documents fad,apps.po_vendors pv1 where entity_name = ''PO_VENDORS'' 
                and fad.pk1_value = pv1.vendor_id
                and pv1.vendor_id  = pv.vendor_id
                ) last_attachment_date,
                pv.tax_reporting_name, flv1.meaning org_type,
                DECODE(pv.allow_awt_flag,NULL,''N'',''N'',''N'',''Y'') allow_withholding_tax,
                pv.state_reportable_flag reportable_state, 
                pv.federal_reportable_flag reportable_federal,
                aptt.description AS income_tax_type,
                supp_accts.masked_bank_account_num AS sup_bank_account_number,
                supp_accts.masked_iban AS sup_iban, supp_accts.currency_code sup_currency_code,
                supp_bank.party_name AS sup_bank_name, supp_uses.start_date sup_start_date, supp_uses.end_date sup_end_date,
                supp_uses.order_of_preference sup_order_of_preference,
                supp_accts.bank_account_type sup_bank_account_type, supp_branch.eft_swift_code sup_eft_swift_code,
                supp_bankprofile.bank_or_branch_number AS sup_bank_number,
                supp_branch.bank_branch_name sup_bank_branch_name, supp_branch.branch_number sup_branch_number,
                DECODE (UPPER (pv.vendor_type_lookup_code),
                        ''EMPLOYEE'', papf.national_identifier,
                        DECODE (pv.organization_type_lookup_code,
                                ''INDIVIDUAL'', pv.individual_1099,
                                ''FOREIGN INDIVIDUAL'', pv.individual_1099,
                                hp.jgzz_fiscal_code
                               )
                       ) taxpayer_id,
                hrou.NAME AS operating_unit,
                (select location_code from apps.hr_locations where location_id = pvsa.ship_to_location_id) ship_to_location,
                (select location_code from apps.hr_locations where location_id = pvsa.bill_to_location_id) bill_to_location,
                pvsa.ship_via_lookup_code ship_via, pvsa.pay_on_code pay_on,
                pay_site.vendor_site_code alt_pay_site,
                pvsa.pay_on_receipt_summary_code inv_summary_level,
                pvsa.create_debit_memo_flag,
                pvsa.selling_company_identifier comp_identifier,
                pvsa.fob_lookup_code fob,
                pvsa.freight_terms_lookup_code freight_terms,
                pvsa.shipping_control transportation,
                cor.territory_short_name AS country_of_origin_name,
                pvsa.invoice_amount_limit inv_amt_limit,
                pvsa.tolerance_id inv_tolerance, 
                DECODE(pvsa.match_option,''P'',''Purchase Order'',''R'',''Receipt'',NULL) match_option,
                pvsa.invoice_currency_code inv_curr_code,
                pvsa.hold_all_payments_flag,
                pvsa.hold_unmatched_invoices_flag,
                pvsa.hold_future_payments_flag, pvsa.hold_reason,
                pvsa.payment_currency_code, pvsa.payment_priority,
                pvsa.pay_group_lookup_code,
                flv_pay.meaning default_payment_method_site,
                (SELECT NAME
                   FROM apps.ap_terms
                  WHERE term_id = pvsa.terms_id) terms, pvsa.terms_date_basis,
                pvsa.pay_date_basis_lookup_code, pvsa.retainage_rate,
                pvsa.always_take_disc_flag,
                pvsa.exclude_freight_from_discount,
                hzl.address1
                 || '' , ''
                 || hzl.address2
                 || '' , ''
                 || hzl.address3
                 || '' , ''
                 || hzl.address4
                 || '' , ''
                 || hzl.city
                 || '' , ''
                 || hzl.county
                 || '' , ''
                 || hzl.state
                 || '' , ''
                 || hzl.province
                 || '' , ''
                 || hzl.postal_code
                 || '' , ''
                 || fvl.territory_short_name AS address_detail_int,
                 hzl.address1 Address_line1,
                 hzl.address2 Address_line2,
                 hzl.address3 Address_line3,
                 hzl.address4 Address_line4,
                 hzl.city City,
                 hzl.county County,
                 hzl.state State,
                 hzl.postal_code postal_code,
                 fvl.territory_short_name country_name,
                 phone.raw_phone_number phone,
                 fax.raw_phone_number fax,
                 email.email_address email,
                 pvsa.vendor_site_code site_name,				
                 DECODE (SIGN (NVL (pvsa.inactive_date, SYSDATE + 1) - SYSDATE),-1, ''INACTIVE'',''ACTIVE'') SITE_STATUS,
                 pvsa.INACTIVE_DATE site_inactive_date,
                 DECODE (pay.site_use_type, ''PAY'', ''Payment'', NULL)||'' , ''||DECODE (pur.site_use_type,''PURCHASING'', ''Purchasing'',NULL)||'' , ''||
                 DECODE (rfq.site_use_type, ''RFQ'', ''RFQ'', NULL) purpose,
                 ''Email: ''||email.email_address||'' , ''||''Phone: ''||phone.raw_phone_number||'', ''||''Fax: ''||fax.raw_phone_number communication,
                 NVL(accts.bank_account_name,supp_accts.bank_account_name) bank_account_name,
                accts.masked_bank_account_num AS bank_account_number,
                accts.masked_iban AS iban, accts.currency_code,
                bank.party_name AS bank_name, uses.start_date, uses.end_date,
                uses.order_of_preference,
                accts.bank_account_type, branch.eft_swift_code,
                bankprofile.bank_or_branch_number AS bank_number,
                branch.bank_branch_name, branch.branch_number
                ,supp_payee.REMIT_ADVICE_EMAIL "Remittance email",
				pvsa.email_address as "SITE_COMMUNICATION_EMAIL_ADDR"			 
           FROM apps.ap_suppliers pv,
                apps.ap_awt_groups aag,
                apps.rcv_routing_headers rcpt,
                apps.fnd_currencies_tl fct,
                apps.fnd_currencies_tl pay,
                apps.fnd_lookup_values pay_group,
                apps.ap_terms_tl terms,
                apps.ap_suppliers PARENT,
                apps.per_employees_current_x emp,
                apps.hz_parties hp,
                apps.fnd_lookup_values flv,
                apps.fnd_lookup_values flv1,
                apps.hz_party_sites hps,
                apps.ap_income_tax_types aptt,
                apps.per_all_people_f papf,
                apps.hz_organization_profiles_v hzpuiorganizationprofileseo1,
                apps.fnd_currencies_vl ctl,
                apps.ap_supplier_sites_all pvsa,
                apps.hr_operating_units hrou,
                apps.ap_supplier_sites_all pay_site,
                apps.fnd_territories_vl cor,
                apps.fnd_territories_vl fvl,
                apps.hz_locations hzl,
                apps.ap_distribution_sets ads,
                apps.po_location_associations poas,
                apps.ap_system_parameters_all ap_param,
                apps.iby_pmt_instr_uses_all uses,
                apps.iby_pmt_instr_uses_all supp_uses,
                apps.iby_external_payees_all payee,
                apps.iby_external_payees_all supp_payee,
                apps.iby_ext_bank_accounts accts,
                apps.iby_ext_bank_accounts supp_accts,
                apps.fnd_currencies_vl fc,
                apps.fnd_currencies_vl supp_fc,
                apps.hz_parties bank,
                apps.hz_parties supp_bank,
                apps.hz_organization_profiles bankprofile,
                apps.hz_organization_profiles supp_bankprofile,
                apps.ce_bank_branches_v branch,
                apps.ce_bank_branches_v supp_branch,
                apps.hz_contact_points email,
                 apps.hz_contact_points phone,
                 apps.hz_contact_points fax,
                 apps.hz_party_site_uses pay,
                 apps.hz_party_site_uses pur,
                 apps.hz_party_site_uses rfq,
                 apps.iby_ext_party_pmt_mthds ieppm,
                 apps.fnd_lookup_values flv_pay
          WHERE 1 = 1
            AND pv.party_id = hp.party_id
            AND (hp.party_id = hps.party_id OR hps.party_id is NULL)
            AND pv.parent_vendor_id = PARENT.vendor_id(+)
            AND pv.awt_group_id = aag.GROUP_ID(+)
            AND pv.receiving_routing_id = rcpt.routing_header_id(+)
            AND fct.LANGUAGE(+) = USERENV (''lang'')
            AND pay.LANGUAGE(+) = USERENV (''lang'')
            AND pv.invoice_currency_code = fct.currency_code(+)
            AND pv.payment_currency_code = pay.currency_code(+)
            AND pv.pay_group_lookup_code = pay_group.lookup_code(+)
            AND pay_group.lookup_type(+) = ''PAY GROUP''
            AND pay_group.LANGUAGE(+) = USERENV (''lang'')
            AND pv.terms_id = terms.term_id(+)
            AND terms.LANGUAGE(+) = USERENV (''LANG'')
            AND terms.enabled_flag(+) = ''Y''
            AND flv.lookup_type(+) = ''VENDOR TYPE''
            AND flv.LANGUAGE(+) = USERENV (''LANG'')
            AND flv.lookup_code(+) = pv.vendor_type_lookup_code
            AND flv1.lookup_type(+) = ''ORGANIZATION TYPE''
            AND flv1.LANGUAGE(+) = USERENV (''LANG'')
            AND flv1.lookup_code(+) = pv.organization_type_lookup_code
            AND pv.employee_id = emp.employee_id(+)
            AND pv.employee_id = papf.person_id(+)
            AND pv.type_1099 = aptt.income_tax_type(+)
            AND pv.vendor_id = pvsa.vendor_id
            AND hzpuiorganizationprofileseo1.effective_end_date IS NULL
            AND hzpuiorganizationprofileseo1.pref_functional_currency = ctl.currency_code(+)
            AND hzpuiorganizationprofileseo1.party_id(+) = hp.party_id
            AND poas.vendor_id(+) = pvsa.vendor_id
            AND poas.vendor_site_id(+) = pvsa.vendor_site_id
            --AND hzl.location_id = pvsa.location_id
            AND hrou.organization_id = pvsa.org_id
            AND pvsa.default_pay_site_id = pay_site.vendor_site_id(+)
            AND pvsa.country_of_origin_code = cor.territory_code(+)
            AND hzl.country = fvl.territory_code(+)
            AND pvsa.distribution_set_id = ads.distribution_set_id(+)
            AND pvsa.org_id = ap_param.org_id
            AND uses.instrument_type(+) = ''BANKACCOUNT''
            AND supp_uses.instrument_type(+) = ''BANKACCOUNT''
            AND payee.ext_payee_id = uses.ext_pmt_party_id(+)
            AND supp_payee.ext_payee_id = supp_uses.ext_pmt_party_id(+)
            AND payee.payee_party_id = hp.party_id(+)
            AND supp_payee.payee_party_id(+) = hp.party_id
            AND payee.payment_function(+) = ''PAYABLES_DISB''
            AND supp_payee.payment_function(+) = ''PAYABLES_DISB''
            AND payee.party_site_id = hps.party_site_id(+)
            AND supp_payee.party_site_id IS NULL
            AND payee.org_id = hrou.organization_id(+)
            AND payee.supplier_site_id = pvsa.vendor_site_id(+)
            AND supp_payee.supplier_site_id IS NULL
            AND payee.ext_payee_id  = ieppm.ext_pmt_party_id (+)
            AND NVL(ieppm.inactive_date, SYSDATE+1) > SYSDATE
            AND ieppm.primary_flag (+) = ''Y''
            AND ieppm.payment_method_code = flv_pay.lookup_code (+)
            AND flv_pay.lookup_type(+) = ''PAYMENT METHOD'' 
            AND flv_pay.language(+) = ''US''
            AND uses.instrument_id = accts.ext_bank_account_id(+)
            AND supp_uses.instrument_id = supp_accts.ext_bank_account_id(+)
            AND fc.currency_code(+) = accts.currency_code
            AND supp_fc.currency_code(+) = supp_accts.currency_code
            AND SYSDATE BETWEEN NVL (accts.start_date, SYSDATE)
                            AND NVL (accts.end_date, SYSDATE)
            AND SYSDATE BETWEEN NVL (supp_accts.start_date, SYSDATE)
                            AND NVL (supp_accts.end_date, SYSDATE)
            AND accts.bank_id = bank.party_id(+)
            AND supp_accts.bank_id = supp_bank.party_id(+)
            AND accts.bank_id = bankprofile.party_id(+)
            AND supp_accts.bank_id = supp_bankprofile.party_id(+)
            AND accts.branch_id = branch.branch_party_id(+)
            AND supp_accts.branch_id = supp_branch.branch_party_id(+)
            AND SYSDATE BETWEEN TRUNC (bankprofile.effective_start_date(+)) AND NVL(TRUNC(bankprofile.effective_end_date(+)),SYSDATE + 1)
            AND SYSDATE BETWEEN TRUNC (supp_bankprofile.effective_start_date(+)) AND NVL(TRUNC(supp_bankprofile.effective_end_date(+)),SYSDATE + 1)
            AND email.owner_table_id(+) = hps.party_site_id
             AND email.owner_table_name(+) = ''HZ_PARTY_SITES''
             AND email.status(+) = ''A''
             AND email.contact_point_type(+) = ''EMAIL''
             AND email.primary_flag(+) = ''Y''
             AND phone.owner_table_id(+) = hps.party_site_id
             AND phone.owner_table_name(+) = ''HZ_PARTY_SITES''
             AND phone.status(+) = ''A''
             AND phone.contact_point_type(+) = ''PHONE''
             AND phone.phone_line_type(+) = ''GEN''
             AND phone.primary_flag(+) = ''Y''
             AND fax.owner_table_id(+) = hps.party_site_id
             AND fax.owner_table_name(+) = ''HZ_PARTY_SITES''
             AND fax.status(+) = ''A''
             AND fax.contact_point_type(+) = ''PHONE''
             AND fax.phone_line_type(+) = ''FAX''
             AND hps.location_id = hzl.location_id(+)
             AND pay.party_site_id(+) = hps.party_site_id
             AND pur.party_site_id(+) = hps.party_site_id
             AND rfq.party_site_id(+) = hps.party_site_id
             AND pay.status(+) = ''A''
             AND pur.status(+) = ''A''
             AND rfq.status(+) = ''A''
             AND NVL (pay.end_date(+), SYSDATE) >= SYSDATE
             AND NVL (pur.end_date(+), SYSDATE) >= SYSDATE
             AND NVL (rfq.end_date(+), SYSDATE) >= SYSDATE
             AND NVL (pay.begin_date(+), SYSDATE) <= SYSDATE
             AND NVL (pur.begin_date(+), SYSDATE) <= SYSDATE
             AND NVL (rfq.begin_date(+), SYSDATE) <= SYSDATE
             AND pay.site_use_type(+) = ''PAY''
             AND pur.site_use_type(+) = ''PURCHASING''
             AND rfq.site_use_type(+) = ''RFQ''
            AND DECODE
                    (SIGN (SYSDATE - NVL (pv.start_date_active, SYSDATE - 1)),
                     -1, ''INACTIVE'',
                     DECODE (SIGN (  NVL (pv.end_date_active, SYSDATE + 1)
                                   - SYSDATE
                                  ),
                             -1, ''INACTIVE'',
                             DECODE (pv.enabled_flag,
                                     ''N'', ''INACTIVE'',
                                     ''ACTIVE''
                                    )
                            )
                    ) = ''ACTIVE''
                    order by hrou.name, pv.segment1',
            p_widths   => owa_sylk_apps.owaSylkArray (20, 20, 20,
                                                      20));
    END main;
END XXDOAR_SUPP_BNK_DTLS_PKG;
/
