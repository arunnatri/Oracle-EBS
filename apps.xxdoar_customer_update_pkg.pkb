--
-- XXDOAR_CUSTOMER_UPDATE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:19 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOAR_CUSTOMER_UPDATE_PKG"
AS
    /******************************************************************************
    -- NAME:       XXDOAR_CUSTOMER_UPDATE_PKG
    -- PURPOSE:   To define procedures used for customer transmission flag and
    --            contact role update
    -- REVISIONS:
    -- Ver      Date          Author          Description
    -- -----    ----------    -------------   -----------------------------------
    -- 1.0      10-JUL-2016    Infosys         Initial version
    ******************************************************************************/
    -- global variables
    g_request_id          NUMBER := 0;
    g_data_file_name      VARCHAR2 (240);
    g_control_file_name   VARCHAR2 (240);
    g_process_type        VARCHAR2 (100);

    -- Procedure to update transmission flag
    PROCEDURE xxdoar_upd_transmission_flag
    IS
        -- Cursor to fetch records for transmission flag update
        CURSOR c_upd_transmission_flag IS
            SELECT customer_name, account_number, party_site_number,
                   operating_unit, site_use_code, invoice_transmission_method,
                   creditmemo_transmission_method, debitmemo_transmission_method, statement_transmission_method,
                   status_flag, error_description, request_id
              FROM xxdoar_customer_update_stg
             WHERE     request_id = g_request_id
                   AND status_flag = 'NEW'
                   AND error_description IS NULL;

        -- Cursor to fetch party site details
        CURSOR cur_party_site_details (l_cust_account_number   VARCHAR2,
                                       l_party_site_number     VARCHAR2)
        IS
            SELECT hps.party_site_id, hou.organization_id, hou.name operating_unit,
                   hps.attribute1, hps.attribute2, hps.attribute3,
                   hps.attribute6, hps.object_version_number
              FROM hz_parties hp, hz_party_sites hps, hz_cust_accounts_all hca,
                   hz_cust_acct_sites_all hcas, hr_operating_units hou, hz_cust_site_uses_all hcsu
             WHERE     hp.party_id = hca.party_id
                   AND hca.cust_account_id = hcas.cust_account_id(+)
                   AND hps.party_site_id(+) = hcas.party_site_id
                   AND hcas.org_id = hou.organization_id
                   AND hcas.status = 'A'
                   AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND hcas.org_id = hcsu.org_id
                   AND hcsu.site_use_code = 'BILL_TO'
                   AND hps.party_site_number =
                       NVL (l_party_site_number, hps.party_site_number)
                   AND hca.account_number = l_cust_account_number;

        --
        -- Local Variable declaration
        lv_return_status           VARCHAR2 (200);
        ln_msg_count               NUMBER;
        lv_msg_data                VARCHAR2 (200);
        lr_party_site_rec          hz_party_site_v2pub.party_site_rec_type;
        lv_msg                     VARCHAR2 (200);
        lv_party_site_exists       VARCHAR2 (1);
        ln_party_site_id           NUMBER;
        ln_context_org_id          NUMBER;
        lv_invoice                 VARCHAR2 (150);
        lv_credit_memo             VARCHAR2 (150);
        lv_debit_memo              VARCHAR2 (150);
        lv_statement               VARCHAR2 (150);
        ln_object_version_number   NUMBER;
        lv_update_req_flag         VARCHAR2 (1);
        lv_chr_error_message       VARCHAR2 (4000);
        lv_chr_error_code          VARCHAR2 (20);
        lv_operating_unit          VARCHAR2 (200);
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'Inside xxdoar_upd_transmission_flag  procedure ');

        --
        FOR c_record IN c_upd_transmission_flag
        LOOP
            lv_party_site_exists   := 'N';
            fnd_file.put_line (
                fnd_file.LOG,
                '------------------------------------------------------------------------------');
            fnd_file.put_line (
                fnd_file.LOG,
                'Process record for customer :' || c_record.account_number);

            -- Fetch customer details
            --
            FOR lcsr_party_site_details
                IN cur_party_site_details (c_record.account_number,
                                           c_record.party_site_number)
            LOOP
                BEGIN
                    -- Initialize the values
                    lv_party_site_exists       := 'Y';
                    ln_party_site_id           := NULL;
                    ln_context_org_id          := NULL;
                    lv_invoice                 := NULL;
                    lv_credit_memo             := NULL;
                    lv_debit_memo              := NULL;
                    lv_statement               := NULL;
                    ln_object_version_number   := NULL;
                    lr_party_site_rec          := NULL;
                    lv_chr_error_code          := NULL;
                    lv_chr_error_message       := NULL;
                    lv_update_req_flag         := 'N';
                    lv_operating_unit          := NULL;
                    ln_party_site_id           :=
                        lcsr_party_site_details.party_site_id;
                    ln_context_org_id          :=
                        lcsr_party_site_details.organization_id;
                    lv_invoice                 :=
                        lcsr_party_site_details.attribute1;
                    lv_credit_memo             :=
                        lcsr_party_site_details.attribute2;
                    lv_debit_memo              :=
                        lcsr_party_site_details.attribute3;
                    lv_statement               :=
                        lcsr_party_site_details.attribute6;
                    ln_object_version_number   :=
                        lcsr_party_site_details.object_version_number;
                    lv_operating_unit          :=
                        lcsr_party_site_details.operating_unit;

                    --
                    IF ln_context_org_id IS NOT NULL
                    THEN
                        mo_global.set_policy_context ('S', ln_context_org_id);
                    END IF;

                    --
                    --
                    BEGIN
                        IF NVL (lv_invoice, 'XXXX') <>
                           NVL (c_record.invoice_transmission_method, 'XXXX')
                        THEN
                            lr_party_site_rec.attribute1   :=
                                c_record.invoice_transmission_method;
                            lv_update_req_flag   := 'Y';
                        END IF;

                        --
                        --
                        IF NVL (lv_credit_memo, 'XXXX') <>
                           NVL (c_record.creditmemo_transmission_method,
                                'XXXX')
                        THEN
                            lr_party_site_rec.attribute2   :=
                                c_record.creditmemo_transmission_method;
                            lv_update_req_flag   := 'Y';
                        END IF;

                        --
                        --
                        IF NVL (lv_debit_memo, 'XXXX') <>
                           NVL (c_record.debitmemo_transmission_method,
                                'XXXX')
                        THEN
                            lr_party_site_rec.attribute3   :=
                                c_record.debitmemo_transmission_method;
                            lv_update_req_flag   := 'Y';
                        --
                        --
                        END IF;

                        IF NVL (lv_statement, 'XXXX') <>
                           NVL (c_record.statement_transmission_method,
                                'XXXX')
                        THEN
                            BEGIN
                                SELECT flv.lookup_code
                                  INTO lr_party_site_rec.attribute6
                                  FROM fnd_lookup_values flv
                                 WHERE     flv.lookup_type =
                                           'DO_AR_TRX_TRANS_METHODS'
                                       AND flv.language = USERENV ('LANG')
                                       AND flv.meaning =
                                           c_record.statement_transmission_method
                                       AND flv.enabled_flag = 'Y'
                                       AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                       NVL (
                                                                           start_date_active,
                                                                             SYSDATE
                                                                           - 1))
                                                               AND TRUNC (
                                                                       NVL (
                                                                           end_date_active,
                                                                             SYSDATE
                                                                           + 1));

                                lv_update_req_flag   := 'Y';
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Error fetching lookup code for statement trans - '
                                        || c_record.statement_transmission_method
                                        || '. Error -'
                                        || SQLERRM);
                                    lv_chr_error_code   := 'ERROR';
                                    lv_chr_error_message   :=
                                           lv_chr_error_message
                                        || ';'
                                        || 'Error fetching lookup code for statement trans - '
                                        || c_record.statement_transmission_method;
                            END;
                        END IF;

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'ln_party_site_id ::' || ln_party_site_id);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'ln_context_org_id ::' || ln_context_org_id);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'ln_object_version_number::'
                            || ln_object_version_number);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            '-- Current Value for Attributes --');
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'lv_invoice::' || NVL (lv_invoice, 'NULL'));
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'lv_credit_memo::'
                            || NVL (lv_credit_memo, 'NULL'));
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'lv_debit_memo::' || NVL (lv_debit_memo, 'NULL'));
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'lv_statement ::' || NVL (lv_statement, 'NULL'));

                        IF (lv_update_req_flag = 'Y' AND lv_chr_error_code IS NULL)
                        THEN
                            --Update attribute category
                            lr_party_site_rec.party_site_id   :=
                                ln_party_site_id;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                '-- Updated Value for Attributes --');
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'invoice_transmission_method::'
                                || NVL (c_record.invoice_transmission_method,
                                        'NULL'));
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'creditmemo_transmission_method::'
                                || NVL (
                                       c_record.creditmemo_transmission_method,
                                       'NULL'));
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'debitmemo_transmission_method::'
                                || NVL (
                                       c_record.debitmemo_transmission_method,
                                       'NULL'));
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'statement_transmission_method ::'
                                || NVL (
                                       c_record.statement_transmission_method,
                                       'NULL'));
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Call to hz_party_site_v2pub.update_party_site API');

                            --
                            BEGIN
                                hz_party_site_v2pub.update_party_site (
                                    p_init_msg_list    => fnd_api.g_false,
                                    p_party_site_rec   => lr_party_site_rec,
                                    p_object_version_number   =>
                                        ln_object_version_number,
                                    x_return_status    => lv_return_status,
                                    x_msg_count        => ln_msg_count,
                                    x_msg_data         => lv_msg_data);

                                IF (lv_return_status <> fnd_api.g_ret_sts_success)
                                THEN
                                    FOR i IN 1 .. fnd_msg_pub.count_msg
                                    LOOP
                                        lv_msg              :=
                                            fnd_msg_pub.get (
                                                p_msg_index   => i,
                                                p_encoded     =>
                                                    fnd_api.g_false);
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'The API call failed with error '
                                            || lv_msg);
                                        lv_chr_error_code   := 'ERROR';
                                        lv_chr_error_message   :=
                                               lv_chr_error_message
                                            || ';'
                                            || 'ERROR in update API';
                                    END LOOP;
                                ELSE
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'The API call status - SUCESSS');
                                    COMMIT;
                                    lv_chr_error_code   := 'SUCCESS';
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Error while executing API. Error -'
                                        || SQLERRM);
                                    lv_chr_error_code   := 'ERROR';
                                    lv_chr_error_message   :=
                                           lv_chr_error_message
                                        || ';'
                                        || 'Error while executing API';
                            END;
                        ELSE
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'No update required to attribute values for customer :'
                                || c_record.account_number);
                            lv_chr_error_code   := 'SUCCESS';
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'ERROR in updating transmission flag for customer :'
                                || c_record.account_number);
                    END;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'ERROR while processing record for customer :'
                            || c_record.account_number);
                END;                -- End of begin for processing each record

                fnd_file.put_line (fnd_file.LOG,
                                   '---------------------------------');
            END LOOP;

            IF lv_party_site_exists = 'N'
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Invalid customer details for customer :' || c_record.account_number);
                lv_chr_error_code      := 'ERROR';
                lv_chr_error_message   := 'Invalid customer details';
                fnd_file.put_line (fnd_file.LOG,
                                   '---------------------------------');
            END IF;

            --
            --Update success and error record details
            IF lv_chr_error_code = 'ERROR'
            THEN
                --
                UPDATE xxdoar_customer_update_stg
                   SET status_flag = 'ERROR', error_description = lv_chr_error_message, operating_unit = lv_operating_unit,
                       last_update_date = SYSDATE, last_updated_by = fnd_global.user_id
                 WHERE     request_id = g_request_id
                       AND account_number = c_record.account_number;
            --
            --
            ELSE
                UPDATE xxdoar_customer_update_stg
                   SET status_flag = 'SUCCESS', error_description = NULL, operating_unit = lv_operating_unit,
                       last_update_date = SYSDATE, last_updated_by = fnd_global.user_id
                 WHERE     request_id = g_request_id
                       AND account_number = c_record.account_number;
            END IF;

            COMMIT;
        END LOOP;                                        -- End of cursor loop

        --
        fnd_file.put_line (
            fnd_file.LOG,
            '------------------------------------------------------------------------------');
        fnd_file.put_line (fnd_file.LOG,
                           'Exiting xxdoar_upd_transmission_flag procedure ');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error in xxdoar_upd_transmission_flag procedure :'
                || SQLERRM);
    END xxdoar_upd_transmission_flag;

    --
    --Procedure to Update Contact role
    PROCEDURE xxdoar_update_contact_role
    IS
        --Cursor to fetch the records for  contact update
        CURSOR c_upd_contact_role IS
            SELECT customer_name, account_number, party_site_number,
                   operating_unit, site_use_code, contact_name,
                   role1, role2, role3,
                   role4, role5, role6,
                   status_flag, error_description, request_id
              FROM xxdoar_customer_update_stg
             WHERE     request_id = g_request_id
                   AND status_flag = 'NEW'
                   AND error_description IS NULL;

        --
        --
        --Local Variables
        lv_chr_error_message        VARCHAR2 (4000);
        lv_chr_error_code           VARCHAR2 (20);
        lv_role_code                VARCHAR2 (100);
        lv_return_status            VARCHAR2 (2000);
        ln_msg_count                NUMBER;
        lv_msg_data                 VARCHAR2 (2000);
        lv_msg                      VARCHAR2 (2000);
        p_role_responsibility_rec   hz_cust_account_role_v2pub.role_responsibility_rec_type;
        p_object_version_number     NUMBER;
        lv_create_role_flag         VARCHAR2 (1);
        lv_update_role_flag         VARCHAR2 (1);
        lv_primary_flag             VARCHAR2 (1);
        lv_created_by_module        hz_role_responsibility.created_by_module%TYPE;
        ln_responsibility_id        NUMBER;
        ln_cust_role_id             NUMBER;
        lv_responsibility_type      VARCHAR2 (30);
        --Variables for creating contact role
        x_responsibility_id         NUMBER;
        x_return_status             VARCHAR2 (2000);
        x_msg_count                 NUMBER;
        x_msg_data                  VARCHAR2 (2000);
        lv_contact_exists           VARCHAR2 (1);
        lv_success_count            NUMBER;
        lv_error_count              NUMBER;
    --
    --
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'Inside xxdoar_update_contact_role procedure ');
        lv_success_count   := 0;
        lv_error_count     := 0;

        FOR c_record IN c_upd_contact_role
        LOOP
            lv_chr_error_code      := NULL;
            lv_chr_error_message   := NULL;
            lv_create_role_flag    := 'N';
            lv_update_role_flag    := 'N';
            lv_contact_exists      := 'N';

            fnd_file.put_line (
                fnd_file.LOG,
                '------------------------------------------------------------------------------');
            fnd_file.put_line (
                fnd_file.LOG,
                   'Process record for customer : '
                || c_record.account_number
                || ' and contact : '
                || c_record.contact_name);

            --
            --
            BEGIN
                SELECT 'Y'
                  INTO lv_contact_exists
                  FROM hz_cust_accounts_all hca, hz_cust_account_roles hcar, hz_relationships hzr,
                       hz_org_contacts hzc, hz_parties hzp
                 WHERE     hcar.cust_account_id = hca.cust_account_id(+)
                       AND hcar.party_id = hzr.party_id(+)
                       AND hca.party_id = hzr.object_id
                       AND hzr.relationship_id = hzc.party_relationship_id(+)
                       AND hzr.subject_id = hzp.party_id
                       AND hca.account_number = c_record.account_number
                       AND hca.status = 'A'
                       AND hzp.status = 'A'
                       AND hzp.party_name = c_record.contact_name;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_contact_exists   := 'N';
                    lv_chr_error_code   := 'ERROR';
                    lv_chr_error_message   :=
                        'No contact exists for customer account';
                WHEN TOO_MANY_ROWS
                THEN
                    lv_contact_exists   := 'N';
                    lv_chr_error_code   := 'ERROR';
                    lv_chr_error_message   :=
                        'More than one contact exists with same name for customer account';
                WHEN OTHERS
                THEN
                    lv_contact_exists   := 'N';
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Error in validating customer contact' || SQLERRM);
                    lv_chr_error_code   := 'ERROR';
                    lv_chr_error_message   :=
                        'Error in validating customer contact';
            END;

            --
            --
            IF lv_contact_exists = 'Y'
            THEN
                --
                --
                IF c_record.role2 IS NOT NULL
                THEN
                    --
                    -- Fetch Role Code
                    BEGIN
                        lv_role_code                := NULL;
                        lv_create_role_flag         := 'N';
                        lv_update_role_flag         := 'N';
                        ln_responsibility_id        := NULL;
                        ln_cust_role_id             := NULL;
                        lv_responsibility_type      := NULL;
                        lv_primary_flag             := 'N';
                        p_role_responsibility_rec   := NULL;
                        p_object_version_number     := NULL;

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Fetch lookup code for role2:: ' || c_record.role2);

                        SELECT ar.lookup_code
                          INTO lv_role_code
                          FROM ar_lookups ar
                         WHERE     ar.lookup_type = 'SITE_USE_CODE'
                               AND ar.meaning = c_record.role2
                               AND ar.enabled_flag = 'Y'
                               AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                               NVL (
                                                                   ar.start_date_active,
                                                                     SYSDATE
                                                                   - 1))
                                                       AND TRUNC (
                                                               NVL (
                                                                   ar.end_date_active,
                                                                     SYSDATE
                                                                   + 1));
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Error in deriving role2 lookup code');
                            lv_chr_error_code   := 'ERROR';
                            lv_chr_error_message   :=
                                'Error in deriving role2 lookup code';
                    END;

                    --
                    -- Fetch details for role update /create
                    BEGIN
                        SELECT hrr.object_version_number, hrr.responsibility_id, hrr.cust_account_role_id,
                               hrr.responsibility_type, hrr.primary_flag, 'Y'
                          INTO p_object_version_number, ln_responsibility_id, ln_cust_role_id, lv_responsibility_type,
                                                      lv_primary_flag, lv_update_role_flag
                          FROM hz_parties hp, hz_cust_accounts_all hca, hz_cust_account_roles hcar,
                               hz_role_responsibility hrr, hz_relationships hzr, hz_org_contacts hzc,
                               hz_parties hp1
                         WHERE     hp.party_id = hca.party_id
                               AND hca.account_number =
                                   c_record.account_number
                               AND hcar.cust_account_id = hca.cust_account_id
                               AND hrr.cust_account_role_id =
                                   hcar.cust_account_role_id
                               AND hca.party_id = hzr.object_id
                               AND hcar.party_id = hzr.party_id(+)
                               AND hzr.relationship_id =
                                   hzc.party_relationship_id(+)
                               AND hzr.subject_id = hp1.party_id
                               AND hrr.responsibility_type = lv_role_code
                               AND hp1.party_name = c_record.contact_name
                               AND hp.status = 'A'
                               AND hca.status = 'A'
                               AND hp1.status = 'A';
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Customer contact role2 does not exist');
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error in validating role2 for customer'
                                || SQLERRM);
                            lv_chr_error_code   := 'ERROR';
                            lv_chr_error_message   :=
                                'Error in validating role2 for customer';
                    END;

                    --
                    --
                    IF (lv_update_role_flag = 'Y' AND lv_primary_flag = 'Y')
                    THEN
                        BEGIN
                            -- Flush messages existing already
                            FND_MSG_PUB.Delete_Msg;

                            -- Initialize the values
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Updating the primary_flag to "N"  for role2 ::'
                                || c_record.role2);

                            p_object_version_number                  :=
                                p_object_version_number;
                            p_role_responsibility_rec.responsibility_id   :=
                                ln_responsibility_id;
                            p_role_responsibility_rec.cust_account_role_id   :=
                                ln_cust_role_id;
                            p_role_responsibility_rec.responsibility_type   :=
                                lv_responsibility_type;
                            p_role_responsibility_rec.primary_flag   := 'N';

                            -- Call API to update for role2
                            hz_cust_account_role_v2pub.update_role_responsibility (
                                'T',
                                p_role_responsibility_rec,
                                p_object_version_number,
                                lv_return_status,
                                ln_msg_count,
                                lv_msg_data);

                            BEGIN
                                IF (lv_return_status <> fnd_api.g_ret_sts_success)
                                THEN
                                    FOR i IN 1 .. fnd_msg_pub.count_msg
                                    LOOP
                                        lv_msg              :=
                                            fnd_msg_pub.get (
                                                p_msg_index   => i,
                                                p_encoded     =>
                                                    fnd_api.g_false);
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'The API call failed with error '
                                            || lv_msg);
                                        lv_chr_error_code   := 'ERROR';
                                        lv_chr_error_message   :=
                                               lv_chr_error_message
                                            || ';'
                                            || 'ERROR in update API';
                                    END LOOP;
                                ELSE
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'The API call status - SUCESSS');
                                    COMMIT;
                                    lv_chr_error_code   := 'SUCCESS';
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'ERROR in API Call for customer :'
                                        || c_record.account_number);
                            END;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Error in API ' || SQLERRM);
                                lv_chr_error_code      := 'ERROR';
                                lv_chr_error_message   := 'Error in API ';
                        END;
                    END IF;

                    IF (lv_update_role_flag = 'Y' AND lv_primary_flag = 'N')
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Contact role exists with Primary flag "N" . No Action required.');
                    END IF;

                    -- Create role if role is not present
                    IF lv_update_role_flag = 'N'
                    THEN
                        BEGIN
                            ln_cust_role_id       := NULL;
                            lv_create_role_flag   := 'N';

                            --
                            --
                            BEGIN
                                SELECT hcar.cust_account_role_id, 'Y'
                                  INTO ln_cust_role_id, lv_create_role_flag
                                  FROM hz_cust_accounts_all hca, hz_cust_account_roles hcar, hz_relationships hzr,
                                       hz_org_contacts hzc, hz_parties hzp
                                 WHERE     hcar.cust_account_id =
                                           hca.cust_account_id(+)
                                       AND hcar.party_id = hzr.party_id(+)
                                       AND hca.party_id = hzr.object_id
                                       AND hzr.relationship_id =
                                           hzc.party_relationship_id(+)
                                       AND hzr.subject_id = hzp.party_id
                                       AND hca.account_number =
                                           c_record.account_number
                                       AND hzp.party_name =
                                           c_record.contact_name
                                       AND hca.status = 'A'
                                       AND hzp.status = 'A';
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'No contact exists for this customer '
                                        || SQLERRM);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Exit processing for this customer '
                                        || SQLERRM);
                                    lv_create_role_flag   := 'N';
                                    lv_chr_error_code     := 'ERROR';
                                    lv_chr_error_message   :=
                                        'No contact exists for this customer  ';
                            END;

                            --
                            --
                            -- Create role only if contact exists
                            IF lv_create_role_flag = 'Y'
                            THEN
                                BEGIN
                                    -- Flush messages existing already
                                    FND_MSG_PUB.Delete_Msg;

                                    p_role_responsibility_rec.cust_account_role_id   :=
                                        ln_cust_role_id;
                                    p_role_responsibility_rec.responsibility_type   :=
                                        lv_role_code;
                                    p_role_responsibility_rec.created_by_module   :=
                                        'TCA_V1_API';

                                    hz_cust_account_role_v2pub.create_role_responsibility (
                                        'T',
                                        p_role_responsibility_rec,
                                        x_responsibility_id,
                                        x_return_status,
                                        x_msg_count,
                                        x_msg_data);

                                    IF x_return_status = 'S'
                                    THEN
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'Contact role created successfully for role2 ::'
                                            || c_record.role2);
                                    END IF;

                                    COMMIT;

                                    IF x_msg_count > 1
                                    THEN
                                        FOR I IN 1 .. x_msg_count
                                        LOOP
                                            fnd_file.put_line (
                                                fnd_file.LOG,
                                                   I
                                                || '. '
                                                || SUBSTR (
                                                       FND_MSG_PUB.Get (
                                                           p_encoded   =>
                                                               FND_API.G_FALSE),
                                                       1,
                                                       255));
                                        END LOOP;
                                    END IF;
                                END;
                            ELSE
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'No Contacts exists for this customer '
                                    || SQLERRM);
                                lv_chr_error_code   := 'ERROR';
                                lv_chr_error_message   :=
                                    'No Contacts exists for this customer ';
                            END IF; --END OF IF FOR ROLE VERIFICATION AND CREATION
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Error in verifiying customer contact '
                                    || SQLERRM);
                                lv_chr_error_code   := 'ERROR';
                                lv_chr_error_message   :=
                                    'Error in verifiying customer contact  ';
                        END;
                    END IF;                     -- End of if for creating role
                --
                --
                END IF;                -- End of if condition for role2 update

                --
                --
                --
                IF c_record.role3 IS NOT NULL
                THEN
                    --
                    --
                    BEGIN
                        lv_role_code                := NULL;
                        lv_create_role_flag         := 'N';
                        lv_update_role_flag         := 'N';
                        ln_responsibility_id        := NULL;
                        ln_cust_role_id             := NULL;
                        lv_responsibility_type      := NULL;
                        lv_primary_flag             := 'N';
                        p_role_responsibility_rec   := NULL;
                        p_object_version_number     := NULL;

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Fetch lookup code for role3:: ' || c_record.role3);

                        SELECT ar.lookup_code
                          INTO lv_role_code
                          FROM ar_lookups ar
                         WHERE     ar.lookup_type = 'SITE_USE_CODE'
                               AND ar.meaning = c_record.role3
                               AND ar.enabled_flag = 'Y'
                               AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                               NVL (
                                                                   ar.start_date_active,
                                                                     SYSDATE
                                                                   - 1))
                                                       AND TRUNC (
                                                               NVL (
                                                                   ar.end_date_active,
                                                                     SYSDATE
                                                                   + 1));
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Error in deriving role3 lookup code');
                            lv_chr_error_code   := 'ERROR';
                            lv_chr_error_message   :=
                                'Error in deriving role3 lookup code';
                    END;

                    --
                    --
                    BEGIN
                        SELECT hrr.object_version_number, hrr.responsibility_id, hrr.cust_account_role_id,
                               hrr.responsibility_type, hrr.primary_flag, 'Y'
                          INTO p_object_version_number, ln_responsibility_id, ln_cust_role_id, lv_responsibility_type,
                                                      lv_primary_flag, lv_update_role_flag
                          FROM hz_parties hp, hz_cust_accounts_all hca, hz_cust_account_roles hcar,
                               hz_role_responsibility hrr, hz_relationships hzr, hz_org_contacts hzc,
                               hz_parties hp1
                         WHERE     hp.party_id = hca.party_id
                               AND hca.account_number =
                                   c_record.account_number
                               AND hcar.cust_account_id = hca.cust_account_id
                               AND hrr.cust_account_role_id =
                                   hcar.cust_account_role_id
                               AND hca.party_id = hzr.object_id
                               AND hcar.party_id = hzr.party_id(+)
                               AND hzr.relationship_id =
                                   hzc.party_relationship_id(+)
                               AND hzr.subject_id = hp1.party_id
                               AND hrr.responsibility_type = lv_role_code
                               AND hp1.party_name = c_record.contact_name
                               AND hp.status = 'A'
                               AND hca.status = 'A'
                               AND hp1.status = 'A';
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Customer contact role3 does not exists');
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error in validating role3 for customer'
                                || SQLERRM);
                            lv_chr_error_code   := 'ERROR';
                            lv_chr_error_message   :=
                                'Error in validating role3 for customer';
                    END;

                    --
                    --
                    IF (lv_update_role_flag = 'Y' AND lv_primary_flag = 'Y')
                    THEN
                        BEGIN
                            -- Flush messages existing already
                            FND_MSG_PUB.Delete_Msg;

                            -- Initialize the values
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Updating the primary_flag to "N"  for role3 ::'
                                || c_record.role3);

                            p_object_version_number                  :=
                                p_object_version_number;
                            p_role_responsibility_rec.responsibility_id   :=
                                ln_responsibility_id;
                            p_role_responsibility_rec.cust_account_role_id   :=
                                ln_cust_role_id;
                            p_role_responsibility_rec.responsibility_type   :=
                                lv_responsibility_type;
                            p_role_responsibility_rec.primary_flag   := 'N';

                            -- Call API to update the primary flag for role 3
                            hz_cust_account_role_v2pub.update_role_responsibility (
                                'T',
                                p_role_responsibility_rec,
                                p_object_version_number,
                                lv_return_status,
                                ln_msg_count,
                                lv_msg_data);

                            BEGIN
                                IF (lv_return_status <> fnd_api.g_ret_sts_success)
                                THEN
                                    FOR i IN 1 .. fnd_msg_pub.count_msg
                                    LOOP
                                        lv_msg              :=
                                            fnd_msg_pub.get (
                                                p_msg_index   => i,
                                                p_encoded     =>
                                                    fnd_api.g_false);
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'The API call failed with error '
                                            || lv_msg);
                                        lv_chr_error_code   := 'ERROR';
                                        lv_chr_error_message   :=
                                               lv_chr_error_message
                                            || ';'
                                            || 'ERROR in update API';
                                    END LOOP;
                                ELSE
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'The API call status - SUCESSS');
                                    COMMIT;
                                    lv_chr_error_code   := 'SUCCESS';
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'ERROR in API Call for customer :'
                                        || c_record.account_number);
                            END;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Error in API ' || SQLERRM);
                                lv_chr_error_code      := 'ERROR';
                                lv_chr_error_message   := 'Error in API ';
                        END;
                    END IF;

                    IF lv_update_role_flag = 'Y' AND lv_primary_flag = 'N'
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Contact role exists with Primary flag "N". No Action required.');
                    END IF;

                    --Code to create role if the role is not present
                    IF lv_update_role_flag = 'N'
                    THEN
                        BEGIN
                            ln_cust_role_id       := NULL;
                            lv_create_role_flag   := 'N';

                            --
                            --
                            BEGIN
                                SELECT hcar.cust_account_role_id, 'Y'
                                  INTO ln_cust_role_id, lv_create_role_flag
                                  FROM hz_cust_accounts_all hca, hz_cust_account_roles hcar, hz_relationships hzr,
                                       hz_org_contacts hzc, hz_parties hzp
                                 WHERE     hcar.cust_account_id =
                                           hca.cust_account_id(+)
                                       AND hcar.party_id = hzr.party_id(+)
                                       AND hca.party_id = hzr.object_id
                                       AND hzr.relationship_id =
                                           hzc.party_relationship_id(+)
                                       AND hzr.subject_id = hzp.party_id
                                       AND hca.account_number =
                                           c_record.account_number
                                       AND hzp.party_name =
                                           c_record.contact_name
                                       AND hca.status = 'A'
                                       AND hzp.status = 'A';
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'No contact exists for this customer - '
                                        || SQLERRM);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Exit processing for this customer '
                                        || SQLERRM);
                                    lv_create_role_flag   := 'N';
                                    lv_chr_error_code     := 'ERROR';
                                    lv_chr_error_message   :=
                                        'No contact exists for this customer  ';
                            END;

                            --
                            --
                            -- Create role only if contact exists
                            IF lv_create_role_flag = 'Y'
                            THEN
                                BEGIN
                                    -- Flush messages existing already
                                    FND_MSG_PUB.Delete_Msg;

                                    p_role_responsibility_rec.cust_account_role_id   :=
                                        ln_cust_role_id;
                                    p_role_responsibility_rec.responsibility_type   :=
                                        lv_role_code;
                                    p_role_responsibility_rec.created_by_module   :=
                                        'TCA_V1_API';
                                    hz_cust_account_role_v2pub.create_role_responsibility (
                                        'T',
                                        p_role_responsibility_rec,
                                        x_responsibility_id,
                                        x_return_status,
                                        x_msg_count,
                                        x_msg_data);

                                    IF x_return_status = 'S'
                                    THEN
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'Contact role created successfully for role3 ::'
                                            || c_record.role3);
                                    END IF;

                                    COMMIT;

                                    IF x_msg_count > 1
                                    THEN
                                        FOR I IN 1 .. x_msg_count
                                        LOOP
                                            fnd_file.put_line (
                                                fnd_file.LOG,
                                                   I
                                                || '. '
                                                || SUBSTR (
                                                       FND_MSG_PUB.Get (
                                                           p_encoded   =>
                                                               FND_API.G_FALSE),
                                                       1,
                                                       255));
                                        END LOOP;
                                    END IF;
                                END;
                            ELSE
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'No Contacts exists for this customer '
                                    || SQLERRM);
                                lv_chr_error_code   := 'ERROR';
                                lv_chr_error_message   :=
                                    'No Contacts exists for this customer ';
                            END IF; --END OF IF FOR ROLE VERIFICATION AND CREATION
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Error in verifiying customer contact '
                                    || SQLERRM);
                                lv_chr_error_code   := 'ERROR';
                                lv_chr_error_message   :=
                                    'Error in verifiying customer contact  ';
                        END;
                    END IF;                     -- End of if for creating role
                --
                --
                END IF;                -- End of if condition for role3 update

                --
                --
                --
                IF c_record.role4 IS NOT NULL
                THEN
                    --
                    --
                    BEGIN
                        lv_role_code                := NULL;
                        lv_create_role_flag         := 'N';
                        lv_update_role_flag         := 'N';
                        ln_responsibility_id        := NULL;
                        ln_cust_role_id             := NULL;
                        lv_responsibility_type      := NULL;
                        lv_primary_flag             := 'N';
                        p_role_responsibility_rec   := NULL;
                        p_object_version_number     := NULL;

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Fetch lookup code for  role4 :: ' || c_record.role4);

                        SELECT ar.lookup_code
                          INTO lv_role_code
                          FROM ar_lookups ar
                         WHERE     ar.lookup_type = 'SITE_USE_CODE'
                               AND ar.meaning = c_record.role4
                               AND ar.enabled_flag = 'Y'
                               AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                               NVL (
                                                                   ar.start_date_active,
                                                                     SYSDATE
                                                                   - 1))
                                                       AND TRUNC (
                                                               NVL (
                                                                   ar.end_date_active,
                                                                     SYSDATE
                                                                   + 1));
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Error in deriving role4 lookup code');
                            lv_chr_error_code   := 'ERROR';
                            lv_chr_error_message   :=
                                'Error in deriving role4 lookup code';
                    END;

                    --
                    --
                    BEGIN
                        SELECT hrr.object_version_number, hrr.responsibility_id, hrr.cust_account_role_id,
                               hrr.responsibility_type, hrr.primary_flag, 'Y'
                          INTO p_object_version_number, ln_responsibility_id, ln_cust_role_id, lv_responsibility_type,
                                                      lv_primary_flag, lv_update_role_flag
                          FROM hz_parties hp, hz_cust_accounts_all hca, hz_cust_account_roles hcar,
                               hz_role_responsibility hrr, hz_relationships hzr, hz_org_contacts hzc,
                               hz_parties hp1
                         WHERE     hp.party_id = hca.party_id
                               AND hca.account_number =
                                   c_record.account_number
                               AND hcar.cust_account_id = hca.cust_account_id
                               AND hrr.cust_account_role_id =
                                   hcar.cust_account_role_id
                               AND hca.party_id = hzr.object_id
                               AND hcar.party_id = hzr.party_id(+)
                               AND hzr.relationship_id =
                                   hzc.party_relationship_id(+)
                               AND hzr.subject_id = hp1.party_id
                               AND hrr.responsibility_type = lv_role_code
                               AND hp1.party_name = c_record.contact_name
                               AND hp.status = 'A'
                               AND hca.status = 'A'
                               AND hp1.status = 'A';
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Customer contact role4 does not exists');
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error in validating role4 for customer'
                                || SQLERRM);
                            lv_chr_error_code   := 'ERROR';
                            lv_chr_error_message   :=
                                'Error in validating role4 for customer';
                    END;

                    --
                    --
                    IF (lv_update_role_flag = 'Y' AND lv_primary_flag = 'Y')
                    THEN
                        BEGIN
                            -- Flush messages existing already
                            FND_MSG_PUB.Delete_Msg;

                            -- Initialize the values
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Updating the primary_flag to "N"  for role4 ::'
                                || c_record.role4);

                            p_object_version_number                  :=
                                p_object_version_number;
                            p_role_responsibility_rec.responsibility_id   :=
                                ln_responsibility_id;
                            p_role_responsibility_rec.cust_account_role_id   :=
                                ln_cust_role_id;
                            p_role_responsibility_rec.responsibility_type   :=
                                lv_responsibility_type;
                            p_role_responsibility_rec.primary_flag   := 'N';

                            --Call API to update the primary flag for role 4
                            hz_cust_account_role_v2pub.update_role_responsibility (
                                'T',
                                p_role_responsibility_rec,
                                p_object_version_number,
                                lv_return_status,
                                ln_msg_count,
                                lv_msg_data);

                            BEGIN
                                IF (lv_return_status <> fnd_api.g_ret_sts_success)
                                THEN
                                    FOR i IN 1 .. fnd_msg_pub.count_msg
                                    LOOP
                                        lv_msg              :=
                                            fnd_msg_pub.get (
                                                p_msg_index   => i,
                                                p_encoded     =>
                                                    fnd_api.g_false);
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'The API call failed with error '
                                            || lv_msg);
                                        lv_chr_error_code   := 'ERROR';
                                        lv_chr_error_message   :=
                                               lv_chr_error_message
                                            || ';'
                                            || 'ERROR in update API';
                                    END LOOP;
                                ELSE
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'The API call status - SUCESSS');
                                    COMMIT;
                                    lv_chr_error_code   := 'SUCCESS';
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'ERROR in API Call for customer :'
                                        || c_record.account_number);
                            END;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Error in API ' || SQLERRM);
                                lv_chr_error_code      := 'ERROR';
                                lv_chr_error_message   := 'Error in API ';
                        END;
                    END IF;

                    IF (lv_update_role_flag = 'Y' AND lv_primary_flag = 'N')
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Contact role exists with Primary flag "N". No Action required.');
                    END IF;

                    --Code to create role if the role is not present
                    IF lv_update_role_flag = 'N'
                    THEN
                        BEGIN
                            ln_cust_role_id       := NULL;
                            lv_create_role_flag   := 'N';

                            --
                            --
                            BEGIN
                                SELECT hcar.cust_account_role_id, 'Y'
                                  INTO ln_cust_role_id, lv_create_role_flag
                                  FROM hz_cust_accounts_all hca, hz_cust_account_roles hcar, hz_relationships hzr,
                                       hz_org_contacts hzc, hz_parties hzp
                                 WHERE     hcar.cust_account_id =
                                           hca.cust_account_id(+)
                                       AND hcar.party_id = hzr.party_id(+)
                                       AND hca.party_id = hzr.object_id
                                       AND hzr.relationship_id =
                                           hzc.party_relationship_id(+)
                                       AND hzr.subject_id = hzp.party_id
                                       AND hca.account_number =
                                           c_record.account_number
                                       AND hzp.party_name =
                                           c_record.contact_name
                                       AND hca.status = 'A'
                                       AND hzp.status = 'A';
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'No contact exists for this customer '
                                        || SQLERRM);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Exit processing for this customer '
                                        || SQLERRM);
                                    lv_create_role_flag   := 'N';
                                    lv_chr_error_code     := 'ERROR';
                                    lv_chr_error_message   :=
                                        'No contact exists for this customer  ';
                            END;

                            --
                            --
                            -- Create role only if contact exists
                            IF lv_create_role_flag = 'Y'
                            THEN
                                BEGIN
                                    -- Flush messages existing already
                                    FND_MSG_PUB.Delete_Msg;

                                    p_role_responsibility_rec.cust_account_role_id   :=
                                        ln_cust_role_id;
                                    p_role_responsibility_rec.responsibility_type   :=
                                        lv_role_code;
                                    p_role_responsibility_rec.created_by_module   :=
                                        'TCA_V1_API';

                                    hz_cust_account_role_v2pub.create_role_responsibility (
                                        'T',
                                        p_role_responsibility_rec,
                                        x_responsibility_id,
                                        x_return_status,
                                        x_msg_count,
                                        x_msg_data);

                                    IF x_return_status = 'S'
                                    THEN
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'Contact role created successfully for role4 ::'
                                            || c_record.role4);
                                    END IF;

                                    COMMIT;

                                    IF x_msg_count > 1
                                    THEN
                                        FOR I IN 1 .. x_msg_count
                                        LOOP
                                            fnd_file.put_line (
                                                fnd_file.LOG,
                                                   I
                                                || '. '
                                                || SUBSTR (
                                                       FND_MSG_PUB.Get (
                                                           p_encoded   =>
                                                               FND_API.G_FALSE),
                                                       1,
                                                       255));
                                        END LOOP;
                                    END IF;
                                END;
                            ELSE
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'No Contacts exists for this customer '
                                    || SQLERRM);
                                lv_chr_error_code   := 'ERROR';
                                lv_chr_error_message   :=
                                    'No Contacts exists for this customer ';
                            END IF; --END OF IF FOR ROLE VERIFICATION AND CREATION
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Error in verifiying customer contact '
                                    || SQLERRM);
                                lv_chr_error_code   := 'ERROR';
                                lv_chr_error_message   :=
                                    'Error in verifiying customer contact  ';
                        END;
                    END IF;                     -- End of if for creating role
                --
                --
                END IF;                -- End of if condition for role4 update

                --
                --
                IF c_record.role5 IS NOT NULL
                THEN
                    --
                    --
                    BEGIN
                        lv_role_code                := NULL;
                        lv_create_role_flag         := 'N';
                        lv_update_role_flag         := 'N';
                        ln_responsibility_id        := NULL;
                        ln_cust_role_id             := NULL;
                        lv_responsibility_type      := NULL;
                        lv_primary_flag             := 'N';
                        p_role_responsibility_rec   := NULL;
                        p_object_version_number     := NULL;

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Fetch lookup code for role5:: ' || c_record.role5);

                        SELECT ar.lookup_code
                          INTO lv_role_code
                          FROM ar_lookups ar
                         WHERE     ar.lookup_type = 'SITE_USE_CODE'
                               AND ar.meaning = c_record.role5
                               AND ar.enabled_flag = 'Y'
                               AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                               NVL (
                                                                   ar.start_date_active,
                                                                     SYSDATE
                                                                   - 1))
                                                       AND TRUNC (
                                                               NVL (
                                                                   ar.end_date_active,
                                                                     SYSDATE
                                                                   + 1));
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Error in deriving role5 lookup code');
                            lv_chr_error_code   := 'ERROR';
                            lv_chr_error_message   :=
                                'Error in deriving role5 lookup code';
                    END;

                    --
                    --
                    BEGIN
                        SELECT hrr.object_version_number, hrr.responsibility_id, hrr.cust_account_role_id,
                               hrr.responsibility_type, hrr.primary_flag, 'Y'
                          INTO p_object_version_number, ln_responsibility_id, ln_cust_role_id, lv_responsibility_type,
                                                      lv_primary_flag, lv_update_role_flag
                          FROM hz_parties hp, hz_cust_accounts_all hca, hz_cust_account_roles hcar,
                               hz_role_responsibility hrr, hz_relationships hzr, hz_org_contacts hzc,
                               hz_parties hp1
                         WHERE     hp.party_id = hca.party_id
                               AND hca.account_number =
                                   c_record.account_number
                               AND hcar.cust_account_id = hca.cust_account_id
                               AND hrr.cust_account_role_id =
                                   hcar.cust_account_role_id
                               AND hca.party_id = hzr.object_id
                               AND hcar.party_id = hzr.party_id(+)
                               AND hzr.relationship_id =
                                   hzc.party_relationship_id(+)
                               AND hzr.subject_id = hp1.party_id
                               AND hrr.responsibility_type = lv_role_code
                               AND hp1.party_name = c_record.contact_name
                               AND hp.status = 'A'
                               AND hca.status = 'A'
                               AND hp1.status = 'A';
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Customer contact role5 does not exist');
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error in validating role5 for customer'
                                || SQLERRM);
                            lv_chr_error_code   := 'ERROR';
                            lv_chr_error_message   :=
                                'Error in validating role5 for customer';
                    END;

                    --
                    --
                    IF (lv_update_role_flag = 'Y' AND lv_primary_flag = 'Y')
                    THEN
                        BEGIN
                            -- Flush messages existing already
                            FND_MSG_PUB.Delete_Msg;

                            -- Initialize the values
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Updating the primary_flag to "N"  for role5 ::'
                                || c_record.role5);
                            p_object_version_number                  :=
                                p_object_version_number;
                            p_role_responsibility_rec.responsibility_id   :=
                                ln_responsibility_id;
                            p_role_responsibility_rec.cust_account_role_id   :=
                                ln_cust_role_id;
                            p_role_responsibility_rec.responsibility_type   :=
                                lv_responsibility_type;
                            p_role_responsibility_rec.primary_flag   := 'N';

                            --Call API to update the primary flag for role 5
                            hz_cust_account_role_v2pub.update_role_responsibility (
                                'T',
                                p_role_responsibility_rec,
                                p_object_version_number,
                                lv_return_status,
                                ln_msg_count,
                                lv_msg_data);

                            BEGIN
                                IF (lv_return_status <> fnd_api.g_ret_sts_success)
                                THEN
                                    FOR i IN 1 .. fnd_msg_pub.count_msg
                                    LOOP
                                        lv_msg              :=
                                            fnd_msg_pub.get (
                                                p_msg_index   => i,
                                                p_encoded     =>
                                                    fnd_api.g_false);
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'The API call failed with error '
                                            || lv_msg);
                                        lv_chr_error_code   := 'ERROR';
                                        lv_chr_error_message   :=
                                               lv_chr_error_message
                                            || ';'
                                            || 'ERROR in update API';
                                    END LOOP;
                                ELSE
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'The API call status - SUCESSS');
                                    COMMIT;
                                    lv_chr_error_code   := 'SUCCESS';
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'ERROR in API Call for customer :'
                                        || c_record.account_number);
                            END;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Error in API ' || SQLERRM);
                                lv_chr_error_code      := 'ERROR';
                                lv_chr_error_message   := 'Error in API ';
                        END;
                    END IF;

                    IF (lv_update_role_flag = 'Y' AND lv_primary_flag = 'N')
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Contact role exists with Primary flag "N". No Action required.');
                    END IF;

                    --Code to create role if the role is not present
                    IF lv_update_role_flag = 'N'
                    THEN
                        BEGIN
                            ln_cust_role_id       := NULL;
                            lv_create_role_flag   := 'N';

                            --
                            --
                            BEGIN
                                SELECT hcar.cust_account_role_id, 'Y'
                                  INTO ln_cust_role_id, lv_create_role_flag
                                  FROM hz_cust_accounts_all hca, hz_cust_account_roles hcar, hz_relationships hzr,
                                       hz_org_contacts hzc, hz_parties hzp
                                 WHERE     hcar.cust_account_id =
                                           hca.cust_account_id(+)
                                       AND hcar.party_id = hzr.party_id(+)
                                       AND hca.party_id = hzr.object_id
                                       AND hzr.relationship_id =
                                           hzc.party_relationship_id(+)
                                       AND hzr.subject_id = hzp.party_id
                                       AND hca.account_number =
                                           c_record.account_number
                                       AND hzp.party_name =
                                           c_record.contact_name
                                       AND hca.status = 'A'
                                       AND hzp.status = 'A';
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'No contact exists for this customer '
                                        || SQLERRM);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Exit processing for this customer '
                                        || SQLERRM);
                                    lv_create_role_flag   := 'N';
                                    lv_chr_error_code     := 'ERROR';
                                    lv_chr_error_message   :=
                                        'No contact exists for this customer  ';
                            END;

                            --
                            --
                            -- Create role only if contact exists
                            IF lv_create_role_flag = 'Y'
                            THEN
                                BEGIN
                                    -- Flush messages existing already
                                    FND_MSG_PUB.Delete_Msg;

                                    p_role_responsibility_rec.cust_account_role_id   :=
                                        ln_cust_role_id;
                                    p_role_responsibility_rec.responsibility_type   :=
                                        lv_role_code;
                                    p_role_responsibility_rec.created_by_module   :=
                                        'TCA_V1_API';
                                    hz_cust_account_role_v2pub.create_role_responsibility (
                                        'T',
                                        p_role_responsibility_rec,
                                        x_responsibility_id,
                                        x_return_status,
                                        x_msg_count,
                                        x_msg_data);

                                    IF x_return_status = 'S'
                                    THEN
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'Contact role created successfully for role5 ::'
                                            || c_record.role5);
                                    END IF;

                                    COMMIT;

                                    IF x_msg_count > 1
                                    THEN
                                        FOR I IN 1 .. x_msg_count
                                        LOOP
                                            fnd_file.put_line (
                                                fnd_file.LOG,
                                                   I
                                                || '. '
                                                || SUBSTR (
                                                       FND_MSG_PUB.Get (
                                                           p_encoded   =>
                                                               FND_API.G_FALSE),
                                                       1,
                                                       255));
                                        END LOOP;
                                    END IF;
                                END;
                            ELSE
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'No Contacts exists for this customer '
                                    || SQLERRM);
                                lv_chr_error_code   := 'ERROR';
                                lv_chr_error_message   :=
                                    'No Contacts exists for this customer ';
                            END IF; --END OF IF FOR ROLE VERIFICATION AND CREATION
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Error in verifiying customer contact '
                                    || SQLERRM);
                                lv_chr_error_code   := 'ERROR';
                                lv_chr_error_message   :=
                                    'Error in verifiying customer contact  ';
                        END;
                    END IF;                     -- End of if for creating role
                --
                --
                END IF;                -- End of if condition for role5 update

                --
                --
                IF c_record.role6 IS NOT NULL
                THEN
                    --
                    --
                    BEGIN
                        lv_role_code                := NULL;
                        lv_create_role_flag         := 'N';
                        lv_update_role_flag         := 'N';
                        ln_responsibility_id        := NULL;
                        ln_cust_role_id             := NULL;
                        lv_responsibility_type      := NULL;
                        lv_primary_flag             := 'N';
                        p_role_responsibility_rec   := NULL;
                        p_object_version_number     := NULL;

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Fetch lookup code for role6 :: ' || c_record.role6);

                        SELECT ar.lookup_code
                          INTO lv_role_code
                          FROM ar_lookups ar
                         WHERE     ar.lookup_type = 'SITE_USE_CODE'
                               AND ar.meaning = c_record.role6
                               AND ar.enabled_flag = 'Y'
                               AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                               NVL (
                                                                   ar.start_date_active,
                                                                     SYSDATE
                                                                   - 1))
                                                       AND TRUNC (
                                                               NVL (
                                                                   ar.end_date_active,
                                                                     SYSDATE
                                                                   + 1));
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Error in deriving role6 lookup code');
                            lv_chr_error_code   := 'ERROR';
                            lv_chr_error_message   :=
                                'Error in deriving role6 lookup code';
                    END;

                    --
                    --
                    BEGIN
                        SELECT hrr.object_version_number, hrr.responsibility_id, hrr.cust_account_role_id,
                               hrr.responsibility_type, hrr.primary_flag, 'Y'
                          INTO p_object_version_number, ln_responsibility_id, ln_cust_role_id, lv_responsibility_type,
                                                      lv_primary_flag, lv_update_role_flag
                          FROM hz_parties hp, hz_cust_accounts_all hca, hz_cust_account_roles hcar,
                               hz_role_responsibility hrr, hz_relationships hzr, hz_org_contacts hzc,
                               hz_parties hp1
                         WHERE     hp.party_id = hca.party_id
                               AND hca.account_number =
                                   c_record.account_number
                               AND hcar.cust_account_id = hca.cust_account_id
                               AND hrr.cust_account_role_id =
                                   hcar.cust_account_role_id
                               AND hca.party_id = hzr.object_id
                               AND hcar.party_id = hzr.party_id(+)
                               AND hzr.relationship_id =
                                   hzc.party_relationship_id(+)
                               AND hzr.subject_id = hp1.party_id
                               AND hrr.responsibility_type = lv_role_code
                               AND hp1.party_name = c_record.contact_name
                               AND hp.status = 'A'
                               AND hca.status = 'A'
                               AND hp1.status = 'A';
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Customer contact role6 does not exists');
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error in validating role6 for customer'
                                || SQLERRM);
                            lv_chr_error_code   := 'ERROR';
                            lv_chr_error_message   :=
                                'Error in validating role6 for customer';
                    END;

                    --
                    --
                    IF (lv_update_role_flag = 'Y' AND lv_primary_flag = 'Y')
                    THEN
                        BEGIN
                            -- Flush messages existing already
                            FND_MSG_PUB.Delete_Msg;

                            -- Initialize the values
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Updating the primary_flag to "N"  for role ::'
                                || c_record.role6);

                            p_object_version_number                  :=
                                p_object_version_number;
                            p_role_responsibility_rec.responsibility_id   :=
                                ln_responsibility_id;
                            p_role_responsibility_rec.cust_account_role_id   :=
                                ln_cust_role_id;
                            p_role_responsibility_rec.responsibility_type   :=
                                lv_responsibility_type;
                            p_role_responsibility_rec.primary_flag   := 'N';

                            --Call API to update the primary flag for role 6
                            hz_cust_account_role_v2pub.update_role_responsibility (
                                'T',
                                p_role_responsibility_rec,
                                p_object_version_number,
                                lv_return_status,
                                ln_msg_count,
                                lv_msg_data);

                            BEGIN
                                IF (lv_return_status <> fnd_api.g_ret_sts_success)
                                THEN
                                    FOR i IN 1 .. fnd_msg_pub.count_msg
                                    LOOP
                                        lv_msg              :=
                                            fnd_msg_pub.get (
                                                p_msg_index   => i,
                                                p_encoded     =>
                                                    fnd_api.g_false);
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'The API call failed with error '
                                            || lv_msg);
                                        lv_chr_error_code   := 'ERROR';
                                        lv_chr_error_message   :=
                                               lv_chr_error_message
                                            || ';'
                                            || 'ERROR in update API';
                                    END LOOP;
                                ELSE
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'The API call status - SUCESSS');
                                    COMMIT;
                                    lv_chr_error_code   := 'SUCCESS';
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'ERROR in API Call for customer :'
                                        || c_record.account_number);
                            END;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Error in API ' || SQLERRM);
                                lv_chr_error_code      := 'ERROR';
                                lv_chr_error_message   := 'Error in API ';
                        END;
                    END IF;

                    IF (lv_update_role_flag = 'Y' AND lv_primary_flag = 'N')
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Contact role exists with Primary flag "N". No Action required.');
                    END IF;

                    --Code to create role if the role is not present
                    IF lv_update_role_flag = 'N'
                    THEN
                        BEGIN
                            ln_cust_role_id       := NULL;
                            lv_create_role_flag   := 'N';

                            --
                            --
                            BEGIN
                                SELECT hcar.cust_account_role_id, 'Y'
                                  INTO ln_cust_role_id, lv_create_role_flag
                                  FROM hz_cust_accounts_all hca, hz_cust_account_roles hcar, hz_relationships hzr,
                                       hz_org_contacts hzc, hz_parties hzp
                                 WHERE     hcar.cust_account_id =
                                           hca.cust_account_id(+)
                                       AND hcar.party_id = hzr.party_id(+)
                                       AND hca.party_id = hzr.object_id
                                       AND hzr.relationship_id =
                                           hzc.party_relationship_id(+)
                                       AND hzr.subject_id = hzp.party_id
                                       AND hca.account_number =
                                           c_record.account_number
                                       AND hzp.party_name =
                                           c_record.contact_name
                                       AND hca.status = 'A'
                                       AND hzp.status = 'A';
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'No contact exists for this customer '
                                        || SQLERRM);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Exit processing for this customer '
                                        || SQLERRM);
                                    lv_create_role_flag   := 'N';
                                    lv_chr_error_code     := 'ERROR';
                                    lv_chr_error_message   :=
                                        'No contact exists for this customer  ';
                            END;

                            --
                            --
                            -- Create role only if contact exists
                            IF lv_create_role_flag = 'Y'
                            THEN
                                BEGIN
                                    -- Flush messages existing already
                                    FND_MSG_PUB.Delete_Msg;

                                    p_role_responsibility_rec.cust_account_role_id   :=
                                        ln_cust_role_id;
                                    p_role_responsibility_rec.responsibility_type   :=
                                        lv_role_code;
                                    p_role_responsibility_rec.created_by_module   :=
                                        'TCA_V1_API';
                                    hz_cust_account_role_v2pub.create_role_responsibility (
                                        'T',
                                        p_role_responsibility_rec,
                                        x_responsibility_id,
                                        x_return_status,
                                        x_msg_count,
                                        x_msg_data);

                                    IF x_return_status = 'S'
                                    THEN
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'Contact role created successfully for role ::'
                                            || c_record.role6);
                                    END IF;

                                    COMMIT;

                                    IF x_msg_count > 1
                                    THEN
                                        FOR I IN 1 .. x_msg_count
                                        LOOP
                                            fnd_file.put_line (
                                                fnd_file.LOG,
                                                   I
                                                || '. '
                                                || SUBSTR (
                                                       FND_MSG_PUB.Get (
                                                           p_encoded   =>
                                                               FND_API.G_FALSE),
                                                       1,
                                                       255));
                                        END LOOP;
                                    END IF;
                                END;
                            ELSE
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'No Contacts exists for this customer '
                                    || SQLERRM);
                                lv_chr_error_code   := 'ERROR';
                                lv_chr_error_message   :=
                                    'No Contacts exists for this customer ';
                            END IF; --END OF IF FOR ROLE VERIFICATION AND CREATION
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Error in verifiying customer contact '
                                    || SQLERRM);
                                lv_chr_error_code   := 'ERROR';
                                lv_chr_error_message   :=
                                    'Error in verifiying customer contact  ';
                        END;
                    END IF;                     -- End of if for creating role
                --
                --
                END IF;                -- End of if condition for role6 update

                --
                --
                IF c_record.role1 IS NOT NULL
                THEN
                    --
                    --
                    BEGIN
                        lv_role_code                := NULL;
                        lv_create_role_flag         := 'N';
                        lv_update_role_flag         := 'N';
                        ln_responsibility_id        := NULL;
                        ln_cust_role_id             := NULL;
                        lv_responsibility_type      := NULL;
                        lv_primary_flag             := 'N';
                        p_role_responsibility_rec   := NULL;
                        p_object_version_number     := NULL;
                        lv_created_by_module        := NULL;

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Fetch lookup code for role1:: ' || c_record.role1);

                        SELECT ar.lookup_code
                          INTO lv_role_code
                          FROM ar_lookups ar
                         WHERE     ar.lookup_type = 'SITE_USE_CODE'
                               AND ar.meaning = c_record.role1
                               AND ar.enabled_flag = 'Y'
                               AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                               NVL (
                                                                   ar.start_date_active,
                                                                     SYSDATE
                                                                   - 1))
                                                       AND TRUNC (
                                                               NVL (
                                                                   ar.end_date_active,
                                                                     SYSDATE
                                                                   + 1));
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Error in deriving role1 lookup code');
                            lv_chr_error_code   := 'ERROR';
                            lv_chr_error_message   :=
                                'Error in deriving role1 lookup code';
                    END;

                    --
                    --
                    BEGIN
                        SELECT hrr.object_version_number, hrr.responsibility_id, hrr.cust_account_role_id,
                               hrr.responsibility_type, hrr.primary_flag, hrr.created_by_module,
                               'Y'
                          INTO p_object_version_number, ln_responsibility_id, ln_cust_role_id, lv_responsibility_type,
                                                      lv_primary_flag, lv_created_by_module, lv_update_role_flag
                          FROM hz_parties hp, hz_cust_accounts_all hca, hz_cust_account_roles hcar,
                               hz_role_responsibility hrr, hz_relationships hzr, hz_org_contacts hzc,
                               hz_parties hp1
                         WHERE     hp.party_id = hca.party_id
                               AND hca.account_number =
                                   c_record.account_number
                               AND hcar.cust_account_id = hca.cust_account_id
                               AND hrr.cust_account_role_id =
                                   hcar.cust_account_role_id
                               AND hca.party_id = hzr.object_id
                               AND hcar.party_id = hzr.party_id(+)
                               AND hzr.relationship_id =
                                   hzc.party_relationship_id(+)
                               AND hzr.subject_id = hp1.party_id
                               AND hrr.responsibility_type = lv_role_code
                               AND hp1.party_name = c_record.contact_name
                               AND hp.status = 'A'
                               AND hca.status = 'A'
                               AND hp1.status = 'A';
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Customer contact role1 does not exists');
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error in validating role1 for customer'
                                || SQLERRM);
                            lv_chr_error_code   := 'ERROR';
                            lv_chr_error_message   :=
                                'Error in validating role1 for customer';
                    END;

                    --
                    --
                    IF lv_update_role_flag = 'Y' AND lv_primary_flag = 'N'
                    THEN
                        BEGIN
                            -- Flush messages existing already
                            FND_MSG_PUB.Delete_Msg;

                            -- Initialize the values
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Updating the primary_flag to "Y"  for role1 ::'
                                || c_record.role1);

                            p_object_version_number                  :=
                                p_object_version_number;
                            p_role_responsibility_rec.responsibility_id   :=
                                ln_responsibility_id;
                            p_role_responsibility_rec.cust_account_role_id   :=
                                ln_cust_role_id;
                            p_role_responsibility_rec.responsibility_type   :=
                                lv_responsibility_type;
                            p_role_responsibility_rec.primary_flag   := 'Y';
                            p_role_responsibility_rec.created_by_module   :=
                                lv_created_by_module;

                            --Call API to update the primary flag for role 1
                            hz_cust_account_role_v2pub.update_role_responsibility (
                                'T',
                                p_role_responsibility_rec,
                                p_object_version_number,
                                lv_return_status,
                                ln_msg_count,
                                lv_msg_data);

                            BEGIN
                                IF (lv_return_status <> fnd_api.g_ret_sts_success)
                                THEN
                                    FOR i IN 1 .. fnd_msg_pub.count_msg
                                    LOOP
                                        lv_msg              :=
                                            fnd_msg_pub.get (
                                                p_msg_index   => i,
                                                p_encoded     =>
                                                    fnd_api.g_false);
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'The API call failed with error '
                                            || lv_msg);
                                        lv_chr_error_code   := 'ERROR';
                                        lv_chr_error_message   :=
                                               lv_chr_error_message
                                            || ';'
                                            || 'ERROR in update API';
                                    END LOOP;
                                ELSE
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'The API call status - SUCESSS');
                                    COMMIT;
                                    lv_chr_error_code   := 'SUCCESS';
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'ERROR in API Call for customer :'
                                        || c_record.account_number);
                            END;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Error in API ' || SQLERRM);
                                lv_chr_error_code      := 'ERROR';
                                lv_chr_error_message   := 'Error in API ';
                        END;
                    END IF;

                    IF (lv_update_role_flag = 'Y' AND lv_primary_flag = 'Y')
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Contact role exists with Primary flag "Y". No Action required.');
                    END IF;

                    --Code to create role if the role is not present
                    IF lv_update_role_flag = 'N'
                    THEN
                        BEGIN
                            ln_cust_role_id       := NULL;
                            lv_create_role_flag   := 'N';

                            --
                            --
                            BEGIN
                                SELECT hcar.cust_account_role_id, 'Y'
                                  INTO ln_cust_role_id, lv_create_role_flag
                                  FROM hz_cust_accounts_all hca, hz_cust_account_roles hcar, hz_relationships hzr,
                                       hz_org_contacts hzc, hz_parties hzp
                                 WHERE     hcar.cust_account_id =
                                           hca.cust_account_id(+)
                                       AND hcar.party_id = hzr.party_id(+)
                                       AND hca.party_id = hzr.object_id
                                       AND hzr.relationship_id =
                                           hzc.party_relationship_id(+)
                                       AND hzr.subject_id = hzp.party_id
                                       AND hca.account_number =
                                           c_record.account_number
                                       AND hzp.party_name =
                                           c_record.contact_name
                                       AND hca.status = 'A'
                                       AND hzp.status = 'A';
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'No contact exists for this customer '
                                        || SQLERRM);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Exit processing for this customer '
                                        || SQLERRM);
                                    lv_create_role_flag   := 'N';
                                    lv_chr_error_code     := 'ERROR';
                                    lv_chr_error_message   :=
                                        'No contact exists for this customer  ';
                            END;

                            --
                            --
                            -- Create role only if contact exists
                            IF lv_create_role_flag = 'Y'
                            THEN
                                BEGIN
                                    -- Flush messages existing already
                                    FND_MSG_PUB.Delete_Msg;

                                    p_role_responsibility_rec.cust_account_role_id   :=
                                        ln_cust_role_id;
                                    p_role_responsibility_rec.responsibility_type   :=
                                        lv_role_code;
                                    p_role_responsibility_rec.primary_flag   :=
                                        'Y';
                                    p_role_responsibility_rec.created_by_module   :=
                                        'TCA_V1_API';

                                    hz_cust_account_role_v2pub.create_role_responsibility (
                                        'T',
                                        p_role_responsibility_rec,
                                        x_responsibility_id,
                                        x_return_status,
                                        x_msg_count,
                                        x_msg_data);

                                    IF x_return_status = 'S'
                                    THEN
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'Contact role created successfully for role1 ::'
                                            || c_record.role1);
                                    END IF;

                                    COMMIT;

                                    IF x_msg_count > 1
                                    THEN
                                        FOR I IN 1 .. x_msg_count
                                        LOOP
                                            fnd_file.put_line (
                                                fnd_file.LOG,
                                                   I
                                                || '. '
                                                || SUBSTR (
                                                       FND_MSG_PUB.Get (
                                                           p_encoded   =>
                                                               FND_API.G_FALSE),
                                                       1,
                                                       255));
                                        END LOOP;
                                    END IF;
                                END;
                            ELSE
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'No Contacts exists for this customer '
                                    || SQLERRM);
                                lv_chr_error_code   := 'ERROR';
                                lv_chr_error_message   :=
                                    'No Contacts exists for this customer ';
                            END IF; --END OF IF FOR ROLE VERIFICATION AND CREATION
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Error in verifiying customer contact '
                                    || SQLERRM);
                                lv_chr_error_code   := 'ERROR';
                                lv_chr_error_message   :=
                                    'Error in verifiying customer contact  ';
                        END;
                    END IF;                     -- End of if for creating role
                --
                --
                END IF;                -- End of if condition for role1 update
            --
            --
            ELSE
                fnd_file.put_line (fnd_file.LOG, lv_chr_error_message);
            END IF;

            fnd_file.put_line (
                fnd_file.LOG,
                '------------------------------------------------------------------------------');

            --Update success and error record details
            IF lv_chr_error_code = 'ERROR'
            THEN
                --
                UPDATE xxdoar_customer_update_stg
                   SET status_flag = 'ERROR', error_description = lv_chr_error_message, last_update_date = SYSDATE,
                       last_updated_by = fnd_global.user_id
                 WHERE     request_id = g_request_id
                       AND account_number = c_record.account_number
                       AND contact_name = c_record.contact_name;
            --
            --
            ELSE
                UPDATE xxdoar_customer_update_stg
                   SET status_flag = 'SUCCESS', error_description = NULL, last_update_date = SYSDATE,
                       last_updated_by = fnd_global.user_id
                 WHERE     request_id = g_request_id
                       AND account_number = c_record.account_number
                       AND contact_name = c_record.contact_name;
            END IF;

            COMMIT;
        END LOOP;                                        -- End of cursor loop

        --
        --
        BEGIN
            SELECT COUNT (*)
              INTO lv_success_count
              FROM xxdoar_customer_update_stg
             WHERE status_flag = 'SUCCESS' AND request_id = g_request_id;

            fnd_file.put_line (
                fnd_file.LOG,
                'Count of records in SUCCESS ::' || lv_success_count);
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error in fetching count of SUCCESS records ::'
                    || SQLERRM);
        END;

        --
        --
        BEGIN
            SELECT COUNT (*)
              INTO lv_error_count
              FROM xxdoar_customer_update_stg
             WHERE status_flag = 'ERROR' AND request_id = g_request_id;

            fnd_file.put_line (
                fnd_file.LOG,
                'Count of records in ERROR ::' || lv_error_count);
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error in fetching count of ERROR records ::' || SQLERRM);
        END;

        --
        --
        fnd_file.put_line (fnd_file.LOG,
                           'Exiting xxdoar_update_contact_role procedure ');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Error in xxdoar_update_contact_role procedure :' || SQLERRM);
    END xxdoar_update_contact_role;

    --
    --
    -- Main procedure
    /*******************************************************************************
    -- Name:                MAIN
    -- Type:                PROCEDURE
    -- Description:         Main procedure to be called from concurrent program
    --                      to load/validate/update customer information
    *******************************************************************************/
    PROCEDURE main_proc (errbuf                   OUT NOCOPY VARCHAR2,
                         retcode                  OUT NOCOPY NUMBER,
                         p_data_file_name      IN            VARCHAR2,
                         p_control_file_name   IN            VARCHAR2,
                         p_process_type        IN            VARCHAR2)
    IS
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Inside main procedure...');
        g_request_id          := fnd_global.conc_request_id;
        g_data_file_name      := p_data_file_name;
        g_control_file_name   := p_control_file_name;
        g_process_type        := p_process_type;
        fnd_file.put_line (fnd_file.LOG, 'Data File : ' || g_data_file_name);
        fnd_file.put_line (fnd_file.LOG,
                           'Control File : ' || g_control_file_name);
        fnd_file.put_line (fnd_file.LOG, 'Process Type : ' || g_process_type);

        --
        --
        BEGIN
            UPDATE xxdoar_customer_update_stg
               SET request_id = g_request_id, creation_date = SYSDATE, created_by = fnd_global.user_id,
                   last_update_date = SYSDATE, last_updated_by = fnd_global.user_id
             WHERE request_id IS NULL AND STATUS_FLAG = 'NEW';

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error in updating request id :' || SQLERRM);
        END;

        --
        --
        IF p_process_type = 'Update Transmission Flag'
        THEN
            -- Call procedure to update transmission flag
            xxdoar_upd_transmission_flag;
        --
        --
        ELSIF p_process_type = 'Update Contact Role'
        THEN
            -- Call procedure to update contact role
            xxdoar_update_contact_role;
        --
        --
        END IF;

        --
        --
        fnd_file.put_line (fnd_file.LOG, 'Exiting main procedure...');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Error in main procedure :' || SQLERRM);
    END main_proc;
END XXDOAR_CUSTOMER_UPDATE_PKG;
/
