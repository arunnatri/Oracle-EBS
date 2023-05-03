--
-- XXDO_AR_CUST_COLL_CA_UPD_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:20 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_AR_CUST_COLL_CA_UPD_PKG"
AS
    /******************************************************************************
    -- NAME:      XXDO_AR_CUST_COLL_CA_UPD_PKG
    -- PURPOSE:   To define procedures used for updating collector and credit analyst name for customers
    -- REVISIONS:
    -- Ver      Date          Author          Description
    -- -----    ----------    -------------   -----------------------------------
    -- 1.0      26-FEB-2017    Infosys         Initial version
    ******************************************************************************/
    -- global variables
    g_request_id     NUMBER := 0;
    g_process_type   VARCHAR2 (100);

    -- Procedure to update COLLECTOR
    PROCEDURE xxdoar_upd_coll_ca
    IS
        -- Cursor to fetch records for COLLECTOR and CREDIT ANALYST update
        CURSOR c_upd_collector IS
            SELECT *
              FROM XXDO_AR_CUST_COLL_AND_CA_UPD
             WHERE     request_id = g_request_id
                   AND status_flag = 'NEW'
                   AND error_description IS NULL;

        --
        -- Local Variable declaration
        lv_row_id                     ROWID := NULL;
        lv_cust_profle_id             NUMBER;
        lv_collector_name             VARCHAR2 (30);
        lv_cust_account_id            NUMBER;
        lv_party_id                   NUMBER;
        lv_collector_id               NUMBER;
        lv_credit_analyst_id          NUMBER;
        lv_credit_analyst             VARCHAR2 (360);
        lv_chr_error_message          VARCHAR2 (4000);
        lv_chr_error_code             VARCHAR2 (20);
        lv_total_count                NUMBER;
        lv_success_count              NUMBER;
        lv_error_count                NUMBER;
        l_chr_create_profile          VARCHAR2 (1);
        p_customer_profile_rec_type   HZ_CUSTOMER_PROFILE_V2PUB.CUSTOMER_PROFILE_REC_TYPE;
        x_return_status               VARCHAR2 (2000);
        x_msg_count                   NUMBER;
        x_msg_data                    VARCHAR2 (2000);
        x_cust_account_profile_id     NUMBER;
        l_party_id                    NUMBER;
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'Inside xxdoar_upd_coll_ca procedure ');
        --
        --
        lv_success_count   := 0;
        lv_error_count     := 0;

        --
        --
        FOR rec_collector_upd IN c_upd_collector
        LOOP
            BEGIN
                lv_chr_error_code      := NULL;
                lv_chr_error_message   := NULL;
                lv_cust_profle_id      := NULL;
                lv_collector_name      := NULL;
                lv_collector_id        := NULL;
                lv_cust_account_id     := NULL;
                lv_row_id              := NULL;
                lv_party_id            := NULL;
                lv_credit_analyst_id   := NULL;
                lv_credit_analyst      := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                    '------------------------------------------------------------------------------');

                -- Collector Update at Account level
                IF     rec_collector_upd.collector_level IS NOT NULL
                   AND rec_collector_upd.collector_name IS NOT NULL
                THEN
                    fnd_file.put_line (fnd_file.LOG, ' ');
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'update collector at account level for customer ::'
                        || rec_collector_upd.account_number);

                    BEGIN
                        --
                        --
                        SELECT hcp.ROWID, hcp.cust_account_profile_id, hca.cust_account_id,
                               arc.name, hzp.party_id
                          INTO lv_row_id, lv_cust_profle_id, lv_cust_account_id, lv_collector_name,
                                        lv_party_id
                          FROM hz_cust_accounts_all hca, hz_parties hzp, hz_customer_profiles hcp,
                               ar_collectors arc
                         WHERE     hca.cust_account_id = hcp.cust_account_id
                               AND hcp.site_use_id IS NULL
                               AND hzp.party_id = hcp.party_id
                               AND hca.account_number =
                                   rec_collector_upd.account_number
                               AND arc.collector_id = hcp.collector_id
                               AND arc.status = 'A'
                               AND hca.status = 'A'
                               AND hcp.status = 'A'
                               AND hzp.status = 'A';

                        --
                        --
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Current collector name ::' || lv_collector_name);
                    --
                    --
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error in fetching customer/profile details ::'
                                || SQLERRM);
                            lv_chr_error_code   := 'ERROR';
                            lv_chr_error_message   :=
                                   'Error in fetching customer/profile details ::'
                                || SQLERRM;
                    END;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Collector name to be updated ::'
                        || rec_collector_upd.collector_name);

                    --
                    --


                    BEGIN
                        --
                        --
                        SELECT arc.collector_id
                          INTO lv_collector_id
                          FROM ar_collectors arc
                         WHERE arc.name = rec_collector_upd.collector_name;
                    --
                    --
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            lv_collector_id     := NULL;
                            lv_chr_error_code   := 'ERROR';
                            lv_chr_error_message   :=
                                   lv_chr_error_message
                                || '   '
                                || 'Collector '
                                || rec_collector_upd.collector_name
                                || ' is not setup';
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Collector '
                                || rec_collector_upd.collector_name
                                || ' is not setup');
                        WHEN OTHERS
                        THEN
                            lv_collector_id     := NULL;
                            lv_chr_error_code   := 'ERROR';
                            lv_chr_error_message   :=
                                   lv_chr_error_message
                                || '   '
                                || 'Error in fetching collector id for  ::'
                                || rec_collector_upd.collector_name
                                || ' '
                                || SQLERRM;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error in fetching collector id for  ::'
                                || rec_collector_upd.collector_name
                                || ' '
                                || SQLERRM);
                    END;

                    --
                    --
                    --
                    --
                    IF lv_chr_error_code IS NULL
                    THEN
                        BEGIN
                            --
                            --
                            hz_customer_profiles_pkg.update_row (
                                x_rowid                          => lv_row_id,
                                x_cust_account_profile_id        =>
                                    lv_cust_profle_id,
                                x_cust_account_id                => lv_cust_account_id,
                                x_status                         => NULL,
                                x_collector_id                   => lv_collector_id,
                                x_credit_analyst_id              => NULL,
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
                                x_party_id                       => lv_party_id,
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
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'updated collector sucessfully');
                        --
                        --
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
                                    || '   '
                                    || 'Error while executing API';
                        END;
                    ELSE
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error in deriving details required for update ::'
                            || lv_chr_error_message);
                    END IF;
                --
                --
                END IF;

                --
                --
                lv_row_id              := NULL;
                lv_cust_profle_id      := NULL;
                lv_cust_account_id     := NULL;
                lv_collector_name      := NULL;
                lv_party_id            := NULL;
                lv_credit_analyst      := NULL;

                --
                --
                -- Credit Analyst Update at Account Level
                IF     rec_collector_upd.credit_analyst_level IS NOT NULL
                   AND rec_collector_upd.credit_analyst IS NOT NULL
                   AND lv_chr_error_code IS NULL
                   AND (rec_collector_upd.credit_analyst_level = 'ACCOUNT' OR rec_collector_upd.credit_analyst_level = 'BOTH')
                THEN
                    fnd_file.put_line (fnd_file.LOG, ' ');
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'update credit analyst at account level for customer ::'
                        || rec_collector_upd.account_number);

                    BEGIN
                        --
                        --
                        SELECT hcp.ROWID, hcp.cust_account_profile_id, hca.cust_account_id,
                               arc.name, hzp.party_id, jrre.source_name
                          INTO lv_row_id, lv_cust_profle_id, lv_cust_account_id, lv_collector_name,
                                        lv_party_id, lv_credit_analyst
                          FROM hz_cust_accounts_all hca, hz_parties hzp, hz_customer_profiles hcp,
                               ar_collectors arc, jtf_rs_resource_extns jrre
                         WHERE     hca.cust_account_id = hcp.cust_account_id
                               AND hcp.site_use_id IS NULL
                               AND hzp.party_id = hcp.party_id
                               AND hca.account_number =
                                   rec_collector_upd.account_number
                               AND arc.collector_id = hcp.collector_id
                               AND hcp.cust_account_id <> '-1'
                               AND hcp.site_use_id IS NULL
                               AND arc.status = 'A'
                               AND hca.status = 'A'
                               AND hcp.status = 'A'
                               AND hzp.status = 'A'
                               AND hcp.CREDIT_ANALYST_ID =
                                   jrre.resource_id(+);

                        --
                        --
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Current credit analyst name ::'
                            || lv_credit_analyst);
                    --
                    --
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error in fetching customer/profile details ::'
                                || SQLERRM);
                            lv_chr_error_code   := 'ERROR';
                            lv_chr_error_message   :=
                                   'Error in fetching customer/profile details ::'
                                || SQLERRM;
                    END;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Credit Analyst name to be updated ::'
                        || rec_collector_upd.credit_analyst);

                    --
                    --
                    BEGIN
                        --
                        --
                        SELECT resource_id
                          INTO lv_credit_analyst_id
                          FROM jtf_rs_resource_extns
                         WHERE     source_name =
                                   rec_collector_upd.credit_analyst
                               AND SYSDATE BETWEEN START_DATE_ACTIVE
                                               AND NVL (end_date_active,
                                                        SYSDATE + 1);
                    --
                    --
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            lv_credit_analyst_id   := NULL;
                            lv_chr_error_code      := 'ERROR';
                            lv_chr_error_message   :=
                                   lv_chr_error_message
                                || '   '
                                || 'Credit Rep '
                                || rec_collector_upd.credit_analyst
                                || ' is not setup';
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Credit Rep '
                                || rec_collector_upd.credit_analyst
                                || ' is not setup');
                        WHEN OTHERS
                        THEN
                            lv_credit_analyst_id   := NULL;
                            lv_chr_error_code      := 'ERROR';
                            lv_chr_error_message   :=
                                   lv_chr_error_message
                                || '   '
                                || 'Error in fetching Credit Rep id for  ::'
                                || rec_collector_upd.credit_analyst
                                || ' '
                                || SQLERRM;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error in fetching Credit Rep id for  ::'
                                || rec_collector_upd.credit_analyst
                                || ' '
                                || SQLERRM);
                    END;

                    --
                    --
                    IF lv_chr_error_code IS NULL
                    THEN
                        BEGIN
                            --
                            --
                            hz_customer_profiles_pkg.update_row (
                                x_rowid                          => lv_row_id,
                                x_cust_account_profile_id        =>
                                    lv_cust_profle_id,
                                x_cust_account_id                => lv_cust_account_id,
                                x_status                         => NULL,
                                x_collector_id                   => NULL,
                                x_credit_analyst_id              => lv_credit_analyst_id,
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
                                x_party_id                       => lv_party_id,
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
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'updated Credit analyst at Account level sucessfully');
                        --
                        --
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
                                    || '   '
                                    || 'Error while executing API';
                        END;
                    ELSE
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error in deriving details required for update ::'
                            || lv_chr_error_message);
                    END IF;
                --
                --
                END IF;

                -- Credit Analyst Update at Party Level
                --
                --
                lv_row_id              := NULL;
                lv_cust_profle_id      := NULL;
                lv_cust_account_id     := NULL;
                lv_collector_name      := NULL;
                lv_party_id            := NULL;
                lv_credit_analyst      := NULL;

                --
                --
                IF     rec_collector_upd.credit_analyst_level IS NOT NULL
                   AND rec_collector_upd.credit_analyst IS NOT NULL
                   AND lv_chr_error_code IS NULL
                   AND (rec_collector_upd.credit_analyst_level = 'PARTY' OR rec_collector_upd.credit_analyst_level = 'BOTH')
                THEN
                    --
                    --Check for profile at party level
                    BEGIN
                        --
                        --
                        BEGIN
                            l_party_id   := NULL;

                            SELECT PARTY_ID
                              INTO l_party_id
                              FROM hz_cust_accounts_all hca
                             WHERE     hca.account_number =
                                       rec_collector_upd.account_number
                                   AND hca.status = 'A';
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Customer is not setup ::' || SQLERRM);
                                l_party_id          := NULL;
                                lv_chr_error_code   := 'ERROR';
                                lv_chr_error_message   :=
                                    'Customer is not setup ::' || SQLERRM;
                        END;

                        --
                        --
                        IF lv_chr_error_code IS NULL
                        THEN
                            BEGIN
                                --
                                --
                                l_chr_create_profile   := 'Y';

                                --
                                --
                                SELECT 'N'
                                  INTO l_chr_create_profile
                                  FROM hz_parties hzp, hz_customer_profiles hcp, hz_cust_accounts_all hca
                                 WHERE     hzp.party_id = hca.party_id
                                       AND hcp.party_id = hzp.party_id
                                       AND hca.status = 'A'
                                       AND hcp.status = 'A'
                                       AND hzp.status = 'A'
                                       AND hcp.cust_account_id = '-1'
                                       AND hca.account_number =
                                           rec_collector_upd.account_number
                                       AND hcp.site_use_id IS NULL;
                            --
                            --
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    l_chr_create_profile   := 'Y';
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Error in getting customer details to create profile ::'
                                        || SQLERRM);
                                    lv_chr_error_code   := 'ERROR';
                                    lv_chr_error_message   :=
                                           'Error in getting customer details to create profile ::'
                                        || SQLERRM;
                            END;
                        END IF;

                        --
                        --
                        IF     l_chr_create_profile = 'Y'
                           AND lv_chr_error_code IS NULL
                        THEN
                            fnd_file.put_line (fnd_file.LOG, ' ');
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Customer profile not set at party level so creating customer Profile at Party level for customer ::'
                                || rec_collector_upd.account_number);

                            --
                            --
                            BEGIN
                                p_customer_profile_rec_type.party_id   :=
                                    l_party_id;
                                p_customer_profile_rec_type.created_by_module   :=
                                    'HZ_CPUI';
                                --
                                --
                                HZ_CUSTOMER_PROFILE_V2PUB.create_customer_profile (
                                    'T',
                                    p_customer_profile_rec_type,
                                    'T',
                                    x_cust_account_profile_id,
                                    x_return_status,
                                    x_msg_count,
                                    x_msg_data);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'x_cust_account_profile_id: '
                                    || x_cust_account_profile_id);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'x_return_status: ' || x_return_status);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'x_msg_count: ' || x_msg_count);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'x_msg_data: ' || x_msg_data);
                            --
                            --
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Error in creating profile at part level ::'
                                        || SQLERRM);
                                    lv_chr_error_code   := 'ERROR';
                                    lv_chr_error_message   :=
                                           'Error in creating profile at part level ::'
                                        || SQLERRM;
                            END;
                        --
                        --
                        END IF;
                    --
                    --
                    --
                    --
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error in creating profile at party level ::'
                                || SQLERRM);
                            lv_chr_error_code   := 'ERROR';
                            lv_chr_error_message   :=
                                   'Error in creating profile at party level ::'
                                || SQLERRM;
                    END;

                    --
                    --
                    BEGIN
                        fnd_file.put_line (fnd_file.LOG, ' ');
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'update credit analyst at Party level for customer ::'
                            || rec_collector_upd.account_number);

                        --
                        --
                        SELECT hcp.ROWID, hcp.cust_account_profile_id, hca.cust_account_id,
                               arc.name, hzp.party_id, jrre.source_name
                          INTO lv_row_id, lv_cust_profle_id, lv_cust_account_id, lv_collector_name,
                                        lv_party_id, lv_credit_analyst
                          FROM hz_cust_accounts_all hca, hz_parties hzp, hz_customer_profiles hcp,
                               ar_collectors arc, jtf_rs_resource_extns jrre
                         WHERE     hca.party_id = hcp.party_id
                               AND hcp.site_use_id IS NULL
                               AND hzp.party_id = hcp.party_id
                               AND hca.account_number =
                                   rec_collector_upd.account_number
                               AND arc.collector_id = hcp.collector_id
                               AND hcp.cust_account_id = '-1'
                               AND arc.status = 'A'
                               AND hca.status = 'A'
                               AND hcp.status = 'A'
                               AND hzp.status = 'A'
                               AND hcp.CREDIT_ANALYST_ID =
                                   jrre.resource_id(+);

                        --
                        --
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Current credit analyst name ::'
                            || lv_credit_analyst);
                    --
                    --
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error in fetching customer/profile details ::'
                                || SQLERRM);
                            lv_chr_error_code   := 'ERROR';
                            lv_chr_error_message   :=
                                   'Error in fetching customer/profile details ::'
                                || SQLERRM;
                    END;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Credit Analyst name to be updated ::'
                        || rec_collector_upd.credit_analyst);

                    --
                    --
                    BEGIN
                        --
                        --
                        SELECT resource_id
                          INTO lv_credit_analyst_id
                          FROM jtf_rs_resource_extns
                         WHERE     source_name =
                                   rec_collector_upd.credit_analyst
                               AND SYSDATE BETWEEN START_DATE_ACTIVE
                                               AND NVL (end_date_active,
                                                        SYSDATE + 1);
                    --
                    --
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            lv_credit_analyst_id   := NULL;
                            lv_chr_error_code      := 'ERROR';
                            lv_chr_error_message   :=
                                   lv_chr_error_message
                                || '   '
                                || 'Credit Rep '
                                || rec_collector_upd.credit_analyst
                                || ' is not setup';
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Credit Rep '
                                || rec_collector_upd.credit_analyst
                                || ' is not setup');
                        WHEN OTHERS
                        THEN
                            lv_credit_analyst_id   := NULL;
                            lv_chr_error_code      := 'ERROR';
                            lv_chr_error_message   :=
                                   lv_chr_error_message
                                || '   '
                                || 'Error in fetching Credit Rep id for  ::'
                                || rec_collector_upd.credit_analyst
                                || ' '
                                || SQLERRM;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error in fetching Credit Rep id for  ::'
                                || rec_collector_upd.credit_analyst
                                || ' '
                                || SQLERRM);
                    END;

                    --
                    --
                    --
                    --
                    IF lv_chr_error_code IS NULL
                    THEN
                        BEGIN
                            --
                            --
                            hz_customer_profiles_pkg.update_row (
                                x_rowid                          => lv_row_id,
                                x_cust_account_profile_id        =>
                                    lv_cust_profle_id,
                                x_cust_account_id                => NULL,
                                x_status                         => NULL,
                                x_collector_id                   => NULL,
                                x_credit_analyst_id              => lv_credit_analyst_id,
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
                                x_party_id                       => lv_party_id,
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
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'updated Credit analyst at Party level sucessfully');
                        --
                        --
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
                                    || '   '
                                    || 'Error while executing API';
                        END;
                    ELSE
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error in deriving details required for update ::'
                            || lv_chr_error_message);
                    END IF;
                --
                --
                END IF;

                --
                --
                --Update success and error record details
                IF lv_chr_error_code = 'ERROR'
                THEN
                    --
                    UPDATE XXDO_AR_CUST_COLL_AND_CA_UPD
                       SET status_flag = 'ERROR', error_description = lv_chr_error_message, last_update_date = SYSDATE,
                           last_updated_by = fnd_global.user_id
                     WHERE     request_id = g_request_id
                           AND account_number =
                               rec_collector_upd.account_number;
                --
                --
                ELSE
                    UPDATE XXDO_AR_CUST_COLL_AND_CA_UPD
                       SET status_flag = 'SUCCESS', error_description = NULL, last_update_date = SYSDATE,
                           last_updated_by = fnd_global.user_id
                     WHERE     request_id = g_request_id
                           AND account_number =
                               rec_collector_upd.account_number;
                END IF;

                COMMIT;
                --
                fnd_file.put_line (
                    fnd_file.LOG,
                    '------------------------------------------------------------------------------');
            --

            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error in loop -' || SQLERRM);
                    lv_chr_error_code   := 'ERROR';
                    lv_chr_error_message   :=
                        lv_chr_error_message || '   ' || 'Error in loop';
            END;
        END LOOP;

        --
        --
        BEGIN
            SELECT COUNT (*)
              INTO lv_total_count
              FROM XXDO_AR_CUST_COLL_AND_CA_UPD
             WHERE request_id = g_request_id;

            fnd_file.put_line (
                fnd_file.LOG,
                'Count of records to be processed ::' || lv_total_count);
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error in fetching count of records to be processed ::'
                    || SQLERRM);
        END;

        --
        --
        BEGIN
            SELECT COUNT (*)
              INTO lv_success_count
              FROM XXDO_AR_CUST_COLL_AND_CA_UPD
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
              FROM XXDO_AR_CUST_COLL_AND_CA_UPD
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
                           'Exiting xxdoar_upd_coll_ca procedure ');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Error in xxdoar_upd_coll_ca procedure :' || SQLERRM);
    END xxdoar_upd_coll_ca;

    --
    --
    -- Main procedure
    /*******************************************************************************
    -- Name:                MAIN
    -- Type:                PROCEDURE
    -- Description:         Main procedure to be called from concurrent program
    --                      to update collector name
    *******************************************************************************/
    PROCEDURE main_proc (errbuf       OUT NOCOPY VARCHAR2,
                         retcode      OUT NOCOPY NUMBER)
    IS
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Inside main procedure...');
        g_request_id   := fnd_global.conc_request_id;

        --
        --
        BEGIN
            UPDATE XXDO_AR_CUST_COLL_AND_CA_UPD
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

        -- Call procedure to update COLLECTOR
        xxdoar_upd_coll_ca;
        --
        fnd_file.put_line (fnd_file.LOG, 'Exiting main procedure...');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Error in main procedure :' || SQLERRM);
    END main_proc;
END XXDO_AR_CUST_COLL_CA_UPD_PKG;
/
