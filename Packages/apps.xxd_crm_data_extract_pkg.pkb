--
-- XXD_CRM_DATA_EXTRACT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:01 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_CRM_DATA_EXTRACT_PKG"
AS
    /************************************************************************************************
    * Package         : XXD_CRM_DATA_EXTRACT_PKG
    * Description     : This package will be used to extract data for CRM
    * Notes           :
    * Modification    :
    *-----------------------------------------------------------------------------------------------
    * Date            Version#      Name                       Description
    *-----------------------------------------------------------------------------------------------
    * 28-Jun-2022     1.0           Ramesh BR/Viswanathan      Initial version
    * 19-Sep-2022     1.1           Viswanathan Pandian        Updated for CCR0010239
    ************************************************************************************************/
    --
    PROCEDURE write_log_prc (pv_msg IN VARCHAR2)
    IS
    BEGIN
        fnd_file.put_line (fnd_file.LOG, pv_msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Error in write_log_prc Procedure -' || SQLERRM);
    END write_log_prc;

    FUNCTION phone_num_mask (pn_contact_point_id IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_status            VARCHAR2 (100);
        ln_msg_count         NUMBER;
        lv_msg_data          VARCHAR2 (100);
        lv_formatted_phone   VARCHAR2 (100);
    BEGIN
        hz_format_phone_v2pub.phone_display (
            p_init_msg_list            => 'T',
            p_contact_point_id         => pn_contact_point_id,
            x_formatted_phone_number   => lv_formatted_phone,
            x_return_status            => lv_status,
            x_msg_count                => ln_msg_count,
            x_msg_data                 => lv_msg_data);
        RETURN lv_formatted_phone;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log_prc ('Exception in PHONE_NUM_MASK - ' || SQLERRM);
            RETURN NULL;
    END phone_num_mask;

    FUNCTION remove_special_char (pv_string IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_string   VARCHAR2 (240);
    BEGIN
        SELECT REPLACE (REPLACE (REPLACE (REPLACE (REPLACE (REPLACE (REPLACE (REPLACE (REGEXP_REPLACE (pv_string, '[ ' || CHR (9) || CHR (10) || ']+', ' '), '"'), ''''), '|'), ','), '“'), '”'), '‘'), '’')
          INTO lv_string
          FROM DUAL;

        RETURN lv_string;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log_prc ('Exception in REMOVE_SPECIAL_CHAR - ' || SQLERRM);
            RETURN NULL;
    END remove_special_char;

    PROCEDURE generate_customer_csv (
        xv_errbuf                OUT NOCOPY VARCHAR2,
        xv_retcode               OUT NOCOPY VARCHAR2,
        pv_integration_mode                 VARCHAR2,
        pv_mode_check                       VARCHAR2,
        pn_cust_acct_id                     NUMBER)
    IS
        CURSOR get_data IS
            SELECT *
              FROM (SELECT * FROM xxdo.xxd_crm_cust_data_current_t
                    MINUS
                    SELECT * FROM xxdo.xxd_crm_cust_data_prior_t)
             WHERE pv_integration_mode = 'Incremental Load'
            UNION
            SELECT *
              FROM xxdo.xxd_crm_cust_data_current_t
             WHERE pv_integration_mode = 'Full Load';

        lv_flag             VARCHAR2 (1) := 'N';
        lv_outbound_file    VARCHAR2 (50) := 'DECKERS_CUSTOMER_DATA.csv';
        lv_directory_path   VARCHAR2 (20) := 'XXD_CRM_OUT_DIR';
        lv_delimeter        VARCHAR2 (5) := '|';
        lv_err_msg          VARCHAR2 (500) := NULL;
        lv_line             VARCHAR2 (32767) := NULL;
        lv_output_file      UTL_FILE.file_type;
    BEGIN
        write_log_prc (
            'Start Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxdo.xxd_crm_cust_data_current_t';

        INSERT INTO xxdo.xxd_crm_cust_data_current_t
            WITH
                org
                AS
                    (SELECT hou.organization_id org_id, hou.name operating_unit
                       FROM hr_operating_units hou, fnd_lookup_values flv
                      WHERE     1 = 1
                            AND hou.name = flv.meaning
                            AND flv.lookup_type = 'XXD_AR_CRM_EMEA_ORG_LKP'
                            AND flv.enabled_flag = 'Y'
                            AND flv.language = USERENV ('LANG')
                            AND NVL (flv.end_date_active, SYSDATE) >= SYSDATE),
                brand_acct
                AS
                    (SELECT hca.cust_account_id,
                            hca.account_number
                                account_number,
                            hca.attribute17
                                cust_lang,
                            hca.attribute1
                                brand,
                            hp.attribute16
                                buying_group,
                            (SELECT ac.name
                               FROM ar_collectors ac
                              WHERE ac.collector_id = hcp.collector_id)
                                collector_name,
                            hcpa.overall_credit_limit
                                credit_limit,
                            hcpa.currency_code
                                currency_type,
                            hp.attribute17
                                cust_member_num,
                            hp.party_name
                                cust_name,
                            hcpa.trx_credit_limit
                                order_limit,
                            hp.attribute14
                                parent_number,
                            (SELECT rt.name
                               FROM ra_terms rt
                              WHERE rt.term_id = hcp.standard_terms)
                                payment_terms,
                            hcpc.name
                                profile_class,
                            hca.sales_channel_code
                                sales_channel,
                            rep.salesrep_name
                                sales_rep_name,
                            (SELECT flv.meaning
                               FROM fnd_lookup_values flv
                              WHERE     flv.lookup_type = 'SHIP_METHOD'
                                    AND flv.enabled_flag = 'Y'
                                    AND language = USERENV ('LANG')
                                    AND flv.lookup_code = hca.ship_via)
                                ship_method,
                            hca.status
                                account_status
                       FROM hz_cust_accounts hca,
                            hz_parties hp,
                            hz_customer_profiles hcp,
                            hz_cust_profile_classes hcpc,
                            hz_cust_profile_amts hcpa,
                            (SELECT DISTINCT customer_id, salesrep_name
                               FROM do_custom.do_rep_cust_assignment
                              WHERE     1 = 1
                                    AND NVL (end_date, SYSDATE + 1) >=
                                        SYSDATE + 1) rep
                      WHERE     1 = 1
                            AND hca.party_id = hp.party_id
                            AND hca.party_id = hcp.party_id(+)
                            AND hcp.cust_account_id(+) = -1
                            AND hcp.profile_class_id =
                                hcpc.profile_class_id(+)
                            AND hcp.cust_account_profile_id =
                                hcpa.cust_account_profile_id(+)
                            AND hca.cust_account_id = rep.customer_id(+)
                            AND hca.attribute18 IS NULL
                            AND hca.attribute1 <> 'ALL BRAND'
                            AND EXISTS
                                    (SELECT 1
                                       FROM hz_cust_acct_sites_all hcasa, org
                                      WHERE     1 = 1
                                            AND hcasa.cust_account_id =
                                                hca.cust_account_id
                                            AND hcasa.org_id = org.org_id)
                            AND ((pv_integration_mode = 'Full Load' AND 1 = 1) OR (pv_integration_mode = 'Incremental Load' AND ((pn_cust_acct_id IS NOT NULL AND hca.cust_account_id = pn_cust_acct_id) OR (pn_cust_acct_id IS NULL AND 1 = 1))))),
                all_aact
                AS
                    (SELECT DISTINCT org.operating_unit, org.org_id, brand_acct.account_number,
                                     hcara.cust_account_id
                       FROM hz_cust_acct_relate_all hcara, brand_acct, org
                      WHERE     1 = 1
                            AND hcara.cust_account_id =
                                brand_acct.cust_account_id
                            AND hcara.org_id = org.org_id
                     UNION
                     SELECT DISTINCT org.operating_unit, org.org_id, brand_acct.account_number,
                                     hcara.cust_account_id
                       FROM hz_cust_acct_relate_all hcara, brand_acct, org
                      WHERE     1 = 1
                            AND hcara.related_cust_account_id =
                                brand_acct.cust_account_id
                            AND hcara.org_id = org.org_id),
                sites
                AS
                    (SELECT DISTINCT cust.account_number, cust.operating_unit, hps.party_site_number site_number,
                                     hcasa.attribute9 site_lang, hcsua.site_use_code site_use_code, hl.address1 site_address_line1,
                                     hl.address2 site_address_line2, hl.address3 site_address_line3, hl.address4 site_address_line4,
                                     hl.city site_city, hl.county site_county, hl.state site_state,
                                     hl.province site_province, hl.postal_code site_postal_code, geo.geography_name site_country,
                                     hcsua.tax_reference site_tax_ref, hcsua.tax_code tax_class_code, hcsua.status site_status
                       FROM hz_cust_acct_sites_all hcasa, hz_cust_site_uses_all hcsua, hz_party_sites hps,
                            hz_locations hl, hz_geographies geo, all_aact cust
                      WHERE     1 = 1
                            AND hcasa.cust_acct_site_id =
                                hcsua.cust_acct_site_id
                            AND hcasa.party_site_id = hps.party_site_id
                            AND hps.location_id = hl.location_id
                            AND hcsua.site_use_code IN ('SHIP_TO', 'BILL_TO')
                            AND hl.country = geo.geography_code
                            -- Start changes for CCR0010239
                            -- AND geo.geography_type = 'COUNTRY_CODE'
                            AND geo.geography_type = 'COUNTRY'
                            -- End changes for CCR0010239
                            AND hcasa.cust_account_id = cust.cust_account_id
                            AND hcasa.org_id = cust.org_id)
            SELECT hca.account_number, NVL (hca.cust_lang, site.site_lang) doc_lang, hca.brand,
                   hca.buying_group, hca.collector_name, hca.credit_limit,
                   hca.currency_type, hca.cust_member_num, hca.cust_name,
                   hca.order_limit, hca.parent_number, hca.payment_terms,
                   hca.profile_class, hca.sales_channel, hca.sales_rep_name,
                   hca.ship_method, hca.account_status, site.site_number,
                   site.site_use_code, site.site_city, site.site_county,
                   site.site_country, site.site_address_line1, site.site_address_line2,
                   site.site_address_line3, site.site_address_line4, site.operating_unit,
                   site.site_postal_code, site.site_province, site.site_state,
                   site.site_status, site.site_tax_ref, site.tax_class_code
              FROM brand_acct hca, sites site
             WHERE hca.account_number = site.account_number;

        write_log_prc ('Full Load Data Count = ' || SQL%ROWCOUNT);

        FOR rec_data IN get_data
        LOOP
            IF lv_flag = 'N'
            THEN
                write_log_prc (
                    'Customer Data File Name is - ' || lv_outbound_file);
                lv_output_file   :=
                    UTL_FILE.fopen (lv_directory_path, lv_outbound_file, 'W',
                                    32767);
                lv_line   :=
                       'Account_Account_Number__c'
                    || lv_delimeter
                    || 'Account_Alternate_Document_Language__c'
                    || lv_delimeter
                    || 'Account_Brand__c'
                    || lv_delimeter
                    || 'Account_Buying_Group_Customer_Number__c'
                    || lv_delimeter
                    || 'Account_Collector_Name__c'
                    || lv_delimeter
                    || 'Account_Credit_Limit__c'
                    || lv_delimeter
                    || 'Account_Currency_Type__c'
                    || lv_delimeter
                    || 'Account_Customer_Membership_Number__c'
                    || lv_delimeter
                    || 'Account_Customer_Name__c'
                    || lv_delimeter
                    || 'Account_Order_Credit_Limit__c'
                    || lv_delimeter
                    || 'Account_Parent_Number__c'
                    || lv_delimeter
                    || 'Account_Payment_Terms__c'
                    || lv_delimeter
                    || 'Account_Profile_Class__c'
                    || lv_delimeter
                    || 'Account_Sales_Channel__c'
                    || lv_delimeter
                    || 'Account_Sales_Rep_Name__c'
                    || lv_delimeter
                    || 'Account_Ship_Method__c'
                    || lv_delimeter
                    || 'Account_Status__c'
                    || lv_delimeter
                    || 'Address_Address_Number__c'
                    || lv_delimeter
                    || 'Address_Address_Type__c'
                    || lv_delimeter
                    || 'Address_City__c'
                    || lv_delimeter
                    || 'Address_Country__c'
                    || lv_delimeter
                    || 'Address_County__c'
                    || lv_delimeter
                    || 'Address_Line1__c'
                    || lv_delimeter
                    || 'Address_Line2__c'
                    || lv_delimeter
                    || 'Address_Line3__c'
                    || lv_delimeter
                    || 'Address_Line4__c'
                    || lv_delimeter
                    || 'Address_Operating_Unit__c'
                    || lv_delimeter
                    || 'Address_Postal_Code__c'
                    || lv_delimeter
                    || 'Address_Province__c'
                    || lv_delimeter
                    || 'Address_State__c'
                    || lv_delimeter
                    || 'Address_Status__c'
                    || lv_delimeter
                    || 'Address_Tax_Classification__c'
                    || lv_delimeter
                    || 'Address_VAT_PST_Number__c';
                UTL_FILE.put_line (lv_output_file, lv_line);
                lv_flag   := 'Y';
            END IF;

            lv_line   :=
                   remove_special_char (rec_data.account_number)
                || lv_delimeter
                || remove_special_char (rec_data.doc_lang)
                || lv_delimeter
                || remove_special_char (rec_data.brand)
                || lv_delimeter
                || remove_special_char (rec_data.buying_group)
                || lv_delimeter
                || remove_special_char (rec_data.collector_name)
                || lv_delimeter
                || remove_special_char (rec_data.credit_limit)
                || lv_delimeter
                || remove_special_char (rec_data.currency_type)
                || lv_delimeter
                || remove_special_char (rec_data.cust_member_num)
                || lv_delimeter
                || remove_special_char (rec_data.cust_name)
                || lv_delimeter
                || remove_special_char (rec_data.order_limit)
                || lv_delimeter
                || remove_special_char (rec_data.parent_number)
                || lv_delimeter
                || remove_special_char (rec_data.payment_terms)
                || lv_delimeter
                || remove_special_char (rec_data.profile_class)
                || lv_delimeter
                || remove_special_char (rec_data.sales_channel)
                || lv_delimeter
                || remove_special_char (rec_data.sales_rep_name)
                || lv_delimeter
                || remove_special_char (rec_data.ship_method)
                || lv_delimeter
                || remove_special_char (rec_data.account_status)
                || lv_delimeter
                || remove_special_char (rec_data.site_number)
                || lv_delimeter
                || remove_special_char (rec_data.site_use_code)
                || lv_delimeter
                || remove_special_char (rec_data.site_city)
                || lv_delimeter
                || remove_special_char (rec_data.site_county)
                || lv_delimeter
                || remove_special_char (rec_data.site_country)
                || lv_delimeter
                || remove_special_char (rec_data.site_address_line1)
                || lv_delimeter
                || remove_special_char (rec_data.site_address_line2)
                || lv_delimeter
                || remove_special_char (rec_data.site_address_line3)
                || lv_delimeter
                || remove_special_char (rec_data.site_address_line4)
                || lv_delimeter
                || remove_special_char (rec_data.operating_unit)
                || lv_delimeter
                || remove_special_char (rec_data.site_postal_code)
                || lv_delimeter
                || remove_special_char (rec_data.site_province)
                || lv_delimeter
                || remove_special_char (rec_data.site_state)
                || lv_delimeter
                || remove_special_char (rec_data.site_status)
                || lv_delimeter
                || remove_special_char (rec_data.site_tax_ref)
                || lv_delimeter
                || remove_special_char (rec_data.tax_class_code);
            UTL_FILE.put_line (lv_output_file, lv_line);
        END LOOP;

        IF lv_flag = 'Y'
        THEN
            UTL_FILE.fclose (lv_output_file);
            write_log_prc ('Customer Data File generated successfully');

            IF pv_integration_mode = 'Full Load'
            THEN
                EXECUTE IMMEDIATE 'TRUNCATE TABLE xxdo.xxd_crm_cust_data_prior_t';

                INSERT INTO xxdo.xxd_crm_cust_data_prior_t
                    SELECT * FROM xxdo.xxd_crm_cust_data_current_t;
            ELSE
                INSERT INTO xxdo.xxd_crm_cust_data_prior_t
                    SELECT * FROM xxdo.xxd_crm_cust_data_current_t
                    MINUS
                    SELECT * FROM xxdo.xxd_crm_cust_data_prior_t;

                write_log_prc ('Data File Record Count = ' || SQL%ROWCOUNT);
            END IF;

            COMMIT;
        ELSE
            write_log_prc ('No data found to extract!');
        END IF;

        write_log_prc (
            'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
    EXCEPTION
        WHEN UTL_FILE.invalid_path
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_PATH: File location or filename was invalid.';
            write_log_prc (lv_err_msg);
            raise_application_error (-20101, lv_err_msg);
        WHEN UTL_FILE.invalid_mode
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_MODE: The open_mode parameter in FOPEN was invalid.';
            write_log_prc (lv_err_msg);
            raise_application_error (-20102, lv_err_msg);
        WHEN UTL_FILE.invalid_filehandle
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_FILEHANDLE: The file handle was invalid.';
            write_log_prc (lv_err_msg);
            raise_application_error (-20103, lv_err_msg);
        WHEN UTL_FILE.invalid_operation
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_OPERATION: The file could not be opened or operated on as requested.';
            write_log_prc (lv_err_msg);
            raise_application_error (-20104, lv_err_msg);
        WHEN UTL_FILE.read_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'READ_ERROR: An operating system error occurred during the read operation.';
            write_log_prc (lv_err_msg);
            raise_application_error (-20105, lv_err_msg);
        WHEN UTL_FILE.write_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'WRITE_ERROR: An operating system error occurred during the write operation.';
            write_log_prc (lv_err_msg);
            raise_application_error (-20106, lv_err_msg);
        WHEN UTL_FILE.internal_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   := 'INTERNAL_ERROR: An unspecified error in PL/SQL.';
            write_log_prc (lv_err_msg);
            raise_application_error (-20107, lv_err_msg);
        WHEN UTL_FILE.invalid_filename
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_FILENAME: The filename parameter is invalid.';
            write_log_prc (lv_err_msg);
            raise_application_error (-20108, lv_err_msg);
        WHEN OTHERS
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                SUBSTR (
                       'Error while creating or writing the data into the file.'
                    || SQLERRM,
                    1,
                    2000);
            write_log_prc (lv_err_msg);
            raise_application_error (-20109, lv_err_msg);
    END generate_customer_csv;
END xxd_crm_data_extract_pkg;
/
