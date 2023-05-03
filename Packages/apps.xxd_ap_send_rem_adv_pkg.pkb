--
-- XXD_AP_SEND_REM_ADV_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:40 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AP_SEND_REM_ADV_PKG"
AS
    --  ####################################################################################################
    --  Package      : XXD_ONT_CALLOFF_PROCESS_PKG
    --  Design       : This package is used to send Remittance Advice to the vendors.
    --  Notes        :
    --  Modification :
    --  ======================================================================================
    --  Date            Version#   Name                    Comments
    --  ======================================================================================
    --  19-Mar-2020     1.0        Showkath Ali            Initial Version
    --  ####################################################################################################
    gn_user_id        CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id       CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id         CONSTANT NUMBER := fnd_global.org_id;
    gn_resp_id        CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id   CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_request_id     CONSTANT NUMBER := fnd_global.conc_request_id;

    /***********************************************************************************************
  **************** Function to insert the data into custom table calling from XML file **********
  ************************************************************************************************/
    FUNCTION xml_main (p_ou IN VARCHAR2, p_pay_group IN VARCHAR2, p_payment_method IN VARCHAR2, p_vendor_name IN VARCHAR2, p_vendor_num IN VARCHAR2, p_vendor_site IN VARCHAR2, p_vendor_type IN VARCHAR2, p_pay_date_from IN VARCHAR2, p_pay_date_to IN VARCHAR2, p_invoice_num IN VARCHAR2, p_payment_num IN NUMBER, P_EMAIL_DISTRIBUTION_LIST IN VARCHAR2
                       , P_OUTPUT_TYPE IN VARCHAR2)
        RETURN BOOLEAN
    AS
        -- Cursor to fetch the payment details based on the parameters provided

        CURSOR fetch_payment_details IS
              SELECT DISTINCT
                     iba.payment_reference_number,
                     iba.payment_id,
                     aipa.amount
                         payment_amount,
                     iba.payment_date,
                     aia.payment_method_code,
                     iba.org_id,
                     aia.invoice_num,
                     aia.invoice_date,
                     aia.payment_currency_code,
                     aia.invoice_amount,
                     aia.description,
                     aia.pay_group_lookup_code,
                     aila.description
                         line_description,
                     aila.line_type_lookup_code,
                     NVL (aila.amount, 0)
                         line_amount,
                     aila.line_number,
                     REPLACE (
                         gl_flexfields_pkg.get_concat_description (
                             gcc.chart_of_accounts_id,
                             gcc.code_combination_id),
                         '=====#####=====',
                         NULL)
                         acc_description,
                     xnp.name,
                     supp.vendor_name,
                     supp.segment1
                         vendor_num,
                     supp.vendor_type_lookup_code,
                     comp_add.address_line1,
                     comp_add.address_line2,
                     comp_add.city,
                     comp_add.country,
                     comp_add.zip,
                     NULL
                         org_address,
                     NULL
                         wh_tax_name,
                     NULL
                         wh_tax_amount,
                     iba.int_bank_name,
                     aca.check_number,
                        (SELECT meaning
                           FROM fnd_lookup_values
                          WHERE     lookup_type = 'PAYMENT METHOD'
                                AND language = 'US'
                                AND NVL (enabled_flag, 'N') = 'Y'
                                AND SYSDATE BETWEEN NVL (
                                                        start_date_active,
                                                        SYSDATE)
                                                AND SYSDATE
                                AND SYSDATE BETWEEN NVL (
                                                        end_date_active,
                                                        SYSDATE)
                                                AND SYSDATE
                                AND lookup_code =
                                    aia.payment_method_code)
                     || ' - '
                     || (SELECT meaning
                           FROM fnd_lookup_values
                          WHERE     lookup_type = 'PAY GROUP'
                                AND language = 'US'
                                AND NVL (enabled_flag, 'N') = 'Y'
                                AND SYSDATE BETWEEN NVL (
                                                        start_date_active,
                                                        SYSDATE)
                                                AND SYSDATE
                                AND SYSDATE BETWEEN NVL (
                                                        end_date_active,
                                                        SYSDATE)
                                                AND SYSDATE
                                AND lookup_code =
                                    aia.pay_group_lookup_code)
                         pay_group_method,
                     NVL (aia.discount_amount_taken, 0)
                         disc_amount,
                     (SELECT segment1
                        FROM po_headers_all pha, po_distributions_all pda
                       WHERE     pha.po_header_id = pda.po_header_id
                             AND pda.po_distribution_id =
                                 aida.po_distribution_id)
                         po_number
                FROM ap_invoices_all aia,
                     ap_invoice_lines_all aila,
                     ap_invoice_distributions_all aida,
                     ap_invoice_payments_all aipa,
                     ap_checks_all aca,
                     ap_suppliers supp,
                     ap_supplier_sites_all supp_site,
                     iby_payments_all iba,
                     hr_operating_units hou,
                     xle_entity_profiles xnp,
                     (SELECT hrl.address_line_1 address_line1, hrl.address_line_2 address_line2, town_or_city city,
                             country country, hrl.postal_code zip, source_id
                        FROM xle_registrations reg, hr_locations_all hrl
                       WHERE     reg.source_table = 'XLE_ENTITY_PROFILES'
                             AND hrl.location_id = reg.location_id
                             AND reg.identifying_flag = 'Y') comp_add,
                     gl_code_combinations gcc
               WHERE     1 = 1
                     AND aia.invoice_id = aila.invoice_id
                     AND aia.invoice_id = aipa.invoice_id
                     AND aia.invoice_id = aida.invoice_id
                     AND aia.org_id = aipa.org_id
                     AND aia.vendor_id = supp.vendor_id
                     AND aia.vendor_site_id = supp_site.vendor_site_id
                     AND aia.org_id = supp_site.org_id
                     AND supp.vendor_id = supp_site.vendor_id
                     AND aca.check_id = aipa.check_id
                     AND iba.payment_id = aca.payment_id
                     AND hou.organization_id = aia.org_id
                     AND hou.default_legal_context_id = xnp.legal_entity_id
                     AND comp_add.source_id = xnp.legal_entity_id
                     AND supp.enabled_flag = 'Y'
                     AND iba.payments_complete_flag = 'Y'
                     --AND iba.payment_status = 'FORMATTED'
                     AND iba.void_date IS NULL
                     AND gcc.code_combination_id(+) = aila.default_dist_ccid
                     AND NVL (supp.start_date_active, SYSDATE) <= SYSDATE
                     AND NVL (supp.end_date_active, SYSDATE) >= SYSDATE
                     AND NVL (supp_site.inactive_date, SYSDATE) >= SYSDATE
                     AND iba.payment_reference_number =
                         NVL (p_payment_num, iba.payment_reference_number)
                     AND TRUNC (iba.payment_date) BETWEEN NVL (
                                                              TRUNC (
                                                                  TO_DATE (
                                                                      p_pay_date_from,
                                                                      'YYYY/MM/DD HH24:MI:SS')),
                                                              TRUNC (
                                                                  iba.payment_date))
                                                      AND NVL (
                                                              TRUNC (
                                                                  TO_DATE (
                                                                      p_pay_date_to,
                                                                      'YYYY/MM/DD HH24:MI:SS')),
                                                              TRUNC (
                                                                  iba.payment_date)) -- CCR0007840
                     AND aia.invoice_num = NVL (p_invoice_num, aia.invoice_num)
                     AND ((p_vendor_type = 'LUCERNEX' AND NVL (supp_site.global_attribute18, 'N') = 'Y') OR (supp.vendor_type_lookup_code = p_vendor_type AND NVL (supp_site.global_attribute18, 'N') = 'N'))
                     AND supp_site.vendor_site_id =
                         NVL (p_vendor_site, supp_site.vendor_site_id)
                     AND supp.vendor_id = NVL (p_vendor_num, supp.vendor_id)
                     AND supp.vendor_id = NVL (p_vendor_name, supp.vendor_id)
                     AND iba.payment_method_code =
                         NVL (p_payment_method, iba.payment_method_code)
                     AND aia.pay_group_lookup_code =
                         NVL (p_pay_group, aia.pay_group_lookup_code)
                     AND aia.org_id = p_ou
            ORDER BY aia.invoice_num, aila.line_number;

        lv_template_type   VARCHAR2 (100) := NULL;
        lv_template        VARCHAR2 (100) := NULL;
        lv_email_address   VARCHAR2 (100) := NULL;
    BEGIN
        --Print the Input parameters
        fnd_file.put_line (fnd_file.LOG, 'Main Program Starts here.......');
        fnd_file.put_line (fnd_file.LOG, 'Input Parameters are...........');
        fnd_file.put_line (fnd_file.LOG, 'P_OU:' || p_ou);
        fnd_file.put_line (fnd_file.LOG, 'P_PAY_GROUP:' || p_pay_group);
        fnd_file.put_line (fnd_file.LOG,
                           'P_PAYMENT_METHOD:' || p_payment_method);
        fnd_file.put_line (fnd_file.LOG, 'P_VENDOR_NAME:' || p_vendor_name);
        fnd_file.put_line (fnd_file.LOG, 'P_VENDOR_NUM:' || p_vendor_num);
        fnd_file.put_line (fnd_file.LOG, 'p_vendor_site:' || p_vendor_site);
        fnd_file.put_line (fnd_file.LOG, 'P_VENDOR_TYPE:' || p_vendor_type);
        fnd_file.put_line (fnd_file.LOG,
                           'P_PAY_DATE_FROM:' || p_pay_date_from);
        fnd_file.put_line (fnd_file.LOG, 'P_PAY_DATE_TO:' || p_pay_date_to);
        fnd_file.put_line (fnd_file.LOG, 'P_INVOICE_NUM:' || p_invoice_num);
        fnd_file.put_line (fnd_file.LOG, 'P_PAYMENT_NUM:' || p_payment_num);
        fnd_file.put_line (
            fnd_file.LOG,
            'P_EMAIL_DISTRIBUTION_LIST:' || P_EMAIL_DISTRIBUTION_LIST);

        -- open the cursor to inset the values
        FOR i IN fetch_payment_details
        LOOP
            -- query to fetch the template type from the value set
            -- There is possibility for OU and pag group combination one template and only OU one template type
            BEGIN
                -- query to get the template type if OU, Pay Group and Payment Methos is defined in the value set
                SELECT attribute4 template_type
                  INTO lv_template_type
                  FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                 WHERE     1 = 1
                       AND ffvs.flex_value_set_name = 'XXD_AP_OU_TEMPLATE_VS'
                       AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
                       AND NVL (ffvl.enabled_flag, 'Y') = 'Y'
                       AND NVL (ffvl.start_date_active, SYSDATE) <= SYSDATE
                       AND NVL (ffvl.end_date_active, SYSDATE) >= SYSDATE
                       AND attribute1 = i.org_id
                       AND attribute2 = i.pay_group_lookup_code
                       AND attribute3 = i.payment_method_code;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    BEGIN
                        -- query to get the template type if OU, Pay Group is defined and Payment Method is null in the value set
                        SELECT attribute4 template_type
                          INTO lv_template_type
                          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                         WHERE     1 = 1
                               AND ffvs.flex_value_set_name =
                                   'XXD_AP_OU_TEMPLATE_VS'
                               AND ffvs.flex_value_set_id =
                                   ffvl.flex_value_set_id
                               AND NVL (ffvl.enabled_flag, 'Y') = 'Y'
                               AND NVL (ffvl.start_date_active, SYSDATE) <=
                                   SYSDATE
                               AND NVL (ffvl.end_date_active, SYSDATE) >=
                                   SYSDATE
                               AND attribute1 = i.org_id
                               AND attribute2 = i.pay_group_lookup_code
                               AND attribute3 IS NULL;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            BEGIN
                                -- query to get the template type if OU, Payment Method defined and Payment group is null in the value set
                                SELECT attribute4 template_type
                                  INTO lv_template_type
                                  FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                                 WHERE     1 = 1
                                       AND ffvs.flex_value_set_name =
                                           'XXD_AP_OU_TEMPLATE_VS'
                                       AND ffvs.flex_value_set_id =
                                           ffvl.flex_value_set_id
                                       AND NVL (ffvl.enabled_flag, 'Y') = 'Y'
                                       AND NVL (ffvl.start_date_active,
                                                SYSDATE) <=
                                           SYSDATE
                                       AND NVL (ffvl.end_date_active,
                                                SYSDATE) >=
                                           SYSDATE
                                       AND attribute1 = i.org_id
                                       AND attribute2 IS NULL
                                       AND attribute3 = i.payment_method_code;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    BEGIN
                                        -- query to get the template type if OU defined and pag group, payment method is NULL in the value set
                                        SELECT attribute4 template_type
                                          INTO lv_template_type
                                          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                                         WHERE     1 = 1
                                               AND ffvs.flex_value_set_name =
                                                   'XXD_AP_OU_TEMPLATE_VS'
                                               AND ffvs.flex_value_set_id =
                                                   ffvl.flex_value_set_id
                                               AND NVL (ffvl.enabled_flag,
                                                        'Y') =
                                                   'Y'
                                               AND NVL (
                                                       ffvl.start_date_active,
                                                       SYSDATE) <=
                                                   SYSDATE
                                               AND NVL (ffvl.end_date_active,
                                                        SYSDATE) >=
                                                   SYSDATE
                                               AND attribute1 = i.org_id
                                               AND attribute2 IS NULL
                                               AND attribute3 IS NULL;
                                    EXCEPTION
                                        WHEN NO_DATA_FOUND
                                        THEN
                                            lv_template_type   := NULL;
                                        WHEN OTHERS
                                        THEN
                                            lv_template_type   := NULL;
                                    END;
                                WHEN OTHERS
                                THEN
                                    lv_template_type   := NULL;
                            END;
                        WHEN OTHERS
                        THEN
                            lv_template_type   := NULL;
                    END;
                WHEN OTHERS
                THEN
                    lv_template_type   := NULL;
            END;

            fnd_file.put_line (
                fnd_file.LOG,
                   'Template Type is:'
                || lv_template_type
                || '-'
                || 'for the Invoice:'
                || i.invoice_num
                || '-'
                || 'of payment num:'
                || i.payment_reference_number);

            IF NVL (lv_template_type, 'X') = 'English Template'
            THEN
                lv_template   := 'EN';
            ELSIF NVL (lv_template_type, 'X') = 'China Template'
            THEN
                lv_template   := 'CH';
            ELSIF NVL (lv_template_type, 'X') = 'Japan Template'
            THEN
                lv_template   := 'JP';
            ELSE
                lv_template   := NULL;
            END IF;

            -- Query to get Vendor Email address, Check at vendor site level, if not exists fetch from verdor.
            BEGIN
                -- query to fetch vendor site level payment email id
                SELECT payee.remit_advice_email
                  INTO lv_email_address
                  FROM iby_external_payees_all payee, iby_payments_all pmt
                 WHERE     payee.payee_party_id = pmt.payee_party_id
                       AND payee.payment_function = pmt.payment_function
                       AND payee.org_id = pmt.org_id
                       AND payee.org_type = pmt.org_type
                       AND payee.party_site_id = pmt.party_site_id
                       AND payee.supplier_site_id = pmt.supplier_site_id
                       AND pmt.payment_reference_number =
                           i.payment_reference_number;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_email_address   := NULL;
            END;

            fnd_file.put_line (
                fnd_file.LOG,
                'Site level email address:' || lv_email_address);

            IF lv_email_address IS NULL
            THEN
                --query to fetch vendor level email address
                BEGIN
                    SELECT payee.remit_advice_email
                      INTO lv_email_address
                      FROM iby_external_payees_all payee, iby_payments_all pmt
                     WHERE     payee.payee_party_id = pmt.payee_party_id
                           AND payee.payment_function = pmt.payment_function
                           AND payee.org_id IS NULL
                           AND payee.party_site_id IS NULL
                           AND payee.supplier_site_id IS NULL
                           AND pmt.payment_reference_number =
                               i.payment_reference_number;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_email_address   := NULL;
                END;

                fnd_file.put_line (
                    fnd_file.LOG,
                    'Vendor level email address:' || lv_email_address);
            END IF;


            -- Insert the cusrsor data in the global temporary table
            BEGIN
                INSERT INTO xxdo.xxd_ap_pay_det_gt (payment_reference_number,
                                                    payment_date,
                                                    legal_entity,
                                                    org_id,
                                                    address_line1,
                                                    address_line2,
                                                    city,
                                                    country,
                                                    zip_code,
                                                    org_address, -- payment method and pay group
                                                    vendor_name,
                                                    vendor_number,
                                                    invoice_number,
                                                    invoice_date,
                                                    currency_code,
                                                    invoice_amount,
                                                    inv_description,
                                                    line_description,
                                                    acc_description,
                                                    line_type,
                                                    line_amount,
                                                    po_number,
                                                    wh_tax_name, -- internal bank name
                                                    wh_tax_amount, -- check number
                                                    disc_amount,
                                                    amount_paid,
                                                    template_type,
                                                    email,
                                                    email_distribution_list,
                                                    output_type,
                                                    creation_date,
                                                    created_by,
                                                    last_update_date,
                                                    last_updated_by,
                                                    request_id)
                     VALUES (i.payment_reference_number, i.payment_date, i.name, i.org_id, i.address_line1, i.address_line2, i.city, i.country, i.zip, i.pay_group_method, i.vendor_name, i.vendor_num, i.invoice_num, i.invoice_date, i.payment_currency_code, i.invoice_amount, i.description, i.line_description, i.acc_description, i.line_type_lookup_code, i.line_amount, i.po_number, i.int_bank_name, i.check_number, i.disc_amount, i.payment_amount, lv_template, lv_email_address, P_EMAIL_DISTRIBUTION_LIST, P_OUTPUT_TYPE, SYSDATE, gn_user_id, SYSDATE
                             , gn_user_id, gn_request_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Failed to insert the records into the table:'
                        || SQLERRM);
            END;
        END LOOP;

        RETURN (TRUE);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'sqlerrm:' || SQLERRM);
            RETURN (TRUE);
    END xml_main;

    /***********************************************************************************************
 **************** Function to submit the xml bursting program*********************************
 ************************************************************************************************/
    FUNCTION send_email (P_EMAIL_REQUIRED IN VARCHAR2)
        RETURN BOOLEAN
    AS
        -- Cursor to fetch the payment details based on the par
        ln_request_id     NUMBER;
        ln_burst_req_id   NUMBER;
    BEGIN
        --  Parameter P_EMAIL_REQUIRED is Y then send email
        IF NVL (P_EMAIL_REQUIRED, 'N') = 'Y'
        THEN
            -- query to get request id of XML program.
            BEGIN
                SELECT DISTINCT request_id
                  INTO ln_request_id
                  FROM xxdo.xxd_ap_pay_det_gt;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_request_id   := NULL;
            END;

            -- submit the concurrent program if request id is not null
            IF ln_request_id IS NOT NULL
            THEN
                ln_burst_req_id   :=
                    fnd_request.submit_request (
                        application   => 'XDO',
                        -- application
                        program       => 'XDOBURSTREP',
                        -- Program
                        description   =>
                            'XML Publisher Report Bursting Program',
                        -- description
                        argument1     => 'Y',
                        argument2     => ln_request_id,
                        -- argument1
                        argument3     => 'Y'                      -- argument2
                                            );

                fnd_file.put_line (
                    fnd_file.LOG,
                    'Bursting Request ID  - ' || ln_burst_req_id);

                IF ln_burst_req_id <= 0
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Failed to submit Bursting XML Publisher Request for Request ID = '
                        || ln_request_id);
                ELSE
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Submitted Bursting XML Publisher Request Request ID = '
                        || ln_burst_req_id);
                END IF;
            END IF;
        ELSE
            fnd_file.put_line (
                fnd_file.LOG,
                'P_EMAIL_REQUIRED Parameter is No - No email.');
        END IF;

        RETURN (TRUE);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'sqlerrm:' || SQLERRM);
            RETURN (TRUE);
    END send_email;

    /************************************************************************************************
  **************** Main Procedure to submit the xml program based on the output type *************
  ************************************************************************************************/
    PROCEDURE main (p_errbuf OUT VARCHAR2, p_retcode OUT NUMBER, p_ou IN VARCHAR2, p_pay_group IN VARCHAR2, p_payment_method IN VARCHAR2, p_vendor_name IN VARCHAR2, p_vendor_num IN VARCHAR2, p_vendor_site IN VARCHAR2, p_vendor_type IN VARCHAR2, P_PAY_DATE_FROM IN VARCHAR2, p_pay_date_to IN VARCHAR2, p_invoice_num IN VARCHAR2, p_payment_num IN NUMBER, P_EMAIL_DISTRIBUTION_LIST IN VARCHAR2, P_EMAIL_REQUIRED IN VARCHAR2
                    , P_OUTPUT_TYPE IN VARCHAR2)
    IS
        ln_layout       BOOLEAN;
        ln_request_id   NUMBER := 0;
    BEGIN
        -- Submit the child program and attach the layout based on p_output_type
        IF NVL (P_OUTPUT_TYPE, 'PDF') = 'PDF'
        THEN
            -- Attach the PDF template to the program.
            ln_layout   :=
                fnd_request.add_layout (
                    template_appl_name   => 'XXDO',
                    template_code        => 'XXDOAPREMADV',
                    template_language    => 'en',
                    template_territory   => 'US',
                    output_format        => 'PDF');
        ELSIF NVL (P_OUTPUT_TYPE, 'PDF') = 'EXCEL'
        THEN
            -- Attach the Excel template to the program.
            ln_layout   :=
                fnd_request.add_layout (
                    template_appl_name   => 'XXDO',
                    template_code        => 'XXDOAPREMADVXLS',
                    template_language    => 'en',
                    template_territory   => 'US',
                    output_format        => 'EXCEL');
        END IF;

        -- Submit the concurrent program with the given parameters.
        BEGIN
            ln_request_id   :=
                fnd_request.submit_request (application => 'XXDO', program => 'XXDOAPREMADV', description => 'Deckers AP Remittance Advise Detail Child', start_time => SYSDATE, sub_request => FALSE, argument1 => p_ou, argument2 => p_pay_group, argument3 => p_payment_method, argument4 => p_vendor_name, argument5 => p_vendor_num, argument6 => p_vendor_site, argument7 => p_vendor_type, argument8 => P_PAY_DATE_FROM, argument9 => p_pay_date_to, argument10 => p_invoice_num, argument11 => p_payment_num, argument12 => P_EMAIL_DISTRIBUTION_LIST, argument13 => P_EMAIL_REQUIRED
                                            , argument14 => p_output_type);
            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_request_id   := 0;
        END;

        IF ln_request_id = 0
        THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Concurrent Request failed to submit');
        ELSE
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'Successfully Submitted the Concurrent Request with request id:'
                || ln_request_id);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'Error While Submitting Concurrent Request '
                || TO_CHAR (SQLCODE)
                || '-'
                || SQLERRM);
    END MAIN;
END;                                    -- Package XXD_AP_SEND_REM_ADV_PKG end
/
