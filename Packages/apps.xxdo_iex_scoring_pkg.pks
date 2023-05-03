--
-- XXDO_IEX_SCORING_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:09 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_IEX_SCORING_PKG"
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
    -- 09-NOV-2016   1.2          Madhav Dhurjaty                   Canada 3PL Project
    -- 07-NOV-2016   1.3          Srinath Siricilla                 Switzerland Project
    -- 14-MAR-2017   1.4          Infosys                           Changes in populate_adl procedure to fix the deadlock error and also to insert the
                                                                    attribute1 (brand-mandatory column) to custom table while calling insert_update procedure
    -- 11-APR-2018   1.5          Srinath Siricilla                 CCR0007180
    -- 01-AUG-2022   2.0          Srinath Siricilla                 CCR0009857
    -- 06-JAN-2023   2.1          Kishan Reddy                      CCR0009817: To update the AR
    --                                                              collection data fro DAP OU
    ******************************************************************************************/

    V_AGING_BUCKET   VARCHAR2 (20);

    FUNCTION get_score_us (P_CUST_ACCOUNT_ID      IN NUMBER,
                           P_SCORE_COMPONENT_ID   IN NUMBER)
        RETURN NUMBER;

    /*Start of changes as part of Canada 3PL Project by Madhav Dhurjaty on 09-NOV-2016*/
    FUNCTION get_score_ca (P_CUST_ACCOUNT_ID      IN NUMBER,
                           P_SCORE_COMPONENT_ID   IN NUMBER)
        RETURN NUMBER;

    /*End of changes as part of Canada 3PL Project by Madhav Dhurjaty on 09-NOV-2016*/

    /*Start of changes as part of Switzerland Project by srinath siricilla on 07-NOV-2016*/
    FUNCTION get_score_switzerland (P_CUST_ACCOUNT_ID      IN NUMBER,
                                    P_SCORE_COMPONENT_ID   IN NUMBER)
        RETURN NUMBER;

    /*End of changes as part of Switzerland Project by srinath siricilla on 07-NOV-2016*/

    FUNCTION get_score_uk (P_CUST_ACCOUNT_ID      IN NUMBER,
                           P_SCORE_COMPONENT_ID   IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_score_benelux (P_CUST_ACCOUNT_ID      IN NUMBER,
                                P_SCORE_COMPONENT_ID   IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_score_germany (P_CUST_ACCOUNT_ID      IN NUMBER,
                                P_SCORE_COMPONENT_ID   IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_score_france (P_CUST_ACCOUNT_ID      IN NUMBER,
                               P_SCORE_COMPONENT_ID   IN NUMBER)
        RETURN NUMBER;

    -- Start of Change for CCR0009857

    FUNCTION get_score_italy (P_CUST_ACCOUNT_ID      IN NUMBER,
                              P_SCORE_COMPONENT_ID   IN NUMBER)
        RETURN NUMBER;

    -- End of Change for CCR0009857

    -- Start of change for CCR0009817
    FUNCTION score_apac_wholesale (P_CUST_ACCOUNT_ID      IN NUMBER,
                                   P_SCORE_COMPONENT_ID   IN NUMBER)
        RETURN NUMBER;

    -- End of Change for CCR0009817

    /*Start of changes as part of CCR0007180 */
    --FUNCTION get_score_japan (P_CUST_ACCOUNT_ID      IN NUMBER,
    --                        P_SCORE_COMPONENT_ID   IN NUMBER)
    -- RETURN NUMBER;
    /*End of changes as part of CCR0007180 */

    /* FUNCTION get_mapped_score (p_score IN NUMBER, p_bucket VARCHAR2)
       RETURN NUMBER;*/

    FUNCTION get_last_payment_score (P_CUST_ACCOUNT_ID IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_amount_due (P_CUST_ACCOUNT_ID IN NUMBER, From_days IN NUMBER, to_days IN NUMBER)
        RETURN NUMBER;

    /*Start of changes as part of CCR0009857*/

    FUNCTION get_aging_bucket_avg_score_it (P_CUST_ACCOUNT_ID IN NUMBER)
        RETURN NUMBER;

    /*End of changes as part of CCR0009857*/

    FUNCTION get_aging_bucket_avg_score_us (P_CUST_ACCOUNT_ID IN NUMBER)
        RETURN NUMBER;

    /*Start of changes as part of Canada 3PL Project by Madhav Dhurjaty on 09-NOV-2016*/
    FUNCTION get_aging_bucket_avg_score_ca (P_CUST_ACCOUNT_ID IN NUMBER)
        RETURN NUMBER;

    /*End of changes as part of Canada 3PL Project by Madhav Dhurjaty on 09-NOV-2016*/

    /*Start of changes as part of Switzerland Project by srinath siricilla on 07-NOV-2016*/

    FUNCTION get_aging_bucket_avg_score_sz (P_CUST_ACCOUNT_ID IN NUMBER)
        RETURN NUMBER;

    /*End of changes as part of Switzerland Project by srinath siricilla on 07-NOV-2016*/

    FUNCTION get_aging_bucket_avg_score_uk (P_CUST_ACCOUNT_ID IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_aging_bucket_avg_score_fr (P_CUST_ACCOUNT_ID IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_aging_bucket_avg_score_gr (P_CUST_ACCOUNT_ID IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_aging_bucket_avg_score_bx (P_CUST_ACCOUNT_ID IN NUMBER)
        RETURN NUMBER;

    /*Start of changes as part of CCR0007180 */
    FUNCTION get_aging_bucket_avg_score_jp (P_CUST_ACCOUNT_ID IN NUMBER)
        RETURN NUMBER;

    /*End of changes as part of CCR0007180 */

    FUNCTION get_Weight (p_weight_name VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_booked_order_score (P_CUST_ACCOUNT_ID IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_adl_score (P_CUST_ACCOUNT_ID IN NUMBER)
        RETURN NUMBER;


    /*Start of changes as part of CCR0007180 */
    /*
    FUNCTION caluclate_score (ln_aging_bucket_score    NUMBER,
                              ln_aging_bucket_wt       NUMBER,
                              ln_last_payment_score    NUMBER,
                              ln_last_payment_wt       NUMBER,
                              ln_book_order_score      NUMBER,
                              ln_book_order_wt         NUMBER,
                              ln_adl_score             NUMBER,
                              ln_adl_wt                NUMBER,
                              lc_prorate_score         VARCHAR2)
       RETURN NUMBER;*/

    FUNCTION caluclate_score (ln_aging_bucket_score NUMBER, ln_aging_bucket_wt NUMBER, ln_last_payment_score NUMBER, ln_last_payment_wt NUMBER, ln_book_order_score NUMBER, ln_book_order_wt NUMBER, ln_adl_score NUMBER, ln_adl_wt NUMBER, lc_prorate_score VARCHAR2
                              , lc_use_weight VARCHAR2) -- Added new to the existing CCR0007180
        RETURN NUMBER;

    /* End of changes as part of CCR0007180 */

    PROCEDURE LOG (p_log_message   IN VARCHAR2,
                   p_module        IN VARCHAR2,
                   p_line_number   IN NUMBER);

    FUNCTION get_non_weight_mapping_score (p_cust_account_id   IN NUMBER,
                                           p_score                NUMBER)
        RETURN NUMBER;

    PROCEDURE POPULATE_ADL (p_errbuff OUT VARCHAR2, p_retcode OUT VARCHAR2, p_ou IN VARCHAR2, p_cust_account_from IN VARCHAR2, p_dummy IN VARCHAR2, p_cust_account_to IN VARCHAR2
                            , p_party_name_from IN VARCHAR2, p_dummy1 IN VARCHAR2, p_party_name_to IN VARCHAR2);

    FUNCTION SCORE_DIST (p_cust_account_id      IN NUMBER,
                         p_score_component_id   IN NUMBER)
        RETURN NUMBER;

    /*Start of changes as part of CCR0007180 */
    FUNCTION SCORE_JAPAN (p_cust_account_id      IN NUMBER,
                          p_score_component_id   IN NUMBER)
        RETURN NUMBER;

    /*End of changes as part of CCR0007180 */

    FUNCTION SCORE_ECOMM (p_cust_account_id      IN NUMBER,
                          p_score_component_id   IN NUMBER)
        RETURN NUMBER;

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
                             p_attribute20          IN VARCHAR2 DEFAULT NULL);
END XXDO_IEX_SCORING_PKG;
/
