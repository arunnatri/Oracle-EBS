--
-- XXDOAR_CREDIT_DATAPOINT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:21 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOAR_CREDIT_DATAPOINT_PKG"
IS
    /***********************************************************************************************************
       file name    : xxdoar_credit_datapoint_pkg.pkb
       created on   : 11-FEB-2015
       created by   : Infosys
       purpose      : package body used for the following

                      1. For Manual review on credit request.

     ***********************************************************************************************************
      Modification history:
     ***********************************************************************************************************
         NAME:        xxdoar_credit_datapoint_pkg
         PURPOSE:

         REVISIONS:
         Version        Date        Author           Description
         ---------  ----------  ---------------  -------------------------------
         1.0         02/11/2015     Infosys        Initial Version.
         1.1         04/21/2015     Infosys      Modified to fix the QC defect ID 903.
         1.2         05/28/2015     Infosys      Modified to fix the QC defect ID 1647
    ************************************************************************************************************
    ************************************************************************************************************/
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

    FUNCTION get_assigned_credit_line (x_resultout      OUT NOCOPY VARCHAR2,
                                       x_errormsg       OUT NOCOPY VARCHAR2)
        RETURN NUMBER
    IS
        l_credit_request_id      NUMBER
            := ocm_add_data_points.pg_ocm_add_dp_param_rec.p_credit_request_id;
        l_party_id               NUMBER
            := ocm_add_data_points.pg_ocm_add_dp_param_rec.p_party_id;
        l_assigned_credit_line   NUMBER;
    BEGIN
        SELECT NVL (assigned_credit_line, calculated_credit_line)
          INTO l_assigned_credit_line
          FROM xxdoar_credit_data_points_stg
         WHERE     credit_request_id = l_credit_request_id
               AND party_id = l_party_id;

        ocm_add_data_points.pg_ocm_add_dp_param_rec.p_data_point_value   :=
            l_assigned_credit_line;
        RETURN (l_assigned_credit_line);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_assigned_credit_line;

    FUNCTION get_calculated_credit_line (
        x_resultout      OUT NOCOPY VARCHAR2,
        x_errormsg       OUT NOCOPY VARCHAR2)
        RETURN NUMBER
    IS
        l_credit_request_id        NUMBER
            := ocm_add_data_points.pg_ocm_add_dp_param_rec.p_credit_request_id;
        l_party_id                 NUMBER
            := ocm_add_data_points.pg_ocm_add_dp_param_rec.p_party_id;
        l_calculated_credit_line   NUMBER;
    BEGIN
        SELECT calculated_credit_line
          INTO l_calculated_credit_line
          FROM xxdoar_credit_data_points_stg
         WHERE     credit_request_id = l_credit_request_id
               AND party_id = l_party_id;

        ocm_add_data_points.pg_ocm_add_dp_param_rec.p_data_point_value   :=
            l_calculated_credit_line;
        RETURN (l_calculated_credit_line);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_calculated_credit_line;

    FUNCTION get_alert_code (x_resultout      OUT NOCOPY VARCHAR2,
                             x_errormsg       OUT NOCOPY VARCHAR2)
        RETURN VARCHAR2
    IS
        l_credit_request_id   NUMBER
            := ocm_add_data_points.pg_ocm_add_dp_param_rec.p_credit_request_id;
        l_party_id            NUMBER
            := ocm_add_data_points.pg_ocm_add_dp_param_rec.p_party_id;
        l_alert_code          VARCHAR2 (100);
    BEGIN
        SELECT alert_code
          INTO l_alert_code
          FROM xxdoar_credit_data_points_stg
         WHERE     credit_request_id = l_credit_request_id
               AND party_id = l_party_id;

        ocm_add_data_points.pg_ocm_add_dp_param_rec.p_data_point_value   :=
            l_alert_code;
        RETURN (l_alert_code);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_alert_code;

    FUNCTION get_credit_score (x_resultout      OUT NOCOPY VARCHAR2,
                               x_errormsg       OUT NOCOPY VARCHAR2)
        RETURN NUMBER
    IS
        l_credit_request_id   NUMBER
            := ocm_add_data_points.pg_ocm_add_dp_param_rec.p_credit_request_id;
        l_party_id            NUMBER
            := ocm_add_data_points.pg_ocm_add_dp_param_rec.p_party_id;
        l_credit_score        VARCHAR2 (100);
    BEGIN
        SELECT credit_score
          INTO l_credit_score
          FROM xxdoar_credit_data_points_stg
         WHERE     credit_request_id = l_credit_request_id
               AND party_id = l_party_id;

        ocm_add_data_points.pg_ocm_add_dp_param_rec.p_data_point_value   :=
            l_credit_score;
        RETURN (l_credit_score);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_credit_score;

    FUNCTION get_intelliscore (x_resultout      OUT NOCOPY VARCHAR2,
                               x_errormsg       OUT NOCOPY VARCHAR2)
        RETURN NUMBER
    IS
        l_credit_request_id   NUMBER
            := ocm_add_data_points.pg_ocm_add_dp_param_rec.p_credit_request_id;
        l_party_id            NUMBER
            := ocm_add_data_points.pg_ocm_add_dp_param_rec.p_party_id;
        l_intelliscore        VARCHAR2 (100);
    BEGIN
        SELECT intelliscore
          INTO l_intelliscore
          FROM xxdoar_credit_data_points_stg
         WHERE     credit_request_id = l_credit_request_id
               AND party_id = l_party_id;

        ocm_add_data_points.pg_ocm_add_dp_param_rec.p_data_point_value   :=
            l_intelliscore;
        RETURN (l_intelliscore);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_intelliscore;

    FUNCTION get_manual_review (x_resultout      OUT NOCOPY VARCHAR2,
                                x_errormsg       OUT NOCOPY VARCHAR2)
        RETURN VARCHAR2
    IS
        l_credit_request_id   NUMBER
            := ocm_add_data_points.pg_ocm_add_dp_param_rec.p_credit_request_id;
        l_party_id            NUMBER
            := ocm_add_data_points.pg_ocm_add_dp_param_rec.p_party_id;
        l_manual_review       VARCHAR2 (100);
    BEGIN
        SELECT manual_review
          INTO l_manual_review
          FROM xxdoar_credit_data_points_stg
         WHERE     credit_request_id = l_credit_request_id
               AND party_id = l_party_id;

        ocm_add_data_points.pg_ocm_add_dp_param_rec.p_data_point_value   :=
            l_manual_review;
        RETURN (l_manual_review);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_manual_review;

    FUNCTION get_pqi (x_resultout      OUT NOCOPY VARCHAR2,
                      x_errormsg       OUT NOCOPY VARCHAR2)
        RETURN NUMBER
    IS
        l_credit_request_id   NUMBER
            := ocm_add_data_points.pg_ocm_add_dp_param_rec.p_credit_request_id;
        l_party_id            NUMBER
            := ocm_add_data_points.pg_ocm_add_dp_param_rec.p_party_id;
        l_pqi                 NUMBER;
    BEGIN
        SELECT payment_quality_index
          INTO l_pqi
          FROM xxdoar_credit_data_points_stg
         WHERE     credit_request_id = l_credit_request_id
               AND party_id = l_party_id;

        ocm_add_data_points.pg_ocm_add_dp_param_rec.p_data_point_value   :=
            l_pqi;
        RETURN (l_pqi);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_pqi;

    FUNCTION get_score_date (x_resultout      OUT NOCOPY VARCHAR2,
                             x_errormsg       OUT NOCOPY VARCHAR2)
        RETURN DATE
    IS
        l_credit_request_id   NUMBER
            := ocm_add_data_points.pg_ocm_add_dp_param_rec.p_credit_request_id;
        l_party_id            NUMBER
            := ocm_add_data_points.pg_ocm_add_dp_param_rec.p_party_id;
        l_score_date          VARCHAR2 (30);
    BEGIN
        SELECT score_date
          INTO l_score_date
          FROM xxdoar_credit_data_points_stg
         WHERE     credit_request_id = l_credit_request_id
               AND party_id = l_party_id;

        ocm_add_data_points.pg_ocm_add_dp_param_rec.p_data_point_value   :=
            l_score_date;
        RETURN (l_score_date);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_score_date;

    FUNCTION get_yrs_in_business (x_resultout      OUT NOCOPY VARCHAR2,
                                  x_errormsg       OUT NOCOPY VARCHAR2)
        RETURN NUMBER
    IS
        l_credit_request_id   NUMBER
            := ocm_add_data_points.pg_ocm_add_dp_param_rec.p_credit_request_id;
        l_party_id            NUMBER
            := ocm_add_data_points.pg_ocm_add_dp_param_rec.p_party_id;
        l_yrs_in_business     NUMBER;
    BEGIN
        SELECT years_in_business
          INTO l_yrs_in_business
          FROM xxdoar_credit_data_points_stg
         WHERE     credit_request_id = l_credit_request_id
               AND party_id = l_party_id;

        ocm_add_data_points.pg_ocm_add_dp_param_rec.p_data_point_value   :=
            l_yrs_in_business;
        RETURN (l_yrs_in_business);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_yrs_in_business;

    FUNCTION get_nsf (x_resultout      OUT NOCOPY VARCHAR2,
                      x_errormsg       OUT NOCOPY VARCHAR2)
        RETURN VARCHAR2
    IS
        l_credit_request_id   NUMBER
            := ocm_add_data_points.pg_ocm_add_dp_param_rec.p_credit_request_id;
        l_party_id            NUMBER
            := ocm_add_data_points.pg_ocm_add_dp_param_rec.p_party_id;
        l_nsf                 VARCHAR2 (100);
    BEGIN
        SELECT nsf
          INTO l_nsf
          FROM xxdoar_credit_data_points_stg
         WHERE     credit_request_id = l_credit_request_id
               AND party_id = l_party_id;

        ocm_add_data_points.pg_ocm_add_dp_param_rec.p_data_point_value   :=
            l_nsf;
        RETURN (l_nsf);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_nsf;

    FUNCTION get_ownership_change (x_resultout      OUT NOCOPY VARCHAR2,
                                   x_errormsg       OUT NOCOPY VARCHAR2)
        RETURN NUMBER
    IS
        l_credit_request_id   NUMBER
            := ocm_add_data_points.pg_ocm_add_dp_param_rec.p_credit_request_id;
        l_party_id            NUMBER
            := ocm_add_data_points.pg_ocm_add_dp_param_rec.p_party_id;
        l_owner_ship_change   NUMBER;
    BEGIN
        SELECT ownership_change
          INTO l_owner_ship_change
          FROM xxdoar_credit_data_points_stg
         WHERE     credit_request_id = l_credit_request_id
               AND party_id = l_party_id;

        ocm_add_data_points.pg_ocm_add_dp_param_rec.p_data_point_value   :=
            l_owner_ship_change;
        RETURN (l_owner_ship_change);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_ownership_change;

    FUNCTION get_confidence_level (x_resultout      OUT NOCOPY VARCHAR2,
                                   x_errormsg       OUT NOCOPY VARCHAR2)
        RETURN NUMBER
    IS
        l_credit_request_id   NUMBER
            := ocm_add_data_points.pg_ocm_add_dp_param_rec.p_credit_request_id;
        l_party_id            NUMBER
            := ocm_add_data_points.pg_ocm_add_dp_param_rec.p_party_id;
        l_confidence_level    NUMBER;
    BEGIN
        SELECT confidence_level
          INTO l_confidence_level
          FROM xxdoar_credit_data_points_stg
         WHERE     credit_request_id = l_credit_request_id
               AND party_id = l_party_id;

        ocm_add_data_points.pg_ocm_add_dp_param_rec.p_data_point_value   :=
            l_confidence_level;
        RETURN (l_confidence_level);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_confidence_level;

    --PROCEDURE apply_recommendation (pv_retcode    OUT VARCHAR2,
    --                                pv_reterror   OUT VARCHAR2)
    --IS
    FUNCTION apply_recommendation (
        p_subscription_guid   IN            RAW,
        p_event               IN OUT NOCOPY wf_event_t)
        RETURN VARCHAR2
    IS
        l_credit_rating           VARCHAR2 (80 BYTE);
        lv_operating_unit         VARCHAR2 (240) := 'Deckers US OU';
        l_num_org_id              NUMBER;
        l_credit_classification   VARCHAR2 (30 BYTE);  -- UnCommented for 1.2.
        lv_review_cycle           VARCHAR2 (80 BYTE);
        l_next_review_date        DATE;
        l_last_review_date        DATE;
        l_credit_analyst_id       NUMBER;
        ln_review_diff            NUMBER;
        l_new_review_date         DATE;
        l_credit_request_id       NUMBER;
        l_party_id                NUMBER;
        l_request_id              NUMBER;
        l_recommendation_id       NUMBER;


        CURSOR csr_recomd_records (p_credit_request_id IN NUMBER)
        IS
            SELECT *
              FROM xxdoar_credit_data_points_stg
             WHERE credit_request_id = p_credit_request_id AND status = 'N';
    BEGIN
        l_credit_request_id   :=
            p_event.GetValueForParameter ('CREDIT_REQUEST_ID');

        write_to_table (
            'Credit Request Id From xxdoar_credit_datapoint_pkg.apply_recommendation',
            l_credit_request_id);


        BEGIN
            SELECT DISTINCT (credit_request_id)
              INTO l_request_id
              FROM ar_cmgt_cf_recommends
             WHERE credit_request_id = l_credit_request_id AND status = 'I';
        EXCEPTION
            WHEN OTHERS
            THEN
                write_to_table (
                    'Error in finding Request ID from recommendatin table',
                    l_request_id);
        END;

        FOR rec_recomd_records IN csr_recomd_records (l_request_id)
        LOOP
            BEGIN
                UPDATE hz_parties
                   SET attribute_category = 'Customer', attribute1 = rec_recomd_records.credit_score, attribute2 = rec_recomd_records.payment_quality_index,
                       attribute3 = rec_recomd_records.nsf, category_code = 'CUSTOMER'
                 WHERE party_id = rec_recomd_records.party_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_to_table (
                           'Error while updating Party DFFs for party id:'
                        || rec_recomd_records.party_id,
                        SQLERRM);
            END;

            BEGIN
                SELECT organization_id
                  INTO l_num_org_id
                  FROM hr_operating_units
                 WHERE NAME = lv_operating_unit;

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
                           AND TO_NUMBER (rec_recomd_records.credit_score) BETWEEN TO_NUMBER (
                                                                                       attr1)
                                                                               AND TO_NUMBER (
                                                                                       attr2);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        write_to_table (
                            'Error in Fetching Credit Rating for score ',
                            SQLERRM);
                END;
            END;

            /* UnCommented for 1.2.*/
            BEGIN
                SELECT credit_classification
                  INTO l_credit_classification
                  FROM ar_cmgt_credit_requests
                 WHERE credit_request_id =
                       rec_recomd_records.credit_request_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_credit_classification   := NULL;
                    write_to_table (
                        'Error in Fetching Credit Classification',
                        SQLERRM);
            END;

            /*  UnCommented for 1.2. */

            BEGIN
                SELECT next_credit_review_date, last_credit_review_date, review_cycle,
                       credit_analyst_id
                  INTO l_next_review_date, l_last_review_date, lv_review_cycle, l_credit_analyst_id
                  FROM hz_customer_profiles
                 WHERE     party_id = rec_recomd_records.party_id
                       AND cust_account_id = -1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_review_cycle       := NULL;
                    l_next_review_date    := NULL;
                    l_last_review_date    := NULL;
                    l_credit_analyst_id   := NULL;
                    write_to_table (
                        'Error in Fetching Customer Profile Details',
                        SQLERRM);
            END;

            IF    l_next_review_date IS NULL
               OR l_last_review_date IS NULL
               OR lv_review_cycle IS NULL
            THEN
                l_new_review_date   := rec_recomd_records.score_date + 365;
            ELSE
                IF TO_DATE (rec_recomd_records.review_date) BETWEEN TO_DATE (
                                                                        l_last_review_date)
                                                                AND TO_DATE (
                                                                        l_next_review_date)
                THEN
                    l_new_review_date   := l_next_review_date;
                ELSE
                    SELECT TO_DATE (l_next_review_date) - TO_DATE (rec_recomd_records.review_date)
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

            BEGIN
                UPDATE hz_customer_profiles
                   SET credit_rating = l_credit_rating, --  credit_classification = l_credit_classification,               -- Commented for 1.1.
                                                        review_cycle = NVL (lv_review_cycle, 'YEARLY'), next_credit_review_date = l_new_review_date,
                       last_credit_review_date = rec_recomd_records.score_date, credit_analyst_id = l_credit_analyst_id
                 WHERE     party_id = rec_recomd_records.party_id
                       AND cust_account_id = -1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_to_table (
                        'Error while updating Customer Profile Details',
                        SQLERRM);
            END;

            --Update is added for 1.2 -- Defect 1647
            BEGIN
                UPDATE hz_customer_profiles
                   SET credit_rating = l_credit_rating, credit_classification = l_credit_classification, review_cycle = 'YEARLY',
                       last_credit_review_date = SYSDATE, credit_analyst_id = l_credit_analyst_id
                 /*(SELECT credit_analyst_id
                    FROM hz_customer_profiles
                   WHERE party_id = rec_recomd_records.party_id
                         AND cust_account_id =
                                (SELECT cust_account_id
                                   FROM hz_cust_accounts
                                  WHERE party_id = rec_recomd_records.party_id
                                        AND attribute1 = 'ALL BRAND'))*/
                 WHERE     party_id = rec_recomd_records.party_id
                       AND cust_account_id != -1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_to_table (
                        'Error in Updating Profiles for ALL Brand Accounts',
                        SQLERRM);
            END;

            COMMIT;

            BEGIN
                UPDATE xxdoar_credit_data_points_stg
                   SET status   = 'S'
                 WHERE credit_request_id =
                       rec_recomd_records.credit_request_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_to_table (
                        'Error while updating Staging table status',
                        SQLERRM);
            END;

            COMMIT;
        END LOOP;
    END apply_recommendation;
END xxdoar_credit_datapoint_pkg;
/
