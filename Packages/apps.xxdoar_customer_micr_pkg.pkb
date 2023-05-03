--
-- XXDOAR_CUSTOMER_MICR_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:19 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOAR_CUSTOMER_MICR_PKG"
AS
    /*
    * Package to load MICR information to customer
    *
    *---------------------------------------------------------------*
    *Who                 Version  When            What              *
    *===============================================================*
    * Madhav Dhurjaty    v1.0     03/07/2016      Created           *
    * Infosys            V1.1     01/09/2016      ENHC0012518       *
    *                                                               *
    *---------------------------------------------------------------*
    */
    FUNCTION get_party_id (p_customer_id IN NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN NUMBER
    AS
        l_party_id   NUMBER;
    BEGIN
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'Getting Party ID ...');

        SELECT party_id
          INTO l_party_id
          FROM hz_cust_accounts hca
         WHERE 1 = 1 AND cust_account_id = p_customer_id;

        RETURN l_party_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg   := 'Error in get_party_id:' || SQLERRM || '. ';
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Error in get_party_id:' || SQLERRM);
            RETURN NULL;
    END get_party_id;


    FUNCTION invoice_exists (p_trx_number   IN     VARCHAR2,
                             p_org_id       IN     NUMBER,
                             --                            p_use_db_link   IN     VARCHAR2,
                             x_ret_msg         OUT VARCHAR2)
        RETURN BOOLEAN
    AS
        l_count   NUMBER;
    BEGIN
        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'Getting Invoice ID for trx:' || p_trx_number);

        IF p_trx_number IS NULL
        THEN
            x_ret_msg   := 'Invoice# is NULL. ';
            RETURN FALSE;
        END IF;

        SELECT COUNT (1)
          INTO l_count
          FROM apps.ra_customer_trx_all
         WHERE 1 = 1 AND trx_number = p_trx_number AND org_id = p_org_id;

        IF l_count = 1
        THEN
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   '1 trx found: '
                || p_trx_number
                || ' Org ID:'
                || TO_CHAR (p_org_id)
                || '. ');
            x_ret_msg   := NULL;
            RETURN TRUE;
        ELSIF l_count > 1
        THEN
            x_ret_msg   :=
                   'More than 1 trx found: '
                || p_trx_number
                || ' Org ID:'
                || TO_CHAR (p_org_id)
                || '. ';
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'More than 1 trx found: '
                || p_trx_number
                || ' Org ID:'
                || TO_CHAR (p_org_id));
            RETURN FALSE;
        ELSE
            --         IF NVL (p_use_db_link, 'N') = 'Y'
            --         THEN
            --            SELECT COUNT (1)
            --              INTO l_count
            --              FROM xxd_conv.ra_customer_trx_all@BT_READ_1206.US.ORACLE.COM
            --             WHERE     1 = 1
            --                   AND trx_number = p_trx_number
            --                   AND org_id = g_legacy_org_id;
            --
            --            IF l_count = 1
            --            THEN
            --               FND_FILE.PUT_LINE (
            --                  FND_FILE.LOG,
            --                     '1 Legacy trx found: '
            --                  || p_trx_number
            --                  || ' Org ID:'
            --                  || TO_CHAR (g_legacy_org_id)
            --                  || '. ');
            --
            --               x_ret_msg := NULL;
            --               RETURN TRUE;
            --            ELSIF l_count > 1
            --            THEN
            --               x_ret_msg :=
            --                     'More than 1 Legacy trx found: '
            --                  || p_trx_number
            --                  || ' Org ID:'
            --                  || TO_CHAR (g_legacy_org_id)
            --                  || '. ';
            --               FND_FILE.PUT_LINE (
            --                  FND_FILE.LOG,
            --                     'More than 1 Legacy trx found: '
            --                  || p_trx_number
            --                  || ' Org ID:'
            --                  || TO_CHAR (g_legacy_org_id));
            --               RETURN FALSE;
            --            ELSE*/
            --               x_ret_msg :=
            --                     'No Legacy trx found: '
            --                  || p_trx_number
            --                  || ' Org ID:'
            --                  || TO_CHAR (g_legacy_org_id)
            --                  || '. ';
            --               FND_FILE.PUT_LINE (
            --                  FND_FILE.LOG,
            --                     'No Legacy trx found: '
            --                  || p_trx_number
            --                  || ' Org ID:'
            --                  || TO_CHAR (g_legacy_org_id));
            --               RETURN FALSE;
            --            END IF;
            --         ELSE
            --            x_ret_msg :=
            --                  'No trx found: '
            --               || p_trx_number
            --               || ' Org ID:'
            --               || TO_CHAR (p_org_id)
            --               || '. ';
            --            FND_FILE.PUT_LINE (
            --               FND_FILE.LOG,
            --                  'No trx found: '
            --               || p_trx_number
            --               || ' Org ID:'
            --               || TO_CHAR (p_org_id));
            --            RETURN FALSE;
            --         END IF;
            ---
            x_ret_msg   :=
                   'No trx found: '
                || p_trx_number
                || ' Org ID:'
                || TO_CHAR (p_org_id)
                || '. ';
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'No trx found: '
                || p_trx_number
                || ' Org ID:'
                || TO_CHAR (p_org_id));
            RETURN FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   'Error checking trx: '
                || p_trx_number
                || ' Org ID:'
                || TO_CHAR (p_org_id)
                || ' - '
                || SQLERRM
                || '. ';
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'Error checking trx: '
                || p_trx_number
                || ' Org ID:'
                || TO_CHAR (p_org_id)
                || ' - '
                || SQLERRM);
            RETURN FALSE;
    END invoice_exists;

    FUNCTION get_cust_id (p_trx_number IN VARCHAR2, p_org_id IN NUMBER, --                         p_use_db_link    IN     VARCHAR2,
                                                                        x_customer_num OUT VARCHAR2
                          , x_ret_msg OUT VARCHAR2)
        RETURN NUMBER
    IS
        l_brand_cust_id        NUMBER;
        l_customer_id          NUMBER;
        l_customer_num         VARCHAR2 (30);
        l_parent_customer_id   NUMBER;
    BEGIN
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
               'Getting Customer ID for trx: '
            || p_trx_number
            || ' Org ID:'
            || TO_CHAR (p_org_id));

        BEGIN
            SELECT bill_to_customer_id, hca1.cust_account_id, hca1.account_number
              INTO l_brand_cust_id, l_parent_customer_id, l_customer_num
              FROM apps.ra_customer_trx_all rct, apps.hz_cust_accounts hca, apps.hz_cust_accounts hca1
             WHERE     1 = 1
                   AND rct.bill_to_customer_id = hca.cust_account_id
                   AND SUBSTR (hca.account_number,
                               1,
                               INSTR (hca.account_number, '-') - 1) =
                       hca1.account_number
                   AND rct.trx_number = p_trx_number
                   AND hca1.attribute1 IN
                           (SELECT flv.meaning
                              FROM apps.fnd_lookup_values flv
                             WHERE     lookup_type =
                                       'XXDOAR_LEGACY_CUST_BRAND'
                                   AND language = 'US'
                                   AND enabled_flag = 'Y'
                                   AND NVL (end_date_active, SYSDATE) >=
                                       SYSDATE)
                   AND rct.org_id = p_org_id;

            x_customer_num   := l_customer_num;
            RETURN l_parent_customer_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                /*IF NVL (p_use_db_link, 'N') = 'Y'
                THEN
                   BEGIN
                      SELECT hca1.cust_account_id, hca1.account_number
                        INTO l_parent_customer_id, l_customer_num
                        FROM xxd_conv.ra_customer_trx_all@BT_READ_1206.US.ORACLE.COM rct,
                             xxd_conv.hz_cust_accounts@BT_READ_1206.US.ORACLE.COM hca,
                             hz_cust_accounts hca1
                       WHERE     1 = 1
                             AND rct.bill_to_customer_id = hca.cust_account_id
                             AND hca.account_number = hca1.account_number
                             AND rct.trx_number = p_trx_number
                             AND rct.org_id = g_legacy_org_id;

                      x_customer_num := l_customer_num;
                      RETURN l_parent_customer_id;
                   EXCEPTION
                      WHEN OTHERS
                      THEN
                         x_ret_msg :=
                               'Cust ID: No data found for Legacy trx: '
                            || p_trx_number
                            || ' Org ID:'
                            || TO_CHAR (g_legacy_org_id)
                            || '. ';
                         FND_FILE.PUT_LINE (
                            FND_FILE.LOG,
                               'Cust ID: No data found for Legacy trx: '
                            || p_trx_number
                            || ' Org ID:'
                            || TO_CHAR (g_legacy_org_id));
                         RETURN NULL;
                   END;
                ELSE*/
                x_ret_msg   :=
                       'Cust ID: No data found for trx: '
                    || p_trx_number
                    || ' Org ID:'
                    || TO_CHAR (p_org_id)
                    || '. ';
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                       'Cust ID: No data found for trx: '
                    || p_trx_number
                    || ' Org ID:'
                    || TO_CHAR (p_org_id));
                RETURN NULL;
            --            END IF;
            WHEN OTHERS
            THEN
                x_ret_msg   :=
                       'Error getting Cust ID for trx: '
                    || p_trx_number
                    || ' Org ID:'
                    || TO_CHAR (p_org_id)
                    || '. ';
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                       'Error getting Cust ID for trx: '
                    || p_trx_number
                    || ' Org ID:'
                    || TO_CHAR (p_org_id)
                    || ' - '
                    || SQLERRM);
                RETURN NULL;
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   'Error getting Cust ID for trx: '
                || p_trx_number
                || ' Org ID:'
                || TO_CHAR (p_org_id)
                || '. ';
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'Error getting Cust ID for trx: '
                || p_trx_number
                || ' Org ID:'
                || TO_CHAR (p_org_id)
                || ' - '
                || SQLERRM);
            RETURN NULL;
    END get_cust_id;

    FUNCTION validate_bank_info (p_routing_num IN VARCHAR2, p_account_num IN VARCHAR2, x_bank_id OUT NUMBER
                                 , x_branch_id OUT NUMBER, x_account_id OUT NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_bank_id      NUMBER;
        l_branch_id    NUMBER;
        l_account_id   NUMBER;
    BEGIN
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'Inside validate_bank_info...');

        SELECT ext_bank_account_id, branch_party_id, bank_party_id
          INTO l_account_id, l_branch_id, l_bank_id
          FROM apps.iby_ext_bank_accounts_v
         WHERE     1 = 1
               AND branch_number = p_routing_num
               AND bank_account_number = p_account_num
               -- Added by Infosys on 01-SEP-2016 for ENHC0012518 to check active record
               AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                               NVL (start_date, SYSDATE - 1))
                                       AND TRUNC (
                                               NVL (end_date, SYSDATE + 1))
               AND ROWNUM = 1;

        x_bank_id      := l_bank_id;
        x_branch_id    := l_branch_id;
        x_account_id   := l_account_id;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg   := 'Error in validate_bank_info:' || SQLERRM;
            RETURN FALSE;
            NULL;
    END validate_bank_info;

    PROCEDURE load_staging (p_filename IN VARCHAR2, p_timestamp IN VARCHAR2, p_directory IN VARCHAR2
                            , x_ret_msg OUT VARCHAR2)
    AS
        l_timestamp   VARCHAR2 (14);
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
               'ALTER TABLE xxdoar_micr_upd_ext DEFAULT DIRECTORY '
            || '"'
            || p_directory
            || '"');

        --Set the directory where the file is located
        EXECUTE IMMEDIATE   'ALTER TABLE xxdoar_micr_upd_ext DEFAULT DIRECTORY '
                         || '"'
                         || p_directory
                         || '"';

        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
               'ALTER TABLE xxdoar_micr_upd_ext LOCATION ('''
            || p_filename
            || ''')');

        --Set the file name to be read by the ext table
        EXECUTE IMMEDIATE   'ALTER TABLE xxdoar_micr_upd_ext LOCATION ('''
                         || p_filename
                         || ''')';

        FND_FILE.PUT_LINE (FND_FILE.LOG, 'Loading Staging table...');
        l_timestamp   := p_timestamp;

        FND_FILE.PUT_LINE (FND_FILE.LOG, 'Process Timestamp:' || l_timestamp);

        INSERT INTO xxdoar_customer_micr_stg (batch_date,
                                              check_num,
                                              payor_name,
                                              payor_name_alt,
                                              payor_zip,
                                              invoice_num,
                                              routing_num,
                                              bank_acct_num,
                                              bank_name,
                                              bank_country,
                                              bank_currency,
                                              process_flag,
                                              process_timestamp,
                                              file_name,
                                              concurrent_request_id,
                                              creation_date,
                                              created_by,
                                              last_update_date,
                                              last_updated_by,
                                              directory_name)
            SELECT batch_date, LTRIM (RTRIM (check_num)), LTRIM (RTRIM (payor_name)),
                   LTRIM (RTRIM (payor_name_alt)), LTRIM (RTRIM (payor_zip)), LTRIM (RTRIM (invoice_num)),
                   LTRIM (RTRIM (routing_num)), LTRIM (RTRIM (REPLACE (bank_acct_num, CHR (13), NULL))), LTRIM (RTRIM (REPLACE (bank_name, CHR (13), NULL))),
                   LTRIM (RTRIM (bank_country)), LTRIM (RTRIM (bank_currency)), 'N',
                   l_timestamp, p_filename, g_conc_req_id,
                   SYSDATE, fnd_global.user_id, SYSDATE,
                   fnd_global.user_id, p_directory
              FROM xxdoar_micr_upd_ext;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            x_ret_msg   := 'Error in load_statging:' || SQLERRM || '. ';
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Error in load_statging:' || SQLERRM);
    END load_staging;

    PROCEDURE create_bank (p_bank_name IN VARCHAR2, p_bank_number IN VARCHAR2, p_country IN VARCHAR2
                           , x_bank_id OUT NUMBER, x_ret_msg OUT VARCHAR2)
    IS
        lc_output          VARCHAR2 (3000);
        lc_msg_dummy       VARCHAR2 (3000);
        lc_return_status   VARCHAR2 (3000);
        lc_msg_data        VARCHAR2 (3000);

        ln_bank_id         NUMBER;
        ln_msg_count       NUMBER;
        lr_extbank_rec     apps.iby_ext_bankacct_pub.extbank_rec_type;
        lr_response_rec    apps.iby_fndcpt_common_pub.result_rec_type;
        ex_bank_exists     EXCEPTION;
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'Inside create_bank...');
        lc_return_status              := NULL;
        ln_msg_count                  := NULL;
        lc_msg_data                   := NULL;

        lr_extbank_rec.bank_name      := p_bank_name;
        lr_extbank_rec.bank_number    := p_bank_number;
        lr_extbank_rec.country_code   := p_country;



        BEGIN
            SELECT bank_party_id
              INTO ln_bank_id
              FROM iby_ext_banks_v
             WHERE     1 = 1
                   AND UPPER (bank_name) =
                       UPPER (NVL (p_bank_name, g_default_bank_name))
                   AND home_country = p_country;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                NULL;
            WHEN OTHERS
            THEN
                FND_FILE.PUT_LINE (FND_FILE.LOG, SQLERRM);
        END;

        IF ln_bank_id IS NULL
        THEN
            apps.fnd_msg_pub.delete_msg (NULL);
            apps.fnd_msg_pub.initialize ();

            IBY_EXT_BANKACCT_PUB.create_ext_bank (
                -- ------------------------------
                -- Input data elements
                -- ------------------------------
                p_api_version     => 1.0,
                p_init_msg_list   => FND_API.G_TRUE,
                p_ext_bank_rec    => lr_extbank_rec,
                -- --------------------------------
                -- Output data elements
                -- --------------------------------
                x_bank_id         => ln_bank_id,
                x_return_status   => lc_return_status,
                x_msg_count       => ln_msg_count,
                x_msg_data        => lc_msg_data,
                x_response        => lr_response_rec);

            lc_output   := NULL;
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'Bank Result Code: '
                || lr_response_rec.Result_Code
                || ' Bank Result Category: '
                || lr_response_rec.Result_Category
                || ' Bank Result Message: '
                || lr_response_rec.Result_Message);

            IF (lc_return_status <> 'S')
            THEN
                FOR i IN 1 .. ln_msg_count
                LOOP
                    apps.fnd_msg_pub.get (i, apps.fnd_api.g_false, lc_msg_data
                                          , lc_msg_dummy);

                    lc_output   :=
                           lc_output
                        || (TO_CHAR (i) || ': ' || SUBSTR (lc_msg_data, 1, 250) || '. ');
                END LOOP;

                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                    'Error Creating Bank: ' || lc_output || '. ');
                x_ret_msg   :=
                    'Error Occured while Creating Bank: ' || lc_output;
            ELSE
                FND_FILE.PUT_LINE (FND_FILE.LOG,
                                   'New Bank ID: ' || ln_bank_id);
            END IF;

            COMMIT;
            x_bank_id   := ln_bank_id;
        ELSE
            x_bank_id   := ln_bank_id;
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Existing Bank ID: ' || ln_bank_id);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Error in create_bank:' || SQLERRM);
    END create_bank;

    PROCEDURE create_branch (p_bank_id IN NUMBER, p_branch_name IN VARCHAR2, p_branch_type IN VARCHAR2
                             , p_routing_number IN VARCHAR2, x_branch_id OUT NUMBER, x_ret_msg OUT VARCHAR2)
    IS
        p_api_version           NUMBER := 1.0;
        p_init_msg_list         VARCHAR2 (1) := 'F';
        x_return_status         VARCHAR2 (2000);
        x_msg_count             NUMBER (5);
        x_msg_data              VARCHAR2 (2000);
        p_count                 NUMBER;
        l_branch_id             NUMBER;
        PRAGMA AUTONOMOUS_TRANSACTION;

        p_ext_bank_branch_rec   iby_ext_bankacct_pub.extbankbranch_rec_type;
        x_response              iby_fndcpt_common_pub.result_rec_type;
    BEGIN
        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'Creating Bank Branch:' || p_branch_name);

        BEGIN
            SELECT branch_party_id
              INTO l_branch_id
              FROM apps.iby_ext_bank_branches_v
             WHERE     bank_party_id = p_bank_id
                   AND branch_number = p_routing_number;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                NULL;
            WHEN OTHERS
            THEN
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                    'Error Checking if the Bank Branch exists:' || SQLERRM);
        END;

        IF l_branch_id IS NULL
        THEN
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'branch_name: '
                || p_branch_name
                || ' Branch Type: '
                || p_branch_type
                || ' Bank ID: '
                || p_bank_id
                || 'Routing Num :'
                || p_routing_number);

            p_ext_bank_branch_rec.bch_object_version_number   := 1.0;
            p_ext_bank_branch_rec.branch_name                 :=
                p_branch_name;
            p_ext_bank_branch_rec.branch_type                 :=
                p_branch_type;
            p_ext_bank_branch_rec.bank_party_id               := p_bank_id;
            p_ext_bank_branch_rec.branch_number               :=
                p_routing_number;

            IBY_EXT_BANKACCT_PUB.CREATE_EXT_BANK_BRANCH (
                -- -----------------------------
                -- Input data elements
                -- -----------------------------
                p_api_version           => p_api_version,
                p_init_msg_list         => p_init_msg_list,
                p_ext_bank_branch_rec   => p_ext_bank_branch_rec,
                -- --------------------------------
                -- Output data elements
                -- --------------------------------
                x_branch_id             => x_branch_id,
                x_return_status         => x_return_status,
                x_msg_count             => x_msg_count,
                x_msg_data              => x_msg_data,
                x_response              => x_response);

            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'Branch Result Code: '
                || x_response.Result_Code
                || ' Branch Result Category: '
                || x_response.Result_Category
                || ' Branch Result Message: '
                || x_response.Result_Message
                || 'x_return_status :'
                || x_return_status);
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'New Bank Branch ID : ' || x_branch_id);

            IF x_return_status <> 'S'
            THEN
                IF (x_msg_count = 1)
                THEN
                    FND_FILE.PUT_LINE (FND_FILE.LOG,
                                       'x_msg_data ' || x_msg_data);
                    x_ret_msg   := x_msg_data || '. ';
                    x_ret_msg   := 'Error creating bank branch' || '. ';
                ELSIF (x_msg_count > 1)
                THEN
                    LOOP
                        p_count   := p_count + 1;
                        x_msg_data   :=
                            fnd_msg_pub.get (fnd_msg_pub.g_next,
                                             fnd_api.g_false);

                        IF (x_msg_data IS NULL)
                        THEN
                            EXIT;
                        END IF;

                        x_ret_msg   :=
                               x_ret_msg
                            || ' - '
                            || p_count
                            || ' - '
                            || x_msg_data
                            || '. ';

                        FND_FILE.PUT_LINE (
                            FND_FILE.LOG,
                               'Message '
                            || ' - '
                            || p_count
                            || ' - '
                            || x_msg_data);
                    END LOOP;
                END IF;

                x_branch_id   := NULL;
            ELSE
                FND_FILE.PUT_LINE (FND_FILE.LOG,
                                   'New Branch ID: ' || x_branch_id);
            END IF;

            COMMIT;
        ELSE
            x_branch_id   := l_branch_id;
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Existing Bank Branch ID : ' || x_branch_id);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            x_ret_msg   := 'Error in create_branch:' || SQLERRM || '. ';
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Error in create_branch:' || SQLERRM);
    END create_branch;

    PROCEDURE create_account (p_bank_id IN NUMBER, p_branch_id IN NUMBER, p_party_id IN NUMBER, p_account_number IN VARCHAR2, p_country IN VARCHAR2, p_currency IN VARCHAR2
                              , p_check_digits IN NUMBER, x_account_id OUT NUMBER, x_ret_msg OUT VARCHAR2)
    IS
        r_ext_bank_acct_rec       iby_ext_bankacct_pub.extbankacct_rec_type;
        x_acct_id                 NUMBER;
        l_party_id                NUMBER;
        v_account_exist           NUMBER;
        v_bank_party_id           NUMBER;
        v_branch_party_id         NUMBER;
        x_bank_branch_count       NUMBER;
        v_return_status_account   VARCHAR2 (100);
        x_msg_count               NUMBER;
        x_response_rec            iby_fndcpt_common_pub.result_rec_type;
        x_msg_data                VARCHAR2 (2000);
        x_error_message           VARCHAR2 (2000);
        l_account_id              NUMBER;
        PRAGMA AUTONOMOUS_TRANSACTION;
    --c_validate_vendor_site_rec is cursor type of cursor crated on site table
    BEGIN
        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'Creating Bank Account:' || p_account_number);

        BEGIN
            SELECT ext_bank_account_id
              INTO l_account_id
              FROM apps.iby_ext_bank_accounts_v
             WHERE     1 = 1
                   AND bank_account_number = p_account_number
                   AND bank_party_id = p_bank_id
                   AND branch_party_id = p_branch_id
                   AND country_code = p_country
                   -- Added by Infosys on 01-SEP-2016 for ENHC0012518 to check active record
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (start_date,
                                                        SYSDATE - 1))
                                           AND TRUNC (
                                                   NVL (end_date,
                                                        SYSDATE + 1));
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                NULL;
            WHEN OTHERS
            THEN
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                    'Error Checking if the Bank Account exists:' || SQLERRM);
        END;

        IF l_account_id IS NULL
        THEN
            r_ext_bank_acct_rec.bank_account_id                := NULL;
            r_ext_bank_acct_rec.country_code                   := p_country;
            r_ext_bank_acct_rec.branch_id                      := p_branch_id;
            r_ext_bank_acct_rec.bank_id                        := p_bank_id;
            r_ext_bank_acct_rec.acct_owner_party_id            := p_party_id;
            r_ext_bank_acct_rec.bank_account_name              := NULL;
            r_ext_bank_acct_rec.bank_account_num               := p_account_number;
            r_ext_bank_acct_rec.currency                       := p_currency;
            r_ext_bank_acct_rec.iban                           := NULL;
            r_ext_bank_acct_rec.check_digits                   := p_check_digits;
            r_ext_bank_acct_rec.multi_currency_allowed_flag    := NULL;
            r_ext_bank_acct_rec.alternate_acct_name            := NULL;
            r_ext_bank_acct_rec.short_acct_name                := NULL;
            r_ext_bank_acct_rec.acct_type                      := NULL;
            r_ext_bank_acct_rec.acct_suffix                    := NULL;
            r_ext_bank_acct_rec.description                    := NULL;
            r_ext_bank_acct_rec.agency_location_code           := NULL;
            r_ext_bank_acct_rec.foreign_payment_use_flag       := NULL;
            r_ext_bank_acct_rec.exchange_rate_agreement_num    := NULL;
            r_ext_bank_acct_rec.exchange_rate_agreement_type   := NULL;
            r_ext_bank_acct_rec.exchange_rate                  := NULL;
            r_ext_bank_acct_rec.payment_factor_flag            := NULL;
            r_ext_bank_acct_rec.status                         := NULL;
            r_ext_bank_acct_rec.end_date                       := NULL;
            r_ext_bank_acct_rec.start_date                     :=
                TO_DATE ('01-JAN-1952', 'DD-MON-YYYY');             --SYSDATE;
            r_ext_bank_acct_rec.hedging_contract_reference     := NULL;
            r_ext_bank_acct_rec.attribute_category             := NULL;
            r_ext_bank_acct_rec.attribute1                     := NULL;
            r_ext_bank_acct_rec.attribute3                     := NULL;
            r_ext_bank_acct_rec.attribute4                     := NULL;
            r_ext_bank_acct_rec.attribute5                     := NULL;
            r_ext_bank_acct_rec.attribute6                     := NULL;
            r_ext_bank_acct_rec.attribute7                     := NULL;
            r_ext_bank_acct_rec.attribute8                     := NULL;
            r_ext_bank_acct_rec.attribute9                     := NULL;
            r_ext_bank_acct_rec.attribute10                    := NULL;
            r_ext_bank_acct_rec.attribute11                    := NULL;
            r_ext_bank_acct_rec.attribute12                    := NULL;
            r_ext_bank_acct_rec.attribute13                    := NULL;
            r_ext_bank_acct_rec.attribute14                    := NULL;
            r_ext_bank_acct_rec.object_version_number          := 1.0;

            iby_ext_bankacct_pub.create_ext_bank_acct (
                p_api_version         => 1.0,
                p_init_msg_list       => fnd_api.g_false,
                p_ext_bank_acct_rec   => r_ext_bank_acct_rec,
                x_acct_id             => x_account_id,
                x_return_status       => v_return_status_account,
                x_msg_count           => x_msg_count,
                x_msg_data            => x_msg_data,
                x_response            => x_response_rec); /* For Bank Account Creation */

            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'Account Result Code: '
                || x_response_rec.Result_Code
                || ' Account Result Category: '
                || x_response_rec.Result_Category
                || ' Account Result Message: '
                || x_response_rec.Result_Message);

            IF v_return_status_account <> 'S'
            THEN
                --error
                --print error message or use x_msg_data
                x_error_message   :=
                    fnd_msg_pub.get_detail (x_msg_count, 'F');

                FND_FILE.PUT_LINE (FND_FILE.LOG,
                                   'x_error_message:' || x_error_message);

                FOR i IN x_msg_count .. 1
                LOOP
                    fnd_msg_pub.delete_msg (i);
                END LOOP;

                x_ret_msg   :=
                    'Error creating bank account:' || x_error_message || '. ';
            ELSE
                FND_FILE.PUT_LINE (FND_FILE.LOG,
                                   'New Bank Account ID:' || x_account_id);
                NULL;
            --success
            END IF;

            COMMIT;
        ELSE
            x_account_id   := l_account_id;
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Existing Bank Account ID:' || x_account_id);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Error in create_account:' || SQLERRM);
            x_ret_msg   := 'Error in create_account:' || SQLERRM || '. ';
    END create_account;

    PROCEDURE set_payer_assignment (p_party_id IN NUMBER, p_pmt_function IN VARCHAR2, p_org_type IN VARCHAR2, p_org_id IN NUMBER DEFAULT NULL, p_account_id IN NUMBER, p_cust_account_id IN NUMBER
                                    , p_acct_site_id IN NUMBER, x_assign_id OUT NUMBER, x_ret_msg OUT VARCHAR2)
    IS
        lr_payer                IBY_FNDCPT_COMMON_PUB.PayerContext_rec_type;
        lr_assignment_attribs   IBY_FNDCPT_SETUP_PUB.PmtInstrAssignment_rec_type;
        lr_instrument           IBY_FNDCPT_SETUP_PUB.PmtInstrument_rec_type;
        x_response              IBY_FNDCPT_COMMON_PUB.Result_rec_type;
        l_assign_id             NUMBER;
        x_return_status         VARCHAR2 (2000);
        x_msg_count             NUMBER (5);
        x_msg_data              VARCHAR2 (2000);
        x_branch_id             NUMBER;
        lc_output               VARCHAR2 (2000);
        lc_msg_dummy            VARCHAR2 (3000);
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_assignment_id         NUMBER;
        l_priority              NUMBER := 0;

        l_cust_account_id       hz_cust_accounts_all.cust_account_id%TYPE; -- Added by Infosys on 01-SEP-2016 for ENHC0012518
        l_cust_account_number   hz_cust_accounts_all.account_number%TYPE; -- Added by Infosys on 01-SEP-2016 for ENHC0012518
        l_bank_account_number   iby_fndcpt_payer_assgn_instr_v.account_number%TYPE; -- Added by Infosys on 01-SEP-2016 for ENHC0012518
    BEGIN
        l_assignment_id         := NULL; -- Added by Infosys on 01-SEP-2016 for ENHC0012518
        l_cust_account_id       := NULL; -- Added by Infosys on 01-SEP-2016 for ENHC0012518
        l_cust_account_number   := NULL; -- Added by Infosys on 01-SEP-2016 for ENHC0012518
        l_bank_account_number   := NULL; -- Added by Infosys on 01-SEP-2016 for ENHC0012518

        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'Checking if Bank Account Assignment exists...');

        BEGIN
            -- Commented by Infosys on 01-SEP-2016 for ENHC0012518
            /* SELECT instr_assignment_id
               INTO l_assignment_id
               FROM iby_fndcpt_payer_assgn_instr_v
              WHERE     1 = 1
                    AND payment_function = g_default_pmt_function --'CUSTOMER_PAYMENT'
                    AND instrument_type = g_default_instr_type
                    AND cust_account_id = p_cust_account_id
                    AND instrument_id = p_account_id
                    AND party_id = p_party_id;*/

            -- Added by Infosys on 01-SEP-2016 for ENHC0012518
            /* Check if the bank account is assigned to any customer account */
            SELECT instr_assignment_id, cust_account_id, account_number
              INTO l_assignment_id, l_cust_account_id, l_bank_account_number
              FROM iby_fndcpt_payer_assgn_instr_v
             WHERE     TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (
                                                       assignment_start_date,
                                                       SYSDATE - 1))
                                           AND TRUNC (
                                                   NVL (assignment_end_date,
                                                        SYSDATE + 1))
                   AND payment_function = g_default_pmt_function --'CUSTOMER_PAYMENT'
                   AND instrument_type = g_default_instr_type
                   AND instrument_id = p_account_id;

            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'MICR Assignment already exists...');
        EXCEPTION
            WHEN TOO_MANY_ROWS
            THEN
                BEGIN
                    /* Code to check if bank account is already existing for more than one customer account */
                    /* To handle existing duplicates before fix for ENHC0012518 */
                    SELECT instr_assignment_id, cust_account_id, account_number
                      INTO l_assignment_id, l_cust_account_id, l_bank_account_number
                      FROM iby_fndcpt_payer_assgn_instr_v
                     WHERE     TRUNC (SYSDATE) BETWEEN TRUNC (
                                                           NVL (
                                                               assignment_start_date,
                                                               SYSDATE - 1))
                                                   AND TRUNC (
                                                           NVL (
                                                               assignment_end_date,
                                                               SYSDATE + 1))
                           AND payment_function = g_default_pmt_function --'CUSTOMER_PAYMENT'
                           AND instrument_type = g_default_instr_type
                           AND instrument_id = p_account_id
                           AND ROWNUM = 1;

                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                        'MICR Assignment already exists for more than one customer...');
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                        'Details for one customer is listed...');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        FND_FILE.PUT_LINE (
                            FND_FILE.LOG,
                               'Error Checking if Bank Account Assignment already exists: '
                            || SQLERRM);
                END;
            WHEN NO_DATA_FOUND
            THEN
                NULL;
            WHEN OTHERS
            THEN
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                       'Error Checking if the Bank Account Assignment exists: '
                    || SQLERRM);
        END;

        IF l_assignment_id IS NULL AND l_cust_account_id IS NULL -- Added l_cust_account_id condition by Infosys on 01-SEP-2016 for ENHC0012518
        THEN
            BEGIN
                SELECT MAX (order_of_preference)
                  INTO l_priority
                  FROM iby_fndcpt_payer_assgn_instr_v
                 WHERE     1 = 1
                       AND payment_function = g_default_pmt_function --'CUSTOMER_PAYMENT'
                       AND instrument_type = g_default_instr_type
                       AND cust_account_id = p_cust_account_id
                       AND party_id = p_party_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_priority   := 0;
            END;


            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'p_pmt_function:'
                || p_pmt_function
                || ' p_party_id:'
                || p_party_id
                || ' p_cust_account_id:'
                || p_cust_account_id
                || ' Instrument_id:'
                || p_account_id);

            lr_payer.Payment_Function          := p_pmt_function;
            lr_payer.Party_Id                  := p_party_id;
            lr_payer.Org_Type                  := NULL;
            lr_payer.Org_Id                    := NULL;
            lr_payer.Cust_Account_Id           := p_cust_account_id;
            lr_payer.Account_Site_Id           := NULL;

            lr_instrument.Instrument_Type      := g_default_instr_type;
            lr_instrument.Instrument_Id        := p_account_id;

            lr_assignment_attribs.Instrument   := lr_instrument;
            lr_assignment_attribs.Priority     := l_priority + 1;
            lr_assignment_attribs.Start_Date   :=
                TO_DATE ('01-JAN-1952', 'DD-MON-YYYY');             --SYSDATE;
            lr_assignment_attribs.End_Date     := NULL;

            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Creating Bank Account Assignment');

            IBY_FNDCPT_SETUP_PUB.Set_Payer_Instr_Assignment (
                p_api_version          => 1.0,
                x_return_status        => x_return_status,
                x_msg_count            => x_msg_count,
                x_msg_data             => x_msg_data,
                p_payer                => lr_payer,
                p_assignment_attribs   => lr_assignment_attribs,
                x_assign_id            => x_assign_id,
                x_response             => x_response);
            lc_output                          := NULL;

            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'Assignment Result Code: '
                || x_response.Result_Code
                || ' Assignment Result Category: '
                || x_response.Result_Category
                || ' Assignment Result Message: '
                || x_response.Result_Message);

            IF (X_return_status <> 'S')
            THEN
                FOR i IN 1 .. x_msg_count
                LOOP
                    apps.fnd_msg_pub.get (i, apps.fnd_api.g_false, X_msg_data
                                          , lc_msg_dummy);

                    lc_output   :=
                           lc_output
                        || (TO_CHAR (i) || ': ' || SUBSTR (X_msg_data, 1, 250));
                END LOOP;

                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                    'Error Occured while Creating assignment: ' || lc_output);
                x_ret_msg   :=
                       'Error Occured while Creating assignment: '
                    || lc_output
                    || '. ';
            ELSE
                FND_FILE.PUT_LINE (FND_FILE.LOG,
                                   'New Assignment ID: ' || x_assign_id);
            END IF;

            COMMIT;
        ELSE
            -- Start: Added by Infosys on 01-SEP-2016 for ENHC0012518
            -- Fetch the customer account number for the bank account number
            BEGIN
                SELECT hca.account_number
                  INTO l_cust_account_number
                  FROM hz_cust_accounts_all hca
                 WHERE     hca.status = 'A'
                       AND hca.cust_account_id = l_cust_account_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_cust_account_number   := NULL;
            END;

            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'Bank Account Number: '
                || l_bank_account_number
                || ' already associated with customer account number: '
                || l_cust_account_number);
            -- End: Added by Infosys on 01-SEP-2016 for ENHC0012518

            x_assign_id   := l_assignment_id;
            x_ret_msg     := 'DUPLICATE';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Error in set_payer_assignment:' || SQLERRM);
            x_ret_msg   :=
                'Error in set_payer_assignment:' || SQLERRM || '. ';
    END set_payer_assignment;

    PROCEDURE print_stats (p_filename    IN     VARCHAR2,
                           p_timestamp   IN     VARCHAR2,
                           x_ret_msg        OUT VARCHAR2)
    AS
        l_total_count         NUMBER;
        l_unprocessed_count   NUMBER;
        l_processed_count     NUMBER;
        l_error_count         NUMBER;
        l_duplicate_count     NUMBER;

        CURSOR C1 IS
            SELECT *
              FROM xxdoar_customer_micr_stg
             WHERE     process_timestamp = p_timestamp
                   AND NVL (process_flag, 'N') IN ('E', 'D');
    BEGIN
        DBMS_OUTPUT.put_line ('Printing File Stats...');

        SELECT COUNT (1)
          INTO l_total_count
          FROM xxdoar_customer_micr_stg
         WHERE process_timestamp = p_timestamp;

        SELECT COUNT (1)
          INTO l_unprocessed_count
          FROM xxdoar_customer_micr_stg
         WHERE     process_timestamp = p_timestamp
               AND NVL (process_flag, 'N') = 'N';

        SELECT COUNT (1)
          INTO l_processed_count
          FROM xxdoar_customer_micr_stg
         WHERE     process_timestamp = p_timestamp
               AND NVL (process_flag, 'N') = 'P';

        SELECT COUNT (1)
          INTO l_duplicate_count
          FROM xxdoar_customer_micr_stg
         WHERE     process_timestamp = p_timestamp
               AND NVL (process_flag, 'N') = 'D';

        SELECT COUNT (1)
          INTO l_error_count
          FROM xxdoar_customer_micr_stg
         WHERE     process_timestamp = p_timestamp
               AND NVL (process_flag, 'N') = 'E';


        FND_FILE.PUT_LINE (
            FND_FILE.OUTPUT,
            '--------------------------------------------------------------------------------');
        FND_FILE.PUT_LINE (FND_FILE.OUTPUT,
                           'File Name                      :' || p_filename);
        FND_FILE.PUT_LINE (FND_FILE.OUTPUT,
                           'Process Timestamp              :' || p_timestamp);
        FND_FILE.PUT_LINE (
            FND_FILE.OUTPUT,
            'Total Record Count             :' || TO_CHAR (l_total_count));
        FND_FILE.PUT_LINE (
            FND_FILE.OUTPUT,
            'Total Processed Record Count   :' || TO_CHAR (l_processed_count));
        FND_FILE.PUT_LINE (
            FND_FILE.OUTPUT,
            'Total Error Record Count       :' || TO_CHAR (l_error_count));
        FND_FILE.PUT_LINE (
            FND_FILE.OUTPUT,
            'Total Duplicate Record Count   :' || TO_CHAR (l_duplicate_count));
        FND_FILE.PUT_LINE (
            FND_FILE.OUTPUT,
               'Total UnProcessed Record Count :'
            || TO_CHAR (l_unprocessed_count));
        FND_FILE.PUT_LINE (
            FND_FILE.OUTPUT,
            '--------------------------------------------------------------------------------');
        FND_FILE.PUT_LINE (
            FND_FILE.OUTPUT,
            '                                Error Records                                   ');
        FND_FILE.PUT_LINE (
            FND_FILE.OUTPUT,
            '================================================================================');

        FND_FILE.PUT_LINE (
            FND_FILE.OUTPUT,
            'Customer#      Invoice#  Routing#       Bank Account#       Status Remarks      ');

        FOR i IN C1
        LOOP
            FND_FILE.PUT_LINE (
                FND_FILE.OUTPUT,
                   SUBSTR (RPAD (NVL (i.customer_number, '*'), 15, ' '),
                           1,
                           15)
                || SUBSTR (RPAD (NVL (i.invoice_num, '*'), 9, ' '), 1, 9)
                || ' '
                || SUBSTR (RPAD (NVL (i.routing_num, '*'), 14, ' '), 1, 14)
                || ' '
                || SUBSTR (
                       RPAD (
                           REPLACE (NVL (i.bank_acct_num, '*'), CHR (13), ''),
                           19,
                           ' '),
                       1,
                       19)
                || ' '
                || i.process_flag
                || '      '
                || SUBSTR (i.error_message, 1, 80));
        END LOOP;

        FND_FILE.PUT_LINE (
            FND_FILE.OUTPUT,
            '--------------------------------------------------------------------------------');
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg   := 'Error in print_stats :' || SQLERRM;
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Error in print_stats :' || SQLERRM);
    END print_stats;

    PROCEDURE main (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_directory IN VARCHAR2
                    , p_filename IN VARCHAR2, p_reprocess IN VARCHAR2      --,
                                                                     --p_use_db_link   IN     VARCHAR2
                                                                     )
    AS
        l_ret_msg       VARCHAR2 (4000);
        l_msg           VARCHAR2 (4000);
        l_org_id        NUMBER := 2;
        l_exists        BOOLEAN;
        l_flag          VARCHAR2 (1);
        x_no_invoice    EXCEPTION;
        x_no_customer   EXCEPTION;
        l_timestamp     VARCHAR2 (16);
        l_filename      VARCHAR2 (360) := p_filename;
        l_directory     VARCHAR2 (360) := p_directory;
        l_customer_id   NUMBER;
        l_bank_id       NUMBER;
        l_branch_id     NUMBER;
        l_account_id    NUMBER;
        l_assign_id     NUMBER;
        l_party_id      NUMBER;
        l_cust_num      VARCHAR2 (30);
        l_bank_info     BOOLEAN;

        CURSOR c1 (p_time_stamp VARCHAR2)
        IS
                SELECT *
                  FROM xxdoar_customer_micr_stg
                 WHERE     NVL (process_flag, 'Y') IN ('N', 'E')
                       AND DECODE (p_reprocess, 'Y', 'XyZ', process_timestamp) =
                           DECODE (p_reprocess, 'Y', 'XyZ', p_time_stamp)
            FOR UPDATE NOWAIT;
    BEGIN
        l_timestamp   := TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS');

        FND_FILE.PUT_LINE (FND_FILE.LOG, 'Inside Main...');

        --Load staging table from external table
        load_staging (p_filename => l_filename, p_timestamp => l_timestamp, p_directory => l_directory
                      , x_ret_msg => l_msg);
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'Inside Main : After Load_staging');

        FOR i IN c1 (l_timestamp)
        LOOP
            l_ret_msg       := NULL;
            l_exists        := NULL;
            l_msg           := NULL;
            l_customer_id   := NULL;
            l_flag          := 'P';
            l_bank_id       := NULL;
            l_branch_id     := NULL;
            l_account_id    := NULL;
            l_assign_id     := NULL;
            l_party_id      := NULL;
            l_cust_num      := NULL;
            l_bank_info     := NULL;

            FND_FILE.PUT_LINE (FND_FILE.LOG, '.............................');

            BEGIN
                --Check if invoice number exists
                l_exists    :=
                    invoice_exists (i.invoice_num, g_org_id, --                               p_use_db_link,
                                                             l_ret_msg);
                l_msg       := l_msg || l_ret_msg;
                l_ret_msg   := NULL;

                IF l_exists = FALSE
                THEN
                    l_flag   := 'E';
                END IF;

                IF l_flag = 'P'
                THEN
                    --Get Customer ID associated with the invoice
                    l_customer_id   :=
                        get_cust_id (p_trx_number => i.invoice_num, p_org_id => g_org_id, --                               p_use_db_link    => p_use_db_link,
                                                                                          x_customer_num => l_cust_num
                                     , x_ret_msg => l_ret_msg);
                    l_msg        := l_msg || l_ret_msg;
                    l_ret_msg    := NULL;

                    IF l_customer_id IS NULL
                    THEN
                        l_flag   := 'E';
                    END IF;

                    --Get Customer Party ID
                    l_party_id   :=
                        get_party_id (p_customer_id   => l_customer_id,
                                      x_ret_msg       => l_ret_msg);
                    l_msg        := l_msg || ' ' || l_ret_msg;
                    l_ret_msg    := NULL;

                    IF l_party_id IS NULL
                    THEN
                        l_flag   := 'E';
                    END IF;

                    l_bank_info   :=
                        validate_bank_info (
                            p_routing_num   => i.routing_num,
                            p_account_num   => i.bank_acct_num,
                            x_bank_id       => l_bank_id,
                            x_branch_id     => l_branch_id,
                            x_account_id    => l_account_id,
                            x_ret_msg       => l_ret_msg);

                    FND_FILE.PUT_LINE (FND_FILE.LOG,
                                       'Validate Bank Info:' || l_ret_msg);

                    l_ret_msg    := NULL;

                    IF l_bank_info = FALSE
                    THEN
                        --Create Bank
                        create_bank (
                            p_bank_name     =>
                                NVL (i.bank_name, g_default_bank_name),
                            p_bank_number   => NULL,
                            p_country       =>
                                NVL (i.bank_country, g_default_bank_country),
                            x_bank_id       => l_bank_id,
                            x_ret_msg       => l_ret_msg);

                        l_msg       := l_msg || l_ret_msg;
                        l_ret_msg   := NULL;

                        IF l_bank_id IS NULL
                        THEN
                            l_flag   := 'E';
                        END IF;

                        --Create Bank Branch
                        create_branch (
                            p_bank_id          => l_bank_id,
                            p_branch_name      =>
                                   NVL (i.bank_name, g_default_bank_name)
                                || ' - '
                                || i.routing_num,
                            p_branch_type      => g_default_branch_type,
                            p_routing_number   => i.routing_num,
                            x_branch_id        => l_branch_id,
                            x_ret_msg          => l_ret_msg);

                        l_msg       := l_msg || l_ret_msg;
                        l_ret_msg   := NULL;

                        IF l_branch_id IS NULL
                        THEN
                            l_flag   := 'E';
                        ELSE
                            --Create Bank account
                            create_account (
                                p_bank_id          => l_bank_id,
                                p_branch_id        => l_branch_id,
                                p_party_id         => l_party_id,
                                p_account_number   => i.bank_acct_num,
                                p_country          =>
                                    NVL (i.bank_country,
                                         g_default_bank_country),
                                p_currency         =>
                                    NVL (i.bank_currency,
                                         g_default_bank_currency),
                                p_check_digits     => NULL,
                                x_account_id       => l_account_id,
                                x_ret_msg          => l_ret_msg);

                            l_msg       := l_msg || l_ret_msg;
                            l_ret_msg   := NULL;

                            IF l_account_id IS NULL
                            THEN
                                l_flag   := 'E';
                            END IF;

                            FND_FILE.PUT_LINE (
                                FND_FILE.LOG,
                                'Account ID :' || l_account_id);
                            --Assign bank account to the customer
                            set_payer_assignment (
                                p_party_id          => l_party_id,
                                p_pmt_function      => g_default_pmt_function,
                                p_org_type          => NULL,
                                p_org_id            => NULL,
                                p_account_id        => l_account_id,
                                p_cust_account_id   => l_customer_id,
                                p_acct_site_id      => NULL,
                                x_assign_id         => l_assign_id,
                                x_ret_msg           => l_ret_msg);

                            IF l_assign_id IS NULL
                            THEN
                                l_flag   := 'E';
                            ELSIF     l_assign_id IS NOT NULL
                                  AND l_ret_msg = 'DUPLICATE'
                            THEN
                                l_flag   := 'D';
                                FND_FILE.PUT_LINE (
                                    FND_FILE.LOG,
                                       ' Existing Assignment ID: '
                                    || l_assign_id
                                    || ','
                                    || 'For customer#: '
                                    || i.customer_number
                                    || ','
                                    || 'For Bank Account#: '
                                    || i.bank_acct_num); --Added by Infosys on 01-SEP-2016 for ENHC0012518
                            END IF;

                            l_msg       := l_msg || l_ret_msg;

                            l_ret_msg   := NULL;
                        END IF;
                    ELSE
                        FND_FILE.PUT_LINE (
                            FND_FILE.LOG,
                               'Bank Account information is available with details -'
                            || ' Bank ID : '
                            || l_bank_id
                            || ' Branch ID : '
                            || l_branch_id
                            || ' Account ID :'
                            || l_account_id); --Added by Infosys on 01-SEP-2016 for ENHC0012518

                        -- Added by Infosys on 01-SEP-2016 for ENHC0012518
                        FND_FILE.PUT_LINE (
                            FND_FILE.LOG,
                            'Calling set_payer_assignment for existing bank account');

                        set_payer_assignment (
                            p_party_id          => l_party_id,
                            p_pmt_function      => g_default_pmt_function,
                            p_org_type          => NULL,
                            p_org_id            => NULL,
                            p_account_id        => l_account_id,
                            p_cust_account_id   => l_customer_id,
                            p_acct_site_id      => NULL,
                            x_assign_id         => l_assign_id,
                            x_ret_msg           => l_ret_msg);


                        IF l_assign_id IS NULL
                        THEN
                            l_flag   := 'E';
                        ELSIF     l_assign_id IS NOT NULL
                              AND l_ret_msg = 'DUPLICATE'
                        THEN
                            l_flag   := 'D';
                            FND_FILE.PUT_LINE (
                                FND_FILE.LOG,
                                   ' Existing Assignment ID: '
                                || l_assign_id
                                || ','
                                || 'For customer#:'
                                || i.customer_number
                                || ','
                                || 'For Bank Account#:'
                                || i.bank_acct_num); --Added by Infosys on 01-SEP-2016 for ENHC0012518
                        END IF;

                        l_msg       := l_msg || l_ret_msg;

                        l_ret_msg   := NULL;
                    END IF;
                END IF;

                --Update staging table with the flag and error message
                UPDATE xxdoar_customer_micr_stg
                   SET process_flag = l_flag, error_message = SUBSTR (l_msg, 1, 4000), last_update_date = SYSDATE,
                       last_updated_by = FND_GLOBAL.USER_ID, process_timestamp = l_timestamp, customer_number = l_cust_num
                 WHERE CURRENT OF C1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_msg   := l_msg || SQLERRM;

                    UPDATE xxdoar_customer_micr_stg
                       SET process_flag = 'E', error_message = SUBSTR (l_msg, 1, 4000), last_update_date = SYSDATE,
                           last_updated_by = FND_GLOBAL.USER_ID, process_timestamp = l_timestamp, customer_number = l_cust_num
                     WHERE CURRENT OF C1;
            END;
        END LOOP;

        COMMIT;

        print_stats (p_filename    => p_filename,
                     p_timestamp   => l_timestamp,
                     x_ret_msg     => l_ret_msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            retcode   := '2';
            errbuf    := 'Unexpected error in main:' || SQLERRM;
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Unexpected error in main:' || SQLERRM);
            NULL;
    END main;
END xxdoar_customer_micr_pkg;
/
