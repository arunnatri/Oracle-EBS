--
-- XXDO_IEX_SCORING_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:54 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_IEX_SCORING_PKG"
AS
    /*******************************************************************************
    * Program Name : XXDO_IEX_SCORING_PKG
    * Language     : PL/SQL
    * Description  : This package will generateScore for given cust_account_id and for ADL Concurrent program
       * Modification :
    -- ======================================================================================
    -- Date          Version#     Name                              Comments
    -- ======================================================================================
    -- 29-SEP-2014   1.0          BT Technology Team                Initial Version
    -- 24-DEC-2014   1.1          BT Technology Team                New MD050
    -- 27-OCT-2015   1.2          BT Technology Team                Defect# 170
    -- 09-NOV-2016   1.2          Madhav Dhurjaty                   Canada 3PL Project
    -- 07-NOV-2016   1.3          Srinath Siricilla                 Switzerland Project
    -- 14-MAR-2017   1.4          Infosys                           Changes in populate_adl procedure to fix the deadlock error and also to insert the
                                                                    attribute1 (brand-mandatory column) to custom table while calling insert_update procedure
    -- 11-APR-2018   1.5          Srinath Siricilla                 CCR0007180
    -- 01-AUG-2022   2.0          Srinath Siricilla                 CCR0009857
    -- 06-JAN-2023   2.1          Kishan Reddy                      CCR0009817: To update the AR
    --                                                              collection data fro DAP OU
    ******************************************************************************************/

    gc_module                       VARCHAR2 (100) := 'XXDO_IEX_SCORING_PKG';
    gn_user_id                      NUMBER := fnd_global.user_id;
    gn_resp_id                      NUMBER := fnd_global.resp_id;
    gn_resp_appl_id                 NUMBER := fnd_global.resp_appl_id;
    gd_sysdate                      DATE := SYSDATE;
    gc_code_pointer                 VARCHAR2 (500);
    gc_default_aging_bucket         VARCHAR2 (10);
    gc_score_component1             VARCHAR2 (30) := 'AGING_WATERFALL';
    gc_risk_component1              VARCHAR2 (30) := 'LAST_PAYMENT';
    gc_risk_component2              VARCHAR2 (30) := 'BOOKED_ORDERS';
    gc_risk_component3              VARCHAR2 (30) := 'ADL_TREND';
    gc_exception_flag               VARCHAR2 (1) := 'N';
    gn_org_id                       NUMBER;
    gc_ao_days                      NUMBER; --Days between request date and order date in AT ONCE Order
    gn_gl_first_quarter             NUMBER := 1;
    gn_gl_Last_quarter              NUMBER := 4;
    gn_adl_rolling_days             NUMBER;
    gn_booked_order_default_score   NUMBER;                                 --
    gn_cust_account_id              NUMBER;
    gc_log_profile_value            VARCHAR2 (1);
    gc_all_brand_code               VARCHAR2 (20);
    gc_insert_check                 VARCHAR2 (1);
    --  gn_dist_low_cutoff_score        NUMBER := 100;
    --  gn_dist_high_cutoff_score       NUMBER := 50;
    --  gn_jpn_low_score                NUMBER := 100;
    --  gn_jpn_mod_score                NUMBER := 50;
    --  gn_jpn_hard1_score              NUMBER := 20;
    --  gn_jpn_hard2_score              NUMBER := 10;
    gc_deckers_bucket_name          VARCHAR2 (100)
        := FND_PROFILE.VALUE ('IEX_COLLECTIONS_BUCKET_NAME');

    --  gn_ecomm_score                  NUMBER := 50;


    PROCEDURE SET_ORG_ID
    IS
        CURSOR get_org_id_c IS
            SELECT DISTINCT fpov.profile_option_value
              FROM applsys.fnd_profile_option_values fpov, applsys.fnd_profile_options fpo, applsys.fnd_profile_options fpot,
                   applsys.fnd_responsibility fr
             WHERE     1 = 1
                   AND fpo.profile_option_name = fpot.profile_option_name
                   AND fpo.profile_option_id = fpov.profile_option_id
                   AND fr.responsibility_id(+) = fpov.level_value
                   AND fr.responsibility_id = fnd_global.resp_id
                   AND fpot.profile_option_name = 'ORG_ID';
    BEGIN
        OPEN get_org_id_c;

        FETCH get_org_id_c INTO gn_org_id;

        CLOSE get_org_id_c;

        mo_global.set_policy_context ('S', gn_org_id);
        mo_global.init ('IEX');
    END SET_ORG_ID;



    /*******************************************************************************
    * Funtion Name : get_score_us
    * Description  : This Function will generate and return the final mapped score
    *                for a given cust_account_id
    * Parameters   :P_CUST_ACCOUNT_ID
                   :P_SCORE_COMPONENT_ID
    * --------------------------------------------------------------------------- */

    FUNCTION get_score_us (P_CUST_ACCOUNT_ID      IN NUMBER,
                           P_SCORE_COMPONENT_ID   IN NUMBER)
        RETURN NUMBER
    IS
        ln_score                 NUMBER := 0;
        ln_aging_bucket_score    NUMBER := 0;
        ln_aging_bucket_wt       NUMBER := 0;
        ln_last_payment_score    NUMBER := 0;
        ln_last_payment_wt       NUMBER := 0;
        ln_book_order_score      NUMBER := 0;
        ln_book_order_wt         NUMBER := 0;
        ln_adl_score             NUMBER := 0;
        ln_adl_wt                NUMBER := 0;
        lc_prorate_score         VARCHAR2 (1);
        ln_mapped_score          NUMBER := 0;
        lc_use_weight            VARCHAR2 (1);
        -- Start of Changes for CCR0007180
        ln_aging_bucket_wt_new   NUMBER := 0;
        ln_last_payment_wt_new   NUMBER := 0;
        ln_book_order_wt_new     NUMBER := 0;
        ln_adl_wt_new            NUMBER := 0;

        -- End of Changes for CCR0007180

        CURSOR insert_update_c (p_cust_acc_id IN NUMBER)
        IS
            SELECT DECODE (COUNT (*), 0, 'Y', 'N')
              FROM xxd_iex_metrics_tbl
             WHERE cust_account_id = p_cust_acc_id AND org_id = gn_org_id;
    --and cust_account_id = 1255459727;

    BEGIN
        SET_ORG_ID;

        --xxv_debug_prc('Flow Started - Test US');

        gn_cust_account_id       := P_CUST_ACCOUNT_ID;
        gc_log_profile_value     :=
            NVL (apps.fnd_profile.VALUE ('XXDO_GEH_LOG_ENABLE'), 'N');
        gc_exception_flag        := 'N';
        gc_log_profile_value     := 'Y';

        --xxv_debug_prc('Cust Account ID is - '||gn_cust_account_id);

        LOG (
            p_module        => 'get_score_us',
            p_line_number   => NULL,
            p_log_message   =>
                ' Start Scoring for Account : ' || P_CUST_ACCOUNT_ID);

        ln_aging_bucket_score    :=
            get_aging_bucket_avg_score_us (P_CUST_ACCOUNT_ID);

        LOG (
            p_module        => 'get_score_us',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_score_us  Aging Bucket Score : '
                || ln_aging_bucket_score);



        LOG (
            p_module        => 'get_score_us',
            p_line_number   => NULL,
            p_log_message   =>
                ' get_score_us  Aging Bucket  : ' || v_aging_bucket);

        LOG (
            p_module        => 'get_score_us',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_score_us  Global Default Aging Bucket  : '
                || gc_default_aging_bucket);
        lc_use_weight            :=
            NVL (apps.fnd_profile.VALUE ('XXDO_IEX_USE_WEIGHT'), 'N');


        -- Start of Changes for CCR0007180
        ln_aging_bucket_wt_new   := get_Weight (gc_score_component1); --'AGING_WATERFALL'
        ln_last_payment_wt_new   := get_Weight (gc_risk_component1); --'LAST_PAYMENT'
        ln_book_order_wt_new     := get_Weight (gc_risk_component2); --'BOOKED_ORDERS'
        ln_adl_wt_new            := get_Weight (gc_risk_component3); --'ADL_TREND'
        -- End of Changes for CCR0007180

        LOG (p_module        => 'get_score_us',
             p_line_number   => NULL,
             p_log_message   => 'lc_use_weight : ' || lc_use_weight);

        IF lc_use_weight <> 'N'
        THEN
            -- xxv_debug_prc('Cust Account ID and Weight - '||gn_cust_account_id|| ' - '||lc_use_weight);
            IF v_aging_bucket <> gc_default_aging_bucket
            THEN
                --xxv_debug_prc('Cust Account ID and v_aging_bucket - '||gn_cust_account_id|| ' - '||v_aging_bucket);
                --xxv_debug_prc('Cust Account ID and gc_default_aging_bucket - '||gn_cust_account_id|| ' - '||gc_default_aging_bucket);

                LOG (
                    p_module        => 'get_score_us',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' get_score_us  Aging Bucket is not  Global Default Aging Bucket');


                ln_last_payment_score   :=
                    get_last_payment_score (P_CUST_ACCOUNT_ID);

                LOG (
                    p_module        => 'get_score_us',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_us  Last Payment Score : '
                        || ln_last_payment_score);



                ln_book_order_score   :=
                    get_booked_order_score (P_CUST_ACCOUNT_ID);

                LOG (
                    p_module        => 'get_score_us',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_us  Booked Order Score : '
                        || ln_book_order_score);



                ln_adl_score         := get_adl_score (P_CUST_ACCOUNT_ID);

                LOG (
                    p_module        => 'get_score_us',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' get_score_us  ADL Score : ' || ln_adl_score);


                ln_aging_bucket_wt   := get_Weight (gc_score_component1); --'AGING_WATERFALL'

                LOG (
                    p_module        => 'get_score_us',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_us  Aging Bucket Wt : '
                        || ln_aging_bucket_wt);



                ln_last_payment_wt   := get_Weight (gc_risk_component1); --'LAST_PAYMENT'
                LOG (
                    p_module        => 'get_score_us',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_us  Last Payment Wt : '
                        || ln_last_payment_wt);



                ln_book_order_wt     := get_Weight (gc_risk_component2); --'BOOKED_ORDERS'

                LOG (
                    p_module        => 'get_score_us',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_us  Booked Order Wt : '
                        || ln_book_order_wt);


                ln_adl_wt            := get_Weight (gc_risk_component3); --'ADL_TREND'
                LOG (
                    p_module        => 'get_score_us',
                    p_line_number   => NULL,
                    p_log_message   => ' get_score_us  ADL Wt : ' || ln_adl_wt);


                lc_prorate_score     :=
                    NVL (apps.fnd_profile.VALUE ('XXDO_IEX_PRORATE_SCORE'),
                         'N');

                LOG (
                    p_module        => 'get_score_us',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_us  Pro-Rate profile : '
                        || lc_prorate_score);



                ln_score             :=
                    caluclate_score (ln_aging_bucket_score, ln_aging_bucket_wt, ln_last_payment_score, ln_last_payment_wt, ln_book_order_score, ln_book_order_wt, ln_adl_score, ln_adl_wt, lc_prorate_score
                                     , lc_use_weight); -- Added for CCR0007180
            ELSE
                LOG (
                    p_module        => 'get_score_us',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' get_score_us  Only Aging Bucket default score is considered if amount due remaining is 0');
                --xxv_debug_prc('Else Cust Account ID and v_aging_bucket - '||gn_cust_account_id|| ' - '||v_aging_bucket);
                --xxv_debug_prc('Else Cust Account ID and gc_default_aging_bucket - '||gn_cust_account_id|| ' - '||gc_default_aging_bucket);

                ln_score   := ln_aging_bucket_score;
            END IF;

            LOG (
                p_module        => 'get_score_us',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_score_us Score : ' || ln_aging_bucket_score);

            /* Start of changes for CCR0007180 */
            ln_mapped_score   :=
                get_non_weight_mapping_score (P_CUST_ACCOUNT_ID, ln_score);
            /* End of changes for CCR0007180 */


            --ln_mapped_score := get_mapped_score (ln_score, v_aging_bucket);
            LOG (
                p_module        => 'get_score_us',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_score_us Mapped Score : ' || ln_mapped_score);
        ELSE
            --xxv_debug_prc('Else Cust Account ID and Weight - '||gn_cust_account_id|| ' - '||lc_use_weight);
            LOG (
                p_module        => 'get_score_us',
                p_line_number   => NULL,
                p_log_message   =>
                    ' When XXDO" Use Weights profile is set to no');

            ln_last_payment_score   :=
                get_last_payment_score (P_CUST_ACCOUNT_ID);

            LOG (
                p_module        => 'get_score_us',
                p_line_number   => NULL,
                p_log_message   =>
                       ' get_score_us  Last Payment Score : '
                    || ln_last_payment_score);



            ln_book_order_score   :=
                get_booked_order_score (P_CUST_ACCOUNT_ID);

            LOG (
                p_module        => 'get_score_us',
                p_line_number   => NULL,
                p_log_message   =>
                       ' get_score_us  Booked Order Score : '
                    || ln_book_order_score);



            ln_adl_score   := get_adl_score (P_CUST_ACCOUNT_ID);

            LOG (
                p_module        => 'get_score_us',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_score_us  ADL Score : ' || ln_adl_score);

            ln_score       :=
                  NVL (ln_aging_bucket_score, 0)
                --    + NVL (ln_aging_bucket_wt, 0)
                + NVL (ln_last_payment_score, 0)
                --    + NVL (ln_last_payment_wt, 0)
                + NVL (ln_adl_score, 0)
                + NVL (ln_book_order_score, 0);

            LOG (p_module        => 'get_score_us',
                 p_line_number   => NULL,
                 p_log_message   => ' get_score_us  Score : ' || ln_score);

            ln_mapped_score   :=
                get_non_weight_mapping_score (P_CUST_ACCOUNT_ID, ln_score);

            LOG (
                p_module        => 'get_score_us',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_score_us Mapped Score : ' || ln_mapped_score);
        END IF;

        LOG (
            p_module        => 'get_score_us',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_score_us before Updating HZ_CUST_ACCOUNTS  : '
                || P_CUST_ACCOUNT_ID);

        OPEN insert_update_c (p_cust_account_id);

        FETCH insert_update_c INTO gc_insert_check;

        CLOSE insert_update_c;

        LOG (p_module        => 'get_score_us',
             p_line_number   => NULL,
             p_log_message   => ' iNSERT fLAG : ' || gc_insert_check);

        IF NVL (gc_insert_check, 'Y') = 'Y'
        THEN
            -- Start of changes for CCR0007180
            IF lc_use_weight <> 'N'
            THEN
                --xxv_debug_prc('Cust Account ID and gc_insert_check - '||gn_cust_account_id|| ' - '||gc_insert_check);
                --xxv_debug_prc('Cust Account ID and lc_use_weight - '||gn_cust_account_id|| ' - '||lc_use_weight);
                LOG (
                    p_module        => 'get_score_us',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' BEFORE INSERT using weighted score: '
                        || P_CUST_ACCOUNT_ID);
                INSERT_UPDATE (p_insert_update_flag => 'Y', p_aging_bucket_score => NVL (ln_aging_bucket_score, 0) * ln_aging_bucket_wt_new, p_aging_bucket => v_aging_bucket, p_booked_order_score => NVL (ln_book_order_score, 0) * ln_book_order_wt_new, p_last_payment_score => NVL (ln_last_payment_score, 0) * ln_last_payment_wt_new, p_adl_score => NVL (ln_adl_score, 0) * ln_adl_wt_new, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);

                LOG (
                    p_module        => 'get_score_us',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' AFTER INSERT using weighted score: '
                        || gc_insert_check);
            -- End of changes for CCR0007180
            ELSE
                --xxv_debug_prc('Else Cust Account ID and lc_use_weight - '||gn_cust_account_id|| ' - '||lc_use_weight);

                LOG (
                    p_module        => 'get_score_us',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' bEFORE INSERT : ' || P_CUST_ACCOUNT_ID);
                INSERT_UPDATE (p_insert_update_flag => 'Y', p_aging_bucket_score => ln_aging_bucket_score, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score, p_last_payment_score => ln_last_payment_score, p_adl_score => ln_adl_score, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);

                LOG (p_module        => 'get_score_us',
                     p_line_number   => NULL,
                     p_log_message   => ' aFTER INSERT : ' || gc_insert_check);
            END IF;
        ELSE
            -- Start of changes for CCR0007180
            IF lc_use_weight <> 'N'
            THEN
                --xxv_debug_prc('Else Cust Account ID and lc_use_weight as Y - '||gn_cust_account_id|| ' - '||lc_use_weight);
                INSERT_UPDATE (p_insert_update_flag => 'N', p_aging_bucket_score => NVL (ln_aging_bucket_score, 0) * ln_aging_bucket_wt_new, p_aging_bucket => v_aging_bucket, p_booked_order_score => NVL (ln_book_order_score, 0) * ln_book_order_wt_new, p_last_payment_score => NVL (ln_last_payment_score, 0) * ln_last_payment_wt_new, p_adl_score => NVL (ln_adl_score, 0) * ln_adl_wt_new, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);
            -- End of changes for CCR0007180
            ELSE
                --xxv_debug_prc('Else Cust Account ID and lc_use_weight as N Enters here - '||gn_cust_account_id|| ' - '||lc_use_weight);
                INSERT_UPDATE (p_insert_update_flag => 'N', p_aging_bucket_score => ln_aging_bucket_score, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score, p_last_payment_score => ln_last_payment_score, p_adl_score => ln_adl_score, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);
            END IF;
        END IF;

        LOG (
            p_module        => 'get_score_us',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_score_us after Updating HZ_CUST_ACCOUNTS  : '
                || P_CUST_ACCOUNT_ID);


        LOG (
            p_module        => 'get_score_us',
            p_line_number   => NULL,
            p_log_message   =>
                ' End Scoring for Account : ' || P_CUST_ACCOUNT_ID);


        RETURN ROUND (ln_mapped_score);
    EXCEPTION
        WHEN OTHERS
        THEN
            gc_exception_flag   := 'Y';
            LOG (
                p_module        => 'get_score_us',
                p_line_number   => NULL,
                p_log_message   =>
                       ' get_score_us  Booked Order Score : '
                    || ln_book_order_score);
            XXDO_GEH_PKG.record_error (
                gc_module,
                P_CUST_ACCOUNT_ID,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                gn_user_id,
                'Code pointer : ' || 'Error in get_score_us',
                'Deckers Customer Account Scoring Program ',
                (gn_org_id));
            ln_mapped_score     := -1;
            RETURN ln_mapped_score;
            COMMIT;
    END get_score_us;

    /*******************************************************************************
    * Funtion Name : get_score_ca
    * Description  : This Function will generate and return the final mapped score
    *                for a given cust_account_id. Included as part of Canada 3PL Project
    * Parameters   :P_CUST_ACCOUNT_ID
                   :P_SCORE_COMPONENT_ID
    * --------------------------------------------------------------------------- */

    FUNCTION get_score_ca (P_CUST_ACCOUNT_ID      IN NUMBER,
                           P_SCORE_COMPONENT_ID   IN NUMBER)
        RETURN NUMBER
    IS
        ln_score                 NUMBER := 0;
        ln_aging_bucket_score    NUMBER := 0;
        ln_aging_bucket_wt       NUMBER := 0;
        ln_last_payment_score    NUMBER := 0;
        ln_last_payment_wt       NUMBER := 0;
        ln_book_order_score      NUMBER := 0;
        ln_book_order_wt         NUMBER := 0;
        ln_adl_score             NUMBER := 0;
        ln_adl_wt                NUMBER := 0;
        lc_prorate_score         VARCHAR2 (1);
        ln_mapped_score          NUMBER := 0;
        lc_use_weight            VARCHAR2 (1);
        -- Start of Changes for CCR0007180
        ln_aging_bucket_wt_new   NUMBER := 0;
        ln_last_payment_wt_new   NUMBER := 0;
        ln_book_order_wt_new     NUMBER := 0;
        ln_adl_wt_new            NUMBER := 0;

        -- End of Changes for CCR0007180

        CURSOR insert_update_c (p_cust_acc_id IN NUMBER)
        IS
            SELECT DECODE (COUNT (*), 0, 'Y', 'N')
              FROM xxd_iex_metrics_tbl
             WHERE cust_account_id = p_cust_acc_id AND org_id = gn_org_id;
    BEGIN
        SET_ORG_ID;

        --xxv_debug_prc('Flow Started - Test CA');

        gn_cust_account_id       := P_CUST_ACCOUNT_ID;
        gc_log_profile_value     :=
            NVL (apps.fnd_profile.VALUE ('XXDO_GEH_LOG_ENABLE'), 'N');
        gc_exception_flag        := 'N';

        LOG (
            p_module        => 'get_score_ca',
            p_line_number   => NULL,
            p_log_message   =>
                ' Start Scoring for Account : ' || P_CUST_ACCOUNT_ID);

        ln_aging_bucket_score    :=
            get_aging_bucket_avg_score_ca (P_CUST_ACCOUNT_ID);

        LOG (
            p_module        => 'get_score_ca',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_score_ca  Aging Bucket Score : '
                || ln_aging_bucket_score);



        LOG (
            p_module        => 'get_score_ca',
            p_line_number   => NULL,
            p_log_message   =>
                ' get_score_ca  Aging Bucket  : ' || v_aging_bucket);


        LOG (
            p_module        => 'get_score_ca',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_score_ca  Global Default Aging Bucket  : '
                || gc_default_aging_bucket);
        lc_use_weight            :=
            NVL (apps.fnd_profile.VALUE ('XXDO_IEX_USE_WEIGHT'), 'N');

        -- Start of Changes for CCR0007180
        ln_aging_bucket_wt_new   := get_Weight (gc_score_component1); --'AGING_WATERFALL'
        ln_last_payment_wt_new   := get_Weight (gc_risk_component1); --'LAST_PAYMENT'
        ln_book_order_wt_new     := get_Weight (gc_risk_component2); --'BOOKED_ORDERS'
        ln_adl_wt_new            := get_Weight (gc_risk_component3); --'ADL_TREND'
        -- End of Changes for CCR0007180

        LOG (p_module        => 'get_score_ca',
             p_line_number   => NULL,
             p_log_message   => 'lc_use_weight : ' || lc_use_weight);

        IF lc_use_weight <> 'N'
        THEN
            IF v_aging_bucket <> gc_default_aging_bucket
            THEN
                LOG (
                    p_module        => 'get_score_ca',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' get_score_ca  Aging Bucket is not  Global Default Aging Bucket');



                ln_last_payment_score   :=
                    get_last_payment_score (P_CUST_ACCOUNT_ID);

                LOG (
                    p_module        => 'get_score_ca',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_ca  Last Payment Score : '
                        || ln_last_payment_score);



                ln_book_order_score   :=
                    get_booked_order_score (P_CUST_ACCOUNT_ID);

                LOG (
                    p_module        => 'get_score_ca',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_ca  Booked Order Score : '
                        || ln_book_order_score);



                ln_adl_score         := get_adl_score (P_CUST_ACCOUNT_ID);

                LOG (
                    p_module        => 'get_score_ca',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' get_score_ca  ADL Score : ' || ln_adl_score);


                ln_aging_bucket_wt   := get_Weight (gc_score_component1); --'AGING_WATERFALL'

                LOG (
                    p_module        => 'get_score_ca',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_ca  Aging Bucket Wt : '
                        || ln_aging_bucket_wt);



                ln_last_payment_wt   := get_Weight (gc_risk_component1); --'LAST_PAYMENT'
                LOG (
                    p_module        => 'get_score_ca',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_ca  Last Payment Wt : '
                        || ln_last_payment_wt);



                ln_book_order_wt     := get_Weight (gc_risk_component2); --'BOOKED_ORDERS'

                LOG (
                    p_module        => 'get_score_ca',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_ca  Booked Order Wt : '
                        || ln_book_order_wt);


                ln_adl_wt            := get_Weight (gc_risk_component3); --'ADL_TREND'
                LOG (
                    p_module        => 'get_score_ca',
                    p_line_number   => NULL,
                    p_log_message   => ' get_score_ca  ADL Wt : ' || ln_adl_wt);


                lc_prorate_score     :=
                    NVL (apps.fnd_profile.VALUE ('XXDO_IEX_PRORATE_SCORE'),
                         'N');

                LOG (
                    p_module        => 'get_score_ca',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_ca  Pro-Rate profile : '
                        || lc_prorate_score);



                ln_score             :=
                    caluclate_score (ln_aging_bucket_score, ln_aging_bucket_wt, ln_last_payment_score, ln_last_payment_wt, ln_book_order_score, ln_book_order_wt, ln_adl_score, ln_adl_wt, lc_prorate_score
                                     , lc_use_weight); -- Added for CCR0007180
            ELSE
                LOG (
                    p_module        => 'get_score_ca',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' get_score_ca  Only Aging Bucket default score is considered if amount due remaining is 0');


                ln_score   := ln_aging_bucket_score;
            END IF;

            LOG (
                p_module        => 'get_score_ca',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_score_ca Score : ' || ln_aging_bucket_score);

            /* Start of changes for CCR0007180 */
            ln_mapped_score   :=
                get_non_weight_mapping_score (P_CUST_ACCOUNT_ID, ln_score);
            /* End of changes for CCR0007180 */

            --ln_mapped_score := get_mapped_score (ln_score, v_aging_bucket);
            LOG (
                p_module        => 'get_score_ca',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_score_ca Mapped Score : ' || ln_mapped_score);
        ELSE
            LOG (
                p_module        => 'get_score_ca',
                p_line_number   => NULL,
                p_log_message   =>
                    ' When XXDO" Use Weights profile is set to no');

            ln_last_payment_score   :=
                get_last_payment_score (P_CUST_ACCOUNT_ID);

            LOG (
                p_module        => 'get_score_ca',
                p_line_number   => NULL,
                p_log_message   =>
                       ' get_score_ca  Last Payment Score : '
                    || ln_last_payment_score);



            ln_book_order_score   :=
                get_booked_order_score (P_CUST_ACCOUNT_ID);

            LOG (
                p_module        => 'get_score_ca',
                p_line_number   => NULL,
                p_log_message   =>
                       ' get_score_ca  Booked Order Score : '
                    || ln_book_order_score);



            ln_adl_score   := get_adl_score (P_CUST_ACCOUNT_ID);

            LOG (
                p_module        => 'get_score_ca',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_score_ca  ADL Score : ' || ln_adl_score);

            ln_score       :=
                  NVL (ln_aging_bucket_score, 0)
                --    + NVL (ln_aging_bucket_wt, 0)
                + NVL (ln_last_payment_score, 0)
                --    + NVL (ln_last_payment_wt, 0)
                + NVL (ln_adl_score, 0)
                + NVL (ln_book_order_score, 0);

            LOG (p_module        => 'get_score_ca',
                 p_line_number   => NULL,
                 p_log_message   => ' get_score_ca  Score : ' || ln_score);

            ln_mapped_score   :=
                get_non_weight_mapping_score (P_CUST_ACCOUNT_ID, ln_score);

            LOG (
                p_module        => 'get_score_ca',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_score_ca Mapped Score : ' || ln_mapped_score);
        END IF;

        LOG (
            p_module        => 'get_score_ca',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_score_ca before Updating HZ_CUST_ACCOUNTS  : '
                || P_CUST_ACCOUNT_ID);

        OPEN insert_update_c (p_cust_account_id);

        FETCH insert_update_c INTO gc_insert_check;

        CLOSE insert_update_c;

        LOG (p_module        => 'get_score_ca',
             p_line_number   => NULL,
             p_log_message   => ' iNSERT fLAG : ' || gc_insert_check);

        IF NVL (gc_insert_check, 'Y') = 'Y'
        THEN
            -- Start of changes for CCR0007180
            IF lc_use_weight <> 'N'
            THEN
                LOG (
                    p_module        => 'get_score_ca',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' BEFORE INSERT using weighted score: '
                        || P_CUST_ACCOUNT_ID);
                INSERT_UPDATE (p_insert_update_flag => 'Y', p_aging_bucket_score => ln_aging_bucket_score * ln_aging_bucket_wt_new, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score * ln_book_order_wt_new, p_last_payment_score => ln_last_payment_score * ln_last_payment_wt_new, p_adl_score => ln_adl_score * ln_adl_wt_new, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);

                LOG (
                    p_module        => 'get_score_ca',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' AFTER INSERT using weighted score: '
                        || gc_insert_check);
            -- End of changes for CCR0007180
            ELSE
                LOG (
                    p_module        => 'get_score_ca',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' bEFORE INSERT : ' || P_CUST_ACCOUNT_ID);
                INSERT_UPDATE (p_insert_update_flag => 'Y', p_aging_bucket_score => ln_aging_bucket_score, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score, p_last_payment_score => ln_last_payment_score, p_adl_score => ln_adl_score, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);

                LOG (p_module        => 'get_score_ca',
                     p_line_number   => NULL,
                     p_log_message   => ' aFTER INSERT : ' || gc_insert_check);
            END IF;
        ELSE
            -- Start of changes for CCR0007180
            IF lc_use_weight <> 'N'
            THEN
                INSERT_UPDATE (p_insert_update_flag => 'N', p_aging_bucket_score => ln_aging_bucket_score * ln_aging_bucket_wt_new, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score * ln_book_order_wt_new, p_last_payment_score => ln_last_payment_score * ln_last_payment_wt_new, p_adl_score => ln_adl_score * ln_adl_wt_new, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);
            -- End of changes for CCR0007180
            ELSE
                INSERT_UPDATE (p_insert_update_flag => 'N', p_aging_bucket_score => ln_aging_bucket_score, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score, p_last_payment_score => ln_last_payment_score, p_adl_score => ln_adl_score, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);
            END IF;
        END IF;


        LOG (
            p_module        => 'get_score_ca',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_score_ca after Updating HZ_CUST_ACCOUNTS  : '
                || P_CUST_ACCOUNT_ID);


        LOG (
            p_module        => 'get_score_ca',
            p_line_number   => NULL,
            p_log_message   =>
                ' End Scoring for Account : ' || P_CUST_ACCOUNT_ID);


        RETURN ROUND (ln_mapped_score);
    EXCEPTION
        WHEN OTHERS
        THEN
            gc_exception_flag   := 'Y';
            LOG (
                p_module        => 'get_score_ca',
                p_line_number   => NULL,
                p_log_message   =>
                       ' get_score_ca  Booked Order Score : '
                    || ln_book_order_score);
            XXDO_GEH_PKG.record_error (
                gc_module,
                P_CUST_ACCOUNT_ID,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                gn_user_id,
                'Code pointer : ' || 'Error in get_score_ca',
                'Deckers Customer Account Scoring Program ',
                (gn_org_id));
            ln_mapped_score     := -1;
            RETURN ln_mapped_score;
    END get_score_ca;

    /*******************************************************************************
    * Funtion Name : get_score_uk
    * Description  : This Function will generate and return the final mapped score
    *                for a given cust_account_id
    * Parameters   :P_CUST_ACCOUNT_ID
                   :P_SCORE_COMPONENT_ID
    * --------------------------------------------------------------------------- */

    FUNCTION get_score_uk (P_CUST_ACCOUNT_ID      IN NUMBER,
                           P_SCORE_COMPONENT_ID   IN NUMBER)
        RETURN NUMBER
    IS
        ln_score                 NUMBER := 0;
        ln_aging_bucket_score    NUMBER := 0;
        ln_aging_bucket_wt       NUMBER := 0;
        ln_last_payment_score    NUMBER := 0;
        ln_last_payment_wt       NUMBER := 0;
        ln_book_order_score      NUMBER := 0;
        ln_book_order_wt         NUMBER := 0;
        ln_adl_score             NUMBER := 0;
        ln_adl_wt                NUMBER := 0;
        lc_prorate_score         VARCHAR2 (1);
        ln_mapped_score          NUMBER := 0;
        lc_use_weight            VARCHAR2 (1);
        -- Start of Changes for CCR0007180
        ln_aging_bucket_wt_new   NUMBER := 0;
        ln_last_payment_wt_new   NUMBER := 0;
        ln_book_order_wt_new     NUMBER := 0;
        ln_adl_wt_new            NUMBER := 0;

        -- End of Changes for CCR0007180

        CURSOR insert_update_c (p_cust_acc_id IN NUMBER)
        IS
            SELECT DECODE (COUNT (*), 0, 'Y', 'N')
              FROM xxd_iex_metrics_tbl
             WHERE cust_account_id = p_cust_acc_id AND org_id = gn_org_id;
    BEGIN
        SET_ORG_ID;

        --xxv_debug_prc('Flow Started - Test UK');

        gn_cust_account_id     := P_CUST_ACCOUNT_ID;
        gc_log_profile_value   :=
            NVL (apps.fnd_profile.VALUE ('XXDO_GEH_LOG_ENABLE'), 'N');
        gc_exception_flag      := 'N';

        LOG (
            p_module        => 'get_score_uk',
            p_line_number   => NULL,
            p_log_message   =>
                ' Start Scoring for Account : ' || P_CUST_ACCOUNT_ID);

        ln_aging_bucket_score   :=
            get_aging_bucket_avg_score_uk (P_CUST_ACCOUNT_ID);

        LOG (
            p_module        => 'get_score_uk',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_score_uk  Aging Bucket Score : '
                || ln_aging_bucket_score);



        LOG (
            p_module        => 'get_score_uk',
            p_line_number   => NULL,
            p_log_message   =>
                ' get_score_uk  Aging Bucket  : ' || v_aging_bucket);


        LOG (
            p_module        => 'get_score_uk',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_score_uk  Global Default Aging Bucket  : '
                || gc_default_aging_bucket);
        lc_use_weight          :=
            NVL (apps.fnd_profile.VALUE ('XXDO_IEX_USE_WEIGHT'), 'N');

        LOG (p_module        => 'get_score_uk',
             p_line_number   => NULL,
             p_log_message   => 'lc_use_weight : ' || lc_use_weight);

        IF lc_use_weight <> 'N'
        THEN
            IF v_aging_bucket <> gc_default_aging_bucket
            THEN
                LOG (
                    p_module        => 'get_score_uk',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' get_score_uk  Aging Bucket is not  Global Default Aging Bucket');



                ln_last_payment_score    :=
                    get_last_payment_score (P_CUST_ACCOUNT_ID);

                LOG (
                    p_module        => 'get_score_uk',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_uk  Last Payment Score : '
                        || ln_last_payment_score);



                ln_book_order_score      :=
                    get_booked_order_score (P_CUST_ACCOUNT_ID);

                LOG (
                    p_module        => 'get_score_uk',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_uk  Booked Order Score : '
                        || ln_book_order_score);



                ln_adl_score             := get_adl_score (P_CUST_ACCOUNT_ID);

                LOG (
                    p_module        => 'get_score_uk',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' get_score_uk  ADL Score : ' || ln_adl_score);


                ln_aging_bucket_wt       := get_Weight (gc_score_component1); --'AGING_WATERFALL'

                LOG (
                    p_module        => 'get_score_uk',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_uk  Aging Bucket Wt : '
                        || ln_aging_bucket_wt);



                ln_last_payment_wt       := get_Weight (gc_risk_component1); --'LAST_PAYMENT'
                LOG (
                    p_module        => 'get_score_uk',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_uk  Last Payment Wt : '
                        || ln_last_payment_wt);



                ln_book_order_wt         := get_Weight (gc_risk_component2); --'BOOKED_ORDERS'

                LOG (
                    p_module        => 'get_score_uk',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_uk  Booked Order Wt : '
                        || ln_book_order_wt);


                ln_adl_wt                := get_Weight (gc_risk_component3); --'ADL_TREND'
                LOG (
                    p_module        => 'get_score_uk',
                    p_line_number   => NULL,
                    p_log_message   => ' get_score_uk  ADL Wt : ' || ln_adl_wt);


                lc_prorate_score         :=
                    NVL (apps.fnd_profile.VALUE ('XXDO_IEX_PRORATE_SCORE'),
                         'N');

                -- Start of Changes for CCR0007180
                ln_aging_bucket_wt_new   := get_Weight (gc_score_component1); --'AGING_WATERFALL'
                ln_last_payment_wt_new   := get_Weight (gc_risk_component1); --'LAST_PAYMENT'
                ln_book_order_wt_new     := get_Weight (gc_risk_component2); --'BOOKED_ORDERS'
                ln_adl_wt_new            := get_Weight (gc_risk_component3); --'ADL_TREND'
                -- End of Changes for CCR0007180

                LOG (
                    p_module        => 'get_score_uk',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_uk  Pro-Rate profile : '
                        || lc_prorate_score);



                ln_score                 :=
                    caluclate_score (ln_aging_bucket_score, ln_aging_bucket_wt, ln_last_payment_score, ln_last_payment_wt, ln_book_order_score, ln_book_order_wt, ln_adl_score, ln_adl_wt, lc_prorate_score
                                     , lc_use_weight); -- Added New for CCR0007180);
            ELSE
                LOG (
                    p_module        => 'get_score_uk',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' get_score_uk  Only Aging Bucket default score is considered if amount due remaining is 0');


                ln_score   := ln_aging_bucket_score;
            END IF;

            LOG (
                p_module        => 'get_score_uk',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_score_uk Score : ' || ln_aging_bucket_score);

            /* Start of changes for CCR0007180 */
            ln_mapped_score   :=
                get_non_weight_mapping_score (P_CUST_ACCOUNT_ID, ln_score);
            /* End of changes for CCR0007180 */

            -- ln_mapped_score := get_mapped_score (ln_score, v_aging_bucket);
            LOG (
                p_module        => 'get_score_uk',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_score_uk Mapped Score : ' || ln_mapped_score);
        ELSE
            LOG (
                p_module        => 'get_score_uk',
                p_line_number   => NULL,
                p_log_message   =>
                    ' When XXDO" Use Weights profile is set to no');

            ln_last_payment_score   :=
                get_last_payment_score (P_CUST_ACCOUNT_ID);

            LOG (
                p_module        => 'get_score_uk',
                p_line_number   => NULL,
                p_log_message   =>
                       ' get_score_uk  Last Payment Score : '
                    || ln_last_payment_score);



            ln_book_order_score   :=
                get_booked_order_score (P_CUST_ACCOUNT_ID);

            LOG (
                p_module        => 'get_score_uk',
                p_line_number   => NULL,
                p_log_message   =>
                       ' get_score_uk  Booked Order Score : '
                    || ln_book_order_score);



            ln_adl_score   := get_adl_score (P_CUST_ACCOUNT_ID);

            LOG (
                p_module        => 'get_score_uk',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_score_uk  ADL Score : ' || ln_adl_score);

            ln_score       :=
                  NVL (ln_aging_bucket_score, 0)
                --    + NVL (ln_aging_bucket_wt, 0)
                + NVL (ln_last_payment_score, 0)
                --    + NVL (ln_last_payment_wt, 0)
                + NVL (ln_adl_score, 0)
                + NVL (ln_book_order_score, 0);

            LOG (p_module        => 'get_score_uk',
                 p_line_number   => NULL,
                 p_log_message   => ' get_score_uk  Score : ' || ln_score);

            ln_mapped_score   :=
                get_non_weight_mapping_score (P_CUST_ACCOUNT_ID, ln_score);

            LOG (
                p_module        => 'get_score_uk',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_score_uk Mapped Score : ' || ln_mapped_score);
        END IF;

        LOG (
            p_module        => 'get_score_uk',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_score_uk before Updating HZ_CUST_ACCOUNTS  : '
                || P_CUST_ACCOUNT_ID);

        OPEN insert_update_c (p_cust_account_id);

        FETCH insert_update_c INTO gc_insert_check;

        CLOSE insert_update_c;

        LOG (p_module        => 'get_score_uk',
             p_line_number   => NULL,
             p_log_message   => ' iNSERT fLAG : ' || gc_insert_check);

        IF NVL (gc_insert_check, 'Y') = 'Y'
        THEN
            -- Start of changes for CCR0007180
            IF lc_use_weight <> 'N'
            THEN
                LOG (
                    p_module        => 'get_score_uk',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' BEFORE INSERT using weighted score: '
                        || P_CUST_ACCOUNT_ID);
                INSERT_UPDATE (p_insert_update_flag => 'Y', p_aging_bucket_score => ln_aging_bucket_score * ln_aging_bucket_wt_new, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score * ln_book_order_wt_new, p_last_payment_score => ln_last_payment_score * ln_last_payment_wt_new, p_adl_score => ln_adl_score * ln_adl_wt_new, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);

                LOG (
                    p_module        => 'get_score_uk',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' AFTER INSERT using weighted score: '
                        || gc_insert_check);
            -- End of changes for CCR0007180
            ELSE
                LOG (
                    p_module        => 'get_score_uk',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' bEFORE INSERT : ' || P_CUST_ACCOUNT_ID);
                INSERT_UPDATE (p_insert_update_flag => 'Y', p_aging_bucket_score => ln_aging_bucket_score, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score, p_last_payment_score => ln_last_payment_score, p_adl_score => ln_adl_score, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);

                LOG (p_module        => 'get_score_uk',
                     p_line_number   => NULL,
                     p_log_message   => ' aFTER INSERT : ' || gc_insert_check);
            END IF;
        ELSE
            -- Start of changes for CCR0007180
            IF lc_use_weight <> 'N'
            THEN
                INSERT_UPDATE (p_insert_update_flag => 'N', p_aging_bucket_score => ln_aging_bucket_score * ln_aging_bucket_wt_new, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score * ln_book_order_wt_new, p_last_payment_score => ln_last_payment_score * ln_last_payment_wt_new, p_adl_score => ln_adl_score * ln_adl_wt_new, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);
            -- End of changes for CCR0007180
            ELSE
                INSERT_UPDATE (p_insert_update_flag => 'N', p_aging_bucket_score => ln_aging_bucket_score, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score, p_last_payment_score => ln_last_payment_score, p_adl_score => ln_adl_score, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);
            END IF;
        END IF;

        LOG (
            p_module        => 'get_score_uk',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_score_uk after Updating HZ_CUST_ACCOUNTS  : '
                || P_CUST_ACCOUNT_ID);


        LOG (
            p_module        => 'get_score_uk',
            p_line_number   => NULL,
            p_log_message   =>
                ' End Scoring for Account : ' || P_CUST_ACCOUNT_ID);


        RETURN ROUND (ln_mapped_score);
    EXCEPTION
        WHEN OTHERS
        THEN
            gc_exception_flag   := 'Y';
            LOG (
                p_module        => 'get_score_uk',
                p_line_number   => NULL,
                p_log_message   =>
                       ' get_score_uk  Booked Order Score : '
                    || ln_book_order_score);
            XXDO_GEH_PKG.record_error (
                gc_module,
                P_CUST_ACCOUNT_ID,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                gn_user_id,
                'Code pointer : ' || 'Error in get_score_uk',
                'Deckers Customer Account Scoring Program ',
                (gn_org_id));
            ln_mapped_score     := -1;
            RETURN ln_mapped_score;
    END get_score_uk;

    /*******************************************************************************
    * Funtion Name : get_score_benelux
    * Description  : This Function will generate and return the final mapped score
    *                for a given cust_account_id
    * Parameters   :P_CUST_ACCOUNT_ID
                   :P_SCORE_COMPONENT_ID
    * --------------------------------------------------------------------------- */

    FUNCTION get_score_benelux (P_CUST_ACCOUNT_ID      IN NUMBER,
                                P_SCORE_COMPONENT_ID   IN NUMBER)
        RETURN NUMBER
    IS
        ln_score                 NUMBER := 0;
        ln_aging_bucket_score    NUMBER := 0;
        ln_aging_bucket_wt       NUMBER := 0;
        ln_last_payment_score    NUMBER := 0;
        ln_last_payment_wt       NUMBER := 0;
        ln_book_order_score      NUMBER := 0;
        ln_book_order_wt         NUMBER := 0;
        ln_adl_score             NUMBER := 0;
        ln_adl_wt                NUMBER := 0;
        lc_prorate_score         VARCHAR2 (1);
        ln_mapped_score          NUMBER := 0;
        lc_use_weight            VARCHAR2 (1);
        -- Start of Changes for CCR0007180
        ln_aging_bucket_wt_new   NUMBER := 0;
        ln_last_payment_wt_new   NUMBER := 0;
        ln_book_order_wt_new     NUMBER := 0;
        ln_adl_wt_new            NUMBER := 0;

        -- End of Changes for CCR0007180

        CURSOR insert_update_c (p_cust_acc_id IN NUMBER)
        IS
            SELECT DECODE (COUNT (*), 0, 'Y', 'N')
              FROM xxd_iex_metrics_tbl
             WHERE cust_account_id = p_cust_acc_id AND org_id = gn_org_id;
    BEGIN
        SET_ORG_ID;

        --xxv_debug_prc('Flow Started - Test BLX');

        gn_cust_account_id       := P_CUST_ACCOUNT_ID;
        gc_log_profile_value     :=
            NVL (apps.fnd_profile.VALUE ('XXDO_GEH_LOG_ENABLE'), 'N');
        gc_exception_flag        := 'N';

        LOG (
            p_module        => 'get_score_benelux',
            p_line_number   => NULL,
            p_log_message   =>
                ' Start Scoring for Account : ' || P_CUST_ACCOUNT_ID);

        ln_aging_bucket_score    :=
            get_aging_bucket_avg_score_bx (P_CUST_ACCOUNT_ID);

        LOG (
            p_module        => 'get_score_benelux',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_score_benelux  Aging Bucket Score : '
                || ln_aging_bucket_score);



        LOG (
            p_module        => 'get_score_benelux',
            p_line_number   => NULL,
            p_log_message   =>
                ' get_score_benelux  Aging Bucket  : ' || v_aging_bucket);


        LOG (
            p_module        => 'get_score_benelux',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_score_benelux  Global Default Aging Bucket  : '
                || gc_default_aging_bucket);
        lc_use_weight            :=
            NVL (apps.fnd_profile.VALUE ('XXDO_IEX_USE_WEIGHT'), 'N');

        -- Start of Changes for CCR0007180
        ln_aging_bucket_wt_new   := get_Weight (gc_score_component1); --'AGING_WATERFALL'
        ln_last_payment_wt_new   := get_Weight (gc_risk_component1); --'LAST_PAYMENT'
        ln_book_order_wt_new     := get_Weight (gc_risk_component2); --'BOOKED_ORDERS'
        ln_adl_wt_new            := get_Weight (gc_risk_component3); --'ADL_TREND'
        -- End of Changes for CCR0007180

        LOG (p_module        => 'get_score_benelux',
             p_line_number   => NULL,
             p_log_message   => 'lc_use_weight : ' || lc_use_weight);

        IF lc_use_weight <> 'N'
        THEN
            IF v_aging_bucket <> gc_default_aging_bucket
            THEN
                LOG (
                    p_module        => 'get_score_benelux',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' get_score_benelux  Aging Bucket is not  Global Default Aging Bucket');



                ln_last_payment_score   :=
                    get_last_payment_score (P_CUST_ACCOUNT_ID);

                LOG (
                    p_module        => 'get  _score_benelux',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_benelux  Last Payment Score : '
                        || ln_last_payment_score);



                ln_book_order_score   :=
                    get_booked_order_score (P_CUST_ACCOUNT_ID);

                LOG (
                    p_module        => 'get_score_benelux',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_benelux  Booked Order Score : '
                        || ln_book_order_score);



                ln_adl_score         := get_adl_score (P_CUST_ACCOUNT_ID);

                LOG (
                    p_module        => 'get_score_benelux',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' get_score_benelux  ADL Score : ' || ln_adl_score);


                ln_aging_bucket_wt   := get_Weight (gc_score_component1); --'AGING_WATERFALL'

                LOG (
                    p_module        => 'get_score_benelux',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_benelux  Aging Bucket Wt : '
                        || ln_aging_bucket_wt);



                ln_last_payment_wt   := get_Weight (gc_risk_component1); --'LAST_PAYMENT'
                LOG (
                    p_module        => 'get_score_benelux',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_benelux  Last Payment Wt : '
                        || ln_last_payment_wt);



                ln_book_order_wt     := get_Weight (gc_risk_component2); --'BOOKED_ORDERS'

                LOG (
                    p_module        => 'get_score_benelux',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_benelux  Booked Order Wt : '
                        || ln_book_order_wt);


                ln_adl_wt            := get_Weight (gc_risk_component3); --'ADL_TREND'
                LOG (
                    p_module        => 'get_score_benelux',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' get_score_benelux  ADL Wt : ' || ln_adl_wt);


                lc_prorate_score     :=
                    NVL (apps.fnd_profile.VALUE ('XXDO_IEX_PRORATE_SCORE'),
                         'N');

                LOG (
                    p_module        => 'get_score_benelux',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_benelux  Pro-Rate profile : '
                        || lc_prorate_score);



                ln_score             :=
                    caluclate_score (ln_aging_bucket_score, ln_aging_bucket_wt, ln_last_payment_score, ln_last_payment_wt, ln_book_order_score, ln_book_order_wt, ln_adl_score, ln_adl_wt, lc_prorate_score
                                     , lc_use_weight); -- Added new for CCR0007180
            ELSE
                LOG (
                    p_module        => 'get_score_benelux',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' get_score_benelux  Only Aging Bucket default score is considered if amount due remaining is 0');


                ln_score   := ln_aging_bucket_score;
            END IF;

            LOG (
                p_module        => 'get_score_benelux',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_score_benelux Score : ' || ln_aging_bucket_score);

            /* Start of changes for CCR0007180 */
            ln_mapped_score   :=
                get_non_weight_mapping_score (P_CUST_ACCOUNT_ID, ln_score);
            /* End of changes for CCR0007180 */

            --ln_mapped_score := get_mapped_score (ln_score, v_aging_bucket);
            LOG (
                p_module        => 'get_score_benelux',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_score_benelux Mapped Score : ' || ln_mapped_score);
        ELSE
            LOG (
                p_module        => 'get_score_benelux',
                p_line_number   => NULL,
                p_log_message   =>
                    ' When XXDO" Use Weights profile is set to no');

            ln_last_payment_score   :=
                get_last_payment_score (P_CUST_ACCOUNT_ID);

            LOG (
                p_module        => 'get_score_benelux',
                p_line_number   => NULL,
                p_log_message   =>
                       ' get_score_benelux  Last Payment Score : '
                    || ln_last_payment_score);



            ln_book_order_score   :=
                get_booked_order_score (P_CUST_ACCOUNT_ID);

            LOG (
                p_module        => 'get_score_benelux',
                p_line_number   => NULL,
                p_log_message   =>
                       ' get_score_benelux  Booked Order Score : '
                    || ln_book_order_score);



            ln_adl_score   := get_adl_score (P_CUST_ACCOUNT_ID);

            LOG (
                p_module        => 'get_score_benelux',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_score_benelux  ADL Score : ' || ln_adl_score);

            ln_score       :=
                  NVL (ln_aging_bucket_score, 0)
                --    + NVL (ln_aging_bucket_wt, 0)
                + NVL (ln_last_payment_score, 0)
                --    + NVL (ln_last_payment_wt, 0)
                + NVL (ln_adl_score, 0)
                + NVL (ln_book_order_score, 0);

            LOG (
                p_module        => 'get_score_benelux',
                p_line_number   => NULL,
                p_log_message   => ' get_score_benelux  Score : ' || ln_score);

            ln_mapped_score   :=
                get_non_weight_mapping_score (P_CUST_ACCOUNT_ID, ln_score);

            LOG (
                p_module        => 'get_score_benelux',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_score_benelux Mapped Score : ' || ln_mapped_score);
        END IF;

        LOG (
            p_module        => 'get_score_benelux',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_score_benelux before Updating HZ_CUST_ACCOUNTS  : '
                || P_CUST_ACCOUNT_ID);

        OPEN insert_update_c (p_cust_account_id);

        FETCH insert_update_c INTO gc_insert_check;

        CLOSE insert_update_c;

        LOG (p_module        => 'get_score_benelux',
             p_line_number   => NULL,
             p_log_message   => ' iNSERT fLAG : ' || gc_insert_check);

        IF NVL (gc_insert_check, 'Y') = 'Y'
        THEN
            -- Start of changes for CCR0007180
            IF lc_use_weight <> 'N'
            THEN
                LOG (
                    p_module        => 'get_score_benelux',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' BEFORE INSERT using weighted score: '
                        || P_CUST_ACCOUNT_ID);
                INSERT_UPDATE (p_insert_update_flag => 'Y', p_aging_bucket_score => ln_aging_bucket_score * ln_aging_bucket_wt_new, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score * ln_book_order_wt_new, p_last_payment_score => ln_last_payment_score * ln_last_payment_wt_new, p_adl_score => ln_adl_score * ln_adl_wt_new, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);

                LOG (
                    p_module        => 'get_score_benelux',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' AFTER INSERT using weighted score: '
                        || gc_insert_check);
            -- End of changes for CCR0007180
            ELSE
                LOG (
                    p_module        => 'get_score_benelux',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' bEFORE INSERT : ' || P_CUST_ACCOUNT_ID);
                INSERT_UPDATE (p_insert_update_flag => 'Y', p_aging_bucket_score => ln_aging_bucket_score, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score, p_last_payment_score => ln_last_payment_score, p_adl_score => ln_adl_score, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);

                LOG (p_module        => 'get_score_benelux',
                     p_line_number   => NULL,
                     p_log_message   => ' aFTER INSERT : ' || gc_insert_check);
            END IF;
        ELSE
            -- Start of changes for CCR0007180
            IF lc_use_weight <> 'N'
            THEN
                INSERT_UPDATE (p_insert_update_flag => 'N', p_aging_bucket_score => ln_aging_bucket_score * ln_aging_bucket_wt_new, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score * ln_book_order_wt_new, p_last_payment_score => ln_last_payment_score * ln_last_payment_wt_new, p_adl_score => ln_adl_score * ln_adl_wt_new, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);
            -- End of changes for CCR0007180
            ELSE
                INSERT_UPDATE (p_insert_update_flag => 'N', p_aging_bucket_score => ln_aging_bucket_score, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score, p_last_payment_score => ln_last_payment_score, p_adl_score => ln_adl_score, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);
            END IF;
        END IF;

        LOG (
            p_module        => 'get_score_benelux',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_score_benelux after Updating HZ_CUST_ACCOUNTS  : '
                || P_CUST_ACCOUNT_ID);


        LOG (
            p_module        => 'get_score_benelux',
            p_line_number   => NULL,
            p_log_message   =>
                ' End Scoring for Account : ' || P_CUST_ACCOUNT_ID);


        RETURN ROUND (ln_mapped_score);
    EXCEPTION
        WHEN OTHERS
        THEN
            gc_exception_flag   := 'Y';
            LOG (
                p_module        => 'get_score_benelux',
                p_line_number   => NULL,
                p_log_message   =>
                       ' get_score_benelux  Booked Order Score : '
                    || ln_book_order_score);
            XXDO_GEH_PKG.record_error (
                gc_module,
                P_CUST_ACCOUNT_ID,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                gn_user_id,
                'Code pointer : ' || 'Error in get_score_benelux',
                'Deckers Customer Account Scoring Program ',
                (gn_org_id));
            ln_mapped_score     := -1;
            RETURN ln_mapped_score;
    END get_score_benelux;

    -- Start of Change for CCR0009857

    /*******************************************************************************
      * Funtion Name : get_score_Italy
      * Description  : This Function will generate and return the final mapped score
      *                for a given cust_account_id
      * Parameters   :P_CUST_ACCOUNT_ID
                     :P_SCORE_COMPONENT_ID
      * --------------------------------------------------------------------------- */

    FUNCTION get_score_Italy (P_CUST_ACCOUNT_ID      IN NUMBER,
                              P_SCORE_COMPONENT_ID   IN NUMBER)
        RETURN NUMBER
    IS
        ln_score                 NUMBER := 0;
        ln_aging_bucket_score    NUMBER := 0;
        ln_aging_bucket_wt       NUMBER := 0;
        ln_last_payment_score    NUMBER := 0;
        ln_last_payment_wt       NUMBER := 0;
        ln_book_order_score      NUMBER := 0;
        ln_book_order_wt         NUMBER := 0;
        ln_adl_score             NUMBER := 0;
        ln_adl_wt                NUMBER := 0;
        lc_prorate_score         VARCHAR2 (1);
        ln_mapped_score          NUMBER := 0;
        lc_use_weight            VARCHAR2 (1);
        ln_aging_bucket_wt_new   NUMBER := 0;
        ln_last_payment_wt_new   NUMBER := 0;
        ln_book_order_wt_new     NUMBER := 0;
        ln_adl_wt_new            NUMBER := 0;

        CURSOR insert_update_c (p_cust_acc_id IN NUMBER)
        IS
            SELECT DECODE (COUNT (*), 0, 'Y', 'N')
              FROM xxd_iex_metrics_tbl
             WHERE cust_account_id = p_cust_acc_id AND org_id = gn_org_id;
    BEGIN
        SET_ORG_ID;

        gn_cust_account_id       := P_CUST_ACCOUNT_ID;
        gc_log_profile_value     :=
            NVL (apps.fnd_profile.VALUE ('XXDO_GEH_LOG_ENABLE'), 'N');
        gc_exception_flag        := 'N';

        LOG (
            p_module        => 'get_score_Italy',
            p_line_number   => NULL,
            p_log_message   =>
                ' Start Scoring for Account : ' || P_CUST_ACCOUNT_ID);

        ln_aging_bucket_score    :=
            get_aging_bucket_avg_score_it (P_CUST_ACCOUNT_ID);

        LOG (
            p_module        => 'get_score_Italy',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_score_Italy  Aging Bucket Score : '
                || ln_aging_bucket_score);



        LOG (
            p_module        => 'get_score_Italy',
            p_line_number   => NULL,
            p_log_message   =>
                ' get_score_Italy  Aging Bucket  : ' || v_aging_bucket);


        LOG (
            p_module        => 'get_score_Italy',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_score_Italy  Global Default Aging Bucket  : '
                || gc_default_aging_bucket);
        lc_use_weight            :=
            NVL (apps.fnd_profile.VALUE ('XXDO_IEX_USE_WEIGHT'), 'N');

        -- Start of Changes for CCR0007180
        ln_aging_bucket_wt_new   := get_Weight (gc_score_component1); --'AGING_WATERFALL'
        ln_last_payment_wt_new   := get_Weight (gc_risk_component1); --'LAST_PAYMENT'
        ln_book_order_wt_new     := get_Weight (gc_risk_component2); --'BOOKED_ORDERS'
        ln_adl_wt_new            := get_Weight (gc_risk_component3); --'ADL_TREND'
        -- End of Changes for CCR0007180

        LOG (p_module        => 'get_score_Italy',
             p_line_number   => NULL,
             p_log_message   => 'get_score_Italy : ' || lc_use_weight);

        IF lc_use_weight <> 'N'
        THEN
            IF v_aging_bucket <> gc_default_aging_bucket
            THEN
                LOG (
                    p_module        => 'get_score_Italy',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' get_score_Italy  Aging Bucket is not  Global Default Aging Bucket');



                ln_last_payment_score   :=
                    get_last_payment_score (P_CUST_ACCOUNT_ID);

                LOG (
                    p_module        => 'get_score_Italy',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_Italy  Last Payment Score : '
                        || ln_last_payment_score);



                ln_book_order_score   :=
                    get_booked_order_score (P_CUST_ACCOUNT_ID);

                LOG (
                    p_module        => 'get_score_Italy',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_Italy  Booked Order Score : '
                        || ln_book_order_score);



                ln_adl_score         := get_adl_score (P_CUST_ACCOUNT_ID);

                LOG (
                    p_module        => 'get_score_Italy',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' get_score_Italy  ADL Score : ' || ln_adl_score);


                ln_aging_bucket_wt   := get_Weight (gc_score_component1); --'AGING_WATERFALL'

                LOG (
                    p_module        => 'get_score_Italy',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_Italy  Aging Bucket Wt : '
                        || ln_aging_bucket_wt);



                ln_last_payment_wt   := get_Weight (gc_risk_component1); --'LAST_PAYMENT'
                LOG (
                    p_module        => 'get_score_Italy',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_Italy  Last Payment Wt : '
                        || ln_last_payment_wt);



                ln_book_order_wt     := get_Weight (gc_risk_component2); --'BOOKED_ORDERS'

                LOG (
                    p_module        => 'get_score_Italy',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_Italy  Booked Order Wt : '
                        || ln_book_order_wt);


                ln_adl_wt            := get_Weight (gc_risk_component3); --'ADL_TREND'
                LOG (
                    p_module        => 'get_score_Italy',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' get_score_Italy  ADL Wt : ' || ln_adl_wt);


                lc_prorate_score     :=
                    NVL (apps.fnd_profile.VALUE ('XXDO_IEX_PRORATE_SCORE'),
                         'N');

                LOG (
                    p_module        => 'get_score_Italy',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_Italy  Pro-Rate profile : '
                        || lc_prorate_score);



                ln_score             :=
                    caluclate_score (ln_aging_bucket_score, ln_aging_bucket_wt, ln_last_payment_score, ln_last_payment_wt, ln_book_order_score, ln_book_order_wt, ln_adl_score, ln_adl_wt, lc_prorate_score
                                     , lc_use_weight);
            ELSE
                LOG (
                    p_module        => 'get_score_Italy',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' get_score_Italy  Only Aging Bucket default score is considered if amount due remaining is 0');


                ln_score   := ln_aging_bucket_score;
            END IF;

            LOG (
                p_module        => 'get_score_Italy',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_score_Italy Score : ' || ln_aging_bucket_score);

            /* Start of changes for CCR0007180 */
            ln_mapped_score   :=
                get_non_weight_mapping_score (P_CUST_ACCOUNT_ID, ln_score);
            /* End of changes for CCR0007180 */

            --ln_mapped_score := get_mapped_score (ln_score, v_aging_bucket);
            LOG (
                p_module        => 'get_score_Italy',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_score_Italy Mapped Score : ' || ln_mapped_score);
        ELSE
            LOG (
                p_module        => 'get_score_Italy',
                p_line_number   => NULL,
                p_log_message   =>
                    ' When XXDO" Use Weights profile is set to no');

            ln_last_payment_score   :=
                get_last_payment_score (P_CUST_ACCOUNT_ID);

            LOG (
                p_module        => 'get_score_Italy',
                p_line_number   => NULL,
                p_log_message   =>
                       ' get_score_Italy  Last Payment Score : '
                    || ln_last_payment_score);



            ln_book_order_score   :=
                get_booked_order_score (P_CUST_ACCOUNT_ID);

            LOG (
                p_module        => 'get_score_Italy',
                p_line_number   => NULL,
                p_log_message   =>
                       ' get_score_Italy  Booked Order Score : '
                    || ln_book_order_score);



            ln_adl_score   := get_adl_score (P_CUST_ACCOUNT_ID);

            LOG (
                p_module        => 'get_score_Italy',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_score_Italy  ADL Score : ' || ln_adl_score);

            ln_score       :=
                  NVL (ln_aging_bucket_score, 0)
                --    + NVL (ln_aging_bucket_wt, 0)
                + NVL (ln_last_payment_score, 0)
                --    + NVL (ln_last_payment_wt, 0)
                + NVL (ln_adl_score, 0)
                + NVL (ln_book_order_score, 0);

            LOG (p_module        => 'get_score_Italy',
                 p_line_number   => NULL,
                 p_log_message   => ' get_score_Italy  Score : ' || ln_score);

            ln_mapped_score   :=
                get_non_weight_mapping_score (P_CUST_ACCOUNT_ID, ln_score);

            LOG (
                p_module        => 'get_score_Italy',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_score_Italy Mapped Score : ' || ln_mapped_score);
        END IF;

        LOG (
            p_module        => 'get_score_Italy',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_score_Italy before Updating HZ_CUST_ACCOUNTS  : '
                || P_CUST_ACCOUNT_ID);

        OPEN insert_update_c (p_cust_account_id);

        FETCH insert_update_c INTO gc_insert_check;

        CLOSE insert_update_c;

        LOG (p_module        => 'get_score_Italy',
             p_line_number   => NULL,
             p_log_message   => ' Insert Flag : ' || gc_insert_check);

        IF NVL (gc_insert_check, 'Y') = 'Y'
        THEN
            -- Start of changes for CCR0007180
            IF lc_use_weight <> 'N'
            THEN
                LOG (
                    p_module        => 'get_score_Italy',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' BEFORE INSERT using weighted score: '
                        || P_CUST_ACCOUNT_ID);
                INSERT_UPDATE (p_insert_update_flag => 'Y', p_aging_bucket_score => ln_aging_bucket_score * ln_aging_bucket_wt_new, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score * ln_book_order_wt_new, p_last_payment_score => ln_last_payment_score * ln_last_payment_wt_new, p_adl_score => ln_adl_score * ln_adl_wt_new, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);

                LOG (
                    p_module        => 'get_score_Italy',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' AFTER INSERT using weighted score: '
                        || gc_insert_check);
            -- End of changes for CCR0007180
            ELSE
                LOG (
                    p_module        => 'get_score_Italy',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' Before INSERT : ' || P_CUST_ACCOUNT_ID);
                INSERT_UPDATE (p_insert_update_flag => 'Y', p_aging_bucket_score => ln_aging_bucket_score, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score, p_last_payment_score => ln_last_payment_score, p_adl_score => ln_adl_score, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);

                LOG (p_module        => 'get_score_Italy',
                     p_line_number   => NULL,
                     p_log_message   => ' After INSERT : ' || gc_insert_check);
            END IF;
        ELSE
            IF lc_use_weight <> 'N'
            THEN
                INSERT_UPDATE (p_insert_update_flag => 'N', p_aging_bucket_score => ln_aging_bucket_score * ln_aging_bucket_wt_new, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score * ln_book_order_wt_new, p_last_payment_score => ln_last_payment_score * ln_last_payment_wt_new, p_adl_score => ln_adl_score * ln_adl_wt_new, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);
            ELSE
                INSERT_UPDATE (p_insert_update_flag => 'N', p_aging_bucket_score => ln_aging_bucket_score, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score, p_last_payment_score => ln_last_payment_score, p_adl_score => ln_adl_score, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);
            END IF;
        END IF;

        LOG (
            p_module        => 'get_score_Italy',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_score_Italy after Updating HZ_CUST_ACCOUNTS  : '
                || P_CUST_ACCOUNT_ID);


        LOG (
            p_module        => 'get_score_Italy',
            p_line_number   => NULL,
            p_log_message   =>
                ' End Scoring for Account : ' || P_CUST_ACCOUNT_ID);


        RETURN ROUND (ln_mapped_score);
    EXCEPTION
        WHEN OTHERS
        THEN
            gc_exception_flag   := 'Y';
            LOG (
                p_module        => 'get_score_Italy',
                p_line_number   => NULL,
                p_log_message   =>
                       ' get_score_Italy  Booked Order Score : '
                    || ln_book_order_score);
            XXDO_GEH_PKG.record_error (
                gc_module,
                P_CUST_ACCOUNT_ID,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                gn_user_id,
                'Code pointer : ' || 'Error in get_score_Italy',
                'Deckers Customer Account Scoring Program ',
                (gn_org_id));
            ln_mapped_score     := -1;
            RETURN ln_mapped_score;
    END get_score_Italy;

    -- End of Change for CCR0009857

    /*Start of changes as part of Switzerland Project by srinath siricilla on 07-NOV-2016*/
    /*******************************************************************************
       * Funtion Name : get_score_switzerland
       * Description  : This Function will generate and return the final mapped score
       *                for a given cust_account_id
       * Parameters   :P_CUST_ACCOUNT_ID
                      :P_SCORE_COMPONENT_ID
       * --------------------------------------------------------------------------- */

    FUNCTION get_score_switzerland (P_CUST_ACCOUNT_ID      IN NUMBER,
                                    P_SCORE_COMPONENT_ID   IN NUMBER)
        RETURN NUMBER
    IS
        ln_score                 NUMBER := 0;
        ln_aging_bucket_score    NUMBER := 0;
        ln_aging_bucket_wt       NUMBER := 0;
        ln_last_payment_score    NUMBER := 0;
        ln_last_payment_wt       NUMBER := 0;
        ln_book_order_score      NUMBER := 0;
        ln_book_order_wt         NUMBER := 0;
        ln_adl_score             NUMBER := 0;
        ln_adl_wt                NUMBER := 0;
        lc_prorate_score         VARCHAR2 (1);
        ln_mapped_score          NUMBER := 0;
        lc_use_weight            VARCHAR2 (1);
        -- Start of Changes for CCR0007180
        ln_aging_bucket_wt_new   NUMBER := 0;
        ln_last_payment_wt_new   NUMBER := 0;
        ln_book_order_wt_new     NUMBER := 0;
        ln_adl_wt_new            NUMBER := 0;

        -- End of Changes for CCR0007180

        CURSOR insert_update_c (p_cust_acc_id IN NUMBER)
        IS
            SELECT DECODE (COUNT (*), 0, 'Y', 'N')
              FROM xxd_iex_metrics_tbl
             WHERE cust_account_id = p_cust_acc_id AND org_id = gn_org_id;
    BEGIN
        SET_ORG_ID;

        --xxv_debug_prc('Flow Started - Test SZ');

        gn_cust_account_id       := P_CUST_ACCOUNT_ID;
        gc_log_profile_value     :=
            NVL (apps.fnd_profile.VALUE ('XXDO_GEH_LOG_ENABLE'), 'N');
        gc_exception_flag        := 'N';

        LOG (
            p_module        => 'get_score_switzerland',
            p_line_number   => NULL,
            p_log_message   =>
                ' Start Scoring for Account : ' || P_CUST_ACCOUNT_ID);

        ln_aging_bucket_score    :=
            get_aging_bucket_avg_score_sz (P_CUST_ACCOUNT_ID);

        LOG (
            p_module        => 'get_score_switzerland',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_score_switzerland  Aging Bucket Score : '
                || ln_aging_bucket_score);



        LOG (
            p_module        => 'get_score_switzerland',
            p_line_number   => NULL,
            p_log_message   =>
                ' get_score_switzerland  Aging Bucket  : ' || v_aging_bucket);


        LOG (
            p_module        => 'get_score_switzerland',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_score_switzerland  Global Default Aging Bucket  : '
                || gc_default_aging_bucket);
        lc_use_weight            :=
            NVL (apps.fnd_profile.VALUE ('XXDO_IEX_USE_WEIGHT'), 'N');

        -- Start of Changes for CCR0007180
        ln_aging_bucket_wt_new   := get_Weight (gc_score_component1); --'AGING_WATERFALL'
        ln_last_payment_wt_new   := get_Weight (gc_risk_component1); --'LAST_PAYMENT'
        ln_book_order_wt_new     := get_Weight (gc_risk_component2); --'BOOKED_ORDERS'
        ln_adl_wt_new            := get_Weight (gc_risk_component3); --'ADL_TREND'
        -- End of Changes for CCR0007180

        LOG (p_module        => 'get_score_switzerland',
             p_line_number   => NULL,
             p_log_message   => 'lc_use_weight : ' || lc_use_weight);

        IF lc_use_weight <> 'N'
        THEN
            IF v_aging_bucket <> gc_default_aging_bucket
            THEN
                LOG (
                    p_module        => 'get_score_switzerland',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' get_score_switzerland  Aging Bucket is not  Global Default Aging Bucket');



                ln_last_payment_score   :=
                    get_last_payment_score (P_CUST_ACCOUNT_ID);

                LOG (
                    p_module        => 'get_score_switzerland',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_switzerland  Last Payment Score : '
                        || ln_last_payment_score);



                ln_book_order_score   :=
                    get_booked_order_score (P_CUST_ACCOUNT_ID);

                LOG (
                    p_module        => 'get_score_switzerland',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_switzerland  Booked Order Score : '
                        || ln_book_order_score);



                ln_adl_score         := get_adl_score (P_CUST_ACCOUNT_ID);

                LOG (
                    p_module        => 'get_score_switzerland',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_switzerland  ADL Score : '
                        || ln_adl_score);


                ln_aging_bucket_wt   := get_Weight (gc_score_component1); --'AGING_WATERFALL'

                LOG (
                    p_module        => 'get_score_switzerland',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_switzerland  Aging Bucket Wt : '
                        || ln_aging_bucket_wt);



                ln_last_payment_wt   := get_Weight (gc_risk_component1); --'LAST_PAYMENT'
                LOG (
                    p_module        => 'get_score_switzerland',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_switzerland  Last Payment Wt : '
                        || ln_last_payment_wt);



                ln_book_order_wt     := get_Weight (gc_risk_component2); --'BOOKED_ORDERS'

                LOG (
                    p_module        => 'get_score_switzerland',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_switzerland  Booked Order Wt : '
                        || ln_book_order_wt);


                ln_adl_wt            := get_Weight (gc_risk_component3); --'ADL_TREND'
                LOG (
                    p_module        => 'get_score_switzerland',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' get_score_switzerland  ADL Wt : ' || ln_adl_wt);


                lc_prorate_score     :=
                    NVL (apps.fnd_profile.VALUE ('XXDO_IEX_PRORATE_SCORE'),
                         'N');

                LOG (
                    p_module        => 'get_score_switzerland',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_switzerland  Pro-Rate profile : '
                        || lc_prorate_score);



                ln_score             :=
                    caluclate_score (ln_aging_bucket_score, ln_aging_bucket_wt, ln_last_payment_score, ln_last_payment_wt, ln_book_order_score, ln_book_order_wt, ln_adl_score, ln_adl_wt, lc_prorate_score
                                     , lc_use_weight); -- Added for CCR0007810);
            ELSE
                LOG (
                    p_module        => 'get_score_switzerland',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' get_score_switzerland  Only Aging Bucket default score is considered if amount due remaining is 0');


                ln_score   := ln_aging_bucket_score;
            END IF;

            LOG (
                p_module        => 'get_score_switzerland',
                p_line_number   => NULL,
                p_log_message   =>
                       ' get_score_switzerland Score : '
                    || ln_aging_bucket_score);

            /* Start of changes for CCR0007180 */
            ln_mapped_score   :=
                get_non_weight_mapping_score (P_CUST_ACCOUNT_ID, ln_score);
            /* End of changes for CCR0007180 */

            --ln_mapped_score := get_mapped_score (ln_score, v_aging_bucket);
            LOG (
                p_module        => 'get_score_switzerland',
                p_line_number   => NULL,
                p_log_message   =>
                       ' get_score_switzerland Mapped Score : '
                    || ln_mapped_score);
        ELSE
            LOG (
                p_module        => 'get_score_switzerland',
                p_line_number   => NULL,
                p_log_message   =>
                    ' When XXDO" Use Weights profile is set to no');

            ln_last_payment_score   :=
                get_last_payment_score (P_CUST_ACCOUNT_ID);

            LOG (
                p_module        => 'get_score_switzerland',
                p_line_number   => NULL,
                p_log_message   =>
                       ' get_score_switzerland  Last Payment Score : '
                    || ln_last_payment_score);



            ln_book_order_score   :=
                get_booked_order_score (P_CUST_ACCOUNT_ID);

            LOG (
                p_module        => 'get_score_switzerland',
                p_line_number   => NULL,
                p_log_message   =>
                       ' get_score_switzerland  Booked Order Score : '
                    || ln_book_order_score);



            ln_adl_score   := get_adl_score (P_CUST_ACCOUNT_ID);

            LOG (
                p_module        => 'get_score_switzerland',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_score_switzerland  ADL Score : ' || ln_adl_score);

            ln_score       :=
                  NVL (ln_aging_bucket_score, 0)
                --    + NVL (ln_aging_bucket_wt, 0)
                + NVL (ln_last_payment_score, 0)
                --    + NVL (ln_last_payment_wt, 0)
                + NVL (ln_adl_score, 0)
                + NVL (ln_book_order_score, 0);

            LOG (
                p_module        => 'get_score_switzerland',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_score_switzerland  Score : ' || ln_score);

            ln_mapped_score   :=
                get_non_weight_mapping_score (P_CUST_ACCOUNT_ID, ln_score);

            LOG (
                p_module        => 'get_score_switzerland',
                p_line_number   => NULL,
                p_log_message   =>
                       ' get_score_switzerland Mapped Score : '
                    || ln_mapped_score);
        END IF;

        LOG (
            p_module        => 'get_score_switzerland',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_score_switzerland before Updating HZ_CUST_ACCOUNTS  : '
                || P_CUST_ACCOUNT_ID);

        OPEN insert_update_c (p_cust_account_id);

        FETCH insert_update_c INTO gc_insert_check;

        CLOSE insert_update_c;

        LOG (p_module        => 'get_score_switzerland',
             p_line_number   => NULL,
             p_log_message   => ' iNSERT fLAG : ' || gc_insert_check);

        IF NVL (gc_insert_check, 'Y') = 'Y'
        THEN
            -- Start of changes for CCR0007180
            IF lc_use_weight <> 'N'
            THEN
                LOG (
                    p_module        => 'get_score_us',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' BEFORE INSERT using weighted score: '
                        || P_CUST_ACCOUNT_ID);
                INSERT_UPDATE (p_insert_update_flag => 'Y', p_aging_bucket_score => ln_aging_bucket_score * ln_aging_bucket_wt_new, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score * ln_book_order_wt_new, p_last_payment_score => ln_last_payment_score * ln_last_payment_wt_new, p_adl_score => ln_adl_score * ln_adl_wt_new, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);

                LOG (
                    p_module        => 'get_score_switzerland',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' AFTER INSERT using weighted score: '
                        || gc_insert_check);
            -- End of changes for CCR0007180
            ELSE
                LOG (
                    p_module        => 'get_score_switzerland',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' bEFORE INSERT : ' || P_CUST_ACCOUNT_ID);
                INSERT_UPDATE (p_insert_update_flag => 'Y', p_aging_bucket_score => ln_aging_bucket_score, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score, p_last_payment_score => ln_last_payment_score, p_adl_score => ln_adl_score, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);

                LOG (p_module        => 'get_score_switzerland',
                     p_line_number   => NULL,
                     p_log_message   => ' aFTER INSERT : ' || gc_insert_check);
            END IF;
        ELSE
            -- Start of changes for CCR0007180
            IF lc_use_weight <> 'N'
            THEN
                INSERT_UPDATE (p_insert_update_flag => 'N', p_aging_bucket_score => ln_aging_bucket_score * ln_aging_bucket_wt_new, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score * ln_book_order_wt_new, p_last_payment_score => ln_last_payment_score * ln_last_payment_wt_new, p_adl_score => ln_adl_score * ln_adl_wt_new, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);
            -- End of changes for CCR0007180
            ELSE
                INSERT_UPDATE (p_insert_update_flag => 'N', p_aging_bucket_score => ln_aging_bucket_score, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score, p_last_payment_score => ln_last_payment_score, p_adl_score => ln_adl_score, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);
            END IF;
        END IF;

        LOG (
            p_module        => 'get_score_switzerland',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_score_switzerland after Updating HZ_CUST_ACCOUNTS  : '
                || P_CUST_ACCOUNT_ID);


        LOG (
            p_module        => 'get_score_switzerland',
            p_line_number   => NULL,
            p_log_message   =>
                ' End Scoring for Account : ' || P_CUST_ACCOUNT_ID);


        RETURN ROUND (ln_mapped_score);
    EXCEPTION
        WHEN OTHERS
        THEN
            gc_exception_flag   := 'Y';
            LOG (
                p_module        => 'get_score_switzerland',
                p_line_number   => NULL,
                p_log_message   =>
                       ' get_score_switzerland  Booked Order Score : '
                    || ln_book_order_score);
            XXDO_GEH_PKG.record_error (
                gc_module,
                P_CUST_ACCOUNT_ID,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                gn_user_id,
                'Code pointer : ' || 'Error in get_score_switzerland',
                'Deckers Customer Account Scoring Program ',
                (gn_org_id));
            ln_mapped_score     := -1;
            RETURN ln_mapped_score;
    END get_score_switzerland;

    /*End of changes as part of Switzerland Project by srinath siricilla on 07-NOV-2016*/

    /*******************************************************************************
    * Funtion Name : get_score_germany
    * Description  : This Function will generate and return the final mapped score
    *                for a given cust_account_id
    * Parameters   :P_CUST_ACCOUNT_ID
                   :P_SCORE_COMPONENT_ID
    * --------------------------------------------------------------------------- */

    FUNCTION get_score_germany (P_CUST_ACCOUNT_ID      IN NUMBER,
                                P_SCORE_COMPONENT_ID   IN NUMBER)
        RETURN NUMBER
    IS
        ln_score                 NUMBER := 0;
        ln_aging_bucket_score    NUMBER := 0;
        ln_aging_bucket_wt       NUMBER := 0;
        ln_last_payment_score    NUMBER := 0;
        ln_last_payment_wt       NUMBER := 0;
        ln_book_order_score      NUMBER := 0;
        ln_book_order_wt         NUMBER := 0;
        ln_adl_score             NUMBER := 0;
        ln_adl_wt                NUMBER := 0;
        lc_prorate_score         VARCHAR2 (1);
        ln_mapped_score          NUMBER := 0;
        lc_use_weight            VARCHAR2 (1);
        -- Start of Changes for CCR0007180
        ln_aging_bucket_wt_new   NUMBER := 0;
        ln_last_payment_wt_new   NUMBER := 0;
        ln_book_order_wt_new     NUMBER := 0;
        ln_adl_wt_new            NUMBER := 0;

        -- End of Changes for CCR0007180

        CURSOR insert_update_c (p_cust_acc_id IN NUMBER)
        IS
            SELECT DECODE (COUNT (*), 0, 'Y', 'N')
              FROM xxd_iex_metrics_tbl
             WHERE cust_account_id = p_cust_acc_id AND org_id = gn_org_id;
    BEGIN
        SET_ORG_ID;

        --xxv_debug_prc('Flow Started - Test Germany');

        gn_cust_account_id       := P_CUST_ACCOUNT_ID;
        gc_log_profile_value     :=
            NVL (apps.fnd_profile.VALUE ('XXDO_GEH_LOG_ENABLE'), 'N');
        gc_exception_flag        := 'N';

        LOG (
            p_module        => 'get_score_germany',
            p_line_number   => NULL,
            p_log_message   =>
                ' Start Scoring for Account : ' || P_CUST_ACCOUNT_ID);

        ln_aging_bucket_score    :=
            get_aging_bucket_avg_score_gr (P_CUST_ACCOUNT_ID);

        LOG (
            p_module        => 'get_score_germany',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_score_germany  Aging Bucket Score : '
                || ln_aging_bucket_score);



        LOG (
            p_module        => 'get_score_germany',
            p_line_number   => NULL,
            p_log_message   =>
                ' get_score_germany  Aging Bucket  : ' || v_aging_bucket);


        LOG (
            p_module        => 'get_score_germany',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_score_germany  Global Default Aging Bucket  : '
                || gc_default_aging_bucket);
        lc_use_weight            :=
            NVL (apps.fnd_profile.VALUE ('XXDO_IEX_USE_WEIGHT'), 'N');

        -- Start of Changes for CCR0007180
        ln_aging_bucket_wt_new   := get_Weight (gc_score_component1); --'AGING_WATERFALL'
        ln_last_payment_wt_new   := get_Weight (gc_risk_component1); --'LAST_PAYMENT'
        ln_book_order_wt_new     := get_Weight (gc_risk_component2); --'BOOKED_ORDERS'
        ln_adl_wt_new            := get_Weight (gc_risk_component3); --'ADL_TREND'
        -- End of Changes for CCR0007180

        LOG (p_module        => 'get_score_germany',
             p_line_number   => NULL,
             p_log_message   => 'lc_use_weight : ' || lc_use_weight);

        IF lc_use_weight <> 'N'
        THEN
            IF v_aging_bucket <> gc_default_aging_bucket
            THEN
                LOG (
                    p_module        => 'get_score_germany',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' get_score_germany  Aging Bucket is not  Global Default Aging Bucket');



                ln_last_payment_score   :=
                    get_last_payment_score (P_CUST_ACCOUNT_ID);

                LOG (
                    p_module        => 'get_score_germany',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_germany  Last Payment Score : '
                        || ln_last_payment_score);



                ln_book_order_score   :=
                    get_booked_order_score (P_CUST_ACCOUNT_ID);

                LOG (
                    p_module        => 'get_score_germany',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_germany  Booked Order Score : '
                        || ln_book_order_score);



                ln_adl_score         := get_adl_score (P_CUST_ACCOUNT_ID);

                LOG (
                    p_module        => 'get_score_germany',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' get_score_germany  ADL Score : ' || ln_adl_score);


                ln_aging_bucket_wt   := get_Weight (gc_score_component1); --'AGING_WATERFALL'

                LOG (
                    p_module        => 'get_score_germany',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_germany  Aging Bucket Wt : '
                        || ln_aging_bucket_wt);



                ln_last_payment_wt   := get_Weight (gc_risk_component1); --'LAST_PAYMENT'
                LOG (
                    p_module        => 'get_score_germany',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_germany  Last Payment Wt : '
                        || ln_last_payment_wt);



                ln_book_order_wt     := get_Weight (gc_risk_component2); --'BOOKED_ORDERS'

                LOG (
                    p_module        => 'get_score_germany',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_germany  Booked Order Wt : '
                        || ln_book_order_wt);


                ln_adl_wt            := get_Weight (gc_risk_component3); --'ADL_TREND'
                LOG (
                    p_module        => 'get_score_germany',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' get_score_germany  ADL Wt : ' || ln_adl_wt);


                lc_prorate_score     :=
                    NVL (apps.fnd_profile.VALUE ('XXDO_IEX_PRORATE_SCORE'),
                         'N');

                LOG (
                    p_module        => 'get_score_germany',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_germany  Pro-Rate profile : '
                        || lc_prorate_score);



                ln_score             :=
                    caluclate_score (ln_aging_bucket_score, ln_aging_bucket_wt, ln_last_payment_score, ln_last_payment_wt, ln_book_order_score, ln_book_order_wt, ln_adl_score, ln_adl_wt, lc_prorate_score
                                     , lc_use_weight); -- Added for CCR0007810);
            ELSE
                LOG (
                    p_module        => 'get_score_germany',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' get_score_germany  Only Aging Bucket default score is considered if amount due remaining is 0');


                ln_score   := ln_aging_bucket_score;
            END IF;

            LOG (
                p_module        => 'get_score_germany',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_score_germany Score : ' || ln_aging_bucket_score);

            /* Start of changes for CCR0007180 */
            ln_mapped_score   :=
                get_non_weight_mapping_score (P_CUST_ACCOUNT_ID, ln_score);
            /* End of changes for CCR0007180 */

            -- ln_mapped_score := get_mapped_score (ln_score, v_aging_bucket);
            LOG (
                p_module        => 'get_score_germany',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_score_germany Mapped Score : ' || ln_mapped_score);
        ELSE
            LOG (
                p_module        => 'get_score_germany',
                p_line_number   => NULL,
                p_log_message   =>
                    ' When XXDO" Use Weights profile is set to no');

            ln_last_payment_score   :=
                get_last_payment_score (P_CUST_ACCOUNT_ID);

            LOG (
                p_module        => 'get_score_germany',
                p_line_number   => NULL,
                p_log_message   =>
                       ' get_score_germany  Last Payment Score : '
                    || ln_last_payment_score);



            ln_book_order_score   :=
                get_booked_order_score (P_CUST_ACCOUNT_ID);

            LOG (
                p_module        => 'get_score_germany',
                p_line_number   => NULL,
                p_log_message   =>
                       ' get_score_germany  Booked Order Score : '
                    || ln_book_order_score);



            ln_adl_score   := get_adl_score (P_CUST_ACCOUNT_ID);

            LOG (
                p_module        => 'get_score_germany',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_score_germany  ADL Score : ' || ln_adl_score);

            ln_score       :=
                  NVL (ln_aging_bucket_score, 0)
                --    + NVL (ln_aging_bucket_wt, 0)
                + NVL (ln_last_payment_score, 0)
                --    + NVL (ln_last_payment_wt, 0)
                + NVL (ln_adl_score, 0)
                + NVL (ln_book_order_score, 0);

            LOG (
                p_module        => 'get_score_germany',
                p_line_number   => NULL,
                p_log_message   => ' get_score_germany  Score : ' || ln_score);

            ln_mapped_score   :=
                get_non_weight_mapping_score (P_CUST_ACCOUNT_ID, ln_score);

            LOG (
                p_module        => 'get_score_germany',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_score_germany Mapped Score : ' || ln_mapped_score);
        END IF;

        LOG (
            p_module        => 'get_score_germany',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_score_germany before Updating HZ_CUST_ACCOUNTS  : '
                || P_CUST_ACCOUNT_ID);

        OPEN insert_update_c (p_cust_account_id);

        FETCH insert_update_c INTO gc_insert_check;

        CLOSE insert_update_c;

        LOG (p_module        => 'get_score_germany',
             p_line_number   => NULL,
             p_log_message   => ' iNSERT fLAG : ' || gc_insert_check);

        IF NVL (gc_insert_check, 'Y') = 'Y'
        THEN
            -- Start of changes for CCR0007180
            IF lc_use_weight <> 'N'
            THEN
                LOG (
                    p_module        => 'get_score_germany',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' BEFORE INSERT using weighted score: '
                        || P_CUST_ACCOUNT_ID);
                INSERT_UPDATE (p_insert_update_flag => 'Y', p_aging_bucket_score => ln_aging_bucket_score * ln_aging_bucket_wt_new, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score * ln_book_order_wt_new, p_last_payment_score => ln_last_payment_score * ln_last_payment_wt_new, p_adl_score => ln_adl_score * ln_adl_wt_new, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);

                LOG (
                    p_module        => 'get_score_germany',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' AFTER INSERT using weighted score: '
                        || gc_insert_check);
            -- End of changes for CCR0007180
            ELSE
                LOG (
                    p_module        => 'get_score_germany',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' bEFORE INSERT : ' || P_CUST_ACCOUNT_ID);
                INSERT_UPDATE (p_insert_update_flag => 'Y', p_aging_bucket_score => ln_aging_bucket_score, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score, p_last_payment_score => ln_last_payment_score, p_adl_score => ln_adl_score, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);

                LOG (p_module        => 'get_score_germany',
                     p_line_number   => NULL,
                     p_log_message   => ' aFTER INSERT : ' || gc_insert_check);
            END IF;
        ELSE
            -- Start of changes for CCR0007180
            IF lc_use_weight <> 'N'
            THEN
                INSERT_UPDATE (p_insert_update_flag => 'N', p_aging_bucket_score => ln_aging_bucket_score * ln_aging_bucket_wt_new, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score * ln_book_order_wt_new, p_last_payment_score => ln_last_payment_score * ln_last_payment_wt_new, p_adl_score => ln_adl_score * ln_adl_wt_new, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);
            -- End of changes for CCR0007180
            ELSE
                INSERT_UPDATE (p_insert_update_flag => 'N', p_aging_bucket_score => ln_aging_bucket_score, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score, p_last_payment_score => ln_last_payment_score, p_adl_score => ln_adl_score, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);
            END IF;
        END IF;

        LOG (
            p_module        => 'get_score_germany',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_score_germany after Updating HZ_CUST_ACCOUNTS  : '
                || P_CUST_ACCOUNT_ID);


        LOG (
            p_module        => 'get_score_germany',
            p_line_number   => NULL,
            p_log_message   =>
                ' End Scoring for Account : ' || P_CUST_ACCOUNT_ID);


        RETURN ROUND (ln_mapped_score);
    EXCEPTION
        WHEN OTHERS
        THEN
            gc_exception_flag   := 'Y';
            LOG (
                p_module        => 'get_score_germany',
                p_line_number   => NULL,
                p_log_message   =>
                       ' get_score_germany  Booked Order Score : '
                    || ln_book_order_score);
            XXDO_GEH_PKG.record_error (
                gc_module,
                P_CUST_ACCOUNT_ID,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                gn_user_id,
                'Code pointer : ' || 'Error in get_score_germany',
                'Deckers Customer Account Scoring Program ',
                (gn_org_id));
            ln_mapped_score     := -1;
            RETURN ln_mapped_score;
    END get_score_germany;

    /*******************************************************************************
    * Funtion Name : get_score_france
    * Description  : This Function will generate and return the final mapped score
    *                for a given cust_account_id
    * Parameters   :P_CUST_ACCOUNT_ID
                   :P_SCORE_COMPONENT_ID
    * --------------------------------------------------------------------------- */

    FUNCTION get_score_france (P_CUST_ACCOUNT_ID      IN NUMBER,
                               P_SCORE_COMPONENT_ID   IN NUMBER)
        RETURN NUMBER
    IS
        ln_score                 NUMBER := 0;
        ln_aging_bucket_score    NUMBER := 0;
        ln_aging_bucket_wt       NUMBER := 0;
        ln_last_payment_score    NUMBER := 0;
        ln_last_payment_wt       NUMBER := 0;
        ln_book_order_score      NUMBER := 0;
        ln_book_order_wt         NUMBER := 0;
        ln_adl_score             NUMBER := 0;
        ln_adl_wt                NUMBER := 0;
        lc_prorate_score         VARCHAR2 (1);
        ln_mapped_score          NUMBER := 0;
        lc_use_weight            VARCHAR2 (1);
        -- Start of Changes for CCR0007180
        ln_aging_bucket_wt_new   NUMBER := 0;
        ln_last_payment_wt_new   NUMBER := 0;
        ln_book_order_wt_new     NUMBER := 0;
        ln_adl_wt_new            NUMBER := 0;

        -- End of Changes for CCR0007180

        CURSOR insert_update_c (p_cust_acc_id IN NUMBER)
        IS
            SELECT DECODE (COUNT (*), 0, 'Y', 'N')
              FROM xxd_iex_metrics_tbl
             WHERE cust_account_id = p_cust_acc_id AND org_id = gn_org_id;
    BEGIN
        SET_ORG_ID;

        --xxv_debug_prc('Flow Started - Test FRance');

        gn_cust_account_id       := P_CUST_ACCOUNT_ID;
        gc_log_profile_value     :=
            NVL (apps.fnd_profile.VALUE ('XXDO_GEH_LOG_ENABLE'), 'N');
        gc_exception_flag        := 'N';

        LOG (
            p_module        => 'get_score_france',
            p_line_number   => NULL,
            p_log_message   =>
                ' Start Scoring for Account : ' || P_CUST_ACCOUNT_ID);

        ln_aging_bucket_score    :=
            get_aging_bucket_avg_score_fr (P_CUST_ACCOUNT_ID);

        LOG (
            p_module        => 'get_score_france',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_score_france  Aging Bucket Score : '
                || ln_aging_bucket_score);

        LOG (
            p_module        => 'get_score_france',
            p_line_number   => NULL,
            p_log_message   =>
                ' get_score_france  Aging Bucket  : ' || v_aging_bucket);


        LOG (
            p_module        => 'get_score_france',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_score_france  Global Default Aging Bucket  : '
                || gc_default_aging_bucket);
        lc_use_weight            :=
            NVL (apps.fnd_profile.VALUE ('XXDO_IEX_USE_WEIGHT'), 'N');

        -- Start of Changes for CCR0007180
        ln_aging_bucket_wt_new   := get_Weight (gc_score_component1); --'AGING_WATERFALL'
        ln_last_payment_wt_new   := get_Weight (gc_risk_component1); --'LAST_PAYMENT'
        ln_book_order_wt_new     := get_Weight (gc_risk_component2); --'BOOKED_ORDERS'
        ln_adl_wt_new            := get_Weight (gc_risk_component3); --'ADL_TREND'
        -- End of Changes for CCR0007180

        LOG (p_module        => 'get_score_france',
             p_line_number   => NULL,
             p_log_message   => 'lc_use_weight : ' || lc_use_weight);

        IF lc_use_weight <> 'N'
        THEN
            IF v_aging_bucket <> gc_default_aging_bucket
            THEN
                LOG (
                    p_module        => 'get_score_france',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' get_score_france  Aging Bucket is not  Global Default Aging Bucket');



                ln_last_payment_score   :=
                    get_last_payment_score (P_CUST_ACCOUNT_ID);

                LOG (
                    p_module        => 'get_score_france',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_france  Last Payment Score : '
                        || ln_last_payment_score);



                ln_book_order_score   :=
                    get_booked_order_score (P_CUST_ACCOUNT_ID);

                LOG (
                    p_module        => 'get_score_france',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_france  Booked Order Score : '
                        || ln_book_order_score);



                ln_adl_score         := get_adl_score (P_CUST_ACCOUNT_ID);

                LOG (
                    p_module        => 'get_score_france',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' get_score_france  ADL Score : ' || ln_adl_score);


                ln_aging_bucket_wt   := get_Weight (gc_score_component1); --'AGING_WATERFALL'

                LOG (
                    p_module        => 'get_score_france',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_france  Aging Bucket Wt : '
                        || ln_aging_bucket_wt);



                ln_last_payment_wt   := get_Weight (gc_risk_component1); --'LAST_PAYMENT'
                LOG (
                    p_module        => 'get_score_france',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_france  Last Payment Wt : '
                        || ln_last_payment_wt);



                ln_book_order_wt     := get_Weight (gc_risk_component2); --'BOOKED_ORDERS'

                LOG (
                    p_module        => 'get_score_france',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_france  Booked Order Wt : '
                        || ln_book_order_wt);


                ln_adl_wt            := get_Weight (gc_risk_component3); --'ADL_TREND'
                LOG (
                    p_module        => 'get_score_france',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' get_score_france  ADL Wt : ' || ln_adl_wt);


                lc_prorate_score     :=
                    NVL (apps.fnd_profile.VALUE ('XXDO_IEX_PRORATE_SCORE'),
                         'N');

                LOG (
                    p_module        => 'get_score_france',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_score_france  Pro-Rate profile : '
                        || lc_prorate_score);



                ln_score             :=
                    caluclate_score (ln_aging_bucket_score, ln_aging_bucket_wt, ln_last_payment_score, ln_last_payment_wt, ln_book_order_score, ln_book_order_wt, ln_adl_score, ln_adl_wt, lc_prorate_score
                                     , lc_use_weight); -- Added for CCR0007810);
            ELSE
                LOG (
                    p_module        => 'get_score_france',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' get_score_france  Only Aging Bucket default score is considered if amount due remaining is 0');


                ln_score   := ln_aging_bucket_score;
            END IF;

            LOG (
                p_module        => 'get_score_france',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_score_france Score : ' || ln_aging_bucket_score);

            /* Start of changes for CCR0007180 */
            ln_mapped_score   :=
                get_non_weight_mapping_score (P_CUST_ACCOUNT_ID, ln_score);
            /* End of changes for CCR0007180 */

            --ln_mapped_score := get_mapped_score (ln_score, v_aging_bucket);
            LOG (
                p_module        => 'get_score_france',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_score_france Mapped Score : ' || ln_mapped_score);
        ELSE
            LOG (
                p_module        => 'get_score_france',
                p_line_number   => NULL,
                p_log_message   =>
                    ' When XXDO" Use Weights profile is set to no');

            ln_last_payment_score   :=
                get_last_payment_score (P_CUST_ACCOUNT_ID);

            LOG (
                p_module        => 'get_score_france',
                p_line_number   => NULL,
                p_log_message   =>
                       ' get_score_france  Last Payment Score : '
                    || ln_last_payment_score);



            ln_book_order_score   :=
                get_booked_order_score (P_CUST_ACCOUNT_ID);

            LOG (
                p_module        => 'get_score_france',
                p_line_number   => NULL,
                p_log_message   =>
                       ' get_score_france  Booked Order Score : '
                    || ln_book_order_score);



            ln_adl_score   := get_adl_score (P_CUST_ACCOUNT_ID);

            LOG (
                p_module        => 'get_score_france',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_score_france  ADL Score : ' || ln_adl_score);

            ln_score       :=
                  NVL (ln_aging_bucket_score, 0)
                --    + NVL (ln_aging_bucket_wt, 0)
                + NVL (ln_last_payment_score, 0)
                --    + NVL (ln_last_payment_wt, 0)
                + NVL (ln_adl_score, 0)
                + NVL (ln_book_order_score, 0);

            LOG (p_module        => 'get_score_france',
                 p_line_number   => NULL,
                 p_log_message   => ' get_score_france  Score : ' || ln_score);

            ln_mapped_score   :=
                get_non_weight_mapping_score (P_CUST_ACCOUNT_ID, ln_score);

            LOG (
                p_module        => 'get_score_france',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_score_france Mapped Score : ' || ln_mapped_score);
        END IF;

        LOG (
            p_module        => 'get_score_france',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_score_france before Updating HZ_CUST_ACCOUNTS  : '
                || P_CUST_ACCOUNT_ID);

        OPEN insert_update_c (p_cust_account_id);

        FETCH insert_update_c INTO gc_insert_check;

        CLOSE insert_update_c;

        LOG (p_module        => 'get_score_france',
             p_line_number   => NULL,
             p_log_message   => ' iNSERT fLAG : ' || gc_insert_check);

        IF NVL (gc_insert_check, 'Y') = 'Y'
        THEN
            -- Start of changes for CCR0007180
            IF lc_use_weight <> 'N'
            THEN
                LOG (
                    p_module        => 'get_score_france',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' BEFORE INSERT using weighted score: '
                        || P_CUST_ACCOUNT_ID);
                INSERT_UPDATE (p_insert_update_flag => 'Y', p_aging_bucket_score => ln_aging_bucket_score * ln_aging_bucket_wt_new, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score * ln_book_order_wt_new, p_last_payment_score => ln_last_payment_score * ln_last_payment_wt_new, p_adl_score => ln_adl_score * ln_adl_wt_new, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);

                LOG (
                    p_module        => 'get_score_france',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' AFTER INSERT using weighted score: '
                        || gc_insert_check);
            -- End of changes for CCR0007180
            ELSE
                LOG (
                    p_module        => 'get_score_france',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' bEFORE INSERT : ' || P_CUST_ACCOUNT_ID);
                INSERT_UPDATE (p_insert_update_flag => 'Y', p_aging_bucket_score => ln_aging_bucket_score, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score, p_last_payment_score => ln_last_payment_score, p_adl_score => ln_adl_score, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);

                LOG (p_module        => 'get_score_france',
                     p_line_number   => NULL,
                     p_log_message   => ' aFTER INSERT : ' || gc_insert_check);
            END IF;
        ELSE
            -- Start of changes for CCR0007180
            IF lc_use_weight <> 'N'
            THEN
                INSERT_UPDATE (p_insert_update_flag => 'N', p_aging_bucket_score => ln_aging_bucket_score * ln_aging_bucket_wt_new, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score * ln_book_order_wt_new, p_last_payment_score => ln_last_payment_score * ln_last_payment_wt_new, p_adl_score => ln_adl_score * ln_adl_wt_new, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);
            -- End of changes for CCR0007180
            ELSE
                INSERT_UPDATE (p_insert_update_flag => 'N', p_aging_bucket_score => ln_aging_bucket_score, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score, p_last_payment_score => ln_last_payment_score, p_adl_score => ln_adl_score, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);
            END IF;
        END IF;

        LOG (
            p_module        => 'get_score_france',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_score_france after Updating HZ_CUST_ACCOUNTS  : '
                || P_CUST_ACCOUNT_ID);


        LOG (
            p_module        => 'get_score_france',
            p_line_number   => NULL,
            p_log_message   =>
                ' End Scoring for Account : ' || P_CUST_ACCOUNT_ID);


        RETURN ROUND (ln_mapped_score);
    EXCEPTION
        WHEN OTHERS
        THEN
            gc_exception_flag   := 'Y';
            LOG (
                p_module        => 'get_score_france',
                p_line_number   => NULL,
                p_log_message   =>
                       ' get_score_france  Booked Order Score : '
                    || ln_book_order_score);
            XXDO_GEH_PKG.record_error (
                gc_module,
                P_CUST_ACCOUNT_ID,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                gn_user_id,
                'Code pointer : ' || 'Error in get_score_france',
                'Deckers Customer Account Scoring Program ',
                (gn_org_id));
            ln_mapped_score     := -1;
            RETURN ln_mapped_score;
    END get_score_france;


    /*******************************************************************************
     * Funtion Name : get_last_payment_score
     * Description  : This Function will generate and return  LastPayment score
     *                for a given cust_account_id At Party Level
     * Parameters   :P_CUST_ACCOUNT_ID
     * --------------------------------------------------------------------------- */

    FUNCTION get_last_payment_score (P_CUST_ACCOUNT_ID IN NUMBER)
        RETURN NUMBER
    IS
        ln_days_from_last_payment   NUMBER := 0;
        ln_last_receipt_date        DATE;
        ln_score                    NUMBER := 0;
        ln_last_cash_appl_date      DATE;
        ln_party_id                 NUMBER;

        CURSOR get_party_c (P_CUST_ACCOUNT_ID NUMBER)
        IS
            SELECT party_id
              FROM hz_cust_accounts
             WHERE cust_account_id = P_CUST_ACCOUNT_ID;

        -- Commented below for defect# 170 by BT Tech team on 21-Oct-15
        /*  CURSOR last_payment_date_c ( p_party_id NUMBER)
          IS
             SELECT MAX (apply_date)
               FROM ar_receivable_applications_all araa,
                    ra_customer_trx_all rcta,
                    hz_cust_accounts hca
              WHERE araa.applied_customer_trx_id = rcta.customer_trx_id
                AND rcta.bill_to_customer_id = hca.cust_account_id
                AND hca.party_id = p_party_id
                AND rcta.org_id = gn_org_id; */
        -- Commented above for defect# 170 by BT Tech team on 21-Oct-15

        -- Added below for defect# 170 by BT Tech team on 21-Oct-15
        CURSOR last_payment_date_c (p_party_id NUMBER)
        IS
            SELECT MAX (acra.receipt_date)
              FROM ar_cash_receipts_all acra, hz_cust_accounts hca
             WHERE     acra.pay_from_customer = hca.cust_account_id
                   AND acra.org_id = gn_org_id
                   AND hca.party_id = p_party_id;

        -- Added below for defect# 170 by BT Tech team on 21-Oct-15

        CURSOR payemnt_score_c (p_days_from_last_payment NUMBER)
        IS
            SELECT ATTRIBUTE3
              FROM fnd_flex_values ffv, FND_FLEX_VALUE_SETS ffvs
             WHERE     ffv.flex_value_set_id = ffvs.flex_value_set_id
                   AND ffvs.FLEX_VALUE_SET_NAME = 'XXDO_IEX_LAST_PAYMENT_VS'
                   AND ffv.enabled_flag = 'Y'
                   AND p_days_from_last_payment BETWEEN ffv.attribute1
                                                    AND ffv.attribute2;
    BEGIN
        --      SELECT MAX (RECEIPT_DATE)
        --        INTO ln_last_receipt_date
        --        FROM ar_cash_receipts_all
        --       WHERE PAY_FROM_CUSTOMER = P_CUST_ACCOUNT_ID;
        gc_exception_flag   := 'N';

        OPEN get_party_c (P_CUST_ACCOUNT_ID);

        FETCH get_party_c INTO ln_party_id;

        CLOSE get_party_c;

        LOG (p_module        => 'GET_LAST_PAYMENT_SCORE',
             p_line_number   => NULL,
             p_log_message   => ' Start get_last_payment_score ');


        OPEN last_payment_date_c (ln_party_id);

        FETCH last_payment_date_c INTO ln_last_receipt_date;

        IF last_payment_date_c%NOTFOUND
        THEN
            LOG (
                p_module        => 'GET_LAST_PAYMENT_SCORE',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_last_payment_score  Last receipt Date is not found  Setting score to 0');


            ln_last_receipt_date   := NULL;
            ln_score               := 0;
            RETURN ln_score;
        END IF;

        CLOSE last_payment_date_c;

        LOG (
            p_module        => 'GET_LAST_PAYMENT_SCORE',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_last_payment_score  Last receipt Date at Customer Level : '
                || ln_last_receipt_date);



        IF ln_last_receipt_date IS NOT NULL
        THEN
            SELECT TRUNC (SYSDATE) - TRUNC (ln_last_receipt_date)
              INTO ln_days_from_last_payment
              FROM DUAL;

            OPEN payemnt_score_c (ln_days_from_last_payment);

            FETCH payemnt_score_c INTO ln_score;

            IF payemnt_score_c%NOTFOUND
            THEN
                LOG (
                    p_module        => 'GET_LAST_PAYMENT_SCORE',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' get_last_payment_score  score is not found  Setting score to 0');


                ln_score   := 0;
                RETURN ln_score;
            END IF;

            CLOSE payemnt_score_c;
        ELSE
            ln_score   := 0;
        END IF;

        LOG (p_module        => 'GET_LAST_PAYMENT_SCORE',
             p_line_number   => NULL,
             p_log_message   => ' End get_last_payment_score ');



        RETURN ln_score;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            gc_exception_flag   := 'Y';

            LOG (p_module        => SQLERRM,
                 p_line_number   => DBMS_UTILITY.format_error_backtrace,
                 p_log_message   => 'Error in get_last_payment_score');

            ln_score            := 0;
            RETURN ln_score;
    END get_last_payment_score;

    /*******************************************************************************
    * Funtion Name : get_amount_due
    * Description  : This Function will return amount due remaining for dive amount dues day
    *                for a given cust_account_id
    * Parameters   :P_CUST_ACCOUNT_ID
    *              From_days
    *             To_days
    * --------------------------------------------------------------------------- */

    FUNCTION get_amount_due (P_CUST_ACCOUNT_ID IN NUMBER, From_days IN NUMBER, to_days IN NUMBER)
        RETURN NUMBER
    IS
        ln_amount   NUMBER := 0;

        CURSOR total_amount_due_c (P_CUST_ACCOUNT_ID NUMBER)
        IS
            SELECT NVL (SUM (AMOUNT_DUE_REMAINING), 0)
              FROM ra_customer_trx_all rcta, hz_cust_accounts hca, ar_payment_schedules_all apsa
             --iex_delinquencies_all ida
             WHERE     hca.cust_account_id = rcta.bill_to_customer_id
                   AND rcta.bill_to_customer_id = p_cust_account_id
                   AND apsa.customer_trx_id = rcta.customer_trx_id
                   AND apsa.status = 'OP'
                   --AND ida.payment_schedule_id = apsa.payment_schedule_id
                   --AND ida.org_id = gn_org_id
                   AND apsa.org_id = gn_org_id;

        CURSOR current_amount_due_c (P_CUST_ACCOUNT_ID NUMBER)
        IS
            SELECT NVL (SUM (AMOUNT_DUE_REMAINING), 0)
              FROM ra_customer_trx_all rcta, hz_cust_accounts hCA, AR_PAYMENT_SCHEDULES_all apsa
             --IEX_DELINQUENCIES_ALL ida
             WHERE     hca.cust_account_id = rcta.BILL_TO_CUSTOMER_ID
                   AND rcta.bill_to_customer_id = P_CUST_ACCOUNT_ID
                   AND   TRUNC (SYSDATE)
                       - TRUNC (NVL (term_due_date, due_date)) <=
                       0
                   AND apsa.customer_trx_id = rcta.customer_trx_id
                   AND apsa.status = 'OP'
                   --AND ida.payment_schedule_id = apsa.payment_schedule_id
                   --AND ida.org_id = gn_org_id
                   AND apsa.org_id = gn_org_id;

        CURSOR days_amount_due_c (P_CUST_ACCOUNT_ID NUMBER, P_From_days NUMBER, p_to_days NUMBER)
        IS
            SELECT NVL (SUM (AMOUNT_DUE_REMAINING), 0)
              FROM ra_customer_trx_all rcta, hz_cust_accounts hCA, AR_PAYMENT_SCHEDULES_all apsa
             -- IEX_DELINQUENCIES_ALL ida
             WHERE     hca.cust_account_id = rcta.BILL_TO_CUSTOMER_ID
                   AND rcta.bill_to_customer_id = P_CUST_ACCOUNT_ID
                   AND   TRUNC (SYSDATE)
                       - TRUNC (NVL (term_due_date, due_date)) BETWEEN P_From_days
                                                                   AND p_to_days
                   AND apsa.customer_trx_id(+) = rcta.customer_trx_id
                   AND apsa.status = 'OP'
                   -- AND ida.payment_schedule_id = apsa.payment_schedule_id
                   -- AND ida.org_id = gn_org_id
                   AND apsa.org_id = gn_org_id;
    BEGIN
        gc_exception_flag   := 'N';
        LOG (p_module        => 'GET_AMOUNT_DUE',
             p_line_number   => NULL,
             p_log_message   => ' Start get_amount_due ');

        LOG (
            p_module        => 'GET_AMOUNT_DUE',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_amount_due From_days : '
                || From_days
                || ' to_days : '
                || to_days);



        IF From_days IS NULL AND to_days IS NULL
        THEN
            OPEN total_amount_due_c (P_CUST_ACCOUNT_ID);

            FETCH total_amount_due_c INTO ln_amount;

            IF total_amount_due_c%NOTFOUND
            THEN
                LOG (
                    p_module        => 'GET_AMOUNT_DUE',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' get_amount_due Total amount due is not found so setting ln_amount to 0');

                ln_amount   := 0;
            END IF;

            CLOSE total_amount_due_c;
        --AND apsa.class = 'INV';
        ELSIF from_days = 0 AND to_days = 0
        THEN
            OPEN current_amount_due_c (P_CUST_ACCOUNT_ID);

            FETCH current_amount_due_c INTO ln_amount;

            IF current_amount_due_c%NOTFOUND
            THEN
                LOG (
                    p_module        => 'GET_AMOUNT_DUE',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' get_amount_due  amount due for current invoice is not found so setting ln_amount to 0');

                ln_amount   := 0;
            END IF;

            CLOSE current_amount_due_c;
        ELSE
            OPEN days_amount_due_c (P_CUST_ACCOUNT_ID, From_days, to_days);

            FETCH days_amount_due_c INTO ln_amount;

            IF days_amount_due_c%NOTFOUND
            THEN
                LOG (
                    p_module        => 'GET_AMOUNT_DUE',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' get_amount_due  amount due for given days is not found so setting ln_amount to 0');

                ln_amount   := 0;
            END IF;

            CLOSE days_amount_due_c;
        --AND apsa.class = 'INV';
        END IF;

        LOG (p_module        => 'GET_AMOUNT_DUE',
             p_line_number   => NULL,
             p_log_message   => ' get_amount_due Amount Due : ' || ln_amount);


        LOG (p_module        => 'GET_AMOUNT_DUE',
             p_line_number   => NULL,
             p_log_message   => ' End get_amount_due ');



        RETURN ln_amount;
    /*EXCEPTION
         when no_data_found then

          gc_exception_flag := 'Y';
      log (
          p_module =>       SQLERRM,
          p_line_number => DBMS_UTILITY.format_error_backtrace,
          p_log_message=>  'error  in get_amount_due');

          ln_amount := 0;
          RETURN ln_amount;*/
    END get_amount_due;

    /*******************************************************************************
    * Funtion Name : get_aging_bucket_avg_score_us
    * Description  : This Function will generate and return  aging bucket score
    *                for a given cust_account_id
    * Parameters   :P_CUST_ACCOUNT_ID
    * --------------------------------------------------------------------------- */


    FUNCTION get_aging_bucket_avg_score_us (P_CUST_ACCOUNT_ID IN NUMBER)
        RETURN NUMBER
    IS
        ln_total_amount_due     NUMBER := 0;

        --P_CUST_ACCOUNT_ID              NUMBER := 1047;

        CURSOR aging_bucket_c IS
              SELECT FFV.attribute6 score, FFV.ATTRIBUTE1 days_from, FFV.attribute2 days_to,
                     ffv.attribute3 ar_avg_from, ffv.attribute4 ar_avg_to, ffv.attribute5 bucket,
                     ffv.attribute6 seq
                FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
               WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_US_VS'
                     AND FFVS.flex_value_set_id = FFV.flex_value_set_id
            ORDER BY FFV.flex_value + 0 ASC;

        CURSOR lowest_score_range_c (P_days_from NUMBER, P_days_to NUMBER)
        IS
            SELECT MIN (ffv.attribute3 + 0)
              FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
             WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_US_VS'
                   AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                   AND FFV.ATTRIBUTE1 = P_days_from
                   AND FFV.attribute2 = P_days_to;


        TYPE l_aging_info_type IS TABLE OF aging_bucket_c%ROWTYPE;

        l_aging_tbl             l_aging_info_type;
        ln_amount_due           NUMBER;
        ln_days_from            NUMBER;
        ln_days_to              NUMBER;
        ln_avg_from             NUMBER;
        ln_avg_to               NUMBER;
        ln_percentage           NUMBER;
        ln_score                NUMBER;
        lc_aging_bucket         VARCHAR2 (20);
        ln_lowest_Score_range   NUMBER;
        ln_prev_days_from       NUMBER;
        ln_prev_days_to         NUMBER;
    BEGIN
        gc_exception_flag     := 'N';
        LOG (p_module        => 'get_aging_bucket_avg_score_us',
             p_line_number   => NULL,
             p_log_message   => ' Start get_aging_bucket_avg_score_us ');



        ln_total_amount_due   := 0;
        ln_percentage         := 0;
        ln_score              := 0;
        ln_amount_due         := 0;
        ln_days_from          := 0;
        ln_days_to            := 0;
        ln_avg_from           := 0;
        ln_avg_to             := 0;
        lc_aging_bucket       := NULL;
        ln_prev_days_from     := 0;
        ln_prev_days_to       := 0;



        ln_total_amount_due   :=
            XXDO_IEX_SCORING_PKG.get_amount_due (P_CUST_ACCOUNT_ID,
                                                 NULL,
                                                 NULL);

        LOG (
            p_module        => 'GET_SCORE',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_us Total amount due : '
                || ln_total_amount_due);

        FND_LOG.STRING (
            LOG_LEVEL   => FND_LOG.LEVEL_STATEMENT,
            MODULE      => gc_module,
            MESSAGE     => 'TOTAL_AMOUNT_DUE : ' || ln_total_amount_due);

        SELECT FFV.attribute5
          INTO gc_default_aging_bucket
          FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
         WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_US_VS'
               AND FFVS.flex_value_set_id = FFV.flex_value_set_id
               AND FFV.ATTRIBUTE3 = 0
               AND FFV.ATTRIBUTE4 = 0
               AND FFV.ATTRIBUTE1 = 0
               AND FFV.ATTRIBUTE2 = 0;

        LOG (
            p_module        => 'GET_SCORE',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_us Fetched Defaulet  Bucket : '
                || gc_default_aging_bucket);

        -- Added below for defect# 3341 by BT Tech Team on 08-Oct-2015
        IF ln_total_amount_due <= 0
        THEN
            --ln_score := 50;

            SELECT MAX (FFV.ATTRIBUTE6 + 0), 'CURRENT'
              INTO ln_score, lc_aging_bucket
              FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
             WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_US_VS'
                   AND FFVS.flex_value_set_id = FFV.flex_value_set_id;

            v_aging_bucket   := lc_aging_bucket;

            -- gc_default_aging_bucket := lc_aging_bucket;

            -- Added above for defect# 3341 by BT Tech Team on 08-Oct-2015
            LOG (
                p_module        => 'GET_SCORE',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_aging_bucket_avg_score_us Fetched Defaulet Score and Bucket');
        ELSE
            OPEN aging_bucket_c;

            FETCH aging_bucket_c BULK COLLECT INTO l_aging_tbl;


            FOR ln_loop IN 1 .. l_aging_tbl.COUNT
            LOOP
                --ln_amount_due := 0;
                ln_days_from      := 0;
                ln_days_to        := 0;
                ln_avg_from       := 0;
                ln_avg_to         := 0;
                ln_percentage     := 0;
                ln_score          := 0;
                lc_aging_bucket   := NULL;

                ln_days_from      := l_aging_tbl (ln_loop).days_from;
                ln_days_to        := l_aging_tbl (ln_loop).days_to;
                ln_avg_from       := l_aging_tbl (ln_loop).ar_avg_from;
                ln_avg_to         := l_aging_tbl (ln_loop).ar_avg_to;
                ln_score          := l_aging_tbl (ln_loop).score;
                lc_aging_bucket   := l_aging_tbl (ln_loop).bucket;

                --            IF    ln_days_from <> ln_prev_days_from
                --               OR ln_days_to <> ln_prev_days_to
                --            THEN
                IF     ln_prev_days_from <> ln_days_from
                   AND ln_prev_days_to <> ln_days_to
                THEN
                    ln_amount_due       :=
                        XXDO_IEX_SCORING_PKG.get_amount_due (
                            P_CUST_ACCOUNT_ID,
                            ln_days_from,
                            ln_days_to);



                    ln_prev_days_from   := ln_days_from;
                    ln_prev_days_to     := ln_days_to;


                    LOG (
                        p_module        => 'get_aging_bucket_avg_score_us',
                        p_line_number   => NULL,
                        p_log_message   =>
                               ' get_aging_bucket_avg_score_us  amount due : '
                            || ln_amount_due);


                    OPEN lowest_score_range_c (ln_days_from, ln_days_to);

                    FETCH lowest_score_range_c INTO ln_lowest_Score_range;

                    CLOSE lowest_score_range_c;

                    LOG (
                        p_module        => 'get_aging_bucket_avg_score_us',
                        p_line_number   => NULL,
                        p_log_message   =>
                               ' get_aging_bucket_avg_score_us  ln_lowest_Score_range: '
                            || ln_lowest_Score_range);
                END IF;

                --            END IF;

                IF     ln_amount_due != 0
                   AND -- Commented below on 23/Sep/2015  for defect# 3150
                       -- ROUND ( (ln_amount_due / ln_total_amount_due), 2) * 100 >=
                       -- Added below on 23/Sep/2015  for defect# 3150
                       ROUND ((ln_amount_due / ln_total_amount_due) * 100, 2) >=
                       ln_lowest_Score_range
                THEN
                    -- Commented below on 23/Sep/2015  for defect# 3150
                    --ln_percentage := ROUND ( (ln_amount_due / ln_total_amount_due), 2) * 100;
                    -- Added below on 23/Sep/2015  for defect# 3150
                    ln_percentage    :=
                        ROUND ((ln_amount_due / ln_total_amount_due) * 100,
                               2);

                    IF ln_percentage > 100
                    THEN
                        ln_percentage   := 100;
                    END IF;

                    v_aging_bucket   := lc_aging_bucket;


                    EXIT WHEN     ln_percentage >= ln_avg_from
                              AND ln_percentage <= ln_avg_to;
                END IF;
            END LOOP;

            CLOSE aging_bucket_c;
        END IF;

        LOG (
            p_module        => 'get_aging_bucket_avg_score_us',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_us AR Percentage : '
                || ln_percentage);

        LOG (
            p_module        => 'get_aging_bucket_avg_score_us',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_us Aging Bucket Score : '
                || ln_score);



        LOG (
            p_module        => 'get_aging_bucket_avg_score_us',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_us Aging Bucket : '
                || lc_aging_bucket);


        LOG (p_module        => 'get_aging_bucket_avg_score_us',
             p_line_number   => NULL,
             p_log_message   => ' End get_aging_bucket_avg_score_us ');



        RETURN ln_score;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            gc_exception_flag   := 'Y';

            LOG (p_module        => SQLERRM,
                 p_line_number   => DBMS_UTILITY.format_error_backtrace,
                 p_log_message   => 'Error in get_aging_bucket_avg_score_us');

            -- Added below for defect# 3341 by BT Tech Team on 08-Oct-2015
            SELECT FFV.ATTRIBUTE6, FFV.ATTRIBUTE5
              INTO ln_score, lc_aging_bucket
              FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
             WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_US_VS'
                   AND FFVS.flex_value_set_id = FFV.flex_value_set_id
                   AND ffv.attribute5 = 'DEFAULT';

            -- ln_score := 15;
            -- Added above for defect# 3341 by BT Tech Team on 08-Oct-2015
            RETURN ln_score;
    END get_aging_bucket_avg_score_us;

    /*******************************************************************************
    * Funtion Name : get_aging_bucket_avg_score_ca
    * Description  : This Function will generate and return  aging bucket score
    *                for a given cust_account_id. Included as part of Canada 3PL Project
    * Parameters   :P_CUST_ACCOUNT_ID
    * --------------------------------------------------------------------------- */


    FUNCTION get_aging_bucket_avg_score_ca (P_CUST_ACCOUNT_ID IN NUMBER)
        RETURN NUMBER
    IS
        ln_total_amount_due     NUMBER := 0;

        --P_CUST_ACCOUNT_ID              NUMBER := 1047;

        CURSOR aging_bucket_c IS
              SELECT FFV.attribute6 score, FFV.ATTRIBUTE1 days_from, FFV.attribute2 days_to,
                     ffv.attribute3 ar_avg_from, ffv.attribute4 ar_avg_to, ffv.attribute5 bucket,
                     ffv.attribute6 seq
                FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
               WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_CA_VS'
                     AND FFVS.flex_value_set_id = FFV.flex_value_set_id
            ORDER BY FFV.flex_value + 0 ASC;

        CURSOR lowest_score_range_c (P_days_from NUMBER, P_days_to NUMBER)
        IS
            SELECT MIN (ffv.attribute3 + 0)
              FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
             WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_CA_VS'
                   AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                   AND FFV.ATTRIBUTE1 = P_days_from
                   AND FFV.attribute2 = P_days_to;


        TYPE l_aging_info_type IS TABLE OF aging_bucket_c%ROWTYPE;

        l_aging_tbl             l_aging_info_type;
        ln_amount_due           NUMBER;
        ln_days_from            NUMBER;
        ln_days_to              NUMBER;
        ln_avg_from             NUMBER;
        ln_avg_to               NUMBER;
        ln_percentage           NUMBER;
        ln_score                NUMBER;
        lc_aging_bucket         VARCHAR2 (20);
        ln_lowest_Score_range   NUMBER;
        ln_prev_days_from       NUMBER;
        ln_prev_days_to         NUMBER;
    BEGIN
        gc_exception_flag     := 'N';
        LOG (p_module        => 'get_aging_bucket_avg_score_ca',
             p_line_number   => NULL,
             p_log_message   => ' Start get_aging_bucket_avg_score_ca ');



        ln_total_amount_due   := 0;
        ln_percentage         := 0;
        ln_score              := 0;
        ln_amount_due         := 0;
        ln_days_from          := 0;
        ln_days_to            := 0;
        ln_avg_from           := 0;
        ln_avg_to             := 0;
        lc_aging_bucket       := NULL;
        ln_prev_days_from     := 0;
        ln_prev_days_to       := 0;



        ln_total_amount_due   :=
            XXDO_IEX_SCORING_PKG.get_amount_due (P_CUST_ACCOUNT_ID,
                                                 NULL,
                                                 NULL);

        LOG (
            p_module        => 'GET_SCORE',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_ca Total amount due : '
                || ln_total_amount_due);

        FND_LOG.STRING (
            LOG_LEVEL   => FND_LOG.LEVEL_STATEMENT,
            MODULE      => gc_module,
            MESSAGE     => 'TOTAL_AMOUNT_DUE : ' || ln_total_amount_due);

        SELECT FFV.attribute5
          INTO gc_default_aging_bucket
          FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
         WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_CA_VS'
               AND FFVS.flex_value_set_id = FFV.flex_value_set_id
               AND FFV.ATTRIBUTE3 = 0
               AND FFV.ATTRIBUTE4 = 0
               AND FFV.ATTRIBUTE1 = 0
               AND FFV.ATTRIBUTE2 = 0;

        LOG (
            p_module        => 'GET_SCORE',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_ca Fetched Defaulet  Bucket : '
                || gc_default_aging_bucket);

        -- Added below for defect# 3341 by BT Tech Team on 08-Oct-2015
        IF ln_total_amount_due <= 0
        THEN
            --ln_score := 50;

            SELECT MAX (FFV.ATTRIBUTE6 + 0), 'CURRENT'
              INTO ln_score, lc_aging_bucket
              FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
             WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_CA_VS'
                   AND FFVS.flex_value_set_id = FFV.flex_value_set_id;

            v_aging_bucket   := lc_aging_bucket;

            -- gc_default_aging_bucket := lc_aging_bucket;

            -- Added above for defect# 3341 by BT Tech Team on 08-Oct-2015
            LOG (
                p_module        => 'GET_SCORE',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_aging_bucket_avg_score_ca Fetched Defaulet Score and Bucket');
        ELSE
            OPEN aging_bucket_c;

            FETCH aging_bucket_c BULK COLLECT INTO l_aging_tbl;


            FOR ln_loop IN 1 .. l_aging_tbl.COUNT
            LOOP
                --ln_amount_due := 0;
                ln_days_from      := 0;
                ln_days_to        := 0;
                ln_avg_from       := 0;
                ln_avg_to         := 0;
                ln_percentage     := 0;
                ln_score          := 0;
                lc_aging_bucket   := NULL;

                ln_days_from      := l_aging_tbl (ln_loop).days_from;
                ln_days_to        := l_aging_tbl (ln_loop).days_to;
                ln_avg_from       := l_aging_tbl (ln_loop).ar_avg_from;
                ln_avg_to         := l_aging_tbl (ln_loop).ar_avg_to;
                ln_score          := l_aging_tbl (ln_loop).score;
                lc_aging_bucket   := l_aging_tbl (ln_loop).bucket;

                --            IF    ln_days_from <> ln_prev_days_from
                --               OR ln_days_to <> ln_prev_days_to
                --            THEN
                IF     ln_prev_days_from <> ln_days_from
                   AND ln_prev_days_to <> ln_days_to
                THEN
                    ln_amount_due       :=
                        XXDO_IEX_SCORING_PKG.get_amount_due (
                            P_CUST_ACCOUNT_ID,
                            ln_days_from,
                            ln_days_to);



                    ln_prev_days_from   := ln_days_from;
                    ln_prev_days_to     := ln_days_to;


                    LOG (
                        p_module        => 'get_aging_bucket_avg_score_ca',
                        p_line_number   => NULL,
                        p_log_message   =>
                               ' get_aging_bucket_avg_score_ca  amount due : '
                            || ln_amount_due);


                    OPEN lowest_score_range_c (ln_days_from, ln_days_to);

                    FETCH lowest_score_range_c INTO ln_lowest_Score_range;

                    CLOSE lowest_score_range_c;

                    LOG (
                        p_module        => 'get_aging_bucket_avg_score_ca',
                        p_line_number   => NULL,
                        p_log_message   =>
                               ' get_aging_bucket_avg_score_ca  ln_lowest_Score_range: '
                            || ln_lowest_Score_range);
                END IF;

                --            END IF;

                IF     ln_amount_due != 0
                   AND -- Commented below on 23/Sep/2015  for defect# 3150
                       -- ROUND ( (ln_amount_due / ln_total_amount_due), 2) * 100 >=
                       -- Added below on 23/Sep/2015  for defect# 3150
                       ROUND ((ln_amount_due / ln_total_amount_due) * 100, 2) >=
                       ln_lowest_Score_range
                THEN
                    -- Commented below on 23/Sep/2015  for defect# 3150
                    --ln_percentage := ROUND ( (ln_amount_due / ln_total_amount_due), 2) * 100;
                    -- Added below on 23/Sep/2015  for defect# 3150
                    ln_percentage    :=
                        ROUND ((ln_amount_due / ln_total_amount_due) * 100,
                               2);

                    IF ln_percentage > 100
                    THEN
                        ln_percentage   := 100;
                    END IF;

                    v_aging_bucket   := lc_aging_bucket;


                    EXIT WHEN     ln_percentage >= ln_avg_from
                              AND ln_percentage <= ln_avg_to;
                END IF;
            END LOOP;

            CLOSE aging_bucket_c;
        END IF;

        LOG (
            p_module        => 'get_aging_bucket_avg_score_ca',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_ca AR Percentage : '
                || ln_percentage);

        LOG (
            p_module        => 'get_aging_bucket_avg_score_ca',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_ca Aging Bucket Score : '
                || ln_score);



        LOG (
            p_module        => 'get_aging_bucket_avg_score_ca',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_ca Aging Bucket : '
                || lc_aging_bucket);


        LOG (p_module        => 'get_aging_bucket_avg_score_ca',
             p_line_number   => NULL,
             p_log_message   => ' End get_aging_bucket_avg_score_ca ');



        RETURN ln_score;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            gc_exception_flag   := 'Y';

            LOG (p_module        => SQLERRM,
                 p_line_number   => DBMS_UTILITY.format_error_backtrace,
                 p_log_message   => 'Error in get_aging_bucket_avg_score_ca');

            -- Added below for defect# 3341 by BT Tech Team on 08-Oct-2015
            SELECT FFV.ATTRIBUTE6, FFV.ATTRIBUTE5
              INTO ln_score, lc_aging_bucket
              FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
             WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_CA_VS'
                   AND FFVS.flex_value_set_id = FFV.flex_value_set_id
                   AND ffv.attribute5 = 'DEFAULT';

            -- ln_score := 15;
            -- Added above for defect# 3341 by BT Tech Team on 08-Oct-2015
            RETURN ln_score;
    END get_aging_bucket_avg_score_ca;

    /*******************************************************************************
    * Funtion Name : get_aging_bucket_avg_score_uk
    * Description  : This Function will generate and return  aging bucket score
    *                for a given cust_account_id
    * Parameters   :P_CUST_ACCOUNT_ID
    * --------------------------------------------------------------------------- */


    FUNCTION get_aging_bucket_avg_score_uk (P_CUST_ACCOUNT_ID IN NUMBER)
        RETURN NUMBER
    IS
        ln_total_amount_due     NUMBER := 0;

        --P_CUST_ACCOUNT_ID              NUMBER := 1047;

        CURSOR aging_bucket_c IS
              SELECT FFV.attribute6 score, FFV.ATTRIBUTE1 days_from, FFV.attribute2 days_to,
                     ffv.attribute3 ar_avg_from, ffv.attribute4 ar_avg_to, ffv.attribute5 bucket,
                     ffv.attribute6 seq
                FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
               WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_UK_VS'
                     AND FFVS.flex_value_set_id = FFV.flex_value_set_id
            ORDER BY FFV.flex_value + 0 ASC;

        CURSOR lowest_score_range_c (P_days_from NUMBER, P_days_to NUMBER)
        IS
            SELECT MIN (ffv.attribute3 + 0)
              FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
             WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_UK_VS'
                   AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                   AND FFV.ATTRIBUTE1 = P_days_from
                   AND FFV.attribute2 = P_days_to;


        TYPE l_aging_info_type IS TABLE OF aging_bucket_c%ROWTYPE;

        l_aging_tbl             l_aging_info_type;
        ln_amount_due           NUMBER;
        ln_days_from            NUMBER;
        ln_days_to              NUMBER;
        ln_avg_from             NUMBER;
        ln_avg_to               NUMBER;
        ln_percentage           NUMBER;
        ln_score                NUMBER;
        lc_aging_bucket         VARCHAR2 (20);
        ln_lowest_Score_range   NUMBER;
        ln_prev_days_from       NUMBER;
        ln_prev_days_to         NUMBER;
    BEGIN
        gc_exception_flag     := 'N';
        LOG (p_module        => 'get_aging_bucket_avg_score_uk',
             p_line_number   => NULL,
             p_log_message   => ' Start get_aging_bucket_avg_score_uk ');



        ln_total_amount_due   := 0;
        ln_percentage         := 0;
        ln_score              := 0;
        ln_amount_due         := 0;
        ln_days_from          := 0;
        ln_days_to            := 0;
        ln_avg_from           := 0;
        ln_avg_to             := 0;
        lc_aging_bucket       := NULL;
        ln_prev_days_from     := 0;
        ln_prev_days_to       := 0;



        ln_total_amount_due   :=
            XXDO_IEX_SCORING_PKG.get_amount_due (P_CUST_ACCOUNT_ID,
                                                 NULL,
                                                 NULL);

        LOG (
            p_module        => 'GET_SCORE',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_uk Total amount due : '
                || ln_total_amount_due);

        FND_LOG.STRING (
            LOG_LEVEL   => FND_LOG.LEVEL_STATEMENT,
            MODULE      => gc_module,
            MESSAGE     => 'TOTAL_AMOUNT_DUE : ' || ln_total_amount_due);

        SELECT FFV.attribute5
          INTO gc_default_aging_bucket
          FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
         WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_UK_VS'
               AND FFVS.flex_value_set_id = FFV.flex_value_set_id
               AND FFV.ATTRIBUTE3 = 0
               AND FFV.ATTRIBUTE4 = 0
               AND FFV.ATTRIBUTE1 = 0
               AND FFV.ATTRIBUTE2 = 0;

        LOG (
            p_module        => 'GET_SCORE',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_uk Fetched Defaulet  Bucket : '
                || gc_default_aging_bucket);

        -- Added below for defect# 3341 by BT Tech Team on 08-Oct-2015
        IF ln_total_amount_due <= 0
        THEN
            --ln_score := 50;

            SELECT MAX (FFV.ATTRIBUTE6 + 0), 'CURRENT'
              INTO ln_score, lc_aging_bucket
              FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
             WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_US_VS'
                   AND FFVS.flex_value_set_id = FFV.flex_value_set_id;

            v_aging_bucket   := lc_aging_bucket;

            -- gc_default_aging_bucket := lc_aging_bucket;
            -- Added above for defect# 3341 by BT Tech Team on 08-Oct-2015
            LOG (
                p_module        => 'GET_SCORE',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_aging_bucket_avg_score_uk Fetched Defaulet Score and Bucket');
        ELSE
            OPEN aging_bucket_c;

            FETCH aging_bucket_c BULK COLLECT INTO l_aging_tbl;


            FOR ln_loop IN 1 .. l_aging_tbl.COUNT
            LOOP
                --ln_amount_due := 0;
                ln_days_from      := 0;
                ln_days_to        := 0;
                ln_avg_from       := 0;
                ln_avg_to         := 0;
                ln_percentage     := 0;
                ln_score          := 0;
                lc_aging_bucket   := NULL;

                ln_days_from      := l_aging_tbl (ln_loop).days_from;
                ln_days_to        := l_aging_tbl (ln_loop).days_to;
                ln_avg_from       := l_aging_tbl (ln_loop).ar_avg_from;
                ln_avg_to         := l_aging_tbl (ln_loop).ar_avg_to;
                ln_score          := l_aging_tbl (ln_loop).score;
                lc_aging_bucket   := l_aging_tbl (ln_loop).bucket;

                --            IF    ln_days_from <> ln_prev_days_from
                --               OR ln_days_to <> ln_prev_days_to
                --            THEN
                IF     ln_prev_days_from <> ln_days_from
                   AND ln_prev_days_to <> ln_days_to
                THEN
                    ln_amount_due       :=
                        XXDO_IEX_SCORING_PKG.get_amount_due (
                            P_CUST_ACCOUNT_ID,
                            ln_days_from,
                            ln_days_to);



                    ln_prev_days_from   := ln_days_from;
                    ln_prev_days_to     := ln_days_to;


                    LOG (
                        p_module        => 'get_aging_bucket_avg_score_uk',
                        p_line_number   => NULL,
                        p_log_message   =>
                               ' get_aging_bucket_avg_score_uk  amount due : '
                            || ln_amount_due);


                    OPEN lowest_score_range_c (ln_days_from, ln_days_to);

                    FETCH lowest_score_range_c INTO ln_lowest_Score_range;

                    CLOSE lowest_score_range_c;

                    LOG (
                        p_module        => 'get_aging_bucket_avg_score_uk',
                        p_line_number   => NULL,
                        p_log_message   =>
                               ' get_aging_bucket_avg_score_uk  ln_lowest_Score_range: '
                            || ln_lowest_Score_range);
                END IF;

                --            END IF;

                IF     ln_amount_due != 0
                   AND -- Commented below on 23/Sep/2015  for defect# 3150
                       -- ROUND ( (ln_amount_due / ln_total_amount_due), 2) * 100 >=
                       -- Added below on 23/Sep/2015  for defect# 3150
                       ROUND ((ln_amount_due / ln_total_amount_due) * 100, 2) >=
                       ln_lowest_Score_range
                THEN
                    -- Commented below on 23/Sep/2015  for defect# 3150
                    --ln_percentage := ROUND ( (ln_amount_due / ln_total_amount_due), 2) * 100;
                    -- Added below on 23/Sep/2015  for defect# 3150
                    ln_percentage    :=
                        ROUND ((ln_amount_due / ln_total_amount_due) * 100,
                               2);

                    IF ln_percentage > 100
                    THEN
                        ln_percentage   := 100;
                    END IF;

                    v_aging_bucket   := lc_aging_bucket;


                    EXIT WHEN     ln_percentage >= ln_avg_from
                              AND ln_percentage <= ln_avg_to;
                END IF;
            END LOOP;

            CLOSE aging_bucket_c;
        END IF;

        LOG (
            p_module        => 'get_aging_bucket_avg_score_uk',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_uk AR Percentage : '
                || ln_percentage);

        LOG (
            p_module        => 'get_aging_bucket_avg_score_uk',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_uk Aging Bucket Score : '
                || ln_score);



        LOG (
            p_module        => 'get_aging_bucket_avg_score_uk',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_uk Aging Bucket : '
                || lc_aging_bucket);


        LOG (p_module        => 'get_aging_bucket_avg_score_uk',
             p_line_number   => NULL,
             p_log_message   => ' End get_aging_bucket_avg_score_uk ');



        RETURN ln_score;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            gc_exception_flag   := 'Y';

            LOG (p_module        => SQLERRM,
                 p_line_number   => DBMS_UTILITY.format_error_backtrace,
                 p_log_message   => 'Error in get_aging_bucket_avg_score_uk');

            -- Added below for defect# 3341 by BT Tech Team on 08-Oct-2015
            SELECT FFV.ATTRIBUTE6, FFV.ATTRIBUTE5
              INTO ln_score, lc_aging_bucket
              FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
             WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_US_VS'
                   AND FFVS.flex_value_set_id = FFV.flex_value_set_id
                   AND ffv.attribute5 = 'DEFAULT';

            -- ln_score := 15;
            -- Added above for defect# 3341 by BT Tech Team on 08-Oct-2015
            RETURN ln_score;
    END get_aging_bucket_avg_score_uk;

    /*******************************************************************************
    * Funtion Name : get_aging_bucket_avg_score_gr
    * Description  : This Function will generate and return  aging bucket score
    *                for a given cust_account_id
    * Parameters   :P_CUST_ACCOUNT_ID
    * --------------------------------------------------------------------------- */


    FUNCTION get_aging_bucket_avg_score_gr (P_CUST_ACCOUNT_ID IN NUMBER)
        RETURN NUMBER
    IS
        ln_total_amount_due     NUMBER := 0;

        --P_CUST_ACCOUNT_ID              NUMBER := 1047;

        CURSOR aging_bucket_c IS
              SELECT FFV.attribute6 score, FFV.ATTRIBUTE1 days_from, FFV.attribute2 days_to,
                     ffv.attribute3 ar_avg_from, ffv.attribute4 ar_avg_to, ffv.attribute5 bucket,
                     ffv.attribute6 seq
                FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
               WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_GR_VS'
                     AND FFVS.flex_value_set_id = FFV.flex_value_set_id
            ORDER BY FFV.flex_value + 0 ASC;

        CURSOR lowest_score_range_c (P_days_from NUMBER, P_days_to NUMBER)
        IS
            SELECT MIN (ffv.attribute3 + 0)
              FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
             WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_GR_VS'
                   AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                   AND FFV.ATTRIBUTE1 = P_days_from
                   AND FFV.attribute2 = P_days_to;


        TYPE l_aging_info_type IS TABLE OF aging_bucket_c%ROWTYPE;

        l_aging_tbl             l_aging_info_type;
        ln_amount_due           NUMBER;
        ln_days_from            NUMBER;
        ln_days_to              NUMBER;
        ln_avg_from             NUMBER;
        ln_avg_to               NUMBER;
        ln_percentage           NUMBER;
        ln_score                NUMBER;
        lc_aging_bucket         VARCHAR2 (20);
        ln_lowest_Score_range   NUMBER;
        ln_prev_days_from       NUMBER;
        ln_prev_days_to         NUMBER;
    BEGIN
        gc_exception_flag     := 'N';
        LOG (p_module        => 'get_aging_bucket_avg_score_gr',
             p_line_number   => NULL,
             p_log_message   => ' Start get_aging_bucket_avg_score_gr ');



        ln_total_amount_due   := 0;
        ln_percentage         := 0;
        ln_score              := 0;
        ln_amount_due         := 0;
        ln_days_from          := 0;
        ln_days_to            := 0;
        ln_avg_from           := 0;
        ln_avg_to             := 0;
        lc_aging_bucket       := NULL;
        ln_prev_days_from     := 0;
        ln_prev_days_to       := 0;



        ln_total_amount_due   :=
            XXDO_IEX_SCORING_PKG.get_amount_due (P_CUST_ACCOUNT_ID,
                                                 NULL,
                                                 NULL);

        LOG (
            p_module        => 'GET_SCORE',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_gr Total amount due : '
                || ln_total_amount_due);

        FND_LOG.STRING (
            LOG_LEVEL   => FND_LOG.LEVEL_STATEMENT,
            MODULE      => gc_module,
            MESSAGE     => 'TOTAL_AMOUNT_DUE : ' || ln_total_amount_due);

        SELECT FFV.attribute5
          INTO gc_default_aging_bucket
          FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
         WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_GR_VS'
               AND FFVS.flex_value_set_id = FFV.flex_value_set_id
               AND FFV.ATTRIBUTE3 = 0
               AND FFV.ATTRIBUTE4 = 0
               AND FFV.ATTRIBUTE1 = 0
               AND FFV.ATTRIBUTE2 = 0;

        LOG (
            p_module        => 'GET_SCORE',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_gr Fetched Defaulet  Bucket : '
                || gc_default_aging_bucket);

        -- Added below for defect# 3341 by BT Tech Team on 08-Oct-2015
        IF ln_total_amount_due <= 0
        THEN
            --ln_score := 50;

            SELECT MAX (FFV.ATTRIBUTE6 + 0), 'CURRENT'
              INTO ln_score, lc_aging_bucket
              FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
             WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_US_VS'
                   AND FFVS.flex_value_set_id = FFV.flex_value_set_id;

            v_aging_bucket   := lc_aging_bucket;
            -- gc_default_aging_bucket := lc_aging_bucket;
            -- Added above for defect# 3341 by BT Tech Team on 08-Oct-2015
            LOG (
                p_module        => 'GET_SCORE',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_aging_bucket_avg_score_gr Fetched Defaulet Score and Bucket');
        ELSE
            OPEN aging_bucket_c;

            FETCH aging_bucket_c BULK COLLECT INTO l_aging_tbl;


            FOR ln_loop IN 1 .. l_aging_tbl.COUNT
            LOOP
                --ln_amount_due := 0;
                ln_days_from      := 0;
                ln_days_to        := 0;
                ln_avg_from       := 0;
                ln_avg_to         := 0;
                ln_percentage     := 0;
                ln_score          := 0;
                lc_aging_bucket   := NULL;

                ln_days_from      := l_aging_tbl (ln_loop).days_from;
                ln_days_to        := l_aging_tbl (ln_loop).days_to;
                ln_avg_from       := l_aging_tbl (ln_loop).ar_avg_from;
                ln_avg_to         := l_aging_tbl (ln_loop).ar_avg_to;
                ln_score          := l_aging_tbl (ln_loop).score;
                lc_aging_bucket   := l_aging_tbl (ln_loop).bucket;

                --            IF    ln_days_from <> ln_prev_days_from
                --               OR ln_days_to <> ln_prev_days_to
                --            THEN
                IF     ln_prev_days_from <> ln_days_from
                   AND ln_prev_days_to <> ln_days_to
                THEN
                    ln_amount_due       :=
                        XXDO_IEX_SCORING_PKG.get_amount_due (
                            P_CUST_ACCOUNT_ID,
                            ln_days_from,
                            ln_days_to);



                    ln_prev_days_from   := ln_days_from;
                    ln_prev_days_to     := ln_days_to;


                    LOG (
                        p_module        => 'get_aging_bucket_avg_score_gr',
                        p_line_number   => NULL,
                        p_log_message   =>
                               ' get_aging_bucket_avg_score_gr  amount due : '
                            || ln_amount_due);


                    OPEN lowest_score_range_c (ln_days_from, ln_days_to);

                    FETCH lowest_score_range_c INTO ln_lowest_Score_range;

                    CLOSE lowest_score_range_c;

                    LOG (
                        p_module        => 'get_aging_bucket_avg_score_gr',
                        p_line_number   => NULL,
                        p_log_message   =>
                               ' get_aging_bucket_avg_score_gr  ln_lowest_Score_range: '
                            || ln_lowest_Score_range);
                END IF;

                --            END IF;

                IF     ln_amount_due != 0
                   AND -- Commented below on 23/Sep/2015  for defect# 3150
                       -- ROUND ( (ln_amount_due / ln_total_amount_due), 2) * 100 >=
                       -- Added below on 23/Sep/2015  for defect# 3150
                       ROUND ((ln_amount_due / ln_total_amount_due) * 100, 2) >=
                       ln_lowest_Score_range
                THEN
                    -- Commented below on 23/Sep/2015  for defect# 3150
                    --ln_percentage := ROUND ( (ln_amount_due / ln_total_amount_due), 2) * 100;
                    -- Added below on 23/Sep/2015  for defect# 3150
                    ln_percentage    :=
                        ROUND ((ln_amount_due / ln_total_amount_due) * 100,
                               2);

                    IF ln_percentage > 100
                    THEN
                        ln_percentage   := 100;
                    END IF;

                    v_aging_bucket   := lc_aging_bucket;


                    EXIT WHEN     ln_percentage >= ln_avg_from
                              AND ln_percentage <= ln_avg_to;
                END IF;
            END LOOP;

            CLOSE aging_bucket_c;
        END IF;

        LOG (
            p_module        => 'get_aging_bucket_avg_score_gr',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_gr AR Percentage : '
                || ln_percentage);

        LOG (
            p_module        => 'get_aging_bucket_avg_score_gr',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_gr Aging Bucket Score : '
                || ln_score);



        LOG (
            p_module        => 'get_aging_bucket_avg_score_gr',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_gr Aging Bucket : '
                || lc_aging_bucket);


        LOG (p_module        => 'get_aging_bucket_avg_score_gr',
             p_line_number   => NULL,
             p_log_message   => ' End get_aging_bucket_avg_score_gr ');



        RETURN ln_score;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            gc_exception_flag   := 'Y';

            LOG (p_module        => SQLERRM,
                 p_line_number   => DBMS_UTILITY.format_error_backtrace,
                 p_log_message   => 'Error in get_aging_bucket_avg_score_gr');

            -- Added below for defect# 3341 by BT Tech Team on 08-Oct-2015
            SELECT FFV.ATTRIBUTE6, FFV.ATTRIBUTE5
              INTO ln_score, lc_aging_bucket
              FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
             WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_US_VS'
                   AND FFVS.flex_value_set_id = FFV.flex_value_set_id
                   AND ffv.attribute5 = 'DEFAULT';

            -- ln_score := 15;
            -- Added above for defect# 3341 by BT Tech Team on 08-Oct-2015
            RETURN ln_score;
    END get_aging_bucket_avg_score_gr;

    /*******************************************************************************
    * Funtion Name : get_aging_bucket_avg_score_bx
    * Description  : This Function will generate and return  aging bucket score
    *                for a given cust_account_id
    * Parameters   :P_CUST_ACCOUNT_ID
    * --------------------------------------------------------------------------- */


    FUNCTION get_aging_bucket_avg_score_bx (P_CUST_ACCOUNT_ID IN NUMBER)
        RETURN NUMBER
    IS
        ln_total_amount_due     NUMBER := 0;

        --P_CUST_ACCOUNT_ID              NUMBER := 1047;

        CURSOR aging_bucket_c IS
              SELECT FFV.attribute6 score, FFV.ATTRIBUTE1 days_from, FFV.attribute2 days_to,
                     ffv.attribute3 ar_avg_from, ffv.attribute4 ar_avg_to, ffv.attribute5 bucket,
                     ffv.attribute6 seq
                FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
               WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_BX_VS'
                     AND FFVS.flex_value_set_id = FFV.flex_value_set_id
            ORDER BY FFV.flex_value + 0 ASC;

        CURSOR lowest_score_range_c (P_days_from NUMBER, P_days_to NUMBER)
        IS
            SELECT MIN (ffv.attribute3 + 0)
              FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
             WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_BX_VS'
                   AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                   AND FFV.ATTRIBUTE1 = P_days_from
                   AND FFV.attribute2 = P_days_to;


        TYPE l_aging_info_type IS TABLE OF aging_bucket_c%ROWTYPE;

        l_aging_tbl             l_aging_info_type;
        ln_amount_due           NUMBER;
        ln_days_from            NUMBER;
        ln_days_to              NUMBER;
        ln_avg_from             NUMBER;
        ln_avg_to               NUMBER;
        ln_percentage           NUMBER;
        ln_score                NUMBER;
        lc_aging_bucket         VARCHAR2 (20);
        ln_lowest_Score_range   NUMBER;
        ln_prev_days_from       NUMBER;
        ln_prev_days_to         NUMBER;
    BEGIN
        gc_exception_flag     := 'N';
        LOG (p_module        => 'get_aging_bucket_avg_score_bx',
             p_line_number   => NULL,
             p_log_message   => ' Start get_aging_bucket_avg_score_bx ');



        ln_total_amount_due   := 0;
        ln_percentage         := 0;
        ln_score              := 0;
        ln_amount_due         := 0;
        ln_days_from          := 0;
        ln_days_to            := 0;
        ln_avg_from           := 0;
        ln_avg_to             := 0;
        lc_aging_bucket       := NULL;
        ln_prev_days_from     := 0;
        ln_prev_days_to       := 0;



        ln_total_amount_due   :=
            XXDO_IEX_SCORING_PKG.get_amount_due (P_CUST_ACCOUNT_ID,
                                                 NULL,
                                                 NULL);

        LOG (
            p_module        => 'GET_SCORE',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_bx Total amount due : '
                || ln_total_amount_due);

        FND_LOG.STRING (
            LOG_LEVEL   => FND_LOG.LEVEL_STATEMENT,
            MODULE      => gc_module,
            MESSAGE     => 'TOTAL_AMOUNT_DUE : ' || ln_total_amount_due);

        SELECT FFV.attribute5
          INTO gc_default_aging_bucket
          FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
         WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_BX_VS'
               AND FFVS.flex_value_set_id = FFV.flex_value_set_id
               AND FFV.ATTRIBUTE3 = 0
               AND FFV.ATTRIBUTE4 = 0
               AND FFV.ATTRIBUTE1 = 0
               AND FFV.ATTRIBUTE2 = 0;

        LOG (
            p_module        => 'GET_SCORE',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_bx Fetched Defaulet  Bucket : '
                || gc_default_aging_bucket);

        -- Added below for defect# 3341 by BT Tech Team on 08-Oct-2015
        IF ln_total_amount_due <= 0
        THEN
            --ln_score := 50;

            SELECT MAX (FFV.ATTRIBUTE6 + 0), 'CURRENT'
              INTO ln_score, lc_aging_bucket
              FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
             WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_US_VS'
                   AND FFVS.flex_value_set_id = FFV.flex_value_set_id;

            v_aging_bucket   := lc_aging_bucket;
            -- gc_default_aging_bucket := lc_aging_bucket;
            -- Added above for defect# 3341 by BT Tech Team on 08-Oct-2015
            LOG (
                p_module        => 'GET_SCORE',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_aging_bucket_avg_score_bx Fetched Defaulet Score and Bucket');
        ELSE
            OPEN aging_bucket_c;

            FETCH aging_bucket_c BULK COLLECT INTO l_aging_tbl;


            FOR ln_loop IN 1 .. l_aging_tbl.COUNT
            LOOP
                --ln_amount_due := 0;
                ln_days_from      := 0;
                ln_days_to        := 0;
                ln_avg_from       := 0;
                ln_avg_to         := 0;
                ln_percentage     := 0;
                ln_score          := 0;
                lc_aging_bucket   := NULL;

                ln_days_from      := l_aging_tbl (ln_loop).days_from;
                ln_days_to        := l_aging_tbl (ln_loop).days_to;
                ln_avg_from       := l_aging_tbl (ln_loop).ar_avg_from;
                ln_avg_to         := l_aging_tbl (ln_loop).ar_avg_to;
                ln_score          := l_aging_tbl (ln_loop).score;
                lc_aging_bucket   := l_aging_tbl (ln_loop).bucket;

                --            IF    ln_days_from <> ln_prev_days_from
                --               OR ln_days_to <> ln_prev_days_to
                --            THEN
                IF     ln_prev_days_from <> ln_days_from
                   AND ln_prev_days_to <> ln_days_to
                THEN
                    ln_amount_due       :=
                        XXDO_IEX_SCORING_PKG.get_amount_due (
                            P_CUST_ACCOUNT_ID,
                            ln_days_from,
                            ln_days_to);



                    ln_prev_days_from   := ln_days_from;
                    ln_prev_days_to     := ln_days_to;


                    LOG (
                        p_module        => 'get_aging_bucket_avg_score_bx',
                        p_line_number   => NULL,
                        p_log_message   =>
                               ' get_aging_bucket_avg_score_bx  amount due : '
                            || ln_amount_due);


                    OPEN lowest_score_range_c (ln_days_from, ln_days_to);

                    FETCH lowest_score_range_c INTO ln_lowest_Score_range;

                    CLOSE lowest_score_range_c;

                    LOG (
                        p_module        => 'get_aging_bucket_avg_score_bx',
                        p_line_number   => NULL,
                        p_log_message   =>
                               ' get_aging_bucket_avg_score_bx  ln_lowest_Score_range: '
                            || ln_lowest_Score_range);
                END IF;

                --            END IF;

                IF     ln_amount_due != 0
                   AND -- Commented below on 23/Sep/2015  for defect# 3150
                       -- ROUND ( (ln_amount_due / ln_total_amount_due), 2) * 100 >=
                       -- Added below on 23/Sep/2015  for defect# 3150
                       ROUND ((ln_amount_due / ln_total_amount_due) * 100, 2) >=
                       ln_lowest_Score_range
                THEN
                    -- Commented below on 23/Sep/2015  for defect# 3150
                    --ln_percentage := ROUND ( (ln_amount_due / ln_total_amount_due), 2) * 100;
                    -- Added below on 23/Sep/2015  for defect# 3150
                    ln_percentage    :=
                        ROUND ((ln_amount_due / ln_total_amount_due) * 100,
                               2);

                    IF ln_percentage > 100
                    THEN
                        ln_percentage   := 100;
                    END IF;

                    v_aging_bucket   := lc_aging_bucket;


                    EXIT WHEN     ln_percentage >= ln_avg_from
                              AND ln_percentage <= ln_avg_to;
                END IF;
            END LOOP;

            CLOSE aging_bucket_c;
        END IF;

        LOG (
            p_module        => 'get_aging_bucket_avg_score_bx',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_bx AR Percentage : '
                || ln_percentage);

        LOG (
            p_module        => 'get_aging_bucket_avg_score_bx',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_bx Aging Bucket Score : '
                || ln_score);



        LOG (
            p_module        => 'get_aging_bucket_avg_score_bx',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_bx Aging Bucket : '
                || lc_aging_bucket);


        LOG (p_module        => 'get_aging_bucket_avg_score_bx',
             p_line_number   => NULL,
             p_log_message   => ' End get_aging_bucket_avg_score_bx ');



        RETURN ln_score;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            gc_exception_flag   := 'Y';

            LOG (p_module        => SQLERRM,
                 p_line_number   => DBMS_UTILITY.format_error_backtrace,
                 p_log_message   => 'Error in get_aging_bucket_avg_score_bx');

            -- Added below for defect# 3341 by BT Tech Team on 08-Oct-2015
            SELECT FFV.ATTRIBUTE6, FFV.ATTRIBUTE5
              INTO ln_score, lc_aging_bucket
              FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
             WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_US_VS'
                   AND FFVS.flex_value_set_id = FFV.flex_value_set_id
                   AND ffv.attribute5 = 'DEFAULT';

            -- ln_score := 15;
            -- Added above for defect# 3341 by BT Tech Team on 08-Oct-2015
            RETURN ln_score;
    END get_aging_bucket_avg_score_bx;

    -- Start of Changes for CCR0009857

    /*******************************************************************************
      * Funtion Name : get_aging_bucket_avg_score_it
      * Description  : This Function will generate and return  aging bucket score
      *                for a given cust_account_id
      * Parameters   :P_CUST_ACCOUNT_ID
      * --------------------------------------------------------------------------- */


    FUNCTION get_aging_bucket_avg_score_it (P_CUST_ACCOUNT_ID IN NUMBER)
        RETURN NUMBER
    IS
        ln_total_amount_due     NUMBER := 0;

        --P_CUST_ACCOUNT_ID              NUMBER := 1047;

        CURSOR aging_bucket_c IS
              SELECT FFV.attribute6 score, FFV.ATTRIBUTE1 days_from, FFV.attribute2 days_to,
                     ffv.attribute3 ar_avg_from, ffv.attribute4 ar_avg_to, ffv.attribute5 bucket,
                     ffv.attribute6 seq
                FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
               WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_IT_VS'
                     AND FFVS.flex_value_set_id = FFV.flex_value_set_id
            ORDER BY FFV.flex_value + 0 ASC;

        CURSOR lowest_score_range_c (P_days_from NUMBER, P_days_to NUMBER)
        IS
            SELECT MIN (ffv.attribute3 + 0)
              FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
             WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_IT_VS'
                   AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                   AND FFV.ATTRIBUTE1 = P_days_from
                   AND FFV.attribute2 = P_days_to;


        TYPE l_aging_info_type IS TABLE OF aging_bucket_c%ROWTYPE;

        l_aging_tbl             l_aging_info_type;
        ln_amount_due           NUMBER;
        ln_days_from            NUMBER;
        ln_days_to              NUMBER;
        ln_avg_from             NUMBER;
        ln_avg_to               NUMBER;
        ln_percentage           NUMBER;
        ln_score                NUMBER;
        lc_aging_bucket         VARCHAR2 (20);
        ln_lowest_Score_range   NUMBER;
        ln_prev_days_from       NUMBER;
        ln_prev_days_to         NUMBER;
    BEGIN
        gc_exception_flag     := 'N';
        LOG (p_module        => 'get_aging_bucket_avg_score_it',
             p_line_number   => NULL,
             p_log_message   => ' Start get_aging_bucket_avg_score_it ');



        ln_total_amount_due   := 0;
        ln_percentage         := 0;
        ln_score              := 0;
        ln_amount_due         := 0;
        ln_days_from          := 0;
        ln_days_to            := 0;
        ln_avg_from           := 0;
        ln_avg_to             := 0;
        lc_aging_bucket       := NULL;
        ln_prev_days_from     := 0;
        ln_prev_days_to       := 0;



        ln_total_amount_due   :=
            XXDO_IEX_SCORING_PKG.get_amount_due (P_CUST_ACCOUNT_ID,
                                                 NULL,
                                                 NULL);

        LOG (
            p_module        => 'GET_SCORE',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_it Total amount due : '
                || ln_total_amount_due);

        FND_LOG.STRING (
            LOG_LEVEL   => FND_LOG.LEVEL_STATEMENT,
            MODULE      => gc_module,
            MESSAGE     => 'TOTAL_AMOUNT_DUE : ' || ln_total_amount_due);

        SELECT FFV.attribute5
          INTO gc_default_aging_bucket
          FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
         WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_IT_VS'
               AND FFVS.flex_value_set_id = FFV.flex_value_set_id
               AND FFV.ATTRIBUTE3 = 0
               AND FFV.ATTRIBUTE4 = 0
               AND FFV.ATTRIBUTE1 = 0
               AND FFV.ATTRIBUTE2 = 0;

        LOG (
            p_module        => 'GET_SCORE',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_it Fetched Defaulet  Bucket : '
                || gc_default_aging_bucket);

        -- Added below for defect# 3341 by BT Tech Team on 08-Oct-2015
        IF ln_total_amount_due <= 0
        THEN
            --ln_score := 50;

            SELECT MAX (FFV.ATTRIBUTE6 + 0), 'CURRENT'
              INTO ln_score, lc_aging_bucket
              FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
             WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_US_VS'
                   AND FFVS.flex_value_set_id = FFV.flex_value_set_id;

            v_aging_bucket   := lc_aging_bucket;
            -- gc_default_aging_bucket := lc_aging_bucket;
            -- Added above for defect# 3341 by BT Tech Team on 08-Oct-2015
            LOG (
                p_module        => 'GET_SCORE',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_aging_bucket_avg_score_it Fetched Defaulet Score and Bucket');
        ELSE
            OPEN aging_bucket_c;

            FETCH aging_bucket_c BULK COLLECT INTO l_aging_tbl;


            FOR ln_loop IN 1 .. l_aging_tbl.COUNT
            LOOP
                --ln_amount_due := 0;
                ln_days_from      := 0;
                ln_days_to        := 0;
                ln_avg_from       := 0;
                ln_avg_to         := 0;
                ln_percentage     := 0;
                ln_score          := 0;
                lc_aging_bucket   := NULL;

                ln_days_from      := l_aging_tbl (ln_loop).days_from;
                ln_days_to        := l_aging_tbl (ln_loop).days_to;
                ln_avg_from       := l_aging_tbl (ln_loop).ar_avg_from;
                ln_avg_to         := l_aging_tbl (ln_loop).ar_avg_to;
                ln_score          := l_aging_tbl (ln_loop).score;
                lc_aging_bucket   := l_aging_tbl (ln_loop).bucket;

                --            IF    ln_days_from <> ln_prev_days_from
                --               OR ln_days_to <> ln_prev_days_to
                --            THEN
                IF     ln_prev_days_from <> ln_days_from
                   AND ln_prev_days_to <> ln_days_to
                THEN
                    ln_amount_due       :=
                        XXDO_IEX_SCORING_PKG.get_amount_due (
                            P_CUST_ACCOUNT_ID,
                            ln_days_from,
                            ln_days_to);



                    ln_prev_days_from   := ln_days_from;
                    ln_prev_days_to     := ln_days_to;


                    LOG (
                        p_module        => 'get_aging_bucket_avg_score_it',
                        p_line_number   => NULL,
                        p_log_message   =>
                               ' get_aging_bucket_avg_score_it  amount due : '
                            || ln_amount_due);


                    OPEN lowest_score_range_c (ln_days_from, ln_days_to);

                    FETCH lowest_score_range_c INTO ln_lowest_Score_range;

                    CLOSE lowest_score_range_c;

                    LOG (
                        p_module        => 'get_aging_bucket_avg_score_it',
                        p_line_number   => NULL,
                        p_log_message   =>
                               ' get_aging_bucket_avg_score_it  ln_lowest_Score_range: '
                            || ln_lowest_Score_range);
                END IF;

                --            END IF;

                IF     ln_amount_due != 0
                   AND -- Commented below on 23/Sep/2015  for defect# 3150
                       -- ROUND ( (ln_amount_due / ln_total_amount_due), 2) * 100 >=
                       -- Added below on 23/Sep/2015  for defect# 3150
                       ROUND ((ln_amount_due / ln_total_amount_due) * 100, 2) >=
                       ln_lowest_Score_range
                THEN
                    -- Commented below on 23/Sep/2015  for defect# 3150
                    --ln_percentage := ROUND ( (ln_amount_due / ln_total_amount_due), 2) * 100;
                    -- Added below on 23/Sep/2015  for defect# 3150
                    ln_percentage    :=
                        ROUND ((ln_amount_due / ln_total_amount_due) * 100,
                               2);

                    IF ln_percentage > 100
                    THEN
                        ln_percentage   := 100;
                    END IF;

                    v_aging_bucket   := lc_aging_bucket;


                    EXIT WHEN     ln_percentage >= ln_avg_from
                              AND ln_percentage <= ln_avg_to;
                END IF;
            END LOOP;

            CLOSE aging_bucket_c;
        END IF;

        LOG (
            p_module        => 'get_aging_bucket_avg_score_it',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_it AR Percentage : '
                || ln_percentage);

        LOG (
            p_module        => 'get_aging_bucket_avg_score_it',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_it Aging Bucket Score : '
                || ln_score);



        LOG (
            p_module        => 'get_aging_bucket_avg_score_it',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_it Aging Bucket : '
                || lc_aging_bucket);


        LOG (p_module        => 'get_aging_bucket_avg_score_it',
             p_line_number   => NULL,
             p_log_message   => ' End get_aging_bucket_avg_score_it ');



        RETURN ln_score;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            gc_exception_flag   := 'Y';

            LOG (p_module        => SQLERRM,
                 p_line_number   => DBMS_UTILITY.format_error_backtrace,
                 p_log_message   => 'Error in get_aging_bucket_avg_score_it');

            -- Added below for defect# 3341 by BT Tech Team on 08-Oct-2015
            SELECT FFV.ATTRIBUTE6, FFV.ATTRIBUTE5
              INTO ln_score, lc_aging_bucket
              FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
             WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_US_VS'
                   AND FFVS.flex_value_set_id = FFV.flex_value_set_id
                   AND ffv.attribute5 = 'DEFAULT';

            -- ln_score := 15;
            -- Added above for defect# 3341 by BT Tech Team on 08-Oct-2015
            RETURN ln_score;
    END get_aging_bucket_avg_score_IT;

    -- End of Changes for CCR0009857

    /*Start of changes as part of Switzerland Project by srinath siricilla on 07-NOV-2016*/
    /*******************************************************************************
    * Funtion Name : get_aging_bucket_avg_score_sz
    * Description  : This Function will generate and return  aging bucket score
    *                for a given cust_account_id
    * Parameters   :P_CUST_ACCOUNT_ID
    * --------------------------------------------------------------------------- */

    FUNCTION get_aging_bucket_avg_score_sz (P_CUST_ACCOUNT_ID IN NUMBER)
        RETURN NUMBER
    IS
        ln_total_amount_due     NUMBER := 0;

        --P_CUST_ACCOUNT_ID              NUMBER := 1047;

        CURSOR aging_bucket_c IS
              SELECT FFV.attribute6 score, FFV.ATTRIBUTE1 days_from, FFV.attribute2 days_to,
                     ffv.attribute3 ar_avg_from, ffv.attribute4 ar_avg_to, ffv.attribute5 bucket,
                     ffv.attribute6 seq
                FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
               WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_SZ_VS'
                     AND FFVS.flex_value_set_id = FFV.flex_value_set_id
            ORDER BY FFV.flex_value + 0 ASC;

        CURSOR lowest_score_range_c (P_days_from NUMBER, P_days_to NUMBER)
        IS
            SELECT MIN (ffv.attribute3 + 0)
              FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
             WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_SZ_VS'
                   AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                   AND FFV.ATTRIBUTE1 = P_days_from
                   AND FFV.attribute2 = P_days_to;


        TYPE l_aging_info_type IS TABLE OF aging_bucket_c%ROWTYPE;

        l_aging_tbl             l_aging_info_type;
        ln_amount_due           NUMBER;
        ln_days_from            NUMBER;
        ln_days_to              NUMBER;
        ln_avg_from             NUMBER;
        ln_avg_to               NUMBER;
        ln_percentage           NUMBER;
        ln_score                NUMBER;
        lc_aging_bucket         VARCHAR2 (20);
        ln_lowest_Score_range   NUMBER;
        ln_prev_days_from       NUMBER;
        ln_prev_days_to         NUMBER;
    BEGIN
        gc_exception_flag     := 'N';
        LOG (p_module        => 'get_aging_bucket_avg_score_sz',
             p_line_number   => NULL,
             p_log_message   => ' Start get_aging_bucket_avg_score_sz ');

        ln_total_amount_due   := 0;
        ln_percentage         := 0;
        ln_score              := 0;
        ln_amount_due         := 0;
        ln_days_from          := 0;
        ln_days_to            := 0;
        ln_avg_from           := 0;
        ln_avg_to             := 0;
        lc_aging_bucket       := NULL;
        ln_prev_days_from     := 0;
        ln_prev_days_to       := 0;



        ln_total_amount_due   :=
            XXDO_IEX_SCORING_PKG.get_amount_due (P_CUST_ACCOUNT_ID,
                                                 NULL,
                                                 NULL);

        -- XXV_DEBUG_PRC('First calculation ln_total_amount_due : '||ln_total_amount_due||' for Cust Account : '||P_CUST_ACCOUNT_ID);

        LOG (
            p_module        => 'GET_SCORE',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_sz Total amount due : '
                || ln_total_amount_due);

        FND_LOG.STRING (
            LOG_LEVEL   => FND_LOG.LEVEL_STATEMENT,
            MODULE      => gc_module,
            MESSAGE     => 'TOTAL_AMOUNT_DUE : ' || ln_total_amount_due);

        SELECT FFV.attribute5
          INTO gc_default_aging_bucket
          FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
         WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_SZ_VS'
               AND FFVS.flex_value_set_id = FFV.flex_value_set_id
               AND FFV.ATTRIBUTE3 = 0
               AND FFV.ATTRIBUTE4 = 0
               AND FFV.ATTRIBUTE1 = 0
               AND FFV.ATTRIBUTE2 = 0;

        --XXV_DEBUG_PRC('Default aging bucket gc_default_aging_bucket : '||gc_default_aging_bucket);

        LOG (
            p_module        => 'GET_SCORE',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_sz Fetched Defaulet  Bucket : '
                || gc_default_aging_bucket);

        -- Added below for defect# 3341 by BT Tech Team on 08-Oct-2015
        IF ln_total_amount_due <= 0
        THEN
            --ln_score := 50;
            --XXV_DEBUG_PRC('Less than Zero ln_total_amount_due : '||ln_total_amount_due);
            SELECT MAX (FFV.ATTRIBUTE6 + 0), 'CURRENT'
              INTO ln_score, lc_aging_bucket
              FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
             WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_US_VS'
                   AND FFVS.flex_value_set_id = FFV.flex_value_set_id;

            v_aging_bucket   := lc_aging_bucket;
            --XXV_DEBUG_PRC('Less than Zero v_aging_bucket : '||v_aging_bucket);
            -- gc_default_aging_bucket := lc_aging_bucket;
            -- Added above for defect# 3341 by BT Tech Team on 08-Oct-2015
            LOG (
                p_module        => 'GET_SCORE',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_aging_bucket_avg_score_sz Fetched Defaulet Score and Bucket');
        ELSE
            --XXV_DEBUG_PRC('Else clause with amount greater than zero');
            OPEN aging_bucket_c;

            FETCH aging_bucket_c BULK COLLECT INTO l_aging_tbl;


            FOR ln_loop IN 1 .. l_aging_tbl.COUNT
            LOOP
                --ln_amount_due := 0;
                ln_days_from      := 0;
                ln_days_to        := 0;
                ln_avg_from       := 0;
                ln_avg_to         := 0;
                ln_percentage     := 0;
                ln_score          := 0;
                lc_aging_bucket   := NULL;

                ln_days_from      := l_aging_tbl (ln_loop).days_from;
                ln_days_to        := l_aging_tbl (ln_loop).days_to;
                ln_avg_from       := l_aging_tbl (ln_loop).ar_avg_from;
                ln_avg_to         := l_aging_tbl (ln_loop).ar_avg_to;
                ln_score          := l_aging_tbl (ln_loop).score;
                lc_aging_bucket   := l_aging_tbl (ln_loop).bucket;

                --            IF    ln_days_from <> ln_prev_days_from
                --               OR ln_days_to <> ln_prev_days_to
                --            THEN
                IF     ln_prev_days_from <> ln_days_from
                   AND ln_prev_days_to <> ln_days_to
                THEN
                    ln_amount_due       :=
                        XXDO_IEX_SCORING_PKG.get_amount_due (
                            P_CUST_ACCOUNT_ID,
                            ln_days_from,
                            ln_days_to);

                    ln_prev_days_from   := ln_days_from;
                    ln_prev_days_to     := ln_days_to;


                    LOG (
                        p_module        => 'get_aging_bucket_avg_score_sz',
                        p_line_number   => NULL,
                        p_log_message   =>
                               ' get_aging_bucket_avg_score_sz  amount due : '
                            || ln_amount_due);


                    OPEN lowest_score_range_c (ln_days_from, ln_days_to);

                    FETCH lowest_score_range_c INTO ln_lowest_Score_range;

                    CLOSE lowest_score_range_c;

                    LOG (
                        p_module        => 'get_aging_bucket_avg_score_sz',
                        p_line_number   => NULL,
                        p_log_message   =>
                               ' get_aging_bucket_avg_score_sz  ln_lowest_Score_range: '
                            || ln_lowest_Score_range);
                END IF;

                --            END IF;

                IF     ln_amount_due != 0
                   AND -- Commented below on 23/Sep/2015  for defect# 3150
                       -- ROUND ( (ln_amount_due / ln_total_amount_due), 2) * 100 >=
                       -- Added below on 23/Sep/2015  for defect# 3150
                       ROUND ((ln_amount_due / ln_total_amount_due) * 100, 2) >=
                       ln_lowest_Score_range
                THEN
                    -- Commented below on 23/Sep/2015  for defect# 3150
                    --ln_percentage := ROUND ( (ln_amount_due / ln_total_amount_due), 2) * 100;
                    -- Added below on 23/Sep/2015  for defect# 3150
                    ln_percentage    :=
                        ROUND ((ln_amount_due / ln_total_amount_due) * 100,
                               2);

                    IF ln_percentage > 100
                    THEN
                        ln_percentage   := 100;
                    END IF;

                    v_aging_bucket   := lc_aging_bucket;
                    --XXV_DEBUG_PRC('Amount Calc with percentage value : '||v_aging_bucket||' and ln_amount_due : '||ln_amount_due);

                    EXIT WHEN     ln_percentage >= ln_avg_from
                              AND ln_percentage <= ln_avg_to;
                END IF;
            END LOOP;

            CLOSE aging_bucket_c;
        END IF;

        LOG (
            p_module        => 'get_aging_bucket_avg_score_sz',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_sz AR Percentage : '
                || ln_percentage);

        LOG (
            p_module        => 'get_aging_bucket_avg_score_sz',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_sz Aging Bucket Score : '
                || ln_score);



        LOG (
            p_module        => 'get_aging_bucket_avg_score_sz',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_sz Aging Bucket : '
                || lc_aging_bucket);


        LOG (p_module        => 'get_aging_bucket_avg_score_sz',
             p_line_number   => NULL,
             p_log_message   => ' End get_aging_bucket_avg_score_sz ');



        RETURN ln_score;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            gc_exception_flag   := 'Y';

            LOG (p_module        => SQLERRM,
                 p_line_number   => DBMS_UTILITY.format_error_backtrace,
                 p_log_message   => 'Error in get_aging_bucket_avg_score_sz');

            -- Added below for defect# 3341 by BT Tech Team on 08-Oct-2015
            SELECT FFV.ATTRIBUTE6, FFV.ATTRIBUTE5
              INTO ln_score, lc_aging_bucket
              FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
             WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_US_VS'
                   AND FFVS.flex_value_set_id = FFV.flex_value_set_id
                   AND ffv.attribute5 = 'DEFAULT';

            -- ln_score := 15;
            -- Added above for defect# 3341 by BT Tech Team on 08-Oct-2015
            RETURN ln_score;
    END get_aging_bucket_avg_score_sz;

    /*End of change as part of Switzerland Project by srinath siricilla on 07-NOV-2016*/

    /*******************************************************************************
    * Funtion Name : get_aging_bucket_avg_score_fr
    * Description  : This Function will generate and return  aging bucket score
    *                for a given cust_account_id
    * Parameters   :P_CUST_ACCOUNT_ID
    * --------------------------------------------------------------------------- */


    FUNCTION get_aging_bucket_avg_score_fr (P_CUST_ACCOUNT_ID IN NUMBER)
        RETURN NUMBER
    IS
        ln_total_amount_due     NUMBER := 0;

        --P_CUST_ACCOUNT_ID              NUMBER := 1047;

        CURSOR aging_bucket_c IS
              SELECT FFV.attribute6 score, FFV.ATTRIBUTE1 days_from, FFV.attribute2 days_to,
                     ffv.attribute3 ar_avg_from, ffv.attribute4 ar_avg_to, ffv.attribute5 bucket,
                     ffv.attribute6 seq
                FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
               WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_FR_VS'
                     AND FFVS.flex_value_set_id = FFV.flex_value_set_id
            ORDER BY FFV.flex_value + 0 ASC;

        CURSOR lowest_score_range_c (P_days_from NUMBER, P_days_to NUMBER)
        IS
            SELECT MIN (ffv.attribute3 + 0)
              FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
             WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_FR_VS'
                   AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                   AND FFV.ATTRIBUTE1 = P_days_from
                   AND FFV.attribute2 = P_days_to;


        TYPE l_aging_info_type IS TABLE OF aging_bucket_c%ROWTYPE;

        l_aging_tbl             l_aging_info_type;
        ln_amount_due           NUMBER;
        ln_days_from            NUMBER;
        ln_days_to              NUMBER;
        ln_avg_from             NUMBER;
        ln_avg_to               NUMBER;
        ln_percentage           NUMBER;
        ln_score                NUMBER;
        lc_aging_bucket         VARCHAR2 (20);
        ln_lowest_Score_range   NUMBER;
        ln_prev_days_from       NUMBER;
        ln_prev_days_to         NUMBER;
    BEGIN
        gc_exception_flag     := 'N';
        LOG (p_module        => 'get_aging_bucket_avg_score_fr',
             p_line_number   => NULL,
             p_log_message   => ' Start get_aging_bucket_avg_score_fr ');



        ln_total_amount_due   := 0;
        ln_percentage         := 0;
        ln_score              := 0;
        ln_amount_due         := 0;
        ln_days_from          := 0;
        ln_days_to            := 0;
        ln_avg_from           := 0;
        ln_avg_to             := 0;
        lc_aging_bucket       := NULL;
        ln_prev_days_from     := 0;
        ln_prev_days_to       := 0;



        ln_total_amount_due   :=
            XXDO_IEX_SCORING_PKG.get_amount_due (P_CUST_ACCOUNT_ID,
                                                 NULL,
                                                 NULL);

        LOG (
            p_module        => 'GET_SCORE',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_fr Total amount due : '
                || ln_total_amount_due);

        FND_LOG.STRING (
            LOG_LEVEL   => FND_LOG.LEVEL_STATEMENT,
            MODULE      => gc_module,
            MESSAGE     => 'TOTAL_AMOUNT_DUE : ' || ln_total_amount_due);

        SELECT FFV.attribute5
          INTO gc_default_aging_bucket
          FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
         WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_FR_VS'
               AND FFVS.flex_value_set_id = FFV.flex_value_set_id
               AND FFV.ATTRIBUTE3 = 0
               AND FFV.ATTRIBUTE4 = 0
               AND FFV.ATTRIBUTE1 = 0
               AND FFV.ATTRIBUTE2 = 0;

        LOG (
            p_module        => 'GET_SCORE',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_fr Fetched Defaulet  Bucket : '
                || gc_default_aging_bucket);

        -- Added below for defect# 3341 by BT Tech Team on 08-Oct-2015
        IF ln_total_amount_due <= 0
        THEN
            --ln_score := 50;

            SELECT MAX (FFV.ATTRIBUTE6 + 0), 'CURRENT'
              INTO ln_score, lc_aging_bucket
              FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
             WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_US_VS'
                   AND FFVS.flex_value_set_id = FFV.flex_value_set_id;

            v_aging_bucket   := lc_aging_bucket;
            -- gc_default_aging_bucket := lc_aging_bucket;
            -- Added above for defect# 3341 by BT Tech Team on 08-Oct-2015
            LOG (
                p_module        => 'GET_SCORE',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_aging_bucket_avg_score_fr Fetched Defaulet Score and Bucket');
        ELSE
            OPEN aging_bucket_c;

            FETCH aging_bucket_c BULK COLLECT INTO l_aging_tbl;


            FOR ln_loop IN 1 .. l_aging_tbl.COUNT
            LOOP
                --ln_amount_due := 0;
                ln_days_from      := 0;
                ln_days_to        := 0;
                ln_avg_from       := 0;
                ln_avg_to         := 0;
                ln_percentage     := 0;
                ln_score          := 0;
                lc_aging_bucket   := NULL;

                ln_days_from      := l_aging_tbl (ln_loop).days_from;
                ln_days_to        := l_aging_tbl (ln_loop).days_to;
                ln_avg_from       := l_aging_tbl (ln_loop).ar_avg_from;
                ln_avg_to         := l_aging_tbl (ln_loop).ar_avg_to;
                ln_score          := l_aging_tbl (ln_loop).score;
                lc_aging_bucket   := l_aging_tbl (ln_loop).bucket;

                --            IF    ln_days_from <> ln_prev_days_from
                --               OR ln_days_to <> ln_prev_days_to
                --            THEN
                IF     ln_prev_days_from <> ln_days_from
                   AND ln_prev_days_to <> ln_days_to
                THEN
                    ln_amount_due       :=
                        XXDO_IEX_SCORING_PKG.get_amount_due (
                            P_CUST_ACCOUNT_ID,
                            ln_days_from,
                            ln_days_to);



                    ln_prev_days_from   := ln_days_from;
                    ln_prev_days_to     := ln_days_to;


                    LOG (
                        p_module        => 'get_aging_bucket_avg_score_fr',
                        p_line_number   => NULL,
                        p_log_message   =>
                               ' get_aging_bucket_avg_score_fr  amount due : '
                            || ln_amount_due);


                    OPEN lowest_score_range_c (ln_days_from, ln_days_to);

                    FETCH lowest_score_range_c INTO ln_lowest_Score_range;

                    CLOSE lowest_score_range_c;

                    LOG (
                        p_module        => 'get_aging_bucket_avg_score_fr',
                        p_line_number   => NULL,
                        p_log_message   =>
                               ' get_aging_bucket_avg_score_fr  ln_lowest_Score_range: '
                            || ln_lowest_Score_range);
                END IF;

                --            END IF;

                IF     ln_amount_due != 0
                   AND -- Commented below on 23/Sep/2015  for defect# 3150
                       -- ROUND ( (ln_amount_due / ln_total_amount_due), 2) * 100 >=
                       -- Added below on 23/Sep/2015  for defect# 3150
                       ROUND ((ln_amount_due / ln_total_amount_due) * 100, 2) >=
                       ln_lowest_Score_range
                THEN
                    -- Commented below on 23/Sep/2015  for defect# 3150
                    --ln_percentage := ROUND ( (ln_amount_due / ln_total_amount_due), 2) * 100;
                    -- Added below on 23/Sep/2015  for defect# 3150
                    ln_percentage    :=
                        ROUND ((ln_amount_due / ln_total_amount_due) * 100,
                               2);

                    IF ln_percentage > 100
                    THEN
                        ln_percentage   := 100;
                    END IF;

                    v_aging_bucket   := lc_aging_bucket;


                    EXIT WHEN     ln_percentage >= ln_avg_from
                              AND ln_percentage <= ln_avg_to;
                END IF;
            END LOOP;

            CLOSE aging_bucket_c;
        END IF;

        LOG (
            p_module        => 'get_aging_bucket_avg_score_fr',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_fr AR Percentage : '
                || ln_percentage);

        LOG (
            p_module        => 'get_aging_bucket_avg_score_fr',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_fr Aging Bucket Score : '
                || ln_score);



        LOG (
            p_module        => 'get_aging_bucket_avg_score_fr',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_fr Aging Bucket : '
                || lc_aging_bucket);


        LOG (p_module        => 'get_aging_bucket_avg_score_fr',
             p_line_number   => NULL,
             p_log_message   => ' End get_aging_bucket_avg_score_fr ');



        RETURN ln_score;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            gc_exception_flag   := 'Y';

            LOG (p_module        => SQLERRM,
                 p_line_number   => DBMS_UTILITY.format_error_backtrace,
                 p_log_message   => 'Error in get_aging_bucket_avg_score_fr');

            -- Added below for defect# 3341 by BT Tech Team on 08-Oct-2015
            SELECT FFV.ATTRIBUTE6, FFV.ATTRIBUTE5
              INTO ln_score, lc_aging_bucket
              FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
             WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_US_VS'
                   AND FFVS.flex_value_set_id = FFV.flex_value_set_id
                   AND ffv.attribute5 = 'DEFAULT';

            -- ln_score := 15;
            -- Added above for defect# 3341 by BT Tech Team on 08-Oct-2015
            RETURN ln_score;
    END get_aging_bucket_avg_score_fr;

    -- Start of Changes for CCR0007180

    /*******************************************************************************
    * Funtion Name : get_aging_bucket_avg_score_jp
    * Description  : This Function will generate and return  aging bucket score
    *                for a given cust_account_id
    * Parameters   :P_CUST_ACCOUNT_ID
    * --------------------------------------------------------------------------- */


    FUNCTION get_aging_bucket_avg_score_jp (P_CUST_ACCOUNT_ID IN NUMBER)
        RETURN NUMBER
    IS
        ln_total_amount_due     NUMBER := 0;

        --P_CUST_ACCOUNT_ID              NUMBER := 1047;

        CURSOR aging_bucket_c IS
              SELECT FFV.attribute6 score, FFV.ATTRIBUTE1 days_from, FFV.attribute2 days_to,
                     ffv.attribute3 ar_avg_from, ffv.attribute4 ar_avg_to, ffv.attribute5 bucket,
                     ffv.attribute6 seq
                FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
               WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_JP_VS'
                     AND FFVS.flex_value_set_id = FFV.flex_value_set_id
            ORDER BY FFV.flex_value + 0 ASC;

        CURSOR lowest_score_range_c (P_days_from NUMBER, P_days_to NUMBER)
        IS
            SELECT MIN (ffv.attribute3 + 0)
              FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
             WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_JP_VS'
                   AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                   AND FFV.ATTRIBUTE1 = P_days_from
                   AND FFV.attribute2 = P_days_to;


        TYPE l_aging_info_type IS TABLE OF aging_bucket_c%ROWTYPE;

        l_aging_tbl             l_aging_info_type;
        ln_amount_due           NUMBER;
        ln_days_from            NUMBER;
        ln_days_to              NUMBER;
        ln_avg_from             NUMBER;
        ln_avg_to               NUMBER;
        ln_percentage           NUMBER;
        ln_score                NUMBER;
        lc_aging_bucket         VARCHAR2 (20);
        ln_lowest_Score_range   NUMBER;
        ln_prev_days_from       NUMBER;
        ln_prev_days_to         NUMBER;
    BEGIN
        gc_exception_flag     := 'N';
        LOG (p_module        => 'get_aging_bucket_avg_score_jp',
             p_line_number   => NULL,
             p_log_message   => ' Start get_aging_bucket_avg_score_jp ');



        ln_total_amount_due   := 0;
        ln_percentage         := 0;
        ln_score              := 0;
        ln_amount_due         := 0;
        ln_days_from          := 0;
        ln_days_to            := 0;
        ln_avg_from           := 0;
        ln_avg_to             := 0;
        lc_aging_bucket       := NULL;
        ln_prev_days_from     := 0;
        ln_prev_days_to       := 0;



        ln_total_amount_due   :=
            XXDO_IEX_SCORING_PKG.get_amount_due (P_CUST_ACCOUNT_ID,
                                                 NULL,
                                                 NULL);

        LOG (
            p_module        => 'GET_SCORE',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_jp Total amount due : '
                || ln_total_amount_due);

        FND_LOG.STRING (
            LOG_LEVEL   => FND_LOG.LEVEL_STATEMENT,
            MODULE      => gc_module,
            MESSAGE     => 'TOTAL_AMOUNT_DUE : ' || ln_total_amount_due);

        SELECT FFV.attribute5
          INTO gc_default_aging_bucket
          FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
         WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_JP_VS'
               AND FFVS.flex_value_set_id = FFV.flex_value_set_id
               AND FFV.ATTRIBUTE3 = 0
               AND FFV.ATTRIBUTE4 = 0
               AND FFV.ATTRIBUTE1 = 0
               AND FFV.ATTRIBUTE2 = 0;

        LOG (
            p_module        => 'GET_SCORE',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_jp Fetched Defaulet  Bucket : '
                || gc_default_aging_bucket);

        IF ln_total_amount_due <= 0
        THEN
            --ln_score := 50;

            SELECT MAX (FFV.ATTRIBUTE6 + 0), 'CURRENT'
              INTO ln_score, lc_aging_bucket
              FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
             WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_JP_VS'
                   AND FFVS.flex_value_set_id = FFV.flex_value_set_id;

            v_aging_bucket   := lc_aging_bucket;

            -- gc_default_aging_bucket := lc_aging_bucket;

            -- Added above for defect# 3341 by BT Tech Team on 08-Oct-2015
            LOG (
                p_module        => 'GET_SCORE',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_aging_bucket_avg_score_jp Fetched Defaulet Score and Bucket');
        ELSE
            OPEN aging_bucket_c;

            FETCH aging_bucket_c BULK COLLECT INTO l_aging_tbl;


            FOR ln_loop IN 1 .. l_aging_tbl.COUNT
            LOOP
                --ln_amount_due := 0;
                ln_days_from      := 0;
                ln_days_to        := 0;
                ln_avg_from       := 0;
                ln_avg_to         := 0;
                ln_percentage     := 0;
                ln_score          := 0;
                lc_aging_bucket   := NULL;

                ln_days_from      := l_aging_tbl (ln_loop).days_from;
                ln_days_to        := l_aging_tbl (ln_loop).days_to;
                ln_avg_from       := l_aging_tbl (ln_loop).ar_avg_from;
                ln_avg_to         := l_aging_tbl (ln_loop).ar_avg_to;
                ln_score          := l_aging_tbl (ln_loop).score;
                lc_aging_bucket   := l_aging_tbl (ln_loop).bucket;

                --            IF    ln_days_from <> ln_prev_days_from
                --               OR ln_days_to <> ln_prev_days_to
                --            THEN
                IF     ln_prev_days_from <> ln_days_from
                   AND ln_prev_days_to <> ln_days_to
                THEN
                    ln_amount_due       :=
                        XXDO_IEX_SCORING_PKG.get_amount_due (
                            P_CUST_ACCOUNT_ID,
                            ln_days_from,
                            ln_days_to);



                    ln_prev_days_from   := ln_days_from;
                    ln_prev_days_to     := ln_days_to;


                    LOG (
                        p_module        => 'get_aging_bucket_avg_score_jp',
                        p_line_number   => NULL,
                        p_log_message   =>
                               ' get_aging_bucket_avg_score_jp  amount due : '
                            || ln_amount_due);


                    OPEN lowest_score_range_c (ln_days_from, ln_days_to);

                    FETCH lowest_score_range_c INTO ln_lowest_Score_range;

                    CLOSE lowest_score_range_c;

                    LOG (
                        p_module        => 'get_aging_bucket_avg_score_jp',
                        p_line_number   => NULL,
                        p_log_message   =>
                               ' get_aging_bucket_avg_score_jp  ln_lowest_Score_range: '
                            || ln_lowest_Score_range);
                END IF;

                --            END IF;

                IF     ln_amount_due != 0
                   AND ROUND ((ln_amount_due / ln_total_amount_due) * 100, 2) >=
                       ln_lowest_Score_range
                THEN
                    ln_percentage    :=
                        ROUND ((ln_amount_due / ln_total_amount_due) * 100,
                               2);

                    IF ln_percentage > 100
                    THEN
                        ln_percentage   := 100;
                    END IF;

                    v_aging_bucket   := lc_aging_bucket;

                    EXIT WHEN     ln_percentage >= ln_avg_from
                              AND ln_percentage <= ln_avg_to;
                END IF;
            END LOOP;

            CLOSE aging_bucket_c;
        END IF;

        LOG (
            p_module        => 'get_aging_bucket_avg_score_jp',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_jp AR Percentage : '
                || ln_percentage);

        LOG (
            p_module        => 'get_aging_bucket_avg_score_jp',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_jp Aging Bucket Score : '
                || ln_score);

        LOG (
            p_module        => 'get_aging_bucket_avg_score_jp',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_aging_bucket_avg_score_jp Aging Bucket : '
                || lc_aging_bucket);


        LOG (p_module        => 'get_aging_bucket_avg_score_jp',
             p_line_number   => NULL,
             p_log_message   => ' End get_aging_bucket_avg_score_jp ');



        RETURN ln_score;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            gc_exception_flag   := 'Y';

            LOG (p_module        => SQLERRM,
                 p_line_number   => DBMS_UTILITY.format_error_backtrace,
                 p_log_message   => 'Error in get_aging_bucket_avg_score_jp');

            SELECT FFV.ATTRIBUTE6, FFV.ATTRIBUTE5
              INTO ln_score, lc_aging_bucket
              FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
             WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_AGING_WATERFALL_JP_VS'
                   AND FFVS.flex_value_set_id = FFV.flex_value_set_id
                   AND ffv.attribute5 = 'DEFAULT';

            RETURN ln_score;
    END get_aging_bucket_avg_score_jp;

    -- End of Changes for CCR0007180

    /*******************************************************************************
    * Funtion Name : get_Weight
    * Description  : This Function will  return  weight
    *                for a given Score Component
    * Parameters   : P_WEIGHT_NAME
    * --------------------------------------------------------------------------- */

    FUNCTION get_Weight (P_WEIGHT_NAME VARCHAR2)
        RETURN NUMBER
    IS
        ln_weight   NUMBER := 0;
    BEGIN
        gc_exception_flag   := 'N';
        LOG (p_module        => 'GET_WEIGHT',
             p_line_number   => NULL,
             p_log_message   => ' Start get_Weight  ');

        LOG (
            p_module        => 'GET_WEIGHT',
            p_line_number   => NULL,
            p_log_message   => ' get_Weight p_weight_name : ' || p_weight_name);



        SELECT Attribute2
          INTO ln_weight
          FROM fnd_flex_values ffv, FND_FLEX_VALUE_SETS ffvs
         WHERE     ffv.flex_value_set_id = ffvs.flex_value_set_id
               AND ffvs.FLEX_VALUE_SET_NAME = 'XXDO_IEX_WEIGHT_MODEL_VS'
               AND ffv.enabled_flag = 'Y'
               AND ffv.attribute1 = p_weight_name;

        LOG (
            p_module        => 'GET_WEIGHT',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_Weight p_weight_name : '
                || p_weight_name
                || ' Weight : '
                || ln_weight);

        LOG (p_module        => 'GET_WEIGHT',
             p_line_number   => NULL,
             p_log_message   => ' End get_Weight  ');


        RETURN ln_weight;
    /*EXCEPTION
       WHEN OTHERS
       THEN
          gc_exception_flag := 'Y';

      log (
          p_module =>        SQLERRM,
          p_line_number => DBMS_UTILITY.format_error_backtrace,
          p_log_message=> ' get_score  Booked Order Score : '
             || ln_book_order_score);

          ln_weight := 0;
          RETURN ln_weight;*/
    END get_Weight;

    /*******************************************************************************
   * Funtion Name : get_booked_order_score
   * Description  : This Function will generate and return  Booked Order score
   *                for a given cust_account_id  at Party Level
   * Parameters   :P_CUST_ACCOUNT_ID
   * --------------------------------------------------------------------------- */

    FUNCTION get_booked_order_score (P_CUST_ACCOUNT_ID IN NUMBER)
        RETURN NUMBER
    IS
        ln_pending_order_count   NUMBER;
        ln_score                 NUMBER;
        ln_party_id              NUMBER;
        lc_is_multi_brand        VARCHAR2 (1);

        CURSOR get_party_c (P_CUST_ACCOUNT_ID NUMBER)
        IS
            SELECT party_id
              FROM hz_cust_accounts
             WHERE cust_account_id = P_CUST_ACCOUNT_ID;

        CURSOR pending_order_c (p_party_id NUMBER)
        IS
            SELECT NVL (COUNT (1), 0)
              FROM oe_order_headers_all ooha, hz_cust_accounts hca
             WHERE     ooha.FLOW_STATUS_CODE = 'BOOKED'
                   AND ooha.sold_to_org_id = hca.cust_account_id
                   AND hca.party_id = p_party_id
                   AND ooha.org_id = gn_org_id;

        CURSOR get_brand_c (p_party_id NUMBER)
        IS
            SELECT DECODE (NVL (COUNT (*), 0),  0, 'N',  1, 'N',  'Y')
              FROM hz_cust_accounts_all hca, fnd_lookup_values_vl flv
             WHERE     hca.party_id = p_party_id
                   AND flv.lookup_code <> gc_all_brand_code
                   AND hca.attribute1 = flv.lookup_code
                   --  AND hca.sales_channel_code IN ('WHOLESALE', 'DISTRIBUTOR')
                   AND flv.lookup_type = 'DO_BRANDS';

        /*SELECT DECODE (COUNT (DISTINCT (attribute1)), 1, 'Y', 'N')
                   FROM hz_cust_accounts
                  WHERE party_id = p_party_id;*/



        CURSOR at_once_order_c (p_party_id NUMBER)
        IS
            SELECT NVL (COUNT (ooha.header_id), 0)
              FROM oe_order_headers_all ooha, hz_cust_accounts_all hca
             WHERE     ooha.sold_to_org_id = hca.cust_account_id
                   AND TRUNC (REQUEST_DATE) - TRUNC (ORDERED_DATE) <
                       gc_ao_days
                   AND ooha.FLOW_STATUS_CODE = 'BOOKED'
                   AND hca.party_id = p_party_id
                   AND ooha.org_id = gn_org_id;

        CURSOR booked_order_score_c (p_is_AO            VARCHAR2,
                                     p_is_multi_brand   VARCHAR2)
        IS
            SELECT ATTRIBUTE3
              FROM FND_FLEX_VALUE_SETS FFVS, FND_FLEX_VALUES FFV
             WHERE     FLEX_VALUE_SET_NAME = 'XXDO_IEX_BOOKED_ORDERS_VS'
                   AND FFVS.flex_value_set_id = FFV.flex_value_set_id
                   AND ffv.enabled_flag = 'Y'
                   AND FFV.attribute1 = p_is_AO
                   AND FFV.attribute2 = p_is_multi_brand;


        CURSOR pre_season_order_c (p_party_id NUMBER)
        IS
            SELECT NVL (COUNT (ooha.header_id), 0)
              INTO ln_pending_order_count
              FROM oe_order_headers_all ooha, hz_cust_accounts_all hca
             WHERE     ooha.sold_to_org_id = hca.cust_account_id
                   AND TRUNC (REQUEST_DATE) - TRUNC (ORDERED_DATE) >=
                       gc_ao_days
                   AND ooha.FLOW_STATUS_CODE = 'BOOKED'
                   AND hca.party_id = p_party_id
                   AND ooha.org_id = gn_org_id;
    BEGIN
        gc_exception_flag   := 'N';
        LOG (p_module        => 'GET_BOOKED_ORDER_SCORE',
             p_line_number   => NULL,
             p_log_message   => ' Start get_booked_order_score ');

        gc_ao_days          :=
            IEX_UTILITIES.GET_LOOKUP_MEANING (
                'XXDO_IEX_SCORING_GLOBAL_VALUES',
                'AT_ONCE_ORDER_DAYS');
        gn_booked_order_default_score   :=
            IEX_UTILITIES.GET_LOOKUP_MEANING (
                'XXDO_IEX_SCORING_GLOBAL_VALUES',
                'BOOKED_ORDER_DEFAULT_SCORE');
        gc_all_brand_code   :=
            IEX_UTILITIES.GET_LOOKUP_MEANING (
                'XXDO_IEX_SCORING_GLOBAL_VALUES',
                'ALL_BRAND');

        OPEN get_party_c (P_CUST_ACCOUNT_ID);

        FETCH get_party_c INTO ln_party_id;

        CLOSE get_party_c;

        LOG (
            p_module        => 'GET_BOOKED_ORDER_SCORE',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_booked_order_score party_id : '
                || ln_party_id
                || ' for given cust_account_id : '
                || P_CUST_ACCOUNT_ID);


        OPEN pending_order_c (ln_party_id);

        FETCH pending_order_c INTO ln_pending_order_count;

        CLOSE pending_order_c;

        LOG (
            p_module        => 'GET_BOOKED_ORDER_SCORE',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_booked_order_score  Pending Order Count at Customer Level : '
                || ln_pending_order_count);



        -- No Pendindg Orders
        IF ln_pending_order_count = 0
        THEN
            ln_score   := gn_booked_order_default_score;

            LOG (
                p_module        => 'GET_BOOKED_ORDER_SCORE',
                p_line_number   => NULL,
                p_log_message   =>
                       ' get_booked_order_score  No Pending Order Count at Customer Level so Score: '
                    || ln_score);
        ELSE
            LOG (
                p_module        => 'GET_SCORE',
                p_line_number   => NULL,
                p_log_message   =>
                    ' Start AT_ONCE_ORDER_DAYS : ' || gc_ao_days);


            OPEN get_brand_c (ln_party_id);

            FETCH get_brand_c INTO lc_is_multi_brand;

            CLOSE get_brand_c;

            -- AO defined as Order date is <11 days from Request Date for multi Brand account

            OPEN at_once_order_c (ln_party_id);

            FETCH at_once_order_c INTO ln_pending_order_count;

            CLOSE at_once_order_c;

            LOG (
                p_module        => 'GET_BOOKED_ORDER_SCORE',
                p_line_number   => NULL,
                p_log_message   =>
                       ' get_booked_order_score  At Once Order Count  : '
                    || ln_pending_order_count);


            IF ln_pending_order_count <> 0
            THEN
                IF lc_is_multi_brand = 'Y'
                THEN
                    OPEN booked_order_score_c ('Y', 'Y');

                    FETCH booked_order_score_c INTO ln_score;

                    CLOSE booked_order_score_c;

                    LOG (
                        p_module        => 'GET_BOOKED_ORDER_SCORE',
                        p_line_number   => NULL,
                        p_log_message   =>
                               ' get_booked_order_score  At Once Order , For All Brand Account score: '
                            || ln_score);
                ELSE
                    -- AO defined as Order date is <11 days from Request Datefor single Brand account
                    OPEN booked_order_score_c ('Y', 'N');

                    FETCH booked_order_score_c INTO ln_score;

                    CLOSE booked_order_score_c;

                    LOG (
                        p_module        => 'GET_BOOKED_ORDER_SCORE',
                        p_line_number   => NULL,
                        p_log_message   =>
                               ' get_booked_order_score  At Once Order , For Single Brand Account SCORE: '
                            || ln_score);
                END IF;
            ELSE
                --pre season order is defined as Order date is >11 days from Request Date for all Brand account
                OPEN pre_season_order_c (ln_party_id);

                FETCH pre_season_order_c INTO ln_pending_order_count;

                CLOSE pre_season_order_c;

                LOG (
                    p_module        => 'GET_BOOKED_ORDER_SCORE',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_booked_order_score pre season order Count  : '
                        || ln_pending_order_count);



                IF ln_pending_order_count <> 0
                THEN
                    IF lc_is_multi_brand = 'Y'
                    THEN
                        OPEN booked_order_score_c ('N', 'Y');

                        FETCH booked_order_score_c INTO ln_score;

                        CLOSE booked_order_score_c;

                        LOG (
                            p_module        => 'GET_BOOKED_ORDER_SCORE',
                            p_line_number   => NULL,
                            p_log_message   =>
                                   ' get_booked_order_score  pre season orcer , For All Brand Account Score : '
                                || ln_score);
                    ELSE
                        --pre season orcer is defined as Order date is >11 days from Request Date for single Brand account


                        OPEN booked_order_score_c ('N', 'N');

                        FETCH booked_order_score_c INTO ln_score;

                        CLOSE booked_order_score_c;

                        LOG (
                            p_module        => 'GET_BOOKED_ORDER_SCORE',
                            p_line_number   => NULL,
                            p_log_message   =>
                                   ' get_booked_order_score  pre season orcer , For Single Brand Account Score : '
                                || ln_score);
                    END IF;
                END IF;
            END IF;
        END IF;

        LOG (p_module        => 'GET_BOOKED_ORDER_SCORE',
             p_line_number   => NULL,
             p_log_message   => ' End get_booked_order_score ');



        RETURN ln_score;
    /*EXCEPTION
       WHEN OTHERS
       THEN
          gc_exception_flag := 'Y';
      log (
          p_module =>        SQLERRM,
          p_line_number => DBMS_UTILITY.format_error_backtrace,
          p_log_message=>  'Error in get_booked_order_score');

          ln_score := 0;
          RETURN ln_score;*/
    END get_booked_order_score;

    /*******************************************************************************
       * Funtion Name : get_adl_score
       * Description  : This Function will generate and return  ADL score
       *                for a given cust_account_id
       * Parameters   :P_CUST_ACCOUNT_ID
       * --------------------------------------------------------------------------- */

    FUNCTION get_adl_score (P_CUST_ACCOUNT_ID IN NUMBER)
        RETURN NUMBER
    IS
        CURSOR adl_scoring_c (P_variance_FLAG VARCHAR2)
        IS
              SELECT ffv.attribute1 adl, ffv.attribute3 score, ffv.attribute4 variance_from,
                     ffv.attribute5 variance_to
                FROM fnd_flex_values ffv, fnd_flex_value_sets ffvs
               WHERE     ffv.flex_value_set_id = ffvs.flex_value_set_id
                     AND ffvs.flex_value_set_name = 'XXDO_IEX_ADL_TREND_VS'
                     AND ffv.attribute6 = P_variance_FLAG
            ORDER BY ffv.flex_value + 0 ASC;

        CURSOR insert_update_c (p_cust_acc_id IN NUMBER)
        IS
            SELECT DECODE (COUNT (*), 0, 'Y', 'N')
              FROM xxd_iex_metrics_tbl
             WHERE cust_account_id = p_cust_acc_id AND org_id = gn_org_id;

        CURSOR adl_scores (p_cust_acc_id IN NUMBER)
        IS
            SELECT NVL (curr_adl, 0), NVL (adl_q1, 0)
              FROM xxd_iex_metrics_tbl
             WHERE cust_account_id = p_cust_acc_id AND org_id = gn_org_id;

        TYPE l_adl_score_type IS TABLE OF adl_scoring_c%ROWTYPE;

        l_adl_score_tbl    l_adl_score_type;

        ln_curr_adl        NUMBER := 0;               --ADL in current quarter
        ln_prv_adl         NUMBER := 0;              --ADL in previous quarter
        ln_score           NUMBER := 0;
        ln_adl_Variance    NUMBER := 0;


        --ln_quat_num                 NUMBER;            -- current quarter number
        -- ln_prev_qrt_num             NUMBER;           -- previous quarter number
        -- ld_prev_cl_qrt_start_date   DATE; -- period start date of period closed pior to recent closed period
        -- ld_prev_cl_qrt_end_date     DATE; -- period end date of period closed pior to recent closed period

        ln_adl             NUMBER;
        ln_variance_from   NUMBER;
        ln_variance_to     NUMBER;
        ln_variance_flag   VARCHAR2 (10);


        CURSOR c_prev_qtr (p_quat_num NUMBER)
        IS
            SELECT MAX (quarter_start_date) - 1
              FROM gl_periods
             WHERE     period_year =
                       DECODE (
                           p_quat_num,
                           gn_gl_last_quarter, TO_CHAR (SYSDATE, 'YYYY') - 1,
                           TO_CHAR (SYSDATE, 'YYYY'))
                   AND quarter_num = p_quat_num
                   AND entered_period_name <> 'ADJ';

        CURSOR adl_variance_c (P_CUST_ACCOUNT_ID NUMBER)
        IS
            SELECT NVL (adl_variance, 0)
              FROM xxd_iex_metrics_tbl
             WHERE cust_account_id = p_cust_account_id AND org_id = gn_org_id;
    BEGIN
        gc_exception_flag   := 'N';

        LOG (p_module        => 'GET_ADL_SCORE',
             p_line_number   => NULL,
             p_log_message   => ' Start get_adl_score ');

        /* Commented this part as the current adl will be calculated by concurrent program
         gn_adl_rolling_days :=
            IEX_UTILITIES.GET_LOOKUP_MEANING ('XXDO_IEX_SCORING_GLOBAL_VALUES',
                                              'ADL_ROLLING_DAYS');

         LOG (p_module        => 'GET_SCORE',
              p_line_number   => NULL,
              p_log_message   => ' ADL_ROLLING_DAYS : ' || gn_adl_rolling_days);


         SELECT NVL (COUNT (*), 0)
           INTO ln_cl_inv_cnt_curr
           FROM ar_payment_schedules_all
          WHERE     gl_date BETWEEN TRUNC (SYSDATE) - gn_adl_rolling_days
                                AND TRUNC (SYSDATE)
                AND status = 'CL'
                AND customer_id = P_CUST_ACCOUNT_ID
                AND org_id = gn_org_id;

         LOG (
            p_module        => 'GET_ADL_SCORE',
            p_line_number   => NULL,
            p_log_message   =>    ' get_adl_score  Current period Invoice Count: '
                               || ln_cl_inv_cnt_curr);


         IF ln_cl_inv_cnt_curr <> 0
         THEN
            SELECT   NVL (SUM (araa.apply_date - apsa.DUE_DATE), 0)
                   / ln_cl_inv_cnt_curr
              INTO ln_curr_adl
              FROM AR_PAYMENT_SCHEDULES_all apsa,
                   AR_RECEIVABLE_APPLICATIONS_ALL araa
             WHERE     apsa.gl_date BETWEEN   TRUNC (SYSDATE)
                                            - gn_adl_rolling_days
                                        AND TRUNC (SYSDATE)
                   AND apsa.status = 'CL'
                   AND araa.APPLIED_CUSTOMER_TRX_ID = apsa.customer_trx_id
                   AND apsa.customer_id = p_cust_account_id
                   AND apsa.org_id = gn_org_id;

            LOG (
               p_module        => 'GET_ADL_SCORE',
               p_line_number   => NULL,
               p_log_message   => ' get_adl_score  Current ADL : ' || ln_curr_adl);
         END IF;

         SELECT DECODE (quarter_num,
                        gn_gl_first_quarter, gn_gl_last_quarter,
                        quarter_num - 1)
           INTO ln_quat_num -- fetching previous quaeter number if current quarter in 1 then previous quarter is 4 QUARTER OD LAST YEAR ELSE  current quater -1
           FROM gl_periods
          WHERE     SYSDATE BETWEEN start_date AND end_date
                AND period_year = TO_CHAR (SYSDATE, 'YYYY');

         OPEN c_prev_qtr (ln_quat_num);

         FETCH c_prev_qtr INTO ld_prev_cl_qrt_end_date;

         CLOSE c_prev_qtr;

         SELECT DECODE (ln_quat_num,
                        gn_gl_first_quarter, gn_gl_last_quarter,
                        ln_quat_num - 1)
           INTO ln_prev_qrt_num -- fetching previous quaeter number if current quarter in 1 then previous quarter is 4 QUARTER OD LAST YEAR ELSE  current quater -1
           FROM DUAL;

         SELECT MAX (quarter_start_date)
           INTO ld_prev_cl_qrt_start_date
           FROM gl_periods
          WHERE     period_year =
                       DECODE (
                          ln_prev_qrt_num,
                          gn_gl_last_quarter, TO_CHAR (SYSDATE, 'YYYY') - 1,
                          TO_CHAR (SYSDATE, 'YYYY'))
                AND quarter_num = ln_prev_qrt_num
                AND entered_period_name <> 'ADJ';

         LOG (
            p_module        => 'GET_ADL_SCORE',
            p_line_number   => NULL,
            p_log_message   =>    ' get_adl_score  Previous to recent Closed period Start Date  : '
                               || ld_prev_cl_qrt_start_date
                               || ' period Start Date  : '
                               || ld_prev_cl_qrt_end_date);



         SELECT NVL (COUNT (*), 0)
           INTO ln_cl_inv_cnt_prv
           FROM ar_payment_schedules_all
          WHERE     gl_date BETWEEN TRUNC (ld_prev_cl_qrt_start_date)
                                AND TRUNC (ld_prev_cl_qrt_end_date)
                AND status = 'CL'
                AND customer_id = P_CUST_ACCOUNT_ID
                AND org_id = gn_org_id;

         LOG (
            p_module        => 'GET_SCORE',
            p_line_number   => NULL,
            p_log_message   =>    ' get_adl_score  Previous to recent Closed period Invoice count  : '
                               || ln_cl_inv_cnt_prv);

         IF ln_cl_inv_cnt_prv <> 0
         THEN
            SELECT   NVL (SUM (araa.apply_date - apsa.DUE_DATE), 0)
                   / ln_cl_inv_cnt_prv
              INTO ln_prv_adl
              FROM AR_PAYMENT_SCHEDULES_all apsa,
                   AR_RECEIVABLE_APPLICATIONS_ALL araa
             WHERE     apsa.gl_date BETWEEN TRUNC (ld_prev_cl_qrt_start_date)
                                        AND TRUNC (ld_prev_cl_qrt_end_date)
                   AND apsa.status = 'CL'
                   AND araa.APPLIED_CUSTOMER_TRX_ID = apsa.customer_trx_id
                   AND apsa.customer_id = p_cust_account_id
                   AND apsa.org_id = gn_org_id;
         END IF;*/


        OPEN adl_scores (p_cust_account_id);

        FETCH adl_scores INTO ln_curr_adl, ln_prv_adl;

        CLOSE adl_scores;

        LOG (
            p_module        => 'GET_ADL_SCORE',
            p_line_number   => NULL,
            p_log_message   =>
                   ' get_adl_score  Previous to recent Closed period ADL  : '
                || ln_prv_adl);



        IF ln_prv_adl <> 0
        THEN
            ln_adl_Variance   :=
                ROUND ((ln_curr_adl - ln_prv_adl) / ln_prv_adl, 2) * 100;
            LOG (
                p_module        => 'GET_ADL_SCORE',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_adl_score  ADL Variance  : ' || ln_adl_Variance);
        END IF;

        --ln_adl_Variance := -133;
        --ln_curr_adl := -9;

        IF ln_adl_variance = 0 AND ln_prv_adl <> 0
        THEN
            LOG (
                p_module        => 'GET_ADL_SCORE',
                p_line_number   => NULL,
                p_log_message   =>
                    ' get_adl_score  ADL Variance is 0 fetch pervious ADL variance');

            OPEN adl_variance_c (p_cust_account_id);

            FETCH adl_variance_c INTO ln_adl_variance;

            CLOSE adl_variance_c;
        END IF;


        IF ln_adl_Variance <> 0 AND ln_curr_adl <> 0
        THEN
            IF ln_curr_adl < ln_prv_adl                        -- Fav Variance
            THEN
                LOG (
                    p_module        => 'GET_ADL_SCORE',
                    p_line_number   => NULL,
                    p_log_message   => ' get_adl_score  Checking FAV Variance');


                OPEN adl_scoring_c ('FAV');

                FETCH adl_scoring_c BULK COLLECT INTO l_adl_score_tbl;


                FOR ln_loop IN 1 .. l_adl_score_tbl.COUNT
                LOOP
                    ln_ADL             := 0;
                    ln_variance_from   := 0;
                    ln_variance_to     := 0;
                    ln_score           := 0;

                    ln_ADL             := l_adl_score_tbl (ln_loop).adl;
                    ln_variance_from   :=
                        l_adl_score_tbl (ln_loop).variance_from;
                    ln_variance_to     :=
                        l_adl_score_tbl (ln_loop).variance_to;
                    ln_score           := l_adl_score_tbl (ln_loop).score;

                    EXIT WHEN     ln_curr_adl < ln_adl
                              AND ln_adl_Variance >= ln_variance_from
                              AND ln_adl_Variance <= ln_variance_to;
                END LOOP;

                CLOSE adl_scoring_c;
            ELSE
                LOG (
                    p_module        => 'GET_ADL_SCORE',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' get_adl_score  Checking UNFAV Variance');


                OPEN adl_scoring_c ('UNFAV');

                FETCH adl_scoring_c BULK COLLECT INTO l_adl_score_tbl;


                FOR ln_loop IN 1 .. l_adl_score_tbl.COUNT
                LOOP
                    ln_ADL             := l_adl_score_tbl (ln_loop).adl;
                    ln_variance_from   :=
                        l_adl_score_tbl (ln_loop).variance_from;
                    ln_variance_to     :=
                        l_adl_score_tbl (ln_loop).variance_to;
                    ln_score           := l_adl_score_tbl (ln_loop).score;

                    EXIT WHEN     ln_curr_adl < ln_adl
                              AND ln_adl_Variance >= ln_variance_from
                              AND ln_adl_Variance <= ln_variance_to;
                END LOOP;

                CLOSE adl_scoring_c;
            END IF;
        END IF;

        LOG (
            p_module        => 'GET_ADL_SCORE',
            p_line_number   => NULL,
            p_log_message   =>
                ' get_adl_score Update hz_cust_accounts with ADL Variance');

        OPEN insert_update_c (p_cust_account_id);

        FETCH insert_update_c INTO gc_insert_check;

        CLOSE insert_update_c;

        IF NVL (gc_insert_check, 'Y') = 'Y'
        THEN
            INSERT_UPDATE (p_insert_update_flag => 'Y', p_cust_account_id => p_cust_account_id, p_org_id => gn_org_id
                           , p_adl_variance => ln_adl_Variance);
        ELSE
            INSERT_UPDATE (p_insert_update_flag => 'N', p_cust_account_id => p_cust_account_id, p_org_id => gn_org_id
                           , p_adl_variance => ln_adl_Variance);
        END IF;

        LOG (p_module        => 'GET_ADL_SCORE',
             p_line_number   => NULL,
             p_log_message   => ' get_adl_score  : ' || ln_score);

        LOG (p_module        => 'GET_ADL_SCORE',
             p_line_number   => NULL,
             p_log_message   => ' END get_adl_score ');


        RETURN ln_score;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            gc_exception_flag   := 'Y';
            LOG (p_module        => SQLERRM,
                 p_line_number   => DBMS_UTILITY.format_error_backtrace,
                 p_log_message   => 'no_data_found  in get_adl_score');

            ln_score            := 0;
            RETURN ln_score;
    END get_adl_score;


    /*******************************************************************************
       * Funtion Name : get_mapped_score
       * Description  : This Function will return The Mapped score
       *                for a given Score and Aging Bucket
       * Parameters   :P_Score
       *               P_AGING_BUCKET
       * --------------------------------------------------------------------------- */

    /*  FUNCTION get_mapped_score (p_score NUMBER, p_bucket VARCHAR2)
         RETURN NUMBER
      IS
         ln_score   NUMBER := 0;
      BEGIN
         LOG (p_module        => 'GET_MAPPED_SCORE',
              p_line_number   => NULL,
              p_log_message   => 'Start get_mapped_score ');

         LOG (
            p_module        => 'GET_MAPPED_SCORE',
            p_line_number   => NULL,
            p_log_message   =>    'get_mapped_score Input Score : '
                               || p_score
                               || ' Bucket : '
                               || P_bucket);


         SELECT ATTRIBUTE4
           INTO ln_score
           FROM fnd_flex_values ffv, FND_FLEX_VALUE_SETS ffvs
          WHERE     ffv.flex_value_set_id = ffvs.flex_value_set_id
                AND ffvs.FLEX_VALUE_SET_NAME LIKE 'XXDO_IEX_MAPPED_SCORES_VS'
                AND ffv.attribute3 = p_bucket
                AND p_score BETWEEN ffv.attribute1 + 0 AND ffv.attribute2 + 0;



         IF NVL (ln_score, 0) = 0
         THEN
            LOG (
               p_module        => 'GET_MAPPED_SCORE',
               p_line_number   => NULL,
               p_log_message   =>    ' get_mapped_score ln_score is Zero so setting to P_Score: '
                                  || p_score);


            ln_score := p_score;
         END IF;

         LOG (p_module        => 'GET_MAPPED_SCORE',
              p_line_number   => NULL,
              p_log_message   => 'End get_mapped_score : ' || ln_score);

         RETURN ln_score;
      /*EXCEPTION
         WHEN OTHERS
         THEN
            gc_exception_flag := 'Y';
        log (
            p_module =>     SQLERRM,
            p_line_number => DBMS_UTILITY.format_error_backtrace,
            p_log_message=>  'Error in get_mapped_score');


            ln_score := 0;
            RETURN ln_score;
      END get_mapped_score;*/


    /*FUNCTION caluclate_score (ln_aging_bucket_score    NUMBER,
                              ln_aging_bucket_wt       NUMBER,
                              ln_last_payment_score    NUMBER,
                              ln_last_payment_wt       NUMBER,
                              ln_book_order_score      NUMBER,
                              ln_book_order_wt         NUMBER,
                              ln_adl_score             NUMBER,
                              ln_adl_wt                NUMBER,
                              lc_prorate_score         VARCHAR2)
       RETURN NUMBER
    IS
       ln_score   NUMBER := 0;
    BEGIN
       IF lc_prorate_score = 'Y'
       THEN
          LOG (
             p_module        => 'CALUCLATE_SCORE',
             p_line_number   => NULL,
             p_log_message   => ' caluclate_score  Pro-Rate profile is set to Yes');

          IF ln_last_payment_score != 0 AND ln_adl_score = 0
          THEN
             -- ln_last_payment_score is not zero
             ln_score :=
                  ln_aging_bucket_score * ln_aging_bucket_wt
                + (  (  (ln_aging_bucket_wt * ln_adl_wt)
                      / (  ln_aging_bucket_wt
                         + ln_last_payment_wt
                         + ln_book_order_wt))
                   * ln_aging_bucket_score)
                + ln_last_payment_score * ln_last_payment_wt
                + (  (  (ln_last_payment_wt * ln_adl_wt)
                      / (  ln_aging_bucket_wt
                         + ln_last_payment_wt
                         + ln_book_order_wt))
                   * ln_last_payment_score)
                + ln_book_order_score * ln_book_order_wt
                + (  (  (ln_book_order_wt * ln_adl_wt)
                      / (  ln_aging_bucket_wt
                         + ln_last_payment_wt
                         + ln_book_order_wt))
                   * ln_book_order_score);
          ELSIF ln_last_payment_score = 0 AND ln_adl_score != 0
          THEN
             -- ln_adl_score is not zero

             ln_score :=
                  ln_aging_bucket_score * ln_aging_bucket_wt
                + (  (  (ln_aging_bucket_wt * ln_last_payment_wt)
                      / (ln_aging_bucket_wt + ln_adl_wt + ln_book_order_wt))
                   * ln_aging_bucket_score)
                + ln_book_order_score * ln_book_order_wt
                + (  (  (ln_book_order_wt * ln_last_payment_wt)
                      / (ln_aging_bucket_wt + ln_adl_wt + ln_book_order_wt))
                   * ln_book_order_score)
                + ln_adl_score * ln_adl_wt
                + (  (  (ln_adl_score * ln_last_payment_wt)
                      / (ln_aging_bucket_wt + ln_adl_wt + ln_book_order_wt))
                   * ln_adl_score);
          ELSIF ln_last_payment_score = 0 AND ln_adl_score = 0
          THEN
             -- ln_adl_score is zero and ln_last_payment_score is zero
             ln_score :=
                  ln_aging_bucket_score * ln_aging_bucket_wt
                + (  (  ln_aging_bucket_wt
                      * (ln_last_payment_wt + ln_adl_wt)
                      / (ln_aging_bucket_wt + ln_book_order_wt))
                   * ln_aging_bucket_score)
                + ln_book_order_score * ln_book_order_wt
                + (  (  ln_book_order_wt
                      * (ln_last_payment_wt + ln_adl_wt)
                      / (ln_book_order_wt + ln_book_order_wt))
                   * ln_book_order_score);
          ELSE
             -- Score when all the score are not null
             ln_score :=
                  ln_aging_bucket_score * ln_aging_bucket_wt
                + ln_last_payment_score * ln_last_payment_wt
                + ln_book_order_score * ln_book_order_wt
                + ln_adl_score * ln_adl_wt;
          END IF;
       ELSE
          LOG (
             p_module        => 'CALUCLATE_SCORE',
             p_line_number   => NULL,
             p_log_message   => ' caluclate_score  Pro-Rate profile is set to No');


          ln_score :=
               ln_aging_bucket_score * ln_aging_bucket_wt
             + ln_last_payment_score * ln_last_payment_wt
             + ln_book_order_score * ln_book_order_wt
             + ln_adl_score * ln_adl_wt;
       END IF;



       RETURN ROUND (ln_score, 2);
    --EXCEPTION
      -- WHEN OTHERS
      -- THEN
      --    gc_exception_flag := 'Y';
      --log (
      --    p_module =>        SQLERRM,
      --    p_line_number => DBMS_UTILITY.format_error_backtrace,
      --    p_log_message=>  'Error in get_mapped_score');

      --    ln_score := -1;
      --    RETURN ln_score;
    END caluclate_score; */

    FUNCTION caluclate_score (ln_aging_bucket_score NUMBER, ln_aging_bucket_wt NUMBER, ln_last_payment_score NUMBER, ln_last_payment_wt NUMBER, ln_book_order_score NUMBER, ln_book_order_wt NUMBER, ln_adl_score NUMBER, ln_adl_wt NUMBER, lc_prorate_score VARCHAR2
                              , lc_use_weight VARCHAR2)
        RETURN NUMBER
    IS
        ln_score   NUMBER := 0;
    BEGIN
        IF lc_prorate_score = 'Y'
        THEN
            LOG (
                p_module        => 'CALUCLATE_SCORE',
                p_line_number   => NULL,
                p_log_message   =>
                    ' caluclate_score  Pro-Rate profile is set to Yes');

            IF lc_use_weight = 'N'
            THEN
                IF ln_last_payment_score != 0 AND ln_adl_score = 0
                THEN
                    -- ln_last_payment_score is not zero
                    ln_score   :=
                          ln_aging_bucket_score * ln_aging_bucket_wt
                        + (((ln_aging_bucket_wt * ln_adl_wt) / (ln_aging_bucket_wt + ln_last_payment_wt + ln_book_order_wt)) * ln_aging_bucket_score)
                        + ln_last_payment_score * ln_last_payment_wt
                        + (((ln_last_payment_wt * ln_adl_wt) / (ln_aging_bucket_wt + ln_last_payment_wt + ln_book_order_wt)) * ln_last_payment_score)
                        + ln_book_order_score * ln_book_order_wt
                        + (((ln_book_order_wt * ln_adl_wt) / (ln_aging_bucket_wt + ln_last_payment_wt + ln_book_order_wt)) * ln_book_order_score);
                ELSIF ln_last_payment_score = 0 AND ln_adl_score != 0
                THEN
                    -- ln_adl_score is not zero

                    ln_score   :=
                          ln_aging_bucket_score * ln_aging_bucket_wt
                        + (((ln_aging_bucket_wt * ln_last_payment_wt) / (ln_aging_bucket_wt + ln_adl_wt + ln_book_order_wt)) * ln_aging_bucket_score)
                        + ln_book_order_score * ln_book_order_wt
                        + (((ln_book_order_wt * ln_last_payment_wt) / (ln_aging_bucket_wt + ln_adl_wt + ln_book_order_wt)) * ln_book_order_score)
                        + ln_adl_score * ln_adl_wt
                        + (((ln_adl_score * ln_last_payment_wt) / (ln_aging_bucket_wt + ln_adl_wt + ln_book_order_wt)) * ln_adl_score);
                ELSIF ln_last_payment_score = 0 AND ln_adl_score = 0
                THEN
                    -- ln_adl_score is zero and ln_last_payment_score is zero
                    ln_score   :=
                          ln_aging_bucket_score * ln_aging_bucket_wt
                        + ((ln_aging_bucket_wt * (ln_last_payment_wt + ln_adl_wt) / (ln_aging_bucket_wt + ln_book_order_wt)) * ln_aging_bucket_score)
                        + ln_book_order_score * ln_book_order_wt
                        + ((ln_book_order_wt * (ln_last_payment_wt + ln_adl_wt) / (ln_book_order_wt + ln_book_order_wt)) * ln_book_order_score);
                ELSE
                    -- Score when all the score are not null
                    ln_score   :=
                          ln_aging_bucket_score * ln_aging_bucket_wt
                        + ln_last_payment_score * ln_last_payment_wt
                        + ln_book_order_score * ln_book_order_wt
                        + ln_adl_score * ln_adl_wt;
                END IF;
            ELSE
                ln_score   :=
                      ln_aging_bucket_score * ln_aging_bucket_wt
                    + ln_last_payment_score * ln_last_payment_wt
                    + ln_book_order_score * ln_book_order_wt
                    + ln_adl_score * ln_adl_wt;
            END IF;
        ELSE
            LOG (
                p_module        => 'CALUCLATE_SCORE',
                p_line_number   => NULL,
                p_log_message   =>
                    ' caluclate_score  Pro-Rate profile is set to No');


            ln_score   :=
                  ln_aging_bucket_score * ln_aging_bucket_wt
                + ln_last_payment_score * ln_last_payment_wt
                + ln_book_order_score * ln_book_order_wt
                + ln_adl_score * ln_adl_wt;
        END IF;



        RETURN ROUND (ln_score, 2);
    --EXCEPTION
    -- WHEN OTHERS
    -- THEN
    --    gc_exception_flag := 'Y';
    --log (
    --    p_module =>        SQLERRM,
    --    p_line_number => DBMS_UTILITY.format_error_backtrace,
    --    p_log_message=>  'Error in get_mapped_score');

    --    ln_score := -1;
    --    RETURN ln_score;
    END caluclate_score;



    PROCEDURE LOG (p_log_message   IN VARCHAR2,
                   p_module        IN VARCHAR2,
                   p_line_number   IN NUMBER)
    IS
    BEGIN
        IF gc_log_profile_value = 'Y'
        THEN
            XXDO_GEH_PKG.record_error (gc_module, gn_cust_account_id, p_module, p_line_number, NULL, gn_user_id
                                       , p_log_message, TO_CHAR (gn_org_id));
        END IF;
    END LOG;

    FUNCTION GET_NON_WEIGHT_MAPPING_SCORE (P_CUST_ACCOUNT_ID   IN NUMBER,
                                           p_score                NUMBER)
        RETURN NUMBER
    IS
        ln_score   NUMBER := 0;
        lc_BRAND   VARCHAR2 (50);
    BEGIN
        LOG (p_module        => 'GET_NON_WEIGHT_MAPPING_SCORE',
             p_line_number   => NULL,
             p_log_message   => 'Start GET_NON_WEIGHT_MAPPING_SCORE ');

        LOG (
            p_module        => 'GET_NON_WEIGHT_MAPPING_SCORE',
            p_line_number   => NULL,
            p_log_message   =>
                   'GET_NON_WEIGHT_MAPPING_SCORE : '
                || p_score
                || ' Account : '
                || P_CUST_ACCOUNT_ID);

        SELECT attribute1
          INTO lc_BRAND
          FROM hz_cust_accounts
         WHERE cust_account_id = P_CUST_ACCOUNT_ID;


        LOG (
            p_module        => 'GET_NON_WEIGHT_MAPPING_SCORE',
            p_line_number   => NULL,
            p_log_message   =>
                ' GET_NON_WEIGHT_MAPPING_SCORE BRAND : ' || lc_BRAND);

        BEGIN
            SELECT ATTRIBUTE4 + 0
              INTO ln_score
              FROM fnd_flex_values ffv, fnd_flex_value_sets ffvs, hr_operating_units hou
             WHERE     ffv.flex_value_set_id = ffvs.flex_value_set_id
                   AND ffvs.FLEX_VALUE_SET_NAME LIKE
                           'XXDO_IEX_SCORE_MAPPINGS_VS'
                   AND ffv.attribute1 = lc_BRAND
                   AND ffv.attribute5 = hou.name
                   AND hou.organization_id = FND_PROFILE.VALUE ('ORG_ID')
                   AND p_score BETWEEN ffv.attribute2 + 0
                                   AND ffv.attribute3 + 0;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                RETURN 15;
        END;



        IF NVL (ln_score, 0) = 0
        THEN
            LOG (
                p_module        => 'GET_NON_WEIGHT_MAPPING_SCORE',
                p_line_number   => NULL,
                p_log_message   =>
                       ' GET_NON_WEIGHT_MAPPING_SCORE ln_score is Zero so setting to P_Score: '
                    || p_score);


            ln_score   := p_score;
        END IF;

        LOG (
            p_module        => 'GET_NON_WEIGHT_MAPPING_SCORE',
            p_line_number   => NULL,
            p_log_message   =>
                'End GET_NON_WEIGHT_MAPPING_SCORE : ' || ln_score);

        RETURN ln_score;
    /*EXCEPTION
       WHEN OTHERS
       THEN
          gc_exception_flag := 'Y';
      log (
          p_module =>     SQLERRM,
          p_line_number => DBMS_UTILITY.format_error_backtrace,
          p_log_message=>  'Error in get_mapped_score');


          ln_score := 0;
          RETURN ln_score;*/
    END get_non_weight_mapping_score;

    PROCEDURE POPULATE_ADL (p_errbuff OUT VARCHAR2, p_retcode OUT VARCHAR2, p_ou IN VARCHAR2, p_cust_account_from IN VARCHAR2, p_dummy IN VARCHAR2, p_cust_account_to IN VARCHAR2
                            , p_party_name_from IN VARCHAR2, p_dummy1 IN VARCHAR2, p_party_name_to IN VARCHAR2)
    IS
        ln_inv_count          NUMBER;
        l_run_date            DATE := TRUNC (SYSDATE);
        ld_first_pay_date     DATE;
        ln_adl                NUMBER;
        gc_insert_check       VARCHAR2 (1);

        CURSOR adl_quarters_c (p_quarter_start_date IN DATE)
        IS
            SELECT quarter_start_date, quarter_end_date, period_year,
                   quarter_num, adl, 'ADL' || (9 - ROWNUM) adl_num
              FROM (  SELECT DISTINCT quarter_start_date, (ADD_MONTHS (TRUNC (quarter_start_date, 'q'), 3) - 1) quarter_end_date, period_year,
                                      quarter_num, NULL adl
                        FROM gl_periods
                       WHERE     quarter_start_date BETWEEN ADD_MONTHS (
                                                                TRUNC (
                                                                    p_quarter_start_date,
                                                                    'q'),
                                                                -27)
                                                        AND ADD_MONTHS (
                                                                  TRUNC (
                                                                      p_quarter_start_date,
                                                                      'q')
                                                                - 1,
                                                                -3)
                             AND period_set_name = 'DO_CY_CALENDAR'
                    ORDER BY period_year ASC, quarter_num ASC);

        CURSOR open_inv_count_c (p_cust_acct_id IN NUMBER)
        IS
            SELECT COUNT (*)
              FROM ar_payment_schedules_all
             WHERE customer_id = p_cust_acct_id AND status = 'OP';


        CURSOR inv_count_c (p_start_date    IN DATE,
                            p_end_date      IN DATE,
                            p_cust_acc_id   IN NUMBER)
        IS
            SELECT NVL (COUNT (*), 0)
              FROM ar_payment_schedules_all apsa, ra_customer_trx_all rct, ra_cust_trx_types_all rctt -- Added for defect# 170 by BT Tech team on 21-Oct-15
             WHERE     rct.trx_date BETWEEN p_start_date AND p_end_date
                   -- Added below for defect# 170 by BT Tech team on 21-Oct-15
                   AND rctt.cust_trx_type_id = rct.cust_trx_type_id
                   AND rctt.org_id = rct.org_id
                   AND rctt.TYPE IN ('INV', 'CB', 'DM')
                   -- Added above for defect# 170 by BT Tech team on 21-Oct-15
                   AND apsa.status = 'CL'
                   -- AND apsa.actual_date_closed > apsa.due_date -- Commented as per CR# 110
                   AND rct.customer_trx_id = apsa.customer_trx_id
                   AND rct.bill_to_customer_id = p_cust_acc_id
                   AND rct.org_id = apsa.org_id
                   AND rct.org_id = p_ou;

        CURSOR get_attr_count (p_adl_num           IN VARCHAR2,
                               p_cust_account_id   IN NUMBER)
        IS
            SELECT DECODE (
                       p_adl_num,
                       'ADL1', SUBSTR (attribute10,
                                       1,
                                       INSTR (attribute10, '|', 1) - 1),
                       'ADL2', SUBSTR (attribute9,
                                       1,
                                       INSTR (attribute9, '|', 1) - 1),
                       'ADL3', SUBSTR (attribute8,
                                       1,
                                       INSTR (attribute8, '|', 1) - 1),
                       'ADL4', SUBSTR (attribute7,
                                       1,
                                       INSTR (attribute7, '|', 1) - 1),
                       'ADL5', SUBSTR (attribute6,
                                       1,
                                       INSTR (attribute6, '|', 1) - 1),
                       'ADL6', SUBSTR (attribute5,
                                       1,
                                       INSTR (attribute5, '|', 1) - 1),
                       'ADL7', SUBSTR (attribute4,
                                       1,
                                       INSTR (attribute4, '|', 1) - 1),
                       'ADL8', SUBSTR (attribute3,
                                       1,
                                       INSTR (attribute3, '|', 1) - 1),
                       SUBSTR (attribute11,
                               1,
                               INSTR (attribute11, '|', 1) - 1)) adl_count,
                   DECODE (p_adl_num,
                           'ADL1', SUBSTR (attribute10,
                                           INSTR (attribute10, '|', 1) + 1,
                                           DECODE (INSTR (attribute10, '|', 1
                                                          , 2),
                                                   0, LENGTH (attribute10),
                                                   (  INSTR (attribute10, '|', 1
                                                             , 2)
                                                    - INSTR (attribute10, '|', 1
                                                             , 1)
                                                    - 1))),
                           'ADL2', SUBSTR (attribute9,
                                           INSTR (attribute9, '|', 1) + 1,
                                           DECODE (INSTR (attribute9, '|', 1,
                                                          2),
                                                   0, LENGTH (attribute9),
                                                   (  INSTR (attribute9, '|', 1
                                                             , 2)
                                                    - INSTR (attribute9, '|', 1
                                                             , 1)
                                                    - 1))),
                           'ADL3', SUBSTR (attribute8,
                                           INSTR (attribute8, '|', 1) + 1,
                                           DECODE (INSTR (attribute8, '|', 1,
                                                          2),
                                                   0, LENGTH (attribute8),
                                                   (  INSTR (attribute8, '|', 1
                                                             , 2)
                                                    - INSTR (attribute8, '|', 1
                                                             , 1)
                                                    - 1))),
                           'ADL4', SUBSTR (attribute7,
                                           INSTR (attribute7, '|', 1) + 1,
                                           DECODE (INSTR (attribute7, '|', 1,
                                                          2),
                                                   0, LENGTH (attribute7),
                                                   (  INSTR (attribute7, '|', 1
                                                             , 2)
                                                    - INSTR (attribute7, '|', 1
                                                             , 1)
                                                    - 1))),
                           'ADL5', SUBSTR (attribute6,
                                           INSTR (attribute6, '|', 1) + 1,
                                           DECODE (INSTR (attribute6, '|', 1,
                                                          2),
                                                   0, LENGTH (attribute6),
                                                   (  INSTR (attribute6, '|', 1
                                                             , 2)
                                                    - INSTR (attribute6, '|', 1
                                                             , 1)
                                                    - 1))),
                           'ADL6', SUBSTR (attribute5,
                                           INSTR (attribute5, '|', 1) + 1,
                                           DECODE (INSTR (attribute5, '|', 1,
                                                          2),
                                                   0, LENGTH (attribute5),
                                                   (  INSTR (attribute5, '|', 1
                                                             , 2)
                                                    - INSTR (attribute5, '|', 1
                                                             , 1)
                                                    - 1))),
                           'ADL7', SUBSTR (attribute4,
                                           INSTR (attribute4, '|', 1) + 1,
                                           DECODE (INSTR (attribute4, '|', 1,
                                                          2),
                                                   0, LENGTH (attribute4),
                                                   (  INSTR (attribute4, '|', 1
                                                             , 2)
                                                    - INSTR (attribute4, '|', 1
                                                             , 1)
                                                    - 1))),
                           'ADL8', SUBSTR (attribute3,
                                           INSTR (attribute3, '|', 1) + 1,
                                           DECODE (INSTR (attribute3, '|', 1,
                                                          2),
                                                   0, LENGTH (attribute3),
                                                   (  INSTR (attribute3, '|', 1
                                                             , 2)
                                                    - INSTR (attribute3, '|', 1
                                                             , 1)
                                                    - 1))),
                           SUBSTR (attribute11,
                                   INSTR (attribute11, '|', 1) + 1,
                                   DECODE (INSTR (attribute11, '|', 1,
                                                  2),
                                           0, LENGTH (attribute11),
                                           (  INSTR (attribute11, '|', 1,
                                                     2)
                                            - INSTR (attribute11, '|', 1,
                                                     1)
                                            - 1)))) old_adl
              FROM xxd_iex_metrics_tbl
             WHERE cust_account_id = p_cust_account_id AND org_id = p_ou;

        CURSOR get_adl_c (p_inv_count     IN NUMBER,
                          p_start_date    IN DATE,
                          p_end_date      IN DATE,
                          p_cust_acc_id   IN NUMBER,
                          p_old_adl       IN NUMBER,
                          p_old_count     IN NUMBER)
        IS
            SELECT ROUND ((NVL (SUM (apsa.actual_date_closed - apsa.DUE_DATE) + (NVL (p_old_adl, 0) * NVL (p_old_count, 0)), 0) / (p_inv_count + NVL (p_old_count, 0))), 2) adl
              FROM ar_payment_schedules_all apsa, ra_customer_trx_all rct, ra_cust_trx_types_all rctt -- Added for defect# 170 by BT Tech team on 21-Oct-15
             WHERE     rct.trx_date BETWEEN p_start_date AND p_end_date
                   -- Added below for defect# 170 by BT Tech team on 21-Oct-15
                   AND rctt.cust_trx_type_id = rct.cust_trx_type_id
                   AND rctt.org_id = rct.org_id
                   AND rctt.TYPE IN ('INV', 'CB', 'DM')
                   -- Added above for defect# 170 by BT Tech team on 21-Oct-15
                   AND apsa.status = 'CL'
                   -- AND apsa.actual_date_closed > apsa.due_date -- Commented as per CR# 100
                   AND rct.customer_trx_id = apsa.customer_trx_id
                   AND rct.bill_to_customer_id = p_cust_acc_id
                   AND rct.org_id = apsa.org_id
                   AND rct.org_id = p_ou;

        CURSOR insert_update_c (p_cust_acc_id IN NUMBER)
        IS
            SELECT DECODE (COUNT (*), 0, 'Y', 'N')
              FROM xxd_iex_metrics_tbl
             WHERE cust_account_id = p_cust_acc_id AND org_id = p_ou;

        CURSOR get_view_name_c IS
            SELECT flvv.attribute1
              FROM hr_all_organization_units haou, fnd_lookup_values_vl flvv
             WHERE     flvv.meaning = haou.name
                   AND lookup_type = 'XXDO_ADL_OU_TO_ACCT_MAP_LKP'
                   AND organization_id = p_ou;

        TYPE t_adl_quarters_rec IS TABLE OF adl_quarters_c%ROWTYPE
            INDEX BY PLS_INTEGER;

        l_adl_quarters_rec    t_adl_quarters_rec;

        TYPE cust_acc_rec IS RECORD
        (
            cust_account_id    NUMBER,
            attribute1         hz_cust_accounts_all.attribute1%TYPE
        );                                                 -- Modified for 1.4

        TYPE t_cust_acc_data_rec IS TABLE OF cust_acc_rec
            INDEX BY PLS_INTEGER;

        l_cust_acc_data_rec   t_cust_acc_data_rec;


        lc_query              VARCHAR2 (32760);
        l_quarter_det         adl_quarters_c%ROWTYPE;
        ln_curr_inv_count     NUMBER;
        ln_curr_adl           NUMBER;
        lc_filter_view        VARCHAR2 (50);
        lc_cur                SYS_REFCURSOR;
        lc_curr_adl_data      VARCHAR2 (1);
        lc_prev_adl_data      VARCHAR2 (1);
        ln_adl_count          NUMBER;
        ln_old_adl            NUMBER;
        ln_open_inv_count     NUMBER;
    BEGIN
        BEGIN
            mo_global.set_policy_context ('S', P_OU);
            mo_global.init ('IEX');
        END;

        FND_FILE.PUT_LINE (FND_FILE.LOG, 'P_OU:' || P_OU);

        IF    (p_cust_account_from IS NOT NULL AND p_cust_account_to IS NULL)
           OR (p_cust_account_from IS NULL AND p_cust_account_to IS NOT NULL)
        THEN
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                'Both Account number from and Account number to needs to be enetered');
            RETURN;
        END IF;

        IF    (p_party_name_from IS NOT NULL AND p_party_name_to IS NULL)
           OR (p_party_name_from IS NULL AND p_party_name_to IS NOT NULL)
        THEN
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                'Both Party Name from and Party Name to needs to be enetered');
            RETURN;
        END IF;

        IF (TRUNC (l_run_date) = TRUNC (l_run_date, 'q'))
        THEN
            UPDATE xxd_iex_metrics_tbl
               SET attribute10 = attribute11, attribute9 = attribute10, attribute8 = attribute9,
                   attribute7 = attribute8, attribute6 = attribute7, attribute5 = attribute6,
                   attribute4 = attribute5, attribute3 = attribute4, attribute11 = NULL,
                   last_update_date = SYSDATE, last_updated_by = FND_GLOBAL.USER_ID;

            COMMIT;                                           -- Added for 1.4
        END IF;

        ld_first_pay_date   := NULL;
        ln_inv_count        := 0;
        ln_adl              := NULL;
        gc_insert_check     := NULL;
        lc_curr_adl_data    := 'N';
        lc_prev_adl_data    := 'N';

        gn_adl_rolling_days   :=
            IEX_UTILITIES.GET_LOOKUP_MEANING (
                'XXDO_IEX_SCORING_GLOBAL_VALUES',
                'ADL_ROLLING_DAYS');

        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'gn_adl_rolling_days:' || gn_adl_rolling_days);

        OPEN get_view_name_c;

        FETCH get_view_name_c INTO lc_filter_view;

        CLOSE get_view_name_c;

        FND_FILE.PUT_LINE (FND_FILE.LOG, 'lc_filter_view:' || lc_filter_view);

        -- lc_query modified to include attribute1 for 1.4
        lc_query            :=
               ' SELECT hcaa.cust_account_id , hcaa.attribute1
                    FROM hz_cust_accounts_all hcaa,
                         hz_parties hp
                   WHERE hp.party_id  = hcaa.party_id
                     AND account_number BETWEEN NVL('''
            || p_cust_account_from
            || ''',account_number) AND NVL('''
            || p_cust_account_to
            || ''',account_number)
                     AND party_name BETWEEN NVL('''
            || p_party_name_from
            || ''',party_name) AND NVL('''
            || p_party_name_to
            || ''',party_name)
                     AND EXISTS (SELECT 1 
                                   FROM '
            || lc_filter_view
            || '
                                  WHERE cust_account_id = hcaa.cust_account_id)
                     AND (EXISTS (SELECT 1
                                   FROM ar_payment_schedules_all
                                  WHERE customer_id = hcaa.cust_account_id
                                    AND actual_date_closed BETWEEN TRUNC(SYSDATE-1) AND TRUNC(SYSDATE))
                           OR (TRUNC(SYSDATE) = TRUNC(SYSDATE,''q'')))';

        FND_FILE.PUT_LINE (FND_FILE.LOG, 'lc_query:' || lc_query);

        OPEN lc_cur FOR lc_query;

        LOOP
            FETCH lc_cur BULK COLLECT INTO l_cust_acc_data_rec LIMIT 1000;

            fnd_file.put_line (
                fnd_file.LOG,
                'l_cust_acc_data_rec.COUNT  ' || l_cust_acc_data_rec.COUNT);

            IF l_cust_acc_data_rec.COUNT > 0
            THEN
                FND_FILE.PUT_LINE (FND_FILE.LOG,
                                   'inside l_cust_acc_data_rec.COUNT >0');

                FOR j IN 1 .. l_cust_acc_data_rec.COUNT
                LOOP
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                           'Processing For Cust Account ID:'
                        || l_cust_acc_data_rec (j).cust_account_id
                        || ' and Brand: '
                        || l_cust_acc_data_rec (j).attribute1); -- Added for 1.4

                    gc_insert_check     := NULL;
                    ln_open_inv_count   := 0;

                    OPEN insert_update_c (
                        l_cust_acc_data_rec (j).cust_account_id);

                    FETCH insert_update_c INTO gc_insert_check;

                    CLOSE insert_update_c;

                    FND_FILE.PUT_LINE (FND_FILE.LOG,
                                       'gc_insert_check:' || gc_insert_check);

                    ln_curr_adl         := NULL;
                    ln_curr_inv_count   := 0;
                    ld_first_pay_date   := NULL;
                    ln_inv_count        := 0;
                    ln_adl              := NULL;
                    lc_curr_adl_data    := 'N';
                    lc_prev_adl_data    := 'N';
                    ln_adl_count        := 0;
                    ln_old_adl          := 0;

                    OPEN get_attr_count (
                        NULL,
                        l_cust_acc_data_rec (j).cust_account_id);

                    FETCH get_attr_count INTO ln_adl_count, ln_old_adl;

                    CLOSE get_attr_count;

                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                           'ln_adl_count,ln_old_adl:'
                        || ln_adl_count
                        || ','
                        || ln_old_adl);

                    OPEN inv_count_c (
                        TRUNC (l_run_date - gn_adl_rolling_days),
                        TRUNC (l_run_date),
                        l_cust_acc_data_rec (j).cust_account_id);

                    FETCH inv_count_c INTO ln_curr_inv_count;

                    CLOSE inv_count_c;

                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                        'ln_curr_inv_count:' || ln_curr_inv_count);

                    IF ln_curr_inv_count > 0
                    THEN
                        OPEN get_adl_c (
                            ln_curr_inv_count,
                            TRUNC (l_run_date - gn_adl_rolling_days),
                            TRUNC (l_run_date),
                            l_cust_acc_data_rec (j).cust_account_id,
                            ln_old_adl,
                            ln_adl_count);

                        FETCH get_adl_c INTO ln_curr_adl;

                        CLOSE get_adl_c;

                        FND_FILE.PUT_LINE (FND_FILE.LOG,
                                           'ln_curr_adl:' || ln_curr_adl);

                        IF ln_curr_adl IS NOT NULL
                        THEN
                            lc_curr_adl_data   := 'Y';
                        END IF;
                    END IF;


                    OPEN adl_quarters_c (l_run_date);

                    FETCH adl_quarters_c BULK COLLECT INTO l_adl_quarters_rec;

                    CLOSE adl_quarters_c;

                    FOR i IN 1 .. l_adl_quarters_rec.COUNT
                    LOOP
                        l_quarter_det   := NULL;
                        ln_inv_count    := 0;
                        ln_adl          := NULL;
                        ln_adl_count    := 0;
                        ln_old_adl      := 0;

                        OPEN get_attr_count (
                            l_adl_quarters_rec (i).adl_num,
                            l_cust_acc_data_rec (j).cust_account_id);

                        FETCH get_attr_count INTO ln_adl_count, ln_old_adl;

                        CLOSE get_attr_count;

                        FND_FILE.PUT_LINE (
                            FND_FILE.LOG,
                               'Prev ADL Quarter:'
                            || l_adl_quarters_rec (i).adl_num
                            || ' ln_adl_count:'
                            || ln_adl_count
                            || ' ln_old_adl:'
                            || ln_old_adl);                   -- Added for 1.4

                        OPEN inv_count_c (
                            l_adl_quarters_rec (i).quarter_start_date,
                            l_adl_quarters_rec (i).quarter_end_date,
                            l_cust_acc_data_rec (j).cust_account_id);

                        FETCH inv_count_c INTO ln_inv_count;

                        CLOSE inv_count_c;

                        FND_FILE.PUT_LINE (
                            FND_FILE.LOG,
                               'Prev ADL Quarter:'
                            || l_adl_quarters_rec (i).adl_num
                            || ' ln_inv_count:'
                            || ln_inv_count);                 -- Added for 1.4

                        IF     ln_inv_count > 0
                           AND ((NVL (ln_adl_count, 0) > 0) OR (gc_insert_check = 'Y') OR (TRUNC (l_run_date) = TRUNC (l_run_date, 'q')))
                        THEN
                            OPEN get_adl_c (
                                ln_inv_count,
                                l_adl_quarters_rec (i).quarter_start_date,
                                l_adl_quarters_rec (i).quarter_end_date,
                                l_cust_acc_data_rec (j).cust_account_id,
                                ln_old_adl,
                                ln_adl_count);

                            FETCH get_adl_c INTO ln_adl;

                            CLOSE get_adl_c;

                            l_adl_quarters_rec (i).adl   := ln_adl;

                            FND_FILE.PUT_LINE (
                                FND_FILE.LOG,
                                   'Prev ADL Quarter:'
                                || l_adl_quarters_rec (i).adl_num
                                || ' ln_adl:'
                                || ln_adl);                   -- Added for 1.4

                            IF ln_adl IS NOT NULL
                            THEN
                                lc_prev_adl_data   := 'Y';
                            END IF;
                        END IF;
                    END LOOP;

                    IF lc_prev_adl_data = 'Y'
                    THEN
                        FND_FILE.PUT_LINE (
                            FND_FILE.LOG,
                            'Inserting/Updating Prev Quarter ADL Data'); -- Added for 1.4

                        INSERT_UPDATE (
                            p_insert_update_flag   => gc_insert_check,
                            p_cust_account_id      =>
                                l_cust_acc_data_rec (j).cust_account_id,
                            p_org_id               => p_ou,
                            p_adl_q1               =>
                                l_adl_quarters_rec (8).adl,
                            p_adl_q2               =>
                                l_adl_quarters_rec (7).adl,
                            p_adl_q3               =>
                                l_adl_quarters_rec (6).adl,
                            p_adl_q4               =>
                                l_adl_quarters_rec (5).adl,
                            p_adl_q5               =>
                                l_adl_quarters_rec (4).adl,
                            p_adl_q6               =>
                                l_adl_quarters_rec (3).adl,
                            p_adl_q7               =>
                                l_adl_quarters_rec (2).adl,
                            p_adl_q8               =>
                                l_adl_quarters_rec (1).adl,
                            p_curr_adl             => ln_curr_adl,
                            p_attribute1           =>
                                l_cust_acc_data_rec (j).attribute1); -- Added for 1.4
                    END IF;

                    IF lc_curr_adl_data = 'Y'
                    THEN
                        FND_FILE.PUT_LINE (FND_FILE.LOG,
                                           'Inserting/Updating Current ADL'); -- Added for 1.4

                        INSERT_UPDATE (
                            p_insert_update_flag   => gc_insert_check,
                            p_cust_account_id      =>
                                l_cust_acc_data_rec (j).cust_account_id,
                            p_org_id               => p_ou,
                            p_curr_adl             => ln_curr_adl,
                            p_attribute1           =>
                                l_cust_acc_data_rec (j).attribute1); -- Added for 1.4
                    END IF;

                    OPEN open_inv_count_c (
                        l_cust_acc_data_rec (j).cust_account_id);

                    FETCH open_inv_count_c INTO ln_open_inv_count;

                    CLOSE open_inv_count_c;

                    IF NVL (ln_open_inv_count, 0) = 0
                    THEN
                        UPDATE xxd_iex_metrics_tbl
                           SET attribute10 = NULL, attribute9 = NULL, attribute8 = NULL,
                               attribute7 = NULL, attribute6 = NULL, attribute5 = NULL,
                               attribute4 = NULL, attribute3 = NULL, attribute11 = NULL,
                               last_update_date = SYSDATE, last_updated_by = FND_GLOBAL.USER_ID
                         WHERE cust_account_id =
                               l_cust_acc_data_rec (j).cust_account_id;
                    END IF;
                END LOOP;

                COMMIT;                                       -- Added for 1.4
            END IF;

            EXIT WHEN l_cust_acc_data_rec.COUNT = 0;
        END LOOP;

        CLOSE lc_cur;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_retcode   := 2;
            p_errbuff   := 'Exception at POPULATE_ADL' || SQLERRM;
            FND_FILE.PUT_LINE (FND_FILE.LOG, p_errbuff);
    END POPULATE_ADL;

    FUNCTION SCORE_DIST (p_cust_account_id      IN NUMBER,
                         p_score_component_id   IN NUMBER)
        RETURN NUMBER
    IS
        CURSOR get_max_aging_c IS
            SELECT NVL (MAX (abl.Bucket_Sequence_num), 0)
              FROM ar_aging_buckets ab, ar_aging_bucket_lines abl, ar_payment_schedules_all arp,
                   iex_delinquencies_all del
             WHERE     abl.aging_bucket_id = ab.aging_bucket_id
                   AND ab.bucket_name = gc_deckers_bucket_name
                   AND del.payment_schedule_id = arp.payment_schedule_id
                   AND del.org_id = gn_org_id
                   AND del.status = ('DELINQUENT')
                   AND arp.status = 'OP'
                   AND del.cust_account_id = p_cust_account_id
                   AND (TRUNC (SYSDATE) - TRUNC (arp.due_date)) BETWEEN abl.days_start
                                                                    AND abl.days_to;


        CURSOR insert_update_c (p_cust_acc_id IN NUMBER)
        IS
            SELECT DECODE (COUNT (*), 0, 'Y', 'N')
              FROM xxd_iex_metrics_tbl
             WHERE cust_account_id = p_cust_acc_id AND org_id = gn_org_id;

        ln_aging_bucket   NUMBER;
        ln_score          NUMBER;
    BEGIN
        SET_ORG_ID;

        -- ln_score        := gn_dist_low_cutoff_score;
        gc_insert_check   := NULL;

        OPEN get_max_aging_c;

        FETCH get_max_aging_c INTO ln_aging_bucket;

        CLOSE get_max_aging_c;

        ln_score          := ln_aging_bucket;

        /*   IF ln_aging_bucket IN (0,1,2) THEN
             ln_score := gn_dist_low_cutoff_score;
           ELSE
             ln_score := gn_dist_high_cutoff_score;
           END IF;
           */
        OPEN insert_update_c (p_cust_account_id);

        FETCH insert_update_c INTO gc_insert_check;

        CLOSE insert_update_c;

        IF gc_insert_check = 'Y'
        THEN
            INSERT_UPDATE (p_insert_update_flag   => 'Y',
                           p_aging_bucket_score   => ln_score,
                           p_score                => ln_score,
                           p_cust_account_id      => p_cust_account_id,
                           p_org_id               => gn_org_id);
        ELSE
            INSERT_UPDATE (p_insert_update_flag   => 'N',
                           p_aging_bucket_score   => ln_score,
                           p_score                => ln_score,
                           p_cust_account_id      => p_cust_account_id,
                           p_org_id               => gn_org_id);
        END IF;

        RETURN ln_score;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END SCORE_DIST;

    -- Start of Changes for CCR0007180

    /*******************************************************************************
      * Funtion Name : score_japan
      * Description  : This Function will generate and return the final mapped score
      *                for a given cust_account_id
      * Parameters   :P_CUST_ACCOUNT_ID
                     :P_SCORE_COMPONENT_ID
      * --------------------------------------------------------------------------- */

    FUNCTION score_japan (P_CUST_ACCOUNT_ID      IN NUMBER,
                          P_SCORE_COMPONENT_ID   IN NUMBER)
        RETURN NUMBER
    IS
        ln_score                 NUMBER := 0;
        ln_aging_bucket_score    NUMBER := 0;
        ln_aging_bucket_wt       NUMBER := 0;
        ln_last_payment_score    NUMBER := 0;
        ln_last_payment_wt       NUMBER := 0;
        ln_book_order_score      NUMBER := 0;
        ln_book_order_wt         NUMBER := 0;
        ln_adl_score             NUMBER := 0;
        ln_adl_wt                NUMBER := 0;
        lc_prorate_score         VARCHAR2 (1);
        ln_mapped_score          NUMBER := 0;
        lc_use_weight            VARCHAR2 (1);
        -- Start of Changes for CCR0007180
        ln_aging_bucket_wt_new   NUMBER := 0;
        ln_last_payment_wt_new   NUMBER := 0;
        ln_book_order_wt_new     NUMBER := 0;
        ln_adl_wt_new            NUMBER := 0;

        -- End of Changes for CCR0007180

        CURSOR insert_update_c (p_cust_acc_id IN NUMBER)
        IS
            SELECT DECODE (COUNT (*), 0, 'Y', 'N')
              FROM xxd_iex_metrics_tbl
             WHERE cust_account_id = p_cust_acc_id AND org_id = gn_org_id;
    BEGIN
        SET_ORG_ID;

        --xxv_debug_prc('Flow Started - Test Japan');

        gn_cust_account_id       := P_CUST_ACCOUNT_ID;
        gc_log_profile_value     :=
            NVL (apps.fnd_profile.VALUE ('XXDO_GEH_LOG_ENABLE'), 'N');
        gc_exception_flag        := 'N';

        LOG (
            p_module        => 'score_japan',
            p_line_number   => NULL,
            p_log_message   =>
                ' Start Scoring for Account : ' || P_CUST_ACCOUNT_ID);

        ln_aging_bucket_score    :=
            get_aging_bucket_avg_score_jp (P_CUST_ACCOUNT_ID);

        LOG (
            p_module        => 'score_japan',
            p_line_number   => NULL,
            p_log_message   =>
                   ' score_japan  Aging Bucket Score : '
                || ln_aging_bucket_score);



        LOG (
            p_module        => 'score_japan',
            p_line_number   => NULL,
            p_log_message   =>
                ' score_japan  Aging Bucket  : ' || v_aging_bucket);


        LOG (
            p_module        => 'score_japan',
            p_line_number   => NULL,
            p_log_message   =>
                   ' score_japan  Global Default Aging Bucket  : '
                || gc_default_aging_bucket);
        lc_use_weight            :=
            NVL (apps.fnd_profile.VALUE ('XXDO_IEX_USE_WEIGHT'), 'N');

        -- Start of Changes for CCR0007180
        ln_aging_bucket_wt_new   := get_Weight (gc_score_component1); --'AGING_WATERFALL'
        ln_last_payment_wt_new   := get_Weight (gc_risk_component1); --'LAST_PAYMENT'
        ln_book_order_wt_new     := get_Weight (gc_risk_component2); --'BOOKED_ORDERS'
        ln_adl_wt_new            := get_Weight (gc_risk_component3); --'ADL_TREND'
        -- End of Changes for CCR0007180

        LOG (p_module        => 'score_japan',
             p_line_number   => NULL,
             p_log_message   => 'lc_use_weight : ' || lc_use_weight);

        IF lc_use_weight <> 'N'
        THEN
            IF v_aging_bucket <> gc_default_aging_bucket
            THEN
                LOG (
                    p_module        => 'score_japan',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' score_japan  Aging Bucket is not  Global Default Aging Bucket');



                ln_last_payment_score   :=
                    get_last_payment_score (P_CUST_ACCOUNT_ID);

                LOG (
                    p_module        => 'score_japan',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' score_japan  Last Payment Score : '
                        || ln_last_payment_score);



                ln_book_order_score   :=
                    get_booked_order_score (P_CUST_ACCOUNT_ID);

                LOG (
                    p_module        => 'score_japan',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' score_japan  Booked Order Score : '
                        || ln_book_order_score);


                ln_adl_score         := get_adl_score (P_CUST_ACCOUNT_ID);

                LOG (
                    p_module        => 'score_japan',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' score_japan  ADL Score : ' || ln_adl_score);


                ln_aging_bucket_wt   := get_Weight (gc_score_component1); --'AGING_WATERFALL'

                LOG (
                    p_module        => 'score_japan',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' score_japan  Aging Bucket Wt : '
                        || ln_aging_bucket_wt);



                ln_last_payment_wt   := get_Weight (gc_risk_component1); --'LAST_PAYMENT'
                LOG (
                    p_module        => 'score_japan',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' score_japan  Last Payment Wt : '
                        || ln_last_payment_wt);



                ln_book_order_wt     := get_Weight (gc_risk_component2); --'BOOKED_ORDERS'

                LOG (
                    p_module        => 'score_japan',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' score_japan  Booked Order Wt : '
                        || ln_book_order_wt);


                ln_adl_wt            := get_Weight (gc_risk_component3); --'ADL_TREND'
                LOG (
                    p_module        => 'score_japan',
                    p_line_number   => NULL,
                    p_log_message   => ' score_japan  ADL Wt : ' || ln_adl_wt);


                lc_prorate_score     :=
                    NVL (apps.fnd_profile.VALUE ('XXDO_IEX_PRORATE_SCORE'),
                         'N');

                LOG (
                    p_module        => 'score_japan',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' score_japan  Pro-Rate profile : '
                        || lc_prorate_score);



                ln_score             :=
                    caluclate_score (ln_aging_bucket_score, ln_aging_bucket_wt, ln_last_payment_score, ln_last_payment_wt, ln_book_order_score, ln_book_order_wt, ln_adl_score, ln_adl_wt, lc_prorate_score
                                     , lc_use_weight); -- Addded for CCR0007810);
            ELSE
                LOG (
                    p_module        => 'score_japan',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' score_japan  Only Aging Bucket default score is considered if amount due remaining is 0');


                ln_score   := ln_aging_bucket_score;
            END IF;

            LOG (
                p_module        => 'score_japan',
                p_line_number   => NULL,
                p_log_message   =>
                    ' score_japan Score : ' || ln_aging_bucket_score);

            /* Start of changes for CCR0007180 */
            ln_mapped_score   :=
                get_non_weight_mapping_score (P_CUST_ACCOUNT_ID, ln_score);
            /* End of changes for CCR0007180 */

            --ln_mapped_score := get_mapped_score (ln_score, v_aging_bucket);
            LOG (
                p_module        => 'score_japan',
                p_line_number   => NULL,
                p_log_message   =>
                    ' score_japan Mapped Score : ' || ln_mapped_score);
        ELSE
            LOG (
                p_module        => 'score_japan',
                p_line_number   => NULL,
                p_log_message   =>
                    ' When XXDO" Use Weights profile is set to no');

            ln_last_payment_score   :=
                get_last_payment_score (P_CUST_ACCOUNT_ID);

            LOG (
                p_module        => 'score_japan',
                p_line_number   => NULL,
                p_log_message   =>
                       ' score_japan  Last Payment Score : '
                    || ln_last_payment_score);



            ln_book_order_score   :=
                get_booked_order_score (P_CUST_ACCOUNT_ID);

            LOG (
                p_module        => 'score_japan',
                p_line_number   => NULL,
                p_log_message   =>
                       ' score_japan  Booked Order Score : '
                    || ln_book_order_score);



            ln_adl_score   := get_adl_score (P_CUST_ACCOUNT_ID);

            LOG (
                p_module        => 'score_japan',
                p_line_number   => NULL,
                p_log_message   =>
                    ' score_japan  ADL Score : ' || ln_adl_score);

            ln_score       :=
                  NVL (ln_aging_bucket_score, 0)
                --    + NVL (ln_aging_bucket_wt, 0)
                + NVL (ln_last_payment_score, 0)
                --    + NVL (ln_last_payment_wt, 0)
                + NVL (ln_adl_score, 0)
                + NVL (ln_book_order_score, 0);

            LOG (p_module        => 'score_japan',
                 p_line_number   => NULL,
                 p_log_message   => ' score_japan  Score : ' || ln_score);

            ln_mapped_score   :=
                get_non_weight_mapping_score (P_CUST_ACCOUNT_ID, ln_score);

            LOG (
                p_module        => 'score_japan',
                p_line_number   => NULL,
                p_log_message   =>
                    ' score_japan Mapped Score : ' || ln_mapped_score);
        END IF;

        LOG (
            p_module        => 'score_japan',
            p_line_number   => NULL,
            p_log_message   =>
                   ' score_japan before Updating HZ_CUST_ACCOUNTS  : '
                || P_CUST_ACCOUNT_ID);

        OPEN insert_update_c (p_cust_account_id);

        FETCH insert_update_c INTO gc_insert_check;

        CLOSE insert_update_c;

        LOG (p_module        => 'score_japan',
             p_line_number   => NULL,
             p_log_message   => ' iNSERT fLAG : ' || gc_insert_check);

        IF NVL (gc_insert_check, 'Y') = 'Y'
        THEN
            -- Start of changes for CCR0007180
            IF lc_use_weight <> 'N'
            THEN
                LOG (
                    p_module        => 'score_japan',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' BEFORE INSERT using weighted score: '
                        || P_CUST_ACCOUNT_ID);
                INSERT_UPDATE (p_insert_update_flag => 'Y', p_aging_bucket_score => ln_aging_bucket_score * ln_aging_bucket_wt_new, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score * ln_book_order_wt_new, p_last_payment_score => ln_last_payment_score * ln_last_payment_wt_new, p_adl_score => ln_adl_score * ln_adl_wt_new, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);

                LOG (
                    p_module        => 'score_japan',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' AFTER INSERT using weighted score: '
                        || gc_insert_check);
            -- End of changes for CCR0007180
            ELSE
                LOG (
                    p_module        => 'score_japan',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' bEFORE INSERT : ' || P_CUST_ACCOUNT_ID);
                INSERT_UPDATE (p_insert_update_flag => 'Y', p_aging_bucket_score => ln_aging_bucket_score, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score, p_last_payment_score => ln_last_payment_score, p_adl_score => ln_adl_score, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);

                LOG (p_module        => 'score_japan',
                     p_line_number   => NULL,
                     p_log_message   => ' aFTER INSERT : ' || gc_insert_check);
            END IF;
        ELSE
            -- Start of changes for CCR0007180
            IF lc_use_weight <> 'N'
            THEN
                INSERT_UPDATE (p_insert_update_flag => 'N', p_aging_bucket_score => ln_aging_bucket_score * ln_aging_bucket_wt_new, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score * ln_book_order_wt_new, p_last_payment_score => ln_last_payment_score * ln_last_payment_wt_new, p_adl_score => ln_adl_score * ln_adl_wt_new, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);
            -- End of changes for CCR0007180
            ELSE
                INSERT_UPDATE (p_insert_update_flag => 'N', p_aging_bucket_score => ln_aging_bucket_score, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score, p_last_payment_score => ln_last_payment_score, p_adl_score => ln_adl_score, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);
            END IF;
        END IF;

        LOG (
            p_module        => 'score_japan',
            p_line_number   => NULL,
            p_log_message   =>
                   ' score_japan after Updating HZ_CUST_ACCOUNTS  : '
                || P_CUST_ACCOUNT_ID);


        LOG (
            p_module        => 'score_japan',
            p_line_number   => NULL,
            p_log_message   =>
                ' End Scoring for Account : ' || P_CUST_ACCOUNT_ID);


        RETURN ROUND (ln_mapped_score);
    EXCEPTION
        WHEN OTHERS
        THEN
            gc_exception_flag   := 'Y';
            LOG (
                p_module        => 'score_japan',
                p_line_number   => NULL,
                p_log_message   =>
                       ' score_japan  Booked Order Score : '
                    || ln_book_order_score);

            XXDO_GEH_PKG.record_error (
                gc_module,
                P_CUST_ACCOUNT_ID,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                gn_user_id,
                'Code pointer : ' || 'Error in score_japan',
                'Deckers Customer Account Scoring Program ',
                (gn_org_id));
            ln_mapped_score     := -1;
            RETURN ln_mapped_score;
    END score_japan;

    -- End of Changes for CCR0007180



    -- Commented score_japan function to mimic this function similar to score_us as part of CCR0007180

    /*FUNCTION SCORE_JAPAN (p_cust_account_id      IN NUMBER,
                          p_score_component_id   IN NUMBER)
         RETURN NUMBER
      IS

      CURSOR get_max_aging_c IS
     SELECT NVL(MAX(abl.Bucket_Sequence_num),0)
      FROM ar_aging_buckets ab,
           ar_aging_bucket_lines abl,
           ar_payment_schedules_all arp,
           iex_delinquencies_all del
     WHERE abl.aging_bucket_id     = ab.aging_bucket_id
       AND ab.bucket_name          = gc_deckers_bucket_name
       AND del.payment_schedule_id = arp.payment_schedule_id
       AND del.org_id              = gn_org_id
       AND del.status              = ('DELINQUENT')
       AND arp.status              = 'OP'
       AND del.cust_account_id     = p_cust_account_id
       AND (TRUNC(SYSDATE) - TRUNC(arp.due_date)) BETWEEN abl.days_start AND abl.days_to;

       CURSOR insert_update_c(p_cust_acc_id IN NUMBER) IS
       SELECT DECODE(COUNT(*),0,'Y','N')
         FROM xxd_iex_metrics_tbl
        WHERE cust_account_id = p_cust_acc_id
          AND org_id          = gn_org_id;

      ln_aging_bucket NUMBER;
      ln_score        NUMBER;

     BEGIN
       gc_insert_check := NULL;

         SET_ORG_ID;

      -- ln_score := gn_jpn_low_score;

       OPEN get_max_aging_c;
       FETCH get_max_aging_c INTO ln_aging_bucket;
       CLOSE get_max_aging_c;

        ln_score := ln_aging_bucket;

      --   IF ln_aging_bucket IN (0,1,2) THEN
      --   ln_score := gn_jpn_low_score;
      -- ELSIF ln_aging_bucket = 3 THEN
      --   ln_score := gn_jpn_mod_score;
      -- ELSIF ln_aging_bucket = 4 THEN
      --   ln_score := gn_jpn_hard1_score;
      -- ELSIF ln_aging_bucket IN (5,6) THEN
      --   ln_score := gn_jpn_hard2_score;
      -- END IF;

       OPEN insert_update_c(p_cust_account_id);
       FETCH insert_update_c INTO gc_insert_check;
       CLOSE insert_update_c;

       IF gc_insert_check = 'Y' THEN
         INSERT_UPDATE (  p_insert_update_flag => 'Y',
                          p_aging_bucket_score => ln_score,
                          p_score              => ln_score,
                          p_cust_account_id    => p_cust_account_id,
                          p_org_id             => gn_org_id);
       ELSE
         INSERT_UPDATE (  p_insert_update_flag => 'N',
                          p_aging_bucket_score => ln_score,
                          p_score              => ln_score,
                          p_cust_account_id    => p_cust_account_id,
                          p_org_id             => gn_org_id);
       END IF;

       RETURN ln_score;
     EXCEPTION WHEN OTHERS THEN
      RETURN 0;
     END SCORE_JAPAN; */

    -- Start of change for CCR0009817
    FUNCTION score_apac_wholesale (P_CUST_ACCOUNT_ID      IN NUMBER,
                                   P_SCORE_COMPONENT_ID   IN NUMBER)
        RETURN NUMBER
    IS
        ln_score                 NUMBER := 0;
        ln_aging_bucket_score    NUMBER := 0;
        ln_aging_bucket_wt       NUMBER := 0;
        ln_last_payment_score    NUMBER := 0;
        ln_last_payment_wt       NUMBER := 0;
        ln_book_order_score      NUMBER := 0;
        ln_book_order_wt         NUMBER := 0;
        ln_adl_score             NUMBER := 0;
        ln_adl_wt                NUMBER := 0;
        lc_prorate_score         VARCHAR2 (1);
        ln_mapped_score          NUMBER := 0;
        lc_use_weight            VARCHAR2 (1);
        -- Start of Changes for CCR0007180
        ln_aging_bucket_wt_new   NUMBER := 0;
        ln_last_payment_wt_new   NUMBER := 0;
        ln_book_order_wt_new     NUMBER := 0;
        ln_adl_wt_new            NUMBER := 0;

        -- End of Changes for CCR0007180

        CURSOR insert_update_c (p_cust_acc_id IN NUMBER)
        IS
            SELECT DECODE (COUNT (*), 0, 'Y', 'N')
              FROM xxd_iex_metrics_tbl
             WHERE cust_account_id = p_cust_acc_id AND org_id = gn_org_id;
    BEGIN
        SET_ORG_ID;

        --xxv_debug_prc('Flow Started - Test Japan');

        gn_cust_account_id       := P_CUST_ACCOUNT_ID;
        gc_log_profile_value     :=
            NVL (apps.fnd_profile.VALUE ('XXDO_GEH_LOG_ENABLE'), 'N');
        gc_exception_flag        := 'N';

        LOG (
            p_module        => 'score_apac_wholesale',
            p_line_number   => NULL,
            p_log_message   =>
                ' Start Scoring for Account : ' || P_CUST_ACCOUNT_ID);

        ln_aging_bucket_score    :=
            get_aging_bucket_avg_score_jp (P_CUST_ACCOUNT_ID);

        LOG (
            p_module        => 'score_apac_wholesale',
            p_line_number   => NULL,
            p_log_message   =>
                   ' score_apac_wholesale  Aging Bucket Score : '
                || ln_aging_bucket_score);



        LOG (
            p_module        => 'score_apac_wholesale',
            p_line_number   => NULL,
            p_log_message   =>
                ' score_apac_wholesale  Aging Bucket  : ' || v_aging_bucket);


        LOG (
            p_module        => 'score_apac_wholesale',
            p_line_number   => NULL,
            p_log_message   =>
                   ' score_apac_wholesale  Global Default Aging Bucket  : '
                || gc_default_aging_bucket);
        lc_use_weight            :=
            NVL (apps.fnd_profile.VALUE ('XXDO_IEX_USE_WEIGHT'), 'N');

        -- Start of Changes for CCR0007180
        ln_aging_bucket_wt_new   := get_Weight (gc_score_component1); --'AGING_WATERFALL'
        ln_last_payment_wt_new   := get_Weight (gc_risk_component1); --'LAST_PAYMENT'
        ln_book_order_wt_new     := get_Weight (gc_risk_component2); --'BOOKED_ORDERS'
        ln_adl_wt_new            := get_Weight (gc_risk_component3); --'ADL_TREND'
        -- End of Changes for CCR0007180

        LOG (p_module        => 'score_apac_wholesale',
             p_line_number   => NULL,
             p_log_message   => 'lc_use_weight : ' || lc_use_weight);

        IF lc_use_weight <> 'N'
        THEN
            IF v_aging_bucket <> gc_default_aging_bucket
            THEN
                LOG (
                    p_module        => 'score_apac_wholesale',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' score_apac_wholesale  Aging Bucket is not  Global Default Aging Bucket');



                ln_last_payment_score   :=
                    get_last_payment_score (P_CUST_ACCOUNT_ID);

                LOG (
                    p_module        => 'score_apac_wholesale',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' score_apac_wholesale  Last Payment Score : '
                        || ln_last_payment_score);



                ln_book_order_score   :=
                    get_booked_order_score (P_CUST_ACCOUNT_ID);

                LOG (
                    p_module        => 'score_apac_wholesale',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' score_apac_wholesale  Booked Order Score : '
                        || ln_book_order_score);


                ln_adl_score         := get_adl_score (P_CUST_ACCOUNT_ID);

                LOG (
                    p_module        => 'score_apac_wholesale',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' score_apac_wholesale  ADL Score : ' || ln_adl_score);


                ln_aging_bucket_wt   := get_Weight (gc_score_component1); --'AGING_WATERFALL'

                LOG (
                    p_module        => 'score_apac_wholesale',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' score_apac_wholesale  Aging Bucket Wt : '
                        || ln_aging_bucket_wt);



                ln_last_payment_wt   := get_Weight (gc_risk_component1); --'LAST_PAYMENT'
                LOG (
                    p_module        => 'score_apac_wholesale',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' score_apac_wholesale  Last Payment Wt : '
                        || ln_last_payment_wt);



                ln_book_order_wt     := get_Weight (gc_risk_component2); --'BOOKED_ORDERS'

                LOG (
                    p_module        => 'score_apac_wholesale',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' score_apac_wholesale  Booked Order Wt : '
                        || ln_book_order_wt);


                ln_adl_wt            := get_Weight (gc_risk_component3); --'ADL_TREND'
                LOG (
                    p_module        => 'score_apac_wholesale',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' score_apac_wholesale  ADL Wt : ' || ln_adl_wt);


                lc_prorate_score     :=
                    NVL (apps.fnd_profile.VALUE ('XXDO_IEX_PRORATE_SCORE'),
                         'N');

                LOG (
                    p_module        => 'score_apac_wholesale',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' score_apac_wholesale  Pro-Rate profile : '
                        || lc_prorate_score);



                ln_score             :=
                    caluclate_score (ln_aging_bucket_score, ln_aging_bucket_wt, ln_last_payment_score, ln_last_payment_wt, ln_book_order_score, ln_book_order_wt, ln_adl_score, ln_adl_wt, lc_prorate_score
                                     , lc_use_weight); -- Addded for CCR0007810);
            ELSE
                LOG (
                    p_module        => 'score_apac_wholesale',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' score_apac_wholesale  Only Aging Bucket default score is considered if amount due remaining is 0');


                ln_score   := ln_aging_bucket_score;
            END IF;

            LOG (
                p_module        => 'score_apac_wholesale',
                p_line_number   => NULL,
                p_log_message   =>
                    ' score_apac_wholesale Score : ' || ln_aging_bucket_score);

            /* Start of changes for CCR0007180 */
            ln_mapped_score   :=
                get_non_weight_mapping_score (P_CUST_ACCOUNT_ID, ln_score);
            /* End of changes for CCR0007180 */

            --ln_mapped_score := get_mapped_score (ln_score, v_aging_bucket);
            LOG (
                p_module        => 'score_apac_wholesale',
                p_line_number   => NULL,
                p_log_message   =>
                       ' score_apac_wholesale Mapped Score : '
                    || ln_mapped_score);
        ELSE
            LOG (
                p_module        => 'score_apac_wholesale',
                p_line_number   => NULL,
                p_log_message   =>
                    ' When XXDO" Use Weights profile is set to no');

            ln_last_payment_score   :=
                get_last_payment_score (P_CUST_ACCOUNT_ID);

            LOG (
                p_module        => 'score_apac_wholesale',
                p_line_number   => NULL,
                p_log_message   =>
                       ' score_apac_wholesale  Last Payment Score : '
                    || ln_last_payment_score);



            ln_book_order_score   :=
                get_booked_order_score (P_CUST_ACCOUNT_ID);

            LOG (
                p_module        => 'score_apac_wholesale',
                p_line_number   => NULL,
                p_log_message   =>
                       ' score_apac_wholesale  Booked Order Score : '
                    || ln_book_order_score);



            ln_adl_score   := get_adl_score (P_CUST_ACCOUNT_ID);

            LOG (
                p_module        => 'score_apac_wholesale',
                p_line_number   => NULL,
                p_log_message   =>
                    ' score_apac_wholesale  ADL Score : ' || ln_adl_score);

            ln_score       :=
                  NVL (ln_aging_bucket_score, 0)
                --    + NVL (ln_aging_bucket_wt, 0)
                + NVL (ln_last_payment_score, 0)
                --    + NVL (ln_last_payment_wt, 0)
                + NVL (ln_adl_score, 0)
                + NVL (ln_book_order_score, 0);

            LOG (
                p_module        => 'score_apac_wholesale',
                p_line_number   => NULL,
                p_log_message   =>
                    ' score_apac_wholesale  Score : ' || ln_score);

            ln_mapped_score   :=
                get_non_weight_mapping_score (P_CUST_ACCOUNT_ID, ln_score);

            LOG (
                p_module        => 'score_apac_wholesale',
                p_line_number   => NULL,
                p_log_message   =>
                       ' score_apac_wholesale Mapped Score : '
                    || ln_mapped_score);
        END IF;

        LOG (
            p_module        => 'score_apac_wholesale',
            p_line_number   => NULL,
            p_log_message   =>
                   ' score_apac_wholesale before Updating HZ_CUST_ACCOUNTS  : '
                || P_CUST_ACCOUNT_ID);

        OPEN insert_update_c (p_cust_account_id);

        FETCH insert_update_c INTO gc_insert_check;

        CLOSE insert_update_c;

        LOG (p_module        => 'score_apac_wholesale',
             p_line_number   => NULL,
             p_log_message   => ' iNSERT fLAG : ' || gc_insert_check);

        IF NVL (gc_insert_check, 'Y') = 'Y'
        THEN
            -- Start of changes for CCR0007180
            IF lc_use_weight <> 'N'
            THEN
                LOG (
                    p_module        => 'score_apac_wholesale',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' BEFORE INSERT using weighted score: '
                        || P_CUST_ACCOUNT_ID);
                INSERT_UPDATE (p_insert_update_flag => 'Y', p_aging_bucket_score => ln_aging_bucket_score * ln_aging_bucket_wt_new, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score * ln_book_order_wt_new, p_last_payment_score => ln_last_payment_score * ln_last_payment_wt_new, p_adl_score => ln_adl_score * ln_adl_wt_new, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);

                LOG (
                    p_module        => 'score_apac_wholesale',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' AFTER INSERT using weighted score: '
                        || gc_insert_check);
            -- End of changes for CCR0007180
            ELSE
                LOG (
                    p_module        => 'score_apac_wholesale',
                    p_line_number   => NULL,
                    p_log_message   =>
                        ' bEFORE INSERT : ' || P_CUST_ACCOUNT_ID);
                INSERT_UPDATE (p_insert_update_flag => 'Y', p_aging_bucket_score => ln_aging_bucket_score, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score, p_last_payment_score => ln_last_payment_score, p_adl_score => ln_adl_score, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);

                LOG (p_module        => 'score_apac_wholesale',
                     p_line_number   => NULL,
                     p_log_message   => ' aFTER INSERT : ' || gc_insert_check);
            END IF;
        ELSE
            -- Start of changes for CCR0007180
            IF lc_use_weight <> 'N'
            THEN
                INSERT_UPDATE (p_insert_update_flag => 'N', p_aging_bucket_score => ln_aging_bucket_score * ln_aging_bucket_wt_new, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score * ln_book_order_wt_new, p_last_payment_score => ln_last_payment_score * ln_last_payment_wt_new, p_adl_score => ln_adl_score * ln_adl_wt_new, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);
            -- End of changes for CCR0007180
            ELSE
                INSERT_UPDATE (p_insert_update_flag => 'N', p_aging_bucket_score => ln_aging_bucket_score, p_aging_bucket => v_aging_bucket, p_booked_order_score => ln_book_order_score, p_last_payment_score => ln_last_payment_score, p_adl_score => ln_adl_score, p_mapped_score => ln_mapped_score, p_score => ln_score, p_cust_account_id => p_cust_account_id
                               , p_org_id => gn_org_id);
            END IF;
        END IF;

        LOG (
            p_module        => 'score_apac_wholesale',
            p_line_number   => NULL,
            p_log_message   =>
                   ' score_apac_wholesale after Updating HZ_CUST_ACCOUNTS  : '
                || P_CUST_ACCOUNT_ID);


        LOG (
            p_module        => 'score_apac_wholesale',
            p_line_number   => NULL,
            p_log_message   =>
                ' End Scoring for Account : ' || P_CUST_ACCOUNT_ID);


        RETURN ROUND (ln_mapped_score);
    EXCEPTION
        WHEN OTHERS
        THEN
            gc_exception_flag   := 'Y';
            LOG (
                p_module        => 'score_apac_wholesale',
                p_line_number   => NULL,
                p_log_message   =>
                       ' score_apac_wholesale  Booked Order Score : '
                    || ln_book_order_score);

            XXDO_GEH_PKG.record_error (
                gc_module,
                P_CUST_ACCOUNT_ID,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                gn_user_id,
                'Code pointer : ' || 'Error in score_apac_wholesale',
                'Deckers Customer Account Scoring Program ',
                (gn_org_id));
            ln_mapped_score     := -1;
            RETURN ln_mapped_score;
    END score_apac_wholesale;

    -- End of change for CCR0009817

    FUNCTION SCORE_ECOMM (p_cust_account_id      IN NUMBER,
                          p_score_component_id   IN NUMBER)
        RETURN NUMBER
    IS
        CURSOR get_max_aging_c IS
            SELECT NVL (MAX (abl.Bucket_Sequence_num), 0)
              FROM ar_aging_buckets ab, ar_aging_bucket_lines abl, ar_payment_schedules_all arp,
                   iex_delinquencies_all del
             WHERE     abl.aging_bucket_id = ab.aging_bucket_id
                   AND ab.bucket_name = gc_deckers_bucket_name
                   AND del.payment_schedule_id = arp.payment_schedule_id
                   AND del.org_id = gn_org_id
                   AND del.status = ('DELINQUENT')
                   AND arp.status = 'OP'
                   AND del.cust_account_id = p_cust_account_id
                   AND (TRUNC (SYSDATE) - TRUNC (arp.due_date)) BETWEEN abl.days_start
                                                                    AND abl.days_to;

        CURSOR insert_update_c (p_cust_acc_id IN NUMBER)
        IS
            SELECT DECODE (COUNT (*), 0, 'Y', 'N')
              FROM xxd_iex_metrics_tbl
             WHERE cust_account_id = p_cust_acc_id AND org_id = gn_org_id;

        ln_aging_bucket   NUMBER;
        ln_score          NUMBER;
    BEGIN
        gc_insert_check   := NULL;

        SET_ORG_ID;

        --xxv_debug_prc('Flow Started - Test Ecomm');

        ln_score          := NULL;

        OPEN get_max_aging_c;

        FETCH get_max_aging_c INTO ln_aging_bucket;

        CLOSE get_max_aging_c;

        ln_score          := ln_aging_bucket;

        /*   IF ln_aging_bucket <> 0 THEN
              ln_score := gn_ecomm_score;
           END IF;*/

        OPEN insert_update_c (p_cust_account_id);

        FETCH insert_update_c INTO gc_insert_check;

        CLOSE insert_update_c;

        IF gc_insert_check = 'Y'
        THEN
            INSERT_UPDATE (p_insert_update_flag   => 'Y',
                           p_aging_bucket_score   => ln_score,
                           p_score                => ln_score,
                           p_cust_account_id      => p_cust_account_id,
                           p_org_id               => gn_org_id);
        ELSE
            INSERT_UPDATE (p_insert_update_flag   => 'N',
                           p_aging_bucket_score   => ln_score,
                           p_score                => ln_score,
                           p_cust_account_id      => p_cust_account_id,
                           p_org_id               => gn_org_id);
        END IF;

        RETURN ln_score;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END SCORE_ECOMM;

    PROCEDURE INSERT_UPDATE (p_insert_update_flag   IN VARCHAR2,
                             p_cust_account_id      IN NUMBER,
                             p_org_id               IN NUMBER,
                             p_adl_q1               IN NUMBER DEFAULT NULL,
                             p_adl_q2               IN NUMBER DEFAULT NULL,
                             p_adl_q3               IN NUMBER DEFAULT NULL,
                             p_adl_q4               IN NUMBER DEFAULT NULL,
                             p_adl_q5               IN NUMBER DEFAULT NULL,
                             p_adl_q6               IN NUMBER DEFAULT NULL,
                             p_adl_q7               IN NUMBER DEFAULT NULL,
                             p_adl_q8               IN NUMBER DEFAULT NULL,
                             p_curr_adl             IN NUMBER DEFAULT NULL,
                             p_adl_variance         IN NUMBER DEFAULT NULL,
                             p_aging_bucket_score   IN NUMBER DEFAULT NULL,
                             p_aging_bucket         IN VARCHAR2 DEFAULT NULL,
                             p_booked_order_score   IN NUMBER DEFAULT NULL,
                             p_last_payment_score   IN NUMBER DEFAULT NULL,
                             p_adl_score            IN NUMBER DEFAULT NULL,
                             p_score                IN NUMBER DEFAULT NULL,
                             p_mapped_score         IN NUMBER DEFAULT NULL,
                             p_attribute_category   IN VARCHAR2 DEFAULT NULL,
                             p_attribute1           IN VARCHAR2 DEFAULT NULL,
                             p_attribute2           IN VARCHAR2 DEFAULT NULL,
                             p_attribute3           IN VARCHAR2 DEFAULT NULL,
                             p_attribute4           IN VARCHAR2 DEFAULT NULL,
                             p_attribute5           IN VARCHAR2 DEFAULT NULL,
                             p_attribute6           IN VARCHAR2 DEFAULT NULL,
                             p_attribute7           IN VARCHAR2 DEFAULT NULL,
                             p_attribute8           IN VARCHAR2 DEFAULT NULL,
                             p_attribute9           IN VARCHAR2 DEFAULT NULL,
                             p_attribute10          IN VARCHAR2 DEFAULT NULL,
                             p_attribute11          IN VARCHAR2 DEFAULT NULL,
                             p_attribute12          IN VARCHAR2 DEFAULT NULL,
                             p_attribute13          IN VARCHAR2 DEFAULT NULL,
                             p_attribute14          IN VARCHAR2 DEFAULT NULL,
                             p_attribute15          IN VARCHAR2 DEFAULT NULL,
                             p_attribute16          IN VARCHAR2 DEFAULT NULL,
                             p_attribute17          IN VARCHAR2 DEFAULT NULL,
                             p_attribute18          IN VARCHAR2 DEFAULT NULL,
                             p_attribute19          IN VARCHAR2 DEFAULT NULL,
                             p_attribute20          IN VARCHAR2 DEFAULT NULL)
    IS
    --  PRAGMA AUTONOMOUS_TRANSACTION; -- Commented for 1.4

    BEGIN
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
               'INSERT_UPDATE:BEFORE IF p_insert_update_flag:'
            || p_insert_update_flag);
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'INSERT_UPDATE:BEFORE IF p_attribute1:' || p_attribute1);

        LOG (p_module        => 'INSERT_UPDATE',
             p_line_number   => NULL,
             p_log_message   => ' Before Insert' || p_org_id || SQLERRM);

        IF p_insert_update_flag = 'Y'
        THEN
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'Inserting new cust account id: '
                || p_cust_account_id
                || ' Org ID: '
                || p_org_id
                || ' Brand: '
                || p_attribute1);
            LOG (p_module        => 'GET_SCORE',
                 p_line_number   => NULL,
                 p_log_message   => ' Before Insert' || p_org_id || SQLERRM);

            --xxv_debug_prc('Inserting into Table');
            INSERT INTO xxd_iex_metrics_tbl (cust_account_id,
                                             org_id,
                                             adl_q1,
                                             adl_q2,
                                             adl_q3,
                                             adl_q4,
                                             adl_q5,
                                             adl_q6,
                                             adl_q7,
                                             adl_q8,
                                             curr_adl,
                                             adl_variance,
                                             aging_bucket_score,
                                             aging_bucket,
                                             booked_order_score,
                                             last_payment_score,
                                             adl_score,
                                             score,
                                             mapped_score,
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
                                             attribute16,
                                             attribute17,
                                             attribute18,
                                             attribute19,
                                             attribute20,
                                             created_by,
                                             creation_date,
                                             last_updated_by,
                                             last_update_date)
                 VALUES (p_cust_account_id, p_org_id, p_adl_q1,
                         p_adl_q2, p_adl_q3, p_adl_q4,
                         p_adl_q5, p_adl_q6, p_adl_q7,
                         p_adl_q8, p_curr_adl, p_adl_variance,
                         p_aging_bucket_score, p_aging_bucket, p_booked_order_score, p_last_payment_score, p_adl_score, p_score, p_mapped_score, p_attribute_category, p_attribute1, p_attribute2, p_attribute3, p_attribute4, p_attribute5, p_attribute6, p_attribute7, p_attribute8, p_attribute9, p_attribute10, p_attribute11, p_attribute12, p_attribute13, p_attribute14, p_attribute15, p_attribute16, p_attribute17, p_attribute18, p_attribute19, p_attribute20, gn_user_id, gd_sysdate
                         , gn_user_id, gd_sysdate);

            LOG (p_module        => 'GET_SCORE',
                 p_line_number   => NULL,
                 p_log_message   => ' After Insert' || SQLERRM);
        ELSE
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'Updating cust account id: '
                || p_cust_account_id
                || ' Org ID: '
                || p_org_id
                || ' Brand: '
                || p_attribute1);

            --xxv_debug_prc('updating  Table');
            UPDATE xxd_iex_metrics_tbl
               SET adl_q1 = NVL (p_adl_q1, adl_q1), adl_q2 = NVL (p_adl_q2, adl_q2), adl_q3 = NVL (p_adl_q3, adl_q3),
                   adl_q4 = NVL (p_adl_q4, adl_q4), adl_q5 = NVL (p_adl_q5, adl_q5), adl_q6 = NVL (p_adl_q6, adl_q6),
                   adl_q7 = NVL (p_adl_q7, adl_q7), adl_q8 = NVL (p_adl_q8, adl_q8), curr_adl = NVL (p_curr_adl, curr_adl),
                   adl_variance = NVL (p_adl_variance, adl_variance), aging_bucket_score = NVL (p_aging_bucket_score, aging_bucket_score), aging_bucket = NVL (p_aging_bucket, aging_bucket),
                   booked_order_score = NVL (p_booked_order_score, booked_order_score), last_payment_score = NVL (p_last_payment_score, last_payment_score), adl_score = NVL (p_adl_score, adl_score),
                   score = NVL (p_score, score), mapped_score = NVL (p_mapped_score, mapped_score), attribute_category = NVL (p_attribute_category, attribute_category),
                   attribute1 = NVL (p_attribute1, attribute1), attribute2 = NVL (p_attribute2, attribute2), attribute3 = NVL (p_attribute3, attribute3),
                   attribute4 = NVL (p_attribute4, attribute4), attribute5 = NVL (p_attribute5, attribute5), attribute6 = NVL (p_attribute6, attribute6),
                   attribute7 = NVL (p_attribute7, attribute7), attribute8 = NVL (p_attribute8, attribute8), attribute9 = NVL (p_attribute9, attribute9),
                   attribute10 = NVL (p_attribute10, attribute10), attribute11 = NVL (p_attribute11, attribute11), attribute12 = NVL (p_attribute12, attribute12),
                   attribute13 = NVL (p_attribute13, attribute13), attribute14 = NVL (p_attribute14, attribute14), attribute15 = NVL (p_attribute15, attribute15),
                   attribute16 = NVL (p_attribute16, attribute16), attribute17 = NVL (p_attribute17, attribute17), attribute18 = NVL (p_attribute18, attribute18),
                   attribute19 = NVL (p_attribute19, attribute19), attribute20 = NVL (p_attribute20, attribute20), last_updated_by = gn_user_id,
                   last_update_date = gd_sysdate
             WHERE cust_account_id = p_cust_account_id AND org_id = p_org_id;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            LOG (p_module        => 'GET_SCORE',
                 p_line_number   => NULL,
                 p_log_message   => ' EXCEPTION AT INSERT ' || SQLERRM);

            FND_FILE.put_line (FND_FILE.LOG,
                               'Exception at INSERT_UPDATE' || SQLERRM);
    --xxv_debug_prc('Inserting/Updation Exception');


    END INSERT_UPDATE;
END XXDO_IEX_SCORING_PKG;
/
