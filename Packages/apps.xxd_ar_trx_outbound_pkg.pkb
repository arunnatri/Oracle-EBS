--
-- XXD_AR_TRX_OUTBOUND_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:18 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AR_TRX_OUTBOUND_PKG"
AS
    /***************************************************************************************
    * Program Name : XXDO_AR_TRX_OUTBOUND_PKG                                              *
    * Language     : PL/SQL                                                                *
    * Description  : Package to generate outbound files for Pagero integration             *
    *                                                                                      *
    * History      :                                                                       *
    *                                                                                      *
    * WHO          :       WHAT      Desc                                    WHEN          *
    * -------------- ----------------------------------------------------------------------*
    * Kishan Reddy         1.0       Initial Version                         10-MAY-2022   *
    * Kishan Reddy         1.1       CCR0010453 : File generation issue      08-FEB-2023   *
    * Pardeep Rohilla   1.2  CCR0010450 : Business Reg Number     02-MAR-2023   *
    * -------------------------------------------------------------------------------------*/
    -- ====================================================================================
    -- Set values for Global Variables
    -- ====================================================================================
    -- Modifed to init G variable from input params

    gn_user_id           CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id          CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id            CONSTANT NUMBER := fnd_global.org_id;
    gn_resp_id           CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id      CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_conc_request_id   CONSTANT NUMBER := fnd_global.conc_request_id;
    gv_package_name      CONSTANT VARCHAR (30) := 'XXD_AR_PGR_OUTBOUND_PKG';
    ex_no_recips                  EXCEPTION;
    gv_time_stamp                 VARCHAR2 (40)
        := TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS');
    gv_file_time_stamp            VARCHAR2 (40)
                                      := TO_CHAR (SYSDATE, 'DD-MON-YYYY');
    gv_def_mail_recips            do_mail_utils.tbl_recips;

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

    PROCEDURE add_error_message (p_cust_trx_id     IN NUMBER,
                                 p_trx_number      IN VARCHAR2,
                                 p_trx_date        IN DATE,
                                 p_error_code      IN VARCHAR2,
                                 p_error_message   IN VARCHAR2)
    IS
    BEGIN
        g_index                               := g_index + 1;
        g_error_tbl (g_index).trx_id          := p_cust_trx_id;
        g_error_tbl (g_index).trx_number      := p_trx_number;
        g_error_tbl (g_index).trx_date        := p_trx_date;
        g_error_tbl (g_index).ERROR_CODE      := p_error_code;
        g_error_tbl (g_index).error_message   := p_error_message;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                ' Unexpected error in procedure add_error_message');
            fnd_file.put_line (
                fnd_file.LOG,
                'Error Message : ' || SUBSTR (SQLERRM, 1, 240));
    END add_error_message;

    PROCEDURE populate_errors_table
    IS
    BEGIN
        FORALL x IN g_error_tbl.FIRST .. g_error_tbl.LAST
            INSERT INTO XXDO.XXD_AR_TRX_ERRORS_GT
                 VALUES g_error_tbl (x);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexpected error in procedure populate_errors_table() ');
            fnd_file.put_line (
                fnd_file.LOG,
                'Error Message : ' || SUBSTR (SQLERRM, 1, 240));
    END populate_errors_table;


    FUNCTION remove_junk (p_input IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_output   VARCHAR2 (32767) := NULL;
    BEGIN
        IF p_input IS NOT NULL
        THEN
            SELECT REPLACE (REPLACE (REPLACE (REPLACE (REPLACE (p_input, CHR (9), ''), CHR (10), ''), '|', ' '), CHR (13), ''), ',', '')
              INTO lv_output
              FROM DUAL;
        ELSE
            RETURN NULL;
        END IF;

        RETURN lv_output;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END remove_junk;

    FUNCTION check_column_enabled (pv_column            VARCHAR2,
                                   pv_company_segment   VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_column_enable   VARCHAR2 (10);
    BEGIN
        SELECT attribute3
          INTO lv_column_enable
          FROM fnd_lookup_values
         WHERE     lookup_type = 'XXD_AR_DOMESTIC_SEND_TO_SDI'
               AND language = 'US'
               AND attribute1 = pv_column
               AND attribute2 = pv_company_segment;

        RETURN lv_column_enable;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 'N';
    END check_column_enabled;

    FUNCTION get_comp_segment (pn_trx_id NUMBER, pn_trx_line_id NUMBER)
        RETURN VARCHAR2
    IS
        lv_comp_segment   VARCHAR2 (10);
    BEGIN
        SELECT UNIQUE gcc.segment1
          INTO lv_comp_segment
          FROM ra_customer_trx_lines_all line, ra_cust_trx_line_gl_dist_all dist, gl_code_combinations gcc
         WHERE     1 = 1
               AND line.customer_trx_id = dist.customer_trx_id
               AND line.customer_trx_line_id = dist.customer_trx_line_id
               AND dist.code_combination_id = gcc.code_combination_id
               AND line.line_type = 'LINE'
               AND line.customer_trx_id = pn_trx_id
               AND dist.customer_trx_line_id = pn_trx_line_id;

        RETURN lv_comp_segment;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Unable to fetch the company segment ');
            lv_comp_segment   := '580';
            RETURN lv_comp_segment;
    END get_comp_segment;

    PROCEDURE get_bank_details (pn_org_id IN NUMBER, xv_bank_acc_num OUT VARCHAR2, xv_swift_code OUT VARCHAR2
                                , xv_iban_num OUT VARCHAR2)
    IS
        lv_bank_acct_num   VARCHAR2 (30);
        lv_swift_code      VARCHAR2 (60);
        lv_iban_num        VARCHAR2 (60);
    BEGIN
        SELECT cba.bank_account_num, cebb.eft_swift_code, cba.iban_number
          INTO xv_bank_acc_num, xv_swift_code, xv_iban_num
          FROM apps.ce_bank_accounts cba, apps.cefv_bank_branches cebb, apps.ce_bank_acct_uses_all cbaa,
               apps.hr_operating_units hou, apps.xle_entity_profiles xep
         WHERE     cebb.bank_branch_id = cba.bank_branch_id
               AND cba.bank_account_id = cbaa.bank_account_id
               AND cbaa.org_id = hou.organization_id
               AND cba.account_owner_org_id = xep.legal_entity_id
               AND cbaa.ar_use_enable_flag = 'Y'
               AND organization_id = pn_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            xv_bank_acc_num   := NULL;
            xv_swift_code     := NULL;
            xv_iban_num       := NULL;
    END get_bank_details;

    PROCEDURE get_hcode (p_style IN VARCHAR2, p_language IN VARCHAR2, x_hcode OUT VARCHAR2
                         , x_origin OUT VARCHAR2)
    IS
        lv_hcode    VARCHAR2 (60);
        lv_origin   VARCHAR2 (60);
    BEGIN
        BEGIN
            SELECT harmonized_tariff_code
              INTO lv_hcode
              FROM do_custom.do_harmonized_tariff_codes
             WHERE style_number = p_style AND country = 'EU';
        EXCEPTION
            WHEN OTHERS
            THEN
                x_hcode   := NULL;
        END;

        IF LENGTH (lv_hcode) > 1
        THEN
            x_hcode   := lv_hcode;

            IF p_language = 'FR'
            THEN
                x_origin   := 'Origine: Chine';
            ELSIF p_language = 'DU'
            THEN
                x_origin   := 'Herkomst: China';
            ELSE
                x_origin   := 'Origin: China';
            END IF;
        ELSE
            x_hcode    := NULL;
            x_origin   := NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Error in get_hcode:' || SQLERRM);
            x_hcode    := NULL;
            x_origin   := NULL;
    END get_hcode;

    FUNCTION get_inco_term (p_operating_unit IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_inco_term   VARCHAR2 (100) := NULL;
    BEGIN
        BEGIN
            SELECT ffv.description
              INTO lv_inco_term
              FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffv
             WHERE     1 = 1
                   AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                   AND ffvs.flex_value_set_name = 'XXDO_CFS_INCO_TERMS_VS'
                   AND ffv.enabled_flag = 'Y'
                   AND NVL (ffv.start_date_active, SYSDATE) <= SYSDATE
                   AND NVL (ffv.end_date_active, SYSDATE + 1) > SYSDATE
                   AND UPPER (RTRIM (LTRIM (ffv.flex_value))) =
                       UPPER (p_operating_unit)--AND ffv.attribute1 = 'EMEA'
                                               ;

            RETURN lv_inco_term;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_inco_term   := NULL;
        -- print_log('When others exception while getting Inco Term from value set.'||SQLERRM);
        END;

        RETURN lv_inco_term;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Error in get_inco_term:');
            lv_inco_term   := NULL;
            RETURN lv_inco_term;
    END get_inco_term;

    PROCEDURE get_le_details (pn_org_id IN NUMBER, xv_le_entity_name OUT VARCHAR2, xv_le_addr_street OUT VARCHAR2, xv_le_addr_post_code OUT VARCHAR2, xv_le_addr_city OUT VARCHAR2, xv_le_addr_province OUT VARCHAR2
                              , xv_le_country OUT VARCHAR2, xv_le_country_code OUT VARCHAR2, xv_le_vat_number OUT VARCHAR2)
    AS
    BEGIN
        SELECT xep.name legal_entity_name, hl.address_line_1 le_address_street, hl.postal_code le_address_postal_code,
               hl.town_or_city le_address_city, hl.region_1 le_address_province, ft.territory_short_name le_country,
               hl.country le_country_code, (hl.country || reg.registration_number) le_vat_number
          INTO xv_le_entity_name, xv_le_addr_street, xv_le_addr_post_code, xv_le_addr_city,
                                xv_le_addr_province, xv_le_country, xv_le_country_code,
                                xv_le_vat_number
          FROM xle_registrations reg, xle_entity_profiles xep, hr_locations hl,
               fnd_territories_tl ft, hr_operating_units hou
         WHERE     xep.transacting_entity_flag = 'Y'
               AND xep.legal_entity_id = reg.source_id
               AND reg.source_table = 'XLE_ENTITY_PROFILES'
               AND reg.identifying_flag = 'Y'
               AND reg.location_id = hl.location_id
               AND hl.country = ft.territory_code
               AND ft.language = USERENV ('LANG')
               AND xep.legal_entity_id = hou.default_legal_context_id
               AND hou.organization_id = pn_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Error in get_le_details :' || SQLERRM);
            xv_le_addr_street      := NULL;
            xv_le_addr_post_code   := NULL;
            xv_le_addr_city        := NULL;
            xv_le_addr_province    := NULL;
            xv_le_country          := NULL;
            xv_le_country_code     := NULL;
            xv_le_vat_number       := NULL;
    END get_le_details;

    PROCEDURE get_constant_values (xv_company_reg_number OUT VARCHAR2, xv_liquidation_status OUT VARCHAR2, xv_share_capital OUT VARCHAR2, xv_status_share OUT VARCHAR2, xv_seller_email OUT VARCHAR2, xv_seller_fax OUT VARCHAR2
                                   , xv_seller_tel OUT VARCHAR2)
    AS
        CURSOR c_cons IS
            SELECT attribute1 field_name, attribute2 field_value
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXD_AR_TRX_CONSTANT_VALUES_LKP'
                   AND language = 'US';

        lv_company_reg_number   VARCHAR2 (30);
        lv_liquidation_status   VARCHAR2 (30);
        lv_share_capital        VARCHAR2 (30);
        lv_status_share         VARCHAR2 (30);
        lv_seller_email         VARCHAR2 (30);
        lv_seller_fax           VARCHAR2 (30);
        lv_seller_tel           VARCHAR2 (30);
    BEGIN
        FOR i IN c_cons
        LOOP
            IF i.field_name = 'COMPANY_REG_NUMBER'
            THEN
                xv_company_reg_number   := i.field_value;
            ELSIF i.field_name = 'LIQUIDATION_STATUS'
            THEN
                xv_liquidation_status   := i.field_value;
            ELSIF i.field_name = 'SELLER_CONTACT_EMAIL'
            THEN
                xv_seller_email   := i.field_value;
            ELSIF i.field_name = 'SELLER_CONTACT_FAX'
            THEN
                xv_seller_fax   := i.field_value;
            ELSIF i.field_name = 'SELLER_CONTACT_TEL'
            THEN
                xv_seller_tel   := i.field_value;
            ELSIF i.field_name = 'SHARE_CAPITAL'
            THEN
                xv_share_capital   := i.field_value;
            ELSIF i.field_name = 'STATUS_SHAREHOLDERS'
            THEN
                xv_status_share   := i.field_value;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Error in fetching get_constant_values :' || SQLERRM);
            xv_company_reg_number   := NULL;
            xv_liquidation_status   := NULL;
            xv_share_capital        := NULL;
            xv_status_share         := NULL;
            xv_seller_email         := NULL;
            xv_seller_fax           := NULL;
            xv_seller_tel           := NULL;
    END get_constant_values;


    FUNCTION get_business_reg_num (p_customer_id IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_business_reg_number   VARCHAR2 (20) := NULL;
    BEGIN
        BEGIN
            SELECT hps.attribute8 business_reg_num
              INTO lv_business_reg_number
              FROM hz_cust_accounts hca, hz_parties hp, hz_party_sites hps,
                   hz_cust_acct_sites_all hcas, hz_cust_site_uses_all hcsu
             WHERE     hca.party_id = hp.party_id
                   AND hp.party_id = hps.party_id
                   AND hps.party_site_id = hcas.party_site_id
                   AND hca.cust_account_id = hcas.cust_account_id
                   AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND hcsu.site_use_code = 'BILL_TO'
                   AND hca.cust_account_id = p_customer_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_business_reg_number   := NULL;
        END;

        RETURN lv_business_reg_number;
    EXCEPTION
        WHEN OTHERS
        THEN
            -- print_log ('Error in get_business_reg_num:' || SQLERRM);
            RETURN NULL;
    END get_business_reg_num;

    -----------------------

    FUNCTION get_to_email_address (p_customer_id IN NUMBER, p_trx_class IN VARCHAR2, p_bill_site_id IN NUMBER)
        RETURN VARCHAR2
    IS
        CURSOR c_email IS
            SELECT DISTINCT hcp.email_address
              FROM hz_contact_points hcp, hz_cust_accounts hca
             WHERE     hcp.owner_table_name = 'HZ_PARTIES'
                   AND hcp.contact_point_type = 'EMAIL'
                   AND hcp.owner_table_id = hca.party_id
                   AND hca.cust_account_id = p_customer_id
                   AND hcp.status = 'A'
                   AND hcp.email_address LIKE '%@%'
            UNION
            -- Account Site at Bill to
            SELECT DISTINCT hcp.email_address
              FROM hz_contact_points hcp, hz_cust_acct_sites_all hcasa
             WHERE     hcp.owner_table_name = 'HZ_PARTY_SITES'
                   AND hcp.contact_point_type = 'EMAIL'
                   AND hcp.owner_table_id = hcasa.party_site_id
                   AND hcasa.cust_account_id = p_customer_id
                   AND hcp.status = 'A'
                   AND hcp.email_address LIKE '%@%'
                   AND EXISTS
                           (SELECT 1
                              FROM apps.hz_cust_site_uses_all uses
                             WHERE     uses.cust_acct_site_id =
                                       hcasa.cust_acct_site_id
                                   AND uses.site_use_id = p_bill_site_id)
            UNION
            -- Account level details email
            SELECT DISTINCT hcp.email_address
              FROM hz_cust_accounts_all hca, hz_contact_points hcp, hz_cust_account_roles har,
                   hz_role_responsibility hrr
             WHERE     1 = 1
                   AND har.party_id = hcp.owner_table_id
                   AND hcp.owner_table_name = 'HZ_PARTIES'
                   AND hcp.contact_point_type = 'EMAIL'
                   AND hca.cust_account_id = har.cust_account_id
                   AND har.cust_account_role_id = hrr.cust_account_role_id
                   AND hrr.responsibility_type =
                       DECODE (p_trx_class, 'CM', 'CM', 'INV')
                   AND hca.cust_account_id = p_customer_id
                   AND har.current_role_state = 'A'
                   --AND hrr.primary_flag = 'Y'
                   AND har.cust_acct_site_id IS NULL
                   AND har.role_type = 'CONTACT'
                   AND hcp.status = 'A'
                   AND hcp.email_address LIKE '%@%'
            --
            UNION
            -- Account Site level Bill to (inside)
            SELECT DISTINCT hcp.email_address
              FROM hz_cust_accounts_all hca, hz_contact_points hcp, hz_cust_account_roles har,
                   hz_role_responsibility hrr
             WHERE     1 = 1
                   AND har.party_id = hcp.owner_table_id
                   AND hcp.owner_table_name = 'HZ_PARTIES'
                   AND hcp.contact_point_type = 'EMAIL'
                   AND hca.cust_account_id = har.cust_account_id
                   AND har.cust_account_role_id = hrr.cust_account_role_id
                   AND hrr.responsibility_type =
                       DECODE (p_trx_class, 'CM', 'CM', 'INV')
                   AND hca.cust_account_id = p_customer_id
                   AND har.current_role_state = 'A'
                   AND har.cust_acct_site_id IS NOT NULL
                   AND har.role_type = 'CONTACT'
                   AND hcp.status = 'A'
                   AND hcp.email_address LIKE '%@%'
                   AND EXISTS
                           (SELECT 1
                              FROM apps.hz_cust_site_uses_all uses
                             WHERE     uses.cust_acct_site_id =
                                       har.cust_acct_site_id
                                   AND uses.site_use_id = p_bill_site_id);

        lv_email_address    VARCHAR2 (360);
        lv_ou_country       VARCHAR2 (100);
        lv_helpdesk_email   VARCHAR2 (100);
    BEGIN
        BEGIN
            SELECT hps.attribute7 email_address
              INTO lv_email_address
              FROM hz_cust_accounts hca, hz_parties hp, hz_party_sites hps,
                   hz_cust_acct_sites_all hcas, hz_cust_site_uses_all hcsu
             WHERE     hca.party_id = hp.party_id
                   AND hp.party_id = hps.party_id
                   AND hps.party_site_id = hcas.party_site_id
                   AND hca.cust_account_id = hcas.cust_account_id
                   AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND hcsu.site_use_code = 'BILL_TO'
                   AND hca.cust_account_id = p_customer_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_email_address   := NULL;
        END;

        IF lv_email_address IS NULL
        THEN
            FOR i IN c_email
            LOOP
                lv_email_address   :=
                    i.email_address || ',' || lv_email_address;
            END LOOP;

            lv_email_address   :=
                SUBSTR (lv_email_address, 0, LENGTH (lv_email_address) - 1);
        END IF;

        RETURN lv_email_address;
    EXCEPTION
        WHEN OTHERS
        THEN
            -- print_log ('Error in get_to_email_address:' || SQLERRM);
            RETURN NULL;
    END get_to_email_address;

    FUNCTION get_to_phone_number (p_customer_id IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_phone_number   VARCHAR2 (360) := NULL;
    BEGIN
        SELECT hcp.phone_number
          INTO lv_phone_number
          FROM hz_contact_points hcp, hz_cust_accounts hca
         WHERE     hcp.owner_table_name = 'HZ_PARTIES'
               AND hcp.contact_point_type = 'PHONE'
               AND hcp.owner_table_id = hca.party_id
               AND hca.cust_account_id = p_customer_id
               AND hcp.status = 'A'
               AND ROWNUM = 1
               AND hcp.email_address LIKE '%@%';

        IF lv_phone_number IS NULL
        THEN
            SELECT hcp.phone_number
              INTO lv_phone_number
              FROM hz_contact_points hcp, hz_cust_accounts hca
             WHERE     hcp.owner_table_name = 'HZ_PARTY_SITES'
                   AND hcp.contact_point_type = 'PHONE'
                   AND hcp.owner_table_id = hca.party_id
                   AND hca.cust_account_id = p_customer_id
                   AND hcp.status = 'A'
                   AND ROWNUM = 1
                   AND hcp.email_address LIKE '%@%';
        END IF;

        RETURN lv_phone_number;
    EXCEPTION
        WHEN OTHERS
        THEN
            --   print_log ('Error in get_to_phone_number:' || SQLERRM);
            RETURN NULL;
    END get_to_phone_number;

    FUNCTION get_vat_amount (p_org_id            IN NUMBER,
                             p_customer_trx_id   IN NUMBER,
                             p_tax_rate          IN NUMBER)
        RETURN NUMBER
    IS
        ln_vat_amount   NUMBER;
    BEGIN
        SELECT SUM (zl.tax_amt)
          INTO ln_vat_amount
          FROM zx_lines zl, ra_customer_trx_lines_all rctl
         WHERE     zl.application_id = 222
               AND zl.trx_id = p_customer_trx_id
               AND zl.trx_id = rctl.customer_trx_id
               AND zl.trx_line_id = rctl.customer_trx_line_id
               AND zl.tax_rate = p_tax_rate
               --AND rctl.inventory_item_id <> 1569786  --excluding freight charges
               AND zl.internal_organization_id = p_org_id;

        RETURN ln_vat_amount;
    EXCEPTION
        WHEN OTHERS
        THEN
            --  print_log('Error occured while fectching get_vat_amount  ');
            RETURN 0;
    END get_vat_amount;

    FUNCTION get_vat_net_amount (p_org_id IN NUMBER, p_customer_trx_id IN NUMBER, p_tax_rate IN NUMBER)
        RETURN NUMBER
    IS
        ln_vat_net_amount   NUMBER;
    BEGIN
        SELECT SUM (line.extended_amount)
          INTO ln_vat_net_amount
          FROM ra_customer_trx_lines_all line, ra_customer_trx_lines_all rtax
         WHERE     line.customer_trx_id = p_customer_trx_id
               AND line.customer_trx_line_id = rtax.link_to_cust_trx_line_id
               AND rtax.tax_rate = p_tax_rate
               -- AND line.inventory_item_id <> 1569786
               AND line.org_id = p_org_id
               AND line.line_type = 'LINE';

        -- and NVL (line.interface_line_attribute11, 0) = 0;

        RETURN ln_vat_net_amount;
    EXCEPTION
        WHEN OTHERS
        THEN
            --  print_log('Error occured while fectching get_vat_net_amount  ');
            RETURN 0;
    END get_vat_net_amount;

    FUNCTION get_line_tax_amt (p_org_id IN NUMBER, p_customer_trx_id IN NUMBER, p_customer_trx_line_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_tax_amt   NUMBER;
    BEGIN
        SELECT SUM (tax_amt)
          INTO ln_tax_amt
          FROM zx_lines
         WHERE     application_id = 222
               AND trx_line_id = p_customer_trx_line_id
               AND trx_id = p_customer_trx_id
               AND internal_organization_id = p_org_id;

        RETURN ln_tax_amt;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END get_line_tax_amt;

    FUNCTION get_tot_net_amount (p_customer_trx_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_tot_net_amount   NUMBER;
    BEGIN
        SELECT SUM (NVL (rctl.extended_amount, 0)) Amount
          INTO ln_tot_net_amount
          FROM apps.ra_customer_trx_lines_all rctl,
               (  SELECT customer_trx_id, link_to_cust_trx_line_id
                    FROM apps.ra_customer_trx_lines_all rctl_tax
                   WHERE     rctl_tax.line_type = 'TAX'
                         AND NVL (rctl_tax.tax_rate, 0) <> 0
                GROUP BY customer_trx_id, link_to_cust_trx_line_id)
               trx_tax_rate
         WHERE     1 = 1
               AND rctl.customer_trx_id = trx_tax_rate.customer_trx_id(+)
               AND rctl.customer_trx_line_id =
                   trx_tax_rate.link_to_cust_trx_line_id(+)
               AND rctl.line_type = 'LINE'
               AND NVL (rctl.inventory_item_id, 0) <> 1569786 -- excluding Freight charges
               AND rctl.customer_trx_id = p_customer_trx_id;

        RETURN ln_tot_net_amount;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Error occured while fectching get_tot_net_amount  ');
            RETURN 0;
    END get_tot_net_amount;

    FUNCTION get_h_discount_amount (p_customer_trx_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_line_amount   NUMBER;
        l_tot_amount     NUMBER;
    BEGIN
        BEGIN
            SELECT SUM (NVL (rctl.extended_amount, 0)) Amount
              INTO ln_line_amount
              FROM apps.ra_customer_trx_lines_all rctl,
                   apps.xxd_common_items_v msib,
                   (  SELECT customer_trx_id, link_to_cust_trx_line_id
                        FROM apps.ra_customer_trx_lines_all rctl_tax
                       WHERE     rctl_tax.line_type = 'TAX'
                             AND NVL (rctl_tax.tax_rate, 0) <> 0
                    GROUP BY customer_trx_id, link_to_cust_trx_line_id)
                   trx_tax_rate
             WHERE     1 = 1
                   AND rctl.customer_trx_id = trx_tax_rate.customer_trx_id(+)
                   AND rctl.customer_trx_line_id =
                       trx_tax_rate.link_to_cust_trx_line_id(+)
                   AND msib.inventory_item_id(+) = rctl.inventory_item_id
                   AND rctl.line_type = 'LINE'
                   AND msib.organization_id = NVL (rctl.warehouse_id, 7)
                   AND rctl.customer_trx_id = p_customer_trx_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_line_amount   := 0;
        END;

        BEGIN
            SELECT SUM (rctl.quantity_invoiced * NVL (DECODE (DECODE (NVL (rctl.interface_line_attribute11, 0), 0, NVL (rctl.quantity_invoiced, rctl.quantity_credited), 0), 0, 0, rctl.extended_amount / DECODE (NVL (rctl.interface_line_attribute11, 0), 0, NVL (rctl.quantity_invoiced, rctl.quantity_credited), 0)), rctl.unit_selling_price)) avg_unit_price_dsp
              INTO l_tot_amount
              FROM ra_customer_trx_lines_all rctl
             WHERE     rctl.customer_trx_id = p_customer_trx_id
                   AND rctl.line_type = 'LINE'
                   AND NVL (rctl.interface_line_attribute11, 0) = 0;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_tot_amount   := 0;
        END;

        RETURN (l_tot_amount - ln_line_amount);
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log (
                'Error occured while fectching get_h_discount_amount  ');
            RETURN 0;
    END get_h_discount_amount;

    FUNCTION get_tax_code (p_org_id IN NUMBER, p_invoice_id IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_tax_code   VARCHAR2 (30);
    BEGIN
        SELECT LISTAGG (tag, ', ') WITHIN GROUP (ORDER BY tag) tax_code
          INTO lv_tax_code
          FROM fnd_lookup_values
         WHERE     language = 'US'
               AND lookup_type = 'XXD_AR_NATURA_CODE_MAPPING'
               AND lookup_Code IN
                       (SELECT SUBSTR (tax_rate_code,
                                       1,
                                         INSTR (tax_rate_code, '_', -1
                                                , 1)
                                       - 1) tax_code
                          FROM zx_lines
                         WHERE     trx_id = p_invoice_id
                               AND application_id = 222
                               AND internal_organization_id = p_org_id);

        RETURN lv_tax_code;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Error occured while fectching get_tax_code  ');
            RETURN NULL;
    END get_tax_code;

    FUNCTION get_tax_exempt_text (p_org_id IN NUMBER, p_invoice_id IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_tax_code   VARCHAR2 (30);
    BEGIN
        SELECT LISTAGG (description, ', ') WITHIN GROUP (ORDER BY description) tax_code
          INTO lv_tax_code
          FROM fnd_lookup_values
         WHERE     language = 'US'
               AND lookup_type = 'XXD_AR_NATURA_CODE_MAPPING'
               AND lookup_Code IN
                       (SELECT SUBSTR (tax_rate_code,
                                       1,
                                         INSTR (tax_rate_code, '_', -1
                                                , 1)
                                       - 1) tax_code
                          FROM zx_lines
                         WHERE     trx_id = p_invoice_id
                               AND application_id = 222
                               AND internal_organization_id = p_org_id);

        RETURN lv_tax_code;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Error occured while fectching get_tax_exempt_text  ');
            RETURN NULL;
    END get_tax_exempt_text;

    FUNCTION get_line_tax_rate (p_org_id IN NUMBER, p_customer_trx_id IN NUMBER, p_customer_trx_line_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_tax_rate   NUMBER;
    BEGIN
        SELECT tax_rate
          INTO ln_tax_rate
          FROM zx_lines
         WHERE     application_id = 222
               AND trx_line_id = p_customer_trx_line_id
               AND trx_id = p_customer_trx_id
               AND internal_organization_id = p_org_id;

        RETURN ln_tax_rate;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END get_line_tax_rate;

    PROCEDURE get_freight_vat_taxable (p_customer_trx_id   IN     NUMBER,
                                       xn_freight_vat         OUT NUMBER)
    AS
        CURSOR tax_cur (p_customer_trx_id NUMBER)
        IS
              SELECT zl.tax_rate_name, zl.description, rctla.tax_rate
                FROM ra_customer_trx_lines_all rctla, zx_rates_tl zl
               WHERE     line_type = 'TAX'
                     AND zl.language = 'US'
                     AND zl.tax_rate_id = rctla.vat_tax_id
                     AND rctla.customer_trx_id = p_customer_trx_id
            GROUP BY zl.tax_rate_name, zl.description, rctla.tax_rate;

        ln_vat_s_t1   NUMBER := 0;
    BEGIN
        FOR i IN tax_cur (p_customer_trx_id)
        LOOP
            SELECT NVL (SUM (NVL (rctl_tax.extended_amount, 0)), 0)
              INTO ln_vat_s_t1
              FROM apps.ra_customer_trx_lines_all rctl_tax,
                   apps.zx_lines zl,
                   (SELECT customer_trx_id, customer_trx_line_id, org_id
                      FROM apps.ra_customer_trx_lines_all rctl
                     WHERE     1 = 1
                           AND (   line_type = 'FREIGHT'
                                OR (    line_type = 'LINE'
                                    AND UPPER (description) LIKE '%FREIGHT%'
                                    AND (   inventory_item_id IS NULL
                                         OR inventory_item_id IN
                                                (SELECT msib.inventory_item_id
                                                   FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffv, hr_operating_units hou,
                                                        mtl_system_items_b msib
                                                  WHERE     ffvs.flex_value_set_name =
                                                            'XXDO_CFS_FREIGHT_LIST_VS'
                                                        AND ffv.flex_value_set_id =
                                                            ffvs.flex_value_set_id
                                                        AND ffv.enabled_flag =
                                                            'Y'
                                                        AND NVL (
                                                                ffv.start_date_active,
                                                                SYSDATE) <=
                                                            SYSDATE
                                                        AND NVL (
                                                                ffv.end_date_active,
                                                                SYSDATE + 1) >
                                                            SYSDATE
                                                        AND ffv.flex_value =
                                                            hou.NAME
                                                        AND hou.organization_id =
                                                            rctl.org_id
                                                        AND UPPER (
                                                                msib.segment1) =
                                                            UPPER (
                                                                ffv.description)))))
                           AND rctl.customer_trx_id = p_customer_trx_id)
                   trx_line
             WHERE     rctl_tax.customer_trx_id = p_customer_trx_id
                   AND rctl_tax.line_type = 'TAX'
                   AND rctl_tax.customer_trx_id = trx_line.customer_trx_id
                   AND rctl_tax.link_to_cust_trx_line_id =
                       trx_line.customer_trx_line_id
                   AND zl.trx_id = trx_line.customer_trx_id
                   AND zl.trx_line_id = trx_line.customer_trx_line_id
                   AND zl.internal_organization_id = trx_line.org_id
                   AND EXISTS
                           (SELECT 1
                              FROM zx_rates_tl ztl
                             WHERE     language = USERENV ('Lang')
                                   AND ztl.tax_rate_id = zl.tax_rate_id
                                   AND ztl.tax_rate_name = i.tax_rate_name);
        END LOOP;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            ln_vat_s_t1   := 0;
        WHEN OTHERS
        THEN
            ln_vat_s_t1   := 0;
    END;

    PROCEDURE get_line_tax_rate_det (p_org_id IN NUMBER, p_customer_trx_id IN NUMBER, p_customer_trx_line_id IN NUMBER
                                     , x_tax_rate_name OUT VARCHAR2, x_tax_rate_des OUT VARCHAR2, x_tax_rate_code OUT VARCHAR2)
    IS
        ln_tax_rate_id     NUMBER;
        lv_tax_rate_name   VARCHAR2 (240);
        lv_tax_rate_desc   VARCHAR2 (240);
        lv_tax_rate_code   VARCHAR2 (240);
    BEGIN
        ln_tax_rate_id     := NULL;
        lv_tax_rate_name   := NULL;
        lv_tax_rate_desc   := NULL;
        lv_tax_rate_code   := NULL;
        x_tax_rate_name    := NULL;
        x_tax_rate_des     := NULL;
        x_tax_rate_code    := NULL;

        BEGIN
            SELECT tax_rate_id
              INTO ln_tax_rate_id
              FROM zx_lines
             WHERE     application_id = 222
                   AND trx_line_id = p_customer_trx_line_id
                   AND trx_id = p_customer_trx_id
                   AND internal_organization_id = p_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_tax_rate_name   := NULL;
                lv_tax_rate_desc   := NULL;
                lv_tax_rate_code   := NULL;
        END;

        IF ln_tax_rate_id IS NOT NULL
        THEN
            BEGIN
                SELECT ztl.tax_rate_name,
                       ztl.description,
                       SUBSTR (zb.tax_rate_code,
                               1,
                                 INSTR (zb.tax_rate_code, '_', -1,
                                        1)
                               - 1)               --tax_rate_code, description
                  INTO lv_tax_rate_name, lv_tax_rate_desc, lv_tax_rate_code
                  FROM zx_rates_tl ztl, zx_rates_b zb             --zx_rates_b
                 WHERE     ztl.tax_rate_id = ln_tax_rate_id
                       AND ztl.tax_rate_id = zb.tax_rate_id
                       AND LANGUAGE = USERENV ('Lang');
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_tax_rate_name   := NULL;
                    lv_tax_rate_desc   := NULL;
                    lv_tax_rate_code   := NULL;
            END;
        END IF;

        x_tax_rate_name    := lv_tax_rate_name;
        x_tax_rate_des     := lv_tax_rate_desc;
        x_tax_rate_code    := lv_tax_rate_code;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_tax_rate_name   := NULL;
            x_tax_rate_des    := NULL;
            x_tax_rate_code   := NULL;
    --   print_log('Finally Ex Error is  - '|| SQLERRM);
    END get_line_tax_rate_det;

    PROCEDURE get_sub_totals_prc (p_customer_trx_id   IN     NUMBER,
                                  x_vat_s_t0             OUT NUMBER,
                                  x_vat_s_t1             OUT NUMBER,
                                  x_vat_s_t2             OUT NUMBER,
                                  x_vat_s_tot            OUT NUMBER)
    IS
        --Local Variables
        lv_proc_name   VARCHAR2 (30) := 'GET_SUB_TOTALS_PRC';
        --Sub Total Goods

        ln_vat_s_t0    NUMBER;
        ln_vat_s_t1    NUMBER;
        ln_vat_s_t2    NUMBER;
        ln_vat_s_tot   NUMBER;


        ln_count       NUMBER := 0;


        CURSOR tax_cur (p_customer_trx_id NUMBER)
        IS
              SELECT zl.tax_rate_name, zl.description, rctla.tax_rate
                FROM ra_customer_trx_lines_all rctla, zx_rates_tl zl
               WHERE     line_type = 'TAX'
                     AND zl.language = 'US'
                     AND zl.tax_rate_id = rctla.vat_tax_id
                     AND rctla.customer_trx_id = p_customer_trx_id
            GROUP BY zl.tax_rate_name, zl.description, rctla.tax_rate;
    BEGIN
        ln_count      := 0;

        FOR i IN tax_cur (p_customer_trx_id)
        LOOP
            ln_count   := ln_count + 1;

            IF ln_count = 1
            THEN
                ln_vat_s_t0   := 0;

                BEGIN
                    -- VAT - Services : Taxable (T0)
                    SELECT NVL (SUM (NVL (rctl_tax.extended_amount, 0)), 0)
                      INTO ln_vat_s_t0
                      FROM apps.ra_customer_trx_lines_all rctl_tax,
                           apps.zx_lines zl,
                           (SELECT customer_trx_id, customer_trx_line_id, org_id
                              FROM apps.ra_customer_trx_lines_all rctl
                             WHERE     1 = 1
                                   AND (   line_type = 'FREIGHT'
                                        OR (    line_type = 'LINE'
                                            AND UPPER (description) LIKE
                                                    '%FREIGHT%'
                                            AND (   inventory_item_id IS NULL
                                                 OR inventory_item_id IN
                                                        (SELECT msib.inventory_item_id
                                                           FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffv, hr_operating_units hou,
                                                                mtl_system_items_b msib
                                                          WHERE     ffvs.flex_value_set_name =
                                                                    'XXDO_CFS_FREIGHT_LIST_VS'
                                                                AND ffv.flex_value_set_id =
                                                                    ffvs.flex_value_set_id
                                                                --- Added as per 3.0
                                                                AND ffv.enabled_flag =
                                                                    'Y'
                                                                AND NVL (
                                                                        ffv.start_date_active,
                                                                        SYSDATE) <=
                                                                    SYSDATE
                                                                AND NVL (
                                                                        ffv.end_date_active,
                                                                          SYSDATE
                                                                        + 1) >
                                                                    SYSDATE
                                                                --- Added as per 3.0
                                                                AND ffv.flex_value =
                                                                    hou.NAME
                                                                AND hou.organization_id =
                                                                    rctl.org_id
                                                                AND UPPER (
                                                                        msib.segment1) =
                                                                    UPPER (
                                                                        ffv.description)))))
                                   AND rctl.customer_trx_id =
                                       p_customer_trx_id) trx_line
                     WHERE     rctl_tax.customer_trx_id = p_customer_trx_id
                           AND rctl_tax.line_type = 'TAX'
                           --AND NVL (tax_rate, 0) = 0
                           AND rctl_tax.customer_trx_id =
                               trx_line.customer_trx_id
                           AND rctl_tax.link_to_cust_trx_line_id =
                               trx_line.customer_trx_line_id
                           AND zl.trx_id = trx_line.customer_trx_id
                           AND zl.trx_line_id = trx_line.customer_trx_line_id
                           AND zl.internal_organization_id = trx_line.org_id
                           AND EXISTS
                                   (SELECT 1
                                      FROM zx_rates_tl ztl
                                     WHERE     language = USERENV ('Lang')
                                           AND ztl.tax_rate_id =
                                               zl.tax_rate_id
                                           AND ztl.tax_rate_name =
                                               i.tax_rate_name);
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_vat_s_t0   := 0;
                    WHEN OTHERS
                    THEN
                        ln_vat_s_t0   := 0;
                END;
            ELSIF ln_count = 2
            THEN
                ln_vat_s_t1   := 0;

                BEGIN
                    -- VAT - Services : Taxable (T1)
                    SELECT NVL (SUM (NVL (rctl_tax.extended_amount, 0)), 0)
                      INTO ln_vat_s_t1
                      FROM apps.ra_customer_trx_lines_all rctl_tax,
                           apps.zx_lines zl,
                           (SELECT customer_trx_id, customer_trx_line_id, org_id
                              FROM apps.ra_customer_trx_lines_all rctl
                             WHERE     1 = 1
                                   AND (   line_type = 'FREIGHT'
                                        OR (    line_type = 'LINE'
                                            AND UPPER (description) LIKE
                                                    '%FREIGHT%'
                                            AND (   inventory_item_id IS NULL
                                                 OR inventory_item_id IN
                                                        (SELECT msib.inventory_item_id
                                                           FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffv, hr_operating_units hou,
                                                                mtl_system_items_b msib
                                                          WHERE     ffvs.flex_value_set_name =
                                                                    'XXDO_CFS_FREIGHT_LIST_VS'
                                                                AND ffv.flex_value_set_id =
                                                                    ffvs.flex_value_set_id
                                                                --- Added as per 3.0
                                                                AND ffv.enabled_flag =
                                                                    'Y'
                                                                AND NVL (
                                                                        ffv.start_date_active,
                                                                        SYSDATE) <=
                                                                    SYSDATE
                                                                AND NVL (
                                                                        ffv.end_date_active,
                                                                          SYSDATE
                                                                        + 1) >
                                                                    SYSDATE
                                                                --- Added as per 3.0
                                                                AND ffv.flex_value =
                                                                    hou.NAME
                                                                AND hou.organization_id =
                                                                    rctl.org_id
                                                                AND UPPER (
                                                                        msib.segment1) =
                                                                    UPPER (
                                                                        ffv.description)))))
                                   AND rctl.customer_trx_id =
                                       p_customer_trx_id) trx_line
                     WHERE     rctl_tax.customer_trx_id = p_customer_trx_id
                           AND rctl_tax.line_type = 'TAX'
                           --AND NVL (tax_rate, 0) <> 0
                           AND rctl_tax.customer_trx_id =
                               trx_line.customer_trx_id
                           AND rctl_tax.link_to_cust_trx_line_id =
                               trx_line.customer_trx_line_id
                           AND zl.trx_id = trx_line.customer_trx_id
                           AND zl.trx_line_id = trx_line.customer_trx_line_id
                           AND zl.internal_organization_id = trx_line.org_id
                           AND EXISTS
                                   (SELECT 1
                                      FROM zx_rates_tl ztl
                                     WHERE     language = USERENV ('Lang')
                                           AND ztl.tax_rate_id =
                                               zl.tax_rate_id
                                           AND ztl.tax_rate_name =
                                               i.tax_rate_name);
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_vat_s_t1   := 0;
                    WHEN OTHERS
                    THEN
                        ln_vat_s_t1   := 0;
                END;
            ELSIF ln_count = 3
            THEN
                ln_vat_s_t2   := 0;

                BEGIN
                    -- VAT - Services  :: Non-Taxable (T2)
                    SELECT NVL (SUM (NVL (rctl_tax.extended_amount, 0)), 0)
                      INTO ln_vat_s_t2
                      FROM apps.ra_customer_trx_lines_all rctl_tax,
                           apps.zx_lines zl,
                           (SELECT customer_trx_id, customer_trx_line_id, org_id
                              FROM apps.ra_customer_trx_lines_all rctl
                             WHERE     1 = 1
                                   AND (   line_type = 'FREIGHT'
                                        OR (    line_type = 'LINE'
                                            AND UPPER (description) LIKE
                                                    '%FREIGHT%'
                                            AND (   inventory_item_id IS NULL
                                                 OR inventory_item_id IN
                                                        (SELECT msib.inventory_item_id
                                                           FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffv, hr_operating_units hou,
                                                                mtl_system_items_b msib
                                                          WHERE     ffvs.flex_value_set_name =
                                                                    'XXDO_CFS_FREIGHT_LIST_VS'
                                                                AND ffv.flex_value_set_id =
                                                                    ffvs.flex_value_set_id
                                                                --- Added as per 3.0
                                                                AND ffv.enabled_flag =
                                                                    'Y'
                                                                AND NVL (
                                                                        ffv.start_date_active,
                                                                        SYSDATE) <=
                                                                    SYSDATE
                                                                AND NVL (
                                                                        ffv.end_date_active,
                                                                          SYSDATE
                                                                        + 1) >
                                                                    SYSDATE
                                                                --- Added as per 3.0
                                                                AND ffv.flex_value =
                                                                    hou.NAME
                                                                AND hou.organization_id =
                                                                    rctl.org_id
                                                                AND UPPER (
                                                                        msib.segment1) =
                                                                    UPPER (
                                                                        ffv.description)))))
                                   AND rctl.customer_trx_id =
                                       p_customer_trx_id) trx_line
                     WHERE     rctl_tax.customer_trx_id = p_customer_trx_id
                           AND rctl_tax.line_type = 'TAX'
                           AND rctl_tax.customer_trx_id =
                               trx_line.customer_trx_id
                           AND rctl_tax.link_to_cust_trx_line_id =
                               trx_line.customer_trx_line_id
                           AND zl.trx_id = trx_line.customer_trx_id
                           AND zl.trx_line_id = trx_line.customer_trx_line_id
                           AND zl.internal_organization_id = trx_line.org_id
                           AND EXISTS
                                   (SELECT 1
                                      FROM zx_rates_tl ztl
                                     WHERE     language = USERENV ('Lang')
                                           AND ztl.tax_rate_id =
                                               zl.tax_rate_id
                                           AND ztl.tax_rate_name =
                                               i.tax_rate_name);
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_vat_s_t2   := 0;
                    WHEN OTHERS
                    THEN
                        ln_vat_s_t2   := 0;
                END;
            END IF;
        END LOOP;

        x_vat_s_t0    := ln_vat_s_t0;
        x_vat_s_t1    := ln_vat_s_t1;
        x_vat_s_t2    := ln_vat_s_t2;
        x_vat_s_tot   := ln_vat_s_tot;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_vat_s_t0    := NULL;
            x_vat_s_t1    := NULL;
            x_vat_s_t2    := NULL;
            x_vat_s_tot   := NULL;
    END get_sub_totals_prc;


    FUNCTION get_email_ids (pv_lookup_type VARCHAR2, pv_inst_name VARCHAR2)
        RETURN do_mail_utils.tbl_recips
    IS
        v_def_mail_recips   do_mail_utils.tbl_recips;

        CURSOR recips_cur IS
            SELECT xx.email_id
              FROM (SELECT flv.meaning email_id
                      FROM fnd_lookup_values flv
                     WHERE     1 = 1
                           AND flv.lookup_type = pv_lookup_type
                           AND flv.enabled_flag = 'Y'
                           AND flv.language = USERENV ('LANG')
                           AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                           NVL (
                                                               flv.start_date_active,
                                                               SYSDATE))
                                                   AND TRUNC (
                                                           NVL (
                                                               flv.end_date_active,
                                                               SYSDATE))) xx
             WHERE xx.email_id IS NOT NULL;

        CURSOR submitted_by_cur IS
            SELECT (fu.email_address) email_id
              FROM fnd_user fu
             WHERE     1 = 1
                   AND fu.user_id = gn_user_id
                   AND TRUNC (SYSDATE) BETWEEN fu.start_date
                                           AND TRUNC (
                                                   NVL (fu.end_date, SYSDATE));
    BEGIN
        -- fnd_file.put_line(fnd_file.log, 'Lookup Type:' || pv_lookup_type);
        v_def_mail_recips.DELETE;

        IF pv_inst_name = 'PRODUCTION'
        THEN
            FOR recips_rec IN recips_cur
            LOOP
                v_def_mail_recips (v_def_mail_recips.COUNT + 1)   :=
                    recips_rec.email_id;
            END LOOP;

            RETURN v_def_mail_recips;
        ELSE
            FOR submitted_by_rec IN submitted_by_cur
            LOOP
                v_def_mail_recips (v_def_mail_recips.COUNT + 1)   :=
                    submitted_by_rec.email_id;
            END LOOP;

            RETURN v_def_mail_recips;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            v_def_mail_recips (1)   := '';
            fnd_file.put_line (fnd_file.LOG,
                               'Failed to fetch email receipents');
            RETURN v_def_mail_recips;
    END get_email_ids;

    --

    PROCEDURE generate_report_prc (p_conc_request_id IN NUMBER)
    IS
        CURSOR ar_failed_msgs_cur IS
              SELECT UNIQUE hdr.invoice_number, hdr.invoice_date, hdr.invoice_currency_code,
                            hdr.transaction_type, hdr.bill_to_customer_num, hdr.h_invoice_total-- ,hdr.error_code
                                                                                               ,
                            er.ERROR_CODE, er.error_message
                FROM xxdo.xxd_ar_trx_hdr_stg hdr, xxdo.xxd_ar_trx_errors_gt er
               WHERE     hdr.conc_request_id = p_conc_request_id
                     AND hdr.invoice_id = er.trx_id
                     AND hdr.conc_request_id = er.request_id
                     AND hdr.process_flag = 'E'
            ORDER BY hdr.invoice_number DESC;

        ln_rec_fail             NUMBER;
        ln_rec_total            NUMBER;
        ln_rec_success          NUMBER;
        lv_message              VARCHAR2 (32000);
        lv_recipients           VARCHAR2 (4000);
        lv_result               VARCHAR2 (100);
        lv_result_msg           VARCHAR2 (4000);
        lv_exc_directory_path   VARCHAR2 (1000);
        lv_exc_file_name        VARCHAR2 (1000);
        lv_mail_delimiter       VARCHAR2 (1) := '/';
        lv_inst_name            VARCHAR2 (30) := NULL;
        lv_msg                  VARCHAR2 (4000) := NULL;
        ln_ret_val              NUMBER := 0;
        lv_out_line             VARCHAR2 (4000);
        lv_error_message        VARCHAR2 (240);
        lv_error_reason         VARCHAR2 (240);
        lv_breif_err_resol      VARCHAR2 (240);
        lv_comments             VARCHAR2 (240);
        ln_counter              NUMBER;
    BEGIN
        ln_rec_fail      := 0;
        ln_rec_total     := 0;
        ln_rec_success   := 0;
        ln_counter       := 0;

        BEGIN
            SELECT COUNT (1)
              INTO ln_rec_total
              FROM xxdo.xxd_ar_trx_hdr_stg
             WHERE conc_request_id = p_conc_request_id AND process_flag = 'E';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_rec_total   := 0;
        END;

        IF ln_rec_total <= 0
        THEN
            print_log ('There is nothing to Process...No File Exists.');
        ELSE
            BEGIN
                SELECT DECODE (applications_system_name, 'EBSPROD', 'PRODUCTION', 'TEST(' || applications_system_name || ')') applications_system_name
                  INTO lv_inst_name
                  FROM fnd_product_groups;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_inst_name   := '';
                    lv_msg         :=
                           'Error getting the instance name in send_email_proc procedure. Error is '
                        || SQLERRM;
                    raise_application_error (-20010, lv_msg);
            END;

            gv_def_mail_recips   :=
                get_email_ids ('XXD_AR_TRX_EMAIL_NOTIF_LKP', lv_inst_name);


            apps.do_mail_utils.send_mail_header ('erp@deckers.com', gv_def_mail_recips, 'Deckers AR Invoices Extract Error Report ' || ' Email generated from ' || lv_inst_name || ' instance'
                                                 , ln_ret_val);

            do_mail_utils.send_mail_line (
                'Content-Type: multipart/mixed; boundary=boundarystring',
                ln_ret_val);
            do_mail_utils.send_mail_line ('', ln_ret_val);
            do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
            do_mail_utils.send_mail_line ('', ln_ret_val);
            do_mail_utils.send_mail_line ('Hello Team', ln_ret_val);
            do_mail_utils.send_mail_line ('  ', ln_ret_val);
            do_mail_utils.send_mail_line (
                'Please see attached Deckers Pagero Outbound failed/error/reject Report.',
                ln_ret_val);
            do_mail_utils.send_mail_line ('', ln_ret_val);
            do_mail_utils.send_mail_line (
                'Note: This is auto generated mail, please donot reply.',
                ln_ret_val);
            do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
            do_mail_utils.send_mail_line ('Content-Type: text/xls',
                                          ln_ret_val);
            do_mail_utils.send_mail_line (
                   'Content-Disposition: attachment; filename="Deckers_AR_extract_error_'
                || TO_CHAR (SYSDATE, 'RRRRMMDD_HH24MISS')
                || '.xls"',
                ln_ret_val);

            --  apps.do_mail_utils.send_mail_line('Summary Report', ln_ret_val);
            -- do_mail_utils.send_mail_line('', ln_ret_val);
            apps.do_mail_utils.send_mail_line (lv_message, ln_ret_val);
            -- mail attachement
            --   apps.do_mail_utils.send_mail_line('  ', ln_ret_val);
            --   --  apps.do_mail_utils.send_mail_line('Detail Report', ln_ret_val);
            --   do_mail_utils.send_mail_line('', ln_ret_val);
            apps.do_mail_utils.send_mail_line (
                   'Sr No'
                || CHR (9)
                || 'Transaction Number'
                || CHR (9)
                || 'Transaction Type'
                || CHR (9)
                || 'Customer Number'
                || CHR (9)
                || 'Transaction Date'
                || CHR (9)
                || 'Currency'
                || CHR (9)
                || 'Amount'
                || CHR (9)
                || 'Error Code'
                || CHR (9)
                || 'Error Message'
                || CHR (9)
                || 'Error Reason'
                || CHR (9)
                || 'Brief Resolution'
                || CHR (9)
                || 'Comments'
                || CHR (9),
                ln_ret_val);

            FOR r_line IN ar_failed_msgs_cur
            LOOP
                ln_counter   := ln_counter + 1;

                -- to get error message details
                BEGIN
                    SELECT ffv.description error_message, attribute1 error_reason, attribute2 breif_error_resolution,
                           attribute3 comments
                      INTO lv_error_message, lv_error_reason, lv_breif_err_resol, lv_comments
                      FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffv
                     WHERE     ffvs.flex_value_set_id = ffv.flex_value_set_id
                           AND ffvs.flex_value_set_name =
                               'XXD_AR_TRX_ERROR_MESSAGES_VS'
                           AND ffv.enabled_flag = 'Y'
                           AND ffv.flex_value = r_line.ERROR_CODE;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        print_log ('Failed to get the error details ');
                        lv_error_message     := NULL;
                        lv_error_reason      := NULL;
                        lv_breif_err_resol   := NULL;
                        lv_comments          := NULL;
                END;


                apps.do_mail_utils.send_mail_line (
                       ln_counter
                    || CHR (9)
                    || r_line.invoice_number
                    || CHR (9)
                    || r_line.transaction_type
                    || CHR (9)
                    || r_line.bill_to_customer_num
                    || CHR (9)
                    || r_line.invoice_date
                    || CHR (9)
                    || r_line.invoice_currency_code
                    || CHR (9)
                    || r_line.h_invoice_total
                    || CHR (9)
                    || r_line.ERROR_CODE
                    || CHR (9)
                    || NVL (lv_error_message, r_line.error_message)
                    || CHR (9)
                    || lv_error_reason
                    || CHR (9)
                    || lv_breif_err_resol
                    || CHR (9)
                    || lv_comments
                    || CHR (9),
                    ln_ret_val);
            --apps.do_mail_utils.send_mail_line(lv_out_line, lv_message);
            END LOOP;

            apps.do_mail_utils.send_mail_close (ln_ret_val);
            print_log ('lv_ result is - ' || lv_result);
            print_log ('lv_result_msg is - ' || lv_result_msg);
        END IF;
    END generate_report_prc;

    PROCEDURE get_line_data (p_style IN VARCHAR2, p_color IN VARCHAR2, p_size IN VARCHAR2, p_cust_trx_id IN NUMBER, p_tax_rec IN VARCHAR2, p_inventory_item_id IN NUMBER, p_int_line_att6 IN VARCHAR2, x_qty_sum OUT NUMBER, x_line_amt OUT NUMBER, x_unit_price OUT NUMBER, x_unit_price_list OUT NUMBER, x_disc_percent OUT NUMBER
                             , x_tax_yn OUT VARCHAR2)
    IS
    BEGIN
        --print_log('Style:'||p_style||' Color:'||p_color||' Size:'||p_size);
        IF p_style IS NOT NULL AND p_color IS NOT NULL
        THEN
            SELECT SUM (DECODE (T1.QTY - NVL (T2.QTY, 0), 0, T1.QTY, T1.QTY - NVL (T2.QTY, 0))) qty, SUM (T1.Amount) line_amt, ROUND (SUM (T1.Amount) / SUM (DECODE (T1.QTY - NVL (T2.QTY, 0), 0, T1.QTY, T1.QTY - NVL (T2.QTY, 0))), 2) unit_price,
                   ROUND (SUM (T1.Amount - NVL (T2.Amount, 0)) / SUM (DECODE (T1.QTY - NVL (T2.QTY, 0), 0, T1.QTY, T1.QTY - NVL (T2.QTY, 0))), 2) unit_price_list, ROUND (DECODE (SUM (t1.amount) - SUM (t2.amount), 0, 0, SUM (t2.amount) / (SUM (t1.amount) - SUM (t2.amount)) * -1) * 100, 2) disc_pct, DECODE (p_tax_rec, NULL, 'T0', 'T1') Tax_YN
              INTO x_qty_sum, x_line_amt, x_unit_price, x_unit_price_list,
                            x_disc_percent, x_tax_yn
              FROM (  SELECT msib.item_size SZE, SUM (NVL (rctl.quantity_invoiced, rctl.quantity_credited)) qty, SUM (NVL (rctl.extended_amount, 0)) Amount,
                             NVL (SUM (rctl.tax_recoverable), 0) tamt
                        FROM apps.ra_customer_trx_lines_all rctl,
                             apps.xxd_common_items_v msib,
                             (  SELECT customer_trx_id, --tax_rate, --Commented on 16Jan2018 by Kranthi Bollam
                                                        link_to_cust_trx_line_id
                                  FROM apps.ra_customer_trx_lines_all rctl_tax
                                 WHERE     rctl_tax.line_type = 'TAX'
                                       AND NVL (rctl_tax.tax_rate, 0) <> 0
                              GROUP BY customer_trx_id, link_to_cust_trx_line_id)
                             trx_tax_rate
                       WHERE     1 = 1
                             AND rctl.customer_trx_id =
                                 trx_tax_rate.customer_trx_id(+)
                             AND rctl.customer_trx_line_id =
                                 trx_tax_rate.link_to_cust_trx_line_id(+)
                             AND msib.inventory_item_id =
                                 rctl.inventory_item_id
                             AND rctl.inventory_item_id = p_inventory_item_id
                             AND rctl.interface_line_attribute6 =
                                 p_int_line_att6
                             AND rctl.line_type = 'LINE'
                             AND msib.organization_id =
                                 NVL (rctl.warehouse_id, 7)
                             --AND NVL (rctl.tax_recoverable, 0) <> 0
                             AND rctl.customer_trx_id = p_cust_trx_id
                    GROUP BY msib.style_number, --msib.color_desc ,
                                                msib.color_code, msib.item_size,
                             msib.item_description, rctl.interface_line_context)
                   T1,
                   (  SELECT msib.item_size SZE, SUM (NVL (rctl.quantity_invoiced, rctl.quantity_credited)) qty, SUM (NVL (rctl.extended_amount, 0)) Amount,
                             NVL (SUM (rctl.tax_recoverable), 0) tamt
                        FROM apps.ra_customer_trx_lines_all rctl,
                             apps.xxd_common_items_v msib,
                             (  SELECT customer_trx_id, link_to_cust_trx_line_id
                                  FROM apps.ra_customer_trx_lines_all rctl_tax
                                 WHERE     rctl_tax.line_type = 'TAX'
                                       AND NVL (rctl_tax.tax_rate, 0) <> 0
                              GROUP BY customer_trx_id, link_to_cust_trx_line_id)
                             trx_tax_rate
                       WHERE     1 = 1
                             AND rctl.customer_trx_id =
                                 trx_tax_rate.customer_trx_id(+)
                             AND rctl.customer_trx_line_id =
                                 trx_tax_rate.link_to_cust_trx_line_id(+)
                             AND msib.inventory_item_id =
                                 rctl.inventory_item_id
                             AND rctl.inventory_item_id = p_inventory_item_id
                             AND rctl.interface_line_attribute6 =
                                 p_int_line_att6
                             AND rctl.line_type = 'LINE'
                             AND msib.organization_id =
                                 NVL (rctl.warehouse_id, 7)
                             AND rctl.interface_line_attribute11 <> '0'
                             AND rctl.interface_line_context = 'ORDER ENTRY'
                             AND rctl.customer_trx_id = p_cust_trx_id
                    GROUP BY msib.style_number, --msib.color_desc ,
                                                msib.color_code, msib.item_size,
                             msib.item_description, rctl.interface_line_context)
                   T2
             WHERE T1.SZE = T2.SZE(+);
        ELSIF p_style IS NULL AND p_color IS NULL
        THEN
            SELECT SUM (DECODE (T1.QTY - NVL (T2.QTY, 0), 0, T1.QTY, T1.QTY - NVL (T2.QTY, 0))) qty, SUM (T1.Amount) line_amt, ROUND (SUM (T1.Amount) / SUM (DECODE (T1.QTY - NVL (T2.QTY, 0), 0, T1.QTY, T1.QTY - NVL (T2.QTY, 0))), 2) unit_price,
                   ROUND (SUM (T1.Amount - NVL (T2.Amount, 0)) / SUM (DECODE (T1.QTY - NVL (T2.QTY, 0), 0, T1.QTY, T1.QTY - NVL (T2.QTY, 0))), 2) unit_price_list, ROUND (DECODE (SUM (t1.amount) - SUM (t2.amount), 0, 0, SUM (t2.amount) / (SUM (t1.amount) - SUM (t2.amount)) * -1) * 100, 2) disc_pct, DECODE (p_tax_rec, NULL, 'T0', 'T1') Tax_YN
              INTO x_qty_sum, x_line_amt, x_unit_price, x_unit_price_list,
                            x_disc_percent, x_tax_yn
              FROM (  SELECT NULL sze, SUM (NVL (rctl.quantity_invoiced, rctl.quantity_credited)) qty, SUM (NVL (rctl.extended_amount, 0)) amount,
                             NVL (SUM (rctl.tax_recoverable), 0) tamt
                        FROM apps.ra_customer_trx_lines_all rctl,
                             (  SELECT customer_trx_id, link_to_cust_trx_line_id
                                  FROM apps.ra_customer_trx_lines_all rctl_tax
                                 WHERE     rctl_tax.line_type = 'TAX'
                                       AND NVL (rctl_tax.tax_rate, 0) <> 0
                              GROUP BY customer_trx_id, link_to_cust_trx_line_id)
                             trx_tax_rate
                       WHERE     1 = 1
                             AND rctl.customer_trx_id =
                                 trx_tax_rate.customer_trx_id(+)
                             AND rctl.customer_trx_line_id =
                                 trx_tax_rate.link_to_cust_trx_line_id(+)
                             AND rctl.line_type = 'LINE'
                             --AND NVL (rctl.tax_recoverable, 0) <> 0
                             AND rctl.customer_trx_id = p_cust_trx_id
                    GROUP BY rctl.interface_line_context) T1,
                   (  SELECT NULL sze, SUM (NVL (rctl.quantity_invoiced, rctl.quantity_credited)) qty, SUM (NVL (rctl.extended_amount, 0)) amount,
                             NVL (SUM (rctl.tax_recoverable), 0) tamt
                        FROM apps.ra_customer_trx_lines_all rctl,
                             (  SELECT customer_trx_id, link_to_cust_trx_line_id
                                  FROM apps.ra_customer_trx_lines_all rctl_tax
                                 WHERE     rctl_tax.line_type = 'TAX'
                                       AND NVL (rctl_tax.tax_rate, 0) <> 0
                              GROUP BY customer_trx_id,                    --A
                                                        link_to_cust_trx_line_id)
                             trx_tax_rate
                       WHERE     1 = 1
                             AND rctl.customer_trx_id =
                                 trx_tax_rate.customer_trx_id(+)
                             AND rctl.customer_trx_line_id =
                                 trx_tax_rate.link_to_cust_trx_line_id(+)
                             AND rctl.line_type = 'LINE'
                             AND rctl.interface_line_attribute11 <> '0'
                             AND rctl.interface_line_context = 'ORDER ENTRY'
                             AND rctl.customer_trx_id = p_cust_trx_id
                    GROUP BY rctl.interface_line_context) T2
             WHERE NVL (T1.Amount, 0) + NVL (T2.Amount, 0) <> 0;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log (
                   'Error in get_line_data for customer_trx_id:'
                || p_cust_trx_id
                || ' . Rrror is: '
                || SQLERRM);
            x_qty_sum           := 0;
            x_line_amt          := 0;
            x_unit_price        := 0;
            x_unit_price_list   := 0;
            x_disc_percent      := NULL;
            x_tax_yn            := 'T0';
    END get_line_data;


    PROCEDURE insert_ar_eligible_recs (pn_org_id           IN     NUMBER,
                                       pv_trx_number       IN     VARCHAR2,
                                       pd_trx_date_from    IN     VARCHAR2,
                                       pd_trx_date_to      IN     VARCHAR2,
                                       pn_customer_id      IN     VARCHAR2,
                                       pv_reprocess_flag   IN     VARCHAR2,
                                       x_ret_code             OUT VARCHAR2,
                                       x_ret_message          OUT VARCHAR2)
    AS
        CURSOR c_hdr (p_org_id IN NUMBER, p_trx_number IN VARCHAR2, p_trx_date_from IN DATE
                      , p_trx_date_to IN DATE, pn_customer_id IN VARCHAR2)
        IS
            SELECT trx.customer_trx_id
                       invoice_id,
                   trx.trx_number
                       invoice_number,
                   TO_CHAR (trx.trx_date, 'DD-MON-RRRR')
                       invoice_date,
                   TO_CHAR (ps.due_date, 'DD-MON-RRRR')
                       term_due_date,
                   rt.description
                       payment_term,
                   trx.invoice_currency_code
                       invoice_currency_code,
                   NULL
                       document_type,
                   trx.set_of_books_id,
                   trx.org_id,
                   NULL
                       duty_stamp,
                   NULL
                       le_registriation_number,
                   hca.cust_account_id,
                   hp.party_name
                       bill_to_customer_name,
                   hca.account_number
                       bill_to_cust_acct_num,
                   hl.address1
                       bill_to_address_street,
                   hl.city
                       bill_to_address_city,
                   hl.postal_code
                       bill_to_address_postal_code,
                   hl.province
                       bill_to_address_province,
                   ft.territory_short_name
                       bill_to_address_country,
                   hl.country
                       bill_to_address_country_code,
                   hcsa.site_use_id
                       bill_to_site_use_id,
                   NVL (hcsa.tax_reference, hp.tax_reference)
                       bill_to_vat_number,
                   NULL
                       bill_to_business_reg_number,
                   NULL
                       bill_to_unique_rec_identifier,
                   NVL (hp.attribute19, '0000000')
                       bill_to_routing_code,
                   NULL
                       bill_to_email,
                   NULL
                       bill_to_telphone,
                   trx.printing_option,
                   rctt.TYPE,
                   DECODE (rctt.TYPE,
                           'CM', 'Credit Memo',
                           'DM', 'Debit Memo',
                           'INV', 'Invoice',
                           NULL)
                       transaction_type,
                   trx.attribute6
                       original_invoice,
                   trx.purchase_order
                       purchase_order,
                   REPLACE (
                       REPLACE (REPLACE (trx.comments, CHR (9), ' '),
                                CHR (10),
                                ' '),
                       '|',
                       ' ')
                       comments,
                   REPLACE (
                       REPLACE (REPLACE (trx.comments, CHR (9), ' '),
                                CHR (10),
                                ' '),
                       '|',
                       ' ')
                       invoice_comments,
                   DECODE (trx.waybill_number, '0', '', trx.waybill_number)
                       waybill_number,
                   trx.interface_header_context,
                   hou.name
                       operating_unit,
                   NVL (trx.interface_header_attribute1, trx.ct_reference)
                       order_reference,
                   trx.interface_header_attribute2
                       order_type,
                   DECODE (trx.interface_header_attribute3,
                           '0', '',
                           trx.interface_header_attribute3)
                       delivery_number,
                   ps.due_date
                       due_date,
                   TO_CHAR (ps.due_date, 'MM/DD/YYYY')
                       due_date_dsp,
                   ps.amount_due_original
                       invoice_amount,
                   ps.amount_due_original
                       inv_amt_dsp,
                   ps.amount_line_items_original,
                   ps.amount_line_items_original
                       invoice_line_amt_dsp,
                   ps.freight_original,
                   NVL (ps.freight_original, 0)
                       invoice_freight_amt_dsp,
                   ps.tax_original,
                   ps.tax_original
                       invoice_tax_amt_dsp,
                   (SELECT SUM (zl.tax_amt)
                      FROM zx_lines zl, ra_customer_trx_lines_all rctl
                     WHERE     zl.application_id = 222
                           AND zl.trx_id = trx.customer_trx_id
                           AND zl.trx_id = rctl.customer_trx_id
                           AND zl.trx_line_id = rctl.customer_trx_line_id
                           AND NVL (rctl.inventory_item_id, 0) <> 1569786 --excluding freight charges
                           AND zl.internal_organization_id = trx.org_id)
                       h_total_tax_amount,
                   get_tot_net_amount (trx.customer_trx_id)
                       h_total_net_amount,
                   get_h_discount_amount (trx.customer_trx_id)
                       h_discount_amt,
                   (SELECT rtax.tax_rate
                      FROM ra_customer_trx_lines_all rctl, ra_customer_trx_lines_all rtax
                     WHERE     rctl.customer_trx_line_id =
                               rtax.link_to_cust_trx_line_id
                           AND rctl.customer_trx_id = trx.customer_trx_id
                           AND UPPER (rctl.description) LIKE
                                   UPPER ('%Discount%')
                           AND ROWNUM = 1)
                       h_discount_rate,
                   DECODE (
                       rt.calc_discount_on_lines_flag,
                       'L', (ROUND (ps.freight_original + ps.tax_original + (ps.amount_line_items_original * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1))), 2)),
                       'I', (ROUND ((ps.amount_due_original * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1))), 2)),
                       'T', (ROUND ((ps.freight_original * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1))) + (ps.tax_original * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1))) + (ps.amount_line_items_original * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1))), 2)),
                       'F', (ROUND (
                                   ps.freight_original
                                 + (  (  ps.tax_original
                                       - (SELECT NVL (SUM (extended_amount), 0)
                                            FROM apps.ra_customer_trx_lines_all rctl
                                           WHERE     rctl.customer_trx_id =
                                                     trx.customer_trx_id
                                                 AND line_type = 'TAX'
                                                 AND link_to_cust_trx_line_id IN
                                                         (SELECT customer_trx_line_id
                                                            FROM apps.ra_customer_trx_lines_all rctl1
                                                           WHERE     1 = 1
                                                                 AND line_type =
                                                                     'FREIGHT'
                                                                 AND rctl1.customer_trx_id =
                                                                     rctl.customer_trx_id)))
                                    * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1)))
                                 + (ps.amount_line_items_original * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1))),
                                 2)))
                       AS disc_amt,
                   ROUND (
                         ps.freight_original
                       + ps.tax_original
                       + (ps.amount_line_items_original * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1))),
                       2)
                       disc_amt_dsp,
                     ROUND (ps.amount_due_original, 2)
                   - ROUND (
                           ps.freight_original
                         + ps.tax_original
                         + (ps.amount_line_items_original * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1))),
                         2)
                       AS discount,
                   DECODE (
                       rt.calc_discount_on_lines_flag,
                       'L', (ROUND (ps.amount_due_original, 2) - ROUND (ps.freight_original + ps.tax_original + (ps.amount_line_items_original * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1))), 2)),
                       'I', (ROUND (ps.amount_due_original, 2) - ROUND ((ps.amount_due_original * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1))), 2)),
                       'T', (ROUND (ps.amount_due_original, 2) - ROUND ((ps.freight_original * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1))) + (ps.tax_original * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1))) + (ps.amount_line_items_original * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1))), 2)),
                       'F', (  ROUND (ps.amount_due_original, 2)
                             - ROUND (
                                     ps.freight_original
                                   + (  (  ps.tax_original
                                         - (SELECT NVL (SUM (extended_amount), 0)
                                              FROM apps.ra_customer_trx_lines_all rctl
                                             WHERE     rctl.customer_trx_id =
                                                       trx.customer_trx_id
                                                   AND line_type = 'TAX'
                                                   AND link_to_cust_trx_line_id IN
                                                           (SELECT customer_trx_line_id
                                                              FROM apps.ra_customer_trx_lines_all rctl1
                                                             WHERE     1 = 1
                                                                   AND line_type =
                                                                       'FREIGHT'
                                                                   AND rctl1.customer_trx_id =
                                                                       rctl.customer_trx_id)))
                                      * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1)))
                                   + (ps.amount_line_items_original * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1))),
                                   2)))
                       AS discounted
              FROM apps.ra_customer_trx_all trx, apps.ar_payment_schedules_all ps, apps.ra_cust_trx_types_all rctt,
                   apps.ra_terms rt, apps.ra_terms_lines_discounts rtld, hz_cust_accounts hca,
                   hz_parties hp, hz_party_sites hps, hz_cust_acct_sites_all hcas,
                   hz_cust_site_uses_all hcsa, hz_locations hl, apps.fnd_territories_tl ft,
                   apps.hr_operating_units hou
             WHERE     1 = 1
                   AND trx.org_id = hou.organization_id
                   AND trx.bill_to_customer_id = hca.cust_account_id
                   AND trx.bill_to_site_use_id = hcsa.site_use_id
                   AND hca.party_id = hp.party_id
                   AND hp.party_id = hps.party_id
                   AND hps.party_site_id = hcas.party_site_id
                   AND hca.cust_account_id = hcas.cust_account_id
                   AND hcas.cust_acct_site_id = hcsa.cust_acct_site_id
                   AND hcsa.site_use_code = 'BILL_TO'
                   AND hps.location_id = hl.location_id
                   AND hl.country = ft.territory_code
                   AND ft.language = USERENV ('LANG')
                   AND trx.customer_trx_id = ps.customer_trx_id
                   AND trx.term_id = rt.term_id(+)
                   AND rtld.term_id(+) = trx.term_id
                   AND trx.cust_trx_type_id = rctt.cust_trx_type_id
                   AND trx.org_id = rctt.org_id
                   AND rctt.TYPE IN ('INV', 'CM', 'DM')
                   AND trx.complete_flag = 'Y'
                   AND NVL (trx.printing_option, 'PRI') = 'PRI'
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxd_ar_trx_hdr_stg stg
                             WHERE     stg.invoice_id = trx.customer_trx_id
                                   AND stg.process_flag = 'Y')
                   AND NVL (trx.printing_pending, 'Y') = 'Y'
                   AND hou.organization_id = pn_org_id
                   AND trx.bill_to_customer_id =
                       NVL (pn_customer_id, trx.bill_to_customer_id)
                   AND trx.customer_trx_id =
                       NVL (pv_trx_number, trx.customer_trx_id)
                   AND trx.trx_date BETWEEN NVL (p_trx_date_from,
                                                 trx.trx_date)
                                        AND NVL (p_trx_date_to, trx.trx_date);

        CURSOR c_reprocess (p_org_id          IN NUMBER,
                            p_trx_number      IN VARCHAR2,
                            p_trx_date_from   IN DATE,
                            p_trx_date_to     IN DATE,
                            pn_customer_id    IN VARCHAR2)
        IS
            SELECT trx.customer_trx_id
                       invoice_id,
                   trx.trx_number
                       invoice_number,
                   TO_CHAR (trx.trx_date, 'DD-MON-RRRR')
                       invoice_date,
                   TO_CHAR (ps.due_date, 'DD-MON-RRRR')
                       term_due_date,
                   rt.description
                       payment_term,
                   trx.invoice_currency_code
                       invoice_currency_code,
                   NULL
                       document_type,
                   trx.set_of_books_id,
                   trx.org_id,
                   NULL
                       duty_stamp,
                   NULL
                       le_registriation_number,
                   NULL
                       company_reg_number,
                   NULL
                       share_capital,
                   NULL
                       status_shareholders,
                   NULL
                       liquidation_status,
                   hca.cust_account_id,
                   hp.party_name
                       bill_to_customer_name,
                   hca.account_number
                       bill_to_cust_acct_num,
                   hl.address1
                       bill_to_address_street,
                   hl.city
                       bill_to_address_city,
                   hl.postal_code
                       bill_to_address_postal_code,
                   hl.province
                       bill_to_address_province,
                   ft.territory_short_name
                       bill_to_address_country,
                   hl.country
                       bill_to_address_country_code,
                   hcsa.site_use_id
                       bill_to_site_use_id,
                   NVL (hcsa.tax_reference, hp.tax_reference)
                       bill_to_vat_number,
                   NULL
                       bill_to_business_reg_number,
                   NULL
                       bill_to_unique_rec_identifier,
                   NVL (hp.attribute19, '0000000')
                       bill_to_routing_code,
                   NULL
                       bill_to_email,
                   NULL
                       bill_to_telphone,
                   trx.printing_option,
                   rctt.TYPE,
                   DECODE (rctt.TYPE,
                           'CM', 'Credit Memo',
                           'DM', 'Debit Memo',
                           'INV', 'Invoice',
                           NULL)
                       transaction_type,
                   trx.attribute6
                       original_invoice,
                   trx.purchase_order
                       purchase_order,
                   REPLACE (
                       REPLACE (REPLACE (trx.comments, CHR (9), ' '),
                                CHR (10),
                                ' '),
                       '|',
                       ' ')
                       comments,
                   REPLACE (
                       REPLACE (REPLACE (trx.comments, CHR (9), ' '),
                                CHR (10),
                                ' '),
                       '|',
                       ' ')
                       invoice_comments,
                   DECODE (trx.waybill_number, '0', '', trx.waybill_number)
                       waybill_number,
                   trx.interface_header_context,
                   hou.name
                       operating_unit,
                   NVL (trx.interface_header_attribute1, trx.ct_reference)
                       order_reference,
                   trx.interface_header_attribute2
                       order_type,
                   DECODE (trx.interface_header_attribute3,
                           '0', '',
                           trx.interface_header_attribute3)
                       delivery_number,
                   ps.due_date
                       due_date,
                   TO_CHAR (ps.due_date, 'MM/DD/YYYY')
                       due_date_dsp,
                   ps.amount_due_original
                       invoice_amount,
                   ps.amount_due_original
                       inv_amt_dsp,
                   ps.amount_line_items_original,
                   ps.amount_line_items_original
                       invoice_line_amt_dsp,
                   ps.freight_original,
                   ps.freight_original
                       invoice_freight_amt_dsp,
                   ps.tax_original,
                   ps.tax_original
                       invoice_tax_amt_dsp,
                   (SELECT SUM (zl.tax_amt)
                      FROM zx_lines zl, ra_customer_trx_lines_all rctl
                     WHERE     zl.application_id = 222
                           AND zl.trx_id = trx.customer_trx_id
                           AND zl.trx_id = rctl.customer_trx_id
                           AND zl.trx_line_id = rctl.customer_trx_line_id
                           AND NVL (rctl.inventory_item_id, 0) <> 1569786 --excluding freight charges
                           AND zl.internal_organization_id = trx.org_id)
                       h_total_tax_amount,
                   get_tot_net_amount (trx.customer_trx_id)
                       h_total_net_amount,
                   get_h_discount_amount (trx.customer_trx_id)
                       h_discount_amt,
                   (SELECT rtax.tax_rate
                      FROM ra_customer_trx_lines_all rctl, ra_customer_trx_lines_all rtax
                     WHERE     rctl.customer_trx_line_id =
                               rtax.link_to_cust_trx_line_id
                           AND rctl.customer_trx_id = trx.customer_trx_id
                           AND UPPER (rctl.description) LIKE
                                   UPPER ('%Discount%')
                           AND ROWNUM = 1)
                       h_discount_rate,
                   DECODE (
                       rt.calc_discount_on_lines_flag,
                       'L', (ROUND (ps.freight_original + ps.tax_original + (ps.amount_line_items_original * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1))), 2)),
                       'I', (ROUND ((ps.amount_due_original * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1))), 2)),
                       'T', (ROUND ((ps.freight_original * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1))) + (ps.tax_original * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1))) + (ps.amount_line_items_original * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1))), 2)),
                       'F', (ROUND (
                                   ps.freight_original
                                 + (  (  ps.tax_original
                                       - (SELECT NVL (SUM (extended_amount), 0)
                                            FROM apps.ra_customer_trx_lines_all rctl
                                           WHERE     rctl.customer_trx_id =
                                                     trx.customer_trx_id
                                                 AND line_type = 'TAX'
                                                 AND link_to_cust_trx_line_id IN
                                                         (SELECT customer_trx_line_id
                                                            FROM apps.ra_customer_trx_lines_all rctl1
                                                           WHERE     1 = 1
                                                                 AND line_type =
                                                                     'FREIGHT'
                                                                 AND rctl1.customer_trx_id =
                                                                     rctl.customer_trx_id)))
                                    * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1)))
                                 + (ps.amount_line_items_original * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1))),
                                 2)))
                       AS disc_amt,
                   ROUND (
                         ps.freight_original
                       + ps.tax_original
                       + (ps.amount_line_items_original * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1))),
                       2)
                       disc_amt_dsp,
                     ROUND (ps.amount_due_original, 2)
                   - ROUND (
                           ps.freight_original
                         + ps.tax_original
                         + (ps.amount_line_items_original * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1))),
                         2)
                       AS discount,
                   DECODE (
                       rt.calc_discount_on_lines_flag,
                       'L', (ROUND (ps.amount_due_original, 2) - ROUND (ps.freight_original + ps.tax_original + (ps.amount_line_items_original * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1))), 2)),
                       'I', (ROUND (ps.amount_due_original, 2) - ROUND ((ps.amount_due_original * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1))), 2)),
                       'T', (ROUND (ps.amount_due_original, 2) - ROUND ((ps.freight_original * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1))) + (ps.tax_original * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1))) + (ps.amount_line_items_original * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1))), 2)),
                       'F', (  ROUND (ps.amount_due_original, 2)
                             - ROUND (
                                     ps.freight_original
                                   + (  (  ps.tax_original
                                         - (SELECT NVL (SUM (extended_amount), 0)
                                              FROM apps.ra_customer_trx_lines_all rctl
                                             WHERE     rctl.customer_trx_id =
                                                       trx.customer_trx_id
                                                   AND line_type = 'TAX'
                                                   AND link_to_cust_trx_line_id IN
                                                           (SELECT customer_trx_line_id
                                                              FROM apps.ra_customer_trx_lines_all rctl1
                                                             WHERE     1 = 1
                                                                   AND line_type =
                                                                       'FREIGHT'
                                                                   AND rctl1.customer_trx_id =
                                                                       rctl.customer_trx_id)))
                                      * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1)))
                                   + (ps.amount_line_items_original * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1))),
                                   2)))
                       AS discounted
              FROM apps.ra_customer_trx_all trx, apps.ar_payment_schedules_all ps, apps.ra_cust_trx_types_all rctt,
                   apps.ra_terms rt, apps.ra_terms_lines_discounts rtld, hz_cust_accounts hca,
                   hz_parties hp, hz_party_sites hps, hz_cust_acct_sites_all hcas,
                   hz_cust_site_uses_all hcsa, hz_locations hl, apps.fnd_territories_tl ft,
                   apps.hr_operating_units hou
             WHERE     1 = 1
                   AND trx.org_id = hou.organization_id
                   AND trx.bill_to_customer_id = hca.cust_account_id
                   AND trx.bill_to_site_use_id = hcsa.site_use_id
                   AND hca.party_id = hp.party_id
                   AND hp.party_id = hps.party_id
                   AND hps.party_site_id = hcas.party_site_id
                   AND hca.cust_account_id = hcas.cust_account_id
                   AND hcas.cust_acct_site_id = hcsa.cust_acct_site_id
                   AND hcsa.site_use_code = 'BILL_TO'
                   AND hps.location_id = hl.location_id
                   AND hl.country = ft.territory_code
                   AND ft.language = USERENV ('LANG')
                   AND trx.customer_trx_id = ps.customer_trx_id
                   AND trx.term_id = rt.term_id(+)
                   AND rtld.term_id(+) = trx.term_id
                   AND trx.cust_trx_type_id = rctt.cust_trx_type_id
                   AND trx.org_id = rctt.org_id
                   AND rctt.TYPE IN ('INV', 'CM', 'DM')
                   AND trx.complete_flag = 'Y'
                   AND NVL (trx.printing_option, 'PRI') = 'PRI'
                   AND NVL (trx.printing_pending, 'Y') = 'Y'
                   AND hou.organization_id = pn_org_id
                   AND trx.bill_to_customer_id =
                       NVL (pn_customer_id, trx.bill_to_customer_id)
                   AND trx.customer_trx_id =
                       NVL (pv_trx_number, trx.customer_trx_id)
                   AND trx.trx_date BETWEEN NVL (p_trx_date_from,
                                                 trx.trx_date)
                                        AND NVL (p_trx_date_to, trx.trx_date);

        CURSOR c_line (p_cust_trx_id IN NUMBER)
        IS
            SELECT rctl.customer_trx_id, rctl.customer_trx_line_id, rctl.line_number,
                   get_comp_segment (rctl.customer_trx_id, rctl.customer_trx_line_id) l_company_segment, rctl.interface_line_attribute6, rctl.interface_line_attribute1,
                   rctl.interface_line_context, (msi.style_number || '-' || rctl.description || '/' || msi.color_code) l_description_goods, NVL (rctl.uom_code, 'EA') uom_code,
                   DECODE (NVL (rctl.interface_line_attribute11, 0), 0, NVL (rctl.quantity_invoiced, rctl.quantity_credited), 0) qty_total_dsp, NVL (DECODE (DECODE (NVL (rctl.interface_line_attribute11, 0), 0, NVL (rctl.quantity_invoiced, rctl.quantity_credited), 0), 0, 0, rctl.extended_amount / DECODE (NVL (rctl.interface_line_attribute11, 0), 0, NVL (rctl.quantity_invoiced, rctl.quantity_credited), 0)), rctl.unit_selling_price) avg_unit_price_dsp, (rctl.quantity_invoiced * rctl.unit_selling_price * 0.1) l_vat_amount,
                   NULL l_vat_rate, NULL l_tax_expemtion_code, (rctl.quantity_invoiced * rctl.unit_selling_price) l_net_amount,
                   NULL l_discount_amount, NULL l_discount_description, NULL l_charge_amount,
                   NULL l_charge_description, NULL l_delivery_date, rctl.description line_description,
                   msi.style_number l_item_style, msi.color_code item_color, msi.style_desc,
                   msi.color_desc, DECODE (msi.item_number, 'FRT-NA-NA', msi.style_desc, msi.style_number) item_style1, DECODE (msi.item_number, 'FRT-NA-NA', msi.color_desc, msi.color_code) item_color1,
                   msi.item_size l_size_qty, rctl.extended_amount ext_amt_dsp, rctl.inventory_item_id,
                   rctl.unit_selling_price, NVL (rctl.quantity_invoiced, rctl.quantity_credited) quantity_invoiced, rctl.tax_recoverable,
                   rctl.warehouse_id, rtax.tax_rate, get_tax_code (rctl.org_id, rctl.customer_trx_id) tax_code,
                   get_tax_exempt_text (rctl.org_id, rctl.customer_trx_id) tax_exempt_text
              FROM apps.ra_customer_trx_lines_all rctl, apps.ra_customer_trx_lines_all rtax, apps.xxd_common_items_v msi
             WHERE     1 = 1
                   AND rctl.customer_trx_line_id =
                       rtax.link_to_cust_trx_line_id(+)
                   AND rctl.inventory_item_id = msi.inventory_item_id(+)
                   AND rctl.warehouse_id = msi.organization_id(+)
                   AND rctl.line_type IN ('LINE')
                   AND NVL (rctl.inventory_item_id, 0) <> 1569786
                   AND NVL (rctl.interface_line_attribute11, 0) = 0
                   AND rctl.customer_trx_id = p_cust_trx_id;

        --Define Variables
        ld_trx_date_from          DATE;
        ld_trx_date_to            DATE;
        lv_le_entity_name         xle_entity_profiles.name%TYPE;
        lv_le_address_street      hr_locations.address_line_1%TYPE;
        lv_le_address_post_code   hr_locations.postal_code%TYPE;
        lv_le_address_city        hr_locations.town_or_city%TYPE;
        lv_le_address_province    hr_locations.region_1%TYPE;
        lv_le_country             fnd_territories_tl.territory_short_name%TYPE;
        lv_le_country_code        hr_locations.country%TYPE;
        lv_le_vat_number          VARCHAR2 (50);
        lv_inco_term              VARCHAR2 (100);
        lv_to_email_address       VARCHAR2 (360);
        lv_business_reg_num       VARCHAR2 (20);        --- CCR0010450 EEK-180
        lv_to_phone_number        VARCHAR2 (100);
        ln_qty_sum                NUMBER;
        ln_line_amt               NUMBER;
        ln_unit_price             NUMBER;
        ln_unit_price_list        NUMBER;
        ln_disc_percent           NUMBER;
        lv_tax_yn                 VARCHAR2 (30);
        ln_line_tax_rate          NUMBER;
        ln_line_tax_amt           NUMBER;
        lv_tax_code               VARCHAR2 (240);
        lv_tax_rate_des           VARCHAR2 (240);
        lv_tax_rate_code          VARCHAR2 (240);
        lv_tax_exemption_code     VARCHAR2 (150);
        lv_tax_exemption_text     VARCHAR2 (150);
        lv_company_reg_num        VARCHAR2 (30);
        lv_share_capital          VARCHAR2 (30);
        lv_status_shareholders    VARCHAR2 (30);
        lv_liquidation_status     VARCHAR2 (30);
        lv_seller_email           VARCHAR2 (30);
        lv_seller_fax             VARCHAR2 (30);
        lv_seller_tel             VARCHAR2 (30);
        lv_document_type          VARCHAR2 (30);
        lv_bank_acct_num          VARCHAR2 (30);
        lv_swift_code             VARCHAR2 (60);
        lv_iban_num               VARCHAR2 (60);
        ln_vat_amount             NUMBER;
        ln_vat_net_amount         NUMBER;
        ld_creation_Date          DATE;

        ln_vat_s_t0               NUMBER;
        ln_vat_s_t1               NUMBER;
        ln_vat_s_t2               NUMBER;
        ln_vat_s_tot              NUMBER;
        ln_hdr_err_count          NUMBER := 0;
        ln_line_err_count         NUMBER := 0;

        lv_item_code              VARCHAR2 (60);
        lv_origin_country         VARCHAR2 (60);
        ln_charge_amount          NUMBER;
        ln_charge_rate            NUMBER;
        l_original_invoice        VARCHAR2 (60);
        lv_conc_error             VARCHAR2 (32767) := NULL;
        lv_description_goods      VARCHAR2 (2000);
        ln_quantity               NUMBER;
        ln_avg_unit_price         NUMBER;
    BEGIN
        ld_trx_date_from   :=
            TO_DATE (pd_trx_date_from, 'RRRR/MM/DD HH24:MI:SS');
        ld_trx_date_to   := TO_DATE (pd_trx_date_to, 'RRRR/MM/DD HH24:MI:SS');

        get_le_details (pn_org_id              => pn_org_id,
                        xv_le_entity_name      => lv_le_entity_name,
                        xv_le_addr_street      => lv_le_address_street,
                        xv_le_addr_post_code   => lv_le_address_post_code,
                        xv_le_addr_city        => lv_le_address_city,
                        xv_le_addr_province    => lv_le_address_province,
                        xv_le_country          => lv_le_country,
                        xv_le_country_code     => lv_le_country_code,
                        xv_le_vat_number       => lv_le_vat_number);

        -- to get constant values
        get_constant_values (xv_company_reg_number => lv_company_reg_num, xv_liquidation_status => lv_liquidation_status, xv_share_capital => lv_share_capital, xv_status_share => lv_status_shareholders, xv_seller_email => lv_seller_email, xv_seller_fax => lv_seller_fax
                             , xv_seller_tel => lv_seller_tel);

        -- To get bank details
        get_bank_details (pn_org_id => pn_org_id, xv_bank_acc_num => lv_bank_acct_num, xv_swift_code => lv_swift_code
                          , xv_iban_num => lv_iban_num);

        FOR i
            IN c_hdr (p_org_id          => pn_org_id,
                      p_trx_number      => pv_trx_number,
                      p_trx_date_from   => ld_trx_date_from, --pd_trx_date_from,
                      p_trx_date_to     => ld_trx_date_to,   --pd_trx_date_to,
                      pn_customer_id    => pn_customer_id)
        LOOP
            lv_inco_term            := NULL;
            lv_to_email_address     := NULL;
            lv_business_reg_num     := NULL;                    --- CCR0010450
            lv_to_phone_number      := NULL;
            lv_tax_exemption_code   := NULL;
            lv_document_type        := NULL;

            ln_vat_s_t0             := 0;
            ln_vat_s_t1             := 0;
            ln_vat_s_t2             := 0;
            ln_vat_s_tot            := 0;
            ln_hdr_err_count        := 0;

            lv_inco_term            := get_inco_term (i.operating_unit);


            -- to get the document type
            BEGIN
                SELECT ffv.flex_value
                  INTO lv_document_type
                  FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffv
                 WHERE     ffvs.flex_value_set_name =
                           'XXD_AR_DOCUMENT_TYPE_VS'
                       AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                       AND ffv.description = i.TYPE;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_document_type   := NULL;
            END;

            -- to get Business reg NUMBER
            lv_business_reg_num     :=
                get_business_reg_num (p_customer_id => i.cust_account_id);



            -- to get email adress

            lv_to_email_address     :=
                get_to_email_address (
                    p_customer_id    => i.cust_account_id,
                    p_trx_class      => i.TYPE,
                    p_bill_site_id   => i.bill_to_site_use_id);
            lv_to_phone_number      :=
                get_to_phone_number (p_customer_id => i.cust_account_id);

            get_sub_totals_prc (p_customer_trx_id   => i.invoice_id,
                                x_vat_s_t0          => ln_vat_s_t0,
                                x_vat_s_t1          => ln_vat_s_t1,
                                x_vat_s_t2          => ln_vat_s_t2,
                                x_vat_s_tot         => ln_vat_s_tot);


            -- Validation Starts
            IF i.term_due_date IS NULL
            THEN
                add_error_message (
                    i.invoice_id,
                    i.invoice_number,
                    i.invoice_date,
                    'PAYMENT_DUE_DATE_NULL',
                    'The Invoice Number does not have Payment Due Date ');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'PAYMENT_DUE_DATE_NULL';
            END IF;

            IF i.invoice_currency_code IS NULL
            THEN
                add_error_message (
                    i.invoice_id,
                    i.invoice_number,
                    i.invoice_date,
                    'CURRENCY_CODE_NULL',
                    'The Invoice number does not have Currency Code ');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'CURRENCY_CODE_NULL';
            END IF;

            IF lv_document_type IS NULL
            THEN
                add_error_message (
                    i.invoice_id,
                    i.invoice_number,
                    i.invoice_date,
                    'DOCUMENT_TYPE_NULL',
                    'The Invoice number does not have Document Type ');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'DOCUMENT_TYPE_NULL';
            END IF;


            IF lv_le_entity_name IS NULL
            THEN
                add_error_message (i.invoice_id,
                                   i.invoice_number,
                                   i.invoice_date,
                                   'INVALID_LEGAL_ENTITY',
                                   'Invalid Legal Entity Name ');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'INVALID_LEGAL_ENTITY';
            END IF;

            IF lv_le_address_street IS NULL
            THEN
                add_error_message (
                    i.invoice_id,
                    i.invoice_number,
                    i.invoice_date,
                    'INVALID_LE_ADDRESS_STREET',
                    'Legal Entity does not have Address Street ');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'INVALID_LE_ADDRESS_STREET';
            END IF;

            IF (lv_le_address_post_code) IS NULL
            THEN
                add_error_message (i.invoice_id,
                                   i.invoice_number,
                                   i.invoice_date,
                                   'INVALID_LE_POSTAL_CODE',
                                   'Legal Entity does not have Postal Code ');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'INVALID_LE_POSTAL_CODE';
            END IF;

            IF (lv_le_address_city) IS NULL
            THEN
                add_error_message (
                    i.invoice_id,
                    i.invoice_number,
                    i.invoice_date,
                    'INVALID_LE_CITY',
                    'Legal Entity does not have Address City ');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'INVALID_LE_CITY';
            END IF;

            IF (lv_le_country_code) IS NULL
            THEN
                add_error_message (i.invoice_id,
                                   i.invoice_number,
                                   i.invoice_date,
                                   'INVALID_LE_COUNTRY_CODE',
                                   'Legal Entity does not have Country Code');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'INVALID_LE_COUNTRY_CODE';
            END IF;

            IF (lv_company_reg_num) IS NULL
            THEN
                add_error_message (
                    i.invoice_id,
                    i.invoice_number,
                    i.invoice_date,
                    'INVALID_COMPANY_REG_NUMBER',
                    'Legal Entity does not have Company registration number');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'INVALID_COMPANY_REG_NUMBER';
            END IF;

            IF (lv_le_address_province) IS NULL
            THEN
                add_error_message (i.invoice_id,
                                   i.invoice_number,
                                   i.invoice_date,
                                   'INVALID_COMPANY_PROVINCE',
                                   'Invalid Province of registration office');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'INVALID_COMPANY_PROVINCE';
            END IF;

            IF (i.bill_to_cust_acct_num) IS NULL
            THEN
                add_error_message (
                    i.invoice_id,
                    i.invoice_number,
                    i.invoice_date,
                    'INVALID_CUST_ACCT_NUM',
                    'The Invoice does not have Bill-TO Customer Number information');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'INVALID_CUST_ACCT_NUM';
            END IF;

            IF (i.bill_to_customer_name) IS NULL
            THEN
                add_error_message (
                    i.invoice_id,
                    i.invoice_number,
                    i.invoice_date,
                    'INVALID_CUSTOMER_NAME',
                    'The Invoice does not have Bill-TO Customer Name information');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'INVALID_CUSTOMER_NAME';
            END IF;

            IF (i.bill_to_address_street) IS NULL
            THEN
                add_error_message (
                    i.invoice_id,
                    i.invoice_number,
                    i.invoice_date,
                    'INVALID_BILL_TO_ADDRESS_STREET',
                    'The Customer does not have address street information');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'INVALID_BILL_TO_ADDRESS_STREET';
            END IF;

            IF (i.bill_to_address_postal_code) IS NULL
            THEN
                add_error_message (
                    i.invoice_id,
                    i.invoice_number,
                    i.invoice_date,
                    'INVALID_BILL_TO_ADDRESS_POST_CODE',
                    'The Customer does not have postal code information');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                       lv_conc_error
                    || ','
                    || 'INVALID_BILL_TO_ADDRESS_POST_CODE';
            END IF;

            IF (i.bill_to_address_city) IS NULL
            THEN
                add_error_message (
                    i.invoice_id,
                    i.invoice_number,
                    i.invoice_date,
                    'INVALID_BILL_TO_ADDRESS_CITY',
                    'The Customer does not have city information');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'INVALID_BILL_TO_ADDRESS_CITY';
            END IF;

            IF (i.bill_to_address_country_code) IS NULL
            THEN
                add_error_message (i.invoice_id,
                                   i.invoice_number,
                                   i.invoice_date,
                                   'INVALID_BILL_TO_ADDRESS_COUNTRY_CODE',
                                   'The Customer does not have country code');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                       lv_conc_error
                    || ','
                    || 'INVALID_BILL_TO_ADDRESS_COUNTRY_CODE';
            END IF;


            IF (i.bill_to_vat_number IS NULL AND lv_business_reg_num IS NULL)
            THEN
                add_error_message (
                    i.invoice_id,
                    i.invoice_number,
                    i.invoice_date,
                    'VAT_AND_BUSINESS_REG_NUM_NULL',
                    'The Customer does not have VAT Number and Business Registration Number ');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'VAT_AND_BUSINESS_REG_NUM_NULL';
            END IF;

            IF (NVL (i.bill_to_routing_code, '0000000') = '0000000' AND lv_to_email_address IS NULL)
            THEN
                add_error_message (
                    i.invoice_id,
                    i.invoice_number,
                    i.invoice_date,
                    'BILL_ROUTING_CODE_NULL',
                    'The Customer does not have Routing Code and Email Address ');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'BILL_ROUTING_CODE_NULL';
            END IF;

            IF (i.invoice_line_amt_dsp IS NULL)
            THEN
                add_error_message (
                    i.invoice_id,
                    i.invoice_number,
                    i.invoice_date,
                    'INVALID_TOTAL_NET_AMOUNT',
                    'Invalid Total net amount of all line items');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'INVALID_TOTAL_NET_AMOUNT';
            END IF;

            IF (i.invoice_tax_amt_dsp IS NULL)
            THEN
                add_error_message (i.invoice_id,
                                   i.invoice_number,
                                   i.invoice_date,
                                   'INVALID_TOTAL_VAT_AMOUNT',
                                   'Invalid Total VAT amount of the invoice');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'INVALID_TOTAL_VAT_AMOUNT';
            END IF;

            IF (i.inv_amt_dsp IS NULL)
            THEN
                add_error_message (i.invoice_id,
                                   i.invoice_number,
                                   i.invoice_date,
                                   'INVALID_INVOICE_TOTAL',
                                   'Invalid Total Invoice amount');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'INVALID_INVOICE_TOTAL';
            END IF;

            BEGIN
                SELECT (rctl.quantity_invoiced * rctl.unit_selling_price) freight_charge, rtax.tax_rate
                  INTO ln_charge_amount, ln_charge_rate
                  FROM ra_customer_trx_lines_all rctl, ra_customer_trx_lines_all rtax
                 WHERE     rctl.customer_trx_line_id =
                           rtax.link_to_cust_trx_line_id(+)
                       AND NVL (rctl.inventory_item_id, 0) = 1569786 -- Default Freight Item
                       AND rctl.customer_trx_id = i.invoice_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_charge_amount   := 0;
                    ln_charge_rate     := 0;
            END;

            -- get original invoice number

            IF i.TYPE IN ('CM', 'DM')
            THEN
                IF i.original_invoice IS NOT NULL
                THEN
                    l_original_invoice   := i.original_invoice;
                ELSIF i.original_invoice IS NULL
                THEN
                    BEGIN
                        SELECT sl.user_element_attribute5
                          INTO l_original_invoice
                          FROM sabrix_line sl
                         WHERE     sl.user_element_attribute5 IS NOT NULL
                               AND ROWNUM = 1
                               AND sl.batch_id =
                                   (SELECT MAX (si.batch_id)
                                      FROM sabrix_invoice si
                                     WHERE     si.user_element_attribute41 =
                                               i.invoice_id
                                           AND si.user_element_attribute45 =
                                               i.org_id);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_original_invoice   := NULL;
                    END;
                END IF;

                IF (i.TYPE = 'CM' AND l_original_invoice IS NULL)
                THEN
                    add_error_message (i.invoice_id,
                                       i.invoice_number,
                                       i.invoice_date,
                                       'ORIGINAL_INVOICE_IS_NULL',
                                       'Original Invoice number is null ');
                    ln_hdr_err_count   := 1;
                    lv_conc_error      :=
                        lv_conc_error || ',' || 'ORIGINAL_INVOICE_IS_NULL';
                END IF;
            END IF;

            BEGIN
                INSERT INTO XXDO.xxd_ar_trx_hdr_stg (
                                invoice_id,
                                invoice_number,
                                invoice_date,
                                payment_due_date,
                                payment_term,
                                invoice_currency_code,
                                transaction_type,
                                org_id,
                                set_of_books_id,
                                duty_stamp,
                                document_type,
                                legal_entity_name,
                                legal_entity_address_street,
                                legal_entity_address_postal_code,
                                legal_entity_address_city,
                                legal_entity_address_province,
                                legal_entity_country,
                                legal_entity_country_code,
                                le_vat_number,
                                le_registriation_number,
                                seller_contact_tel,
                                seller_contact_fax,
                                seller_contact_email,
                                bank_account_num,
                                bank_swfit_bic,
                                bank_iban,
                                province_reg_office,
                                company_reg_number,
                                share_capital,
                                status_shareholders,
                                liquidation_status,
                                bill_to_customer_num,
                                bill_to_customer_name,
                                bill_to_address_street,
                                bill_to_address_postal_code,
                                bill_to_address_city,
                                bill_to_address_province,
                                bill_to_address_country,
                                bill_to_address_country_code,
                                bill_to_vat_number,
                                bill_to_business_registration_number,
                                bill_to_unique_recipient_identifier,
                                bill_to_routing_code,
                                bill_to_email,
                                bill_to_telphone,
                                printing_pending,
                                h_total_tax_amount,
                                h_total_net_amount,
                                h_total_net_amount_including_discount_charges,
                                h_invoice_total,
                                h_rounding_amt,
                                h_discount_amount,
                                h_discount_description,
                                h_discount_tax_rate,
                                h_charge_amount,
                                h_charge_description,
                                h_charge_tax_rate,
                                invoice_doc_reference,
                                inv_doc_ref_desc,
                                h_tender_ref,
                                h_project_ref,
                                h_cust_po,
                                h_sales_order,
                                h_inco_term,
                                h_delivery_num,
                                cust_acct_num,
                                tax_chg_code,
                                created_by,
                                creation_date,
                                last_updated_by,
                                last_update_date,
                                last_update_login,
                                conc_request_id,
                                process_flag,
                                reprocess_flag,
                                extract_flag,
                                extract_date,
                                ERROR_CODE)
                     VALUES (i.invoice_id, i.invoice_number, i.invoice_date,
                             i.term_due_date, i.payment_term, i.invoice_currency_code, i.transaction_type, i.org_id, i.set_of_books_id, i.duty_stamp, lv_document_type, remove_junk (lv_le_entity_name), remove_junk (lv_le_address_street), remove_junk (lv_le_address_post_code), remove_junk (lv_le_address_city), remove_junk (lv_le_address_province), remove_junk (lv_le_country), remove_junk (lv_le_country_code), remove_junk (lv_le_vat_number), remove_junk (i.le_registriation_number), remove_junk (lv_seller_tel), lv_seller_fax, remove_junk (lv_seller_email), lv_bank_Acct_num, remove_junk (lv_swift_code), remove_junk (lv_iban_num), remove_junk (lv_le_address_province), lv_company_reg_num, lv_share_capital, lv_status_shareholders, lv_liquidation_status, remove_junk (i.bill_to_cust_acct_num), remove_junk (i.bill_to_customer_name), remove_junk (i.bill_to_address_street), remove_junk (i.bill_to_address_postal_code), remove_junk (i.bill_to_address_city), remove_junk (i.bill_to_address_province), remove_junk (i.bill_to_address_country), remove_junk (i.bill_to_address_country_code), remove_junk (i.bill_to_vat_number)-- ,i.bill_to_business_reg_number
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                , remove_junk (lv_business_reg_num) --- CCR0010450
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   , i.bill_to_unique_rec_identifier, remove_junk (i.bill_to_routing_code), remove_junk (lv_to_email_address), remove_junk (lv_to_phone_number), i.printing_option, i.invoice_tax_amt_dsp --h_total_tax_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         , i.h_total_net_amount --h_total_net_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               , i.invoice_line_amt_dsp --h_tot_net_amt_incl_disc_chrgs
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       , i.inv_amt_dsp --h_invoice_total
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      , NULL --h_rounding_amt
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            , NULL --        i.h_discount_amt
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  , NULL --DECODE(i.h_discount_amt,0,NULL,NULL,'','Discount')                 --h_discount_description
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        , NULL ---DECODE(i.h_discount_amt,0,NULL,NULL,'',i.h_discount_rate)     --h_discount_rate                                                        --h_discount_tax_rate
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              , DECODE (i.invoice_freight_amt_dsp, 0, DECODE (ln_charge_amount, 0, NULL, ln_charge_amount), i.invoice_freight_amt_dsp) --h_charge_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      , DECODE (DECODE (i.invoice_freight_amt_dsp, 0, ln_charge_amount, i.invoice_freight_amt_dsp), 0, NULL, 'Freight') --h_charge_description
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       , DECODE (ln_vat_s_t1, 0, ln_charge_rate, ln_vat_s_t1) --h_charge_tax_rate
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             , DECODE (i.TYPE,  'CM', remove_junk (l_original_invoice),  'DM', remove_junk (l_original_invoice),  NULL) --invoice_doc_reference
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       , NULL --inv_doc_ref_desc
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             , NULL --h_tender_ref
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   , NULL --h_project_ref
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         , remove_junk (i.purchase_order) --h_cust_po
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         , remove_junk (i.order_reference) --h_sales_order
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          , remove_junk (lv_inco_term) --h_inco_term
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      , i.delivery_number --h_delivery_num
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         , i.bill_to_cust_acct_num --cust_acct_num
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  , NULL --tax_chg_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        , gn_user_id, SYSDATE, gn_user_id, SYSDATE, gn_user_id, gn_conc_request_id, 'N', pv_reprocess_flag
                             , NULL, SYSDATE, NULL);

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Failed to insert the data into custom table:'
                        || SQLERRM);
            END;


            -- Inserting Lines data
            FOR j IN c_line (i.invoice_id)
            LOOP
                ln_qty_sum              := NULL;
                ln_line_amt             := NULL;
                ln_unit_price           := NULL;
                ln_unit_price_list      := NULL;
                ln_disc_percent         := NULL;
                lv_tax_yn               := NULL;
                ln_line_tax_rate        := NULL;
                lv_tax_code             := NULL;
                lv_tax_rate_des         := NULL;
                lv_tax_rate_code        := NULL;
                lv_tax_exemption_code   := NULL;
                lv_tax_exemption_text   := NULL;
                ln_line_tax_amt         := NULL;
                ln_vat_amount           := NULL;
                ln_vat_net_amount       := NULL;

                ln_line_err_count       := 0;


                BEGIN
                    --Get Line Data
                    get_line_data (p_style => j.item_style1, p_color => j.item_color1, p_size => j.l_size_qty, p_cust_trx_id => j.customer_trx_id, p_tax_rec => j.tax_recoverable, p_inventory_item_id => j.inventory_item_id, p_int_line_att6 => j.interface_line_attribute6, x_qty_sum => ln_qty_sum, x_line_amt => ln_line_amt, x_unit_price => ln_unit_price, x_unit_price_list => ln_unit_price_list, x_disc_percent => ln_disc_percent
                                   , x_tax_yn => lv_tax_yn);

                    ln_line_tax_rate   :=
                        get_line_tax_rate (
                            p_org_id                 => i.org_id,
                            p_customer_trx_id        => j.customer_trx_id,
                            p_customer_trx_line_id   => j.customer_trx_line_id);

                    ln_line_tax_amt   :=
                        get_line_tax_amt (
                            p_org_id                 => i.org_id,
                            p_customer_trx_id        => j.customer_trx_id,
                            p_customer_trx_line_id   => j.customer_trx_line_id);

                    ln_vat_amount   :=
                        get_vat_amount (
                            p_org_id            => i.org_id,
                            p_customer_trx_id   => j.customer_trx_id,
                            p_tax_rate          => j.tax_rate);

                    ln_vat_net_amount   :=
                        get_vat_net_amount (
                            p_org_id            => i.org_id,
                            p_customer_trx_id   => j.customer_trx_id,
                            p_tax_rate          => j.tax_rate);


                    get_line_tax_rate_det (i.org_id,
                                           i.invoice_id,
                                           j.customer_trx_line_id,
                                           lv_tax_code,
                                           lv_tax_rate_des,
                                           lv_tax_rate_code);

                    -- For Debit Memo invoice, sign change for qty and unit_price

                    IF (i.transaction_type = 'Debit Memo' AND j.quantity_invoiced < 0 AND j.avg_unit_price_dsp < 0)
                    THEN
                        ln_quantity         := (-1 * j.quantity_invoiced);
                        ln_avg_unit_price   := (-1 * j.avg_unit_price_dsp);
                    ELSE
                        ln_quantity         := j.quantity_invoiced;
                        ln_avg_unit_price   := j.avg_unit_price_dsp;
                    END IF;


                    BEGIN
                        SELECT TAG, Description
                          INTO lv_tax_exemption_code, lv_tax_exemption_text
                          FROM FND_LOOKUP_VALUES
                         WHERE     lookup_type = 'XXD_AR_NATURA_CODE_MAPPING'
                               AND lookup_code = lv_tax_rate_code
                               AND language = 'US'
                               AND ROWNUM = 1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_tax_exemption_code   := NULL;
                            lv_tax_exemption_text   := NULL;
                    END;

                    get_hcode (p_style => j.l_item_style, p_language => NULL, x_hcode => lv_item_code
                               , x_origin => lv_origin_country);

                    -- Line Level Validation

                    IF (j.style_desc IS NULL AND lv_item_code IS NULL AND j.color_desc IS NULL)
                    THEN
                        lv_description_goods   := j.line_description;

                        IF lv_description_goods IS NULL
                        THEN
                            lv_description_goods   := 'Invoice Line';
                        END IF;
                    ELSE
                        lv_description_goods   :=
                               j.style_desc
                            || ' '
                            || lv_item_code
                            || ' '
                            || j.color_desc;
                    END IF;

                    /*  IF (j.l_description_goods IS NULL ) THEN
                         add_error_message(i.invoice_id,i.invoice_number,i.invoice_date,'INVALID_LINE_DESCRIPTION','Invoice Line Item does not have Description');
                         ln_line_err_count :=1;
          lv_conc_error := lv_conc_error ||  ',' ||   'INVALID_LINE_DESCRIPTION' ;
                      END IF;*/

                    IF (j.uom_code IS NULL)
                    THEN
                        add_error_message (
                            i.invoice_id,
                            i.invoice_number,
                            i.invoice_date,
                            'INVALID_UOM_CODE',
                            'Invoice Line Item does not have Unit of Measure');
                        ln_line_err_count   := 1;
                        lv_conc_error       :=
                            lv_conc_error || ',' || 'INVALID_UOM_CODE';
                    END IF;

                    IF (j.quantity_invoiced IS NULL)
                    THEN
                        add_error_message (
                            i.invoice_id,
                            i.invoice_number,
                            i.invoice_date,
                            'INVALID_QUANTITY',
                            'Invoice Line Item does not have Quantity');
                        ln_line_err_count   := 1;
                        lv_conc_error       :=
                            lv_conc_error || ',' || 'INVALID_QUANTITY';
                    END IF;

                    IF (NVL (ln_unit_price_list, j.unit_selling_price) IS NULL)
                    THEN
                        add_error_message (
                            i.invoice_id,
                            i.invoice_number,
                            i.invoice_date,
                            'INVALID_UNIT_PRICE',
                            'Invoice Line Item does not have Unit Price');
                        ln_line_err_count   := 1;
                        lv_conc_error       :=
                            lv_conc_error || ',' || 'INVALID_UNIT_PRICE';
                    END IF;

                    IF (ln_line_tax_rate IS NULL)
                    THEN
                        add_error_message (
                            i.invoice_id,
                            i.invoice_number,
                            i.invoice_date,
                            'INVALID_LINE_VAT_RATE',
                            'Invoice Line Item does not have VAT Rate');
                        ln_line_err_count   := 1;
                        lv_conc_error       :=
                            lv_conc_error || ',' || 'INVALID_LINE_VAT_RATE';
                    END IF;

                    IF (NVL (ln_line_amt, j.ext_amt_dsp) IS NULL)
                    THEN
                        add_error_message (
                            i.invoice_id,
                            i.invoice_number,
                            i.invoice_date,
                            'INVALID_NET_AMOUNT',
                            'Invoice Line Item does not have Net Amount');
                        ln_line_err_count   := 1;
                        lv_conc_error       :=
                            lv_conc_error || ',' || 'INVALID_NET_AMOUNT';
                    END IF;

                    INSERT INTO xxd_ar_trx_line_stg (concurrent_request_id,
                                                     customer_trx_id,
                                                     customer_trx_line_id,
                                                     l_company_segment,
                                                     l_description_goods,
                                                     l_unit_of_measure,
                                                     l_qty,
                                                     l_unit_price,
                                                     l_vat_amount,
                                                     l_vat_rate,
                                                     vat_net_amount,
                                                     vat_rate,
                                                     vat_amount,
                                                     l_tax_exemption_code,
                                                     l_net_amount,
                                                     l_discount_amount,
                                                     l_discount_description,
                                                     l_charge_amount,
                                                     l_charge_description,
                                                     tax_code,
                                                     tax_exemption_text,
                                                     tax_chg_code,
                                                     l_delivery_date,
                                                     l_item_style,
                                                     l_size_qty,
                                                     line_placeholder1,
                                                     line_placeholder2,
                                                     line_placeholder3,
                                                     item_code,
                                                     country_of_origin,
                                                     created_by,
                                                     creation_date,
                                                     last_updated_by,
                                                     last_update_date,
                                                     last_update_login)
                         VALUES (gn_conc_request_id, j.customer_trx_id, j.customer_trx_line_id, j.l_company_segment, lv_description_goods, j.uom_code, ln_quantity --j.quantity_invoiced
                                                                                                                                                                  , ln_avg_unit_price --j.avg_unit_price_dsp
                                                                                                                                                                                     , ((NVL (ln_line_amt, j.ext_amt_dsp) * ln_line_tax_rate) / 100) --ln_line_tax_amt
                                                                                                                                                                                                                                                    , ln_line_tax_rate, ln_vat_net_amount, ln_line_tax_rate, ln_vat_amount, DECODE (ln_line_tax_rate, 0, lv_tax_exemption_code, NULL) --j.l_tax_expemtion_code
                                                                                                                                                                                                                                                                                                                                                                                     , NVL (ln_line_amt, j.ext_amt_dsp) --j.l_net_amount
                                                                                                                                                                                                                                                                                                                                                                                                                       , ((j.quantity_invoiced * j.avg_unit_price_dsp) - NVL (ln_line_amt, j.ext_amt_dsp)) --l_discount_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          , DECODE (((j.quantity_invoiced * j.avg_unit_price_dsp) - NVL (ln_line_amt, j.ext_amt_dsp)),  0, NULL,  NULL, NULL,  'Discount') --j.l_discount_description
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          , j.l_charge_amount, j.l_charge_description, remove_junk (DECODE (ln_line_tax_rate, 0, j.tax_code, NULL)), remove_junk (DECODE (ln_line_tax_rate, 0, j.tax_exempt_text, NULL)) --j.l_tax_exemption_text
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        , NULL, j.l_delivery_date, j.l_item_style, (lv_origin_country || ' ' || j.l_size_qty || ' ' || j.quantity_invoiced) --j.l_size_qty
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           , lv_tax_rate_des --line_placeholder1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            , NULL --line_placeholder2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  , lv_tax_rate_code --line_placeholder3
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    , lv_item_code, lv_origin_country, gn_user_id, SYSDATE, gn_user_id
                                 , SYSDATE, gn_user_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Failed to insert the lines data into custom table:'
                            || SQLERRM);
                END;
            END LOOP;

            BEGIN
                IF ln_hdr_err_count = 1 OR ln_line_err_count = 1
                THEN
                    UPDATE xxdo.xxd_ar_trx_hdr_stg
                       SET process_flag = 'E', extract_flag = 'N', extract_date = SYSDATE,
                           send_to_pgr = 'N', ERROR_CODE = SUBSTR (LTRIM (lv_conc_error, ','), 1, 4000), last_update_date = SYSDATE,
                           last_updated_by = gn_user_id
                     WHERE     conc_request_id = gn_conc_request_id
                           AND invoice_id = i.invoice_Id;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END LOOP;

        COMMIT;

        populate_errors_table;

        IF pv_reprocess_flag = 'Y'
        THEN
            FOR i
                IN c_reprocess (p_org_id          => pn_org_id,
                                p_trx_number      => pv_trx_number,
                                p_trx_date_from   => ld_trx_date_from,
                                p_trx_date_to     => ld_trx_date_to,
                                pn_customer_id    => pn_customer_id)
            LOOP
                lv_inco_term            := NULL;
                lv_to_email_address     := NULL;
                lv_business_reg_num     := NULL;
                lv_to_phone_number      := NULL;
                lv_tax_exemption_code   := NULL;
                lv_document_type        := NULL;

                ln_vat_s_t0             := 0;
                ln_vat_s_t1             := 0;
                ln_vat_s_t2             := 0;
                ln_vat_s_tot            := 0;


                lv_inco_term            := get_inco_term (i.operating_unit);


                -- to get the document type
                BEGIN
                    SELECT ffv.flex_value
                      INTO lv_document_type
                      FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffv
                     WHERE     ffvs.flex_value_set_name =
                               'XXD_AR_DOCUMENT_TYPE_VS'
                           AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                           AND ffv.description = i.TYPE;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_document_type   := NULL;
                END;


                -- to get Business reg NUMBER
                lv_business_reg_num     :=
                    get_business_reg_num (p_customer_id => i.cust_account_id);
                -- to get email adress

                lv_to_email_address     :=
                    get_to_email_address (
                        p_customer_id    => i.cust_account_id,
                        p_trx_class      => i.TYPE,
                        p_bill_site_id   => i.bill_to_site_use_id -- Added as per change 3.2
                                                                 );
                lv_to_phone_number      :=
                    get_to_phone_number (p_customer_id => i.cust_account_id);

                get_sub_totals_prc (p_customer_trx_id   => i.invoice_id,
                                    x_vat_s_t0          => ln_vat_s_t0,
                                    x_vat_s_t1          => ln_vat_s_t1,
                                    x_vat_s_t2          => ln_vat_s_t2,
                                    x_vat_s_tot         => ln_vat_s_tot);

                BEGIN
                    SELECT (rctl.quantity_invoiced * rctl.unit_selling_price) freight_charge, rtax.tax_rate
                      INTO ln_charge_amount, ln_charge_rate
                      FROM ra_customer_trx_lines_all rctl, ra_customer_trx_lines_all rtax
                     WHERE     rctl.customer_trx_line_id =
                               rtax.link_to_cust_trx_line_id(+)
                           AND NVL (rctl.inventory_item_id, 0) = 1569786 -- Default Freight Item
                           AND rctl.customer_trx_id = i.invoice_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_charge_amount   := 0;
                        ln_charge_rate     := 0;
                END;

                -- get original invoice number

                IF i.TYPE IN ('CM', 'DM')
                THEN
                    IF i.original_invoice IS NOT NULL
                    THEN
                        l_original_invoice   := i.original_invoice;
                    ELSIF i.original_invoice IS NULL
                    THEN
                        BEGIN
                            SELECT DISTINCT sl.user_element_attribute5
                              INTO l_original_invoice
                              FROM sabrix_line sl
                             WHERE     sl.user_element_attribute5 IS NOT NULL
                                   AND ROWNUM = 1
                                   AND sl.batch_id =
                                       (SELECT MAX (si.batch_id)
                                          FROM sabrix_invoice si
                                         WHERE     si.user_element_attribute41 =
                                                   i.invoice_id
                                               AND si.user_element_attribute45 =
                                                   i.org_id);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_original_invoice   := NULL;
                        END;
                    END IF;
                END IF;

                BEGIN
                    INSERT INTO XXDO.xxd_ar_trx_hdr_stg (
                                    invoice_id,
                                    invoice_number,
                                    invoice_date,
                                    payment_due_date,
                                    payment_term,
                                    invoice_currency_code,
                                    transaction_type,
                                    org_id,
                                    set_of_books_id,
                                    duty_stamp,
                                    document_type,
                                    legal_entity_name,
                                    legal_entity_address_street,
                                    legal_entity_address_postal_code,
                                    legal_entity_address_city,
                                    legal_entity_address_province,
                                    legal_entity_country,
                                    legal_entity_country_code,
                                    le_vat_number,
                                    le_registriation_number,
                                    seller_contact_tel,
                                    seller_contact_fax,
                                    seller_contact_email,
                                    bank_account_num,
                                    bank_swfit_bic,
                                    bank_iban,
                                    province_reg_office,
                                    company_reg_number,
                                    share_capital,
                                    status_shareholders,
                                    liquidation_status,
                                    bill_to_customer_num,
                                    bill_to_customer_name,
                                    bill_to_address_street,
                                    bill_to_address_postal_code,
                                    bill_to_address_city,
                                    bill_to_address_province,
                                    bill_to_address_country,
                                    bill_to_address_country_code,
                                    bill_to_vat_number,
                                    bill_to_business_registration_number,
                                    bill_to_unique_recipient_identifier,
                                    bill_to_routing_code,
                                    bill_to_email,
                                    bill_to_telphone,
                                    printing_pending,
                                    h_total_tax_amount,
                                    h_total_net_amount,
                                    H_TOTAL_NET_AMOUNT_INCLUDING_DISCOUNT_CHARGES,
                                    h_invoice_total,
                                    h_rounding_amt,
                                    h_discount_amount,
                                    h_discount_description,
                                    h_discount_tax_rate,
                                    h_charge_amount,
                                    h_charge_description,
                                    h_charge_tax_rate,
                                    invoice_doc_reference,
                                    inv_doc_ref_desc,
                                    h_tender_ref,
                                    h_project_ref,
                                    h_cust_po,
                                    h_sales_order,
                                    h_inco_term,
                                    h_delivery_num,
                                    cust_acct_num,
                                    tax_chg_code,
                                    created_by,
                                    creation_date,
                                    last_updated_by,
                                    last_update_date,
                                    last_update_login,
                                    conc_request_id,
                                    process_flag,
                                    reprocess_flag,
                                    extract_flag,
                                    extract_date,
                                    ERROR_CODE)
                         VALUES (i.invoice_id, i.invoice_number, i.invoice_date, i.term_due_date, i.payment_term, i.invoice_currency_code, i.transaction_type, i.org_id, i.set_of_books_id, i.duty_stamp, lv_document_type, remove_junk (lv_le_entity_name), remove_junk (lv_le_address_street), remove_junk (lv_le_address_post_code), remove_junk (lv_le_address_city), remove_junk (lv_le_address_province), remove_junk (lv_le_country), remove_junk (lv_le_country_code), remove_junk (lv_le_vat_number), remove_junk (i.le_registriation_number), remove_junk (lv_seller_tel), lv_seller_fax, remove_junk (lv_seller_email), lv_bank_Acct_num, remove_junk (lv_swift_code), remove_junk (lv_iban_num), remove_junk (lv_le_address_province), lv_company_reg_num, lv_share_capital, lv_status_shareholders, lv_liquidation_status, remove_junk (i.bill_to_cust_acct_num), remove_junk (i.bill_to_customer_name), remove_junk (i.bill_to_address_street), remove_junk (i.bill_to_address_postal_code), remove_junk (i.bill_to_address_city), remove_junk (i.bill_to_address_province), remove_junk (i.bill_to_address_country), remove_junk (i.bill_to_address_country_code), remove_junk (i.bill_to_vat_number)---  ,i.bill_to_business_reg_number    -- CCR0010450
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    , remove_junk (lv_business_reg_num) -- CCR0010450
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       , i.bill_to_unique_rec_identifier, remove_junk (i.bill_to_routing_code), remove_junk (lv_to_email_address), remove_junk (lv_to_phone_number), i.printing_option, i.invoice_tax_amt_dsp --h_total_tax_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             , i.h_total_net_amount --h_total_net_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   , i.invoice_line_amt_dsp --h_tot_net_amt_incl_disc_chrgs
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           , i.inv_amt_dsp --h_invoice_total
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          , NULL --h_rounding_amt
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                , NULL ---i.h_discount_amt                                           --h_discount_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      , NULL ---DECODE(i.h_discount_amt,0,NULL,NULL,'','Discount')                       --h_discount_description
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            , NULL ---DECODE(i.h_discount_amt,0,NULL,NULL,'',i.h_discount_rate)     --h_discount_rate
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  , DECODE (i.invoice_freight_amt_dsp, 0, DECODE (ln_charge_amount, 0, NULL, ln_charge_amount), i.invoice_freight_amt_dsp) --h_charge_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          , DECODE (DECODE (i.invoice_freight_amt_dsp, 0, ln_charge_amount, i.invoice_freight_amt_dsp), 0, NULL, 'Freight') --h_charge_description
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           , DECODE (ln_vat_s_t1, 0, ln_charge_rate, ln_vat_s_t1) --h_charge_tax_rate
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 , DECODE (i.TYPE,  'CM', remove_junk (l_original_invoice),  'DM', remove_junk (l_original_invoice),  NULL) --invoice_doc_reference
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           , NULL --inv_doc_ref_desc
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 , NULL --h_tender_ref
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       , NULL --h_project_ref
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             , remove_junk (i.purchase_order) --h_cust_po
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             , remove_junk (i.order_reference) --h_sales_order
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              , remove_junk (lv_inco_term) --h_inco_term
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          , i.delivery_number --h_delivery_num
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             , i.bill_to_cust_acct_num --cust_acct_num
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      , NULL --tax_chg_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            , gn_user_id, SYSDATE, gn_user_id, SYSDATE, gn_user_id, gn_conc_request_id, 'N', pv_reprocess_flag
                                 , NULL, SYSDATE, NULL);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Failed to insert the data into custom table:'
                            || SQLERRM);
                END;


                -- Inserting Lines data
                FOR j IN c_line (i.invoice_id)
                LOOP
                    ln_qty_sum              := NULL;
                    ln_line_amt             := NULL;
                    ln_unit_price           := NULL;
                    ln_unit_price_list      := NULL;
                    ln_disc_percent         := NULL;
                    lv_tax_yn               := NULL;
                    ln_line_tax_rate        := NULL;
                    lv_tax_code             := NULL;
                    lv_tax_rate_des         := NULL;
                    lv_tax_rate_code        := NULL;
                    lv_tax_exemption_code   := NULL;
                    lv_tax_exemption_text   := NULL;
                    ln_line_tax_amt         := NULL;
                    ln_vat_amount           := NULL;
                    ln_vat_net_amount       := NULL;


                    BEGIN
                        --Get Line Data
                        get_line_data (p_style => j.item_style1, p_color => j.item_color1, p_size => j.l_size_qty, p_cust_trx_id => j.customer_trx_id, p_tax_rec => j.tax_recoverable, p_inventory_item_id => j.inventory_item_id, p_int_line_att6 => j.interface_line_attribute6, x_qty_sum => ln_qty_sum, x_line_amt => ln_line_amt, x_unit_price => ln_unit_price, x_unit_price_list => ln_unit_price_list, x_disc_percent => ln_disc_percent
                                       , x_tax_yn => lv_tax_yn);

                        ln_line_tax_rate   :=
                            get_line_tax_rate (
                                p_org_id            => i.org_id,
                                p_customer_trx_id   => j.customer_trx_id,
                                p_customer_trx_line_id   =>
                                    j.customer_trx_line_id);

                        ln_line_tax_amt   :=
                            get_line_tax_amt (
                                p_org_id            => i.org_id,
                                p_customer_trx_id   => j.customer_trx_id,
                                p_customer_trx_line_id   =>
                                    j.customer_trx_line_id);

                        ln_vat_amount   :=
                            get_vat_amount (
                                p_org_id            => i.org_id,
                                p_customer_trx_id   => j.customer_trx_id,
                                p_tax_rate          => j.tax_rate);

                        ln_vat_net_amount   :=
                            get_vat_net_amount (
                                p_org_id            => i.org_id,
                                p_customer_trx_id   => j.customer_trx_id,
                                p_tax_rate          => j.tax_rate);


                        get_line_tax_rate_det (i.org_id,
                                               i.invoice_id,
                                               j.customer_trx_line_id,
                                               lv_tax_code,
                                               lv_tax_rate_des,
                                               lv_tax_rate_code);

                        BEGIN
                            SELECT TAG, Description
                              INTO lv_tax_exemption_code, lv_tax_exemption_text
                              FROM FND_LOOKUP_VALUES
                             WHERE     lookup_type =
                                       'XXD_AR_NATURA_CODE_MAPPING'
                                   AND lookup_code = lv_tax_rate_code
                                   AND language = 'US'
                                   AND ROWNUM = 1;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_tax_exemption_code   := NULL;
                                lv_tax_exemption_text   := NULL;
                        END;

                        get_hcode (p_style => j.l_item_style, p_language => NULL, x_hcode => lv_item_code
                                   , x_origin => lv_origin_country);

                        IF (j.style_desc IS NULL AND lv_item_code IS NULL AND j.color_desc IS NULL)
                        THEN
                            lv_description_goods   := j.line_description;

                            IF lv_description_goods IS NULL
                            THEN
                                lv_description_goods   := 'Invoice Line';
                            END IF;
                        ELSE
                            lv_description_goods   :=
                                   j.style_desc
                                || ' '
                                || lv_item_code
                                || ' '
                                || j.color_desc;
                        END IF;

                        -- For Debit Memo invoice, sign change for qty and unit_price

                        IF (i.transaction_type = 'Debit Memo' AND j.quantity_invoiced < 0 AND j.avg_unit_price_dsp < 0)
                        THEN
                            ln_quantity   := (-1 * j.quantity_invoiced);
                            ln_avg_unit_price   :=
                                (-1 * j.avg_unit_price_dsp);
                        ELSE
                            ln_quantity         := j.quantity_invoiced;
                            ln_avg_unit_price   := j.avg_unit_price_dsp;
                        END IF;

                        INSERT INTO xxd_ar_trx_line_stg (
                                        concurrent_request_id,
                                        customer_trx_id,
                                        customer_trx_line_id,
                                        l_company_segment,
                                        l_description_goods,
                                        l_unit_of_measure,
                                        l_qty,
                                        l_unit_price,
                                        l_vat_amount,
                                        l_vat_rate,
                                        vat_net_amount,
                                        vat_rate,
                                        vat_amount,
                                        l_tax_exemption_code,
                                        l_net_amount,
                                        l_discount_amount,
                                        l_discount_description,
                                        l_charge_amount,
                                        l_charge_description,
                                        tax_code,
                                        tax_exemption_text,
                                        tax_chg_code,
                                        l_delivery_date,
                                        l_item_style,
                                        l_size_qty,
                                        line_placeholder1,
                                        line_placeholder2,
                                        line_placeholder3,
                                        item_code,
                                        country_of_origin,
                                        created_by,
                                        creation_date,
                                        last_updated_by,
                                        last_update_date,
                                        last_update_login)
                             VALUES (gn_conc_request_id, j.customer_trx_id, j.customer_trx_line_id, j.l_company_segment, lv_description_goods, j.uom_code, ln_quantity --j.quantity_invoiced
                                                                                                                                                                      , ln_avg_unit_price -- j.avg_unit_price_dsp
                                                                                                                                                                                         , ((NVL (ln_line_amt, j.ext_amt_dsp) * ln_line_tax_rate) / 100) --ln_line_tax_amt
                                                                                                                                                                                                                                                        , ln_line_tax_rate, ln_vat_net_amount, ln_line_tax_rate, ln_vat_amount, DECODE (ln_line_tax_rate, 0, lv_tax_exemption_code, NULL) --j.l_tax_expemtion_code
                                                                                                                                                                                                                                                                                                                                                                                         , NVL (ln_line_amt, j.ext_amt_dsp) --j.l_net_amount
                                                                                                                                                                                                                                                                                                                                                                                                                           , ((j.quantity_invoiced * j.avg_unit_price_dsp) - NVL (ln_line_amt, j.ext_amt_dsp)) --l_discount_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              , DECODE (((j.quantity_invoiced * j.avg_unit_price_dsp) - NVL (ln_line_amt, j.ext_amt_dsp)),  0, NULL,  NULL, NULL,  'Discount') --j.l_discount_description
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              , j.l_charge_amount, j.l_charge_description, remove_junk (DECODE (ln_line_tax_rate, 0, j.tax_code, NULL)), remove_junk (DECODE (ln_line_tax_rate, 0, j.tax_exempt_text, NULL)) --j.l_tax_exemption_text
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            , NULL, j.l_delivery_date, j.l_item_style, (lv_origin_country || ' ' || j.l_size_qty || ' ' || j.quantity_invoiced) --j.l_size_qty
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               , lv_tax_rate_des --line_placeholder1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                , NULL --line_placeholder2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      , lv_tax_rate_code --line_placeholder3
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        , lv_item_code, lv_origin_country, gn_user_id, SYSDATE, gn_user_id
                                     , SYSDATE, gn_user_id);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Failed to insert the lines data into custom table:'
                                || SQLERRM);
                    END;
                END LOOP;
            END LOOP;

            COMMIT;
        END IF;

        -- send email
        generate_report_prc (gn_conc_request_id);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Failed to insert the data into custom table:' || SQLERRM);
    END insert_ar_eligible_recs;

    PROCEDURE write_trx_file (p_conc_request_id   IN     NUMBER,
                              p_file_path         IN     VARCHAR2,
                              p_file_name         IN     VARCHAR2,
                              x_ret_code             OUT VARCHAR2,
                              x_ret_message          OUT VARCHAR2)
    AS
        --DEFINE CURSORS
        CURSOR c_lines (p_conc_request_id IN NUMBER, p_cust_trx_id IN NUMBER)
        IS
            SELECT DECODE (check_column_enabled ('INVOICE_ID', LINE.l_company_segment), 'N', NULL, hdr.invoice_id) invoice_id, DECODE (check_column_enabled ('INVOICE_NUMBER', LINE.l_company_segment), 'N', NULL, hdr.invoice_number) invoice_number, DECODE (check_column_enabled ('INVOICE_DATE', LINE.l_company_segment), 'N', NULL, TO_CHAR (hdr.invoice_date, 'DD-MON-RRRR')) invoice_date,
                   DECODE (check_column_enabled ('PAYMENT_DUE_DATE', LINE.l_company_segment), 'N', NULL, TO_CHAR (hdr.payment_due_date, 'DD-MON-RRRR')) payment_due_date, DECODE (check_column_enabled ('PAYMENT_TERM', LINE.l_company_segment), 'N', NULL, hdr.payment_term) payment_term, DECODE (check_column_enabled ('INVOICE_CURRENCY_CODE', LINE.l_company_segment), 'N', NULL, hdr.invoice_currency_code) invoice_currency_code,
                   DECODE (check_column_enabled ('DUTY_STAMP', LINE.l_company_segment), 'N', NULL, hdr.duty_stamp) duty_stamp, DECODE (check_column_enabled ('DOCUMENT_TYPE', LINE.l_company_segment), 'N', NULL, hdr.document_type) document_type, DECODE (check_column_enabled ('LEGAL_ENTITY_NAME', LINE.l_company_segment), 'N', NULL, hdr.legal_entity_name) legal_entity_name,
                   DECODE (check_column_enabled ('LEGAL_ENTITY_ADDRESS_STREET', LINE.l_company_segment), 'N', NULL, hdr.legal_entity_address_street) legal_entity_address_street, DECODE (check_column_enabled ('LEGAL_ENTITY_ADDRESS_POSTAL_CODE', LINE.l_company_segment), 'N', NULL, hdr.legal_entity_address_postal_code) legal_entity_address_postal_code, DECODE (check_column_enabled ('LEGAL_ENTITY_ADDRESS_CITY', LINE.l_company_segment), 'N', NULL, hdr.legal_entity_address_city) legal_entity_address_city,
                   DECODE (check_column_enabled ('LEGAL_ENTITY_ADDRESS_PROVINCE', LINE.l_company_segment), 'N', NULL, hdr.legal_entity_address_province) legal_entity_address_province, DECODE (check_column_enabled ('LEGAL_ENTITY_COUNTRY', LINE.l_company_segment), 'N', NULL, hdr.legal_entity_country) legal_entity_country, DECODE (check_column_enabled ('LEGAL_ENTITY_COUNTRY_CODE', LINE.l_company_segment), 'N', NULL, hdr.legal_entity_country_code) legal_entity_country_code,
                   DECODE (check_column_enabled ('LE_VAT_NUMBER', LINE.l_company_segment), 'N', NULL, hdr.le_vat_number) le_vat_number, DECODE (check_column_enabled ('LE_REGISTRIATION_NUMBER', LINE.l_company_segment), 'N', NULL, hdr.le_registriation_number) le_registriation_number, DECODE (check_column_enabled ('SELLER_CONTACT_TEL', LINE.l_company_segment), 'N', NULL, hdr.seller_contact_tel) seller_contact_tel,
                   DECODE (check_column_enabled ('SELLER_CONTACT_FAX', LINE.l_company_segment), 'N', NULL, hdr.seller_contact_fax) seller_contact_fax, DECODE (check_column_enabled ('SELLER_CONTACT_EMAIL', LINE.l_company_segment), 'N', NULL, hdr.seller_contact_email) seller_contact_email, DECODE (check_column_enabled ('BANK_ACCOUNT_NUM', LINE.l_company_segment), 'N', NULL, hdr.bank_account_num) bank_account_num,
                   DECODE (check_column_enabled ('BANK_SWFIT_BIC', LINE.l_company_segment), 'N', NULL, hdr.bank_swfit_bic) bank_swfit_bic, DECODE (check_column_enabled ('BANK_IBAN', LINE.l_company_segment), 'N', NULL, hdr.bank_iban) bank_iban, DECODE (check_column_enabled ('PROVINCE_REG_OFFICE', LINE.l_company_segment), 'N', NULL, hdr.province_reg_office) province_reg_office,
                   DECODE (check_column_enabled ('COMPANY_REG_NUMBER', LINE.l_company_segment), 'N', NULL, hdr.company_reg_number) company_reg_number, DECODE (check_column_enabled ('SHARE_CAPITAL', LINE.l_company_segment), 'N', NULL, hdr.share_capital) share_capital, DECODE (check_column_enabled ('STATUS_SHAREHOLDERS', LINE.l_company_segment), 'N', NULL, hdr.status_shareholders) status_shareholders,
                   DECODE (check_column_enabled ('LIQUIDATION_STATUS', LINE.l_company_segment), 'N', NULL, hdr.liquidation_status) liquidation_status, DECODE (check_column_enabled ('BILL_TO_CUSTOMER_NAME', LINE.l_company_segment), 'N', NULL, hdr.bill_to_customer_name) bill_to_customer_name, DECODE (check_column_enabled ('BILL_TO_ADDRESS_STREET', LINE.l_company_segment), 'N', NULL, hdr.bill_to_address_street) bill_to_address_street,
                   DECODE (check_column_enabled ('BILL_TO_ADDRESS_POSTAL_CODE', LINE.l_company_segment), 'N', NULL, hdr.bill_to_address_postal_code) bill_to_address_postal_code, DECODE (check_column_enabled ('BILL_TO_ADDRESS_CITY', LINE.l_company_segment), 'N', NULL, hdr.bill_to_address_city) bill_to_address_city, DECODE (check_column_enabled ('BILL_TO_ADDRESS_PROVINCE', LINE.l_company_segment), 'N', NULL, hdr.bill_to_address_province) bill_to_address_province,
                   DECODE (check_column_enabled ('BILL_TO_ADDRESS_COUNTRY', LINE.l_company_segment), 'N', NULL, hdr.bill_to_address_country) bill_to_address_country, DECODE (check_column_enabled ('BILL_TO_ADDRESS_COUNTRY_CODE', LINE.l_company_segment), 'N', NULL, hdr.bill_to_address_country_code) bill_to_address_country_code, DECODE (check_column_enabled ('BILL_TO_VAT_NUMBER', LINE.l_company_segment), 'N', NULL, hdr.bill_to_vat_number) bill_to_vat_number,
                   DECODE (check_column_enabled ('BILL_TO_BUSINESS_REGISTRATION_NUMBER', LINE.l_company_segment), 'N', NULL, hdr.bill_to_business_registration_number) bill_to_business_registration_number, DECODE (check_column_enabled ('BILL_TO_UNIQUE_RECIPIENT_IDENTIFIER', LINE.l_company_segment), 'N', NULL, hdr.bill_to_unique_recipient_identifier) bill_to_unique_recipient_identifier, DECODE (check_column_enabled ('BILL_TO_ROUTING_CODE', LINE.l_company_segment), 'N', NULL, hdr.bill_to_routing_code) bill_to_routing_code,
                   DECODE (check_column_enabled ('BILL_TO_EMAIL', LINE.l_company_segment), 'N', NULL, hdr.bill_to_email) bill_to_email, DECODE (check_column_enabled ('BILL_TO_TELPHONE', LINE.l_company_segment), 'N', NULL, hdr.bill_to_telphone) bill_to_telphone, DECODE (check_column_enabled ('PRINTING_PENDING', LINE.l_company_segment), 'N', NULL, hdr.printing_pending) printing_pending,
                   DECODE (check_column_enabled ('H_TOTAL_TAX_AMOUNT', LINE.l_company_segment), 'N', NULL, hdr.h_total_tax_amount) h_total_tax_amount, DECODE (check_column_enabled ('H_TOTAL_NET_AMOUNT', LINE.l_company_segment), 'N', NULL, hdr.h_total_net_amount) h_total_net_amount, DECODE (check_column_enabled ('H_TOTAL_NET_AMOUNT_INCLUDING_DISCOUNT_CHARGES', LINE.l_company_segment), 'N', NULL, hdr.h_total_net_amount_including_discount_charges) h_total_net_amount_including_discount_charges,
                   DECODE (check_column_enabled ('H_INVOICE_TOTAL', LINE.l_company_segment), 'N', NULL, hdr.h_invoice_total) h_invoice_total, DECODE (check_column_enabled ('H_ROUNDING_AMT', LINE.l_company_segment), 'N', NULL, hdr.h_rounding_amt) h_rounding_amt, DECODE (check_column_enabled ('H_DISCOUNT_AMOUNT', LINE.l_company_segment), 'N', NULL, hdr.h_discount_amount) h_discount_amount,
                   DECODE (check_column_enabled ('H_DISCOUNT_DESCRIPTION', LINE.l_company_segment), 'N', NULL, hdr.h_discount_description) h_discount_description, DECODE (check_column_enabled ('H_DISCOUNT_TAX_RATE', LINE.l_company_segment), 'N', NULL, hdr.h_discount_tax_rate) h_discount_tax_rate, DECODE (check_column_enabled ('H_CHARGE_AMOUNT', LINE.l_company_segment), 'N', NULL, hdr.h_charge_amount) h_charge_amount,
                   DECODE (check_column_enabled ('H_CHARGE_DESCRIPTION', LINE.l_company_segment), 'N', NULL, hdr.h_charge_description) h_charge_description, DECODE (check_column_enabled ('H_CHARGE_TAX_RATE', LINE.l_company_segment), 'N', NULL, hdr.h_charge_tax_rate) h_charge_tax_rate, DECODE (check_column_enabled ('INVOICE_DOC_REFERENCE', LINE.l_company_segment), 'N', NULL, hdr.invoice_doc_reference) invoice_doc_reference,
                   DECODE (check_column_enabled ('INV_DOC_REF_DESC', LINE.l_company_segment), 'N', NULL, hdr.inv_doc_ref_desc) inv_doc_ref_desc, DECODE (check_column_enabled ('H_TENDER_REF', LINE.l_company_segment), 'N', NULL, hdr.h_tender_ref) h_tender_ref, DECODE (check_column_enabled ('H_PROJECT_REF', LINE.l_company_segment), 'N', NULL, hdr.h_project_ref) h_project_ref,
                   DECODE (check_column_enabled ('H_CUST_PO', LINE.l_company_segment), 'N', NULL, hdr.h_cust_po) h_cust_po, DECODE (check_column_enabled ('H_SALES_ORDER', LINE.l_company_segment), 'N', NULL, hdr.h_sales_order) h_sales_order, DECODE (check_column_enabled ('H_INCO_TERM', LINE.l_company_segment), 'N', NULL, hdr.h_inco_term) h_inco_term,
                   DECODE (check_column_enabled ('H_DELIVERY_NUM', LINE.l_company_segment), 'N', NULL, hdr.h_delivery_num) h_delivery_num, DECODE (check_column_enabled ('CUST_ACCT_NUM', LINE.l_company_segment), 'N', NULL, hdr.cust_acct_num) cust_acct_num, DECODE (check_column_enabled ('VAT_NET_AMOUNT', LINE.l_company_segment), 'N', NULL, line.vat_net_amount) vat_net_amount,
                   DECODE (check_column_enabled ('VAT_RATE', LINE.l_company_segment), 'N', NULL, line.l_vat_rate) vat_rate, DECODE (check_column_enabled ('VAT_AMOUNT', LINE.l_company_segment), 'N', NULL, line.vat_amount) vat_amount, DECODE (check_column_enabled ('TAX_CHG_CODE', LINE.l_company_segment), 'N', NULL, hdr.tax_chg_code) tax_chg_code,
                   hdr.created_by, hdr.creation_date, hdr.last_updated_by,
                   hdr.last_update_date, hdr.last_update_login, hdr.conc_request_id,
                   hdr.process_flag, hdr.reprocess_flag, hdr.extract_flag,
                   hdr.extract_date, hdr.ERROR_CODE, LINE.concurrent_request_id,
                   LINE.customer_trx_id, LINE.customer_trx_line_id, LINE.l_company_segment,
                   DECODE (check_column_enabled ('L_DESCRIPTION_GOODS', LINE.l_company_segment), 'N', NULL, LINE.l_description_goods) l_description_goods, DECODE (check_column_enabled ('L_UNIT_OF_MEASURE', LINE.l_company_segment), 'N', NULL, LINE.l_unit_of_measure) l_unit_of_measure, DECODE (check_column_enabled ('L_QTY', LINE.l_company_segment), 'N', NULL, LINE.l_qty) l_qty,
                   DECODE (check_column_enabled ('L_UNIT_PRICE', LINE.l_company_segment), 'N', NULL, LINE.l_unit_price) l_unit_price, DECODE (check_column_enabled ('L_VAT_AMOUNT', LINE.l_company_segment), 'N', NULL, LINE.l_vat_amount) l_vat_amount, DECODE (check_column_enabled ('L_VAT_RATE', LINE.l_company_segment), 'N', NULL, LINE.l_vat_rate) l_vat_rate,
                   DECODE (check_column_enabled ('L_TAX_EXPEMTION_CODE', LINE.l_company_segment), 'N', NULL, LINE.l_tax_exemption_code) l_tax_expemtion_code, DECODE (check_column_enabled ('L_NET_AMOUNT', LINE.l_company_segment), 'N', NULL, LINE.l_net_amount) l_net_amount, DECODE (check_column_enabled ('L_DISCOUNT_AMOUNT', LINE.l_company_segment), 'N', NULL, LINE.l_discount_amount) l_discount_amount,
                   DECODE (check_column_enabled ('L_DISCOUNT_DESCRIPTION', LINE.l_company_segment), 'N', NULL, LINE.l_discount_description) l_discount_description, DECODE (check_column_enabled ('L_CHARGE_AMOUNT', LINE.l_company_segment), 'N', NULL, LINE.l_charge_amount) l_charge_amount, DECODE (check_column_enabled ('L_CHARGE_DESCRIPTION', LINE.l_company_segment), 'N', NULL, LINE.l_charge_description) l_charge_description,
                   DECODE (check_column_enabled ('L_DELIVERY_DATE', LINE.l_company_segment), 'N', NULL, LINE.l_delivery_date) l_delivery_date, DECODE (check_column_enabled ('TAX_CODE', LINE.l_company_segment), 'N', NULL, LINE.tax_code) tax_code, DECODE (check_column_enabled ('TAX_EXEMPTION_TEXT', LINE.l_company_segment), 'N', NULL, LINE.tax_exemption_text) tax_exemption_text,
                   DECODE (check_column_enabled ('L_ITEM_STYLE', LINE.l_company_segment), 'N', NULL, LINE.l_item_style) l_item_style, DECODE (check_column_enabled ('L_SIZE_QTY', LINE.l_company_segment), 'N', NULL, LINE.l_size_qty) l_size_qty
              FROM xxdo.xxd_ar_trx_hdr_stg hdr, xxdo.xxd_ar_trx_line_stg LINE
             WHERE     1 = 1
                   AND hdr.invoice_id = LINE.customer_trx_id
                   AND hdr.conc_request_id = LINE.concurrent_request_id
                   AND hdr.conc_request_id = p_conc_request_id
                   AND hdr.invoice_id = p_cust_trx_id
                   AND hdr.process_flag = 'N'
            FOR UPDATE;

        CURSOR c_header (p_conc_request_id IN NUMBER)
        IS
              SELECT UNIQUE hdr.conc_request_id, hdr.invoice_id, hdr.invoice_number,
                            TO_CHAR (rct.creation_date, 'DDMONYYYYHH24MISS') creation_date
                FROM xxdo.xxd_ar_trx_hdr_stg hdr, apps.ra_Customer_trx_all rct
               WHERE     1 = 1
                     AND hdr.conc_request_id = p_conc_request_id
                     AND hdr.invoice_id = rct.customer_trx_id
                     AND hdr.set_of_books_id = rct.set_of_books_id
                     AND hdr.process_flag = 'N'
            ORDER BY invoice_id;

        --DEFINE VARIABLES
        lv_output_file     UTL_FILE.file_type;
        lv_file_path       VARCHAR2 (360) := p_file_path;
        lv_outbound_file   VARCHAR2 (360) := NULL;
        lv_err_msg         VARCHAR2 (2000) := NULL;
        ln_hdr_cnt         NUMBER := 0;
        ln_line_cnt        NUMBER := 0;
        ln_ftr_cnt         NUMBER := 0;
        lv_hdr             VARCHAR2 (32767) := NULL;
        lv_hdr_desc        VARCHAR2 (32767) := NULL;
        lv_line            VARCHAR2 (32767) := NULL;
        lv_ftr             VARCHAR2 (32767) := NULL;
        lv_sum             VARCHAR2 (32767) := NULL;
        ln_sum_amount      NUMBER := 0;
        lv_ver             VARCHAR2 (32767) := NULL;
        lv_header_desc     VARCHAR2 (32767) := NULL;
    BEGIN
        lv_hdr_desc   :=
               'INVOICE_ID'
            || '||'
            || 'INVOICE_NUMBER'
            || '||'
            || 'INVOICE_DATE'
            || '||'
            || 'PAYMENT_DUE_DATE'
            || '||'
            || 'PAYMENT_TERM'
            || '||'
            || 'INVOICE_CURRENCY_CODE'
            || '||'
            || 'DUTY_STAMP'
            || '||'
            || 'DOCUMENT_TYPE'
            || '||'
            || 'LEGAL_ENTITY_NAME'
            || '||'
            || 'LEGAL_ENTITY_ADDRESS_STREET'
            || '||'
            || 'LEGAL_ENTITY_ADDRESS_POSTAL_CODE'
            || '||'
            || 'LEGAL_ENTITY_ADDRESS_CITY'
            || '||'
            || 'LEGAL_ENTITY_ADDRESS_PROVINCE'
            || '||'
            || 'LEGAL_ENTITY_COUNTRY'
            || '||'
            || 'LEGAL_ENTITY_COUNTRY_CODE'
            || '||'
            || 'LE_VAT_NUMBER'
            || '||'
            || 'LE_REGISTRIATION_NUMBER'
            || '||'
            || 'SELLER_CONTACT_TEL'
            || '||'
            || 'SELLER_CONTACT_FAX'
            || '||'
            || 'SELLER_CONTACT_EMAIL'
            || '||'
            || 'BANK_ACCOUNT_NUM'
            || '||'
            || 'BANK_SWFIT_BIC'
            || '||'
            || 'BANK_IBAN'
            || '||'
            || 'PROVINCE_REG_OFFICE'
            || '||'
            || 'COMPANY_REG_NUMBER'
            || '||'
            || 'SHARE_CAPITAL'
            || '||'
            || 'STATUS_SHAREHOLDERS'
            || '||'
            || 'LIQUIDATION_STATUS'
            || '||'
            || 'BILL_TO_CUSTOMER_NAME'
            || '||'
            || 'BILL_TO_ADDRESS_STREET'
            || '||'
            || 'BILL_TO_ADDRESS_POSTAL_CODE'
            || '||'
            || 'BILL_TO_ADDRESS_CITY'
            || '||'
            || 'BILL_TO_ADDRESS_PROVINCE'
            || '||'
            || 'BILL_TO_ADDRESS_COUNTRY'
            || '||'
            || 'BILL_TO_ADDRESS_COUNTRY_CODE'
            || '||'
            || 'BILL_TO_VAT_NUMBER'
            || '||'
            || 'BILL_TO_BUSINESS_REGISTRATION_NUMBER'
            || '||'
            || 'BILL_TO_UNIQUE_RECIPIENT_IDENTIFIER'
            || '||'
            || 'BILL_TO_ROUTING_CODE'
            || '||'
            || 'BILL_TO_EMAIL'
            || '||'
            || 'BILL_TO_TELPHONE'
            || '||'
            || 'H_TOTAL_TAX_AMOUNT'
            || '||'
            || 'H_TOTAL_NET_AMOUNT'
            || '||'
            || 'H_TOTAL_NET_AMOUNT_INCLUDING_DISCOUNT_CHARGES'
            || '||'
            || 'H_INVOICE_TOTAL'
            || '||'
            || 'H_ROUNDING_AMT'
            || '||'
            || 'VAT_NET_AMOUNT'
            || '||'
            || 'VAT_RATE'
            || '||'
            || 'VAT_AMOUNT'
            || '||'
            || 'TAX_CODE'
            || '||'
            || 'TAX_EXEMPTION_TEXT'
            || '||'
            || 'TAX_CHG_CODE'
            || '||'
            || 'L_DESCRIPTION_GOODS'
            || '||'
            || 'L_UNIT_OF_MEASURE'
            || '||'
            || 'L_QTY'
            || '||'
            || 'L_UNIT_PRICE'
            || '||'
            || 'L_VAT_AMOUNT'
            || '||'
            || 'L_VAT_RATE'
            || '||'
            || 'L_TAX_EXPEMTION_CODE'
            || '||'
            || 'L_NET_AMOUNT'
            || '||'
            || 'H_DISCOUNT_AMOUNT'
            || '||'
            || 'H_DISCOUNT_DESCRIPTION'
            || '||'
            || 'H_DISCOUNT_TAX_RATE'
            || '||'
            || 'H_CHARGE_AMOUNT'
            || '||'
            || 'H_CHARGE_DESCRIPTION'
            || '||'
            || 'H_CHARGE_TAX_RATE'
            || '||'
            || 'INVOICE_DOC_REFERENCE'
            || '||'
            || 'INV_DOC_REF_DESC'
            || '||'
            || 'H_TENDER_REF'
            || '||'
            || 'H_PROJECT_REF'
            || '||'
            || 'H_CUST_PO'
            || '||'
            || 'H_SALES_ORDER'
            || '||'
            || 'H_INCO_TERM'
            || '||'
            || 'H_DELIVERY_NUM'
            || '||'
            || 'L_DISCOUNT_AMOUNT'
            || '||'
            || 'L_DISCOUNT_DESCRIPTION'
            || '||'
            || 'L_CHARGE_AMOUNT'
            || '||'
            || 'L_CHARGE_DESCRIPTION'
            || '||'
            || 'L_DELIVERY_DATE'
            || '||'
            || 'L_ITEM_STYLE'
            || '||'
            || 'L_SIZE_QTY'
            || '||'
            || 'CUST_ACCT_NUM';


        FOR i IN c_header (p_conc_request_id)
        LOOP
            lv_outbound_file   :=
                'AR' || i.invoice_id || i.invoice_number || i.creation_date;

            lv_output_file   :=
                UTL_FILE.fopen (lv_file_path, lv_outbound_file || '.csv', 'W' --opening the file in write mode
                                , 32767);

            UTL_FILE.put_line (lv_output_file, 'Deckers');
            UTL_FILE.put_line (lv_output_file, 'AR Invoice Domestic');
            UTL_FILE.put_line (
                lv_output_file,
                'AR INV Domestic Export - Run Date of ' || gv_file_time_stamp);
            UTL_FILE.put_line (lv_output_file, ' ');

            UTL_FILE.put_line (lv_output_file, lv_hdr_desc);

            IF UTL_FILE.is_open (lv_output_file)
            THEN
                FOR j IN c_lines (i.conc_request_id, i.invoice_id)
                LOOP
                    --Add Line Record
                    lv_line   :=
                           j.INVOICE_ID
                        || '||'
                        || j.INVOICE_NUMBER
                        || '||'
                        || j.INVOICE_DATE
                        || '||'
                        || j.PAYMENT_DUE_DATE
                        || '||'
                        || j.PAYMENT_TERM
                        || '||'
                        || j.INVOICE_CURRENCY_CODE
                        || '||'
                        || j.DUTY_STAMP
                        || '||'
                        || j.DOCUMENT_TYPE
                        || '||'
                        || j.LEGAL_ENTITY_NAME
                        || '||'
                        || j.LEGAL_ENTITY_ADDRESS_STREET
                        || '||'
                        || j.LEGAL_ENTITY_ADDRESS_POSTAL_CODE
                        || '||'
                        || j.LEGAL_ENTITY_ADDRESS_CITY
                        || '||'
                        || j.LEGAL_ENTITY_ADDRESS_PROVINCE
                        || '||'
                        || j.LEGAL_ENTITY_COUNTRY
                        || '||'
                        || j.LEGAL_ENTITY_COUNTRY_CODE
                        || '||'
                        || j.LE_VAT_NUMBER
                        || '||'
                        || j.LE_REGISTRIATION_NUMBER
                        || '||'
                        || j.SELLER_CONTACT_TEL
                        || '||'
                        || j.SELLER_CONTACT_FAX
                        || '||'
                        || j.SELLER_CONTACT_EMAIL
                        || '||'
                        || j.BANK_ACCOUNT_NUM
                        || '||'
                        || j.BANK_SWFIT_BIC
                        || '||'
                        || j.BANK_IBAN
                        || '||'
                        || j.PROVINCE_REG_OFFICE
                        || '||'
                        || j.COMPANY_REG_NUMBER
                        || '||'
                        || j.SHARE_CAPITAL
                        || '||'
                        || j.STATUS_SHAREHOLDERS
                        || '||'
                        || j.LIQUIDATION_STATUS
                        || '||'
                        || j.BILL_TO_CUSTOMER_NAME
                        || '||'
                        || remove_junk (j.BILL_TO_ADDRESS_STREET)
                        || '||'
                        || j.BILL_TO_ADDRESS_POSTAL_CODE
                        || '||'
                        || j.BILL_TO_ADDRESS_CITY
                        || '||'
                        || j.BILL_TO_ADDRESS_PROVINCE
                        || '||'
                        || j.BILL_TO_ADDRESS_COUNTRY
                        || '||'
                        || j.BILL_TO_ADDRESS_COUNTRY_CODE
                        || '||'
                        || j.BILL_TO_VAT_NUMBER
                        || '||'
                        || j.BILL_TO_BUSINESS_REGISTRATION_NUMBER
                        || '||'
                        || j.BILL_TO_UNIQUE_RECIPIENT_IDENTIFIER
                        || '||'
                        || j.BILL_TO_ROUTING_CODE
                        || '||'
                        || j.BILL_TO_EMAIL
                        || '||'
                        || j.BILL_TO_TELPHONE
                        || '||'
                        || j.H_TOTAL_TAX_AMOUNT
                        || '||'
                        || j.H_TOTAL_NET_AMOUNT
                        || '||'
                        || j.h_total_net_amount_including_discount_charges
                        || '||'
                        || j.H_INVOICE_TOTAL
                        || '||'
                        || j.H_ROUNDING_AMT
                        || '||'
                        || j.VAT_NET_AMOUNT
                        || '||'
                        || j.VAT_RATE
                        || '||'
                        || j.VAT_AMOUNT
                        || '||'
                        || j.TAX_CODE
                        || '||'
                        || j.TAX_EXEMPTION_TEXT
                        || '||'
                        || j.TAX_CHG_CODE
                        || '||'
                        || j.L_DESCRIPTION_GOODS
                        || '||'
                        || j.L_UNIT_OF_MEASURE
                        || '||'
                        || j.L_QTY
                        || '||'
                        || j.L_UNIT_PRICE
                        || '||'
                        || j.L_VAT_AMOUNT
                        || '||'
                        || j.L_VAT_RATE
                        || '||'
                        || j.L_TAX_EXPEMTION_CODE
                        || '||'
                        || j.L_NET_AMOUNT
                        || '||'
                        || j.H_DISCOUNT_AMOUNT
                        || '||'
                        || j.H_DISCOUNT_DESCRIPTION
                        || '||'
                        || j.H_DISCOUNT_TAX_RATE
                        || '||'
                        || j.H_CHARGE_AMOUNT
                        || '||'
                        || j.H_CHARGE_DESCRIPTION
                        || '||'
                        || j.H_CHARGE_TAX_RATE
                        || '||'
                        || j.INVOICE_DOC_REFERENCE
                        || '||'
                        || j.INV_DOC_REF_DESC
                        || '||'
                        || j.H_TENDER_REF
                        || '||'
                        || j.H_PROJECT_REF
                        || '||'
                        || j.H_CUST_PO
                        || '||'
                        || j.H_SALES_ORDER
                        || '||'
                        || j.H_INCO_TERM
                        || '||'
                        || j.H_DELIVERY_NUM
                        || '||'
                        || j.L_DISCOUNT_AMOUNT
                        || '||'
                        || j.L_DISCOUNT_DESCRIPTION
                        || '||'
                        || j.L_CHARGE_AMOUNT
                        || '||'
                        || j.L_CHARGE_DESCRIPTION
                        || '||'
                        || j.L_DELIVERY_DATE
                        || '||'
                        || j.L_ITEM_STYLE
                        || '||'
                        || j.L_SIZE_QTY
                        || '||'
                        || j.CUST_ACCT_NUM;

                    UTL_FILE.put_line (lv_output_file, lv_line);
                END LOOP;

                BEGIN
                    UPDATE xxdo.xxd_ar_trx_hdr_stg
                       SET process_flag = 'Y', extract_flag = 'Y', extract_date = SYSDATE,
                           send_to_pgr = 'Y'
                     WHERE     conc_request_id = i.conc_request_id
                           AND process_flag = 'N'
                           AND invoice_id = i.invoice_Id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;
            ELSE
                lv_err_msg      :=
                    SUBSTR (
                           'Error in Opening the pagero data file for writing. Error is : '
                        || SQLERRM,
                        1,
                        2000);
                print_log (lv_err_msg);
                x_ret_code      := gn_error;
                x_ret_message   := lv_err_msg;
                RETURN;
            END IF;

            --added as part of this CCR0010453
            UTL_FILE.fclose (lv_output_file);
        END LOOP;

        -- as part of this CCR0010453, commented below piece of code
        -- UTL_FILE.fclose (lv_output_file);
        COMMIT;
    EXCEPTION
        WHEN UTL_FILE.invalid_path
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_PATH: File location or filename was invalid.';
            print_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20201, lv_err_msg);
        WHEN UTL_FILE.invalid_mode
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_MODE: The open_mode parameter in FOPEN was invalid.';
            print_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20202, lv_err_msg);
        WHEN UTL_FILE.invalid_filehandle
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_FILEHANDLE: The file handle was invalid.';
            print_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20203, lv_err_msg);
        WHEN UTL_FILE.invalid_operation
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_OPERATION: The file could not be opened or operated on as requested.';
            print_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20204, lv_err_msg);
        WHEN UTL_FILE.read_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'READ_ERROR: An operating system error occurred during the read operation.';
            print_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20205, lv_err_msg);
        WHEN UTL_FILE.write_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'WRITE_ERROR: An operating system error occurred during the write operation.';
            print_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20206, lv_err_msg);
        WHEN UTL_FILE.internal_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      := 'INTERNAL_ERROR: An unspecified error in PL/SQL.';
            print_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20207, lv_err_msg);
        WHEN UTL_FILE.invalid_filename
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_FILENAME: The filename parameter is invalid.';
            print_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20208, lv_err_msg);
        WHEN OTHERS
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                SUBSTR (
                       'Error while creating or writing the data into the file.'
                    || SQLERRM,
                    1,
                    2000);
            print_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20209, lv_err_msg);
    END write_trx_file;

    PROCEDURE main (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, pn_org_id IN NUMBER, pv_reprocess_flag IN VARCHAR2, pv_trans_enabled_tmp IN VARCHAR2, pv_trx_number IN VARCHAR2, pd_trx_date_from IN VARCHAR2, pd_trx_date_to IN VARCHAR2, pn_customer_id IN NUMBER
                    , pn_site_id IN NUMBER, p_file_path IN VARCHAR2)
    AS
        --Define Variables
        lv_ret_code       VARCHAR2 (30) := NULL;
        lv_ret_message    VARCHAR2 (2000) := NULL;
        lv_file_name      VARCHAR2 (100);
        lb_file_exists    BOOLEAN;
        ln_file_length    NUMBER := NULL;
        ln_block_size     NUMBER := NULL;
        lv_file_prefix    VARCHAR2 (30) := 'DECKERS_BILLING_';
        lv_program_name   VARCHAR2 (30) := 'PAGERO_FILE';
        lv_file_path      VARCHAR2 (360) := p_file_path;
    BEGIN
        --Print Input Parameters
        print_log ('Printing Input Parameters');
        print_log (' ');
        print_log ('p_org_id                         :' || pn_org_id);
        print_log ('p_reprocess_flag                 :' || pv_reprocess_flag);
        print_log ('p_trx_number                     :' || pv_trx_number);
        print_log ('p_trx_date_from                  :' || pd_trx_date_from);
        print_log ('p_trx_date_to                    :' || pd_trx_date_to);
        print_log ('p_customer_id                    :' || pn_customer_id);
        print_log ('p_site_id                        :' || pn_site_id);
        print_log ('p_file_path                      :' || p_file_path);
        print_log (' ');


        --Insert data into Staging tables
        insert_ar_eligible_recs (pn_org_id           => pn_org_id,
                                 pv_trx_number       => pv_trx_number,
                                 pd_trx_date_from    => pd_trx_date_from,
                                 pd_trx_date_to      => pd_trx_date_to,
                                 pn_customer_id      => pn_customer_id,
                                 pv_reprocess_flag   => pv_reprocess_flag,
                                 x_ret_code          => lv_ret_code,
                                 x_ret_message       => lv_ret_message);

        IF lv_ret_code = gn_error
        THEN
            retcode   := gn_error;
            errbuf    := 'After insert_ar_pagero_stg - ' || lv_ret_message;
            print_log (errbuf);
            raise_application_error (-20001, errbuf);
        END IF;

        lv_ret_code      := NULL;
        lv_ret_message   := NULL;

        --Write Data into Billing file
        write_trx_file (p_conc_request_id   => gn_conc_request_id,
                        p_file_path         => p_file_path,
                        p_file_name         => lv_file_prefix || lv_file_name,
                        x_ret_code          => lv_ret_code,
                        x_ret_message       => lv_ret_message);

        IF lv_ret_code = gn_error
        THEN
            retcode   := gn_error;
            errbuf    := 'After write_pagero_file - ' || lv_ret_message;
            print_log (errbuf);
            raise_application_error (-20002, errbuf);
        END IF;

        NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Error in Main - Others:' || SQLERRM);
    END main;
END XXD_AR_TRX_OUTBOUND_PKG;
/
