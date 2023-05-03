--
-- XXDOAR_CREDIT_INB_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:20 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOAR_CREDIT_INB_PKG"
IS
    /***********************************************************************************************************
       file name    : xxdoar_credit_inb_pkg.pkb
       created on   : 11-FEB-2015
       created by   : Infosys
       purpose      : package body used for the following

                      1. to record the credit review

     ***********************************************************************************************************
      Modification history:
     ***********************************************************************************************************
         NAME:        xxdoar_credit_inb_pkg
         PURPOSE:

         REVISIONS:
         Version        Date        Author           Description
         ---------  ----------  ---------------  -------------------------------
         1.0         02/11/2015    Infosys        Initial Version.
         1.1         04/10/2015    Infosys        Updated credit rating logic
         1.2         04/13/2015    Infosys        Validate analyst
         1.3         04/21/2015    Infosys        Modified to fix the QC Defect ID 903.
         1.4         04/22/2015    Infosys        Changed the date format.
                              Removed SAVEPOINT reference to avoid invalid savepoint issue.
         1.5         05/26/2015    Infosys        Modified for Changing Review Type as per UAT Configuration.
         1.6         05/28/2015    Infosys        Modified for populating credit analyst id. Defect 1647
         1.7         06/04/2015    Infosys        Modified for QC defect 2137
         1.8         06/05/2015    Infosys        Modified for QC defect 2169
         1.9         06/17/2015    Infosys        Modified for QC defect 2565
        1.10         04/15/2016    Infosys        Automatic Review - Assigned Credit Line is to be Populated
                                                  IDENTIFIED By ASSIGNED_CREDIT_LINE
    ************************************************************************************************************
    ************************************************************************************************************/
    gv_package_name        VARCHAR2 (200) := 'xxdoar_credit_inb_pkg';
    gv_currproc            VARCHAR2 (1000) := NULL;
    gv_sqlstat             VARCHAR2 (2000) := NULL;
    gv_reterror            VARCHAR2 (2000) := NULL;
    gn_userid              NUMBER := apps.fnd_global.user_id;
    gn_resp_id             NUMBER := apps.fnd_global.resp_id;
    gn_app_id              NUMBER := apps.fnd_global.prog_appl_id;
    gv_retcode             VARCHAR2 (2000) := NULL;
    l_buffer_number        NUMBER;
    l_dbname               VARCHAR2 (240);
    g_case_folder_number   VARCHAR2 (240);

    PROCEDURE write_to_table (msg VARCHAR2, app VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO custom.do_debug (created_by, application_id, debug_text,
                                     session_id, call_stack)
                 VALUES (NVL (fnd_global.user_id, -1),
                         app,
                         msg,
                         USERENV ('SESSIONID'),
                         SUBSTR (DBMS_UTILITY.format_call_stack, 1, 2000));

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END;

    /* PROCEDURE msg (pv_msg VARCHAR2, pn_level NUMBER := 1000)
     IS
     BEGIN
        apps.fnd_file.put_line (apps.fnd_file.LOG, pv_msg);
        do_debug_tools.msg (pv_msg, pn_level);
     EXCEPTION
        WHEN OTHERS
        THEN
           fnd_file.put_line (fnd_file.LOG,
                                   'Error In msg procedure' || SQLERRM);
     END; */
    -- Commented for 1.7

    /****************************************************************************************
     * Procedure/Function Name  :  Create_Credit_Review
     *
     * Description              :  The purpose of this procedure to record the credit review
     * INPUT Parameters : pv_customername
     *                    pn_customernumber
     *                    pn_creditscore
     *                 pn_assignedcreditline
     *                    pn_calculatedcreditline
     *                    pn_confidencelevel
     *                    pn_PQI
     *                    pn_intelliscore
     *                    pn_yearsinbusiness
     *                    pv_nsf
     *                    pv_altercode
     *                    pv_manualreview
     *
     * OUTPUT Parameters: pv_retcode
     *                    pv_reterror
     *
     * DEVELOPMENT and MAINTENANCE HISTORY
     *
     * date          author             Version  Description
     * ------------  -----------------  -------  ------------------------------
     * 2/11/2015     INFOSYS            1.0.1    Initial Version
     *************************************************************************/
    PROCEDURE create_credit_review (pv_retcode OUT NUMBER, pv_reterror OUT VARCHAR2, pv_customername VARCHAR2, pn_customernumber VARCHAR2, pn_creditscore NUMBER, pn_assignedcreditline NUMBER, pn_calculatedcreditline NUMBER, pn_confidencelevel NUMBER, pn_pqi NUMBER, pn_intelliscore NUMBER, pn_yearsinbusiness NUMBER, pv_nsf VARCHAR2, pv_altercode VARCHAR2, pv_manualreview VARCHAR2, pv_ownershipchagne NUMBER DEFAULT NULL, pv_rescorereason VARCHAR2 DEFAULT NULL, pv_scorename VARCHAR2 DEFAULT NULL, pd_scoredate DATE DEFAULT NULL, pv_agencyaccountid VARCHAR2 DEFAULT NULL, pv_accountid VARCHAR2 DEFAULT NULL, pv_companyid VARCHAR2 DEFAULT NULL
                                    , pv_scoreid VARCHAR2 DEFAULT NULL, pd_reviewdate DATE DEFAULT NULL, pv_agent VARCHAR2) --VARCHAR2 DEFAULT NULL)
    IS
        /*****************************
           declaring variables
           ****************************/
        lv_pn              VARCHAR2 (240) := gv_package_name || '.Create_Credit_Review';
        ln_requestid       NUMBER := 0;
        lv_phasecode       VARCHAR2 (100) := NULL;
        lv_statuscode      VARCHAR2 (100) := NULL;
        lv_devphase        VARCHAR2 (100) := NULL;
        lv_devstatus       VARCHAR2 (100) := NULL;
        lv_returnmsg       VARCHAR2 (200) := NULL;
        lv_dev_phase       VARCHAR2 (50);
        lv_dev_status      VARCHAR2 (50);
        lv_status          VARCHAR2 (50);
        lv_phase           VARCHAR2 (50);
        lv_message         VARCHAR2 (240);
        lv_return_status   VARCHAR2 (2000);
        lv_message_data    VARCHAR2 (2000);
        econcreqsuberr     EXCEPTION;
    BEGIN
        -- msg (' pv_customername ' || pv_customername, 1); -- Commented for 1.7
        write_to_table ('Customer Name', pv_customername);

        IF pv_agent IS NOT NULL
        THEN
            credit_handler (
                p_customer_name            => pv_customername,
                p_customer_number          => pn_customernumber,
                p_credit_score             => pn_creditscore,
                p_scoredate                => pd_scoredate,
                p_assigned_credit_line     => pn_assignedcreditline,
                p_calculated_credit_line   => pn_calculatedcreditline,
                p_confidence_level         => pn_confidencelevel,
                p_payment_quality_index    => pn_pqi,
                p_intelliscore             => pn_intelliscore,
                p_years_in_business        => pn_yearsinbusiness,
                p_manual_review_flag       => pv_manualreview,
                p_nsf_c2b                  => pv_nsf,
                p_alert_code               => pv_altercode,
                p_ownershipchange          => pv_ownershipchagne,
                p_review_date              => pd_reviewdate,
                p_agent                    => pv_agent,
                x_return_status            => lv_return_status,
                x_message_data             => lv_message_data);
        ELSIF pv_agent IS NULL
        THEN
            lv_message_data   :=
                'Agent Name is Mandatory field for processing Credit Request.';
        END IF;

        pv_reterror   := NVL (lv_message_data, 'SUCCESS');

        IF lv_message_data <> 'SUCCESS'
        THEN
            pv_retcode   := 1;
        ELSE
            pv_retcode   := 0;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode   := SQLCODE;
            pv_reterror   :=
                   'Unexpected Error in Create Credit Review Procedure :: '
                || SQLERRM;
            write_to_table (
                   'Error in Create Credit Review Procedure Customer '
                || pv_customername,
                SQLERRM);
    /* msg (
           ' ERROR in procedure '
        || lv_pn
        || ' : '
        || pv_retcode
        || pv_reterror,
        1); */
    -- Commented for 1.7
    END create_credit_review;

    PROCEDURE create_credit_request (p_customer_name VARCHAR2, p_customer_number VARCHAR2, -- 1.7
                                                                                           p_manual_review VARCHAR2, p_agent VARCHAR2, x_credit_request_id OUT NUMBER, p_assigned_credit_line IN NUMBER, x_party_id OUT NUMBER, x_return_status IN OUT VARCHAR2, x_message_count OUT NUMBER
                                     , x_message_data OUT VARCHAR2)
    IS
        l_credit_check_rule_id      NUMBER;
        l_count                     NUMBER;
        l_cust_acct_id              NUMBER;
        lv_pn                       VARCHAR2 (240)
            := gv_package_name || '.create_credit_request';
        l_new_customer              VARCHAR2 (1);
        l_credit_request_id         ar_cmgt_credit_requests.credit_request_id%TYPE;
        l_review_type               ar_cmgt_credit_requests.review_type%TYPE;
        l_party_id                  hz_parties.party_id%TYPE;
        l_credit_analyst_id         NUMBER;
        l_cust_account_profile_id   hz_customer_profiles.cust_account_profile_id%TYPE;
        l_row_id                    ROWID := NULL;
        l_requester_id              NUMBER;
        l_save                      VARCHAR2 (30) := NULL;
        l_check_list_id             NUMBER;
        l_score_model_id            NUMBER;
    BEGIN
        /* msg (
               ' Inside  create_credit_request '
            || ' p_customer_name : '
            || p_customer_name,
            1); */
        -- Commented for 1.7
        write_to_table (
            'Inside create_credit_request Procedure for Customer',
            p_customer_name);

        SELECT hp.party_id
          INTO l_party_id
          FROM hz_parties hp
         --  WHERE hp.party_name = p_customer_name -- Commented for 1.9
         WHERE party_number = p_customer_number -- Added 1.7 -- Modified for 1.9
                                                AND address1 IS NOT NULL;

        SELECT COUNT (*)
          INTO l_count
          FROM hz_parties hp, hz_cust_accounts hca, oe_order_headers_all oeh
         WHERE     hp.party_id = hca.party_id
               AND hca.cust_account_id = oeh.sold_to_org_id
               AND hp.party_number = p_customer_number;    -- Modified for 1.9

        --AND hp.party_name = p_customer_name;-- Commented for 1.9

        IF l_count = 0
        THEN
            l_new_customer   := 'Y';
        ELSE
            l_new_customer   := 'N';
        END IF;

        IF l_new_customer = 'Y'
        THEN
            IF UPPER (p_manual_review) = 'YES'
            THEN
                l_review_type   := 'US_NEW_CUSTOMER_MANUAL'; --'NEW_CUSTOMER_MANUAL'; 1.5
                l_save          := 'CREATED';
            ELSE
                l_review_type   := 'US_NEW_CUSTOMER_AUTO'; --'NEW_CUSTOMER_AUTO';  1.5
                l_save          := NULL;
            END IF;
        ELSE
            IF UPPER (p_manual_review) = 'YES'
            THEN
                l_review_type   := 'US_RENEWAL_MANUAL'; --'RENEWAL_MANUAL';  1.5
                l_save          := 'CREATED';
            ELSE
                l_review_type   := 'US_RENEWAL_AUTO';   --'RENEWAL_AUTO';  1.5
                l_save          := NULL;
            END IF;
        END IF;

        BEGIN
            SELECT score_model_id
              INTO l_score_model_id
              FROM ar_cmgt_scores
             WHERE NAME = fnd_profile.VALUE ('DO_SCORE_MODEL');
        EXCEPTION
            WHEN OTHERS
            THEN
                l_score_model_id   := NULL;
                /* msg ('Error in Fetching Score Model Id :: ' || SQLERRM, 1); */
                                                          -- Commented for 1.7
                write_to_table (
                    'Error in Fetching Score Model Id for US Scoring Model',
                    SQLERRM);
        END;

        --added for defect #965 and 968 start
        BEGIN
            SELECT SOURCE_ID
              INTO l_requester_id
              FROM jtf_rs_resource_extns
             -- WHERE source_name = p_agent; --W.r.t Version 1.8
             WHERE     UPPER (SOURCE_FIRST_NAME || ' ' || SOURCE_LAST_NAME) =
                       UPPER (p_agent)                     --W.r.t Version 1.8
                   AND SYSDATE BETWEEN NVL (START_DATE_ACTIVE, SYSDATE)
                                   AND NVL (END_DATE_ACTIVE, SYSDATE); -- Added for INC0349657
        EXCEPTION
            WHEN OTHERS
            THEN
                x_message_data   :=
                    'Error in Fetching Employee Id for Agent :: ' || SQLERRM;
                /* msg ('Error Found in fetching source Id :: ' || SQLERRM, 1);*/
                                                          -- Commented for 1.7
                write_to_table ('Error in Fetching Employee Id for Agent',
                                p_agent || ' ; ' || SQLERRM);
        END;

        --added for defect #965 and 968 end

        --commented for defect# 965 and 968 start
        --    begin
        --      SELECT employee_id
        --        INTO l_requester_id
        --        FROM fnd_user
        --       WHERE user_name =  'SYSADMIN';                              --gn_userid;
        --       end;
        --commented for defect# 965 and 968 end

        /* msg (' Inside  create_credit_request ', 1); */
                                                          -- Commented for 1.7
        ar_cmgt_credit_request_api.create_credit_request (p_api_version => 1, p_init_msg_list => fnd_api.g_true, p_commit => fnd_api.g_true, p_validation_level => fnd_api.g_valid_level_full, x_return_status => x_return_status, x_msg_count => x_message_count, x_msg_data => x_message_data, p_application_number => NULL, p_application_date => SYSDATE, p_requestor_type => 'EMPLOYEE', p_requestor_id => l_requester_id, p_review_type => l_review_type, p_credit_classification => 'ALL_CREDIT_CLASS_US', p_requested_amount => NULL, p_requested_currency => 'USD', p_trx_amount => p_assigned_credit_line, p_trx_currency => 'USD', p_credit_type => 'TRADE', p_term_length => NULL, p_credit_check_rule_id => NULL, p_credit_request_status => 'SAVE', p_party_id => l_party_id, p_cust_account_id => NULL, p_cust_acct_site_id => NULL, p_site_use_id => NULL, p_contact_party_id => NULL, p_notes => NULL, p_source_org_id => fnd_global.org_id, p_source_user_id => fnd_global.user_id, p_source_resp_id => fnd_global.resp_id, p_source_appln_id => 222, p_source_security_group_id => NULL, p_source_name => NULL, p_source_column1 => NULL, p_source_column2 => NULL, p_source_column3 => NULL, p_credit_request_id => l_credit_request_id, p_review_cycle => NULL, p_case_folder_number => NULL, p_score_model_id => NULL, p_parent_credit_request_id => NULL, p_credit_request_type => NULL
                                                          , p_reco => NULL);

        IF x_return_status != g_ret_success
        THEN
            write_to_table ('Create Credit Request API Error',
                            x_return_status || ' :: ' || x_message_data);
        /*         msg (
                       'ar_cmgt_credit_Request_api.create_credit_request returned ('
                    || x_return_status
                    || ')',
                    1);
                 msg (x_message_data, 1); */
        -- Commented for 1.7
        ELSE
            x_credit_request_id   := l_credit_request_id;
            x_party_id            := l_party_id;
        END IF;

        write_to_table ('Credit Request Id Created', l_credit_request_id);

        IF l_credit_request_id > 0
        THEN
            -- Commented Start for 1.7
            BEGIN
                SELECT cust_account_profile_id
                  INTO l_cust_account_profile_id
                  FROM hz_customer_profiles
                 WHERE     party_id = l_party_id
                       AND cust_account_id = -1
                       AND site_use_id IS NULL;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    --msg ('Party Profile Not found', 1);
                    ar_cmgt_hz_cover_api.create_party_profile (
                        p_party_id        => l_party_id,
                        p_return_status   => x_return_status);

                    IF x_return_status <> fnd_api.g_ret_sts_success
                    THEN
                        --                 msg ('TCA API failed to create party profile', 1);
                        write_to_table (
                            'TCA API failed to create customer profile at party level',
                            SQLERRM);
                    --RAISE;
                    ELSE
                        --                msg ('TCA API created party profile successfully', 1);
                        write_to_table (
                            'TCA API created party profile successfully',
                            NULL);
                    END IF;
                WHEN OTHERS
                THEN
                    --               msg ('Error while checking Party Profile' || SQLERRM, 1);
                    write_to_table (
                        'Error while checking Customer Profile at Party level ',
                        SQLERRM);
            --RAISE;
            END;

            -- Commented End for 1.7

            l_check_list_id   := NULL;

            BEGIN
                SELECT check_list_id
                  INTO l_check_list_id
                  FROM ar_cmgt_check_lists
                 WHERE     review_type = l_review_type
                       AND credit_classification = 'ALL_CREDIT_CLASS_US'
                       AND SYSDATE BETWEEN start_date
                                       AND NVL (end_date, SYSDATE + 1);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    /*  msg ('No Data Found in fetching Check list', 1); */
                                                          -- Commented for 1.7
                    write_to_table ('No Data Found in fetching Check list',
                                    NULL);
                WHEN OTHERS
                THEN
                    /*  msg ('Error Found in fetching Check list :: ' || SQLERRM, 1); */
                                                          -- Commented for 1.7
                    write_to_table ('Error Found in fetching Check list',
                                    SQLERRM);
            END;

            BEGIN
                SELECT resource_id
                  INTO l_credit_analyst_id
                  FROM jtf_rs_resource_extns
                 --WHERE source_name = p_agent; --W.r.t Version 1.8
                 WHERE     UPPER (
                               SOURCE_FIRST_NAME || ' ' || SOURCE_LAST_NAME) =
                           UPPER (p_agent)                 --W.r.t Version 1.8
                       AND SYSDATE BETWEEN NVL (START_DATE_ACTIVE, SYSDATE)
                                       AND NVL (END_DATE_ACTIVE, SYSDATE); -- Added for INC0349657
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_credit_analyst_id   := NULL;
                    /*  msg ('Error Found in fetching Credit Analyst Id :: ' || SQLERRM, 1); */
                                                          -- Commented for 1.7
                    write_to_table (
                        'Error Found in fetching Credit Analyst Id',
                        SQLERRM);
            END;

            UPDATE ar_cmgt_credit_requests
               SET check_list_id = l_check_list_id, credit_analyst_id = l_credit_analyst_id
             WHERE credit_request_id = l_credit_request_id;

            /* msg ('Rows Updated 1 :: ' || SQL%ROWCOUNT, 1); */
                                                          -- Commented for 1.7

            COMMIT;
        --ELSE
        --   msg ('No party-level profile required', 1);  -- Commented 1.7
        END IF;


        BEGIN
            SELECT ROWID
              INTO l_row_id
              FROM hz_customer_profiles
             WHERE party_id = l_party_id AND cust_account_id = -1;
        EXCEPTION
            WHEN OTHERS
            THEN
                write_to_table (
                    'Error in Fetching Customer Profile at Party Level',
                    SQLERRM);
        END;

        BEGIN
            hz_customer_profiles_pkg.update_row (
                x_rowid                          => l_row_id,
                x_cust_account_profile_id        => NULL,
                x_cust_account_id                => NULL,
                x_status                         => NULL,
                x_collector_id                   => NULL,
                x_credit_analyst_id              => l_credit_analyst_id,
                x_credit_checking                => NULL,
                x_next_credit_review_date        => NULL,
                x_tolerance                      => NULL,
                x_discount_terms                 => NULL,
                x_dunning_letters                => NULL,
                x_interest_charges               => NULL,
                x_send_statements                => NULL,
                x_credit_balance_statements      => NULL,
                x_credit_hold                    => NULL,
                x_profile_class_id               => NULL,
                x_site_use_id                    => NULL,
                x_credit_rating                  => NULL,
                x_risk_code                      => NULL,
                x_standard_terms                 => NULL,
                x_override_terms                 => NULL,
                x_dunning_letter_set_id          => NULL,
                x_interest_period_days           => NULL,
                x_payment_grace_days             => NULL,
                x_discount_grace_days            => NULL,
                x_statement_cycle_id             => NULL,
                x_account_status                 => NULL,
                x_percent_collectable            => NULL,
                x_autocash_hierarchy_id          => NULL,
                x_attribute_category             => NULL,
                x_attribute1                     => NULL,
                x_attribute2                     => NULL,
                x_attribute3                     => NULL,
                x_attribute4                     => NULL,
                x_attribute5                     => NULL,
                x_attribute6                     => NULL,
                x_attribute7                     => NULL,
                x_attribute8                     => NULL,
                x_attribute9                     => NULL,
                x_attribute10                    => NULL,
                x_attribute11                    => NULL,
                x_attribute12                    => NULL,
                x_attribute13                    => NULL,
                x_attribute14                    => NULL,
                x_attribute15                    => NULL,
                x_auto_rec_incl_disputed_flag    => NULL,
                x_tax_printing_option            => NULL,
                x_charge_on_finance_charge_fg    => NULL,
                x_grouping_rule_id               => NULL,
                x_clearing_days                  => NULL,
                x_jgzz_attribute_category        => NULL,
                x_jgzz_attribute1                => NULL,
                x_jgzz_attribute2                => NULL,
                x_jgzz_attribute3                => NULL,
                x_jgzz_attribute4                => NULL,
                x_jgzz_attribute5                => NULL,
                x_jgzz_attribute6                => NULL,
                x_jgzz_attribute7                => NULL,
                x_jgzz_attribute8                => NULL,
                x_jgzz_attribute9                => NULL,
                x_jgzz_attribute10               => NULL,
                x_jgzz_attribute11               => NULL,
                x_jgzz_attribute12               => NULL,
                x_jgzz_attribute13               => NULL,
                x_jgzz_attribute14               => NULL,
                x_jgzz_attribute15               => NULL,
                x_global_attribute1              => NULL,
                x_global_attribute2              => NULL,
                x_global_attribute3              => NULL,
                x_global_attribute4              => NULL,
                x_global_attribute5              => NULL,
                x_global_attribute6              => NULL,
                x_global_attribute7              => NULL,
                x_global_attribute8              => NULL,
                x_global_attribute9              => NULL,
                x_global_attribute10             => NULL,
                x_global_attribute11             => NULL,
                x_global_attribute12             => NULL,
                x_global_attribute13             => NULL,
                x_global_attribute14             => NULL,
                x_global_attribute15             => NULL,
                x_global_attribute16             => NULL,
                x_global_attribute17             => NULL,
                x_global_attribute18             => NULL,
                x_global_attribute19             => NULL,
                x_global_attribute20             => NULL,
                x_global_attribute_category      => NULL,
                x_cons_inv_flag                  => NULL,
                x_cons_inv_type                  => NULL,
                x_autocash_hierarchy_id_adr      => NULL,
                x_lockbox_matching_option        => NULL,
                x_object_version_number          => NULL,
                x_created_by_module              => NULL,
                x_application_id                 => NULL,
                x_review_cycle                   => NULL,
                x_last_credit_review_date        => NULL,
                x_party_id                       => l_party_id,
                x_credit_classification          => NULL,
                x_cons_bill_level                => NULL,
                x_late_charge_calculation_trx    => NULL,
                x_credit_items_flag              => NULL,
                x_disputed_transactions_flag     => NULL,
                x_late_charge_type               => NULL,
                x_late_charge_term_id            => NULL,
                x_interest_calculation_period    => NULL,
                x_hold_charged_invoices_flag     => NULL,
                x_message_text_id                => NULL,
                x_multiple_interest_rates_flag   => NULL,
                x_charge_begin_date              => NULL,
                x_automatch_set_id               => NULL);

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                write_to_table (
                    'Error in Updating Customer Profile with Credit Analyst Id at Party Level',
                    SQLERRM);
        END;

        --write_to_table ('Update Customer Profile (-1) with Credit Analyst Id',l_credit_request_id);

        x_message_data   := NVL (x_message_data, 'SUCCESS');
    --write_to_table ('Error in Create Credit Request', x_message_data); -- 1.7
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_status   := g_ret_unexp_error;
            x_message_data    :=
                   'Unexpected Error in Create Credit Request Procedure :: '
                || SQLERRM;
            write_to_table ('Error in Create Credit Request Procedure',
                            x_message_data);
    /* msg (
          ' ERROR in procedure '
       || lv_pn
       || ' : '
       || x_return_status
       || x_message_data,
       1); */
    -- Commented for 1.7
    END create_credit_request;

    PROCEDURE populate_case_folder (p_party_id IN NUMBER, p_credit_request_id IN NUMBER, x_case_folder_id OUT NUMBER, x_data_folder_id OUT NUMBER, x_return_status OUT VARCHAR2, x_message_count OUT NUMBER
                                    , x_message_data OUT VARCHAR2)
    IS
        l_case_folder_id          NUMBER := NULL;
        l_case_folder_number      VARCHAR2 (240);
        l_resultout               NUMBER := 0;
        l_check_list_id           ar_cmgt_check_lists.check_list_id%TYPE;
        l_score_model_id          NUMBER := NULL;
        l_cnt                     NUMBER := 0;
        l_review_type             ar_cmgt_credit_requests.review_type%TYPE;
        l_credit_classification   ar_cmgt_credit_requests.credit_classification%TYPE;
        l_cust_account_id         ar_cmgt_credit_requests.cust_account_id%TYPE;
        l_cust_acct_site_id       ar_cmgt_credit_requests.cust_acct_site_id%TYPE;
        l_site_use_id             ar_cmgt_credit_requests.site_use_id%TYPE;
        l_trx_currency            ar_cmgt_credit_requests.trx_currency%TYPE;
        l_cust_acct_id            NUMBER;
        lv_pn                     VARCHAR2 (240)
            := gv_package_name || '.populate_case_folder';
        l_data_folder_id          ar_cmgt_case_folders.case_folder_id%TYPE
                                      := NULL;

        CURSOR get_check_list_c (p_review_type             IN VARCHAR2,
                                 p_credit_classification   IN VARCHAR2)
        IS
            SELECT check_list_id
              FROM ar_cmgt_check_lists
             WHERE     review_type = p_review_type
                   AND credit_classification = p_credit_classification
                   AND SYSDATE BETWEEN start_date
                                   AND NVL (end_date, SYSDATE + 1);
    BEGIN
        x_return_status    := g_ret_success;

        /* msg (' Inside  populate_case_folder ', 1); */
                                                          -- Commented for 1.7

        BEGIN
            SELECT review_type, credit_classification, trx_currency,
                   cust_account_id, cust_acct_site_id, site_use_id
              INTO l_review_type, l_credit_classification, l_trx_currency, l_cust_account_id,
                                l_cust_acct_site_id, l_site_use_id
              FROM ar_cmgt_credit_requests
             WHERE credit_request_id = p_credit_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_review_type             := NULL;
                l_credit_classification   := NULL;
                l_trx_currency            := NULL;
                write_to_table ('Error in Fetching Credit Request Details',
                                SQLERRM);
        END;

        SELECT ar_cmgt_case_folder_number_s.NEXTVAL
          INTO l_case_folder_number
          FROM DUAL;

        BEGIN
            SELECT score_model_id
              INTO l_score_model_id
              FROM ar_cmgt_scores
             WHERE NAME = fnd_profile.VALUE ('DO_SCORE_MODEL');
        EXCEPTION
            WHEN OTHERS
            THEN
                l_score_model_id   := NULL;
                write_to_table ('Error in Fetcing Score Model Id', SQLERRM);
        END;

        OPEN get_check_list_c (l_review_type, l_credit_classification);

        FETCH get_check_list_c INTO l_check_list_id;

        CLOSE get_check_list_c;

        l_case_folder_id   := NULL;

        BEGIN
            SELECT case_folder_id
              INTO l_case_folder_id
              FROM ar_cmgt_case_folders
             WHERE     party_id = p_party_id
                   AND cust_account_id = l_cust_account_id
                   AND site_use_id = l_site_use_id
                   AND credit_request_id = p_credit_request_id
                   AND TYPE = 'CASE';

            IF l_case_folder_id IS NOT NULL
            THEN
                UPDATE ar_cmgt_case_folders
                   SET case_folder_number = l_case_folder_number, check_list_id = l_check_list_id, score_model_id = l_score_model_id,
                       limit_currency = l_trx_currency, exchange_rate_type = NULL, credit_classification = l_credit_classification,
                       last_update_date = SYSDATE, last_updated_by = fnd_global.user_id, last_update_login = fnd_global.login_id,
                       last_updated = SYSDATE, credit_request_id = p_credit_request_id
                 WHERE     party_id = p_party_id
                       AND cust_account_id = l_cust_account_id
                       AND site_use_id = l_site_use_id
                       AND TYPE = 'CASE'
                       AND credit_request_id = p_credit_request_id;

                --msg ('Number of Rows Updated for Case :: ' || SQL%ROWCOUNT, 1);
                COMMIT;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                BEGIN
                    SELECT ar_cmgt_case_folders_s.NEXTVAL
                      INTO l_case_folder_id
                      FROM DUAL;

                    x_case_folder_id   := l_case_folder_id;
                    ar_cmgt_controls.populate_case_folder (
                        p_case_folder_id          => l_case_folder_id,
                        p_case_folder_number      => l_case_folder_number,
                        p_credit_request_id       => p_credit_request_id,
                        p_check_list_id           => l_check_list_id,
                        p_status                  => NULL,
                        p_party_id                => p_party_id,
                        p_cust_account_id         => -99,
                        p_cust_acct_site_id       => -99,
                        p_score_model_id          => l_score_model_id, --NULL, -- 1.7
                        p_credit_classification   => l_credit_classification,
                        p_review_type             => l_review_type,
                        p_limit_currency          => l_trx_currency,
                        p_exchange_rate_type      => NULL,
                        p_type                    => 'CASE',
                        p_errmsg                  => x_message_data,
                        p_resultout               => l_resultout);

                    IF l_resultout <> 0
                    THEN
                        write_to_table (
                            'Error in Creating Case Folder (CASE)',
                            x_message_data);
                    --RETURN; -- 1.7
                    END IF;
                END;
            WHEN OTHERS
            THEN
                write_to_table (
                    'Unexpected Error occured in Creating Case Folder (CASE)',
                    SQLERRM);
                x_message_data   := SQLERRM;
                /*   msg (
                         'Unable to create case folder CASE records for'
                      || 'party id '
                      || TO_CHAR (p_party_id)
                      || ' Cust Account Id '
                      || TO_CHAR (l_cust_account_id)
                      || ' Cust Account Site Use Id '
                      || TO_CHAR (l_cust_acct_site_id)
                      || 'Sql Error '
                      || SQLERRM,
                      1); */
                -- Commented for 1.7
                l_resultout      := '1';
        END;

        x_case_folder_id   := l_case_folder_id;

        /*BEGIN
           SELECT case_folder_id
             INTO l_data_folder_id
             FROM ar_cmgt_case_folders
            WHERE     party_id = p_party_id
                  AND cust_account_id = l_cust_account_id
                  AND site_use_id = l_site_use_id
                  AND credit_request_id = p_credit_request_id
                  AND TYPE = 'DATA';

           IF l_data_folder_id IS NOT NULL
           THEN
              UPDATE ar_cmgt_case_folders
                 SET case_folder_number = l_case_folder_number,
                     check_list_id = l_check_list_id,
                     score_model_id = l_score_model_id,
                     limit_currency = l_trx_currency,
                     exchange_rate_type = NULL,
                     credit_classification = l_credit_classification,
                     last_update_date = SYSDATE,
                     last_updated_by = fnd_global.user_id,
                     last_update_login = fnd_global.login_id,
                     last_updated = SYSDATE,
                     credit_request_id = p_credit_request_id
               WHERE     party_id = p_party_id
                     AND cust_account_id = l_cust_account_id
                     AND site_use_id = l_site_use_id
                     AND TYPE = 'DATA'
                     AND credit_request_id = p_credit_request_id;

              msg ('Number of Rows Updated for DATA :: ' || SQL%ROWCOUNT, 1);
           END IF;
        EXCEPTION
           WHEN NO_DATA_FOUND
           THEN
              BEGIN
                 SELECT ar_cmgt_case_folders_s.NEXTVAL
                   INTO l_data_folder_id
                   FROM DUAL;

                 ar_cmgt_controls.populate_case_folder (
                    p_case_folder_id          => l_data_folder_id,
                    p_case_folder_number      => l_case_folder_number,
                    p_credit_request_id       => p_credit_request_id,
                    p_check_list_id           => l_check_list_id,
                    p_status                  => NULL,
                    p_party_id                => p_party_id,
                    p_cust_account_id         => -99,
                    p_cust_acct_site_id       => -99,
                    p_score_model_id          => NULL,
                    p_credit_classification   => l_credit_classification,
                    p_review_type             => l_review_type,
                    p_limit_currency          => l_trx_currency,
                    p_exchange_rate_type      => NULL,
                    p_type                    => 'DATA',
                    p_errmsg                  => x_message_data,
                    p_resultout               => l_resultout);

                 IF l_resultout <> 0
                 THEN
                    write_to_table('Error in Creating Case Folder (DATA)',x_message_data);
                    RETURN;
                 END IF;
              END;
           WHEN OTHERS
           THEN
              write_to_table('Error in Creating Case Folder (DATA)',SQLERRM);
              msg (
                    'Unable to create case folder DATA records for'
                 || 'party id '
                 || TO_CHAR (p_party_id)
                 || ' Cust Account Id '
                 || TO_CHAR (l_cust_account_id)
                 || ' Cust Account Site Use Id '
                 || TO_CHAR (l_cust_acct_site_id)
                 || 'Sql Error '
                 || SQLERRM,
                 1);
              l_resultout := '1';
        END;

        x_data_folder_id := l_data_folder_id;

        UPDATE ar_cmgt_case_folders
           SET status = 'SUBMITTED'
         WHERE case_folder_id = l_case_folder_id;

        COMMIT;*/

        IF l_resultout != 0
        THEN
            write_to_table ('Case Folder Returned', x_message_data);
            /*         msg (
                           'ar_cmgt_controls.populate_case_folder returned ('
                        || l_resultout
                        || ')',
                        1);
                     msg (x_message_data, 1); */
            -- Commented for 1.7
            x_return_status   := g_ret_error;
        END IF;

        x_message_data     := NVL (x_message_data, 'SUCCESS');
        write_to_table ('Error in Populate Case Folder', x_message_data);
    EXCEPTION
        WHEN OTHERS
        THEN
            write_to_table ('Error in Populate Case Folder Procedure',
                            SQLERRM);
            x_return_status   := g_ret_unexp_error;
            x_message_data    :=
                   'Unexpected Error in Populate Case Folder Procedure :: '
                || SQLERRM;
    /*   msg (
             ' ERROR in procedure '
          || lv_pn
          || ' : '
          || x_return_status
          || x_message_data,
          1); */
    -- Commented for 1.7
    END populate_case_folder;

    PROCEDURE populate_case_folder_details (
        p_case_folder_id     IN     NUMBER,
        p_data_folder_id     IN     NUMBER,
        p_data_point_name    IN     VARCHAR2,
        p_data_point_value   IN     VARCHAR2 DEFAULT NULL,
        p_score              IN     VARCHAR2 DEFAULT NULL,
        x_return_status         OUT VARCHAR2,
        x_message_count         OUT NUMBER,
        x_message_data          OUT VARCHAR2)
    IS
        l_data_point_id   NUMBER;
        l_resultout       NUMBER := 0;
        lv_pn             VARCHAR2 (240)
            := gv_package_name || '.populate_case_folder_details';
    BEGIN
        x_return_status   := g_ret_success;

        /*  msg (' Inside  populate_case_folder_details ', 1); */
                                                          -- Commented for 1.7

        SELECT data_point_id
          INTO l_data_point_id
          FROM ar_cmgt_data_points_b
         WHERE data_point_code = p_data_point_name;

        ar_cmgt_controls.populate_case_folder_details (
            p_case_folder_id           => p_case_folder_id,
            p_data_point_id            => l_data_point_id,
            p_data_point_value         => p_data_point_value,
            p_included_in_check_list   => 'Y',
            p_score                    => p_score,
            p_errmsg                   => x_message_data,
            p_resultout                => l_resultout);

        IF l_resultout != 0
        THEN
            /*  msg (
                    'ar_cmgt_controls.populate_case_folder_details returned ('
                 || l_resultout
                 || ')',
                 1);
              msg (x_message_data, 1); */
            -- Commented for 1.7
            x_return_status   := g_ret_error;
        END IF;

        /*ar_cmgt_controls.populate_case_folder_details (
           p_case_folder_id           => p_data_folder_id,
           p_data_point_id            => l_data_point_id,
           p_data_point_value         => p_data_point_value,
           p_included_in_check_list   => 'Y',
           p_score                    => p_score,
           p_errmsg                   => x_message_data,
           p_resultout                => l_resultout);

        IF l_resultout != 0
        THEN
           msg (
                 'ar_cmgt_controls.populate_case_folder_details returned ('
              || l_resultout
              || ')',1);
           msg (x_message_data,1);
           x_return_status := g_ret_error;
        END IF;*/

        x_message_data    := NVL (x_message_data, 'SUCCESS');
    EXCEPTION
        WHEN OTHERS
        THEN
            write_to_table ('Error in Populate Case Folder Details', SQLERRM);
            x_return_status   := g_ret_unexp_error;
            x_message_data    :=
                   'Unexpected Error occured in Populate Case folder Details Procedure :: '
                || SQLERRM;
    /*   msg (
             ' ERROR in procedure '
          || lv_pn
          || ' : '
          || x_return_status
          || x_message_data,
          1); */
    END populate_case_folder_details;

    PROCEDURE populate_recommendations (
        p_case_folder_id             IN     NUMBER,
        p_credit_request_id          IN     VARCHAR2,
        p_recommended_credit_limit   IN     NUMBER,
        p_credit_review_date         IN     DATE,
        p_credit_recommendation      IN     VARCHAR2,
        p_recommendation_value1      IN     VARCHAR2,
        p_recommendation_value2      IN     VARCHAR2,
        p_credit_type                IN     VARCHAR2,
        x_return_status                 OUT VARCHAR2,
        x_message_count                 OUT NUMBER,
        x_message_data                  OUT VARCHAR2)
    IS
        l_data_point_id   NUMBER;
        l_resultout       NUMBER := 0;
        lv_pn             VARCHAR2 (240)
            := gv_package_name || '.populate_recommendations';
    BEGIN
        x_return_status   := g_ret_success;
        /* msg (' Inside  populate_recommendations ', 1); */
                                                          -- Commented for 1.7
        ar_cmgt_controls.populate_recommendation (
            p_case_folder_id             => p_case_folder_id,
            p_credit_request_id          => p_credit_request_id,
            p_score                      => NULL,
            p_recommended_credit_limit   => p_recommended_credit_limit,
            p_credit_review_date         => p_credit_review_date,
            p_credit_recommendation      => p_credit_recommendation,
            p_recommendation_value1      => p_recommendation_value1,
            p_recommendation_value2      => p_recommendation_value2,
            p_status                     => 'I',
            p_credit_type                => p_credit_type,
            p_errmsg                     => x_message_data,
            p_resultout                  => l_resultout);

        IF l_resultout != 0
        THEN
            /*  msg (
                    'ar_cmgt_controls.populate_recommendation returned ('
                 || l_resultout
                 || ')',
                 1);
              msg (x_message_data, 1); */
            -- Commented for 1.7
            x_return_status   := g_ret_error;
        END IF;

        x_message_data    := NVL (x_message_data, SQLERRM);
        write_to_table ('Error in Populate Recommendations', x_message_data);
    EXCEPTION
        WHEN OTHERS
        THEN
            write_to_table ('Error in Populate Recommendations', SQLERRM);
            x_return_status   := g_ret_unexp_error;
            x_message_data    :=
                   'Unexpected Error in Populate Recommendations Procedure :: '
                || SQLERRM;
    /* msg (
           ' ERROR in procedure '
        || lv_pn
        || ' : '
        || x_return_status
        || x_message_data,
        1); */
    -- Commented for 1.7
    END populate_recommendations;

    PROCEDURE implement_recommendations (p_case_folder_id IN NUMBER, p_customer_number IN VARCHAR2, p_reviewdate IN DATE, p_credit_request_id IN VARCHAR2, p_scoredate DATE, p_credit_score IN NUMBER, p_agent IN VARCHAR2, p_assigned_credit_line IN NUMBER, p_calculated_credit_line IN NUMBER
                                         , x_return_status OUT VARCHAR2, x_message_count OUT NUMBER, x_message_data OUT VARCHAR2)
    IS
        l_payment_quality_index     VARCHAR2 (240 BYTE);
        l_credit_score              NUMBER;
        l_nsf_c2b                   VARCHAR2 (240 BYTE);
        l_next_review_date          DATE;
        l_last_review_date          DATE;
        l_credit_classification     VARCHAR2 (30 BYTE);
        l_row_id1                   ROWID := NULL;
        l_row_id2                   ROWID := NULL;
        l_party_id                  NUMBER;
        l_cust_account_id           NUMBER;
        l_score                     NUMBER;
        l_row_id3                   ROWID := NULL;
        l_cust_account_id1          NUMBER;
        l_limit                     VARCHAR2 (60 BYTE);
        l_credit_rating             VARCHAR2 (80 BYTE);
        lv_review_cycle             VARCHAR2 (80 BYTE);
        ln_review_diff              NUMBER;
        l_new_review_date           DATE;
        l_cust_account_profile_id   NUMBER;
        l_credit_analyst_id         NUMBER;
        lv_pn                       VARCHAR2 (240)
            := gv_package_name || '.implement_recommendations';
        lv_operating_unit           VARCHAR2 (240) := 'Deckers US OU';
        l_num_org_id                NUMBER;
    BEGIN
        x_return_status   := g_ret_success;

        /* msg (' Inside  implement_recommendations ', 1); */
                                                          -- Commented for 1.7

        BEGIN
            SELECT party_id, credit_classification
              INTO l_party_id, l_credit_classification
              FROM ar_cmgt_credit_requests
             WHERE credit_request_id = p_credit_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                write_to_table (
                       'Error in Fetching Party Information '
                    || p_credit_request_id,
                    SQLERRM);
        /*   msg ('Error in Fetching Party Information :: ' || SQLERRM, 1); */
                                                          -- Commented for 1.7
        END;

        BEGIN
            SELECT ROWID
              INTO l_row_id1
              FROM hz_parties
             WHERE party_id = l_party_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                write_to_table (
                       'Error in Fetching Row ID for Party Information '
                    || l_party_id,
                    SQLERRM);
        /*  msg (
             'Error in Fetching Row ID for Party Information :: '
             || SQLERRM,
             1); */
        -- Commented for 1.7
        END;

        BEGIN
            SELECT score
              INTO l_credit_score
              FROM ar_cmgt_cf_dtls
             WHERE     case_folder_id = p_case_folder_id
                   AND data_point_id IN
                           (SELECT data_point_id
                              FROM ar_cmgt_data_points_b
                             WHERE data_point_code = 'C2B_CREDIT_SCORE');
        EXCEPTION
            WHEN OTHERS
            THEN
                l_credit_score   := NULL;
        END;

        BEGIN
            SELECT data_point_value
              INTO l_payment_quality_index
              FROM ar_cmgt_cf_dtls
             WHERE     case_folder_id = p_case_folder_id
                   AND data_point_id IN (SELECT data_point_id
                                           FROM ar_cmgt_data_points_b
                                          WHERE data_point_code = 'C2B_PQI');
        EXCEPTION
            WHEN OTHERS
            THEN
                l_payment_quality_index   := NULL;
        END;

        BEGIN
            SELECT data_point_value
              INTO l_nsf_c2b
              FROM ar_cmgt_cf_dtls
             WHERE     case_folder_id = p_case_folder_id
                   AND data_point_id IN (SELECT data_point_id
                                           FROM ar_cmgt_data_points_b
                                          WHERE data_point_code = 'C2B_NSF');
        EXCEPTION
            WHEN OTHERS
            THEN
                l_nsf_c2b   := NULL;
        END;

        BEGIN
            hz_parties_pkg.update_row (x_rowid => l_row_id1, x_party_id => l_party_id, x_party_number => NULL, x_party_name => NULL, x_party_type => NULL, x_validated_flag => NULL, x_attribute_category => 'Customer', x_attribute1 => p_credit_score, x_attribute2 => l_payment_quality_index, x_attribute3 => l_nsf_c2b, x_attribute4 => NULL, x_attribute5 => NULL, x_attribute6 => NULL, x_attribute7 => NULL, x_attribute8 => NULL, x_attribute9 => NULL, x_attribute10 => NULL, x_attribute11 => NULL, x_attribute12 => NULL, x_attribute13 => NULL, x_attribute14 => NULL, x_attribute15 => NULL, x_attribute16 => NULL, x_attribute17 => NULL, x_attribute18 => NULL, x_attribute19 => NULL, x_attribute20 => NULL, x_attribute21 => NULL, x_attribute22 => NULL, x_attribute23 => NULL, x_attribute24 => NULL, x_orig_system_reference => NULL, x_sic_code => NULL, x_hq_branch_ind => NULL, x_customer_key => NULL, x_tax_reference => NULL, x_jgzz_fiscal_code => NULL, x_person_pre_name_adjunct => NULL, x_person_first_name => NULL, x_person_middle_name => NULL, x_person_last_name => NULL, x_person_name_suffix => NULL, x_person_title => NULL, x_person_academic_title => NULL, x_person_previous_last_name => NULL, x_known_as => NULL, x_person_iden_type => NULL, x_person_identifier => NULL, x_group_type => NULL, x_country => NULL, x_address1 => NULL, x_address2 => NULL, x_address3 => NULL, x_address4 => NULL, x_city => NULL, x_postal_code => NULL, x_state => NULL, x_province => NULL, x_status => NULL, x_county => NULL, x_sic_code_type => NULL, x_url => NULL, x_email_address => NULL, x_analysis_fy => NULL, x_fiscal_yearend_month => NULL, x_employees_total => NULL, x_curr_fy_potential_revenue => NULL, x_next_fy_potential_revenue => NULL, x_year_established => NULL, x_gsa_indicator_flag => NULL, x_mission_statement => NULL, x_organization_name_phonetic => NULL, x_person_first_name_phonetic => NULL, x_person_last_name_phonetic => NULL, x_language_name => NULL, x_category_code => 'CUSTOMER', x_salutation => NULL, x_known_as2 => NULL, x_known_as3 => NULL, x_known_as4 => NULL, x_known_as5 => NULL, x_object_version_number => NULL, x_duns_number_c => NULL, x_created_by_module => NULL
                                       , x_application_id => NULL);
        EXCEPTION
            WHEN OTHERS
            THEN
                write_to_table ('Error in Updating Party Attributes',
                                SQLERRM);
        END;

        BEGIN
            SELECT ROWID, cust_account_profile_id
              INTO l_row_id3, l_cust_account_profile_id
              FROM hz_cust_profile_amts
             WHERE cust_account_profile_id IN
                       (SELECT cust_account_profile_id
                          FROM hz_customer_profiles
                         WHERE party_id = l_party_id AND cust_account_id = -1);
        EXCEPTION
            WHEN OTHERS
            THEN
                write_to_table ('Error in Fetching Cust Profile Id', SQLERRM);
        /*  msg ('Error in Fetching Cust Profile Id :: ' || SQLERRM, 1); */
                                                          -- Commented for 1.7
        END;

        BEGIN
            SELECT recommendation_value2
              INTO l_limit
              FROM ar_cmgt_cf_recommends
             WHERE     credit_request_id = p_credit_request_id
                   AND CREDIT_RECOMMENDATION = 'CREDIT_LIMIT';
        EXCEPTION
            WHEN OTHERS
            THEN
                write_to_table ('Error in Fetching Credit Limit Value',
                                SQLERRM);
        /*   msg ('Error in Fetching Credit Limit Value :: ' || SQLERRM, 1); */
                                                          -- Commented for 1.7
        END;

        /* msg (
              ' p_calculated_credit_line '
           || p_calculated_credit_line
           || ' Cust Account Prof Id '
           || l_cust_account_profile_id,
           1); */
        -- Commented for 1.7

        BEGIN
            hz_cust_profile_amts_pkg.update_row (
                x_rowid                         => l_row_id3,
                x_cust_acct_profile_amt_id      => NULL,
                x_cust_account_profile_id       => l_cust_account_profile_id,
                x_currency_code                 => NULL,
                x_trx_credit_limit              => p_assigned_credit_line, --p_calculated_credit_line, -- ASSIGNED_CREDIT_LINE
                x_overall_credit_limit          => p_assigned_credit_line, --NVL (p_assigned_credit_line,
                --p_calculated_credit_line), -- ASSIGNED_CREDIT_LINE
                x_min_dunning_amount            => NULL,
                x_min_dunning_invoice_amount    => NULL,
                x_max_interest_charge           => NULL,
                x_min_statement_amount          => NULL,
                x_auto_rec_min_receipt_amount   => NULL,
                x_interest_rate                 => NULL,
                x_attribute_category            => NULL,
                x_attribute1                    => NULL,
                x_attribute2                    => NULL,
                x_attribute3                    => NULL,
                x_attribute4                    => NULL,
                x_attribute5                    => NULL,
                x_attribute6                    => NULL,
                x_attribute7                    => NULL,
                x_attribute8                    => NULL,
                x_attribute9                    => NULL,
                x_attribute10                   => NULL,
                x_attribute11                   => NULL,
                x_attribute12                   => NULL,
                x_attribute13                   => NULL,
                x_attribute14                   => NULL,
                x_attribute15                   => NULL,
                x_min_fc_balance_amount         => NULL,
                x_min_fc_invoice_amount         => NULL,
                x_cust_account_id               => NULL,
                x_site_use_id                   => NULL,
                x_expiration_date               => NULL,
                x_jgzz_attribute_category       => NULL,
                x_jgzz_attribute1               => NULL,
                x_jgzz_attribute2               => NULL,
                x_jgzz_attribute3               => NULL,
                x_jgzz_attribute4               => NULL,
                x_jgzz_attribute5               => NULL,
                x_jgzz_attribute6               => NULL,
                x_jgzz_attribute7               => NULL,
                x_jgzz_attribute8               => NULL,
                x_jgzz_attribute9               => NULL,
                x_jgzz_attribute10              => NULL,
                x_jgzz_attribute11              => NULL,
                x_jgzz_attribute12              => NULL,
                x_jgzz_attribute13              => NULL,
                x_jgzz_attribute14              => NULL,
                x_jgzz_attribute15              => NULL,
                x_global_attribute1             => NULL,
                x_global_attribute2             => NULL,
                x_global_attribute3             => NULL,
                x_global_attribute4             => NULL,
                x_global_attribute5             => NULL,
                x_global_attribute6             => NULL,
                x_global_attribute7             => NULL,
                x_global_attribute8             => NULL,
                x_global_attribute9             => NULL,
                x_global_attribute10            => NULL,
                x_global_attribute11            => NULL,
                x_global_attribute12            => NULL,
                x_global_attribute13            => NULL,
                x_global_attribute14            => NULL,
                x_global_attribute15            => NULL,
                x_global_attribute16            => NULL,
                x_global_attribute17            => NULL,
                x_global_attribute18            => NULL,
                x_global_attribute19            => NULL,
                x_global_attribute20            => NULL,
                x_global_attribute_category     => NULL,
                x_object_version_number         => NULL,
                x_created_by_module             => NULL,
                x_application_id                => NULL,
                x_exchange_rate_type            => NULL,
                x_min_fc_invoice_overdue_type   => NULL,
                x_min_fc_invoice_percent        => NULL,
                x_min_fc_balance_overdue_type   => NULL,
                x_min_fc_balance_percent        => NULL,
                x_interest_type                 => NULL,
                x_interest_fixed_amount         => NULL,
                x_interest_schedule_id          => NULL,
                x_penalty_type                  => NULL,
                x_penalty_rate                  => NULL,
                x_min_interest_charge           => NULL,
                x_penalty_fixed_amount          => NULL,
                x_penalty_schedule_id           => NULL);
        EXCEPTION
            WHEN OTHERS
            THEN
                /*  msg ('Error in Updating Cust Profiles :: ' || SQLERRM, 1); */
                                                          -- Commented for 1.7
                write_to_table ('Error in Updating Cust Profiles Amts',
                                SQLERRM);
        END;

        BEGIN
            SELECT ROWID, next_credit_review_date, last_credit_review_date,
                   review_cycle, credit_analyst_id
              INTO l_row_id2, l_next_review_date, l_last_review_date, lv_review_cycle,
                            l_credit_analyst_id
              FROM hz_customer_profiles
             WHERE party_id = l_party_id AND cust_account_id = -1;
        EXCEPTION
            WHEN OTHERS
            THEN
                write_to_table (
                    'Error in Fetching Review Dates from Party Information',
                    SQLERRM);
        /*  msg (
             'Error in Fetching Review Dates from Party Information :: '
             || SQLERRM,
             1); */
        -- Commented for 1.7
        END;

        BEGIN
            SELECT organization_id
              INTO l_num_org_id
              FROM hr_operating_units
             WHERE name = lv_operating_unit;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_num_org_id   := NULL;
                write_to_table ('Error in Fetching Operating Unit', SQLERRM);
        /*  msg ('Error in Fetching Operating Unit :: ' || SQLERRM, 1); */
                                                          -- Commented for 1.7
        END;

        --added for 1.1 start
        BEGIN
            SELECT lookup_code
              INTO l_credit_rating
              FROM (SELECT TO_NUMBER (attribute1) attr1, TO_NUMBER (attribute2) attr2, flv.*
                      FROM fnd_lookup_values_vl flv
                     WHERE     NOT REGEXP_LIKE (attribute1, '^[A-Z]')
                           AND NOT REGEXP_LIKE (attribute2, '^[A-Z]')
                           AND lookup_type = 'CREDIT_RATING') flv1
             WHERE     enabled_flag = 'Y'
                   AND attribute3 = 'Y'
                   AND attribute5 = TO_CHAR (l_num_org_id)
                   AND TO_NUMBER (p_credit_score) BETWEEN TO_NUMBER (attr1)
                                                      AND TO_NUMBER (attr2);
        EXCEPTION
            WHEN OTHERS
            THEN
                l_credit_rating   := NULL;
                write_to_table ('Error in Fetching Credit Rating', SQLERRM);
        /*  msg ('Error in Fetching Credit Rating :: ' || SQLERRM, 1); */
                                                          -- Commented for 1.7
        END;

        --added for 1.1 end
        --commented for 1.1 start
        --     IF p_credit_score > 89
        --     THEN
        --        BEGIN
        --          SELECT lookup_code
        --            INTO l_credit_rating
        --            FROM fnd_lookup_values_vl
        --           WHERE lookup_type = 'CREDIT_RATING'
        --             AND attribute5 = TO_CHAR (l_num_org_id)
        --             AND enabled_flag = 'Y'
        --             AND attribute3 = 'Y'
        --             AND meaning NOT LIKE 'US Sub Grade%'
        --             AND TO_CHAR(attribute1) > '89';
        --        EXCEPTION
        --             WHEN OTHERS
        --             THEN
        --               fnd_file.put_line(fnd_file.log,'Error in Fetching Credit Rating for score > 89 :: ' || SQLERRM);
        --        END;
        --     ELSE
        --       BEGIN
        --         SELECT lookup_code
        --           INTO l_credit_rating
        --           FROM fnd_lookup_values_vl
        --          WHERE     lookup_type = 'CREDIT_RATING'
        --                AND (   TO_CHAR (p_credit_score) BETWEEN attribute1
        --                                                     AND attribute2
        --                     OR TO_CHAR (p_credit_score) = attribute1
        --                     OR TO_CHAR (p_credit_score) = attribute2)
        --                AND enabled_flag = 'Y'
        --                AND ATTRIBUTE3 = 'Y'
        --                AND ATTRIBUTE5 = TO_CHAR (l_num_org_id);
        --      --                       (SELECT b.org_id
        --      --                          FROM hz_cust_accounts a,
        --      --                               hz_cust_acct_sites_all b
        --      --                         WHERE ACCOUNT_NUMBER = p_customer_number
        --      --                           AND party_id = l_party_id
        --      --                           AND a.cust_account_id = b.cust_account_id
        --      --                           AND ROWNUM = 1);
        --       EXCEPTION
        --         WHEN OTHERS
        --         THEN
        --            l_credit_rating := NULL;
        --            msg ('Error in Fetching Credit Rating :: ' || SQLERRM, 1);
        --       END;
        --     END IF;
        --commented for 1.1 end

        IF    l_next_review_date IS NULL
           OR l_last_review_date IS NULL
           OR lv_review_cycle IS NULL
        THEN
            l_new_review_date   := p_scoredate + 365;
        ELSE
            IF TO_DATE (p_reviewdate) BETWEEN TO_DATE (l_last_review_date)
                                          AND TO_DATE (l_next_review_date)
            THEN
                l_new_review_date   := l_next_review_date;
            ELSE
                SELECT TO_DATE (l_next_review_date) - TO_DATE (p_reviewdate)
                  INTO ln_review_diff
                  FROM DUAL;

                IF ln_review_diff <= 15
                THEN
                    IF UPPER (lv_review_cycle) = 'QUARTERLY'
                    THEN
                        l_new_review_date   := l_next_review_date + 90;
                    ELSIF UPPER (lv_review_cycle) = 'YEARLY'
                    THEN
                        l_new_review_date   := l_next_review_date + 365;
                    ELSIF UPPER (lv_review_cycle) = 'HALF_YEARLY'
                    THEN
                        l_new_review_date   := l_next_review_date + 180;
                    ELSIF UPPER (lv_review_cycle) = 'MONTHLY'
                    THEN
                        l_new_review_date   := l_next_review_date + 30;
                    ELSIF UPPER (lv_review_cycle) = 'WEEKLY'
                    THEN
                        l_new_review_date   := l_next_review_date + 7;
                    END IF;
                ELSE
                    l_new_review_date   := l_next_review_date;
                END IF;
            END IF;
        END IF;

        /*  msg (
                ' p_reviewdate '
             || p_reviewdate
             || ' l_next_review_date '
             || l_next_review_date
             || ' ln_review_diff '
             || ln_review_diff
             || ' lv_review_cycle '
             || lv_review_cycle
             || ' l_next_review_date '
             || l_next_review_date
             || ' Credit Rating '
             || l_credit_rating,
             1); */
        -- Commented for 1.7

        BEGIN
            hz_customer_profiles_pkg.update_row (
                x_rowid                          => l_row_id2,
                x_cust_account_profile_id        => NULL,
                x_cust_account_id                => NULL,
                x_status                         => NULL,
                x_collector_id                   => NULL,
                x_credit_analyst_id              => l_credit_analyst_id,
                x_credit_checking                => NULL,
                x_next_credit_review_date        => l_new_review_date,
                x_tolerance                      => NULL,
                x_discount_terms                 => NULL,
                x_dunning_letters                => NULL,
                x_interest_charges               => NULL,
                x_send_statements                => NULL,
                x_credit_balance_statements      => NULL,
                x_credit_hold                    => NULL,
                x_profile_class_id               => NULL,
                x_site_use_id                    => NULL,
                x_credit_rating                  => l_credit_rating,
                x_risk_code                      => NULL,
                x_standard_terms                 => NULL,
                x_override_terms                 => NULL,
                x_dunning_letter_set_id          => NULL,
                x_interest_period_days           => NULL,
                x_payment_grace_days             => NULL,
                x_discount_grace_days            => NULL,
                x_statement_cycle_id             => NULL,
                x_account_status                 => NULL,
                x_percent_collectable            => NULL,
                x_autocash_hierarchy_id          => NULL,
                x_attribute_category             => NULL,
                x_attribute1                     => NULL,
                x_attribute2                     => NULL,
                x_attribute3                     => NULL,
                x_attribute4                     => NULL,
                x_attribute5                     => NULL,
                x_attribute6                     => NULL,
                x_attribute7                     => NULL,
                x_attribute8                     => NULL,
                x_attribute9                     => NULL,
                x_attribute10                    => NULL,
                x_attribute11                    => NULL,
                x_attribute12                    => NULL,
                x_attribute13                    => NULL,
                x_attribute14                    => NULL,
                x_attribute15                    => NULL,
                x_auto_rec_incl_disputed_flag    => NULL,
                x_tax_printing_option            => NULL,
                x_charge_on_finance_charge_fg    => NULL,
                x_grouping_rule_id               => NULL,
                x_clearing_days                  => NULL,
                x_jgzz_attribute_category        => NULL,
                x_jgzz_attribute1                => NULL,
                x_jgzz_attribute2                => NULL,
                x_jgzz_attribute3                => NULL,
                x_jgzz_attribute4                => NULL,
                x_jgzz_attribute5                => NULL,
                x_jgzz_attribute6                => NULL,
                x_jgzz_attribute7                => NULL,
                x_jgzz_attribute8                => NULL,
                x_jgzz_attribute9                => NULL,
                x_jgzz_attribute10               => NULL,
                x_jgzz_attribute11               => NULL,
                x_jgzz_attribute12               => NULL,
                x_jgzz_attribute13               => NULL,
                x_jgzz_attribute14               => NULL,
                x_jgzz_attribute15               => NULL,
                x_global_attribute1              => NULL,
                x_global_attribute2              => NULL,
                x_global_attribute3              => NULL,
                x_global_attribute4              => NULL,
                x_global_attribute5              => NULL,
                x_global_attribute6              => NULL,
                x_global_attribute7              => NULL,
                x_global_attribute8              => NULL,
                x_global_attribute9              => NULL,
                x_global_attribute10             => NULL,
                x_global_attribute11             => NULL,
                x_global_attribute12             => NULL,
                x_global_attribute13             => NULL,
                x_global_attribute14             => NULL,
                x_global_attribute15             => NULL,
                x_global_attribute16             => NULL,
                x_global_attribute17             => NULL,
                x_global_attribute18             => NULL,
                x_global_attribute19             => NULL,
                x_global_attribute20             => NULL,
                x_global_attribute_category      => NULL,
                x_cons_inv_flag                  => NULL,
                x_cons_inv_type                  => NULL,
                x_autocash_hierarchy_id_adr      => NULL,
                x_lockbox_matching_option        => NULL,
                x_object_version_number          => NULL,
                x_created_by_module              => NULL,
                x_application_id                 => NULL,
                x_review_cycle                   =>
                    NVL (lv_review_cycle, 'YEARLY'),
                x_last_credit_review_date        => p_scoredate,
                x_party_id                       => NULL,
                x_credit_classification          => l_credit_classification,
                x_cons_bill_level                => NULL,
                x_late_charge_calculation_trx    => NULL,
                x_credit_items_flag              => NULL,
                x_disputed_transactions_flag     => NULL,
                x_late_charge_type               => NULL,
                x_late_charge_term_id            => NULL,
                x_interest_calculation_period    => NULL,
                x_hold_charged_invoices_flag     => NULL,
                x_message_text_id                => NULL,
                x_multiple_interest_rates_flag   => NULL,
                x_charge_begin_date              => NULL,
                x_automatch_set_id               => NULL);
        EXCEPTION
            WHEN OTHERS
            THEN
                /* msg (
                    'Error in Fetching Party Profile Information :: ' || SQLERRM); */
                -- Commented for 1.7
                write_to_table ('Error in Updating Cust Profiles', SQLERRM);
        END;

        COMMIT;

        BEGIN
            UPDATE hz_customer_profiles
               SET credit_rating = l_credit_rating, credit_classification = l_credit_classification, review_cycle = 'YEARLY',
                   --NEXT_CREDIT_REVIEW_DATE = SYSDATE + 365,              --defect 903
                   last_credit_review_date = SYSDATE, credit_analyst_id = l_credit_analyst_id -- 1.6 Defect 1647
             /*(SELECT credit_analyst_id
                FROM hz_customer_profiles
               WHERE party_id = l_party_id
                     AND cust_account_id =
                            (SELECT cust_account_id
                               FROM hz_cust_accounts
                              WHERE party_id = l_party_id
                                    AND attribute1 = 'ALL BRAND'))*/
             WHERE party_id = l_party_id AND cust_account_id != -1;
        EXCEPTION
            WHEN OTHERS
            THEN
                write_to_table (
                    'Error in Updating Profiles for ALL Brand Accounts',
                    SQLERRM);
        /* msg (
            'Error in Updating Profiles for ALL Brand Accounts :: '
            || SQLERRM); */
        -- Commented for 1.7
        END;

        COMMIT;

        x_message_data    := NVL (x_message_data, 'SUCCESS');
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_status   := g_ret_unexp_error;
            x_message_data    :=
                   'Unexpected Error in Implement Recommendations Procedure :: '
                || SQLERRM;
            write_to_table (
                   ' ERROR in procedure '
                || lv_pn
                || ' : '
                || x_return_status
                || x_message_data,
                SQLERRM);
    /*  msg (
            ' ERROR in procedure '
         || lv_pn
         || ' : '
         || x_return_status
         || x_message_data,
         1); */
    -- Commented for 1.7
    END implement_recommendations;

    PROCEDURE initiate_manual_review (p_case_folder_id IN NUMBER, p_credit_request_id IN VARCHAR2, p_agent IN VARCHAR2
                                      , x_return_status OUT VARCHAR2, x_message_count OUT NUMBER, x_message_data OUT VARCHAR2)
    IS
        l_credit_analyst_id   NUMBER;
        lv_pn                 VARCHAR2 (240)
            := gv_package_name || '.initiate_manual_review';
    BEGIN
        x_return_status   := g_ret_success;

        /*  msg (' Inside  initiate_manual_review ', 1); */
                                                          -- Commented for 1.7

        launch_approval_process (p_case_folder_id      => p_case_folder_id,
                                 p_credit_request_id   => p_credit_request_id,
                                 x_return_status       => x_return_status,
                                 x_message_count       => x_message_count,
                                 x_message_data        => x_message_data);

        IF x_return_status <> g_ret_success
        THEN
            /*  msg ('(' || x_return_status || ')', 1); */
                                                          -- Commented for 1.7
            write_to_table (x_return_status, NULL);
        END IF;

        x_message_data    := NVL (x_message_data, 'SUCCESS');
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_status   := g_ret_unexp_error;
            x_message_data    :=
                   'Unexpected Error found in Initial Manual review Procedure :: '
                || SQLERRM;
    /* msg (
           ' ERROR in procedure '
        || lv_pn
        || ' : '
        || x_return_status
        || x_message_data,
        1); */
    -- Commented for 1.7
    END initiate_manual_review;

    PROCEDURE launch_approval_process (p_case_folder_id      IN     NUMBER,
                                       p_credit_request_id   IN     VARCHAR2,
                                       x_return_status          OUT VARCHAR2,
                                       x_message_count          OUT NUMBER,
                                       x_message_data           OUT VARCHAR2)
    IS
        l_score_model_id   NUMBER := NULL;
        l_resultout        VARCHAR2 (240) := '0';
        l_case_folder      NUMBER;
        lv_pn              VARCHAR2 (240)
            := gv_package_name || '.launch_approval_process';
    BEGIN
        x_return_status   := g_ret_success;
        /*  msg (' Inside  launch_approval_process ', 1); */
                                                          -- Commented for 1.7
        ar_cmgt_wf_engine.start_workflow (
            p_credit_request_id    => p_credit_request_id,
            p_application_status   => 'SUBMIT');
    /*IF l_resultout != '0'
    THEN
       msg (
             'AR_CMGT_WF_ENGINE.APPROVAL_PROCESS returned ('
          || l_resultout
          || ')');
       x_return_status := g_ret_error;
    ELSE
       UPDATE ar_cmgt_cf_recommends
          SET status = 'I'
        WHERE credit_request_id = p_credit_request_id;

       msg ('Rows Updated 3 :: ' || SQL%ROWCOUNT, 1);
    END IF;*/
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_status   := g_ret_unexp_error;
            x_message_data    :=
                'Unexpected Error in Launch Approval Process :: ' || SQLERRM;
    /* msg (
           ' ERROR in procedure '
        || lv_pn
        || ' : '
        || x_return_status
        || x_message_data,
        1); */
    -- Commented for 1.7
    END launch_approval_process;

    PROCEDURE credit_handler (p_customer_name IN VARCHAR2, p_customer_number IN VARCHAR2, p_credit_score IN NUMBER, p_scoredate DATE, p_assigned_credit_line IN NUMBER, p_calculated_credit_line IN NUMBER, p_confidence_level IN NUMBER, p_payment_quality_index IN NUMBER, p_intelliscore IN NUMBER, p_years_in_business IN NUMBER, p_manual_review_flag IN VARCHAR2, p_nsf_c2b IN VARCHAR2, p_alert_code IN VARCHAR2, p_ownershipchange IN NUMBER, p_review_date IN DATE
                              , p_agent IN VARCHAR2, x_return_status OUT VARCHAR2, x_message_data OUT VARCHAR2)
    IS
        l_party_id            NUMBER;
        l_review_cycle        VARCHAR2 (80 BYTE);
        l_credit_request_id   NUMBER;
        l_message_count       NUMBER;
        l_cnt                 NUMBER;
        l_case_folder_id      NUMBER;
        l_data_folder_id      NUMBER;
        l_credit_request      ar_cmgt_credit_requests%ROWTYPE;
        l_credit_analyst_id   NUMBER;
        l_resultout           NUMBER := 0;
        lv_pn                 VARCHAR2 (240)
                                  := gv_package_name || '.credit_handler';
    BEGIN
        /*  msg (' Inside  credit_handler ', 1);
          msg (' p_customer_name ' || p_customer_name, 1); */
        -- Commented for 1.7
        x_return_status   := g_ret_success;

        --   SAVEPOINT begin_credit_handler;  -- Commented for 1.4.

        --added for 1.2 start
        BEGIN
            SELECT RESOURCE_ID
              INTO l_credit_analyst_id
              FROM jtf_rs_resource_extns
             -- WHERE SOURCE_NAME = p_agent;  --W.r.t Version 1.8
             WHERE     UPPER (SOURCE_FIRST_NAME || ' ' || SOURCE_LAST_NAME) =
                       UPPER (p_agent)                     --W.r.t Version 1.8
                   AND SYSDATE BETWEEN NVL (START_DATE_ACTIVE, SYSDATE)
                                   AND NVL (END_DATE_ACTIVE, SYSDATE); -- Added for INC0349657
        EXCEPTION
            WHEN TOO_MANY_ROWS
            THEN
                write_to_table ('Too many analysts found', SQLERRM);
                x_message_data    := 'Too many analysts found';
                x_return_status   := g_ret_error;
                RETURN;
            WHEN NO_DATA_FOUND
            THEN
                write_to_table ('No credit analyst found', SQLERRM);
                x_message_data    := 'No credit analyst found';
                x_return_status   := g_ret_error;
                RETURN;
            WHEN OTHERS
            THEN
                write_to_table ('Error in Finding credit analyst', SQLERRM);
                x_message_data    :=
                    'Error in finding Credit Analyst :: ' || SQLERRM;
                x_return_status   := g_ret_error;
                RETURN;
        END;

        --added for 1.2 end

        SELECT COUNT (*), MAX (hp.party_id)
          INTO l_cnt, l_party_id
          FROM hz_parties hp
         -- WHERE party_name = p_customer_name -- Commented for 1.9
         --  AND party_number = p_customer_number -- Commented for 1.9
         WHERE     party_number = p_customer_number           -- Added for 1.9
               AND status = 'A'
               AND address1 IS NOT NULL;

        IF l_cnt <> 1
        THEN
            x_return_status   := g_ret_error;
            x_message_data    :=
                   'The expected number of parties (1) was not found for customer name ('
                || p_customer_name
                || '), ('
                || l_cnt
                || ') parties found';
            write_to_table ('Error in Fetching Parties', x_message_data);
            RETURN;
        END IF;


        --IF NVL (TRIM (fnd_profile.VALUE ('Credit Check List')), '--NONE--') =
        --      '--NONE--'
        --THEN
        --   x_return_status := g_ret_error;
        --   x_message_data := 'Profile value (Credit Check List) not configured';

        --   IF l_dbname != 'BTDEV'
        --   THEN
        --      RETURN;
        --   END IF;
        --END IF;

        create_credit_request (p_customer_name => p_customer_name, p_customer_number => p_customer_number, -- 1.7
                                                                                                           p_manual_review => p_manual_review_flag, p_agent => p_agent, x_credit_request_id => l_credit_request_id, p_assigned_credit_line => p_assigned_credit_line, --NVL (p_assigned_credit_line,
                                                                                                                                                                                                                                                                      --p_calculated_credit_line), -- ASSIGNED_CREDIT_LINE
                                                                                                                                                                                                                                                                      x_party_id => l_party_id, x_return_status => x_return_status, x_message_count => l_message_count
                               , x_message_data => x_message_data);

        IF x_return_status <> g_ret_success
        THEN
            /*  msg ('(' || x_return_status || ')'); */
                                                          -- Commented for 1.7
            write_to_table ('Create Credit Requst Failed with Error',
                            x_message_data);
            --  ROLLBACK TO begin_credit_handler;    -- Commented for 1.4.
            RETURN;
        END IF;

        IF UPPER (p_manual_review_flag) = 'YES'
        THEN
            BEGIN
                INSERT INTO xxdoar_credit_data_points_stg (credit_request_id, party_id, alert_code, assigned_credit_line, calculated_credit_line, credit_score, intelliscore, manual_review, payment_quality_index, score_date, years_in_business, nsf, ownership_change, confidence_level, review_date
                                                           , status)
                     VALUES (l_credit_request_id, l_party_id, p_alert_code,
                             p_assigned_credit_line, -- ASSIGNED_CREDIT_LINE NVL (p_assigned_credit_line, p_calculated_credit_line),
                                                     p_calculated_credit_line, p_credit_score, p_intelliscore, p_manual_review_flag, p_payment_quality_index, p_scoredate, p_years_in_business, p_nsf_c2b, p_ownershipchange, p_confidence_level, p_review_date
                             , 'N');

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_to_table ('Error in writing data points to table',
                                    SQLERRM);
            END;
        ELSIF UPPER (p_manual_review_flag) = 'NO'
        THEN
            populate_case_folder (p_party_id => l_party_id, p_credit_request_id => l_credit_request_id, x_case_folder_id => l_case_folder_id, x_data_folder_id => l_data_folder_id, x_return_status => x_return_status, x_message_count => l_message_count
                                  , x_message_data => x_message_data);

            IF x_return_status <> g_ret_success
            THEN
                /*  msg ('(' || x_return_status || ')'); */
                                                          -- Commented for 1.7
                write_to_table ('Create Case Folder Failed with Error',
                                x_message_data);
                --  ROLLBACK TO begin_credit_handler;  -- Commented for 1.4.
                RETURN;
            END IF;


            populate_case_folder_details (
                p_case_folder_id     => l_case_folder_id,
                p_data_folder_id     => l_data_folder_id,
                p_data_point_name    => 'C2B_CREDIT_SCORE',
                p_data_point_value   => p_credit_score,
                p_score              => p_credit_score,
                x_return_status      => x_return_status,
                x_message_count      => l_message_count,
                x_message_data       => x_message_data);

            IF x_return_status <> g_ret_success
            THEN
                /* msg ('(' || x_return_status || ')'); */
                                                          -- Commented for 1.7
                write_to_table (
                    'Create Case Folder Details C2B_CREDIT_SCORE Failed with Error',
                    x_message_data);
                --   ROLLBACK TO begin_credit_handler;   -- Commented for 1.4.
                RETURN;
            END IF;

            populate_case_folder_details (
                p_case_folder_id     => l_case_folder_id,
                p_data_folder_id     => l_data_folder_id,
                p_data_point_name    => 'C2B_ASSIGN_CREDIT_LINE',
                p_data_point_value   => p_assigned_credit_line, --NVL (p_assigned_credit_line,
                --p_calculated_credit_line), -- ASSIGNED_CREDIT_LINE
                p_score              => NULL,
                x_return_status      => x_return_status,
                x_message_count      => l_message_count,
                x_message_data       => x_message_data);

            IF x_return_status <> g_ret_success
            THEN
                /*  msg ('(' || x_return_status || ')'); */
                                                          -- Commented for 1.7
                write_to_table (
                    'Create Case Folder Details C2B_ASSIGN_CREDIT_LINE Failed with Error',
                    x_message_data);
                --  ROLLBACK TO begin_credit_handler;   -- Commented for 1.4.
                RETURN;
            END IF;

            populate_case_folder_details (
                p_case_folder_id     => l_case_folder_id,
                p_data_folder_id     => l_data_folder_id,
                p_data_point_name    => 'C2B_CALC_CREDIT_LINE',
                p_data_point_value   => p_calculated_credit_line,
                p_score              => NULL,
                x_return_status      => x_return_status,
                x_message_count      => l_message_count,
                x_message_data       => x_message_data);

            IF x_return_status <> g_ret_success
            THEN
                /* msg ('(' || x_return_status || ')'); */
                write_to_table (
                    'Create Case Folder Details C2B_CALC_CREDIT_LINE Failed with Error',
                    x_message_data);
                --  ROLLBACK TO begin_credit_handler;  -- Commented for 1.4.
                RETURN;
            END IF;

            populate_case_folder_details (
                p_case_folder_id     => l_case_folder_id,
                p_data_folder_id     => l_data_folder_id,
                p_data_point_name    => 'C2B_CONF_LEVEL',
                p_data_point_value   => p_confidence_level,
                p_score              => NULL,
                x_return_status      => x_return_status,
                x_message_count      => l_message_count,
                x_message_data       => x_message_data);

            IF x_return_status <> g_ret_success
            THEN
                /*  msg ('(' || x_return_status || ')'); */
                write_to_table (
                    'Create Case Folder Details C2B_CONF_LEVEL Failed with Error',
                    x_message_data);
                -- ROLLBACK TO begin_credit_handler;  -- Commented for 1.4.
                RETURN;
            END IF;

            populate_case_folder_details (
                p_case_folder_id     => l_case_folder_id,
                p_data_folder_id     => l_data_folder_id,
                p_data_point_name    => 'C2B_PQI',
                p_data_point_value   => p_payment_quality_index,
                p_score              => NULL,
                x_return_status      => x_return_status,
                x_message_count      => l_message_count,
                x_message_data       => x_message_data);

            IF x_return_status <> g_ret_success
            THEN
                /*  msg ('(' || x_return_status || ')');*/
                write_to_table (
                    'Create Case Folder Details C2B_PQI Failed with Error',
                    x_message_data);
                -- ROLLBACK TO begin_credit_handler;   -- Commented for 1.4.
                RETURN;
            END IF;

            populate_case_folder_details (
                p_case_folder_id     => l_case_folder_id,
                p_data_folder_id     => l_data_folder_id,
                p_data_point_name    => 'C2B_INTELLISCORE',
                p_data_point_value   => p_intelliscore,
                p_score              => NULL,
                x_return_status      => x_return_status,
                x_message_count      => l_message_count,
                x_message_data       => x_message_data);

            IF x_return_status <> g_ret_success
            THEN
                /* msg ('(' || x_return_status || ')'); */
                                                          -- Commented for 1.7
                write_to_table (
                    'Create Case Folder Details C2B_INTELLISCORE Failed with Error',
                    x_message_data);
                -- ROLLBACK TO begin_credit_handler;  -- Commented for 1.4.
                RETURN;
            END IF;

            populate_case_folder_details (
                p_case_folder_id     => l_case_folder_id,
                p_data_folder_id     => l_data_folder_id,
                p_data_point_name    => 'C2B_YRS_IN_BUSINESS',
                p_data_point_value   => p_years_in_business,
                p_score              => NULL,
                x_return_status      => x_return_status,
                x_message_count      => l_message_count,
                x_message_data       => x_message_data);

            IF x_return_status <> g_ret_success
            THEN
                /* msg ('(' || x_return_status || ')');*/
                                                          -- Commented for 1.7
                write_to_table (
                    'Create Case Folder Details C2B_YRS_IN_BUSINESS Failed with Error',
                    x_message_data);
                -- ROLLBACK TO begin_credit_handler;  -- Commented for 1.4.
                RETURN;
            END IF;

            populate_case_folder_details (
                p_case_folder_id     => l_case_folder_id,
                p_data_folder_id     => l_data_folder_id,
                p_data_point_name    => 'C2B_NSF',
                p_data_point_value   => p_nsf_c2b,
                p_score              => NULL,
                x_return_status      => x_return_status,
                x_message_count      => l_message_count,
                x_message_data       => x_message_data);

            IF x_return_status <> g_ret_success
            THEN
                /*  msg ('(' || x_return_status || ')' || x_message_data); */
                                                          -- Commented for 1.7
                write_to_table (
                    'Create Case Folder Details C2B_NSF Failed with Error',
                    x_message_data);
                -- ROLLBACK TO begin_credit_handler;  -- Commented for 1.4.
                RETURN;
            END IF;

            populate_case_folder_details (
                p_case_folder_id     => l_case_folder_id,
                p_data_folder_id     => l_data_folder_id,
                p_data_point_name    => 'C2B_OWNER_CHANGE',
                p_data_point_value   => p_ownershipchange,
                p_score              => NULL,
                x_return_status      => x_return_status,
                x_message_count      => l_message_count,
                x_message_data       => x_message_data);

            IF x_return_status <> g_ret_success
            THEN
                /* msg ('(' || x_return_status || ')' || x_message_data); */
                                                          -- Commented for 1.7
                write_to_table (
                    'Create Case Folder Details C2B_OWNER_CHANGE Failed with Error',
                    x_message_data);
                -- ROLLBACK TO begin_credit_handler;  -- Commented for 1.4.
                RETURN;
            END IF;

            populate_case_folder_details (
                p_case_folder_id     => l_case_folder_id,
                p_data_folder_id     => l_data_folder_id,
                p_data_point_name    => 'C2B_SCORE_DATE',
                p_data_point_value   => TO_CHAR (p_scoredate, 'DD/MM/RRRR'), -- 1.4 --TO_CHAR (p_scoredate, 'MM-DD-YYYY'),
                p_score              => NULL,
                x_return_status      => x_return_status,
                x_message_count      => l_message_count,
                x_message_data       => x_message_data);

            IF x_return_status <> g_ret_success
            THEN
                /*  msg ('(' || x_return_status || ')' || x_message_data); */
                                                          -- Commented for 1.7
                write_to_table (
                    'Create Case Folder Details C2B_SCORE_DATE Failed with Error',
                    x_message_data);
                -- ROLLBACK TO begin_credit_handler;  -- Commented for 1.4.
                RETURN;
            END IF;

            populate_case_folder_details (
                p_case_folder_id     => l_case_folder_id,
                p_data_folder_id     => l_data_folder_id,
                p_data_point_name    => 'C2B_ALERT_CODE',
                p_data_point_value   => p_alert_code,
                p_score              => NULL,
                x_return_status      => x_return_status,
                x_message_count      => l_message_count,
                x_message_data       => x_message_data);

            IF x_return_status <> g_ret_success
            THEN
                /*  msg ('(' || x_return_status || ')'); */
                                                          -- Commented for 1.7
                write_to_table (
                    'Create Case Folder Details C2B_ALERT_CODE Failed with Error',
                    x_message_data);
                -- ROLLBACK TO begin_credit_handler;  -- Commented for 1.4.
                RETURN;
            END IF;

            populate_case_folder_details (
                p_case_folder_id     => l_case_folder_id,
                p_data_folder_id     => l_data_folder_id,
                p_data_point_name    => 'C2B_MANUAL_REVIEW',
                p_data_point_value   => p_manual_review_flag,
                p_score              => NULL,
                x_return_status      => x_return_status,
                x_message_count      => l_message_count,
                x_message_data       => x_message_data);

            IF x_return_status <> g_ret_success
            THEN
                /*  msg ('(' || x_return_status || ')'); */
                                                          -- Commented for 1.7
                write_to_table (
                    'Create Case Folder Details C2B_MANUAL_REVIEW Failed with Error',
                    x_message_data);
                -- ROLLBACK TO begin_credit_handler;  -- Commented for 1.4.
                RETURN;
            END IF;

            BEGIN
                SELECT *
                  INTO l_credit_request
                  FROM ar_cmgt_credit_requests
                 WHERE credit_request_id = l_credit_request_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    x_message_data    :=
                        'Unable to locate previously created credit request id';
                    x_return_status   := g_ret_error;
            END;

            BEGIN
                SELECT case_folder_id
                  INTO l_case_folder_id
                  FROM ar_cmgt_case_folders
                 WHERE     credit_request_id = l_credit_request_id
                       AND TYPE = 'CASE';
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    x_message_data    :=
                        'Unable to locate previously created credit request id';
                    x_return_status   := g_ret_error;
            END;

            /* msg ('l_credit_request_id ' || l_credit_request_id); */
                                                          -- Commented for 1.7

            populate_recommendations (
                p_case_folder_id             => l_case_folder_id,
                p_credit_request_id          => l_credit_request_id,
                p_recommended_credit_limit   => p_assigned_credit_line, --NVL (p_assigned_credit_line,
                --p_calculated_credit_line), -- ASSIGNED_CREDIT_LINE
                p_credit_review_date         => SYSDATE,
                p_credit_recommendation      => 'CREDIT_LIMIT',
                p_recommendation_value1      => 'USD',
                p_recommendation_value2      => p_assigned_credit_line, --NVL (p_assigned_credit_line,
                --p_calculated_credit_line), -- ASSIGNED_CREDIT_LINE
                p_credit_type                => 'TRADE',
                x_return_status              => x_return_status,
                x_message_count              => l_message_count,
                x_message_data               => x_message_data);

            IF x_return_status <> g_ret_success
            THEN
                /*  msg ('(' || x_return_status || ')' || x_message_data); */
                                                          -- Commented for 1.7
                write_to_table (
                    'Create Recommendations CREDIT_LIMIT Failed with Error',
                    x_message_data);
                -- ROLLBACK TO begin_credit_handler;  -- Commented for 1.4.
                RETURN;
            END IF;


            populate_recommendations (
                p_case_folder_id             => l_case_folder_id,
                p_credit_request_id          => l_credit_request_id,
                p_recommended_credit_limit   => p_assigned_credit_line, --NVL (p_assigned_credit_line,
                --p_calculated_credit_line), -- ASSIGNED_CREDIT_LINE
                p_credit_review_date         => SYSDATE,
                p_credit_recommendation      => 'TXN_CREDIT_LIMIT',
                p_recommendation_value1      => 'USD',
                p_recommendation_value2      => p_assigned_credit_line, --NVL (p_assigned_credit_line,
                --p_calculated_credit_line), -- ASSIGNED_CREDIT_LINE
                p_credit_type                => 'TRADE',
                x_return_status              => x_return_status,
                x_message_count              => l_message_count,
                x_message_data               => x_message_data);

            IF x_return_status <> g_ret_success
            THEN
                /* msg ('(' || x_return_status || ')' || x_message_data); */
                                                          -- Commented for 1.7
                write_to_table (
                    'Create Recommendations TXN_CREDIT_LIMIT Failed with Error',
                    x_message_data);
                -- ROLLBACK TO begin_credit_handler;  -- Commented for 1.4.
                RETURN;
            END IF;
        /* -- Commented for 1.3. Implementing the Review Cycle recommendation is impacting Review Dates.
        BEGIN
           SELECT review_cycle
             INTO l_review_cycle
             FROM hz_customer_profiles
            WHERE cust_account_id = -1
                  AND party_id =
                         (SELECT party_id
                            FROM ar_cmgt_credit_requests
                           WHERE credit_request_id = l_credit_request_id);
        EXCEPTION
           WHEN OTHERS
           THEN
              l_review_cycle := NULL;
        END;

        populate_recommendations (
           p_case_folder_id             => l_case_folder_id,
           p_credit_request_id          => l_credit_request_id,
           p_recommended_credit_limit   => NVL (p_assigned_credit_line,
                                                p_calculated_credit_line),
           p_credit_review_date         => SYSDATE,
           p_credit_recommendation      => 'CHANGE_REVIEW_CYCLE',
           p_recommendation_value1      => NVL (l_review_cycle, 'YEARLY'),
           p_recommendation_value2      => NULL,
           p_credit_type                => 'TRADE',
           x_return_status              => x_return_status,
           x_message_count              => l_message_count,
           x_message_data               => x_message_data);

        IF x_return_status <> g_ret_success
        THEN
           msg ('(' || x_return_status || ')' || x_message_data);
           write_to_table (
              'Create Recommendations CHANGE_REVIEW_CYCLE Failed with Error',
              x_message_data);
           ROLLBACK TO begin_credit_handler;
           RETURN;
        END IF;
       */
        -- Commented for 1.3. Implementing the Review Cycle recommendation is impacting Review Dates.

        END IF;


        IF UPPER (p_manual_review_flag) = 'YES'
        THEN
            initiate_manual_review (
                p_case_folder_id      => l_case_folder_id,
                p_credit_request_id   => l_credit_request_id,
                p_agent               => p_agent,
                x_return_status       => x_return_status,
                x_message_count       => l_message_count,
                x_message_data        => x_message_data);

            BEGIN
                SELECT RESOURCE_ID
                  INTO l_credit_analyst_id
                  FROM jtf_rs_resource_extns
                 --   WHERE SOURCE_NAME = p_agent; --W.r.t Version 1.8
                 WHERE     UPPER (
                               SOURCE_FIRST_NAME || ' ' || SOURCE_LAST_NAME) =
                           UPPER (p_agent)                 --W.r.t Version 1.8
                       AND SYSDATE BETWEEN NVL (START_DATE_ACTIVE, SYSDATE)
                                       AND NVL (END_DATE_ACTIVE, SYSDATE); -- Added for INC0349657
            EXCEPTION
                WHEN TOO_MANY_ROWS
                THEN
                    write_to_table (
                        'Too many analysts found for customer request',
                        SQLERRM);
                    x_message_data    :=
                        'Too many analysts found for customer request';
                    x_return_status   := g_ret_error;
                    RETURN;
                WHEN NO_DATA_FOUND
                THEN
                    write_to_table (
                        'No customer profile found for credit request',
                        SQLERRM);
                    x_message_data        :=
                        'No customer profile found for credit request';
                    x_return_status       := g_ret_error;
                    l_credit_analyst_id   := NULL;
                    RETURN;
            END;

            /*msg (' Update Credit Analyst ', 1);*/
                                                          -- Commented for 1.7

            UPDATE ar_cmgt_case_folders
               SET credit_analyst_id = l_credit_analyst_id, status = 'CREATED' --'SAVED' Raja
             WHERE credit_request_id = l_credit_request_id;

            /*msg ('Rows Updated 2 :: ' || SQL%ROWCOUNT, 1);*/
                                                          -- Commented for 1.7

            COMMIT;
        /* msg ('Entered Manual Review as Yes', 1);*/
                                                          -- Commented for 1.7
        ELSIF UPPER (p_manual_review_flag) = 'NO'
        THEN
            BEGIN
                implement_recommendations (
                    p_case_folder_id           => l_case_folder_id,
                    p_customer_number          => p_customer_number,
                    p_reviewdate               => p_review_date,
                    p_credit_request_id        => l_credit_request_id,
                    p_scoredate                => p_scoredate,
                    p_credit_score             => p_credit_score,
                    p_agent                    => p_agent,
                    p_assigned_credit_line     => p_assigned_credit_line, --NVL (p_assigned_credit_line,
                    --p_calculated_credit_line), -- ASSIGNED_CREDIT_LINE
                    p_calculated_credit_line   => p_calculated_credit_line,
                    x_return_status            => x_return_status,
                    x_message_count            => l_message_count,
                    x_message_data             => x_message_data);
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_to_table (
                        'Implement Recommendations Failed with Error',
                        x_message_data);
            /*  msg ('Error in Implement Recommendations :: ' || SQLERRM, 1); */
                                                          -- Commented for 1.7
            END;

            BEGIN
                SELECT RESOURCE_ID
                  INTO l_credit_analyst_id
                  FROM jtf_rs_resource_extns
                 -- WHERE SOURCE_NAME = p_agent;  --W.r.t Version 1.8
                 WHERE     UPPER (
                               SOURCE_FIRST_NAME || ' ' || SOURCE_LAST_NAME) =
                           UPPER (p_agent)                 --W.r.t Version 1.8
                       AND SYSDATE BETWEEN NVL (START_DATE_ACTIVE, SYSDATE)
                                       AND NVL (END_DATE_ACTIVE, SYSDATE); -- Added for INC0349657
            EXCEPTION
                WHEN TOO_MANY_ROWS
                THEN
                    write_to_table (
                        'Too many analysts found for customer request',
                        SQLERRM);
                    x_message_data    :=
                        'Too many analysts found for customer request';
                    x_return_status   := g_ret_error;
                    RETURN;
                WHEN NO_DATA_FOUND
                THEN
                    write_to_table (
                        'No customer profile found for credit request',
                        SQLERRM);
                    x_message_data        :=
                        'No customer profile found for credit request';
                    x_return_status       := g_ret_error;
                    l_credit_analyst_id   := NULL;
                    RETURN;
            END;

            /* msg (' Update Credit Analyst ', 1); */
                                                          -- Commented for 1.7

            UPDATE ar_cmgt_case_folders
               SET credit_analyst_id = l_credit_analyst_id, status = 'CLOSED' -- 'SUBMITTED' -- Modified for 1.7
             WHERE credit_request_id = l_credit_request_id;

            COMMIT;

            UPDATE ar_cmgt_credit_requests
               SET status   = 'PROCESSED'      -- 'SUBMIT' -- Modified for 1.7
             WHERE credit_request_id = l_credit_request_id;

            COMMIT;

            UPDATE ar_cmgt_cf_recommends
               SET status   = 'I'
             WHERE credit_request_id = l_credit_request_id;

            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_status   := g_ret_unexp_error;
            x_message_data    := SQLERRM;
            write_to_table ('Error in Procedure', x_message_data);
    /*  msg (
            ' ERROR in procedure '
         || lv_pn
         || ' : '
         || x_return_status
         || x_message_data,
         1); */
    -- Commented for 1.7
    END credit_handler;
END;
/


GRANT EXECUTE ON APPS.XXDOAR_CREDIT_INB_PKG TO SOA_INT
/
