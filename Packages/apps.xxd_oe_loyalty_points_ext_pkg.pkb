--
-- XXD_OE_LOYALTY_POINTS_EXT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:18 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_OE_LOYALTY_POINTS_EXT_PKG"
IS
    /******************************************************************************************
     NAME           : XXD_OE_LOYALTY_POINTS_EXT_PKG
     REPORT NAME    : Deckers Loyalty Balances Extract Program

     REVISIONS:
     Date        Author             Version  Description
     ----------  ----------         -------  ---------------------------------------------------
     30-JUL-2021 Showkath           1.0      Created this package using XXD_OE_LOYALTY_POINTS_EXT_PKG
                                             for sending the report output to BlackLine
  10-SEP-2022 Showkath           1.1      CCR0010249
    *********************************************************************************************/

    --Global constants
    -- Return Statuses

    gn_user_id           CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id          CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id            CONSTANT NUMBER := fnd_profile.VALUE ('ORG_ID');
    gn_resp_id           CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id      CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_request_id        CONSTANT NUMBER := fnd_global.conc_request_id;
    gv_ret_success       CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_success;
    gv_ret_error         CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_error;
    gv_ret_unexp_error   CONSTANT VARCHAR2 (1)
                                      := fnd_api.g_ret_sts_unexp_error ;
    gv_ret_warning       CONSTANT VARCHAR2 (1) := 'W';
    gn_success           CONSTANT NUMBER := 0;
    gn_warning           CONSTANT NUMBER := 1;
    gn_error             CONSTANT NUMBER := 2;
    gn_limit_rec         CONSTANT NUMBER := 100;
    gn_commit_rows       CONSTANT NUMBER := 1000;
    gv_delimeter                  VARCHAR2 (1) := '|';

    -- procedure to purge the duplicate data from can card

    PROCEDURE purge_can_card_duplicates (p_period_end_date IN VARCHAR2, p_org_id IN NUMBER, p_us_pnts_purge_status OUT VARCHAR2)
    AS
    BEGIN
        BEGIN
            INSERT INTO xxdo.xxd_oe_can_loyalty_card_arc_t
                (SELECT *
                   FROM xxdo.xxd_oe_can_loyalty_card_t
                  WHERE     org_id = p_org_id
                        AND TO_DATE (period_end_date, 'MM/DD/YYYY') =
                            TO_DATE (p_period_end_date, 'MM/DD/YYYY'));

            COMMIT;

            DELETE FROM
                xxdo.xxd_oe_can_loyalty_card_t
                  WHERE     org_id = p_org_id
                        AND TO_DATE (period_end_date, 'MM/DD/YYYY') =
                            TO_DATE (p_period_end_date, 'MM/DD/YYYY');

            COMMIT;
            p_us_pnts_purge_status   := 'S';
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Failed to purge CAN card data:' || SQLERRM);
                p_us_pnts_purge_status   := 'E';
        END;
    END purge_can_card_duplicates;

    -- procedure to purge the duplicate data from US Card

    PROCEDURE purge_us_card_duplicates (p_period_end_date IN VARCHAR2, p_org_id IN NUMBER, p_us_pnts_purge_status OUT VARCHAR2)
    AS
    BEGIN
        BEGIN
            INSERT INTO xxdo.xxd_oe_us_loyalty_card_arc_t
                (SELECT *
                   FROM xxdo.xxd_oe_us_loyalty_card_t
                  WHERE     org_id = p_org_id
                        AND TO_DATE (period_end_date, 'MM/DD/YYYY') =
                            TO_DATE (p_period_end_date, 'MM/DD/YYYY'));

            COMMIT;

            DELETE FROM
                xxdo.xxd_oe_us_loyalty_card_t
                  WHERE     org_id = p_org_id
                        AND TO_DATE (period_end_date, 'MM/DD/YYYY') =
                            TO_DATE (p_period_end_date, 'MM/DD/YYYY');

            COMMIT;
            p_us_pnts_purge_status   := 'S';
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Failed to purge US Card data:' || SQLERRM);
                p_us_pnts_purge_status   := 'E';
        END;
    END purge_us_card_duplicates;

    -- procedure to purge the duplicate data from can points

    PROCEDURE purge_can_points_duplicates (p_period_end_date IN VARCHAR2, p_org_id IN NUMBER, p_us_pnts_purge_status OUT VARCHAR2)
    AS
    BEGIN
        BEGIN
            INSERT INTO xxdo.xxd_oe_can_loyalty_pnts_arc_t
                (SELECT *
                   FROM xxdo.xxd_oe_can_loyalty_points_t
                  WHERE     org_id = p_org_id
                        AND TO_DATE (period_end_date, 'MM/DD/YYYY') =
                            TO_DATE (p_period_end_date, 'MM/DD/YYYY'));

            COMMIT;

            DELETE FROM
                xxdo.xxd_oe_can_loyalty_points_t
                  WHERE     org_id = p_org_id
                        AND TO_DATE (period_end_date, 'MM/DD/YYYY') =
                            TO_DATE (p_period_end_date, 'MM/DD/YYYY');

            COMMIT;
            p_us_pnts_purge_status   := 'S';
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Failed to purge CAN Points data:' || SQLERRM);
                p_us_pnts_purge_status   := 'E';
        END;
    END purge_can_points_duplicates;

    -- procedure to purge the duplicate data

    PROCEDURE purge_us_points_duplicates (p_period_end_date IN VARCHAR2, p_org_id IN NUMBER, p_us_pnts_purge_status OUT VARCHAR2)
    AS
    BEGIN
        BEGIN
            INSERT INTO xxdo.xxd_oe_us_loyalty_pnts_arc_t
                (SELECT *
                   FROM xxdo.xxd_oe_us_loyalty_points_t
                  WHERE     org_id = p_org_id
                        AND TO_DATE (period_end_date, 'MM/DD/YYYY') =
                            TO_DATE (p_period_end_date, 'MM/DD/YYYY'));

            COMMIT;

            DELETE FROM
                xxdo.xxd_oe_us_loyalty_points_t
                  WHERE     org_id = p_org_id
                        AND TO_DATE (period_end_date, 'MM/DD/YYYY') =
                            TO_DATE (p_period_end_date, 'MM/DD/YYYY');

            COMMIT;
            p_us_pnts_purge_status   := 'S';
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Failed to purge US Points data:' || SQLERRM);
                p_us_pnts_purge_status   := 'E';
        END;
    END purge_us_points_duplicates;

    PROCEDURE write_log (pv_msg IN VARCHAR2)
    IS
        lv_msg   VARCHAR2 (4000) := pv_msg;
    BEGIN
        IF gn_user_id = -1
        THEN
            DBMS_OUTPUT.put_line (pv_msg);
        ELSE
            apps.fnd_file.put_line (apps.fnd_file.LOG, pv_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Error in WRITE_LOG Procedure -' || SQLERRM);
            DBMS_OUTPUT.put_line (
                'Error in WRITE_LOG Procedure -' || SQLERRM);
    END write_log;

    PROCEDURE write_op_file (pv_file_path IN VARCHAR2, pv_period_end_date IN VARCHAR2, pv_type IN VARCHAR2, pv_method IN VARCHAR2, p_operating_unit IN NUMBER, x_ret_code OUT VARCHAR2
                             , x_ret_message OUT VARCHAR2, pn_points_amt IN NUMBER, -- 1.1
                                                                                    pn_us_aquisition_points IN NUMBER)
    IS
        CURSOR op_file_us_points IS
              SELECT line
                FROM (SELECT 1 AS seq, created_at || gv_delimeter || acq_begining_balance || gv_delimeter || acq_earned || gv_delimeter || acq_reward || gv_delimeter || acq_expired || gv_delimeter || acq_returned || gv_delimeter || acq_ending_balance || gv_delimeter || acq_conversion || gv_delimeter || partner_acq_begin_balance || gv_delimeter || partner_acq_earned || gv_delimeter || partner_acq_reward || gv_delimeter || partner_acq_expired || gv_delimeter || partner_acq_ending_balance || gv_delimeter || engagement_begining_balance || gv_delimeter || engagement_earned || gv_delimeter || engagement_reward || gv_delimeter || engagement_expired || gv_delimeter || engagement_returned || gv_delimeter || engagement_adjusted || gv_delimeter || engagement_ending_balance || gv_delimeter || engagement_conversion || gv_delimeter || overage_begining_balance || gv_delimeter || overage_reward || gv_delimeter || overage_expired || gv_delimeter || overage_adjusted || gv_delimeter || overage_ending_balance || gv_delimeter || total_day || gv_delimeter || total_ending_balance line
                        FROM xxdo.xxd_oe_us_loyalty_points_t
                       WHERE 1 = 1 AND request_id = gn_request_id
                      UNION
                      SELECT 2 AS seq, 'Created at' || gv_delimeter || 'Acquisition Begining Balance' || gv_delimeter || 'Acquisition Earned' || gv_delimeter || 'Acquisition Reward' || gv_delimeter || 'Acquisition Expired' || gv_delimeter || 'Acquisition Returned' || gv_delimeter || 'Acquisition Ending Balance' || gv_delimeter || 'Acquisition Conversion' || gv_delimeter || 'Partner Acquisition Begin Balance' || gv_delimeter || 'Partner Acquisition Earned' || gv_delimeter || 'Partner Acquisition Reward' || gv_delimeter || 'Partner Acquisition Expired' || gv_delimeter || 'Partner Acquisition Ending Balance' || gv_delimeter || 'Engagement Begining Balance' || gv_delimeter || 'Engagement Earned' || gv_delimeter || 'Engagement Reward' || gv_delimeter || 'Engagement Expired' || gv_delimeter || 'Engagement Returned' || gv_delimeter || 'Engagement Adjusted' || gv_delimeter || 'Engagement Ending Balance' || gv_delimeter || 'Engagement Conversion' || gv_delimeter || 'Overage Begining Balance' || gv_delimeter || 'Overage Reward ' || gv_delimeter || 'Overage Expired' || gv_delimeter || 'Overage Adjusted' || gv_delimeter || 'Overage Ending Balance' || gv_delimeter || 'Total Day ' || gv_delimeter || 'Total Ending Balance'
                        FROM DUAL)
            ORDER BY 1 DESC;

        CURSOR op_file_can_points IS
              SELECT line
                FROM (SELECT 1 AS seq, created_at || gv_delimeter || acq_begining_balance || gv_delimeter || acq_earned || gv_delimeter || acq_earned_local_value || gv_delimeter || acq_reward || gv_delimeter || acq_reward_local_value || gv_delimeter || acq_expired || gv_delimeter || acq_expired_local_value || gv_delimeter || acq_returned || gv_delimeter || acq_returned_local_value || gv_delimeter || future_future_attribute1 || gv_delimeter || future_attribute2 || gv_delimeter || acq_ending_balance || gv_delimeter || acq_ending_bal_local_value || gv_delimeter || acq_conversion || gv_delimeter || acq_conversion_local_value || gv_delimeter || partner_acq_begin_bal || gv_delimeter || partner_acq_beg_bal_local_val || gv_delimeter || partner_acq_earned || gv_delimeter || partner_acq_earned_local_val || gv_delimeter || partner_acq_reward || gv_delimeter || partner_acq_reward_local_val || gv_delimeter || partner_acq_expired || gv_delimeter || partner_acq_expired_local_val || gv_delimeter || partner_acq_ending_balance || gv_delimeter || partner_acq_end_bal_local_val || gv_delimeter || engagement_begining_balance || gv_delimeter || engagement_beg_bal_local_val || gv_delimeter || engagement_earned || gv_delimeter || engagement_earned_local_val || gv_delimeter || engagement_reward || gv_delimeter || engagement_reward_local_val || gv_delimeter || engagement_expired || gv_delimeter || engagement_exp_local_val || gv_delimeter || engagement_returned || gv_delimeter || engagement_return_local_val || gv_delimeter || engagement_adjusted || gv_delimeter || engagement_adjust_local_val || gv_delimeter || engagement_ending_balance || gv_delimeter || engagement_end_bal_local_val || gv_delimeter || engagement_conversion || gv_delimeter || engagement_conv_local_value || gv_delimeter || overage_begining_balance || gv_delimeter || overage_begin_bal_local_val || gv_delimeter || overage_reward || gv_delimeter || overage_reward_local_val || gv_delimeter || overage_expired || gv_delimeter || overage_expired_local_val || gv_delimeter || overage_adjusted || gv_delimeter || overage_adjusted_local_val || gv_delimeter || overage_ending_balance || gv_delimeter || overage_end_bal_local_val || gv_delimeter || total_day || gv_delimeter || total_day_local_value || gv_delimeter || total_ending_balance || gv_delimeter || total_ending_bal_local_val line
                        FROM xxdo.xxd_oe_can_loyalty_points_t
                       WHERE     1 = 1
                             AND request_id = gn_request_id
                             AND TO_DATE (created_at, 'YYYY-MM-DD') <=
                                 TO_DATE (pv_period_end_date,
                                          'RRRR/MM/DD HH24:MI:SS')
                      UNION
                      SELECT 2 AS seq, 'Created at' || gv_delimeter || 'Acquisition Begining Balance' || gv_delimeter || 'Acquisition Earned' || gv_delimeter || 'Acquisition Earned Local Value' || gv_delimeter || 'Acquisition Reward' || gv_delimeter || 'Acquisition Reward Local Value' || gv_delimeter || 'Acquisition Expired' || gv_delimeter || 'Acquisition Expired Local Value' || gv_delimeter || 'Acquisition Returned' || gv_delimeter || 'Acquisition Returned Local Value' || gv_delimeter || 'Aquisition Closed Member' || gv_delimeter || 'Aquisition Closed Member Local Value' || gv_delimeter || 'Acquisition Ending Balance' || gv_delimeter || 'Acquisition Ending Balance Local Value' || gv_delimeter || 'Acquisition Conversion' || gv_delimeter || 'Acquisition Conversion Local Value' || gv_delimeter || 'Partner Acquisition Begin Balance' || gv_delimeter || 'Partner Acquisition Begin Balance Local Value' || gv_delimeter || 'Partner Acquisition Earned' || gv_delimeter || 'Partner Acquisition Earned Local Value' || gv_delimeter || 'Partner Acquisition Reward' || gv_delimeter || 'Partner Acquisition Reward Local Value' || gv_delimeter || 'Partner Acquisition Expired' || gv_delimeter || 'Partner Acquisition Expired Local Value' || gv_delimeter || 'Partner Acquisition Ending Balance' || gv_delimeter || 'Partner Acquisition Ending Balance Local Value' || gv_delimeter || 'Engagement Begining Balance' || gv_delimeter || 'Engagement Begining Balance Local Value' || gv_delimeter || 'Engagement Earned' || gv_delimeter || 'Engagement Earned Local Value' || gv_delimeter || 'Engagement Reward' || gv_delimeter || 'Engagement Reward Local Value' || gv_delimeter || 'Engagement Expired' || gv_delimeter || 'Engagement Expired Local Value' || gv_delimeter || 'Engagement Returned' || gv_delimeter || 'Engagement Returned Local Value' || gv_delimeter || 'Engagement Adjusted' || gv_delimeter || 'Engagement Adjusted Local Value' || gv_delimeter || 'Engagement Ending Balance' || gv_delimeter || 'Engagement Ending Balance Local Value' || gv_delimeter || 'Engagement Conversion' || gv_delimeter || 'Engagement Conversion Local Value' || gv_delimeter || 'Overage Begining Balance' || gv_delimeter || 'Overage Begining Balance Local Value' || gv_delimeter || 'Overage Reward' || gv_delimeter || 'Overage Reward Local Value' || gv_delimeter || 'Overage Expired' || gv_delimeter || 'Overage Expired Local Value' || gv_delimeter || 'Overage Adjusted' || gv_delimeter || 'Overage Adjusted Local Value' || gv_delimeter || 'Overage Ending Balance' || gv_delimeter || 'Overage Ending Balance Local Value' || gv_delimeter || 'Total Day' || gv_delimeter || 'Total Day Local Value' || gv_delimeter || 'Total Ending Balance' || gv_delimeter || 'Total Ending Balance Local Value'
                        FROM DUAL)
            ORDER BY 1 DESC;

        CURSOR op_file_us_coupon IS
              SELECT line
                FROM (SELECT 1 AS seq, date_at || gv_delimeter || reward_id || gv_delimeter || cost || gv_delimeter || starting_balance || gv_delimeter || issued || gv_delimeter || redeemed || gv_delimeter || expired || gv_delimeter || invalidated || gv_delimeter || reissued || gv_delimeter || ending_balance line
                        FROM xxdo.xxd_oe_us_loyalty_card_t
                       WHERE 1 = 1 AND request_id = gn_request_id
                      UNION
                      SELECT 2 AS seq, 'Date at' || gv_delimeter || 'Reward id' || gv_delimeter || 'Cost' || gv_delimeter || 'Starting Balance' || gv_delimeter || 'Issued' || gv_delimeter || 'Redeemed' || gv_delimeter || 'Expired' || gv_delimeter || 'Invalidated' || gv_delimeter || 'Reissued' || gv_delimeter || 'Ending Balance'
                        FROM DUAL)
            ORDER BY 1 DESC;

        CURSOR op_file_can_coupon IS
              SELECT line
                FROM (SELECT 1 AS seq, date_at || gv_delimeter || reward_id || gv_delimeter || cost || gv_delimeter || strating_balance || gv_delimeter || issued || gv_delimeter || reward_issued_local_value || gv_delimeter || redeemed || gv_delimeter || reward_redeemed_local_value || gv_delimeter || expired || gv_delimeter || reward_expired_local_value || gv_delimeter || invalidated || gv_delimeter || reward_invalid_local_val || gv_delimeter || reissued || gv_delimeter || reward_reissued_local_value || gv_delimeter || ending_balance || gv_delimeter || reward_ending_bal_local_val line
                        FROM xxdo.xxd_oe_can_loyalty_card_t
                       WHERE 1 = 1 AND request_id = gn_request_id
                      UNION
                      SELECT 2 AS seq, 'Date at' || gv_delimeter || 'Reward id' || gv_delimeter || 'Cost' || gv_delimeter || 'Starting Balance' || gv_delimeter || 'Issued' || gv_delimeter || 'Reward Issued Local Value' || gv_delimeter || 'Redeemed' || gv_delimeter || 'Reward Redeemed Local Value' || gv_delimeter || 'Expired' || gv_delimeter || 'Reward Expired Local Value' || gv_delimeter || 'Invalidated' || gv_delimeter || 'Reward Invalidated Local Value' || gv_delimeter || 'Reissued' || gv_delimeter || 'Reward Reissued Local Value' || gv_delimeter || 'Ending Balance' || gv_delimeter || 'Reward Ending Balance Local Value'
                        FROM DUAL)
            ORDER BY 1 DESC;

        --DEFINE VARIABLES

        lv_file_path                    VARCHAR2 (360);    -- := pv_file_path;
        lv_file_name                    VARCHAR2 (360);
        lv_file_dir                     VARCHAR2 (1000);
        lv_output_file                  UTL_FILE.file_type;
        lv_outbound_file                VARCHAR2 (360);    -- := pv_file_name;
        lv_err_msg                      VARCHAR2 (2000) := NULL;
        lv_line                         VARCHAR2 (32767) := NULL;
        lv_vs_default_file_path         VARCHAR2 (2000);
        lv_vs_file_path                 VARCHAR2 (200);
        lv_vs_file_name                 VARCHAR2 (200);
        lv_ou_short_name                VARCHAR2 (100);
        lv_period_name                  VARCHAR2 (50);
        --1.1 changes start
        ln_acq_begining_balance         NUMBER;
        ln_acq_earned                   NUMBER;
        ln_acq_reward                   NUMBER;
        ln_acq_expired                  NUMBER;
        ln_acq_returned                 NUMBER;
        ln_acq_ending_balance           NUMBER;
        ln_acq_conversion               NUMBER;
        ln_engagement_reward            NUMBER;
        ln_engagement_earned            NUMBER;
        LN_FINAL_ACQ_BEGINING_BALANCE   NUMBER;
        ln_final_acq_earned             NUMBER;
        ln_final_acq_reward             NUMBER;
        ln_final_acq_expired            NUMBER;
        ln_final_acq_returned           NUMBER;
        ln_final_acq_ending_balance     NUMBER;
        ln_final_acq_conversion         NUMBER;
        ln_final_engagement_reward      NUMBER;
        ln_final_engagement_earned      NUMBER;
        lv_line1                        VARCHAR2 (32767) := NULL;
        lv_line2                        VARCHAR2 (32767) := NULL;
        lv_line3                        VARCHAR2 (32767) := NULL;
        lv_line4                        VARCHAR2 (32767) := NULL;
        lv_line5                        VARCHAR2 (32767) := NULL;
        lv_line6                        VARCHAR2 (32767) := NULL;
        lv_line7                        VARCHAR2 (32767) := NULL;
        lv_line8                        VARCHAR2 (32767) := NULL;
        ln_sum_acq_conversion_pre       NUMBER;
        ln_sum_acq_conversion_curr      NUMBER;
        -- coupon
        ln_begining_balance             NUMBER;
        ln_issued                       NUMBER;
        ln_redeemed                     NUMBER;
        ln_expired                      NUMBER;
        ln_invalidated                  NUMBER;
        ln_reissued                     NUMBER;
        ln_ending_balance               NUMBER;
        ln_sum_begining_balance         NUMBER;
        ln_sum_issued                   NUMBER;
        ln_sum_redeemed                 NUMBER;
        ln_sum_expired                  NUMBER;
        ln_sum_invalidated              NUMBER;
        ln_sum_reissued                 NUMBER;
        ln_sum_ending_balance           NUMBER;
        ln_cost                         NUMBER;
        -- coupon brokage
        ln_month1_amount                NUMBER;
        ln_month2_amount                NUMBER;
        ln_month3_amount                NUMBER;
        ln_month1_vs_brokage            NUMBER;
        ln_month2_vs_brokage            NUMBER;
        ln_month3_vs_brokage            NUMBER;
        ln_month1_brokage_amt           NUMBER;
        ln_month2_brokage_amt           NUMBER;
        ln_month3_brokage_amt           NUMBER;
        lv_period_type                  VARCHAR2 (100);
        ln_total_brokage                NUMBER;
        ln_final_amount                 NUMBER;
        ln_acq_closed_member            NUMBER;
        ln_final_acq_closed_member      NUMBER;
    --1.1 changes end
    BEGIN
        -- WRITE INTO BL FOLDER
        IF pv_file_path IS NOT NULL
        THEN
            BEGIN
                SELECT ffvl.attribute1, ffvl.attribute3
                  INTO lv_vs_file_path, lv_vs_file_name
                  FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                 WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                       AND fvs.flex_value_set_name =
                           'XXD_GL_AAR_FILE_DETAILS_VS'
                       AND NVL (TRUNC (ffvl.start_date_active),
                                TRUNC (SYSDATE)) <=
                           TRUNC (SYSDATE)
                       AND NVL (TRUNC (ffvl.end_date_active),
                                TRUNC (SYSDATE)) >=
                           TRUNC (SYSDATE)
                       AND ffvl.enabled_flag = 'Y'
                       AND ffvl.description = 'LOYALTY'
                       AND ffvl.flex_value = pv_file_path;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_vs_file_path   := NULL;
                    lv_vs_file_name   := NULL;
            END;

            IF pv_period_end_date IS NULL
            THEN
                BEGIN
                    SELECT period_year || '.' || period_num || '.' || period_name
                      INTO lv_period_name
                      FROM apps.gl_periods
                     WHERE     period_set_name = 'DO_FY_CALENDAR'
                           AND TRUNC (SYSDATE) BETWEEN start_date
                                                   AND end_date;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_period_name   := NULL;
                END;
            ELSE
                BEGIN
                    SELECT period_year || '.' || period_num || '.' || period_name
                      INTO lv_period_name
                      FROM apps.gl_periods
                     WHERE     period_set_name = 'DO_CY_CALENDAR'
                           AND TO_DATE (pv_period_end_date,
                                        'YYYY/MM/DD HH24:MI:SS') BETWEEN start_date
                                                                     AND end_date;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_period_name   := NULL;
                END;
            END IF;

            IF     lv_vs_file_path IS NOT NULL
               AND NVL (lv_vs_file_path, 'X') <> 'NA'
               AND lv_vs_file_name IS NOT NULL
            THEN
                lv_ou_short_name   := NULL;

                BEGIN
                    SELECT ffvl.attribute2
                      INTO lv_ou_short_name
                      FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                     WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                           AND fvs.flex_value_set_name =
                               'XXD_GL_AAR_OU_SHORTNAME_VS'
                           AND NVL (TRUNC (ffvl.start_date_active),
                                    TRUNC (SYSDATE)) <=
                               TRUNC (SYSDATE)
                           AND NVL (TRUNC (ffvl.end_date_active),
                                    TRUNC (SYSDATE)) >=
                               TRUNC (SYSDATE)
                           AND ffvl.enabled_flag = 'Y'
                           AND ffvl.attribute1 = p_operating_unit;
                --                          AND ffvl.attribute3 = pv_company;

                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_ou_short_name   := NULL;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Exce fetching OU Short Name is - '
                            || SUBSTR (SQLERRM, 1, 200));
                --

                END;

                --                fnd_file.put_line (fnd_file.LOG,'pn_ou_id is - ' || p_operating_unit);
                --                fnd_file.put_line (fnd_file.LOG,'lv_ou_short_name is - ' || lv_ou_short_name);

                lv_file_dir        := lv_vs_file_path;

                IF pv_type = 'Points' AND pv_method = 'A'
                THEN
                    --1.1 chanegs start
                    -- query to fetch previos points total

                    BEGIN
                        SELECT SUM (acq_conversion) + pn_us_aquisition_points
                          INTO ln_sum_acq_conversion_pre
                          FROM xxdo.xxd_oe_us_loyalty_points_t
                         WHERE     1 = 1
                               AND TO_DATE (period_end_date, 'MM/DD/YYYY') <
                                   TO_DATE (pv_period_end_date,
                                            'RRRR/MM/DD HH24:MI:SS');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_sum_acq_conversion_pre   := NULL;
                    END;

                    -- query to fetch previos points total

                    BEGIN
                        SELECT SUM (acq_conversion) + pn_us_aquisition_points
                          INTO ln_sum_acq_conversion_curr
                          FROM xxdo.xxd_oe_us_loyalty_points_t
                         WHERE     1 = 1
                               AND TO_DATE (period_end_date, 'MM/DD/YYYY') <=
                                   TO_DATE (pv_period_end_date,
                                            'RRRR/MM/DD HH24:MI:SS');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_sum_acq_conversion_curr   := NULL;
                    END;

                    -- query to fetch summary of all the report columns

                    BEGIN
                        SELECT   (SELECT acq_begining_balance
                                    FROM xxdo.xxd_oe_us_loyalty_points_t
                                   WHERE TO_DATE (created_at, 'YYYY-MM-DD') =
                                         first_day)
                               + ln_sum_acq_conversion_pre begining_balance,
                               acq_earned,
                               acq_reward,
                               acq_expired,
                               acq_returned,
                                 (SELECT acq_ending_balance
                                    FROM xxdo.xxd_oe_us_loyalty_points_t
                                   WHERE TO_DATE (created_at, 'YYYY-MM-DD') =
                                         LAST_DAY)
                               + ln_sum_acq_conversion_curr ending_balance,
                               acq_conversion,
                               engagement_earned,
                               engagement_reward,
                                 (  (SELECT acq_begining_balance
                                       FROM xxdo.xxd_oe_us_loyalty_points_t
                                      WHERE TO_DATE (created_at,
                                                     'YYYY-MM-DD') =
                                            first_day)
                                  + ln_sum_acq_conversion_pre)
                               * pn_points_amt sum_begining_balance,
                               sum_acq_earned,
                               sum_acq_reward,
                               sum_acq_expired,
                               sum_acq_returned,
                                 (  (SELECT acq_ending_balance
                                       FROM xxdo.xxd_oe_us_loyalty_points_t
                                      WHERE TO_DATE (created_at,
                                                     'YYYY-MM-DD') =
                                            LAST_DAY)
                                  + ln_sum_acq_conversion_curr)
                               * pn_points_amt sum_ending_balance,
                               sum_acq_conversion,
                               sum_engagement_earned,
                               sum_engagement_reward
                          INTO ln_acq_begining_balance, ln_acq_earned, ln_acq_reward, ln_acq_expired,
                                                      ln_acq_returned, ln_acq_ending_balance, ln_acq_conversion,
                                                      ln_engagement_earned, ln_engagement_reward, LN_FINAL_ACQ_BEGINING_BALANCE,
                                                      ln_final_acq_earned, ln_final_acq_reward, ln_final_acq_expired,
                                                      ln_final_acq_returned, ln_final_acq_ending_balance, ln_final_acq_conversion,
                                                      ln_final_engagement_earned, ln_final_engagement_reward
                          FROM (  SELECT ADD_MONTHS (LAST_DAY (TO_DATE (period_end_date, 'MM/DD/YYYY')), -1) + 1 first_day, SUM (acq_earned) acq_earned, SUM (acq_reward) acq_reward,
                                         SUM (acq_expired) acq_expired, SUM (acq_returned) acq_returned, LAST_DAY (TO_DATE (period_end_date, 'MM/DD/YYYY')) LAST_DAY,
                                         SUM (acq_conversion) acq_conversion, SUM (engagement_earned) engagement_earned, SUM (engagement_reward) engagement_reward,
                                         SUM (acq_earned) * pn_points_amt sum_acq_earned, SUM (acq_reward) * pn_points_amt sum_acq_reward, SUM (acq_expired) * pn_points_amt sum_acq_expired,
                                         SUM (acq_returned) * pn_points_amt sum_acq_returned, SUM (acq_conversion) * pn_points_amt sum_acq_conversion, SUM (engagement_earned) * pn_points_amt sum_engagement_earned,
                                         SUM (engagement_reward) * pn_points_amt sum_engagement_reward
                                    FROM xxdo.xxd_oe_us_loyalty_points_t
                                   WHERE     request_id = gn_request_id
                                         AND TO_DATE (created_at, 'YYYY-MM-DD') <=
                                             TO_DATE (pv_period_end_date,
                                                      'RRRR/MM/DD HH24:MI:SS')
                                GROUP BY period_end_date);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_acq_begining_balance         := NULL;
                            ln_acq_earned                   := NULL;
                            ln_acq_reward                   := NULL;
                            ln_acq_expired                  := NULL;
                            ln_acq_returned                 := NULL;
                            ln_acq_ending_balance           := NULL;
                            ln_acq_conversion               := NULL;
                            ln_engagement_earned            := NULL;
                            ln_engagement_reward            := NULL;
                            LN_FINAL_ACQ_BEGINING_BALANCE   := NULL;
                            ln_final_acq_earned             := NULL;
                            ln_final_acq_reward             := NULL;
                            ln_final_acq_expired            := NULL;
                            ln_final_acq_returned           := NULL;
                            ln_final_acq_ending_balance     := NULL;
                            ln_final_acq_conversion         := NULL;
                            ln_final_engagement_earned      := NULL;
                            ln_final_engagement_reward      := NULL;
                    END;

                    lv_line4   :=
                           'Conversion Points'
                        || gv_delimeter
                        || ln_sum_acq_conversion_pre
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || ln_sum_acq_conversion_curr
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter;


                    lv_line1   :=
                           'Total Points'
                        || gv_delimeter
                        || ln_acq_begining_balance
                        || gv_delimeter
                        || ln_acq_earned
                        || gv_delimeter
                        || ln_acq_reward
                        || gv_delimeter
                        || ln_acq_expired
                        || gv_delimeter
                        || ln_acq_returned
                        || gv_delimeter
                        || ln_acq_ending_balance
                        || gv_delimeter
                        || ln_acq_conversion
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || ln_engagement_reward;
                    lv_line2   :=
                           'Value'
                        || gv_delimeter
                        || pn_points_amt
                        || gv_delimeter
                        || pn_points_amt
                        || gv_delimeter
                        || pn_points_amt
                        || gv_delimeter
                        || pn_points_amt
                        || gv_delimeter
                        || pn_points_amt
                        || gv_delimeter
                        || pn_points_amt
                        || gv_delimeter
                        || pn_points_amt
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || pn_points_amt;
                    lv_line3   :=
                           'Total Dollar'
                        || gv_delimeter
                        || ln_final_acq_begining_balance
                        || gv_delimeter
                        || ln_final_acq_earned
                        || gv_delimeter
                        || ln_final_acq_reward
                        || gv_delimeter
                        || ln_final_acq_expired
                        || gv_delimeter
                        || ln_final_acq_returned
                        || gv_delimeter
                        || ln_final_acq_ending_balance
                        || gv_delimeter
                        || ln_final_acq_conversion
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || ln_final_engagement_reward;


                    --1.1
                    lv_file_name   :=
                           lv_vs_file_name
                        || '_'
                        || lv_period_name
                        || '_'
                        || lv_ou_short_name
                        || '_'
                        || pv_type
                        || '_'
                        || gn_request_id
                        || '_'
                        || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')
                        || '.txt';

                    --                END IF;

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Supporting File Name is - ' || lv_file_name);
                    lv_output_file   :=
                        UTL_FILE.fopen (lv_file_dir, lv_file_name, 'W' --opening the file in write mode
                                                                      ,
                                        32767);

                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        FOR i IN op_file_us_points
                        LOOP
                            lv_line   := i.line;
                            UTL_FILE.put_line (lv_output_file, lv_line);
                        END LOOP;

                        --1.1 changes
                        UTL_FILE.put_line (lv_output_file, lv_line4);
                        UTL_FILE.put_line (lv_output_file, ' ');
                        UTL_FILE.put_line (lv_output_file, lv_line1);
                        UTL_FILE.put_line (lv_output_file, lv_line2);
                        UTL_FILE.put_line (lv_output_file, lv_line3);
                    --1.1 changes
                    ELSE
                        lv_err_msg      :=
                            SUBSTR (
                                   'Error in Opening the  data file for writing. Error is : '
                                || SQLERRM,
                                1,
                                2000);
                        write_log (lv_err_msg);
                        x_ret_code      := gn_error;
                        x_ret_message   := lv_err_msg;
                        RETURN;
                    END IF;

                    UTL_FILE.fclose (lv_output_file);
                ELSIF pv_type = 'Points' AND pv_method = 'B'
                THEN
                    -- 1.1 changes start
                    BEGIN
                        SELECT (SELECT acq_begining_balance
                                  FROM xxdo.xxd_oe_can_loyalty_points_t
                                 WHERE     TO_DATE (created_at, 'YYYY-MM-DD') =
                                           first_day
                                       AND period_end_date =
                                           a.period_end_date)
                                   begining_balance,
                               acq_earned,
                               acq_reward,
                               acq_expired,
                               acq_returned,
                               ACQ_CLOSED_MEMBER,
                               (SELECT acq_ending_balance
                                  FROM xxdo.xxd_oe_can_loyalty_points_t
                                 WHERE     TO_DATE (created_at, 'YYYY-MM-DD') =
                                           LAST_DAY
                                       AND period_end_date =
                                           a.period_end_date)
                                   ending_balance,
                               engagement_reward,
                                 ((SELECT acq_begining_balance
                                     FROM xxdo.xxd_oe_can_loyalty_points_t
                                    WHERE     TO_DATE (created_at,
                                                       'YYYY-MM-DD') =
                                              first_day
                                          AND period_end_date =
                                              a.period_end_date))
                               * pn_points_amt
                                   sum_begining_balance,
                               sum_acq_earned,
                               sum_acq_reward,
                               sum_acq_expired,
                               sum_acq_returned,
                               sum_ACQ_CLOSED_MEMBER,
                                 ((SELECT acq_ending_balance
                                     FROM xxdo.xxd_oe_can_loyalty_points_t
                                    WHERE     TO_DATE (created_at,
                                                       'YYYY-MM-DD') =
                                              LAST_DAY
                                          AND period_end_date =
                                              a.period_end_date))
                               * pn_points_amt
                                   sum_ending_balance,
                               sum_engagement_reward
                          INTO ln_acq_begining_balance, ln_acq_earned, ln_acq_reward, ln_acq_expired,
                                                      ln_acq_returned, ln_acq_closed_member, ln_acq_ending_balance,
                                                      ln_engagement_reward, LN_FINAL_ACQ_BEGINING_BALANCE, ln_final_acq_earned,
                                                      ln_final_acq_reward, ln_final_acq_expired, ln_final_acq_returned,
                                                      ln_final_acq_closed_member, ln_final_acq_ending_balance, ln_final_engagement_reward
                          FROM (  SELECT ADD_MONTHS (LAST_DAY (TO_DATE (period_end_date, 'MM/DD/YYYY')), -1) + 1 first_day, SUM (acq_earned) acq_earned, SUM (acq_reward) acq_reward,
                                         SUM (acq_expired) acq_expired, SUM (acq_returned) acq_returned, SUM (future_future_attribute1) ACQ_CLOSED_MEMBER,
                                         LAST_DAY (TO_DATE (period_end_date, 'MM/DD/YYYY')) LAST_DAY, SUM (acq_conversion) acq_conversion, SUM (engagement_earned) engagement_earned,
                                         SUM (engagement_reward) engagement_reward, --SUM(acq_begining_balance)*:pn_points_amt,
                                                                                    SUM (acq_earned) * pn_points_amt sum_acq_earned, SUM (acq_reward) * pn_points_amt sum_acq_reward,
                                         SUM (acq_expired) * pn_points_amt sum_acq_expired, SUM (acq_returned) * pn_points_amt sum_acq_returned, SUM (future_future_attribute1) * pn_points_amt sum_acq_closed_member,
                                         --  SUM(acq_ending_balance)*:pn_points_amt,
                                         SUM (acq_conversion) * pn_points_amt sum_acq_conversion, SUM (engagement_earned) * pn_points_amt sum_engagement_earned, SUM (engagement_reward) * pn_points_amt sum_engagement_reward,
                                         period_end_date
                                    FROM xxdo.xxd_oe_can_loyalty_points_t a
                                   WHERE     request_id = gn_request_id
                                         AND TO_DATE (created_at, 'YYYY-MM-DD') <=
                                             TO_DATE (pv_period_end_date,
                                                      'RRRR/MM/DD HH24:MI:SS')
                                GROUP BY period_end_date) a;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_acq_begining_balance         := NULL;
                            ln_acq_earned                   := NULL;
                            ln_acq_reward                   := NULL;
                            ln_acq_expired                  := NULL;
                            ln_acq_returned                 := NULL;
                            ln_acq_ending_balance           := NULL;
                            ln_engagement_reward            := NULL;
                            LN_FINAL_ACQ_BEGINING_BALANCE   := NULL;
                            ln_final_acq_earned             := NULL;
                            ln_final_acq_reward             := NULL;
                            ln_final_acq_expired            := NULL;
                            ln_final_acq_returned           := NULL;
                            ln_final_acq_ending_balance     := NULL;
                            ln_final_engagement_reward      := NULL;
                    END;

                    lv_line1   :=
                           'Total Points'
                        || gv_delimeter
                        || ln_acq_begining_balance
                        || gv_delimeter
                        || ln_acq_earned
                        || gv_delimeter
                        || gv_delimeter
                        || ln_acq_reward
                        || gv_delimeter
                        || gv_delimeter
                        || ln_acq_expired
                        || gv_delimeter
                        || gv_delimeter
                        || ln_acq_returned
                        || gv_delimeter
                        || gv_delimeter
                        || ln_acq_closed_member
                        || gv_delimeter
                        || gv_delimeter
                        || ln_acq_ending_balance
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || ln_engagement_reward;
                    lv_line2   :=
                           'Value'
                        || gv_delimeter
                        || pn_points_amt
                        || gv_delimeter
                        || pn_points_amt
                        || gv_delimeter
                        || gv_delimeter
                        || pn_points_amt
                        || gv_delimeter
                        || gv_delimeter
                        || pn_points_amt
                        || gv_delimeter
                        || gv_delimeter
                        || pn_points_amt
                        || gv_delimeter
                        || gv_delimeter
                        || pn_points_amt
                        || gv_delimeter
                        || gv_delimeter
                        || pn_points_amt
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || pn_points_amt;
                    lv_line3   :=
                           'Total Dollar'
                        || gv_delimeter
                        || ln_final_acq_begining_balance
                        || gv_delimeter
                        || ln_final_acq_earned
                        || gv_delimeter
                        || gv_delimeter
                        || ln_final_acq_reward
                        || gv_delimeter
                        || gv_delimeter
                        || ln_final_acq_expired
                        || gv_delimeter
                        || gv_delimeter
                        || ln_final_acq_returned
                        || gv_delimeter
                        || gv_delimeter
                        || ln_final_acq_closed_member
                        || gv_delimeter
                        || gv_delimeter
                        || ln_final_acq_ending_balance
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || ln_final_engagement_reward;
                    -- 1.1
                    lv_file_name   :=
                           lv_vs_file_name
                        || '_'
                        || lv_period_name
                        || '_'
                        || lv_ou_short_name
                        || '_'
                        || pv_type
                        || '_'
                        || gn_request_id
                        || '_'
                        || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')
                        || '.txt';

                    --                END IF;

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Supporting File Name is - ' || lv_file_name);
                    lv_output_file   :=
                        UTL_FILE.fopen (lv_file_dir, lv_file_name, 'W' --opening the file in write mode
                                                                      ,
                                        32767);

                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        FOR i IN op_file_can_points
                        LOOP
                            lv_line   := i.line;
                            UTL_FILE.put_line (lv_output_file, lv_line);
                        END LOOP;

                        --1.1 changes
                        UTL_FILE.put_line (lv_output_file, lv_line1);
                        UTL_FILE.put_line (lv_output_file, lv_line2);
                        UTL_FILE.put_line (lv_output_file, lv_line3);
                    --1.1 changes
                    ELSE
                        lv_err_msg      :=
                            SUBSTR (
                                   'Error in Opening the  data file for writing. Error is : '
                                || SQLERRM,
                                1,
                                2000);
                        write_log (lv_err_msg);
                        x_ret_code      := gn_error;
                        x_ret_message   := lv_err_msg;
                        RETURN;
                    END IF;

                    UTL_FILE.fclose (lv_output_file);
                ELSIF pv_type = 'Coupon' AND pv_method = 'A'
                THEN
                    lv_file_name   :=
                           lv_vs_file_name
                        || '_'
                        || lv_period_name
                        || '_'
                        || lv_ou_short_name
                        || '_'
                        || pv_type
                        || '_'
                        || gn_request_id
                        || '_'
                        || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')
                        || '.txt';

                    --                END IF;
                    -- 1.1 changes
                    -- query to get brokage details
                    BEGIN
                        SELECT month1_amount, month2_amount, month3_amount,
                               month1_vs_brokage, month2_vs_brokage, month3_vs_brokage,
                               month1_brokage_amt, month2_brokage_amt, month3_brokage_amt,
                               period_type
                          INTO ln_month1_amount, ln_month2_amount, ln_month3_amount, ln_month1_vs_brokage,
                                               ln_month2_vs_brokage, ln_month3_vs_brokage, ln_month1_brokage_amt,
                                               ln_month2_brokage_amt, ln_month3_brokage_amt, lv_period_type
                          FROM xxdo.xxd_oe_us_loyalty_brok_dtls_t
                         WHERE request_id = gn_request_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_month1_amount        := NULL;
                            ln_month2_amount        := NULL;
                            ln_month3_amount        := NULL;
                            ln_month1_vs_brokage    := NULL;
                            ln_month2_vs_brokage    := NULL;
                            ln_month3_vs_brokage    := NULL;
                            ln_month1_brokage_amt   := NULL;
                            ln_month2_brokage_amt   := NULL;
                            ln_month3_brokage_amt   := NULL;
                            lv_period_type          := NULL;
                    END;

                    FND_FILE.PUT_LINE (FND_FILE.LOG, '1');

                    --                   query to get summaries
                    BEGIN
                        SELECT (SELECT starting_balance
                                  FROM xxdo.xxd_oe_us_loyalty_card_t
                                 WHERE TO_DATE (date_at, 'yyyy-mm-dd') =
                                       first_day) begining_balance,
                               issued,
                               -1 * redeemed,
                               -1 * expired,
                               -1 * invalidated,
                               reissued,
                               (SELECT ending_balance
                                  FROM xxdo.xxd_oe_us_loyalty_card_t
                                 WHERE TO_DATE (date_at, 'YYYY-MM-DD') =
                                       LAST_DAY) ending_balance,
                                 (SELECT starting_balance
                                    FROM xxdo.xxd_oe_us_loyalty_card_t
                                   WHERE TO_DATE (date_at, 'yyyy-mm-dd') =
                                         first_day)
                               * cost sum_begining_balance,
                               issued * cost sum_issued,
                               -1 * (redeemed * cost) sum_redeemed,
                               -1 * (expired * cost) sum_expired,
                               -1 * (invalidated * cost) sum_invalidated,
                               reissued * cost sum_reissued,
                                 (SELECT ending_balance
                                    FROM xxdo.xxd_oe_us_loyalty_card_t
                                   WHERE TO_DATE (date_at, 'YYYY-MM-DD') =
                                         LAST_DAY)
                               * cost sum_ending_balance,
                               cost
                          INTO ln_begining_balance, ln_issued, ln_redeemed, ln_expired,
                                                  ln_invalidated, ln_reissued, ln_ending_balance,
                                                  ln_sum_begining_balance, ln_sum_issued, ln_sum_redeemed,
                                                  ln_sum_expired, ln_sum_invalidated, ln_sum_reissued,
                                                  ln_sum_ending_balance, ln_cost
                          FROM (  SELECT LAST_DAY (TO_DATE (period_end_date, 'MM/DD/YYYY')) LAST_DAY, ADD_MONTHS (LAST_DAY (TO_DATE (period_end_date, 'MM/DD/YYYY')), -1) + 1 first_day, SUM (issued) issued,
                                         SUM (redeemed) redeemed, SUM (expired) expired, SUM (invalidated) invalidated,
                                         SUM (reissued) reissued, cost
                                    FROM xxdo.xxd_oe_us_loyalty_card_t
                                   WHERE TO_DATE (period_end_date,
                                                  'MM/DD/YYYY') =
                                         TO_DATE (pv_period_end_date,
                                                  'RRRR/MM/DD HH24:MI:SS')
                                GROUP BY period_end_date, cost);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_begining_balance       := NULL;
                            ln_issued                 := NULL;
                            ln_redeemed               := NULL;
                            ln_expired                := NULL;
                            ln_invalidated            := NULL;
                            ln_reissued               := NULL;
                            ln_ending_balance         := NULL;
                            ln_sum_begining_balance   := NULL;
                            ln_sum_issued             := NULL;
                            ln_sum_redeemed           := NULL;
                            ln_sum_expired            := NULL;
                            ln_sum_invalidated        := NULL;
                            ln_sum_reissued           := NULL;
                            ln_sum_ending_balance     := NULL;
                            ln_cost                   := NULL;
                    END;

                    --FND_FILE.PUT_LINE(FND_FILE.LOG,'2');
                    lv_line1   :=
                           ' '
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || ln_begining_balance
                        || gv_delimeter
                        || ln_issued
                        || gv_delimeter
                        || ln_redeemed
                        || gv_delimeter
                        || ln_expired
                        || gv_delimeter
                        || ln_invalidated
                        || gv_delimeter
                        || ln_reissued
                        || gv_delimeter
                        || ln_ending_balance;
                    -- FND_FILE.PUT_LINE(FND_FILE.LOG,'3');
                    lv_line2   :=
                           ' '
                        || gv_delimeter
                        || gv_delimeter
                        || 'Coupon Value in USD'
                        || gv_delimeter
                        || ln_cost
                        || gv_delimeter
                        || ln_cost
                        || gv_delimeter
                        || ln_cost
                        || gv_delimeter
                        || ln_cost
                        || gv_delimeter
                        || ln_cost
                        || gv_delimeter
                        || ln_cost
                        || gv_delimeter
                        || ln_cost;
                    --  FND_FILE.PUT_LINE(FND_FILE.LOG,'4');
                    lv_line3   :=
                           ' '
                        || gv_delimeter
                        || gv_delimeter
                        || 'Ending Balance @'
                        || pv_period_end_date
                        || gv_delimeter
                        || ln_sum_begining_balance
                        || gv_delimeter
                        || ln_sum_issued
                        || gv_delimeter
                        || ln_sum_redeemed
                        || gv_delimeter
                        || ln_sum_expired
                        || gv_delimeter
                        || ln_sum_invalidated
                        || gv_delimeter
                        || ln_sum_reissued
                        || gv_delimeter
                        || ln_sum_ending_balance;
                    --FND_FILE.PUT_LINE(FND_FILE.LOG,'5');
                    ln_total_brokage   :=
                          NVL (ln_month1_brokage_amt, 0)
                        + NVL (ln_month2_brokage_amt, 0)
                        + NVL (ln_month3_brokage_amt, 0);
                    ln_final_amount   :=
                          NVL (ln_sum_ending_balance, 0)
                        + (NVL (ln_month1_brokage_amt, 0) + NVL (ln_month2_brokage_amt, 0) + NVL (ln_month3_brokage_amt, 0));

                    IF lv_period_type = 'Quarter'
                    THEN
                        --FND_FILE.PUT_LINE(FND_FILE.LOG,'6');
                        lv_line4   :=
                               ' '
                            || gv_delimeter
                            || gv_delimeter
                            || 'Month1 Amount:'
                            || ln_month1_amount
                            || ' * '
                            || 'Month1 Breakage%:'
                            || ln_month1_vs_brokage
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || ln_month1_brokage_amt;
                        --   FND_FILE.PUT_LINE(FND_FILE.LOG,'7');
                        lv_line5   :=
                               ' '
                            || gv_delimeter
                            || gv_delimeter
                            || 'Month2 Amount:'
                            || ln_month2_amount
                            || ' * '
                            || 'Month2 Breakage%:'
                            || ln_month2_vs_brokage
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || ln_month2_brokage_amt;
                        --  FND_FILE.PUT_LINE(FND_FILE.LOG,'8');
                        lv_line6   :=
                               ' '
                            || gv_delimeter
                            || gv_delimeter
                            || 'Month3 Amount:'
                            || ln_month3_amount
                            || ' * '
                            || 'Month3 Breakage%:'
                            || ln_month3_vs_brokage
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || ln_month3_brokage_amt;
                        --FND_FILE.PUT_LINE(FND_FILE.LOG,'9');
                        lv_line7   :=
                               ' '
                            || gv_delimeter
                            || gv_delimeter
                            || 'Total Breakage:'
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || ln_total_brokage;
                        --FND_FILE.PUT_LINE(FND_FILE.LOG,'10');
                        lv_line8   :=
                               ' '
                            || gv_delimeter
                            || gv_delimeter
                            || 'Total Liability Balance:'
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || ln_final_amount;
                    --FND_FILE.PUT_LINE(FND_FILE.LOG,'11');

                    ELSE
                        --FND_FILE.PUT_LINE(FND_FILE.LOG,'12');
                        lv_line4   :=
                               ' '
                            || gv_delimeter
                            || gv_delimeter
                            || 'Total Breakage of Previous Quarter:'
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || ln_total_brokage;
                        lv_line5   :=
                               ' '
                            || gv_delimeter
                            || gv_delimeter
                            || 'Total Liability Balance:'
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || ln_final_amount;
                    END IF;

                    --FND_FILE.PUT_LINE(FND_FILE.LOG,'13');
                    -- 1.1. changes end

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Supporting File Name is - ' || lv_file_name);
                    lv_output_file   :=
                        UTL_FILE.fopen (lv_file_dir, lv_file_name, 'W' --opening the file in write mode
                                                                      ,
                                        32767);

                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        FOR i IN op_file_us_coupon
                        LOOP
                            lv_line   := i.line;
                            UTL_FILE.put_line (lv_output_file, lv_line);
                        END LOOP;

                        IF lv_period_type = 'Quarter'
                        THEN
                            UTL_FILE.put_line (lv_output_file, lv_line1);
                            UTL_FILE.put_line (lv_output_file, lv_line2);
                            UTL_FILE.put_line (lv_output_file, lv_line3);
                            UTL_FILE.put_line (lv_output_file, lv_line4);
                            UTL_FILE.put_line (lv_output_file, lv_line5);
                            UTL_FILE.put_line (lv_output_file, lv_line6);
                            UTL_FILE.put_line (lv_output_file, lv_line7);
                            UTL_FILE.put_line (lv_output_file, lv_line8);
                        ELSE
                            UTL_FILE.put_line (lv_output_file, lv_line1);
                            UTL_FILE.put_line (lv_output_file, lv_line2);
                            UTL_FILE.put_line (lv_output_file, lv_line3);
                            UTL_FILE.put_line (lv_output_file, lv_line4);
                            UTL_FILE.put_line (lv_output_file, lv_line5);
                        END IF;
                    ELSE
                        lv_err_msg      :=
                            SUBSTR (
                                   'Error in Opening the  data file for writing. Error is : '
                                || SQLERRM,
                                1,
                                2000);
                        write_log (lv_err_msg);
                        x_ret_code      := gn_error;
                        x_ret_message   := lv_err_msg;
                        RETURN;
                    END IF;

                    UTL_FILE.fclose (lv_output_file);
                ELSIF pv_type = 'Coupon' AND pv_method = 'B'
                THEN
                    lv_file_name   :=
                           lv_vs_file_name
                        || '_'
                        || lv_period_name
                        || '_'
                        || lv_ou_short_name
                        || '_'
                        || pv_type
                        || '_'
                        || gn_request_id
                        || '_'
                        || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')
                        || '.txt';

                    --                END IF;
                    -- 1.1 changes
                    -- query to get brokage details
                    BEGIN
                        SELECT month1_amount, month2_amount, month3_amount,
                               month1_vs_brokage, month2_vs_brokage, month3_vs_brokage,
                               month1_brokage_amt, month2_brokage_amt, month3_brokage_amt,
                               period_type
                          INTO ln_month1_amount, ln_month2_amount, ln_month3_amount, ln_month1_vs_brokage,
                                               ln_month2_vs_brokage, ln_month3_vs_brokage, ln_month1_brokage_amt,
                                               ln_month2_brokage_amt, ln_month3_brokage_amt, lv_period_type
                          FROM xxdo.xxd_oe_can_loyalty_brok_dtls_t
                         WHERE request_id = gn_request_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_month1_amount        := NULL;
                            ln_month2_amount        := NULL;
                            ln_month3_amount        := NULL;
                            ln_month1_vs_brokage    := NULL;
                            ln_month2_vs_brokage    := NULL;
                            ln_month3_vs_brokage    := NULL;
                            ln_month1_brokage_amt   := NULL;
                            ln_month2_brokage_amt   := NULL;
                            ln_month3_brokage_amt   := NULL;
                            lv_period_type          := NULL;
                    END;

                    --                   query to get summaries
                    BEGIN
                        SELECT (SELECT strating_balance
                                  FROM xxdo.xxd_oe_can_loyalty_card_t
                                 WHERE     TO_DATE (date_at, 'yyyy-mm-dd') =
                                           first_day
                                       AND strating_balance <> 0)
                                   begining_balance,
                               issued,
                               -1 * redeemed,
                               -1 * expired,
                               -1 * invalidated,
                               reissued,
                               (SELECT ending_balance
                                  FROM xxdo.xxd_oe_can_loyalty_card_t
                                 WHERE     TO_DATE (date_at, 'YYYY-MM-DD') =
                                           LAST_DAY
                                       AND strating_balance <> 0)
                                   ending_balance,
                                 (SELECT strating_balance
                                    FROM xxdo.xxd_oe_can_loyalty_card_t
                                   WHERE     TO_DATE (date_at, 'yyyy-mm-dd') =
                                             first_day
                                         AND strating_balance <> 0)
                               * cost
                                   sum_begining_balance,
                               issued * cost
                                   sum_issued,
                               -1 * (redeemed * cost)
                                   sum_redeemed,
                               -1 * (expired * cost)
                                   sum_expired,
                               -1 * (invalidated * cost)
                                   sum_invalidated,
                               reissued * cost
                                   sum_reissued,
                                 (SELECT ending_balance
                                    FROM xxdo.xxd_oe_can_loyalty_card_t
                                   WHERE     TO_DATE (date_at, 'YYYY-MM-DD') =
                                             LAST_DAY
                                         AND strating_balance <> 0)
                               * cost
                                   sum_ending_balance,
                               cost
                          INTO ln_begining_balance, ln_issued, ln_redeemed, ln_expired,
                                                  ln_invalidated, ln_reissued, ln_ending_balance,
                                                  ln_sum_begining_balance, ln_sum_issued, ln_sum_redeemed,
                                                  ln_sum_expired, ln_sum_invalidated, ln_sum_reissued,
                                                  ln_sum_ending_balance, ln_cost
                          FROM (  SELECT LAST_DAY (TO_DATE (period_end_date, 'MM/DD/YYYY')) LAST_DAY, ADD_MONTHS (LAST_DAY (TO_DATE (period_end_date, 'MM/DD/YYYY')), -1) + 1 first_day, SUM (issued) issued,
                                         SUM (redeemed) redeemed, SUM (expired) expired, SUM (invalidated) invalidated,
                                         SUM (reissued) reissued, cost
                                    FROM xxdo.xxd_oe_can_loyalty_card_t
                                   WHERE TO_DATE (period_end_date,
                                                  'MM/DD/YYYY') =
                                         TO_DATE (pv_period_end_date,
                                                  'RRRR/MM/DD HH24:MI:SS')
                                GROUP BY period_end_date, cost);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_begining_balance       := NULL;
                            ln_issued                 := NULL;
                            ln_redeemed               := NULL;
                            ln_expired                := NULL;
                            ln_invalidated            := NULL;
                            ln_reissued               := NULL;
                            ln_ending_balance         := NULL;
                            ln_sum_begining_balance   := NULL;
                            ln_sum_issued             := NULL;
                            ln_sum_redeemed           := NULL;
                            ln_sum_expired            := NULL;
                            ln_sum_invalidated        := NULL;
                            ln_sum_reissued           := NULL;
                            ln_sum_ending_balance     := NULL;
                            ln_cost                   := NULL;
                    END;

                    lv_line1   :=
                           ' '
                        || gv_delimeter
                        || gv_delimeter
                        || gv_delimeter
                        || ln_begining_balance
                        || gv_delimeter
                        || ln_issued
                        || gv_delimeter
                        || gv_delimeter                                     --
                        || ln_redeemed
                        || gv_delimeter
                        || gv_delimeter                                     --
                        || ln_expired
                        || gv_delimeter
                        || gv_delimeter                                     --
                        || ln_invalidated
                        || gv_delimeter
                        || gv_delimeter                                     --
                        || ln_reissued
                        || gv_delimeter
                        || gv_delimeter                                     --
                        || ln_ending_balance;
                    lv_line2   :=
                           ' '
                        || gv_delimeter
                        || gv_delimeter
                        || 'Coupon Value in USD'
                        || gv_delimeter
                        || ln_cost
                        || gv_delimeter
                        || ln_cost
                        || gv_delimeter
                        || gv_delimeter                                     --
                        || ln_cost
                        || gv_delimeter
                        || gv_delimeter                                     --
                        || ln_cost
                        || gv_delimeter
                        || gv_delimeter                                     --
                        || ln_cost
                        || gv_delimeter
                        || gv_delimeter                                     --
                        || ln_cost
                        || gv_delimeter
                        || gv_delimeter                                     --
                        || ln_cost;
                    lv_line3   :=
                           ' '
                        || gv_delimeter
                        || gv_delimeter
                        || 'Ending Balance @'
                        || pv_period_end_date
                        || gv_delimeter
                        || ln_sum_begining_balance
                        || gv_delimeter
                        || ln_sum_issued
                        || gv_delimeter
                        || gv_delimeter                                     --
                        || ln_sum_redeemed
                        || gv_delimeter
                        || gv_delimeter                                     --
                        || ln_sum_expired
                        || gv_delimeter
                        || gv_delimeter                                     --
                        || ln_sum_invalidated
                        || gv_delimeter
                        || gv_delimeter                                     --
                        || ln_sum_reissued
                        || gv_delimeter
                        || gv_delimeter                                     --
                        || ln_sum_ending_balance;
                    ln_total_brokage   :=
                          NVL (ln_month1_brokage_amt, 0)
                        + NVL (ln_month2_brokage_amt, 0)
                        + NVL (ln_month3_brokage_amt, 0);
                    ln_final_amount   :=
                          NVL (ln_sum_ending_balance, 0)
                        + (NVL (ln_month1_brokage_amt, 0) + NVL (ln_month2_brokage_amt, 0) + NVL (ln_month3_brokage_amt, 0));

                    IF lv_period_type = 'Quarter'
                    THEN
                        lv_line4   :=
                               ' '
                            || gv_delimeter
                            || gv_delimeter
                            || 'Month1 Amount:'
                            || ln_month1_amount
                            || ' * '
                            || 'Month1 Breakage%:'
                            || ln_month1_vs_brokage
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || ln_month1_brokage_amt;
                        lv_line5   :=
                               ' '
                            || gv_delimeter
                            || gv_delimeter
                            || 'Month2 Amount:'
                            || ln_month2_amount
                            || ' * '
                            || 'Month2 Breakage%:'
                            || ln_month2_vs_brokage
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || ln_month2_brokage_amt;
                        lv_line6   :=
                               ' '
                            || gv_delimeter
                            || gv_delimeter
                            || 'Month3 Amount:'
                            || ln_month3_amount
                            || ' * '
                            || 'Month3 Breakage%:'
                            || ln_month3_vs_brokage
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || ln_month3_brokage_amt;
                        lv_line7   :=
                               ' '
                            || gv_delimeter
                            || gv_delimeter
                            || 'Total Breakage:'
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || ln_total_brokage;
                        lv_line8   :=
                               ' '
                            || gv_delimeter
                            || gv_delimeter
                            || 'Total Liability Balance:'
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || ln_final_amount;
                    ELSE
                        lv_line4   :=
                               ' '
                            || gv_delimeter
                            || gv_delimeter
                            || 'Total Breakage of Previous Quarter:'
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || ln_total_brokage;
                        lv_line5   :=
                               ' '
                            || gv_delimeter
                            || gv_delimeter
                            || 'Total Liability Balance:'
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || gv_delimeter
                            || ln_final_amount;
                    END IF;



                    -- 1.1 changes



                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Supporting File Name is - ' || lv_file_name);
                    lv_output_file   :=
                        UTL_FILE.fopen (lv_file_dir, lv_file_name, 'W' --opening the file in write mode
                                                                      ,
                                        32767);

                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        FOR i IN op_file_can_coupon
                        LOOP
                            lv_line   := i.line;
                            UTL_FILE.put_line (lv_output_file, lv_line);
                        END LOOP;

                        IF lv_period_type = 'Quarter'
                        THEN
                            UTL_FILE.put_line (lv_output_file, lv_line1);
                            UTL_FILE.put_line (lv_output_file, lv_line2);
                            UTL_FILE.put_line (lv_output_file, lv_line3);
                            UTL_FILE.put_line (lv_output_file, lv_line4);
                            UTL_FILE.put_line (lv_output_file, lv_line5);
                            UTL_FILE.put_line (lv_output_file, lv_line6);
                            UTL_FILE.put_line (lv_output_file, lv_line7);
                            UTL_FILE.put_line (lv_output_file, lv_line8);
                        ELSE
                            UTL_FILE.put_line (lv_output_file, lv_line1);
                            UTL_FILE.put_line (lv_output_file, lv_line2);
                            UTL_FILE.put_line (lv_output_file, lv_line3);
                            UTL_FILE.put_line (lv_output_file, lv_line4);
                            UTL_FILE.put_line (lv_output_file, lv_line5);
                        END IF;
                    ELSE
                        lv_err_msg      :=
                            SUBSTR (
                                   'Error in Opening the  data file for writing. Error is : '
                                || SQLERRM,
                                1,
                                2000);
                        write_log (lv_err_msg);
                        x_ret_code      := gn_error;
                        x_ret_message   := lv_err_msg;
                        RETURN;
                    END IF;

                    UTL_FILE.fclose (lv_output_file);
                END IF;
            END IF;
        END IF;
    EXCEPTION
        WHEN UTL_FILE.invalid_path
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_PATH: File location or filename was invalid.';
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20101, lv_err_msg);
        WHEN UTL_FILE.invalid_mode
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_MODE: The open_mode parameter in FOPEN was invalid.';
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20102, lv_err_msg);
        WHEN UTL_FILE.invalid_filehandle
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_FILEHANDLE: The file handle was invalid.';
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20103, lv_err_msg);
        WHEN UTL_FILE.invalid_operation
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_OPERATION: The file could not be opened or operated on as requested.';
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20104, lv_err_msg);
        WHEN UTL_FILE.read_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'READ_ERROR: An operating system error occurred during the read operation.';
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20105, lv_err_msg);
        WHEN UTL_FILE.write_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'WRITE_ERROR: An operating system error occurred during the write operation.';
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20106, lv_err_msg);
        WHEN UTL_FILE.internal_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      := 'INTERNAL_ERROR: An unspecified error in PL/SQL.';
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20107, lv_err_msg);
        WHEN UTL_FILE.invalid_filename
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_FILENAME: The filename parameter is invalid.';
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20108, lv_err_msg);
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
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20109, lv_err_msg);
    END write_op_file;

    PROCEDURE update_valueset_prc (pv_file_path IN VARCHAR2)
    IS
        lv_user_name      VARCHAR2 (100);
        lv_request_info   VARCHAR2 (100);
    BEGIN
        lv_user_name      := NULL;
        lv_request_info   := NULL;

        BEGIN
            SELECT fu.user_name, TO_CHAR (fcr.actual_start_date, 'MM/DD/RRRR HH24:MI:SS')
              INTO lv_user_name, lv_request_info
              FROM apps.fnd_concurrent_requests fcr, apps.fnd_user fu
             WHERE request_id = gn_request_id AND requested_by = fu.user_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_user_name      := NULL;
                lv_request_info   := NULL;
        END;

        UPDATE apps.fnd_flex_values_vl ffvl
           SET ffvl.attribute5 = lv_user_name, ffvl.attribute6 = lv_request_info
         WHERE     NVL (TRUNC (ffvl.start_date_active), TRUNC (SYSDATE)) <=
                   TRUNC (SYSDATE)
               AND NVL (TRUNC (ffvl.end_date_active), TRUNC (SYSDATE)) >=
                   TRUNC (SYSDATE)
               AND ffvl.enabled_flag = 'Y'
               AND ffvl.description = 'LOYALTY'
               AND ffvl.flex_value = pv_file_path
               AND ffvl.flex_value_set_id IN
                       (SELECT flex_value_set_id
                          FROM apps.fnd_flex_value_sets
                         WHERE flex_value_set_name =
                               'XXD_GL_AAR_FILE_DETAILS_VS');

        COMMIT;
    END update_valueset_prc;

    PROCEDURE write_ret_recon_file (pv_type         IN     VARCHAR2,
                                    pv_method       IN     VARCHAR2,
                                    pv_file_path    IN     VARCHAR2,
                                    x_ret_code         OUT VARCHAR2,
                                    x_ret_message      OUT VARCHAR2)
    IS
        CURSOR ret_reconcilation IS
              SELECT entity_unique_identifier || CHR (9) || account_number || CHR (9) || key3 || CHR (9) || key || CHR (9) || key5 || CHR (9) || key6 || CHR (9) || key7 || CHR (9) || key8 || CHR (9) || key9 || CHR (9) || key10 || CHR (9) || period_end_date || CHR (9) || subledger_rep_bal || CHR (9) || subledger_alt_bal || CHR (9) || MAX (subledger_acc_bal) line
                FROM xxdo.xxd_oe_us_loyalty_points_t
               WHERE     1 = 1
                     AND request_id = gn_request_id
                     AND pv_type = 'Points'
                     AND pv_method = 'A'
            GROUP BY entity_unique_identifier, account_number, key3,
                     key, key5, key6,
                     key7, key8, key9,
                     key10, period_end_date, subledger_rep_bal,
                     subledger_alt_bal
            UNION ALL
              SELECT entity_unique_identifier || CHR (9) || account || CHR (9) || key3 || CHR (9) || key || CHR (9) || key5 || CHR (9) || key6 || CHR (9) || key7 || CHR (9) || key8 || CHR (9) || key9 || CHR (9) || key10 || CHR (9) || period_end_date || CHR (9) || subledger_rep_bal || CHR (9) || subledger_alt_bal || CHR (9) || MAX (subledger_acc_bal) line
                FROM xxdo.xxd_oe_can_loyalty_points_t
               WHERE     1 = 1
                     AND request_id = gn_request_id
                     AND pv_type = 'Points'
                     AND pv_method = 'B'
            GROUP BY entity_unique_identifier, account, key3,
                     key, key5, key6,
                     key7, key8, key9,
                     key10, period_end_date, subledger_rep_bal,
                     subledger_alt_bal
            UNION ALL
              SELECT entity_unique_identifier || CHR (9) || account_number || CHR (9) || key3 || CHR (9) || key || CHR (9) || key5 || CHR (9) || key6 || CHR (9) || key7 || CHR (9) || key8 || CHR (9) || key9 || CHR (9) || key10 || CHR (9) || period_end_date || CHR (9) || subledger_rep_bal || CHR (9) || subledger_alt_bal || CHR (9) || MAX (subledger_acc_bal) line
                FROM xxdo.xxd_oe_us_loyalty_card_t
               WHERE     1 = 1
                     AND request_id = gn_request_id
                     AND pv_type = 'Coupon'
                     AND pv_method = 'A'
            GROUP BY entity_unique_identifier, account_number, key3,
                     key, key5, key6,
                     key7, key8, key9,
                     key10, period_end_date, subledger_rep_bal,
                     subledger_alt_bal
            UNION ALL
              SELECT entity_unique_identifier || CHR (9) || account_number || CHR (9) || key3 || CHR (9) || key || CHR (9) || key5 || CHR (9) || key6 || CHR (9) || key7 || CHR (9) || key8 || CHR (9) || key9 || CHR (9) || key10 || CHR (9) || period_end_date || CHR (9) || subledger_rep_bal || CHR (9) || subledger_alt_bal || CHR (9) || MAX (subledger_acc_bal) line
                FROM xxdo.xxd_oe_can_loyalty_card_t
               WHERE     1 = 1
                     AND request_id = gn_request_id
                     AND pv_type = 'Coupon'
                     AND pv_method = 'B'
            GROUP BY entity_unique_identifier, account_number, key3,
                     key, key5, key6,
                     key7, key8, key9,
                     key10, period_end_date, subledger_rep_bal,
                     subledger_alt_bal;

        --DEFINE VARIABLES

        lv_file_path              VARCHAR2 (360);
        lv_output_file            UTL_FILE.file_type;
        lv_outbound_file          VARCHAR2 (360);
        lv_err_msg                VARCHAR2 (2000) := NULL;
        lv_line                   VARCHAR2 (32767) := NULL;
        lv_vs_default_file_path   VARCHAR2 (2000);
        lv_vs_file_path           VARCHAR2 (200);
        lv_vs_file_name           VARCHAR2 (200);
        l_line                    VARCHAR2 (4000);
    BEGIN
        FOR i IN ret_reconcilation
        LOOP
            l_line   := i.line;
            fnd_file.put_line (fnd_file.output, l_line);
        END LOOP;

        IF pv_file_path IS NOT NULL
        THEN
            BEGIN
                SELECT ffvl.attribute2, ffvl.attribute4
                  INTO lv_vs_file_path, lv_vs_file_name
                  FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                 WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                       AND fvs.flex_value_set_name =
                           'XXD_GL_AAR_FILE_DETAILS_VS'
                       AND NVL (TRUNC (ffvl.start_date_active),
                                TRUNC (SYSDATE)) <=
                           TRUNC (SYSDATE)
                       AND NVL (TRUNC (ffvl.end_date_active),
                                TRUNC (SYSDATE)) >=
                           TRUNC (SYSDATE)
                       AND ffvl.enabled_flag = 'Y'
                       AND ffvl.description = 'LOYALTY'
                       AND ffvl.flex_value = pv_file_path;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_vs_file_path   := NULL;
                    lv_vs_file_name   := NULL;
            END;

            IF     lv_vs_file_name IS NOT NULL
               AND NVL (lv_vs_file_path, 'X') <> 'NA'
            THEN
                IF lv_vs_file_path IS NOT NULL
                THEN
                    lv_file_path   := lv_vs_file_path;
                ELSE
                    BEGIN
                        SELECT ffvl.description
                          INTO lv_vs_default_file_path
                          FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                         WHERE     fvs.flex_value_set_id =
                                   ffvl.flex_value_set_id
                               AND fvs.flex_value_set_name =
                                   'XXD_AAR_GL_BL_FILE_PATH_VS'
                               AND NVL (TRUNC (ffvl.start_date_active),
                                        TRUNC (SYSDATE)) <=
                                   TRUNC (SYSDATE)
                               AND NVL (TRUNC (ffvl.end_date_active),
                                        TRUNC (SYSDATE)) >=
                                   TRUNC (SYSDATE)
                               AND ffvl.enabled_flag = 'Y';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_vs_default_file_path   := NULL;
                    END;

                    lv_file_path   := lv_vs_default_file_path;
                END IF;

                -- WRITE INTO BL FOLDER

                lv_outbound_file   :=
                       lv_vs_file_name
                    || '_'
                    || gn_request_id
                    || '_'
                    || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')
                    || '.txt';

                fnd_file.put_line (fnd_file.LOG,
                                   'BL File Name is - ' || lv_outbound_file);
                lv_output_file   :=
                    UTL_FILE.fopen (lv_file_path, lv_outbound_file, 'W' --opening the file in write mode
                                                                       ,
                                    32767);

                IF UTL_FILE.is_open (lv_output_file)
                THEN
                    FOR i IN ret_reconcilation
                    LOOP
                        lv_line   := i.line;
                        UTL_FILE.put_line (lv_output_file, lv_line);
                    END LOOP;
                ELSE
                    lv_err_msg      :=
                        SUBSTR (
                               'Error in Opening the Account Balance data file for writing. Error is : '
                            || SQLERRM,
                            1,
                            2000);
                    write_log (lv_err_msg);
                    x_ret_code      := gn_error;
                    x_ret_message   := lv_err_msg;
                    RETURN;
                END IF;

                UTL_FILE.fclose (lv_output_file);
            END IF;
        END IF;
    EXCEPTION
        WHEN UTL_FILE.invalid_path
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_PATH: File location or filename was invalid.';
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20101, lv_err_msg);
        WHEN UTL_FILE.invalid_mode
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_MODE: The open_mode parameter in FOPEN was invalid.';
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20102, lv_err_msg);
        WHEN UTL_FILE.invalid_filehandle
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_FILEHANDLE: The file handle was invalid.';
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20103, lv_err_msg);
        WHEN UTL_FILE.invalid_operation
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_OPERATION: The file could not be opened or operated on as requested.';
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20104, lv_err_msg);
        WHEN UTL_FILE.read_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'READ_ERROR: An operating system error occurred during the read operation.';
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20105, lv_err_msg);
        WHEN UTL_FILE.write_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'WRITE_ERROR: An operating system error occurred during the write operation.';
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20106, lv_err_msg);
        WHEN UTL_FILE.internal_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      := 'INTERNAL_ERROR: An unspecified error in PL/SQL.';
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20107, lv_err_msg);
        WHEN UTL_FILE.invalid_filename
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_FILENAME: The filename parameter is invalid.';
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20108, lv_err_msg);
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
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20109, lv_err_msg);
    END write_ret_recon_file;

    -- function to get canada card amount

    FUNCTION get_can_coupon_amt (p_period_end_date IN DATE, p_request_id IN NUMBER, p_vs_1st_month_amt IN NUMBER
                                 , p_vs_2nd_month_amt IN NUMBER, p_vs_3rd_month_amt IN NUMBER, p_org_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_acq_ending_balance      NUMBER;
        ln_can_points_value        NUMBER;
        ln_period_year             NUMBER;
        ln_period_num              NUMBER;
        lv_period_name             VARCHAR2 (50);
        ln_ending_balance          NUMBER;
        ln_cost                    NUMBER;
        ln_1month_bro_amount       NUMBER;
        ln_2month_bro_amount       NUMBER;
        ln_3month_bro_amount       NUMBER;
        ln_can_card_cost           NUMBER;
        ln_end_bal_cost            NUMBER;
        lv_month1_brokarage        VARCHAR2 (20);
        lv_month2_brokarage        VARCHAR2 (20);
        lv_month3_brokarage        VARCHAR2 (20);
        ln_can_card_percen         NUMBER;
        ln_end_bal_cost_bro        NUMBER := 0;
        --1.1 changes
        ln_pre_qtr_brokage1        NUMBER;
        ln_pre_qtr_brokage2        NUMBER;
        ln_pre_qtr_brokage3        NUMBER;
        ld_last_qtr_per_end_date   DATE;
        ln_1month_amount           NUMBER;
        ln_2month_amount           NUMBER;
        ln_3month_amount           NUMBER;

        --1.1 changes
        CURSOR get_coupon_id_cur IS
            SELECT DISTINCT reward_id
              FROM xxdo.xxd_oe_can_loyalty_card_t
             WHERE request_id = p_request_id;
    BEGIN
        -- query to get the period details
        IF p_period_end_date IS NULL
        THEN
            BEGIN
                SELECT period_year, period_num, period_name
                  INTO ln_period_year, ln_period_num, lv_period_name
                  FROM apps.gl_periods a
                 WHERE     period_set_name = 'DO_FY_CALENDAR'
                       AND TRUNC (SYSDATE) BETWEEN start_date AND end_date;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_period_year   := NULL;
                    ln_period_num    := NULL;
                    lv_period_name   := NULL;
            END;
        ELSE
            BEGIN
                SELECT period_year, period_num, period_name
                  INTO ln_period_year, ln_period_num, lv_period_name
                  FROM apps.gl_periods
                 WHERE     period_set_name = 'DO_FY_CALENDAR'
                       AND p_period_end_date BETWEEN start_date AND end_date;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_period_year   := NULL;
                    ln_period_num    := NULL;
                    lv_period_name   := NULL;
            END;
        END IF;

        fnd_file.put_line (fnd_file.LOG, 'ln_period_year:' || ln_period_year);
        fnd_file.put_line (fnd_file.LOG, 'ln_period_num:' || ln_period_num);
        fnd_file.put_line (fnd_file.LOG, 'lv_period_name:' || lv_period_name);

        IF ln_period_num IN (3, 6, 9,
                             12)
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'This month is Quarter end' || lv_period_name);

            BEGIN
                SELECT SUM (ending_balance * cost)
                  INTO ln_end_bal_cost
                  FROM xxdo.xxd_oe_can_loyalty_card_t
                 WHERE     TO_DATE (date_at, 'YYYY-MM-DD') =
                           p_period_end_date
                       AND request_id = p_request_id;
            --fnd_file.put_line(fnd_file.log, 'acq ending balance' || ln_acq_ending_balance);

            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Failed to fetch acq ending balance' || SQLERRM);
                    ln_acq_ending_balance   := NULL;
            END;

            BEGIN
                SELECT SUM (issued * cost)
                  INTO ln_end_bal_cost_bro
                  FROM xxdo.xxd_oe_can_loyalty_card_t
                 WHERE     TO_DATE (date_at, 'YYYY-MM-DD') <=
                           p_period_end_date
                       AND request_id = p_request_id;

                fnd_file.put_line (
                    fnd_file.LOG,
                    'ln_end_bal_cost_bro:' || ln_end_bal_cost_bro);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Failed to fetch ending balance' || SQLERRM);
                    ln_end_bal_cost_bro   := NULL;
            END;

            fnd_file.put_line (fnd_file.LOG,
                               'LN_END_BAL_COST:' || ln_end_bal_cost);

            --FND_FILE.PUT_LINE(FND_FILE.LOG,'ln_cost'||ln_cost);

            -- query to fetch brokarage amount first time for september 2021 quarter
            SELECT ffvl.attribute1, ffvl.attribute2, ffvl.attribute3
              INTO lv_month1_brokarage, lv_month2_brokarage, lv_month3_brokarage
              FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
             WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                   AND fvs.flex_value_set_name = 'XXD_OE_LOYALTY_BROK_PER_VS'
                   AND NVL (TRUNC (ffvl.start_date_active), TRUNC (SYSDATE)) <=
                       TRUNC (SYSDATE)
                   AND NVL (TRUNC (ffvl.end_date_active), TRUNC (SYSDATE)) >=
                       TRUNC (SYSDATE)
                   AND ffvl.enabled_flag = 'Y';

            -- query to get 1st month brokarage in quarter

            BEGIN
                SELECT -1 * MAX (report_amount) * (p_vs_1st_month_amt / 100), MAX (report_amount)
                  INTO ln_1month_bro_amount, ln_1month_amount
                  FROM xxdo.xxd_oe_can_loyalty_card_t
                 WHERE     period_year = ln_period_year
                       AND period_month = ln_period_num - 2
                       AND org_id = p_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_1month_bro_amount   := 0;
            END;

            fnd_file.put_line (
                fnd_file.LOG,
                'ln_1month_bro_amount:' || ln_1month_bro_amount);

            -- query to get 2nd month brokarage in quarter
            BEGIN
                SELECT -1 * MAX (report_amount) * (p_vs_2nd_month_amt / 100), MAX (report_amount)
                  INTO ln_2month_bro_amount, ln_2month_amount
                  FROM xxdo.xxd_oe_can_loyalty_card_t
                 WHERE     period_year = ln_period_year
                       AND period_month = ln_period_num - 1
                       AND org_id = p_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_1month_bro_amount   := 0;
            END;

            fnd_file.put_line (
                fnd_file.LOG,
                'ln_2month_bro_amount:' || ln_2month_bro_amount);
            -- query to get 3rd month brokarage in quarter
            ln_3month_bro_amount   :=
                (ln_end_bal_cost_bro) * (p_vs_3rd_month_amt / 100);
            fnd_file.put_line (
                fnd_file.LOG,
                'ln_3month_bro_amount' || ln_3month_bro_amount);
            /* IF lv_period_name = 'SEP-22' THEN
                 ln_can_card_cost := ( -1 * ( ln_end_bal_cost ) ) + lv_month1_brokarage + lv_month2_brokarage + ln_3month_bro_amount
                 ;
             ELSE
                 ln_can_card_cost := ( -1 * ( ln_end_bal_cost ) ) + ln_1month_bro_amount + ln_2month_bro_amount + ln_3month_bro_amount
                 ;
             END IF;*/
            ln_can_card_cost   :=
                  -1
                * ((ln_end_bal_cost) + NVL (ln_1month_bro_amount, lv_month1_brokarage) + NVL (ln_2month_bro_amount, lv_month2_brokarage) + NVL (ln_3month_bro_amount, lv_month3_brokarage));

            fnd_file.put_line (fnd_file.LOG,
                               'ln_can_card_cost:' || ln_can_card_cost);

            -- UPDATE the ln_us_points_amt in custom table
            BEGIN
                UPDATE xxdo.xxd_oe_can_loyalty_card_t
                   SET report_amount = ln_can_card_cost, period_year = ln_period_year, period_month = ln_period_num,
                       period_name = lv_period_name, last_updated_by = gn_user_id, last_update_date = SYSDATE,
                       --1.1 changes start
                       future_attribute1 = ln_end_bal_cost, future_attribute2 = ln_1month_bro_amount, future_attribute3 = ln_2month_bro_amount,
                       future_attribute4 = ln_3month_bro_amount
                 --1.1 chages end

                 WHERE request_id = gn_request_id;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (fnd_file.LOG,
                                       'Update is failed:' || SQLERRM);
            END;

            --
            -- insert the values into custom table for displaying in output file.
            -- 1.1
            BEGIN
                INSERT INTO xxdo.xxd_oe_can_loyalty_brok_dtls_t
                     VALUES (p_request_id, ln_1month_amount, ln_2month_amount, ln_end_bal_cost_bro, p_vs_1st_month_amt, p_vs_2nd_month_amt, p_vs_3rd_month_amt, ln_1month_bro_amount, ln_2month_bro_amount, ln_3month_bro_amount, p_period_end_date, p_org_id
                             , 'Quarter');

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                           'Failed to insert brokage date in Custom table:'
                        || SQLERRM);
            END;

            -- 1.1


            RETURN ln_can_card_cost;
        ELSE
            -- 1.1 changes start
            -- query to fetch last month period end date
            IF ln_period_num IN (1, 4, 7,
                                 10)
            THEN
                BEGIN
                    SELECT LAST_DAY (ADD_MONTHS (p_period_end_date, -1))
                      INTO ld_last_qtr_per_end_date
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ld_last_qtr_per_end_date   := NULL;
                END;
            ELSIF ln_period_num IN (2, 5, 8,
                                    11)
            THEN
                BEGIN
                    SELECT LAST_DAY (ADD_MONTHS (p_period_end_date, -2))
                      INTO ld_last_qtr_per_end_date
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ld_last_qtr_per_end_date   := NULL;
                END;
            END IF;

            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                'ld_last_qtr_per_end_date:' || ld_last_qtr_per_end_date);

            BEGIN
                SELECT MIN (future_attribute2), MIN (future_attribute3), MIN (future_attribute4)
                  INTO ln_pre_qtr_brokage1, ln_pre_qtr_brokage2, ln_pre_qtr_brokage3
                  FROM xxdo.xxd_oe_can_loyalty_card_t
                 WHERE     TO_DATE (period_end_date, 'MM/DD/YYYY') =
                           ld_last_qtr_per_end_date
                       AND org_id = p_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_pre_qtr_brokage1   := NULL;
                    ln_pre_qtr_brokage2   := NULL;
                    ln_pre_qtr_brokage3   := NULL;
            END;

            -- 1.1 changes end
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'ln_pre_qtr_brokage1:' || ln_pre_qtr_brokage1);
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'ln_pre_qtr_brokage2:' || ln_pre_qtr_brokage2);
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'ln_pre_qtr_brokage3:' || ln_pre_qtr_brokage3);

            BEGIN
                SELECT SUM (ending_balance * cost)
                  INTO ln_end_bal_cost
                  FROM xxdo.xxd_oe_can_loyalty_card_t
                 WHERE     TO_DATE (date_at, 'YYYY-MM-DD') =
                           p_period_end_date
                       AND request_id = p_request_id;

                -- show

                fnd_file.put_line (fnd_file.LOG,
                                   'ln_end_Bal_cost:' || ln_end_bal_cost);
            -- fnd_file.put_line(fnd_file.log, 'ln_cost:' || ln_cost);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Failed to fetch acq ending balance:' || SQLERRM);
                    ln_acq_ending_balance   := NULL;
            END;

            --ln_can_card_cost := -1 * ( ln_end_bal_cost )-- 1.1

            ln_can_card_cost   :=
                  -1
                * ((ln_end_bal_cost) + (NVL (ln_pre_qtr_brokage1, 0) + NVL (ln_pre_qtr_brokage2, 0) + NVL (ln_pre_qtr_brokage3, 0))); -- 1.1

            BEGIN
                SELECT SUM (issued * cost)
                  INTO ln_end_bal_cost_bro
                  FROM xxdo.xxd_oe_can_loyalty_card_t
                 WHERE     TO_DATE (date_at, 'YYYY-MM-DD') <=
                           p_period_end_date
                       AND request_id = p_request_id;

                fnd_file.put_line (
                    fnd_file.LOG,
                    'ln_end_bal_cost_bro:' || ln_end_bal_cost_bro);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Failed to fetch ending balance' || SQLERRM);
                    ln_end_bal_cost_bro   := NULL;
            END;

            -- UPDATE the ln_us_points_amt in custom table

            BEGIN
                UPDATE xxdo.xxd_oe_can_loyalty_card_t
                   SET report_amount = -1 * ln_end_bal_cost_bro, period_year = ln_period_year, period_month = ln_period_num,
                       period_name = lv_period_name, last_updated_by = gn_user_id, last_update_date = SYSDATE,
                       --1.1 changes start
                       future_attribute1 = ln_end_bal_cost, future_attribute2 = ln_pre_qtr_brokage1, future_attribute3 = ln_pre_qtr_brokage2,
                       future_attribute4 = ln_pre_qtr_brokage3
                 --1.1 chages end
                 WHERE request_id = gn_request_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (fnd_file.LOG,
                                       'Update is failed:' || SQLERRM);
            END;


            -- insert the values into custom table for displaying in output file.
            -- 1.1
            BEGIN
                INSERT INTO xxdo.xxd_oe_can_loyalty_brok_dtls_t
                     VALUES (p_request_id, NULL, NULL,
                             NULL, NULL, NULL,
                             NULL, ln_pre_qtr_brokage1, ln_pre_qtr_brokage2,
                             ln_pre_qtr_brokage3, p_period_end_date, p_org_id
                             , 'Month');
            EXCEPTION
                WHEN OTHERS
                THEN
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                           'Failed to insert brokage date in Custom table:'
                        || SQLERRM);
            END;

            -- 1.1

            RETURN ln_can_card_cost;
            fnd_file.put_line (fnd_file.LOG,
                               'ln_can_card_cost:' || ln_can_card_cost);
        END IF;
    -- Query to fetch acquisition ending balance
    END get_can_coupon_amt;

    --Function to get canada points amount

    -- Function to get US Card amount

    FUNCTION get_us_card_amt (p_period_end_date IN DATE, p_request_id IN NUMBER, p_vs_1st_month_amt IN NUMBER
                              , p_vs_2nd_month_amt IN NUMBER, p_vs_3rd_month_amt IN NUMBER, p_org_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_acq_ending_balance      NUMBER;
        ln_can_points_value        NUMBER;
        ln_period_year             NUMBER;
        ln_period_num              NUMBER;
        lv_period_name             VARCHAR2 (50);
        ln_ending_balance          NUMBER;
        ln_cost                    NUMBER;
        ln_1month_bro_amount       NUMBER;
        ln_2month_bro_amount       NUMBER;
        ln_3month_bro_amount       NUMBER;
        ln_us_card_cost            NUMBER;
        ln_ending_balance_cost     NUMBER;
        lv_month1_brokarage        VARCHAR2 (20);
        lv_month2_brokarage        VARCHAR2 (20);
        lv_month3_brokarage        VARCHAR2 (20);
        ln_us_card_percen          NUMBER;
        ln_end_bal_cost_bro        NUMBER := 0;
        --1.1 changes
        ln_pre_qtr_brokage1        NUMBER;
        ln_pre_qtr_brokage2        NUMBER;
        ln_pre_qtr_brokage3        NUMBER;
        ld_last_qtr_per_end_date   DATE;
        ln_1month_amount           NUMBER;
        ln_2month_amount           NUMBER;
        ln_3month_amount           NUMBER;

        --1.1 changes
        CURSOR get_coupon_id_cur IS
            SELECT DISTINCT reward_id
              FROM xxdo.xxd_oe_us_loyalty_card_t
             WHERE request_id = p_request_id;
    BEGIN
        -- query to get the period details
        IF p_period_end_date IS NULL
        THEN
            BEGIN
                SELECT period_year, period_num, period_name
                  INTO ln_period_year, ln_period_num, lv_period_name
                  FROM apps.gl_periods a
                 WHERE     period_set_name = 'DO_FY_CALENDAR'
                       AND TRUNC (SYSDATE) BETWEEN start_date AND end_date;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_period_year   := NULL;
                    ln_period_num    := NULL;
                    lv_period_name   := NULL;
            END;
        ELSE
            BEGIN
                SELECT period_year, period_num, period_name
                  INTO ln_period_year, ln_period_num, lv_period_name
                  FROM apps.gl_periods
                 WHERE     period_set_name = 'DO_FY_CALENDAR'
                       AND p_period_end_date BETWEEN start_date AND end_date;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_period_year   := NULL;
                    ln_period_num    := NULL;
                    lv_period_name   := NULL;
            END;
        END IF;

        fnd_file.put_line (fnd_file.LOG, 'ln_period_year:' || ln_period_year);
        fnd_file.put_line (fnd_file.LOG, 'ln_period_num:' || ln_period_num);
        fnd_file.put_line (fnd_file.LOG, 'lv_period_name:' || lv_period_name);

        --FOR i IN get_coupon_id_cur LOOP
        IF ln_period_num IN (3, 6, 9,
                             12)
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'This month is Quarter end:' || lv_period_name);

            BEGIN
                SELECT SUM (ending_balance * cost)
                  INTO ln_ending_balance_cost
                  FROM xxdo.xxd_oe_us_loyalty_card_t
                 WHERE     TO_DATE (date_at, 'YYYY-MM-DD') =
                           p_period_end_date
                       AND request_id = p_request_id;

                fnd_file.put_line (
                    fnd_file.LOG,
                    'ln_ending_balance_cost:' || ln_ending_balance_cost);
            -- fnd_file.put_line(fnd_file.log, 'ln_cost:' || ln_cost);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Failed to fetch ending balance:' || SQLERRM);
                    ln_ending_balance_cost   := NULL;
            END;

            BEGIN
                SELECT SUM (issued * cost)
                  INTO ln_end_bal_cost_bro
                  FROM xxdo.xxd_oe_us_loyalty_card_t
                 WHERE     TO_DATE (date_at, 'YYYY-MM-DD') <=
                           p_period_end_date
                       AND request_id = p_request_id;

                fnd_file.put_line (
                    fnd_file.LOG,
                    'ln_ending_balance_cost:' || ln_ending_balance_cost);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Failed to fetch ending balance' || SQLERRM);
                    ln_end_bal_cost_bro   := NULL;
            END;

            fnd_file.put_line (fnd_file.LOG,
                               'ln_end_bal_cost_bro:' || ln_end_bal_cost_bro);

            --FND_FILE.PUT_LINE(FND_FILE.LOG,'ln_cost'||ln_cost);

            -- query to fetch brokarage amounts if brokarage amount is null for specific month in quarter
            SELECT ffvl.attribute1, ffvl.attribute2, ffvl.attribute3
              INTO lv_month1_brokarage, lv_month2_brokarage, lv_month3_brokarage
              FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
             WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                   AND fvs.flex_value_set_name = 'XXD_OE_LOYALTY_BROK_PER_VS'
                   AND NVL (TRUNC (ffvl.start_date_active), TRUNC (SYSDATE)) <=
                       TRUNC (SYSDATE)
                   AND NVL (TRUNC (ffvl.end_date_active), TRUNC (SYSDATE)) >=
                       TRUNC (SYSDATE)
                   AND ffvl.enabled_flag = 'Y';

            -- query to get 1st month brokarage in quarter

            BEGIN
                SELECT -1 * MAX (report_amount) * (p_vs_1st_month_amt / 100), MAX (report_amount)
                  INTO ln_1month_bro_amount, ln_1month_amount
                  FROM xxdo.xxd_oe_us_loyalty_card_t
                 WHERE     period_year = ln_period_year
                       AND period_month = ln_period_num - 2
                       AND org_id = p_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_1month_bro_amount   := 0;
            END;

            fnd_file.put_line (
                fnd_file.LOG,
                'ln_1month_bro_amount:' || ln_1month_bro_amount);

            -- query to get 2nd month brokarage in quarter
            BEGIN
                SELECT -1 * MAX (report_amount) * (p_vs_2nd_month_amt / 100), MAX (report_amount)
                  INTO ln_2month_bro_amount, ln_2month_amount
                  FROM xxdo.xxd_oe_us_loyalty_card_t
                 WHERE     period_year = ln_period_year
                       AND period_month = ln_period_num - 1
                       AND org_id = p_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_1month_bro_amount   := 0;
            END;

            fnd_file.put_line (
                fnd_file.LOG,
                'ln_2month_bro_amount:' || ln_2month_bro_amount);
            -- query to get 3rd month brokarage in quarter
            ln_3month_bro_amount   :=
                (ln_end_bal_cost_bro * (p_vs_3rd_month_amt / 100));
            fnd_file.put_line (
                fnd_file.LOG,
                'ln_3month_bro_amount' || ln_3month_bro_amount);
            /*IF lv_period_name = 'SEP-22' THEN
                ln_us_card_cost := ( -1 * ( ln_ending_balance_cost ) ) + lv_month1_brokarage + lv_month2_brokarage + ln_3month_bro_amount
                ;
            ELSE
                ln_us_card_cost := ( -1 * ( ln_ending_balance_cost ) ) + ln_1month_bro_amount + ln_2month_bro_amount + ln_3month_bro_amount
                ;
            END IF;*/
            ln_us_card_cost   :=
                  -1
                * ((ln_ending_balance_cost) + NVL (ln_1month_bro_amount, lv_month1_brokarage) + NVL (ln_2month_bro_amount, lv_month2_brokarage) + NVL (ln_3month_bro_amount, lv_month3_brokarage));

            fnd_file.put_line (fnd_file.LOG,
                               'ln_us_card_cost:' || ln_us_card_cost);

            -- UPDATE the ln_us_points_amt in custom table
            BEGIN
                UPDATE xxdo.xxd_oe_us_loyalty_card_t
                   SET report_amount = ln_us_card_cost, period_year = ln_period_year, period_month = ln_period_num,
                       period_name = lv_period_name, last_updated_by = gn_user_id, last_update_date = SYSDATE,
                       --1.1 changes start
                       future_attribute1 = ln_ending_balance_cost, future_attribute2 = ln_1month_bro_amount, future_attribute3 = ln_2month_bro_amount,
                       future_attribute4 = ln_3month_bro_amount
                 --1.1 chages end
                 WHERE request_id = gn_request_id;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (fnd_file.LOG,
                                       'Update is failed:' || SQLERRM);
            END;

            --
            -- insert the values into custom table for displaying in output file.
            -- 1.1
            BEGIN
                INSERT INTO xxdo.xxd_oe_us_loyalty_brok_dtls_t
                     VALUES (p_request_id, ln_1month_amount, ln_2month_amount, ln_end_bal_cost_bro, p_vs_1st_month_amt, p_vs_2nd_month_amt, p_vs_3rd_month_amt, ln_1month_bro_amount, ln_2month_bro_amount, ln_3month_bro_amount, p_period_end_date, p_org_id
                             , 'Quarter');

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                           'Failed to insert brokage date in Custom table:'
                        || SQLERRM);
            END;

            -- 1.1

            RETURN ln_us_card_cost;
        ELSE
            -- 1.1 changes start
            -- query to fetch last month period end date
            IF ln_period_num IN (1, 4, 7,
                                 10)
            THEN
                BEGIN
                    SELECT LAST_DAY (ADD_MONTHS (p_period_end_date, -1))
                      INTO ld_last_qtr_per_end_date
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ld_last_qtr_per_end_date   := NULL;
                END;
            ELSIF ln_period_num IN (2, 5, 8,
                                    11)
            THEN
                BEGIN
                    SELECT LAST_DAY (ADD_MONTHS (p_period_end_date, -2))
                      INTO ld_last_qtr_per_end_date
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ld_last_qtr_per_end_date   := NULL;
                END;
            END IF;

            BEGIN
                SELECT MIN (future_attribute2), MIN (future_attribute3), MIN (future_attribute4)
                  INTO ln_pre_qtr_brokage1, ln_pre_qtr_brokage2, ln_pre_qtr_brokage3
                  FROM xxdo.xxd_oe_us_loyalty_card_t
                 WHERE     TO_DATE (period_end_date, 'MM/DD/YYYY') =
                           ld_last_qtr_per_end_date
                       AND org_id = p_org_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_pre_qtr_brokage1   := NULL;
                    ln_pre_qtr_brokage2   := NULL;
                    ln_pre_qtr_brokage3   := NULL;
                WHEN OTHERS
                THEN
                    ln_pre_qtr_brokage1   := NULL;
                    ln_pre_qtr_brokage2   := NULL;
                    ln_pre_qtr_brokage3   := NULL;
            END;

            -- 1.1 changes end

            BEGIN
                SELECT SUM (ending_balance * cost)
                  INTO ln_ending_balance_cost
                  FROM xxdo.xxd_oe_us_loyalty_card_t
                 WHERE     TO_DATE (date_at, 'YYYY-MM-DD') =
                           p_period_end_date
                       AND request_id = p_request_id;

                fnd_file.put_line (
                    fnd_file.LOG,
                    'ln_ending_balance_cost:' || ln_ending_balance_cost);
            -- fnd_file.put_line(fnd_file.log, 'ln_cost:' || ln_cost);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Failed to fetch ending balance:' || SQLERRM);
                    ln_ending_balance_cost   := NULL;
            END;

            --ln_us_card_cost := -1 * ( ln_ending_balance_cost ); -- 1.1
            ln_us_card_cost   :=
                  -1
                * ((ln_ending_balance_cost) + (NVL (ln_pre_qtr_brokage1, 0) + NVL (ln_pre_qtr_brokage2, 0) + NVL (ln_pre_qtr_brokage3, 0))); -- 1.1

            BEGIN
                SELECT SUM (issued * cost)
                  INTO ln_end_bal_cost_bro
                  FROM xxdo.xxd_oe_us_loyalty_card_t
                 WHERE     TO_DATE (date_at, 'YYYY-MM-DD') <=
                           p_period_end_date
                       AND request_id = p_request_id;

                fnd_file.put_line (
                    fnd_file.LOG,
                    'ln_ending_balance_cost:' || ln_ending_balance_cost);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Failed to fetch ending balance' || SQLERRM);
                    ln_end_bal_cost_bro   := NULL;
            END;


            -- UPDATE the ln_us_points_amt in custom table

            BEGIN
                UPDATE xxdo.xxd_oe_us_loyalty_card_t
                   SET report_amount = -1 * ln_end_bal_cost_bro, period_year = ln_period_year, period_month = ln_period_num,
                       period_name = lv_period_name, last_updated_by = gn_user_id, last_update_date = SYSDATE,
                       --1.1 changes start
                       future_attribute1 = ln_ending_balance_cost, future_attribute2 = ln_pre_qtr_brokage1, future_attribute3 = ln_pre_qtr_brokage2,
                       future_attribute4 = ln_pre_qtr_brokage3
                 --1.1 chages end
                 WHERE request_id = gn_request_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (fnd_file.LOG,
                                       'Update is failed:' || SQLERRM);
            END;

            -- insert the values into custom table for displaying in output file.
            -- 1.1
            BEGIN
                INSERT INTO xxdo.xxd_oe_us_loyalty_brok_dtls_t
                     VALUES (p_request_id, NULL, NULL,
                             NULL, NULL, NULL,
                             NULL, ln_pre_qtr_brokage1, ln_pre_qtr_brokage2,
                             ln_pre_qtr_brokage3, p_period_end_date, p_org_id
                             , 'Month');
            EXCEPTION
                WHEN OTHERS
                THEN
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                           'Failed to insert brokage date in Custom table:'
                        || SQLERRM);
            END;

            -- 1.1

            RETURN ln_us_card_cost;
            fnd_file.put_line (fnd_file.LOG,
                               'ln_us_card_cost:' || ln_us_card_cost);
        END IF;
    -- Query to fetch acquisition ending balance

    END get_us_card_amt;

    --Function to get canada points amount

    FUNCTION get_can_points_amt (p_period_end_date IN DATE, p_request_id IN NUMBER, p_vs_amount IN NUMBER)
        RETURN NUMBER
    IS
        ln_acq_ending_balance   NUMBER;
        ln_can_points_value     NUMBER;
    BEGIN
        -- Query to fetch acquisition ending balance
        BEGIN
            SELECT acq_ending_balance
              INTO ln_acq_ending_balance
              FROM xxdo.xxd_oe_can_loyalty_points_t
             WHERE     TO_DATE (created_at, 'YYYY-MM-DD') = p_period_end_date
                   AND request_id = p_request_id;

            fnd_file.put_line (fnd_file.LOG,
                               'acq ending balance' || ln_acq_ending_balance);
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Failed to fetch acq ending balance' || SQLERRM);
                ln_acq_ending_balance   := NULL;
        END;

        -- points amount calculation

        ln_can_points_value   := (-1) * (ln_acq_ending_balance) * p_vs_amount;
        fnd_file.put_line (fnd_file.LOG,
                           'Can Points value' || ln_can_points_value);
        RETURN ln_can_points_value;
    END get_can_points_amt;

    -- Function to get US points amount

    FUNCTION get_us_points_amt (p_period_end_date IN DATE, p_request_id IN NUMBER, p_vs_amount IN NUMBER
                                , p_us_aquisition_points IN NUMBER)
        RETURN NUMBER
    IS
        ln_acq_ending_balance   NUMBER;
        ln_sum_acq_conversion   NUMBER;
        ln_us_points_value      NUMBER;
    BEGIN
        -- Query to fetch acquisition ending balance
        BEGIN
            SELECT acq_ending_balance
              INTO ln_acq_ending_balance
              FROM xxdo.xxd_oe_us_loyalty_points_t
             WHERE     TO_DATE (created_at, 'YYYY-MM-DD') = p_period_end_date
                   AND request_id = p_request_id;

            fnd_file.put_line (fnd_file.LOG,
                               'acq ending balance' || ln_acq_ending_balance);
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Failed to fetch acq ending balance' || SQLERRM);
                ln_acq_ending_balance   := NULL;
        END;

        -- query to fetch sum of sum of acquisition conversion coloumn

        BEGIN
            SELECT SUM (acq_conversion)
              INTO ln_sum_acq_conversion
              FROM xxdo.xxd_oe_us_loyalty_points_t
             WHERE     1 = 1
                   AND TO_DATE (period_end_date, 'MM/DD/YYYY') <=
                       p_period_end_date;

            -- AND request_id = p_request_id;

            fnd_file.put_line (
                fnd_file.LOG,
                'sum of acq conversion' || ln_sum_acq_conversion);
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Failed to fetch sum of acq conversion' || SQLERRM);
                ln_sum_acq_conversion   := NULL;
        END;

        -- points amount calculation

        ln_us_points_value   :=
              (-1)
            * ((ln_acq_ending_balance + ln_sum_acq_conversion + p_us_aquisition_points) * p_vs_amount);

        fnd_file.put_line (fnd_file.LOG,
                           'US Points value' || ln_us_points_value);
        RETURN ln_us_points_value;
    END get_us_points_amt;

    PROCEDURE get_coupon_segments (p_coupon_gl IN VARCHAR2, p_coupon_segment1 OUT VARCHAR2, p_coupon_segment2 OUT VARCHAR2, p_coupon_segment3 OUT VARCHAR2, p_coupon_segment4 OUT VARCHAR2, p_coupon_segment5 OUT VARCHAR2
                                   , p_coupon_segment6 OUT VARCHAR2, p_coupon_segment7 OUT VARCHAR2, p_coupon_segment8 OUT VARCHAR2)
    IS
    BEGIN
        BEGIN
            SELECT segment1, segment2, segment3,
                   segment4, segment5, segment6,
                   segment7, segment8
              INTO p_coupon_segment1, p_coupon_segment2, p_coupon_segment3, p_coupon_segment4,
                                    p_coupon_segment5, p_coupon_segment6, p_coupon_segment7,
                                    p_coupon_segment8
              FROM apps.gl_code_combinations_kfv
             WHERE concatenated_segments = p_coupon_gl;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'In Exception: Failed to fetch segments for ccid');
                p_coupon_segment1   := NULL;
                p_coupon_segment2   := NULL;
                p_coupon_segment3   := NULL;
                p_coupon_segment4   := NULL;
                p_coupon_segment5   := NULL;
                p_coupon_segment6   := NULL;
                p_coupon_segment7   := NULL;
                p_coupon_segment8   := NULL;
        END;
    END get_coupon_segments;

    PROCEDURE get_points_segments (p_points_gl IN VARCHAR2, p_points_segment1 OUT VARCHAR2, p_points_segment2 OUT VARCHAR2, p_points_segment3 OUT VARCHAR2, p_points_segment4 OUT VARCHAR2, p_points_segment5 OUT VARCHAR2
                                   , p_points_segment6 OUT VARCHAR2, p_points_segment7 OUT VARCHAR2, p_points_segment8 OUT VARCHAR2)
    IS
    BEGIN
        BEGIN
            SELECT segment1, segment2, segment3,
                   segment4, segment5, segment6,
                   segment7, segment8
              INTO p_points_segment1, p_points_segment2, p_points_segment3, p_points_segment4,
                                    p_points_segment5, p_points_segment6, p_points_segment7,
                                    p_points_segment8
              FROM apps.gl_code_combinations_kfv
             WHERE concatenated_segments = p_points_gl;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'In Exception: Failed to fetch segments for ccid');
                p_points_segment1   := NULL;
                p_points_segment2   := NULL;
                p_points_segment3   := NULL;
                p_points_segment4   := NULL;
                p_points_segment5   := NULL;
                p_points_segment6   := NULL;
                p_points_segment7   := NULL;
                p_points_segment8   := NULL;
        END;
    END get_points_segments;

    FUNCTION xxd_remove_junk_fnc (p_input IN VARCHAR2)
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
    END xxd_remove_junk_fnc;

    --    PROCEDURE purge_prc (
    --        pn_purge_days IN NUMBER
    --    ) IS
    --
    --        CURSOR purge_cur IS
    --        SELECT DISTINCT
    --            stg.request_id
    --        FROM
    --            xxdo.xxd_rms_lmt_asset_stg_t stg
    --        WHERE
    --            1 = 1
    --            AND stg.creation_date < ( SYSDATE - pn_purge_days );
    --
    --    BEGIN
    --        FOR purge_rec IN purge_cur LOOP
    --            DELETE FROM xxdo.xxd_rms_lmt_asset_stg_t
    --            WHERE
    --                1 = 1
    --                AND request_id = purge_rec.request_id;
    --
    --            COMMIT;
    --        END LOOP;
    --    EXCEPTION
    --        WHEN OTHERS THEN
    --            write_log('Error in Purge Procedure -' || sqlerrm);
    --    END purge_prc;

    PROCEDURE get_file_names (pv_directory_name IN VARCHAR2)
    AS
        LANGUAGE JAVA
        NAME 'DirList.getList( java.lang.String )' ;

    PROCEDURE load_file_into_tbl (p_table IN VARCHAR2, p_dir IN VARCHAR2, p_filename IN VARCHAR2, p_ignore_headerlines IN INTEGER DEFAULT 1, p_delimiter IN VARCHAR2 DEFAULT ',', p_optional_enclosed IN VARCHAR2 DEFAULT '"'
                                  , p_num_of_columns IN NUMBER, retcode OUT VARCHAR2, errbuf OUT VARCHAR2)
    IS
        /***************************************************************************
        -- PROCEDURE load_file_into_tbl
        -- PURPOSE: This Procedure read the data from a CSV file.
        -- And load it into the target oracle table.
        -- Finally it renames the source file with date.
        --
        -- P_FILENAME
        -- The name of the flat file(a text file)
        --
        -- P_DIRECTORY
        -- Name of the directory where the file is been placed.
        -- Note: The grant has to be given for the user to the directory
        -- before executing the function
        --
        -- P_IGNORE_HEADERLINES:
        -- Pass the value as '1' to ignore importing headers.
        --
        -- P_DELIMITER
        -- By default the delimiter is used as ','
        -- As we are using CSV file to load the data into oracle
        --
        -- P_OPTIONAL_ENCLOSED
        -- By default the optionally enclosed is used as '"'
        -- As we are using CSV file to load the data into oracle
        --
        **************************************************************************/

        l_input                 UTL_FILE.file_type;
        l_lastline              VARCHAR2 (32767);
        l_cnames                VARCHAR2 (32767);
        l_bindvars              VARCHAR2 (32767);
        l_status                INTEGER;
        l_cnt                   NUMBER DEFAULT 0;
        l_rowcount              NUMBER DEFAULT 0;
        l_sep                   CHAR (1) DEFAULT NULL;
        l_errmsg                VARCHAR2 (32767);
        v_eof                   BOOLEAN := FALSE;
        l_thecursor             NUMBER DEFAULT DBMS_SQL.open_cursor;
        v_insert                VARCHAR2 (32767);
        lv_arc_dir              VARCHAR2 (100) := 'XXD_OE_LOYALTY_ARC_DIR';
        ln_req_id               NUMBER;
        lb_wait_req             BOOLEAN;
        lv_phase                VARCHAR2 (100);
        lv_status               VARCHAR2 (30);
        lv_dev_phase            VARCHAR2 (100);
        lv_dev_status           VARCHAR2 (100);
        lv_message              VARCHAR2 (4000);
        lv_arc_directory_path   VARCHAR2 (1000) := NULL;
        lv_inb_directory_path   VARCHAR2 (1000) := NULL;
    BEGIN
        l_cnt        := 1;

        FOR tab_columns
            IN (  SELECT column_name, data_type
                    FROM all_tab_columns
                   WHERE table_name = p_table AND column_id < p_num_of_columns
                ORDER BY column_id)
        LOOP
            l_cnames   := l_cnames || tab_columns.column_name || ',';
            l_bindvars   :=
                   l_bindvars
                || CASE
                       WHEN tab_columns.data_type IN ('DATE', 'TIMESTAMP(6)')
                       THEN
                           ':b' || l_cnt || ','
                       ELSE
                           ':b' || l_cnt || ','
                   END;

            l_cnt      := l_cnt + 1;
        END LOOP;

        l_cnames     := RTRIM (l_cnames, ',');
        l_bindvars   := RTRIM (l_bindvars, ',');
        write_log ('Count of Columns is - ' || l_cnt);
        l_input      := UTL_FILE.fopen (p_dir, p_filename, 'r');

        IF p_ignore_headerlines > 0
        THEN
            BEGIN
                FOR i IN 1 .. p_ignore_headerlines
                LOOP
                    -- DBMS_OUTPUT.put_line ('No of lines Ignored is - ' || i);
                    write_log ('No of lines Ignored is - ' || i);
                    write_log ('P_DIR - ' || p_dir);
                    write_log ('P_FILENAME - ' || p_filename);
                    UTL_FILE.get_line (l_input, l_lastline);
                END LOOP;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    v_eof   := TRUE;
                WHEN OTHERS
                THEN
                    write_log (
                           'File Read error due to heading size is huge: - '
                        || SQLERRM);
            END;
        END IF;

        v_insert     :=
               'insert into '
            || p_table
            || '('
            || l_cnames
            || ') values ('
            || l_bindvars
            || ')';

        IF NOT v_eof
        THEN
            write_log (
                   l_thecursor
                || '-'
                || 'insert into '
                || p_table
                || '('
                || l_cnames
                || ') values ('
                || l_bindvars
                || ')');

            DBMS_SQL.parse (l_thecursor, v_insert, DBMS_SQL.native);

            LOOP
                BEGIN
                    UTL_FILE.get_line (l_input, l_lastline);
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        EXIT;
                END;

                IF LENGTH (l_lastline) > 0
                THEN
                    FOR i IN 1 .. l_cnt - 1
                    LOOP
                        --
                        DBMS_SQL.bind_variable (
                            l_thecursor,
                            ':b' || i,
                            xxd_remove_junk_fnc (
                                RTRIM (
                                    RTRIM (LTRIM (LTRIM (REGEXP_SUBSTR (l_lastline, '(^|,)("[^"]*"|[^",]*)', 1
                                                                        , i),
                                                         p_delimiter),
                                                  p_optional_enclosed),
                                           p_delimiter),
                                    p_optional_enclosed)));
                    END LOOP;

                    BEGIN
                        l_status     := DBMS_SQL.execute (l_thecursor);
                        l_rowcount   := l_rowcount + 1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_errmsg   := SQLERRM;
                    END;
                END IF;
            END LOOP;

            -- Derive the directory Path

            BEGIN
                SELECT directory_path
                  INTO lv_inb_directory_path
                  FROM dba_directories
                 WHERE 1 = 1 AND directory_name = p_dir;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_inb_directory_path   := NULL;
            END;

            BEGIN
                SELECT directory_path
                  INTO lv_arc_directory_path
                  FROM dba_directories
                 WHERE 1 = 1 AND directory_name = lv_arc_dir;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_arc_directory_path   := NULL;
            END;

            -- copyfile_prc(p_filename, SYSDATE || p_filename, p_dir, lv_arc_dir);
            -- utl_file.fremove(p_dir, p_filename);
            -- Moving the file

            BEGIN
                write_log (
                       'Move files Process Begins...'
                    || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
                ln_req_id   :=
                    fnd_request.submit_request (
                        application   => 'XXDO',
                        program       => 'XXDO_CP_MV_RM_FILE',
                        argument1     => 'MOVE', -- MODE : COPY, MOVE, RENAME, REMOVE
                        argument2     => 2,
                        argument3     =>
                            lv_inb_directory_path || '/' || p_filename, -- Source File Directory
                        argument4     =>
                               lv_arc_directory_path
                            || '/'
                            || SYSDATE
                            || '_'
                            || p_filename,       -- Destination File Directory
                        start_time    => SYSDATE,
                        sub_request   => FALSE);

                COMMIT;

                IF ln_req_id = 0
                THEN
                    retcode   := 1;
                    write_log (
                        ' Unable to submit move files concurrent program ');
                ELSE
                    write_log (
                        'Move Files concurrent request submitted successfully.');
                    lb_wait_req   :=
                        fnd_concurrent.wait_for_request (
                            request_id   => ln_req_id,
                            INTERVAL     => 5,
                            phase        => lv_phase,
                            status       => lv_status,
                            dev_phase    => lv_dev_phase,
                            dev_status   => lv_dev_status,
                            MESSAGE      => lv_message);

                    IF lv_dev_phase = 'COMPLETE' AND lv_dev_status = 'NORMAL'
                    THEN
                        write_log (
                               'Move Files concurrent request with the request id '
                            || ln_req_id
                            || ' completed with NORMAL status.');
                    ELSE
                        retcode   := 1;
                        write_log (
                               'Move Files concurrent request with the request id '
                            || ln_req_id
                            || ' did not complete with NORMAL status.');
                    END IF; -- End of if to check if the status is normal and phase is complete
                END IF;              -- End of if to check if request ID is 0.

                COMMIT;
                write_log (
                       'Move Files Ends...'
                    || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
            EXCEPTION
                WHEN OTHERS
                THEN
                    retcode   := 2;
                    write_log ('Error in Move Files -' || SQLERRM);
            END;

            --

            DBMS_SQL.close_cursor (l_thecursor);
            UTL_FILE.fclose (l_input);
        END IF;
    END load_file_into_tbl;

    PROCEDURE load_file_into_tbl_can_pts (p_table IN VARCHAR2, p_dir IN VARCHAR2, p_filename IN VARCHAR2, p_ignore_headerlines IN INTEGER DEFAULT 1, p_delimiter IN VARCHAR2 DEFAULT ',', p_optional_enclosed IN VARCHAR2 DEFAULT '"'
                                          , p_num_of_columns IN NUMBER, retcode OUT VARCHAR2, errbuf OUT VARCHAR2)
    IS
        /***************************************************************************
        -- PROCEDURE load_file_into_tbl
        -- PURPOSE: This Procedure read the data from a CSV file.
        -- And load it into the target oracle table.
        -- Finally it renames the source file with date.
        --
        -- P_FILENAME
        -- The name of the flat file(a text file)
        --
        -- P_DIRECTORY
        -- Name of the directory where the file is been placed.
        -- Note: The grant has to be given for the user to the directory
        -- before executing the function
        --
        -- P_IGNORE_HEADERLINES:
        -- Pass the value as '1' to ignore importing headers.
        --
        -- P_DELIMITER
        -- By default the delimiter is used as ','
        -- As we are using CSV file to load the data into oracle
        --
        -- P_OPTIONAL_ENCLOSED
        -- By default the optionally enclosed is used as '"'
        -- As we are using CSV file to load the data into oracle
        --
        **************************************************************************/

        l_input                 UTL_FILE.file_type;
        l_lastline              VARCHAR2 (32767);
        l_cnames                VARCHAR2 (32767);
        l_bindvars              VARCHAR2 (32767);
        l_status                INTEGER;
        l_cnt                   NUMBER DEFAULT 0;
        l_rowcount              NUMBER DEFAULT 0;
        l_sep                   CHAR (1) DEFAULT NULL;
        l_errmsg                VARCHAR2 (32767);
        v_eof                   BOOLEAN := FALSE;
        l_thecursor             NUMBER DEFAULT DBMS_SQL.open_cursor;
        v_insert                VARCHAR2 (32767);
        lv_arc_dir              VARCHAR2 (100) := 'XXD_OE_LOYALTY_ARC_DIR';
        ln_req_id               NUMBER;
        lb_wait_req             BOOLEAN;
        lv_phase                VARCHAR2 (100);
        lv_status               VARCHAR2 (30);
        lv_dev_phase            VARCHAR2 (100);
        lv_dev_status           VARCHAR2 (100);
        lv_message              VARCHAR2 (1000);
        lv_inb_directory_path   VARCHAR2 (1000) := NULL;
        lv_arc_directory_path   VARCHAR2 (1000) := NULL;
    BEGIN
        l_cnt        := 1;

        FOR tab_columns
            IN (  SELECT column_name, data_type
                    FROM all_tab_columns
                   WHERE table_name = p_table AND column_id < p_num_of_columns
                ORDER BY column_id)
        LOOP
            l_cnames   := l_cnames || tab_columns.column_name || ',';
            l_bindvars   :=
                   l_bindvars
                || CASE
                       WHEN tab_columns.data_type IN ('DATE', 'TIMESTAMP(6)')
                       THEN
                           ':b' || l_cnt || ','
                       ELSE
                           ':b' || l_cnt || ','
                   END;

            l_cnt      := l_cnt + 1;
        END LOOP;

        l_cnames     := RTRIM (l_cnames, ',');
        l_bindvars   := RTRIM (l_bindvars, ',');
        write_log ('Count of Columns is - ' || l_cnt);
        l_input      := UTL_FILE.fopen (p_dir, p_filename, 'r');

        IF p_ignore_headerlines > 0
        THEN
            BEGIN
                FOR i IN 1 .. p_ignore_headerlines
                LOOP
                    -- DBMS_OUTPUT.put_line ('No of lines Ignored is - ' || i);
                    write_log ('No of lines Ignored is - ' || i);
                    write_log ('P_DIR - ' || p_dir);
                    write_log ('P_FILENAME - ' || p_filename);
                    UTL_FILE.get_line (l_input, l_lastline);
                END LOOP;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    v_eof   := TRUE;
                WHEN OTHERS
                THEN
                    write_log (
                           'File Read error due to heading size is huge: - '
                        || SQLERRM);
            END;
        END IF;

        v_insert     :=
               'insert into '
            || p_table
            || '('
            || l_cnames
            || ') values ('
            || l_bindvars
            || ')';

        IF NOT v_eof
        THEN
            write_log (
                   l_thecursor
                || '-'
                || 'insert into '
                || p_table
                || '('
                || l_cnames
                || ') values ('
                || l_bindvars
                || ')');

            DBMS_SQL.parse (l_thecursor, v_insert, DBMS_SQL.native);

            LOOP
                BEGIN
                    UTL_FILE.get_line (l_input, l_lastline);
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        EXIT;
                END;

                IF LENGTH (l_lastline) > 0
                THEN
                    FOR i IN 1 .. l_cnt - 1
                    LOOP
                        --
                        DBMS_SQL.bind_variable (
                            l_thecursor,
                            ':b' || i,
                            xxd_remove_junk_fnc (
                                RTRIM (
                                    RTRIM (LTRIM (LTRIM (REGEXP_SUBSTR (l_lastline, '(^|,)("[^"]*"|[^",]*)', 1
                                                                        , i),
                                                         p_delimiter),
                                                  p_optional_enclosed),
                                           p_delimiter),
                                    p_optional_enclosed)));
                    END LOOP;

                    BEGIN
                        l_status     := DBMS_SQL.execute (l_thecursor);
                        l_rowcount   := l_rowcount + 1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_errmsg   := SQLERRM;
                    END;
                END IF;
            END LOOP;

            -- Derive the directory Path

            BEGIN
                SELECT directory_path
                  INTO lv_inb_directory_path
                  FROM dba_directories
                 WHERE 1 = 1 AND directory_name = p_dir;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_inb_directory_path   := NULL;
            END;

            BEGIN
                SELECT directory_path
                  INTO lv_arc_directory_path
                  FROM dba_directories
                 WHERE 1 = 1 AND directory_name = lv_arc_dir;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_arc_directory_path   := NULL;
            END;

            -- copyfile_prc(p_filename, SYSDATE || p_filename, p_dir, lv_arc_dir);
            -- utl_file.fremove(p_dir, p_filename);
            -- Moving the file

            BEGIN
                write_log (
                       'Move files Process Begins...'
                    || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
                ln_req_id   :=
                    fnd_request.submit_request (
                        application   => 'XXDO',
                        program       => 'XXDO_CP_MV_RM_FILE',
                        argument1     => 'MOVE', -- MODE : COPY, MOVE, RENAME, REMOVE
                        argument2     => 2,
                        argument3     =>
                            lv_inb_directory_path || '/' || p_filename, -- Source File Directory
                        argument4     =>
                               lv_arc_directory_path
                            || '/'
                            || SYSDATE
                            || '_'
                            || p_filename,       -- Destination File Directory
                        start_time    => SYSDATE,
                        sub_request   => FALSE);

                COMMIT;

                IF ln_req_id = 0
                THEN
                    retcode   := 1;
                    write_log (
                        ' Unable to submit move files concurrent program ');
                ELSE
                    write_log (
                        'Move Files concurrent request submitted successfully.');
                    lb_wait_req   :=
                        fnd_concurrent.wait_for_request (
                            request_id   => ln_req_id,
                            INTERVAL     => 5,
                            phase        => lv_phase,
                            status       => lv_status,
                            dev_phase    => lv_dev_phase,
                            dev_status   => lv_dev_status,
                            MESSAGE      => lv_message);

                    IF lv_dev_phase = 'COMPLETE' AND lv_dev_status = 'NORMAL'
                    THEN
                        write_log (
                               'Move Files concurrent request with the request id '
                            || ln_req_id
                            || ' completed with NORMAL status.');
                    ELSE
                        retcode   := 1;
                        write_log (
                               'Move Files concurrent request with the request id '
                            || ln_req_id
                            || ' did not complete with NORMAL status.');
                    END IF; -- End of if to check if the status is normal and phase is complete
                END IF;              -- End of if to check if request ID is 0.

                COMMIT;
                write_log (
                       'Move Files Ends...'
                    || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
            EXCEPTION
                WHEN OTHERS
                THEN
                    retcode   := 2;
                    write_log ('Error in Move Files -' || SQLERRM);
            END;

            DBMS_SQL.close_cursor (l_thecursor);
            UTL_FILE.fclose (l_input);
        END IF;
    END load_file_into_tbl_can_pts;

    PROCEDURE copyfile_prc (p_in_filename IN VARCHAR2, p_out_filename IN VARCHAR2, p_src_dir VARCHAR2
                            , p_dest_dir VARCHAR2)
    IS
        in_file                UTL_FILE.file_type;
        out_file               UTL_FILE.file_type;
        buffer_size   CONSTANT INTEGER := 32767;    -- Max Buffer Size = 32767
        buffer                 RAW (32767);
        buffer_length          INTEGER;
    BEGIN
        -- Open a handle to the location where you are going to read the Text or Binary file from
        -- NOTE: The 'rb' parameter means "read in byte mode" and is only available
        in_file         :=
            UTL_FILE.fopen (p_src_dir, p_in_filename, 'rb',
                            buffer_size);

        -- Open a handle to the location where you are going to write the Text or Binary file to
        -- NOTE: The 'wb' parameter means "write in byte mode" and is only available
        out_file        :=
            UTL_FILE.fopen (p_dest_dir, p_out_filename, 'wb',
                            buffer_size);

        -- Attempt to read the first chunk of the in_file
        UTL_FILE.get_raw (in_file, buffer, buffer_size);

        -- Determine the size of the first chunk read
        buffer_length   := UTL_RAW.LENGTH (buffer);

        -- Only write the chunk to the out_file if data exists
        WHILE buffer_length > 0
        LOOP
            -- Write one chunk of data
            UTL_FILE.put_raw (out_file, buffer, TRUE);

            -- Read the next chunk of data
            IF buffer_length = buffer_size
            THEN
                -- Buffer was full on last read, read another chunk
                UTL_FILE.get_raw (in_file, buffer, buffer_size);
                -- Determine the size of the current chunk
                buffer_length   := UTL_RAW.LENGTH (buffer);
            ELSE
                buffer_length   := 0;
            END IF;
        END LOOP;

        -- Close the file handles

        UTL_FILE.fclose (in_file);
        UTL_FILE.fclose (out_file);
    EXCEPTION
        -- Raised when the size of the file is a multiple of the buffer_size
        WHEN NO_DATA_FOUND
        THEN
            -- Close the file handles
            -- utl_file.fclose(in_file);
            UTL_FILE.fclose (out_file);
    END;

    PROCEDURE main_prc (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, pn_org_id IN NUMBER
                        , pv_type IN VARCHAR2, pv_period_end_date IN VARCHAR2, pv_file_path IN VARCHAR2)
    IS
        CURSOR get_file_us_pnts_cur IS
            SELECT filename FROM xxd_dir_list_tbl_syn;

        lv_directory_path          VARCHAR2 (100);
        lv_directory               VARCHAR2 (100);
        lv_file_name               VARCHAR2 (100);
        lv_ret_message             VARCHAR2 (4000) := NULL;
        lv_ret_code                VARCHAR2 (30) := NULL;
        lv_period_name             VARCHAR2 (100);
        ln_file_exists             NUMBER;
        ln_ret_count               NUMBER := 0;
        ln_final_count             NUMBER := 0;
        ln_lia_count               NUMBER := 0;
        lv_vs_file_method          VARCHAR2 (10);
        lv_vs_points_gl            VARCHAR2 (1000);
        lv_vs_coupon_gl            VARCHAR2 (1000);
        ln_vs_amount               NUMBER;
        lv_vs_coupon_amount        NUMBER;
        lv_points_dir              VARCHAR2 (100);
        lv_coupon_dir              VARCHAR2 (100);
        lv_archive_dir             VARCHAR2 (100) := 'XXD_OE_LOYALTY_ARC_DIR';
        lv_points_segment1         gl_code_combinations.segment1%TYPE;
        lv_points_segment2         gl_code_combinations.segment1%TYPE;
        lv_points_segment3         gl_code_combinations.segment1%TYPE;
        lv_points_segment4         gl_code_combinations.segment1%TYPE;
        lv_points_segment5         gl_code_combinations.segment1%TYPE;
        lv_points_segment6         gl_code_combinations.segment1%TYPE;
        lv_points_segment7         gl_code_combinations.segment1%TYPE;
        lv_points_segment8         gl_code_combinations.segment1%TYPE;
        lv_coupon_segment1         gl_code_combinations.segment1%TYPE;
        lv_coupon_segment2         gl_code_combinations.segment1%TYPE;
        lv_coupon_segment3         gl_code_combinations.segment1%TYPE;
        lv_coupon_segment4         gl_code_combinations.segment1%TYPE;
        lv_coupon_segment5         gl_code_combinations.segment1%TYPE;
        lv_coupon_segment6         gl_code_combinations.segment1%TYPE;
        lv_coupon_segment7         gl_code_combinations.segment1%TYPE;
        lv_coupon_segment8         gl_code_combinations.segment1%TYPE;
        lv_period_end_date         VARCHAR2 (100);
        ld_period_end_date         DATE;
        ln_us_points_amt           NUMBER;
        ln_can_points_amt          NUMBER;
        ln_us_coupon_amt           NUMBER;
        ln_can_coupon_amt          NUMBER;
        lv_vs_1st_coupon_amount    NUMBER;       -- 1st month coupon brokarage
        lv_vs_2nd_coupon_amount    NUMBER;       -- 2nd month coupon brokarage
        lv_vs_3rd_coupon_amount    NUMBER;       -- 3rd month coupon brokarage
        lv_us_pnts_purge_status    VARCHAR2 (10);
        lv_can_pnts_purge_status   VARCHAR2 (10);
        lv_us_card_purge_status    VARCHAR2 (10);
        lv_can_card_purge_status   VARCHAR2 (10);
        ln_us_aquisition_points    NUMBER;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, '------------------------');
        fnd_file.put_line (fnd_file.LOG, 'Program parameters are:');
        fnd_file.put_line (fnd_file.LOG, '------------------------');
        fnd_file.put_line (fnd_file.LOG, 'pn_org_id:' || pn_org_id);
        fnd_file.put_line (fnd_file.LOG, 'pv_type:' || pv_type);
        fnd_file.put_line (fnd_file.LOG,
                           'pv_period_end_date:' || pv_period_end_date);
        fnd_file.put_line (fnd_file.LOG, 'pv_file_path:' || pv_file_path);
        lv_directory_path   := NULL;
        lv_directory        := NULL;
        ln_file_exists      := 0;
        lv_period_end_date   :=
            TO_CHAR (TO_DATE (pv_period_end_date, 'RRRR/MM/DD HH24:MI:SS'),
                     'MM/DD/YYYY');

        --Query to fetch details from Value set
        BEGIN
            SELECT ffvl.attribute11, ffvl.attribute12, ffvl.attribute13,
                   ffvl.attribute14, ffvl.attribute15, ffvl.attribute16,
                   ffvl.attribute18, ffvl.attribute19, ffvl.attribute20,
                   ffvl.attribute22
              INTO lv_vs_file_method, lv_vs_points_gl, lv_vs_coupon_gl, ln_vs_amount,
                                    lv_points_dir, lv_coupon_dir, lv_vs_1st_coupon_amount, -- 1st month coupon brokarage
                                    lv_vs_2nd_coupon_amount, -- 2nd month coupon brokarage
                                                             lv_vs_3rd_coupon_amount, -- 3rd month coupon brokarage
                                                                                      ln_us_aquisition_points
              FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
             WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                   AND fvs.flex_value_set_name = 'XXD_GL_AAR_OU_SHORTNAME_VS'
                   AND NVL (TRUNC (ffvl.start_date_active), TRUNC (SYSDATE)) <=
                       TRUNC (SYSDATE)
                   AND NVL (TRUNC (ffvl.end_date_active), TRUNC (SYSDATE)) >=
                       TRUNC (SYSDATE)
                   AND ffvl.enabled_flag = 'Y'
                   AND ffvl.attribute1 = pn_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Failed to fetch details from value set: XXD_GL_AAR_OU_SHORTNAME_VS');
        END;

        fnd_file.put_line (fnd_file.LOG, '-----------------------------');
        fnd_file.put_line (fnd_file.LOG, 'Value set defined values are:');
        fnd_file.put_line (fnd_file.LOG, '-----------------------------');
        fnd_file.put_line (fnd_file.LOG, 'File Method:' || lv_vs_file_method);
        fnd_file.put_line (fnd_file.LOG, 'Points GL:' || lv_vs_points_gl);
        fnd_file.put_line (fnd_file.LOG, 'Coupon GL:' || lv_vs_coupon_gl);
        fnd_file.put_line (fnd_file.LOG,
                           'Amount from Value set:' || ln_vs_amount);
        fnd_file.put_line (fnd_file.LOG,
                           'Points directory:' || lv_points_dir);
        fnd_file.put_line (fnd_file.LOG, 'Coupon directory' || lv_coupon_dir);
        fnd_file.put_line (
            fnd_file.LOG,
            '1st Month Coupon Brokarage' || lv_vs_1st_coupon_amount);
        fnd_file.put_line (
            fnd_file.LOG,
            '2nd Month Coupon Brokarage' || lv_vs_2nd_coupon_amount);
        fnd_file.put_line (
            fnd_file.LOG,
            '3rd Month Coupon Brokarage' || lv_vs_3rd_coupon_amount);
        fnd_file.put_line (fnd_file.LOG,
                           'us_aquisition_points' || ln_us_aquisition_points);
        fnd_file.put_line (fnd_file.LOG, '-----------------------------');

        IF pv_type = 'Points'
        THEN
            IF lv_vs_file_method = 'A'
            THEN                                                  -- US method
                -- Derive the directory Path
                BEGIN
                    SELECT directory_path
                      INTO lv_directory_path
                      FROM dba_directories
                     WHERE directory_name = lv_points_dir;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_directory_path   := NULL;
                END;

                fnd_file.put_line (fnd_file.LOG,
                                   'Directory Path:' || lv_directory_path);
                -- Now Get the file names
                get_file_names (lv_directory_path);

                FOR data IN get_file_us_pnts_cur
                LOOP
                    ln_file_exists   := 0;
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'File is availale - ' || data.filename);

                    -- Check the file name exists in the table if exists then SKIP
                    /*  BEGIN
                          SELECT
                              COUNT(1)
                          INTO ln_file_exists
                          FROM
                              xxdo.xxd_oe_us_loyalty_points_stg_t
                          WHERE
                              upper(file_name) = upper(data.filename);

                      EXCEPTION
                          WHEN OTHERS THEN
                              ln_file_exists := 0;
                      END;*/

                    -- IF ln_file_exists = 0 THEN
                    -- loading the data into staging table
                    load_file_into_tbl (
                        p_table                => 'XXD_OE_US_LOYALTY_POINTS_STG_T',
                        p_dir                  => lv_points_dir,
                        p_filename             => data.filename,
                        p_ignore_headerlines   => 1,
                        p_delimiter            => ',',
                        p_optional_enclosed    => '"',
                        p_num_of_columns       => 29,
                        retcode                => retcode,
                        errbuf                 => errbuf);

                    --

                    BEGIN
                        UPDATE xxdo.xxd_oe_us_loyalty_points_stg_t
                           SET file_name = data.filename, request_id = gn_request_id, creation_date = SYSDATE,
                               last_update_date = SYSDATE, created_by = gn_user_id, last_updated_by = gn_user_id
                         WHERE file_name IS NULL AND request_id IS NULL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Updating the staging table is failed:'
                                || SQLERRM);
                    END;

                    -- get the points segments

                    get_points_segments (lv_vs_points_gl,
                                         lv_points_segment1,
                                         lv_points_segment2,
                                         lv_points_segment3,
                                         lv_points_segment4,
                                         lv_points_segment5,
                                         lv_points_segment6,
                                         lv_points_segment7,
                                         lv_points_segment8);

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Points Segment1 is:' || lv_points_segment1);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Points Segment2 is:' || lv_points_segment2);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Points Segment3 is:' || lv_points_segment3);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Points Segment4 is:' || lv_points_segment4);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Points Segment5 is:' || lv_points_segment5);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Points Segment6 is:' || lv_points_segment6);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Points Segment7 is:' || lv_points_segment7);

                    -- check wheather the data is exist already, if yes purge the date into new custom table, and insert the new records.
                    BEGIN
                        SELECT COUNT (1)
                          INTO ln_file_exists
                          FROM xxdo.xxd_oe_us_loyalty_points_t
                         WHERE period_end_date = lv_period_end_date;    -- 1.1
                    -- upper(file_name) = upper(data.filename);--1.1

                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_file_exists   := 0;
                    END;

                    IF NVL (ln_file_exists, 0) <> 0
                    THEN                                                -- 1.1
                        purge_us_points_duplicates (lv_period_end_date,
                                                    pn_org_id,
                                                    lv_us_pnts_purge_status);
                    END IF;

                    -- Load the data in custom table
                    --   IF nvl(lv_us_pnts_purge_status, 'E') = 'S' THEN
                    BEGIN
                        INSERT INTO xxdo.xxd_oe_us_loyalty_points_t
                            (SELECT created_at, acq_begining_balance, acq_earned,
                                    acq_reward, acq_expired, acq_returned,
                                    acq_ending_balance, acq_conversion, partner_acq_begin_balance,
                                    partner_acq_earned, partner_acq_reward, partner_acq_expired,
                                    partner_acq_ending_balance, engagement_begining_balance, engagement_earned,
                                    engagement_reward, engagement_expired, engagement_returned,
                                    engagement_adjusted, engagement_ending_balance, engagement_conversion,
                                    overage_begining_balance, overage_reward, overage_expired,
                                    overage_adjusted, overage_ending_balance, total_day,
                                    total_ending_balance, NULL, NULL,
                                    NULL, NULL, NULL,
                                    NULL, NULL, NULL,
                                    NULL, NULL, lv_points_segment1, --entity_unique_identifier   ,
                                    lv_points_segment6, --account_number             ,
                                                        lv_points_segment2, --key3                       ,
                                                                            lv_points_segment3, --key                        ,
                                    lv_points_segment4, --key5                       ,
                                                        lv_points_segment5, --key6                       ,
                                                                            lv_points_segment7, --key7                       ,
                                    NULL, NULL, NULL,
                                    lv_period_end_date, --period_end_date            ,
                                                        NULL, --subledger_rep_bal          ,
                                                              NULL, --subledger_alt_bal          ,
                                    NULL,       --subledger_acc_bal          ,
                                          gn_user_id, SYSDATE,
                                    gn_user_id, SYSDATE, gn_request_id,
                                    data.filename,                 --file_name
                                                   pn_org_id
                               FROM xxdo.xxd_oe_us_loyalty_points_stg_t
                              WHERE     request_id = gn_request_id
                                    AND TO_DATE (created_at, 'YYYY-MM-DD') <=
                                        TO_DATE (lv_period_end_date,
                                                 'MM/DD/YYYY'));

                        COMMIT;
                        fnd_file.put_line (fnd_file.LOG,
                                           'Insertion is Success:');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Insertion is failed:' || SQLERRM);
                    END;

                    ld_period_end_date   :=
                        TO_DATE (lv_period_end_date, 'MM/DD/YYYY');

                    -- get the points amount
                    ln_us_points_amt   :=
                        get_us_points_amt (ld_period_end_date, gn_request_id, ln_vs_amount
                                           , ln_us_aquisition_points);

                    -- UPDATE the ln_us_points_amt in custom table
                    BEGIN
                        UPDATE xxdo.xxd_oe_us_loyalty_points_t
                           SET subledger_acc_bal = ln_us_points_amt, last_updated_by = gn_user_id, last_update_date = SYSDATE
                         WHERE request_id = gn_request_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Update is failed:' || SQLERRM);
                    END;
                /* ELSE
                     write_log(' Data with this File name - '
                               || data.filename
                               || ' - is already loaded. Please change the file data ');
                 END IF;*/

                --  ELSE
                --    fnd_file.put_line(fnd_file.log, 'Failed to purge the duplicate data for US Points:' || sqlerrm);
                --END IF;
                END LOOP;

                write_op_file (pv_file_path,
                               pv_period_end_date,
                               pv_type,
                               lv_vs_file_method,
                               pn_org_id,
                               lv_ret_code,
                               lv_ret_message,
                               ln_vs_amount,
                               ln_us_aquisition_points);
                write_ret_recon_file (pv_type, lv_vs_file_method, pv_file_path
                                      , lv_ret_code, lv_ret_message);
                update_valueset_prc (pv_file_path);
            --------------------------
            ELSIF lv_vs_file_method = 'B'
            THEN                                              -- CANADA method
                -- Derive the directory Path
                BEGIN
                    SELECT directory_path
                      INTO lv_directory_path
                      FROM dba_directories
                     WHERE directory_name = lv_points_dir;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_directory_path   := NULL;
                END;

                fnd_file.put_line (fnd_file.LOG,
                                   'Directory Path:' || lv_directory_path);
                -- Now Get the file names
                get_file_names (lv_directory_path);

                FOR data IN get_file_us_pnts_cur
                LOOP
                    ln_file_exists   := 0;
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'File is availale - ' || data.filename);

                    -- Check the file name exists in the table if exists then SKIP
                    /*BEGIN
                        SELECT
                            COUNT(1)
                        INTO ln_file_exists
                        FROM
                            xxdo.xxd_oe_can_loyalty_pnts_stg_t
                        WHERE
                            upper(file_name) = upper(data.filename);

                    EXCEPTION
                        WHEN OTHERS THEN
                            ln_file_exists := 0;
                    END;

                    IF ln_file_exists = 0 THEN  */
                    -- loading the data into staging table
                    load_file_into_tbl_can_pts (
                        p_table                => 'XXD_OE_CAN_LOYALTY_PNTS_STG1_T',
                        p_dir                  => lv_points_dir,
                        p_filename             => data.filename,
                        p_ignore_headerlines   => 1,
                        p_delimiter            => ',',
                        p_optional_enclosed    => '"',
                        p_num_of_columns       => 59,
                        retcode                => retcode,
                        errbuf                 => errbuf);

                    --

                    BEGIN
                        -- UPDATE xxdo.xxd_oe_can_loyalty_pnts_stg_t
                        UPDATE xxdo.xxd_oe_can_loyalty_pnts_stg1_t
                           SET file_name = data.filename, request_id = gn_request_id, creation_date = SYSDATE,
                               last_update_date = SYSDATE, created_by = gn_user_id, last_updated_by = gn_user_id
                         WHERE file_name IS NULL AND request_id IS NULL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Updating the staging table is failed:'
                                || SQLERRM);
                    END;

                    -- get the points segments

                    get_points_segments (lv_vs_points_gl,
                                         lv_points_segment1,
                                         lv_points_segment2,
                                         lv_points_segment3,
                                         lv_points_segment4,
                                         lv_points_segment5,
                                         lv_points_segment6,
                                         lv_points_segment7,
                                         lv_points_segment8);

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Points Segment1 is:' || lv_points_segment1);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Points Segment2 is:' || lv_points_segment2);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Points Segment3 is:' || lv_points_segment3);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Points Segment4 is:' || lv_points_segment4);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Points Segment5 is:' || lv_points_segment5);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Points Segment6 is:' || lv_points_segment6);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Points Segment7 is:' || lv_points_segment7);

                    -- check wheather the data is exist already, if yes purge the date into new custom table, and insert the new records.
                    BEGIN
                        SELECT COUNT (1)
                          INTO ln_file_exists
                          FROM xxdo.xxd_oe_can_loyalty_points_t
                         WHERE period_end_date = lv_period_end_date;    -- 1.1
                    -- upper(file_name) = upper(data.filename);--1.1

                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_file_exists   := 0;
                    END;

                    IF NVL (ln_file_exists, 0) <> 0
                    THEN                                                -- 1.1
                        purge_can_points_duplicates (
                            lv_period_end_date,
                            pn_org_id,
                            lv_can_pnts_purge_status);
                    END IF;

                    -- IF nvl(lv_can_pnts_purge_status, 'E') = 'S' THEN
                    -- Load the data in custom table
                    BEGIN
                        INSERT INTO xxdo.xxd_oe_can_loyalty_points_t
                            (SELECT created_at, acq_begining_balance, acq_earned,
                                    acq_earned_local_value, acq_reward, acq_reward_local_value,
                                    acq_expired, acq_expired_local_value, acq_returned,
                                    acq_returned_local_value, acq_ending_balance, acq_ending_bal_local_value,
                                    acq_conversion, acq_conversion_local_value, partner_acq_begin_bal,
                                    partner_acq_beg_bal_local_val, partner_acq_earned, partner_acq_earned_local_val,
                                    partner_acq_reward, partner_acq_reward_local_val, partner_acq_expired,
                                    partner_acq_expired_local_val, partner_acq_ending_balance, partner_acq_end_bal_local_val,
                                    engagement_begining_balance, engagement_beg_bal_local_val, engagement_earned,
                                    engagement_earned_local_val, engagement_reward, engagement_reward_local_val,
                                    engagement_expired, engagement_exp_local_val, engagement_returned,
                                    engagement_return_local_val, engagement_adjusted, engagement_adjust_local_val,
                                    engagement_ending_balance, engagement_end_bal_local_val, engagement_conversion,
                                    engagement_conv_local_value, overage_begining_balance, overage_begin_bal_local_val,
                                    overage_reward, overage_reward_local_val, overage_expired,
                                    overage_expired_local_val, overage_adjusted, overage_adjusted_local_val,
                                    overage_ending_balance, overage_end_bal_local_val, total_day,
                                    total_day_local_value, total_ending_balance, total_ending_bal_local_val,
                                    ACQ_CLOSED_MEMBER,                   --1.1
                                                       ACQ_CLOSED_MEMBER_LOCAL_VAL, --1.1
                                                                                    NULL,
                                    NULL, NULL, NULL,
                                    NULL, NULL, NULL,
                                    NULL, lv_points_segment1, --entity_unique_identifier   ,
                                                              lv_points_segment6, --account_number             ,
                                    lv_points_segment2, --key3                       ,
                                                        lv_points_segment3, --key                        ,
                                                                            lv_points_segment4, --key5                       ,
                                    lv_points_segment5, --key6                       ,
                                                        lv_points_segment7, --key7                       ,
                                                                            NULL,
                                    NULL, NULL, lv_period_end_date, --period_end_date            ,
                                    NULL,       --subledger_rep_bal          ,
                                          NULL, --subledger_alt_bal          ,
                                                NULL, --subledger_acc_bal          ,
                                    gn_user_id, SYSDATE, gn_user_id,
                                    SYSDATE, gn_request_id, data.filename, --file_name
                                    pn_org_id
                               FROM --xxdo.xxd_oe_can_loyalty_pnts_stg_t
                                    xxdo.xxd_oe_can_loyalty_pnts_stg1_t
                              WHERE     request_id = gn_request_id
                                    AND total_ending_balance IS NOT NULL -- 1.1
                                                                        -- AND TO_DATE(created_at, 'MM/DD/YYYY') <= TO_DATE(lv_period_end_date, 'MM/DD/YYYY')
                                                                        /* AND ROWID NOT IN (
                                                                             SELECT
                                                                                 ROWID
                                                                             FROM
                                                                                 --xxdo.xxd_oe_can_loyalty_pnts_stg1_t
                                                   xxdo.xxd_oe_can_loyalty_pnts_stg1_t
                                                                             WHERE
                                                                                 request_id = gn_request_id
                                                                                 AND ROWNUM = 1
                                                                         )*/
                                                                        );

                        COMMIT;
                        fnd_file.put_line (fnd_file.LOG,
                                           'Insertion is Success:');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Insertion is failed:' || SQLERRM);
                    END;

                    ld_period_end_date   :=
                        TO_DATE (lv_period_end_date, 'MM/DD/YYYY');

                    -- get the points amount
                    ln_can_points_amt   :=
                        get_can_points_amt (ld_period_end_date,
                                            gn_request_id,
                                            ln_vs_amount);

                    -- UPDATE the ln_us_points_amt in custom table
                    BEGIN
                        UPDATE xxdo.xxd_oe_can_loyalty_points_t
                           SET subledger_acc_bal = ln_can_points_amt, last_updated_by = gn_user_id, last_update_date = SYSDATE
                         WHERE request_id = gn_request_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Update is failed:' || SQLERRM);
                    END;
                --

                --

                /*ELSE
                    write_log(' Data with this File name - '
                              || data.filename
                              || ' - is already loaded. Please change the file data ');
                END IF;*/

                -- END IF;

                END LOOP;

                write_op_file (pv_file_path, pv_period_end_date, pv_type,
                               lv_vs_file_method, pn_org_id, lv_ret_code,
                               lv_ret_message, ln_vs_amount, NULL);
                write_ret_recon_file (pv_type, lv_vs_file_method, pv_file_path
                                      , lv_ret_code, lv_ret_message);
                update_valueset_prc (pv_file_path);
            END IF;
        -- else
        ELSIF pv_type = 'Coupon'
        THEN
            IF lv_vs_file_method = 'A'
            THEN                                                  -- US method
                --  -- Derive the directory Path
                BEGIN
                    SELECT directory_path
                      INTO lv_directory_path
                      FROM dba_directories
                     WHERE directory_name = lv_coupon_dir;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_directory_path   := NULL;
                END;

                fnd_file.put_line (fnd_file.LOG,
                                   'lv_coupon_dir:' || lv_coupon_dir);
                fnd_file.put_line (fnd_file.LOG,
                                   'lv_directory_path:' || lv_directory_path);

                -- Now Get the file names
                get_file_names (lv_directory_path);

                FOR data IN get_file_us_pnts_cur
                LOOP
                    ln_file_exists   := 0;
                    fnd_file.put_line (
                        fnd_file.LOG,
                        ' File is availale - ' || data.filename);

                    -- Check the file name exists in the table if exists then SKIP
                    load_file_into_tbl (
                        p_table                => 'XXD_OE_US_LOYALTY_CARD_STG_T',
                        p_dir                  => lv_coupon_dir,
                        p_filename             => data.filename,
                        p_ignore_headerlines   => 1,
                        p_delimiter            => ',',
                        p_optional_enclosed    => '"',
                        p_num_of_columns       => 11,
                        retcode                => retcode,
                        errbuf                 => errbuf);

                    --

                    UPDATE xxdo.xxd_oe_us_loyalty_card_stg_t
                       SET file_name = data.filename, request_id = gn_request_id, creation_date = SYSDATE,
                           last_update_date = SYSDATE, created_by = gn_user_id, last_updated_by = gn_user_id
                     WHERE file_name IS NULL AND request_id IS NULL;

                    get_coupon_segments (lv_vs_coupon_gl,
                                         lv_coupon_segment1,
                                         lv_coupon_segment2,
                                         lv_coupon_segment3,
                                         lv_coupon_segment4,
                                         lv_coupon_segment5,
                                         lv_coupon_segment6,
                                         lv_coupon_segment7,
                                         lv_coupon_segment8);

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Coupon Segment1 is:' || lv_coupon_segment1);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Coupon Segment2 is:' || lv_coupon_segment2);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Coupon Segment3 is:' || lv_coupon_segment3);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Coupon Segment4 is:' || lv_coupon_segment4);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Coupon Segment5 is:' || lv_coupon_segment5);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Coupon Segment6 is:' || lv_coupon_segment6);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Coupon Segment7 is:' || lv_coupon_segment7);

                    BEGIN
                        SELECT COUNT (1)
                          INTO ln_file_exists
                          FROM xxdo.xxd_oe_us_loyalty_card_t
                         WHERE period_end_date = lv_period_end_date;    -- 1.1
                    -- upper(file_name) = upper(data.filename);--1.1

                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_file_exists   := 0;
                    END;

                    IF NVL (ln_file_exists, 0) <> 0
                    THEN
                        -- check wheather the data is exist already, if yes purge the date into new custom table, and insert the new records.
                        purge_us_card_duplicates (lv_period_end_date,
                                                  pn_org_id,
                                                  lv_us_card_purge_status);
                    END IF;

                    --IF nvl(lv_us_card_purge_status, 'E') = 'S' THEN

                    -- Load the data in custom table
                    BEGIN
                        INSERT INTO xxdo.xxd_oe_us_loyalty_card_t
                            (SELECT date_at, reward_id, cost,
                                    starting_balance, issued, redeemed,
                                    expired, invalidated, reissued,
                                    ending_balance, NULL,     -- report amount
                                                          NULL, -- period_year
                                    NULL,                      -- period_month
                                          NULL,                 -- period_name
                                                NULL,
                                    NULL, NULL, NULL,
                                    NULL, NULL, NULL,
                                    NULL, NULL, NULL,
                                    lv_coupon_segment1, --entity_unique_identifier   ,
                                                        lv_coupon_segment6, --account_number             ,
                                                                            lv_coupon_segment2, --key3                       ,
                                    lv_coupon_segment3, --key                        ,
                                                        lv_coupon_segment4, --key5                       ,
                                                                            lv_coupon_segment5, --key6                       ,
                                    lv_coupon_segment7, --key7                       ,
                                                        NULL, NULL,
                                    NULL, lv_period_end_date, --period_end_date            ,
                                                              NULL, --subledger_rep_bal          ,
                                    NULL,       --subledger_alt_bal          ,
                                          NULL, --subledger_acc_bal          ,
                                                gn_user_id,
                                    SYSDATE, gn_user_id, SYSDATE,
                                    gn_request_id, data.filename,  --file_name
                                                                  pn_org_id
                               FROM xxdo.xxd_oe_us_loyalty_card_stg_t
                              WHERE     request_id = gn_request_id
                                    AND TO_DATE (date_at, 'YYYY-MM-DD') <=
                                        TO_DATE (lv_period_end_date,
                                                 'MM/DD/YYYY'));

                        COMMIT;
                        fnd_file.put_line (fnd_file.LOG,
                                           'Insertion is Success:');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Insertion is failed:' || SQLERRM);
                    END;

                    ld_period_end_date   :=
                        TO_DATE (lv_period_end_date, 'MM/DD/YYYY');

                    -- get the points amount
                    ln_us_coupon_amt   :=
                        get_us_card_amt (ld_period_end_date,
                                         gn_request_id,
                                         lv_vs_1st_coupon_amount,
                                         lv_vs_2nd_coupon_amount,
                                         lv_vs_3rd_coupon_amount,
                                         pn_org_id);

                    -- UPDATE the ln_us_points_amt in custom table
                    BEGIN
                        UPDATE xxdo.xxd_oe_us_loyalty_card_t
                           SET subledger_acc_bal = ln_us_coupon_amt, last_updated_by = gn_user_id, last_update_date = SYSDATE
                         WHERE request_id = gn_request_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Update is failed:' || SQLERRM);
                    END;
                --

                --

                --  copyfile_prc(data.filename, SYSDATE || data.filename, lv_coupon_dir, lv_archive_dir);
                ----
                -- Utl_File.Fremove('XXD_LCX_BAL_BL_INB_DIR', data.filename);
                --

                /* ELSE
                     write_log(' Data with this File name - '
                               || data.filename
                               || ' - is already loaded. Please change the file data ');
                 END IF;*/

                --END IF;

                END LOOP;

                write_op_file (pv_file_path, pv_period_end_date, pv_type,
                               lv_vs_file_method, pn_org_id, lv_ret_code,
                               lv_ret_message, NULL, NULL);
                write_ret_recon_file (pv_type, lv_vs_file_method, pv_file_path
                                      , lv_ret_code, lv_ret_message);
                update_valueset_prc (pv_file_path);
            --------------------------
            ELSIF lv_vs_file_method = 'B'
            THEN                                              -- CANADA method
                --  -- Derive the directory Path
                BEGIN
                    SELECT directory_path
                      INTO lv_directory_path
                      FROM dba_directories
                     WHERE directory_name = lv_coupon_dir;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_directory_path   := NULL;
                END;

                fnd_file.put_line (fnd_file.LOG,
                                   'lv_directory_path:' || lv_directory_path);
                -- Now Get the file names
                get_file_names (lv_directory_path);

                FOR data IN get_file_us_pnts_cur
                LOOP
                    ln_file_exists   := 0;
                    fnd_file.put_line (
                        fnd_file.LOG,
                        ' File is availale - ' || data.filename);

                    -- Check the file name exists in the table if exists then SKIP
                    /* BEGIN
                         SELECT
                             COUNT(1)
                         INTO ln_file_exists
                         FROM
                             xxdo.xxd_oe_can_loyalty_card_stg_t
                         WHERE
                             upper(file_name) = upper(data.filename);

                     EXCEPTION
                         WHEN OTHERS THEN
                             ln_file_exists := 0;
                     END;

                     IF ln_file_exists = 0 THEN*/
                    load_file_into_tbl (
                        p_table                => 'XXD_OE_CAN_LOYALTY_CARD_STG_T',
                        p_dir                  => lv_coupon_dir,
                        p_filename             => data.filename,
                        p_ignore_headerlines   => 1,
                        p_delimiter            => ',',
                        p_optional_enclosed    => '"',
                        p_num_of_columns       => 17,
                        retcode                => retcode,
                        errbuf                 => errbuf);

                    --

                    UPDATE xxdo.xxd_oe_can_loyalty_card_stg_t
                       SET file_name = data.filename, request_id = gn_request_id, creation_date = SYSDATE,
                           last_update_date = SYSDATE, created_by = gn_user_id, last_updated_by = gn_user_id
                     WHERE file_name IS NULL AND request_id IS NULL;

                    get_coupon_segments (lv_vs_coupon_gl,
                                         lv_coupon_segment1,
                                         lv_coupon_segment2,
                                         lv_coupon_segment3,
                                         lv_coupon_segment4,
                                         lv_coupon_segment5,
                                         lv_coupon_segment6,
                                         lv_coupon_segment7,
                                         lv_coupon_segment8);

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Coupon Segment1 is:' || lv_coupon_segment1);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Coupon Segment2 is:' || lv_coupon_segment2);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Coupon Segment3 is:' || lv_coupon_segment3);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Coupon Segment4 is:' || lv_coupon_segment4);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Coupon Segment5 is:' || lv_coupon_segment5);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Coupon Segment6 is:' || lv_coupon_segment6);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Coupon Segment7 is:' || lv_coupon_segment7);

                    -- check wheather the data is exist already, if yes purge the date into new custom table, and insert the new records.
                    BEGIN
                        SELECT COUNT (1)
                          INTO ln_file_exists
                          FROM xxdo.xxd_oe_can_loyalty_card_t
                         WHERE period_end_date = lv_period_end_date;    -- 1.1
                    -- upper(file_name) = upper(data.filename);--1.1

                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_file_exists   := 0;
                    END;

                    IF NVL (ln_file_exists, 0) <> 0
                    THEN                                                -- 1.1
                        purge_can_card_duplicates (lv_period_end_date,
                                                   pn_org_id,
                                                   lv_can_card_purge_status);
                    END IF;

                    --IF nvl(lv_can_card_purge_status, 'E') = 'S' THEN
                    -- Load the data in custom table
                    BEGIN
                        INSERT INTO xxdo.xxd_oe_can_loyalty_card_t
                            (SELECT date_at, reward_id, cost,
                                    strating_balance, issued, reward_issued_local_value,
                                    redeemed, reward_redeemed_local_value, expired,
                                    reward_expired_local_value, invalidated, reward_invalid_local_val,
                                    reissued, reward_reissued_local_value, ending_balance,
                                    reward_ending_bal_local_val, NULL, -- report amount
                                                                       NULL, -- period_year
                                    NULL,                      -- period_month
                                          NULL,                 -- period_name
                                                NULL,
                                    NULL, NULL, NULL,
                                    NULL, NULL, NULL,
                                    NULL, NULL, NULL,
                                    lv_coupon_segment1, --entity_unique_identifier   ,
                                                        lv_coupon_segment6, --account_number             ,
                                                                            lv_coupon_segment2, --key3                       ,
                                    lv_coupon_segment3, --key                        ,
                                                        lv_coupon_segment4, --key5                       ,
                                                                            lv_coupon_segment5, --key6                       ,
                                    lv_coupon_segment7, --key7                       ,
                                                        NULL, NULL,
                                    NULL, lv_period_end_date, --period_end_date            ,
                                                              NULL, --subledger_rep_bal          ,
                                    NULL,       --subledger_alt_bal          ,
                                          NULL, --subledger_acc_bal          ,
                                                gn_user_id,
                                    SYSDATE, gn_user_id, SYSDATE,
                                    gn_request_id, data.filename,  --file_name
                                                                  pn_org_id
                               FROM xxdo.xxd_oe_can_loyalty_card_stg_t
                              WHERE     request_id = gn_request_id
                                    AND TO_DATE (date_at, 'YYYY-MM-DD') <=
                                        TO_DATE (lv_period_end_date,
                                                 'MM/DD/YYYY'));

                        COMMIT;
                        fnd_file.put_line (fnd_file.LOG,
                                           'Insertion is Success:');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Insertion is failed:' || SQLERRM);
                    END;

                    ld_period_end_date   :=
                        TO_DATE (lv_period_end_date, 'MM/DD/YYYY');

                    -- get the points amount
                    ln_can_coupon_amt   :=
                        get_can_coupon_amt (ld_period_end_date,
                                            gn_request_id,
                                            lv_vs_1st_coupon_amount,
                                            lv_vs_2nd_coupon_amount,
                                            lv_vs_3rd_coupon_amount,
                                            pn_org_id);

                    -- UPDATE the ln_us_points_amt in custom table
                    BEGIN
                        UPDATE xxdo.xxd_oe_can_loyalty_card_t
                           SET subledger_acc_bal = ln_can_coupon_amt, last_updated_by = gn_user_id, last_update_date = SYSDATE
                         WHERE request_id = gn_request_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Update is failed:' || SQLERRM);
                    END;
                --

                -- copyfile_prc(data.filename, SYSDATE || data.filename, lv_coupon_dir, lv_archive_dir);
                ----
                --Utl_File.Fremove('XXD_LCX_BAL_BL_INB_DIR', data.filename);

                /*write_op_file(pv_file_path, pv_period_end_date, pv_type, lv_vs_file_method, pn_org_id, lv_ret_code, lv_ret_message

                );
                write_ret_recon_file(pv_type, lv_vs_file_method, pv_file_path, lv_ret_code, lv_ret_message);
                update_valueset_prc(pv_file_path);*/
                /* ELSE
                     write_log(' Data with this File name - '
                               || data.filename
                               || ' - is already loaded. Please change the file data ');
                 END IF;*/

                --END IF;

                END LOOP;

                write_op_file (pv_file_path, pv_period_end_date, pv_type,
                               lv_vs_file_method, pn_org_id, lv_ret_code,
                               lv_ret_message, NULL, NULL);
                write_ret_recon_file (pv_type, lv_vs_file_method, pv_file_path
                                      , lv_ret_code, lv_ret_message);
                update_valueset_prc (pv_file_path);
            --  END IF;
            END IF;
        END IF;
    /* write_op_file(pv_file_path, pv_period_end_date, pv_type, lv_vs_file_method, pn_org_id, lv_ret_code, lv_ret_message);
     write_ret_recon_file(pv_type, lv_vs_file_method, pv_file_path, lv_ret_code, lv_ret_message);
     update_valueset_prc(pv_file_path);*/

    END main_prc;
END;
/
