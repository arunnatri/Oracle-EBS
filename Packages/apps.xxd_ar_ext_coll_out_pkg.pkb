--
-- XXD_AR_EXT_COLL_OUT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:28 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AR_EXT_COLL_OUT_PKG"
IS
    /***************************************************************************************
    * Program Name : XXD_AR_EXT_COLL_OUT_PKG                                               *
    * Language     : PL/SQL                                                                *
    * Description  : Package to generate xml file for iCollector integration               *
    *                                                                                      *
    * History      :                                                                       *
    *                                                                                      *
    * WHO          :       WHAT      Desc                                    WHEN          *
    * -------------- ----------------------------------------------------------------------*
    * Kishan Reddy         1.0       Initial Version                         16-JUL-2022   *
    * -------------------------------------------------------------------------------------*/

    v_filename                    VARCHAR2 (30);
    f_xml_file                    UTL_FILE.file_type;
    gn_user_id           CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id          CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id            CONSTANT NUMBER := fnd_global.org_id;
    gn_resp_id           CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id      CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_conc_request_id   CONSTANT NUMBER := fnd_global.conc_request_id;

    PROCEDURE print_log (pv_msg IN VARCHAR2, pv_time IN VARCHAR2 DEFAULT 'N')
    IS
        lv_proc_name    VARCHAR2 (30) := 'PRINT_LOG';
        lv_msg          VARCHAR2 (4000);
        lv_time_stamp   VARCHAR2 (20)
                            := TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS');
    BEGIN
        IF pv_time = 'Y'
        THEN
            lv_msg   := pv_msg || '. Timestamp: ' || lv_time_stamp;
        ELSE
            lv_msg   := pv_msg;
        END IF;

        IF gn_user_id = -1
        THEN
            DBMS_OUTPUT.put_line (lv_msg);
        ELSE
            fnd_file.put_line (fnd_file.LOG, lv_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Unable to print log:' || SQLERRM);
    END print_log;

    FUNCTION get_claim_owner (p_claim_id IN NUMBER)
        RETURN VARCHAR2
    AS
        lv_owner_name   VARCHAR2 (250);
    BEGIN
        SELECT source_name
          INTO lv_owner_name
          FROM jtf_rs_resource_extns jrse, ozf_claims_all oca
         WHERE     jrse.resource_id = oca.owner_id
               AND SYSDATE BETWEEN jrse.start_date_active
                               AND NVL (jrse.end_date_active, SYSDATE + 1)
               AND oca.claim_id = p_claim_id;

        RETURN lv_owner_name;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_last_payment_date (p_party_id IN NUMBER)
        RETURN DATE
    AS
        ld_payment_date   DATE;
    BEGIN
        SELECT bal.last_payment_date
          INTO ld_payment_date
          FROM ar_trx_bal_summary bal, hz_cust_accounts hca
         WHERE     bal.last_payment_date IS NOT NULL
               AND bal.cust_account_id = hca.cust_account_id
               AND bal.last_payment_date >=
                   (SELECT MAX (last_payment_date)
                      FROM ar_trx_bal_summary bal1, hz_cust_accounts cust
                     WHERE     bal1.cust_account_id = cust.cust_account_id
                           AND bal1.last_payment_date IS NOT NULL
                           AND cust.party_id = p_party_id)
               AND hca.party_id = p_party_id;

        RETURN ld_payment_date;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_last_payment_date;

    FUNCTION get_last_payment_due_date (p_party_id IN NUMBER)
        RETURN DATE
    AS
        ld_payment_date   DATE;
    BEGIN
        SELECT MAX (DECODE (ps.payment_schedule_id, -1, NULL, ps.due_date))
          INTO ld_payment_date
          FROM ar_trx_bal_summary trx_sum, hz_cust_accounts ca, ar_cash_receipts_all cr,
               ar_receivable_applications_all ra, ar_payment_schedules_all ps
         WHERE     ca.party_id = p_party_id
               AND ca.cust_account_id = trx_sum.cust_account_id --Added for bug#7512425 by PNAVEENK
               AND cr.pay_from_customer = trx_sum.cust_account_id --Added for bug#7512425 by PNAVEENK
               AND cr.customer_site_use_id = trx_sum.site_use_id
               AND TRUNC (cr.receipt_date) =
                   TRUNC (trx_sum.last_payment_date)
               AND ABS (cr.amount) = ABS (trx_sum.last_payment_amount)
               AND cr.receipt_number = trx_sum.last_payment_number
               AND ra.cash_receipt_id(+) = cr.cash_receipt_id
               AND ps.payment_schedule_id(+) = ra.applied_payment_schedule_id
               AND trx_sum.last_payment_date IS NOT NULL
               AND NVL (ps.payment_schedule_id, 0) > 0;

        RETURN ld_payment_date;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_last_payment_due_date;

    FUNCTION get_last_payment_amt (p_party_id IN NUMBER)
        RETURN NUMBER
    AS
        ln_payment_amt   NUMBER;
    BEGIN
        SELECT bal.last_payment_amount
          INTO ln_payment_amt
          FROM ar_trx_bal_summary bal, hz_cust_accounts hca
         WHERE     bal.last_payment_date IS NOT NULL
               AND bal.cust_account_id = hca.cust_account_id
               AND bal.last_payment_date >=
                   (SELECT MAX (last_payment_date)
                      FROM ar_trx_bal_summary bal1, hz_cust_accounts cust
                     WHERE     bal1.cust_account_id = cust.cust_account_id
                           AND bal1.last_payment_date IS NOT NULL
                           AND cust.party_id = p_party_id)
               AND hca.party_id = p_party_id;

        RETURN ln_payment_amt;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_last_payment_amt;

    FUNCTION get_currency (p_org_id IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_currency   VARCHAR2 (30);
    BEGIN
        SELECT ffv.attribute3
          INTO lv_currency
          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values ffv
         WHERE     1 = 1
               AND ffvs.flex_value_set_id = ffv.flex_value_set_id
               AND ffvs.flex_value_set_name = 'XXD_AR_COLL_DEFAULT_VS'
               AND ffv.enabled_flag = 'Y'
               AND NVL (ffv.start_date_active, SYSDATE) <= SYSDATE
               AND NVL (ffv.end_date_active, SYSDATE + 1) > SYSDATE
               AND ffv.attribute1 = TO_CHAR (p_org_id);

        RETURN lv_currency;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_currency;

    FUNCTION get_country (p_org_id IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_country   VARCHAR2 (30);
    BEGIN
        SELECT ffv.attribute4
          INTO lv_country
          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values ffv
         WHERE     1 = 1
               AND ffvs.flex_value_set_id = ffv.flex_value_set_id
               AND ffvs.flex_value_set_name = 'XXD_AR_COLL_DEFAULT_VS'
               AND ffv.enabled_flag = 'Y'
               AND NVL (ffv.start_date_active, SYSDATE) <= SYSDATE
               AND NVL (ffv.end_date_active, SYSDATE + 1) > SYSDATE
               AND ffv.attribute1 = TO_CHAR (p_org_id);

        RETURN lv_country;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_country;

    FUNCTION get_language (p_customer_id IN NUMBER, p_bill_to_site_use_id IN NUMBER, p_org_id IN NUMBER
                           , p_party_id IN NUMBER)
        RETURN VARCHAR2
    IS
        ln_org_id            NUMBER;
        lv_lang_code         VARCHAR2 (30);
        lv_lang_at_account   VARCHAR2 (30);
        lv_lang_at_site      VARCHAR2 (30);
        x_lang_code          VARCHAR2 (30);
        ln_lang_cnt          NUMBER := 0;
        lv_nb_lang           VARCHAR2 (60);
        ln_lang_count        NUMBER := 0;
    BEGIN
        -- get the count of languges
        BEGIN
            SELECT COUNT (DISTINCT attribute17)
              INTO ln_lang_cnt
              FROM hz_cust_accounts
             WHERE party_id = p_party_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_lang_cnt   := 0;
        END;

        -- get NB language value
        BEGIN
            SELECT attribute17
              INTO lv_nb_lang
              FROM hz_cust_accounts
             WHERE party_id = p_party_id AND attribute1 = 'ALL BRAND';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_nb_lang   := NULL;
        END;

        IF ln_lang_cnt = 1
        THEN
            SELECT hca.attribute17 lang_at_account, hcas.ATTRIBUTE9 lang_at_site
              INTO lv_lang_at_account, lv_lang_at_site
              FROM apps.hz_cust_accounts hca, apps.hz_cust_acct_sites_all hcas, apps.hz_cust_site_uses_all uses
             WHERE     1 = 1
                   AND hca.cust_account_id = hcas.cust_account_id
                   AND hca.status = 'A'
                   AND hcas.status = 'A'
                   AND hcas.org_id = p_org_id
                   AND hcas.cust_acct_site_id = uses.cust_acct_site_id
                   AND uses.status = 'A'
                   AND uses.site_use_id = p_bill_to_site_use_id
                   AND hca.cust_account_id = p_customer_id;
        ELSIF ln_lang_cnt > 1
        THEN
            IF lv_nb_lang IS NOT NULL
            THEN
                lv_lang_at_account   := lv_nb_lang;
            ELSIF lv_nb_lang IS NULL
            THEN
                SELECT attribute17
                  INTO lv_lang_at_account
                  FROM (  SELECT attribute17
                            FROM hz_cust_accounts
                           WHERE     party_id = p_party_id
                                 AND attribute17 IS NOT NULL
                        ORDER BY attribute17)
                 WHERE ROWNUM = 1;
            END IF;
        END IF;

        lv_lang_code   := lv_lang_at_account;

        IF lv_lang_code IS NULL
        THEN
            BEGIN
                SELECT ffv.attribute2
                  INTO lv_lang_code
                  FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values ffv
                 WHERE     1 = 1
                       AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                       AND ffvs.flex_value_set_name =
                           'XXD_AR_COLL_DEFAULT_VS'
                       AND ffv.enabled_flag = 'Y'
                       AND NVL (ffv.start_date_active, SYSDATE) <= SYSDATE
                       AND NVL (ffv.end_date_active, SYSDATE + 1) > SYSDATE
                       --- Added as per 3.0
                       AND ffv.attribute1 = TO_CHAR (p_org_id);

                x_lang_code   := lv_lang_code;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_lang_code   := NULL;
            END;
        ELSE
            BEGIN
                x_lang_code   := lv_lang_code;

                -- validate the language
                SELECT COUNT (*)
                  INTO ln_lang_count
                  FROM fnd_languages
                 WHERE iso_language = lv_lang_code;

                IF ln_lang_count = 0
                THEN
                    BEGIN
                        SELECT ffv.attribute2
                          INTO lv_lang_code
                          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values ffv
                         WHERE     1 = 1
                               AND ffvs.flex_value_set_id =
                                   ffv.flex_value_set_id
                               AND ffvs.flex_value_set_name =
                                   'XXD_AR_COLL_DEFAULT_VS'
                               AND ffv.enabled_flag = 'Y'
                               AND NVL (ffv.start_date_active, SYSDATE) <=
                                   SYSDATE
                               AND NVL (ffv.end_date_active, SYSDATE + 1) >
                                   SYSDATE
                               AND ffv.attribute1 = TO_CHAR (p_org_id);

                        x_lang_code   := lv_lang_code;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_lang_code   := NULL;
                    END;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_lang_code   := NULL;
            END;


            x_lang_code   := lv_lang_code;
        END IF;

        RETURN x_lang_code;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_language;

    FUNCTION return_credit_limit (pn_party_id        NUMBER,
                                  pv_currency_code   VARCHAR2)
        RETURN NUMBER
    IS
        ln_credit_limit   NUMBER;
    BEGIN
        BEGIN
            SELECT overall_credit_limit
              INTO ln_credit_limit
              FROM hz_customer_profiles hcp, hz_cust_profile_amts hcpa
             WHERE     1 = 1
                   AND hcp.cust_account_profile_id =
                       hcpa.cust_account_profile_id
                   AND hcp.cust_account_id = -1
                   AND hcp.site_use_id IS NULL
                   AND hcp.party_id = pn_party_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_credit_limit   := NULL;
        END;

        IF ln_credit_limit IS NULL
        THEN
            BEGIN
                SELECT overall_credit_limit
                  INTO ln_credit_limit
                  FROM hz_customer_profiles hcp, hz_cust_profile_amts hcpa
                 WHERE     1 = 1
                       AND hcp.cust_account_profile_id =
                           hcpa.cust_account_profile_id
                       AND hcp.cust_account_id = -1
                       AND hcp.site_use_id IS NULL
                       AND hcp.party_id = pn_party_id
                       AND hcpa.currency_code = pv_currency_code;
            EXCEPTION
                WHEN OTHERS
                THEN
                    BEGIN
                        SELECT overall_credit_limit
                          INTO ln_credit_limit
                          FROM hz_customer_profiles hcp, hz_cust_profile_amts hcpa
                         WHERE     1 = 1
                               AND hcp.cust_account_profile_id =
                                   hcpa.cust_account_profile_id
                               AND hcp.cust_account_id = -1
                               AND hcp.site_use_id IS NULL
                               AND hcp.party_id = pn_party_id
                               AND ROWNUM = 1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_credit_limit   := NULL;
                    END;
            END;
        END IF;

        RETURN ln_credit_limit;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END return_credit_limit;

    --

    FUNCTION return_last_credit_date (pn_party_id        NUMBER,
                                      pv_currency_code   VARCHAR2)
        RETURN DATE
    IS
        ld_last_credit_dt   DATE;
    BEGIN
        BEGIN
            SELECT last_credit_review_date
              INTO ld_last_credit_dt
              FROM hz_customer_profiles hcp, hz_cust_profile_amts hcpa
             WHERE     1 = 1
                   AND hcp.cust_account_profile_id =
                       hcpa.cust_account_profile_id
                   AND hcp.cust_account_id = -1
                   AND hcp.site_use_id IS NULL
                   AND hcp.party_id = pn_party_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ld_last_credit_dt   := NULL;
        END;

        IF ld_last_credit_dt IS NULL
        THEN
            BEGIN
                SELECT last_credit_review_date
                  INTO ld_last_credit_dt
                  FROM hz_customer_profiles hcp, hz_cust_profile_amts hcpa
                 WHERE     1 = 1
                       AND hcp.cust_account_profile_id =
                           hcpa.cust_account_profile_id
                       AND hcp.cust_account_id = -1
                       AND hcp.site_use_id IS NULL
                       AND hcp.party_id = pn_party_id
                       AND hcpa.currency_code = pv_currency_code;
            EXCEPTION
                WHEN OTHERS
                THEN
                    BEGIN
                        SELECT last_credit_review_date
                          INTO ld_last_credit_dt
                          FROM hz_customer_profiles hcp, hz_cust_profile_amts hcpa
                         WHERE     1 = 1
                               AND hcp.cust_account_profile_id =
                                   hcpa.cust_account_profile_id
                               AND hcp.cust_account_id = -1
                               AND hcp.site_use_id IS NULL
                               AND hcp.party_id = pn_party_id
                               AND ROWNUM = 1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ld_last_credit_dt   := NULL;
                    END;
            END;
        END IF;

        RETURN ld_last_credit_dt;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END return_last_credit_date;

    --

    FUNCTION return_next_credit_date (pn_party_id        NUMBER,
                                      pv_currency_code   VARCHAR2)
        RETURN DATE
    IS
        ld_last_credit_dt   DATE;
    BEGIN
        BEGIN
            SELECT next_credit_review_date
              INTO ld_last_credit_dt
              FROM hz_customer_profiles hcp, hz_cust_profile_amts hcpa
             WHERE     1 = 1
                   AND hcp.cust_account_profile_id =
                       hcpa.cust_account_profile_id
                   AND hcp.cust_account_id = -1
                   AND hcp.site_use_id IS NULL
                   AND hcp.party_id = pn_party_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ld_last_credit_dt   := NULL;
        END;

        IF ld_last_credit_dt IS NULL
        THEN
            BEGIN
                SELECT next_credit_review_date
                  INTO ld_last_credit_dt
                  FROM hz_customer_profiles hcp, hz_cust_profile_amts hcpa
                 WHERE     1 = 1
                       AND hcp.cust_account_profile_id =
                           hcpa.cust_account_profile_id
                       AND hcp.cust_account_id = -1
                       AND hcp.site_use_id IS NULL
                       AND hcp.party_id = pn_party_id
                       AND hcpa.currency_code = pv_currency_code;
            EXCEPTION
                WHEN OTHERS
                THEN
                    BEGIN
                        SELECT next_credit_review_date
                          INTO ld_last_credit_dt
                          FROM hz_customer_profiles hcp, hz_cust_profile_amts hcpa
                         WHERE     1 = 1
                               AND hcp.cust_account_profile_id =
                                   hcpa.cust_account_profile_id
                               AND hcp.cust_account_id = -1
                               AND hcp.site_use_id IS NULL
                               AND hcp.party_id = pn_party_id
                               AND ROWNUM = 1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ld_last_credit_dt   := NULL;
                    END;
            END;
        END IF;

        RETURN ld_last_credit_dt;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END return_next_credit_date;


    --

    FUNCTION return_profile_class (pn_party_id NUMBER)
        RETURN VARCHAR2
    IS
        ln_profile_class   VARCHAR2 (50) := NULL;
    BEGIN
        BEGIN
            SELECT hcpc.name
              INTO ln_profile_class
              FROM hz_customer_profiles hcp, hz_cust_profile_classes hcpc
             WHERE     1 = 1
                   AND hcp.profile_class_id = hcpc.profile_class_id
                   AND hcp.cust_account_id = -1
                   AND hcp.site_use_id IS NULL
                   AND hcp.party_id = pn_party_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                RETURN NULL;
        END;

        RETURN ln_profile_class;
    EXCEPTION
        WHEN OTHERS
        THEN
            -- LOG ('Error while fetching credit limit' || SQLERRM);
            RETURN NULL;
    END return_profile_class;

    --=

    FUNCTION get_sales_resp (pn_salesrep_id NUMBER)
        RETURN VARCHAR2
    IS
        lv_sales_rep_name   VARCHAR2 (150);
    BEGIN
        BEGIN
            SELECT jrr.resource_name
              INTO lv_sales_rep_name
              FROM jtf_rs_salesreps jrs, jtf_rs_resource_extns_tl jrr
             WHERE     1 = 1
                   AND jrs.resource_id = jrr.resource_id(+)
                   AND jrr.language(+) = 'US'
                   AND jrs.salesrep_id = pn_salesrep_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                RETURN NULL;
        END;

        RETURN lv_sales_rep_name;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_sales_resp;

    FUNCTION return_collector (pn_party_id NUMBER)
        RETURN VARCHAR2
    IS
        lv_collector_name   VARCHAR2 (150);
    BEGIN
        BEGIN
            SELECT ar.name
              INTO lv_collector_name
              FROM hz_customer_profiles hcp, hz_cust_accounts hca, ar_collectors ar
             WHERE     1 = 1
                   AND hcp.party_id = hca.party_id
                   AND hcp.cust_account_id = hca.cust_account_id
                   AND hcp.collector_id = ar.collector_id
                   AND hca.party_id = pn_party_id
                   AND hca.attribute1 = 'ALL BRAND';
        EXCEPTION
            WHEN OTHERS
            THEN
                RETURN NULL;
        END;

        RETURN lv_collector_name;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END return_collector;

    --


    FUNCTION return_credit_analyst (pn_party_id NUMBER)
        RETURN VARCHAR2
    IS
        lv_credit_analyst   VARCHAR2 (150);
    BEGIN
        BEGIN
            SELECT jrr.source_name
              INTO lv_credit_analyst
              FROM hz_customer_profiles hcp, jtf_rs_resource_extns jrr
             WHERE     1 = 1
                   AND hcp.credit_analyst_id = jrr.resource_id(+)
                   AND hcp.party_id = pn_party_id
                   AND hcp.cust_account_id = -1;
        EXCEPTION
            WHEN OTHERS
            THEN
                RETURN NULL;
        END;

        RETURN lv_credit_analyst;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END return_credit_analyst;

    --

    FUNCTION return_deduction_reseacher (pn_party_id NUMBER)
        RETURN VARCHAR2
    IS
        lv_collector_name   VARCHAR2 (150);
    BEGIN
        BEGIN
            SELECT jrr.source_name
              INTO lv_collector_name
              FROM hz_parties hp, jtf_rs_resource_extns jrr
             WHERE     1 = 1
                   AND TO_NUMBER (hp.attribute11) = jrr.resource_id
                   AND hp.party_id = pn_party_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                RETURN NULL;
        END;

        RETURN lv_collector_name;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END return_deduction_reseacher;

    --

    FUNCTION get_profile_currency (pn_party_id        NUMBER,
                                   pv_currency_code   VARCHAR2)
        RETURN VARCHAR
    IS
        lv_profile_currency   VARCHAR2 (10);
    BEGIN
        BEGIN
            SELECT hcpa.currency_code
              INTO lv_profile_currency
              FROM hz_customer_profiles hcp, hz_cust_profile_amts hcpa
             WHERE     1 = 1
                   AND hcp.cust_account_profile_id =
                       hcpa.cust_account_profile_id
                   AND hcp.cust_account_id = -1
                   AND hcp.site_use_id IS NULL
                   AND hcp.party_id = pn_party_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_profile_currency   := NULL;
        END;

        IF lv_profile_currency IS NULL
        THEN
            BEGIN
                SELECT hcpa.currency_code
                  INTO lv_profile_currency
                  FROM hz_customer_profiles hcp, hz_cust_profile_amts hcpa
                 WHERE     1 = 1
                       AND hcp.cust_account_profile_id =
                           hcpa.cust_account_profile_id
                       AND hcp.cust_account_id = -1
                       AND hcp.site_use_id IS NULL
                       AND hcp.party_id = pn_party_id
                       AND hcpa.currency_code = pv_currency_code;
            EXCEPTION
                WHEN OTHERS
                THEN
                    BEGIN
                        SELECT hcpa.currency_code
                          INTO lv_profile_currency
                          FROM hz_customer_profiles hcp, hz_cust_profile_amts hcpa
                         WHERE     1 = 1
                               AND hcp.cust_account_profile_id =
                                   hcpa.cust_account_profile_id
                               AND hcp.cust_account_id = -1
                               AND hcp.site_use_id IS NULL
                               AND hcp.party_id = pn_party_id
                               AND ROWNUM = 1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_profile_currency   := NULL;
                    END;
            END;
        END IF;

        RETURN lv_profile_currency;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_profile_currency;

    PROCEDURE createxml (p_conc_request_id   IN NUMBER,
                         p_dir_name          IN VARCHAR2,
                         p_file_name         IN VARCHAR2)
    IS
        v_record_data      VARCHAR2 (4000) := NULL;
        v_trx_num          VARCHAR2 (50) := NULL;
        v_trx_date         VARCHAR2 (50) := NULL;
        v_currency         VARCHAR2 (50) := NULL;
        v_order_total      VARCHAR2 (50) := NULL;

        CURSOR c_hdr (p_conc_request_id IN NUMBER)
        IS
            (SELECT customer_trx_id, unique_trx_id, invoice_number,
                    TO_CHAR (trx_date, 'RRRR-MM-DD') trx_date, TO_CHAR (due_date, 'RRRR-MM-DD') due_date, invoice_amount,
                    invoice_currency_code, original_currency, base_currency,
                    denomination_in_base_currency, denomination_in_original_currency, orig_denom_orig_currency,
                    orig_denom_base_currency, cust_trx_type_id, open_amount,
                    po_number, payment_term, payment_term_id,
                    party_id, nb_customer_number, nb_party_name,
                    nb_currency, nb_address_lines, nb_city,
                    nb_zip_code, nb_country, bill_to_customer_id,
                    bill_to_customer_num, bill_to_customer_name, bill_to_address1,
                    bill_to_address2, bill_to_address3, bill_to_address4,
                    bill_to_city, bill_to_state, bill_to_zip_code,
                    bill_to_country, DECODE (document_type,  'Invoice', 2,  'Credit Memo', 3,  1) document_type, so_number,
                    bol, delivery, waybill_number,
                    TO_CHAR (dispute_date, 'RRRR-MM-DD') dispute_date, dispute_amount, comments,
                    brand, sales_rep, claim_reason,
                    claim_owner, buying_agent_group_num, buying_membership_num,
                    buying_group_vat_num, operating_unit, org_id,
                    ship_to_customer_num, ship_to_customer_name, ship_to_address1,
                    ship_to_address2, ship_to_address3, ship_to_address4,
                    ship_to_city, ship_to_state, ship_to_zip_code,
                    ship_to_country, bill_to_site_use_id, ship_to_site_use_id,
                    LANGUAGE, tel, mobile_phone,
                    fax, email_address, credit_limit,
                    profile_class, ultimate_parent, collector_name,
                    researcher, credit_analyst, parent_number,
                    ALIAS, TO_CHAR (customer_since, 'RRRR-MM-DD') customer_since, TO_CHAR (last_payment_paid_on, 'RRRR-MM-DD') last_payment_paid_on,
                    TO_CHAR (last_payment_due_on, 'RRRR-MM-DD') last_payment_due_on, last_payment_amount, TO_CHAR (last_credit_review, 'RRRR-MM-DD') last_credit_review,
                    TO_CHAR (next_credit_review, 'RRRR-MM-DD') next_credit_review, conc_request_id
               FROM xxd_ar_ext_coll_cust_trx_stg_t trx
              WHERE trx.conc_request_id = p_conc_request_id--  AND trx.party_id =1255466680
                                                           );

        CURSOR c_cust (p_conc_request_id NUMBER)
        IS
              SELECT nb_customer_number, nb_party_name, party_id,
                     DECODE (nb_currency, NULL, get_currency (org_id), nb_currency) nb_currency, nb_address_lines, nb_city,
                     nb_zip_code, DECODE (nb_country, NULL, get_country (org_id), nb_country) nb_country, tel,
                     mobile_phone, fax, email_address,
                     NVL (language, 'EN') language, NVL (credit_limit, 0.00) credit_limit, profile_class,
                     ultimate_parent, collector_name, researcher,
                     credit_analyst, parent_number, alias,
                     BUYING_AGENT_GROUP_NUM, buying_membership_num, buying_group_vat_num,
                     TO_CHAR (customer_since, 'RRRR-MM-DD') customer_since, TO_CHAR (Last_Payment_Paid_On, 'RRRR-MM-DD') Last_Payment_Paid_On, TO_CHAR (Last_Payment_Due_On, 'RRRR-MM-DD') Last_Payment_Due_On,
                     Last_Payment_Amount, TO_CHAR (last_credit_review, 'RRRR-MM-DD') last_credit_review, TO_CHAR (next_credit_review, 'RRRR-MM-DD') next_credit_review,
                     org_id
                FROM XXD_AR_EXT_COLL_CUST_TRX_STG_T
               WHERE conc_request_id = p_conc_request_id
            -- and party_id =1255466680
            GROUP BY nb_customer_number, nb_party_name, party_id,
                     nb_currency, nb_address_lines, nb_city,
                     nb_zip_code, nb_country, tel,
                     mobile_phone, fax, email_address,
                     credit_limit, profile_class, ultimate_parent,
                     collector_name, researcher, credit_analyst,
                     parent_number, language, alias,
                     BUYING_AGENT_GROUP_NUM, buying_membership_num, buying_group_vat_num,
                     customer_since, Last_Payment_Paid_On, Last_Payment_Due_On,
                     Last_Payment_Amount, last_credit_review, next_credit_review,
                     org_id
            ORDER BY party_id;

        CURSOR c_cont (p_conc_request_id IN NUMBER)
        IS
              SELECT contact_point_id, party_id, account_number,
                     first_name, last_name, job_title,
                     job_role, phone_number, mobile_number,
                     fax, email
                FROM XXD_AR_EXT_COLL_CONTACTS_STG_T
               WHERE conc_request_id = p_conc_request_id
            -- and party_id =1255466680
            GROUP BY contact_point_id, party_id, account_number,
                     first_name, last_name, job_title,
                     job_role, phone_number, mobile_number,
                     fax, email
            ORDER BY 3, 4;

        ln_unique_trx_id   NUMBER := 0;
        ln_party_id        NUMBER := 0;
        lv_cust_hdr        VARCHAR2 (4000);
        lv_trx_hdr         VARCHAR2 (4000);
    BEGIN
        v_FILENAME      :=
               gn_conc_request_id
            || '-'
            || TO_CHAR (SYSDATE, 'DDMMYYYYHH24MI')
            || '.xml';

        f_XML_FILE      :=
            UTL_FILE.fopen (p_dir_name, p_file_name, 'W',
                            32767);

        -- UTL_FILE.fopen('XXD_AR_TRX_EXTRACT_OUT_DIR', v_FILENAME, 'W',32767);

        v_RECORD_DATA   := '<?xml version="1.0" encoding="UTF-8"?>';

        UTL_FILE.put_line (f_XML_FILE, v_RECORD_DATA);
        -- icontroller Section starts
        UTL_FILE.put_line (f_XML_FILE, '<icontroller>');
        -- debtors Section starts
        UTL_FILE.put_line (f_XML_FILE, '<debtors>');

        FOR j IN c_cust (p_conc_request_id)
        LOOP
            IF (ln_party_id <> j.party_id)
            THEN
                ln_party_id   := j.party_id;
                -- debtor Section starts
                UTL_FILE.put_line (f_XML_FILE, ' <debtor>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                    ' <reference>' || j.nb_customer_number || '</reference>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <name>'
                    || REPLACE (
                           REPLACE (
                               REPLACE (
                                   REPLACE (
                                       REPLACE (j.nb_party_name,
                                                '&',
                                                '&' || 'amp;'),
                                       '>',
                                       '&' || 'gt;'),
                                   '<',
                                   '&' || 'lt;'),
                               '"',
                               '&' || 'quot;'),
                           '''',
                           '&' || '#39;')
                    || '</name>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <address_country>'
                    || j.nb_country
                    || '</address_country>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                    ' <language>' || j.language || '</language>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                    ' <currency>' || j.nb_currency || '</currency>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <address_lines>'
                    || REPLACE (
                           REPLACE (
                               REPLACE (
                                   REPLACE (
                                       REPLACE (j.nb_address_lines,
                                                '&',
                                                '&' || 'amp;'),
                                       '>',
                                       '&' || 'gt;'),
                                   '<',
                                   '&' || 'lt;'),
                               '"',
                               '&' || 'quot;'),
                           '''',
                           '&' || '#39;')
                    || '</address_lines>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                    ' <address_zip>' || j.nb_zip_code || '</address_zip>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <address_city>'
                    || REPLACE (
                           REPLACE (
                               REPLACE (
                                   REPLACE (
                                       REPLACE (j.nb_city,
                                                '&',
                                                '&' || 'amp;'),
                                       '>',
                                       '&' || 'gt;'),
                                   '<',
                                   '&' || 'lt;'),
                               '"',
                               '&' || 'quot;'),
                           '''',
                           '&' || '#39;')
                    || '</address_city>');
                UTL_FILE.put_line (f_XML_FILE, ' <tel>' || j.tel || '</tel>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                    ' <mobile_phone>' || j.mobile_phone || '</mobile_phone>');
                UTL_FILE.put_line (f_XML_FILE, ' <fax>' || j.fax || '</fax>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <email>'
                    || REPLACE (
                           REPLACE (
                               REPLACE (
                                   REPLACE (
                                       REPLACE (j.email_address,
                                                '&',
                                                '&' || 'amp;'),
                                       '>',
                                       '&' || 'gt;'),
                                   '<',
                                   '&' || 'lt;'),
                               '"',
                               '&' || 'quot;'),
                           '''',
                           '&' || '#39;')
                    || '</email>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <credit_limit>'
                    || TO_CHAR (j.credit_limit, 'fm999999999990.00')
                    || '</credit_limit>');
                -- Fields Section Starts
                UTL_FILE.put_line (f_XML_FILE, ' <fields>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <string reference="profile_class">'
                    || j.profile_class
                    || '</string>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <string reference="ultimate_parent">'
                    || REPLACE (
                           REPLACE (
                               REPLACE (
                                   REPLACE (
                                       REPLACE (j.ultimate_parent,
                                                '&',
                                                '&' || 'amp;'),
                                       '>',
                                       '&' || 'gt;'),
                                   '<',
                                   '&' || 'lt;'),
                               '"',
                               '&' || 'quot;'),
                           '''',
                           '&' || '#39;')
                    || '</string>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <string reference="collector_name">'
                    || REPLACE (
                           REPLACE (
                               REPLACE (
                                   REPLACE (
                                       REPLACE (j.collector_name,
                                                '&',
                                                '&' || 'amp;'),
                                       '>',
                                       '&' || 'gt;'),
                                   '<',
                                   '&' || 'lt;'),
                               '"',
                               '&' || 'quot;'),
                           '''',
                           '&' || '#39;')
                    || '</string>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <string reference="researcher">'
                    || REPLACE (
                           REPLACE (
                               REPLACE (
                                   REPLACE (
                                       REPLACE (j.researcher,
                                                '&',
                                                '&' || 'amp;'),
                                       '>',
                                       '&' || 'gt;'),
                                   '<',
                                   '&' || 'lt;'),
                               '"',
                               '&' || 'quot;'),
                           '''',
                           '&' || '#39;')
                    || '</string>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <string reference="credit_analyst">'
                    || REPLACE (
                           REPLACE (
                               REPLACE (
                                   REPLACE (
                                       REPLACE (j.credit_analyst,
                                                '&',
                                                '&' || 'amp;'),
                                       '>',
                                       '&' || 'gt;'),
                                   '<',
                                   '&' || 'lt;'),
                               '"',
                               '&' || 'quot;'),
                           '''',
                           '&' || '#39;')
                    || '</string>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <string reference="parent_number">'
                    || REPLACE (
                           REPLACE (
                               REPLACE (
                                   REPLACE (
                                       REPLACE (j.parent_number,
                                                '&',
                                                '&' || 'amp;'),
                                       '>',
                                       '&' || 'gt;'),
                                   '<',
                                   '&' || 'lt;'),
                               '"',
                               '&' || 'quot;'),
                           '''',
                           '&' || '#39;')
                    || '</string>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <string reference="alias">'
                    || REPLACE (
                           REPLACE (
                               REPLACE (
                                   REPLACE (
                                       REPLACE (j.alias, '&', '&' || 'amp;'),
                                       '>',
                                       '&' || 'gt;'),
                                   '<',
                                   '&' || 'lt;'),
                               '"',
                               '&' || 'quot;'),
                           '''',
                           '&' || '#39;')
                    || '</string>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <string reference="buying_group_customer_number">'
                    || REPLACE (
                           REPLACE (
                               REPLACE (
                                   REPLACE (
                                       REPLACE (j.buying_agent_group_num,
                                                '&',
                                                '&' || 'amp;'),
                                       '>',
                                       '&' || 'gt;'),
                                   '<',
                                   '&' || 'lt;'),
                               '"',
                               '&' || 'quot;'),
                           '''',
                           '&' || '#39;')
                    || '</string>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <string reference="customer_membership_number">'
                    || REPLACE (
                           REPLACE (
                               REPLACE (
                                   REPLACE (
                                       REPLACE (j.buying_membership_num,
                                                '&',
                                                '&' || 'amp;'),
                                       '>',
                                       '&' || 'gt;'),
                                   '<',
                                   '&' || 'lt;'),
                               '"',
                               '&' || 'quot;'),
                           '''',
                           '&' || '#39;')
                    || '</string>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <string reference="buying_group_vat_number">'
                    || REPLACE (
                           REPLACE (
                               REPLACE (
                                   REPLACE (
                                       REPLACE (j.buying_group_vat_num,
                                                '&',
                                                '&' || 'amp;'),
                                       '>',
                                       '&' || 'gt;'),
                                   '<',
                                   '&' || 'lt;'),
                               '"',
                               '&' || 'quot;'),
                           '''',
                           '&' || '#39;')
                    || '</string>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <string reference="customer_since">'
                    || j.customer_since
                    || '</string>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <string reference="last_payment_paid_on">'
                    || j.last_payment_paid_on
                    || '</string>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <string reference="last_payment_due_on">'
                    || j.last_payment_due_on
                    || '</string>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <string reference="last_payment_amount">'
                    || j.last_payment_amount
                    || '</string>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <string reference="last_credit_review">'
                    || j.last_credit_review
                    || '</string>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <string reference="next_credit_review">'
                    || j.next_credit_review
                    || '</string>');
                -- Fields Section Ends
                UTL_FILE.put_line (f_XML_FILE, ' </fields>');
                -- debtor Section Ends
                UTL_FILE.put_line (f_XML_FILE, ' </debtor>');
            ELSIF ln_party_id = j.party_id
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   '************************************* ');
                fnd_file.put_line (
                    fnd_file.LOG,
                    ' Below parties are having duplicate information and please verify ');

                lv_cust_hdr   :=
                       'DEBTOR'
                    || CHR (9)
                    || 'NAME'
                    || CHR (9)
                    || 'ADDRESS_COUNTRY'
                    || CHR (9)
                    || 'LANGUAGE'
                    || CHR (9)
                    || 'CURRENCY'
                    || CHR (9)
                    || 'ADDRESS_LINES'
                    || CHR (9)
                    || 'ADDRESS_ZIP'
                    || CHR (9)
                    || 'ADDRESS_CITY'
                    || CHR (9)
                    || 'TEL'
                    || CHR (9)
                    || 'MOBILE_PHONE'
                    || CHR (9)
                    || 'FAX'
                    || CHR (9)
                    || 'EMAIL'
                    || CHR (9)
                    || 'CREDIT_LIMIT'
                    || CHR (9)
                    || 'PROFILE_CLASS'
                    || CHR (9)
                    || 'ULTIMATE_PARENT'
                    || CHR (9)
                    || 'COLLECTOR_NAME'
                    || CHR (9)
                    || 'RESEARCHER'
                    || CHR (9)
                    || 'CREDIT_ANALYST'
                    || CHR (9)
                    || 'PARENT_NUMBER'
                    || CHR (9)
                    || 'BUYING_GROUP_CUSTOMER_NUMBER'
                    || CHR (9)
                    || 'CUSTOMER_MEMBERSHIP_NUMBER'
                    || CHR (9)
                    || 'BUYING_GROUP_VAT_NUMBER'
                    || CHR (9)
                    || 'CUSTOMER_SINCE'
                    || CHR (9)
                    || 'LAST_PAYMENT_PAID_ON'
                    || CHR (9)
                    || 'LAST_PAYMENT_DUE_ON'
                    || CHR (9)
                    || 'LAST_PAYMENT_AMOUNT'
                    || CHR (9)
                    || 'LAST_CREDIT_REVIEW'
                    || CHR (9)
                    || 'NEXT_CREDIT_REVIEW';

                fnd_file.put_line (fnd_file.LOG, lv_cust_hdr);
                fnd_file.put_line (
                    fnd_file.LOG,
                       j.nb_customer_number
                    || CHR (9)
                    || j.nb_party_name
                    || CHR (9)
                    || j.nb_country
                    || CHR (9)
                    || j.language
                    || CHR (9)
                    || j.nb_currency
                    || CHR (9)
                    || j.nb_address_lines
                    || CHR (9)
                    || j.nb_zip_code
                    || CHR (9)
                    || j.nb_city
                    || CHR (9)
                    || j.tel
                    || CHR (9)
                    || j.mobile_phone
                    || CHR (9)
                    || j.fax
                    || CHR (9)
                    || j.email_address
                    || CHR (9)
                    || TO_CHAR (j.credit_limit, 'fm999999999990.00')
                    || CHR (9)
                    || j.profile_class
                    || CHR (9)
                    || j.ultimate_parent
                    || CHR (9)
                    || j.collector_name
                    || CHR (9)
                    || j.researcher
                    || CHR (9)
                    || j.credit_analyst
                    || CHR (9)
                    || j.parent_number
                    || CHR (9)
                    || j.alias
                    || CHR (9)
                    || j.buying_agent_group_num
                    || CHR (9)
                    || j.buying_membership_num
                    || CHR (9)
                    || j.buying_group_vat_num
                    || CHR (9)
                    || j.customer_since
                    || CHR (9)
                    || j.last_payment_paid_on
                    || CHR (9)
                    || j.last_payment_due_on
                    || CHR (9)
                    || j.last_payment_amount
                    || CHR (9)
                    || j.last_credit_review
                    || CHR (9)
                    || j.next_credit_review);

                fnd_file.put_line (fnd_file.LOG,
                                   '************************************* ');
            END IF;
        END LOOP;

        -- debtors Section Ends
        UTL_FILE.put_line (f_XML_FILE, '</debtors>');

        -- documents Section starts
        UTL_FILE.put_line (f_XML_FILE, '<documents>');

        FOR i IN c_hdr (p_conc_request_id)
        LOOP
            IF (ln_unique_trx_id <> i.unique_trx_id)
            THEN
                ln_unique_trx_id   := i.unique_trx_id;
                -- document Section starts
                UTL_FILE.put_line (f_XML_FILE, ' <document>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                    ' <reference>' || i.unique_trx_id || '</reference>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <document_number>'
                    || i.invoice_number
                    || '</document_number>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <debtor_reference>'
                    || i.nb_customer_number
                    || '</debtor_reference>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <original_denomination_in_original_currency>'
                    || TO_CHAR (i.invoice_amount, 'fm9999999990.00')
                    || '</original_denomination_in_original_currency>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <original_denomination_in_base_currency>'
                    || TO_CHAR (i.invoice_amount, 'fm9999999990.00')
                    || '</original_denomination_in_base_currency>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <denomination_in_original_currency>'
                    || TO_CHAR (i.open_amount, 'fm9999990.00')
                    || '</denomination_in_original_currency>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <denomination_in_base_currency>'
                    || TO_CHAR (i.open_amount, 'fm9999999990.00')
                    || '</denomination_in_base_currency>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <original_currency>'
                    || i.invoice_currency_code
                    || '</original_currency>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <base_currency>'
                    || i.invoice_currency_code
                    || '</base_currency>');
                UTL_FILE.put_line (f_XML_FILE,
                                   ' <date>' || i.trx_date || '</date>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                    ' <due_date>' || i.due_date || '</due_date>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <document_type>'
                    || i.document_type
                    || '</document_type>');
                --  UTL_FILE.put_line(f_XML_FILE, ' <is_archived>'   || i.invoice_currency_code || '</is_archived>');
                -- Fields Section Starts
                UTL_FILE.put_line (f_XML_FILE, ' <fields>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <string reference="po">'
                    || REPLACE (
                           REPLACE (
                               REPLACE (
                                   REPLACE (
                                       REPLACE (i.po_number,
                                                '&',
                                                '&' || 'amp;'),
                                       '>',
                                       '&' || 'gt;'),
                                   '<',
                                   '&' || 'lt;'),
                               '"',
                               '&' || 'quot;'),
                           '''',
                           '&' || '#39;')
                    || '</string>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <string reference="order">'
                    || REPLACE (
                           REPLACE (
                               REPLACE (
                                   REPLACE (
                                       REPLACE (i.so_number,
                                                '&',
                                                '&' || 'amp;'),
                                       '>',
                                       '&' || 'gt;'),
                                   '<',
                                   '&' || 'lt;'),
                               '"',
                               '&' || 'quot;'),
                           '''',
                           '&' || '#39;')
                    || '</string>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <string reference="bol">'
                    || REPLACE (
                           REPLACE (
                               REPLACE (
                                   REPLACE (
                                       REPLACE (i.bol, '&', '&' || 'amp;'),
                                       '>',
                                       '&' || 'gt;'),
                                   '<',
                                   '&' || 'lt;'),
                               '"',
                               '&' || 'quot;'),
                           '''',
                           '&' || '#39;')
                    || '</string>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <string reference="delivery">'
                    || REPLACE (
                           REPLACE (
                               REPLACE (
                                   REPLACE (
                                       REPLACE (i.delivery,
                                                '&',
                                                '&' || 'amp;'),
                                       '>',
                                       '&' || 'gt;'),
                                   '<',
                                   '&' || 'lt;'),
                               '"',
                               '&' || 'quot;'),
                           '''',
                           '&' || '#39;')
                    || '</string>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <string reference="account">'
                    || REPLACE (
                           REPLACE (
                               REPLACE (
                                   REPLACE (
                                       REPLACE (i.bill_to_customer_num,
                                                '&',
                                                '&' || 'amp;'),
                                       '>',
                                       '&' || 'gt;'),
                                   '<',
                                   '&' || 'lt;'),
                               '"',
                               '&' || 'quot;'),
                           '''',
                           '&' || '#39;')
                    || '</string>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <string reference="waybill">'
                    || REPLACE (
                           REPLACE (
                               REPLACE (
                                   REPLACE (
                                       REPLACE (i.waybill_number,
                                                '&',
                                                '&' || 'amp;'),
                                       '>',
                                       '&' || 'gt;'),
                                   '<',
                                   '&' || 'lt;'),
                               '"',
                               '&' || 'quot;'),
                           '''',
                           '&' || '#39;')
                    || '</string>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <string reference="dispute_amount">'
                    || i.dispute_amount
                    || '</string>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <string reference="dispute_date">'
                    || i.dispute_date
                    || '</string>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <string reference="payment_terms">'
                    || REPLACE (
                           REPLACE (
                               REPLACE (
                                   REPLACE (
                                       REPLACE (i.payment_term,
                                                '&',
                                                '&' || 'amp;'),
                                       '>',
                                       '&' || 'gt;'),
                                   '<',
                                   '&' || 'lt;'),
                               '"',
                               '&' || 'quot;'),
                           '''',
                           '&' || '#39;')
                    || '</string>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <string reference="receivable_comments">'
                    || REPLACE (
                           REPLACE (
                               REPLACE (
                                   REPLACE (
                                       REPLACE (i.comments,
                                                '&',
                                                '&' || 'amp;'),
                                       '>',
                                       '&' || 'gt;'),
                                   '<',
                                   '&' || 'lt;'),
                               '"',
                               '&' || 'quot;'),
                           '''',
                           '&' || '#39;')
                    || '</string>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                    ' <string reference="brand">' || i.brand || '</string>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <string reference="salesrep">'
                    || REPLACE (
                           REPLACE (
                               REPLACE (
                                   REPLACE (
                                       REPLACE (i.sales_rep,
                                                '&',
                                                '&' || 'amp;'),
                                       '>',
                                       '&' || 'gt;'),
                                   '<',
                                   '&' || 'lt;'),
                               '"',
                               '&' || 'quot;'),
                           '''',
                           '&' || '#39;')
                    || '</string>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <string reference="claim_reason">'
                    || REPLACE (
                           REPLACE (
                               REPLACE (
                                   REPLACE (
                                       REPLACE (i.claim_reason,
                                                '&',
                                                '&' || 'amp;'),
                                       '>',
                                       '&' || 'gt;'),
                                   '<',
                                   '&' || 'lt;'),
                               '"',
                               '&' || 'quot;'),
                           '''',
                           '&' || '#39;')
                    || '</string>');
                UTL_FILE.put_line (
                    f_XML_FILE,
                       ' <string reference="claim_owner">'
                    || REPLACE (
                           REPLACE (
                               REPLACE (
                                   REPLACE (
                                       REPLACE (i.claim_owner,
                                                '&',
                                                '&' || 'amp;'),
                                       '>',
                                       '&' || 'gt;'),
                                   '<',
                                   '&' || 'lt;'),
                               '"',
                               '&' || 'quot;'),
                           '''',
                           '&' || '#39;')
                    || '</string>');
                UTL_FILE.put_line (f_XML_FILE, ' </fields>');
                -- Fields Section Ends
                UTL_FILE.put_line (f_XML_FILE, ' </document>');
            -- Document Section Ends

            ELSIF (ln_unique_trx_id = i.unique_trx_id)
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   '************************************* ');
                fnd_file.put_line (
                    fnd_file.LOG,
                    ' Below documents are having duplicate information and please verify ');

                lv_trx_hdr   :=
                       'REFERENCE'
                    || CHR (9)
                    || 'INVOICE_NUMBER'
                    || CHR (9)
                    || 'DEBTOR_REFERENCE'
                    || CHR (9)
                    || 'ORIGINAL_DENOMINATION_IN_ORIGINAL_CURRENCY'
                    || CHR (9)
                    || 'ORIGINAL_DENOMINATION_IN_BASE_CURRENCY'
                    || CHR (9)
                    || 'DENOMINATION_IN_ORIGINAL_CURRENCY'
                    || CHR (9)
                    || 'DENOMINATION_IN_BASE_CURRENCY'
                    || CHR (9)
                    || 'ORIGINAL_CURRENCY'
                    || CHR (9)
                    || 'BASE_CURRENCY'
                    || CHR (9)
                    || 'TRX_DATE'
                    || CHR (9)
                    || 'DUE_DATE'
                    || CHR (9)
                    || 'DOCUMENT_TYPE'
                    || CHR (9)
                    || 'PO'
                    || CHR (9)
                    || 'ORDER'
                    || CHR (9)
                    || 'BOL'
                    || CHR (9)
                    || 'DELIVERY'
                    || CHR (9)
                    || 'ACCOUNT'
                    || CHR (9)
                    || 'WAYBILL'
                    || CHR (9)
                    || 'DISPUTE_AMOUNT'
                    || CHR (9)
                    || 'DISPUTE_DATE'
                    || CHR (9)
                    || 'PAYMENT_TERMS'
                    || CHR (9)
                    || 'RECEIVABLE_COMMENTS'
                    || CHR (9)
                    || 'BRAND'
                    || CHR (9)
                    || 'SALESREP'
                    || CHR (9)
                    || 'CLAIM_REASON'
                    || CHR (9)
                    || 'CLAIM_OWNER';

                fnd_file.put_line (fnd_file.LOG, lv_trx_hdr);
                fnd_file.put_line (
                    fnd_file.LOG,
                       i.unique_trx_id
                    || CHR (9)
                    || i.invoice_number
                    || CHR (9)
                    || i.nb_customer_number
                    || CHR (9)
                    || i.invoice_amount
                    || CHR (9)
                    || i.invoice_amount
                    || CHR (9)
                    || i.open_amount
                    || CHR (9)
                    || i.open_amount
                    || CHR (9)
                    || i.invoice_currency_code
                    || CHR (9)
                    || i.invoice_currency_code
                    || CHR (9)
                    || i.trx_date
                    || CHR (9)
                    || i.due_date
                    || CHR (9)
                    || i.document_type
                    || CHR (9)
                    || i.po_number
                    || CHR (9)
                    || i.so_number
                    || CHR (9)
                    || i.bol
                    || CHR (9)
                    || i.delivery
                    || CHR (9)
                    || i.bill_to_customer_num
                    || CHR (9)
                    || i.waybill_number
                    || CHR (9)
                    || i.dispute_amount
                    || CHR (9)
                    || i.dispute_date
                    || CHR (9)
                    || i.payment_term
                    || CHR (9)
                    || i.comments
                    || CHR (9)
                    || i.brand
                    || CHR (9)
                    || i.sales_rep
                    || CHR (9)
                    || i.claim_reason
                    || CHR (9)
                    || i.claim_owner);

                fnd_file.put_line (fnd_file.LOG,
                                   '************************************* ');
            END IF;
        END LOOP;

        UTL_FILE.put_line (f_XML_FILE, '</documents>');
        -- Documents Section Ends

        -- contacts Section starts
        UTL_FILE.put_line (f_XML_FILE, '<contacts>');

        FOR k IN c_cont (p_conc_request_id)
        LOOP
            -- contact Section starts
            UTL_FILE.put_line (f_XML_FILE, ' <contact>');
            UTL_FILE.put_line (
                f_XML_FILE,
                ' <reference>' || k.contact_point_id || '</reference>');
            UTL_FILE.put_line (
                f_XML_FILE,
                   ' <debtor_reference>'
                || k.account_number
                || '</debtor_reference>');
            UTL_FILE.put_line (
                f_XML_FILE,
                   ' <first_name>'
                || REPLACE (
                       REPLACE (
                           REPLACE (
                               REPLACE (
                                   REPLACE (k.first_name, '&', '&' || 'amp;'),
                                   '>',
                                   '&' || 'gt;'),
                               '<',
                               '&' || 'lt;'),
                           '"',
                           '&' || 'quot;'),
                       '''',
                       '&' || '#39;')
                || '</first_name>');
            UTL_FILE.put_line (
                f_XML_FILE,
                   ' <last_name>'
                || REPLACE (
                       REPLACE (
                           REPLACE (
                               REPLACE (
                                   REPLACE (k.last_name, '&', '&' || 'amp;'),
                                   '>',
                                   '&' || 'gt;'),
                               '<',
                               '&' || 'lt;'),
                           '"',
                           '&' || 'quot;'),
                       '''',
                       '&' || '#39;')
                || '</last_name>');
            UTL_FILE.put_line (
                f_XML_FILE,
                   ' <function>'
                || REPLACE (
                       REPLACE (
                           REPLACE (
                               REPLACE (
                                   REPLACE (k.job_title, '&', '&' || 'amp;'),
                                   '>',
                                   '&' || 'gt;'),
                               '<',
                               '&' || 'lt;'),
                           '"',
                           '&' || 'quot;'),
                       '''',
                       '&' || '#39;')
                || '</function>');
            UTL_FILE.put_line (
                f_XML_FILE,
                   ' <description>'
                || REPLACE (
                       REPLACE (
                           REPLACE (
                               REPLACE (
                                   REPLACE (k.job_role, '&', '&' || 'amp;'),
                                   '>',
                                   '&' || 'gt;'),
                               '<',
                               '&' || 'lt;'),
                           '"',
                           '&' || 'quot;'),
                       '''',
                       '&' || '#39;')
                || '</description>');
            UTL_FILE.put_line (f_XML_FILE,
                               ' <tel>' || k.phone_number || '</tel>');
            UTL_FILE.put_line (
                f_XML_FILE,
                ' <mobile_phone>' || k.mobile_number || '</mobile_phone>');
            UTL_FILE.put_line (
                f_XML_FILE,
                   ' <email>'
                || REPLACE (
                       REPLACE (
                           REPLACE (
                               REPLACE (
                                   REPLACE (k.email, '&', '&' || 'amp;'),
                                   '>',
                                   '&' || 'gt;'),
                               '<',
                               '&' || 'lt;'),
                           '"',
                           '&' || 'quot;'),
                       '''',
                       '&' || '#39;')
                || '</email>');
            UTL_FILE.put_line (f_XML_FILE, ' </contact>');
        END LOOP;

        UTL_FILE.put_line (f_XML_FILE, '</contacts>');
        -- contacts Section Ends

        UTL_FILE.put_line (f_XML_FILE, '</icontroller>');
        -- icontroller Section Ends

        UTL_FILE.FCLOSE (f_XML_FILE);

        BEGIN
            UPDATE XXDO.XXD_AR_EXT_COLL_CUST_TRX_STG_T
               SET file_name = p_file_name, extract_status = 'Y'
             WHERE conc_request_id = gn_conc_request_id;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;
    EXCEPTION
        WHEN UTL_FILE.INTERNAL_ERROR
        THEN
            raise_application_error (
                -20500,
                   'Cannot open file :'
                || v_FILENAME
                || ', internal error; code:'
                || SQLCODE
                || ',message:'
                || SQLERRM);
        WHEN UTL_FILE.INVALID_OPERATION
        THEN
            raise_application_error (
                -20501,
                   'Cannot open file :'
                || v_FILENAME
                || ', invalid operation; code:'
                || SQLCODE
                || ',message:'
                || SQLERRM);
        WHEN UTL_FILE.INVALID_PATH
        THEN
            raise_application_error (
                -20502,
                   'Cannot open file :'
                || v_FILENAME
                || ', invalid path; code:'
                || SQLCODE
                || ',message:'
                || SQLERRM);
        WHEN UTL_FILE.WRITE_ERROR
        THEN
            raise_application_error (
                -20503,
                   'Cannot write to file :'
                || v_FILENAME
                || ', write error; code:'
                || SQLCODE
                || ',message:'
                || SQLERRM);
    END createxml;

    --
    PROCEDURE insert_open_ar_staging (p_org_id IN NUMBER, x_ret_code OUT VARCHAR2, x_ret_message OUT VARCHAR2)
    IS
        CURSOR open_ar_cur (p_org_id IN NUMBER)
        IS
            (SELECT rct.trx_number
                        invoice_number                         --InvoiceNumber
                                      ,
                    ps.amount_due_original
                        invoice_amount                         --InvoiceAmount
                                      ,
                    DECODE (
                        arl.meaning,
                        'Credit Memo', ps.amount_due_remaining,
                        NVL (
                            (  ps.amount_due_original
                             + NVL (ps.amount_adjusted, 0)
                             + (SELECT NVL (SUM (NVL (app.amount_applied_from, app.amount_applied)), 0) amount1
                                  FROM apps.ar_receivable_applications_all app
                                 WHERE     1 = 1
                                       AND app.status = 'APP'
                                       AND app.payment_schedule_id =
                                           ps.payment_schedule_id)),
                            0))
                        open_amount                               --OpenAmount
                                   ,
                    rct.trx_date
                        invoice_date,
                    ps.due_date,
                    rct.purchase_order
                        po_number                                   --PONumber
                                 ,
                    NULL
                        statement_number --StatementNumber --Do not send this field --Need clarification
                                        ,
                    0.00
                        statement_amount --StatementAmount --Do not send this field(If Yes, Send '0.00') --Need clarification
                                        ,
                    nb_cust.party_id,
                    nb_cust.cust_account_id--  ,nb_cust.site_use_id
                                           ,
                    nb_cust.account_number
                        nb_account_number,
                    nb_cust.party_name
                        nb_party_name,
                    nb_cust.currency_code
                        nb_currency,
                    (nb_cust.address1 || '' || nb_cust.address2 || '' || nb_cust.address3 || nb_cust.address4)
                        nb_address_lines,
                    nb_cust.city
                        nb_city,
                    nb_cust.state
                        nb_state,
                    nb_cust.postal_Code
                        nb_postal_code,
                    nb_cust.country
                        nb_country,
                    nb_cust.tel,
                    nb_cust.mobile_phone,
                    nb_cust.fax,
                    nb_cust.email,
                    nb_cust.credit_limit,
                    nb_cust.profile_class,
                    nb_cust.ultimate_parent,
                    nb_cust.collector_name,
                    nb_cust.researcher,
                    nb_cust.credit_analyst,
                    nb_cust.parent_number,
                    nb_cust.alias--,nb_cust.language
                                 ,
                    get_language (rct.bill_to_customer_id, rct.bill_to_site_use_id, rct.org_id
                                  , nb_cust.party_id)
                        language,
                    nb_cust.buying_group_customer_number,
                    nb_cust.customer_membership_number,
                    nb_cust.buying_group_vat_number,
                    nb_cust.customer_since,
                    nb_cust.Last_Payment_Paid_On,
                    nb_cust.last_payment_due_on,
                    nb_cust.Last_Payment_Amount,
                    nb_cust.last_credit_review_date,
                    nb_cust.next_credit_review_date,
                    CASE
                        WHEN REGEXP_COUNT (hca.account_number, '-', 1,
                                           'i') > 0
                        THEN
                            SUBSTR (hca.account_number,
                                    1,
                                    INSTR (hca.account_number, '-', 1) - 1)
                        ELSE
                            hca.account_number
                    END
                        nonbrand_customer_number --ParentCustomerNumber --Non-Brand Customer Number
                                                ,
                    hca.account_number
                        bill_to_customer_number               --CustomerNumber
                                               ,
                    hp.party_name
                        bill_to_customer_name                   --CustomerName
                                             ,
                    hl.address1
                        bill_to_address1 --CustomerAddress1 --Bill TO Address1
                                        ,
                    hl.address2
                        bill_to_address2 --CustomerAddress2 --Bill To Address 2 and 3
                                        ,
                    hl.address3
                        bill_to_address3 --CustomerAddress2 --Bill To Address 2 and 3
                                        ,
                    hl.address4
                        bill_to_address4       --bill_to_address4 --No Mapping
                                        ,
                    hl.city
                        bill_to_city             --CustomerCity --Bill To City
                                    ,
                    NVL (hl.state, hl.province)
                        bill_to_state_or_prov --CustomerState --Bill To State or Province
                                             ,
                    hl.postal_code
                        bill_to_zip_code     --CustomerZip  --Bill To Zip Code
                                        ,
                    hl.country
                        bill_to_country      --CustomField1  --Bill To Country
                                       ,
                    arl.meaning
                        document_type           --CustomField2 --Document Type
                                     --    ,NULL                 sales_order_number --CustomField3 --SO Number (Write a function to concatenate SO# from RCT lines table)
                                     --     ,DECODE(rct.waybill_number, '0', NULL, rct.waybill_number) bill_of_lading --CustomField4 --Bill Of Lading --Need clarification
                                     ,
                    NVL (rct.interface_header_attribute1, rct.ct_reference)
                        sales_order_number,
                    NVL (rct.Interface_Header_Attribute8, rct.waybill_number)
                        bill_of_lading,
                    rct.interface_header_attribute3
                        delivery,
                    rct.Interface_Header_Attribute4
                        waybill,
                    arpt_sql_func_util.get_dispute_amount (
                        rct.customer_trx_id,
                        tt.TYPE,
                        tt.accounting_affect_flag)
                        dispute_amount,
                    arpt_sql_func_util.get_max_dispute_date (
                        rct.customer_trx_id,
                        tt.TYPE,
                        tt.accounting_affect_flag)
                        dispute_date,
                    rct.comments,
                    rct.attribute5
                        brand,
                    get_sales_resp (rct.primary_salesrep_id)
                        sales_rep,
                    rct.interface_header_context,
                    rct.interface_header_attribute1
                        claim_number,
                    rct.interface_header_attribute2
                        claim_id,
                    rct.Interface_header_Attribute7
                        claim_reason,
                    DECODE (
                        rct.interface_header_context,
                        'CLAIM', get_claim_owner (
                                     TO_NUMBER (
                                         rct.interface_header_attribute2)),
                        NULL)
                        claim_owner,
                    hp.attribute16
                        buying_agent_group_num --CustomField5 --Buying Agent/Group Number --x_cpo_acc --Need Clarification --
                                              ,
                    NVL (NVL (hcsua_ship.attribute11, hcsua.attribute11),
                         hp.attribute17)
                        buying_membership_num --CustomField6 --Buying Membership Number --Logic to derive  - TBD
                                             ,
                    hou.name
                        operating_unit    --CustomField7 --Operating Unit Name
                                      ,
                    hca_ship.account_number
                        ship_to_customer_number --Customfield8 --Ship To Customer Number
                                               ,
                    hp_ship.party_name
                        ship_to_customer_name --Customfield9 --Ship To Customer Name
                                             ,
                    hl_ship.address1
                        ship_to_address1    --CustomField10 --Ship To address1
                                        ,
                    hl_ship.address2
                        ship_to_address2 --CustomField11 --Ship To address 2 and 3
                                        ,
                    hl_ship.address3
                        ship_to_address3 --CustomField11 --Ship To address 2 and 3
                                        ,
                    hl_ship.address4
                        ship_to_address4                          --No Mapping
                                        ,
                    hl_ship.city
                        ship_to_city            --CustomField12 --Ship To City
                                    ,
                    NVL (hl_ship.state, hl_ship.province)
                        ship_to_state_or_prov --CustomField13 --Ship To State/Province
                                             ,
                    hl_ship.postal_code
                        ship_to_zip_code    --CustomField14 --Ship To Zip Code
                                        ,
                    hl_ship.country
                        ship_to_country      --CustomField15 --Ship To Country
                                       ,
                    rct.invoice_currency_code
                        invoice_currency_code  --CustomField16 --Currency Code
                                             ,
                    rt.name
                        payment_term            --CustomField17 --Payment Term
                                    ,
                    NULL
                        consolidated_invoice_number --CustomField18 --Consolidated Inv # This is now mapped to Statement Number Field
                                                   ,
                    NULL
                        record_identifier --CustomField18 --Dummy Record Identifier to be sent in CustomField18
                                         ,
                    rct.org_id,
                    CONCAT (rct.customer_trx_id, 0)
                        unique_trx_id,
                    rct.customer_trx_id,
                    rct.cust_trx_type_id,
                    ps.cash_receipt_id,
                    rct.bill_to_customer_id,
                    rct.bill_to_site_use_id,
                    rct.ship_to_site_use_id,
                    rct.term_id
                        payment_term_id
               FROM apps.ar_payment_schedules_all ps,
                    apps.fnd_flex_value_sets ffvs,
                    apps.fnd_flex_values ffv,
                    apps.hr_operating_units hou,
                    apps.hz_cust_site_uses_all hcsua,
                    apps.hz_cust_acct_sites_all hcasa,
                    apps.hz_party_sites hps,
                    apps.hz_locations hl,
                    apps.hz_cust_accounts hca,
                    apps.hz_parties hp,
                    apps.ra_customer_trx_all rct,
                    --  apps.ra_terms_lines_discounts  rtld,
                    apps.ra_cust_trx_types_all tt,
                    apps.ar_lookups arl,
                    apps.hz_cust_site_uses_all hcsua_ship,
                    apps.hz_cust_acct_sites_all hcasa_ship,
                    apps.hz_party_sites hps_ship,
                    apps.hz_locations hl_ship,
                    apps.hz_cust_accounts hca_ship,
                    apps.hz_parties hp_ship,
                    apps.ra_terms rt,
                    (SELECT hp.party_name,
                            cust_acct.account_number,
                            cust_acct.cust_account_id,
                            --  hsu.site_use_id,
                            cust_acct.party_id,
                            hou.organization_id,
                            loc.address1,
                            loc.address2,
                            loc.address3,
                            loc.address4,
                            loc.city,
                            loc.postal_code,
                            loc.state,
                            loc.country,
                            -- cred.currency_code,
                            get_profile_currency (hp.party_id,
                                                  gl.currency_code)
                                currency_code,
                            -- cred.profile_class,
                            return_profile_class (hp.party_id)
                                profile_class,
                            hp.attribute15
                                ultimate_parent,
                            return_collector (hp.party_id)
                                collector_name,
                            -- ar.name                     collector_name,
                            -- jrr1.source_name         researcher,
                            return_deduction_reseacher (hp.party_id)
                                researcher,
                            return_credit_analyst (hp.party_id)
                                credit_analyst,
                            --jrr.source_name          credit_analyst,
                            hp.attribute14
                                parent_number,
                            hp.known_as
                                alias,
                            hp.attribute16
                                buying_group_customer_number,
                            hp.attribute17
                                customer_membership_number,
                            hp.attribute18
                                buying_group_vat_number,
                            hp.creation_date
                                customer_since,
                            get_last_payment_date (hp.party_id)
                                last_payment_paid_on,
                            get_last_payment_due_date (hp.party_id)
                                last_payment_due_on,
                            get_last_payment_amt (hp.party_id)
                                last_payment_amount,
                            return_last_credit_date (hp.party_id,
                                                     gl.currency_code)
                                last_credit_review_date,
                            --  cred.last_credit_review_date,
                            return_next_credit_date (hp.party_id,
                                                     gl.currency_code)
                                next_credit_review_date,
                            --  cred.next_credit_review_date,
                            return_credit_limit (hp.party_id,
                                                 gl.currency_code)
                                credit_limit,
                            -- cred.overall_credit_limit   credit_limit,
                            (SELECT iso_language
                               FROM fnd_languages_vl
                              WHERE     language_code = sites.attribute9
                                    AND ROWNUM = 1)
                                language,
                            (SELECT phone_number
                               FROM hz_contact_points
                              WHERE     contact_point_type = 'PHONE'
                                    AND owner_table_name = 'HZ_PARTIES'
                                    AND phone_line_type = 'GEN'
                                    AND status = 'A'
                                    AND owner_table_id = hp.party_id)
                                tel,
                            (SELECT phone_number
                               FROM hz_contact_points
                              WHERE     contact_point_type = 'PHONE'
                                    AND owner_table_name = 'HZ_PARTIES'
                                    AND phone_line_type = 'MOBILE'
                                    AND status = 'A'
                                    AND owner_table_id = hp.party_id)
                                mobile_phone,
                            (SELECT phone_number
                               FROM hz_contact_points
                              WHERE     contact_point_type = 'PHONE'
                                    AND owner_table_name = 'HZ_PARTIES'
                                    AND phone_line_type = 'FAX'
                                    AND status = 'A'
                                    AND owner_table_id = hp.party_id)
                                fax,
                            (SELECT email_address
                               FROM hz_contact_points
                              WHERE     contact_point_type = 'EMAIL'
                                    AND owner_table_name = 'HZ_PARTIES'
                                    AND primary_flag = 'Y'
                                    AND status = 'A'
                                    AND owner_table_id = hp.party_id)
                                email
                       FROM apps.hz_party_sites psites, apps.hz_locations loc, apps.hz_cust_acct_sites_all sites,
                            apps.hr_operating_units hou, apps.gl_ledgers gl, apps.hz_cust_accounts cust_acct,
                            apps.hz_parties hp
                      WHERE     sites.party_site_id = psites.party_site_id
                            --  AND sites.cust_acct_site_id  = hsu.cust_acct_site_id
                            AND loc.location_id = psites.location_id
                            AND sites.cust_account_id =
                                cust_acct.cust_account_id
                            AND cust_acct.party_id = hp.party_id
                            AND psites.party_id = hp.party_id
                            AND sites.status = 'A'
                            --   AND psites.identifying_address_flag = 'Y' -- missing customers
                            AND sites.org_id = hou.organization_id
                            AND hou.set_of_books_id = gl.ledger_id
                            --  AND hsu.primary_flag = 'Y'
                            --   AND hsu.status = 'A'
                            --   AND hsu.site_use_code = 'BILL_TO'
                            AND hp.status = 'A'
                            --    AND cust_acct.status ='A'
                            AND sites.bill_to_flag = 'P'
                            AND cust_acct.attribute1 = 'ALL BRAND') nb_cust
              WHERE     1 = 1
                    AND ps.org_id = NVL (p_org_id, ps.org_id) --Operating Unit Parameter
                    AND NVL (ps.amount_due_remaining, 0) <> 0        --OPEN AR
                    -- and rct.trx_date between '01-JAN-2022' and '05-JAN-2022'
                    -- AND rct.trx_number = '12597939'
                    AND ps.status = 'OP'                   --Open Transactions
                    AND ps.customer_id IS NOT NULL
                    AND ps.class <> 'PMT'
                    AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                    AND ffvs.flex_value_set_name =
                        'XXDOAR_B2B_OPERATING_UNITS'
                    AND ffv.enabled_flag = 'Y'
                    AND NVL (ffv.start_date_active, SYSDATE) <= SYSDATE
                    AND NVL (ffv.end_date_active, SYSDATE + 1) > SYSDATE
                    AND TO_CHAR (ps.org_id) = RTRIM (LTRIM (ffv.flex_value))
                    AND ps.org_id = hou.organization_id
                    AND ps.customer_trx_id = rct.customer_trx_id
                    --   AND NVL(rct.printing_option, 'PRI') = 'PRI' --Added for CCR0007216
                    AND rct.bill_to_site_use_id = hcsua.site_use_id
                    AND hcsua.cust_acct_site_id = hcasa.cust_acct_site_id
                    AND hcasa.party_site_id = hps.party_site_id
                    AND hps.location_id = hl.location_id
                    AND rct.bill_to_customer_id = hca.cust_account_id
                    AND hca.party_id = hp.party_id
                    AND rct.ship_to_site_use_id = hcsua_ship.site_use_id(+)
                    AND hcsua_ship.cust_acct_site_id =
                        hcasa_ship.cust_acct_site_id(+)
                    AND hcasa_ship.party_site_id = hps_ship.party_site_id(+)
                    AND hps_ship.location_id = hl_ship.location_id(+)
                    --AND hcasa_ship.cust_account_id = hca_ship.cust_account_id(+)
                    AND rct.ship_to_customer_id = hca_ship.cust_account_id(+)
                    AND hca_ship.party_id = hp_ship.party_id(+)
                    --   AND rct.term_id = rtld.term_id(+)
                    AND rct.cust_trx_type_id = tt.cust_trx_type_id
                    AND rct.org_id = tt.org_id
                    AND tt.TYPE = arl.lookup_code
                    AND arl.lookup_type = 'INV/CM'
                    AND rct.term_id = rt.term_id(+)
                    AND hca.party_id = nb_cust.party_id
                    AND hou.organization_id = nb_cust.organization_id
                    AND EXISTS
                            (SELECT appa.payment_schedule_id
                               FROM apps.ar_receivable_applications_all appa
                              WHERE     1 = 1
                                    AND appa.status = 'APP'
                                    AND appa.payment_schedule_id =
                                        ps.payment_schedule_id)
             UNION
             SELECT DISTINCT
                    rct.trx_number
                        invoice_number                         --InvoiceNumber
                                      ,
                    ps.amount_due_original
                        invoice_amount                         --InvoiceAmount
                                      ,
                    ps.amount_due_remaining
                        open_amount                               --OpenAmount
                                   ,
                    rct.trx_date
                        invoice_date,
                    ps.due_date,
                    rct.purchase_order
                        po_number                                   --PONumber
                                 ,
                    NULL
                        statement_number --StatementNumber --Do not send this field --Need clarification
                                        ,
                    0.00
                        statement_amount --StatementAmount --Do not send this field(If Yes, Send '0.00') --Need clarification
                                        ,
                    nb_cust.party_id,
                    nb_cust.cust_account_id--  ,nb_cust.site_use_id
                                           ,
                    nb_cust.account_number
                        nb_account_number,
                    nb_cust.party_name
                        nb_party_name,
                    nb_cust.currency_code
                        nb_currency,
                    (nb_cust.address1 || '' || nb_cust.address2 || '' || nb_cust.address3 || nb_cust.address4)
                        nb_address_lines,
                    nb_cust.city
                        nb_city,
                    nb_cust.state
                        nb_state,
                    nb_cust.postal_Code
                        nb_postal_code,
                    nb_cust.country
                        nb_country,
                    nb_cust.tel,
                    nb_cust.mobile_phone,
                    nb_cust.fax,
                    nb_cust.email,
                    nb_cust.credit_limit,
                    nb_cust.profile_class,
                    nb_cust.ultimate_parent,
                    nb_cust.collector_name,
                    nb_cust.researcher,
                    nb_cust.credit_analyst,
                    nb_cust.parent_number,
                    nb_cust.alias--,nb_cust.language
                                 ,
                    get_language (rct.bill_to_customer_id, rct.bill_to_site_use_id, rct.org_id
                                  , nb_cust.party_id)
                        language,
                    nb_cust.buying_group_customer_number,
                    nb_cust.customer_membership_number,
                    nb_cust.buying_group_vat_number,
                    nb_cust.customer_since,
                    nb_cust.Last_Payment_Paid_On,
                    nb_cust.last_payment_due_on,
                    nb_cust.Last_Payment_Amount,
                    nb_cust.last_credit_review_date,
                    nb_cust.next_credit_review_date,
                    CASE
                        WHEN REGEXP_COUNT (hca.account_number, '-', 1,
                                           'i') > 0
                        THEN
                            SUBSTR (hca.account_number,
                                    1,
                                    INSTR (hca.account_number, '-', 1) - 1)
                        ELSE
                            hca.account_number
                    END
                        nonbrand_customer_number --ParentCustomerNumber --Non-Brand Customer Number
                                                ,
                    hca.account_number
                        bill_to_customer_number               --CustomerNumber
                                               ,
                    hp.party_name
                        bill_to_customer_name                   --CustomerName
                                             ,
                    hl.address1
                        bill_to_address1 --CustomerAddress1 --Bill TO Address1
                                        ,
                    hl.address2
                        bill_to_address2 --CustomerAddress2 --Bill To Address 2 and 3
                                        ,
                    hl.address3
                        bill_to_address3 --CustomerAddress2 --Bill To Address 2 and 3
                                        ,
                    hl.address4
                        bill_to_address4       --bill_to_address4 --No Mapping
                                        ,
                    hl.city
                        bill_to_city             --CustomerCity --Bill To City
                                    ,
                    NVL (hl.state, hl.province)
                        bill_to_state_or_prov --CustomerState --Bill To State or Province
                                             ,
                    hl.postal_code
                        bill_to_zip_code     --CustomerZip  --Bill To Zip Code
                                        ,
                    hl.country
                        bill_to_country      --CustomField1  --Bill To Country
                                       ,
                    arl.meaning
                        document_type           --CustomField2 --Document Type
                                     --    ,NULL                 sales_order_number --CustomField3 --SO Number (Write a function to concatenate SO# from RCT lines table)
                                     --     ,DECODE(rct.waybill_number, '0', NULL, rct.waybill_number) bill_of_lading --CustomField4 --Bill Of Lading --Need clarification
                                     ,
                    NVL (rct.interface_header_attribute1, rct.ct_reference)
                        sales_order_number,
                    NVL (rct.Interface_Header_Attribute8, rct.waybill_number)
                        bill_of_lading,
                    rct.interface_header_attribute3
                        delivery,
                    rct.Interface_Header_Attribute4
                        waybill,
                    arpt_sql_func_util.get_dispute_amount (
                        rct.customer_trx_id,
                        tt.TYPE,
                        tt.accounting_affect_flag)
                        dispute_amount,
                    arpt_sql_func_util.get_max_dispute_date (
                        rct.customer_trx_id,
                        tt.TYPE,
                        tt.accounting_affect_flag)
                        dispute_date,
                    rct.comments,
                    rct.attribute5
                        brand,
                    get_sales_resp (rct.primary_salesrep_id)
                        sales_rep,
                    rct.interface_header_context,
                    rct.interface_header_attribute1
                        claim_number,
                    rct.interface_header_attribute2
                        claim_id,
                    rct.Interface_header_Attribute7
                        claim_reason,
                    DECODE (
                        rct.interface_header_context,
                        'CLAIM', get_claim_owner (
                                     TO_NUMBER (
                                         rct.interface_header_attribute2)),
                        NULL)
                        claim_owner,
                    hp.attribute16
                        buying_agent_group_num --CustomField5 --Buying Agent/Group Number --x_cpo_acc --Need Clarification --
                                              ,
                    NVL (NVL (hcsua_ship.attribute11, hcsua.attribute11),
                         hp.attribute17)
                        buying_membership_num --CustomField6 --Buying Membership Number --Logic to derive  - TBD
                                             ,
                    hou.name
                        operating_unit    --CustomField7 --Operating Unit Name
                                      ,
                    hca_ship.account_number
                        ship_to_customer_number --Customfield8 --Ship To Customer Number
                                               ,
                    hp_ship.party_name
                        ship_to_customer_name --Customfield9 --Ship To Customer Name
                                             ,
                    hl_ship.address1
                        ship_to_address1    --CustomField10 --Ship To address1
                                        ,
                    hl_ship.address2
                        ship_to_address2 --CustomField11 --Ship To address 2 and 3
                                        ,
                    hl_ship.address3
                        ship_to_address3 --CustomField11 --Ship To address 2 and 3
                                        ,
                    hl_ship.address4
                        ship_to_address4                          --No Mapping
                                        ,
                    hl_ship.city
                        ship_to_city            --CustomField12 --Ship To City
                                    ,
                    NVL (hl_ship.state, hl_ship.province)
                        ship_to_state_or_prov --CustomField13 --Ship To State/Province
                                             ,
                    hl_ship.postal_code
                        ship_to_zip_code    --CustomField14 --Ship To Zip Code
                                        ,
                    hl_ship.country
                        ship_to_country      --CustomField15 --Ship To Country
                                       ,
                    rct.invoice_currency_code
                        invoice_currency_code  --CustomField16 --Currency Code
                                             ,
                    rt.name
                        payment_term            --CustomField17 --Payment Term
                                    ,
                    NULL
                        consolidated_invoice_number --CustomField18 --Consolidated Inv # This is now mapped to Statement Number Field
                                                   ,
                    NULL
                        record_identifier --CustomField18 --Dummy Record Identifier to be sent in CustomField18
                                         ,
                    rct.org_id,
                    CONCAT (rct.customer_trx_id, 4)
                        unique_trx_id,
                    rct.customer_trx_id,
                    rct.cust_trx_type_id,
                    ps.cash_receipt_id,
                    rct.bill_to_customer_id,
                    rct.bill_to_site_use_id,
                    rct.ship_to_site_use_id,
                    rct.term_id
                        payment_term_id
               FROM apps.ar_payment_schedules_all ps,
                    apps.fnd_flex_value_sets ffvs,
                    apps.fnd_flex_values ffv,
                    apps.hr_operating_units hou,
                    apps.hz_cust_site_uses_all hcsua,
                    apps.hz_cust_acct_sites_all hcasa,
                    apps.hz_party_sites hps,
                    apps.hz_locations hl,
                    apps.hz_cust_accounts hca,
                    apps.hz_parties hp,
                    apps.ra_customer_trx_all rct,
                    --    apps.ra_terms_lines_discounts  rtld,
                    apps.ra_cust_trx_types_all tt,
                    apps.ar_lookups arl,
                    apps.hz_cust_site_uses_all hcsua_ship,
                    apps.hz_cust_acct_sites_all hcasa_ship,
                    apps.hz_party_sites hps_ship,
                    apps.hz_locations hl_ship,
                    apps.hz_cust_accounts hca_ship,
                    apps.hz_parties hp_ship,
                    apps.ra_terms rt,
                    --   jtf_rs_salesreps               jrs,
                    --  jtf_rs_resource_extns_tl       jrr,
                     (SELECT hp.party_name,
                             cust_acct.account_number,
                             cust_acct.cust_account_id,
                             --  hsu.site_use_id,
                             cust_acct.party_id,
                             hou.organization_id,
                             loc.address1,
                             loc.address2,
                             loc.address3,
                             loc.address4,
                             loc.city,
                             loc.postal_code,
                             loc.state,
                             loc.country,
                             -- cred.currency_code,
                             get_profile_currency (hp.party_id,
                                                   gl.currency_code)
                                 currency_code,
                             -- cred.profile_class,
                             return_profile_class (hp.party_id)
                                 profile_class,
                             hp.attribute15
                                 ultimate_parent,
                             return_collector (hp.party_id)
                                 collector_name,
                             -- ar.name                     collector_name,
                             -- jrr1.source_name         researcher,
                             return_deduction_reseacher (hp.party_id)
                                 researcher,
                             return_credit_analyst (hp.party_id)
                                 credit_analyst,
                             --jrr.source_name          credit_analyst,
                             hp.attribute14
                                 parent_number,
                             hp.known_as
                                 alias,
                             hp.attribute16
                                 buying_group_customer_number,
                             hp.attribute17
                                 customer_membership_number,
                             hp.attribute18
                                 buying_group_vat_number,
                             hp.creation_date
                                 customer_since,
                             get_last_payment_date (hp.party_id)
                                 last_payment_paid_on,
                             get_last_payment_due_date (hp.party_id)
                                 last_payment_due_on,
                             get_last_payment_amt (hp.party_id)
                                 last_payment_amount,
                             return_last_credit_date (hp.party_id,
                                                      gl.currency_code)
                                 last_credit_review_date,
                             --  cred.last_credit_review_date,
                             return_next_credit_date (hp.party_id,
                                                      gl.currency_code)
                                 next_credit_review_date,
                             --  cred.next_credit_review_date,
                             return_credit_limit (hp.party_id,
                                                  gl.currency_code)
                                 credit_limit,
                             -- cred.overall_credit_limit   credit_limit,
                             (SELECT iso_language
                                FROM fnd_languages_vl
                               WHERE     language_code = sites.attribute9
                                     AND ROWNUM = 1)
                                 language,
                             (SELECT phone_number
                                FROM hz_contact_points
                               WHERE     contact_point_type = 'PHONE'
                                     AND owner_table_name = 'HZ_PARTIES'
                                     AND phone_line_type = 'GEN'
                                     AND status = 'A'
                                     AND owner_table_id = hp.party_id)
                                 tel,
                             (SELECT phone_number
                                FROM hz_contact_points
                               WHERE     contact_point_type = 'PHONE'
                                     AND owner_table_name = 'HZ_PARTIES'
                                     AND phone_line_type = 'MOBILE'
                                     AND status = 'A'
                                     AND owner_table_id = hp.party_id)
                                 mobile_phone,
                             (SELECT phone_number
                                FROM hz_contact_points
                               WHERE     contact_point_type = 'PHONE'
                                     AND owner_table_name = 'HZ_PARTIES'
                                     AND phone_line_type = 'FAX'
                                     AND status = 'A'
                                     AND owner_table_id = hp.party_id)
                                 fax,
                             (SELECT email_address
                                FROM hz_contact_points
                               WHERE     contact_point_type = 'EMAIL'
                                     AND owner_table_name = 'HZ_PARTIES'
                                     AND primary_flag = 'Y'
                                     AND status = 'A'
                                     AND owner_table_id = hp.party_id)
                                 email
                        FROM apps.hz_party_sites psites, apps.hz_locations loc, apps.hz_cust_acct_sites_all sites,
                             apps.hr_operating_units hou, apps.gl_ledgers gl, apps.hz_cust_accounts cust_acct,
                             apps.hz_parties hp
                       WHERE     sites.party_site_id = psites.party_site_id
                             --  AND sites.cust_acct_site_id  = hsu.cust_acct_site_id
                             AND loc.location_id = psites.location_id
                             AND sites.cust_account_id =
                                 cust_acct.cust_account_id
                             AND cust_acct.party_id = hp.party_id
                             AND psites.party_id = hp.party_id
                             AND sites.status = 'A'
                             --   AND psites.identifying_address_flag = 'Y' -- missing customers
                             AND sites.org_id = hou.organization_id
                             AND hou.set_of_books_id = gl.ledger_id
                             --  AND hsu.primary_flag = 'Y'
                             --   AND hsu.status = 'A'
                             --   AND hsu.site_use_code = 'BILL_TO'
                             AND hp.status = 'A'
                             --    AND cust_acct.status ='A'
                             AND sites.bill_to_flag = 'P'
                             AND cust_acct.attribute1 = 'ALL BRAND') nb_cust
              WHERE     1 = 1
                    AND ps.org_id = NVL (p_org_id, ps.org_id) --Operating Unit Parameter
                    AND NVL (ps.amount_due_remaining, 0) <> 0        --OPEN AR
                    -- and rct.trx_date between '01-JAN-2022' and '05-JAN-2022'
                    -- AND rct.trx_number = '12597939'
                    AND ps.status = 'OP'                   --Open Transactions
                    AND ps.customer_id IS NOT NULL
                    AND ps.class <> 'PMT'
                    AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                    AND ffvs.flex_value_set_name =
                        'XXDOAR_B2B_OPERATING_UNITS'
                    AND ffv.enabled_flag = 'Y'
                    AND NVL (ffv.start_date_active, SYSDATE) <= SYSDATE
                    AND NVL (ffv.end_date_active, SYSDATE + 1) > SYSDATE
                    AND TO_CHAR (ps.org_id) = RTRIM (LTRIM (ffv.flex_value))
                    AND ps.org_id = hou.organization_id
                    AND ps.customer_trx_id = rct.customer_trx_id
                    --   AND NVL(rct.printing_option, 'PRI') = 'PRI' --Added for CCR0007216
                    AND rct.bill_to_site_use_id = hcsua.site_use_id
                    AND hcsua.cust_acct_site_id = hcasa.cust_acct_site_id
                    AND hcasa.party_site_id = hps.party_site_id
                    AND hps.location_id = hl.location_id
                    AND rct.bill_to_customer_id = hca.cust_account_id
                    AND hca.party_id = hp.party_id
                    AND rct.ship_to_site_use_id = hcsua_ship.site_use_id(+)
                    AND hcsua_ship.cust_acct_site_id =
                        hcasa_ship.cust_acct_site_id(+)
                    AND hcasa_ship.party_site_id = hps_ship.party_site_id(+)
                    AND hps_ship.location_id = hl_ship.location_id(+)
                    --AND hcasa_ship.cust_account_id = hca_ship.cust_account_id(+)
                    AND rct.ship_to_customer_id = hca_ship.cust_account_id(+)
                    AND hca_ship.party_id = hp_ship.party_id(+)
                    --  AND rct.term_id = rtld.term_id(+)
                    AND rct.cust_trx_type_id = tt.cust_trx_type_id
                    AND rct.org_id = tt.org_id
                    AND tt.TYPE = arl.lookup_code
                    AND arl.lookup_type = 'INV/CM'
                    AND rct.term_id = rt.term_id(+)
                    -- AND rct.primary_salesrep_id  = jrs.salesrep_id(+)
                    -- AND jrs.resource_id   = jrr.resource_id(+)
                    -- AND jrr.language(+) = 'US'
                    AND hca.party_id = nb_cust.party_id
                    AND hou.organization_id = nb_cust.organization_id
                    AND NOT EXISTS
                            (SELECT appa.payment_schedule_id
                               FROM apps.ar_receivable_applications_all appa
                              WHERE     1 = 1
                                    AND appa.status = 'APP'
                                    AND appa.payment_schedule_id =
                                        ps.payment_schedule_id)
             UNION
               SELECT cr.receipt_number
                          invoice_number                       --InvoiceNumber
                                        ,
                      -1 * cr.amount
                          invoice_amount                       --InvoiceAmount
                                        ,
                      -1 * SUM (app.amount_applied)
                          open_amount                             --OpenAmount
                                     ,
                      cr.receipt_date
                          invoice_date --InvoiceDate --format data while creating file(TO_CHAR(date, 'MM/DD/YYYY'))
                                      ,
                      cr.receipt_date
                          due_date,
                      NULL
                          po_number                                 --PONumber
                                   ,
                      NULL
                          statement_number                   --StatementNumber
                                          ,
                      0.00
                          statement_amount                   --StatementAmount
                                          ,
                      nb_cust.party_id,
                      nb_cust.cust_account_id--   ,nb_cust.site_use_id
                                             ,
                      nb_cust.account_number
                          nb_account_number,
                      nb_cust.party_name
                          nb_party_name,
                      nb_cust.currency_code
                          nb_currency,
                      (nb_cust.address1 || '' || nb_cust.address2 || '' || nb_cust.address3 || nb_cust.address4)
                          nb_address_lines,
                      nb_cust.city
                          nb_city,
                      nb_cust.state
                          nb_state,
                      nb_cust.postal_Code
                          nb_postal_code,
                      nb_cust.country
                          nb_country,
                      nb_cust.tel,
                      nb_cust.mobile_phone,
                      nb_cust.fax,
                      nb_cust.email,
                      nb_cust.credit_limit,
                      nb_cust.profile_class,
                      nb_cust.ultimate_parent,
                      nb_cust.collector_name,
                      nb_cust.researcher,
                      nb_cust.credit_analyst,
                      nb_cust.parent_number,
                      nb_cust.alias-- ,nb_cust.language
                                   ,
                      get_language (cr.pay_from_customer, cr.customer_site_use_id, cr.org_id
                                    , nb_cust.party_id)
                          language,
                      nb_cust.buying_group_customer_number,
                      nb_cust.customer_membership_number,
                      nb_cust.buying_group_vat_number,
                      nb_cust.customer_since,
                      nb_cust.Last_Payment_Paid_On,
                      nb_cust.last_payment_due_on,
                      nb_cust.Last_Payment_Amount,
                      nb_cust.last_credit_review_date,
                      nb_cust.next_credit_review_date,
                      CASE
                          WHEN REGEXP_COUNT (hca.account_number, '-', 1,
                                             'i') > 0
                          THEN
                              SUBSTR (hca.account_number,
                                      1,
                                      INSTR (hca.account_number, '-', 1) - 1)
                          ELSE
                              hca.account_number
                      END
                          nonbrand_customer_number --ParentCustomerNumber --Non-Brand Customer Number
                                                  ,
                      hca.account_number
                          bill_to_customer_number             --CustomerNumber
                                                 ,
                      hp.party_name
                          bill_to_customer_name                 --CustomerName
                                               ,
                      hl.address1
                          bill_to_address1 --CustomerAddress1 --Bill TO Address1
                                          ,
                      hl.address2
                          bill_to_address2 --CustomerAddress2 --Bill To Address 2 and 3
                                          ,
                      hl.address3
                          bill_to_address3 --CustomerAddress2 --Bill To Address 2 and 3
                                          ,
                      hl.address4
                          bill_to_address4     --bill_to_address4 --No Mapping
                                          ,
                      hl.city
                          bill_to_city           --CustomerCity --Bill To City
                                      ,
                      NVL (hl.state, hl.province)
                          bill_to_state_or_prov --CustomerState --Bill To State or Province
                                               ,
                      hl.postal_code
                          bill_to_zip_code   --CustomerZip  --Bill To Zip Code
                                          ,
                      hl.country
                          bill_to_country    --CustomField1  --Bill To Country
                                         ,
                      'ONACCOUNT'
                          document_type         --CustomField2 --Document Type
                                       ,
                      NULL
                          sales_order_number --CustomField3 --SO Number (Write a function to concatenate SO# from RCT lines table)
                                            ,
                      NULL
                          bill_of_lading --CustomField4 --Bill Of Lading --Need clarification
                                        ,
                      NULL
                          delivery,
                      NULL
                          waybill,
                      NULL
                          dispute_amount,
                      NULL
                          dispute_date,
                      NULL
                          comments,
                      NULL
                          brand,
                      NULL
                          sales_rep,
                      NULL
                          interface_header_context,
                      NULL
                          claim_number,
                      NULL
                          claim_id,
                      NULL
                          claim_reason,
                      NULL
                          claim_owner,
                      NULL
                          buying_agent_group_num --CustomField5 --Buying Agent/Group Number --x_cpo_acc --Need Clarification --
                                                ,
                      NULL
                          buying_membership_num --CustomField6 --Buying Membership Number --Logic to derive  - TBD
                                               ,
                      hou.name
                          operating_unit  --CustomField7 --Operating Unit Name
                                        ,
                      NULL
                          ship_to_customer_number --CustomField8 --Ship To Customer Number
                                                 ,
                      NULL
                          ship_to_customer_name --CustomField9 --Ship To Customer Name
                                               ,
                      NULL
                          ship_to_address1  --CustomField10 --Ship To address1
                                          ,
                      NULL
                          ship_to_address2 --CustomField11 --Ship To address 2 and 3
                                          ,
                      NULL
                          ship_to_address3 --CustomField11 --Ship To address 2 and 3
                                          ,
                      NULL
                          ship_to_address4                        --No Mapping
                                          ,
                      NULL
                          ship_to_city          --CustomField12 --Ship To City
                                      ,
                      NULL
                          ship_to_state_or_prov --CustomField13 --Ship To State/Province
                                               ,
                      NULL
                          ship_to_zip_code  --CustomField14 --Ship To Zip Code
                                          ,
                      NULL
                          ship_to_country    --CustomField15 --Ship To Country
                                         ,
                      cr.currency_code
                          invoice_currency_code --CustomField16 --Currency Code
                                               ,
                      NULL
                          payment_term          --CustomField17 --Payment Term
                                      ,
                      NULL
                          consolidated_invoice_number --CustomField18 --Consolidated Inv #
                                                     ,
                      NULL
                          record_identifier --CustomField18 --Dummy Record Identifier to be sent in CustomField18
                                           ,
                      cr.org_id,
                      CONCAT (cr.cash_receipt_id, 1)
                          unique_trx_id,
                      cr.cash_receipt_id
                          customer_trx_id,
                      NULL
                          cust_trx_type_id,
                      cr.cash_receipt_id,
                      cr.pay_from_customer
                          bill_to_customer_id,
                      cr.customer_site_use_id
                          bill_to_site_use_id,
                      NULL
                          ship_to_site_use_id,
                      NULL
                          payment_term_id
                 FROM apps.ar_receivable_applications_all app,
                      apps.ar_cash_receipts_all cr,
                      apps.fnd_flex_value_sets ffvs,
                      apps.fnd_flex_values ffv,
                      apps.ar_payment_schedules_all ps_inv,
                      hz_cust_accounts hca,
                      hz_parties hp,
                      apps.hz_cust_site_uses_all hcsua,
                      apps.hz_cust_acct_sites_all hcasa,
                      apps.hz_party_sites hps,
                      apps.hz_locations hl,
                      apps.hr_operating_units hou,
                      (SELECT hp.party_name,
                              cust_acct.account_number,
                              cust_acct.cust_account_id,
                              --  hsu.site_use_id,
                              cust_acct.party_id,
                              hou.organization_id,
                              loc.address1,
                              loc.address2,
                              loc.address3,
                              loc.address4,
                              loc.city,
                              loc.postal_code,
                              loc.state,
                              loc.country,
                              -- cred.currency_code,
                              get_profile_currency (hp.party_id,
                                                    gl.currency_code)
                                  currency_code,
                              -- cred.profile_class,
                              return_profile_class (hp.party_id)
                                  profile_class,
                              hp.attribute15
                                  ultimate_parent,
                              return_collector (hp.party_id)
                                  collector_name,
                              -- ar.name                     collector_name,
                              -- jrr1.source_name         researcher,
                              return_deduction_reseacher (hp.party_id)
                                  researcher,
                              return_credit_analyst (hp.party_id)
                                  credit_analyst,
                              --jrr.source_name          credit_analyst,
                              hp.attribute14
                                  parent_number,
                              hp.known_as
                                  alias,
                              hp.attribute16
                                  buying_group_customer_number,
                              hp.attribute17
                                  customer_membership_number,
                              hp.attribute18
                                  buying_group_vat_number,
                              hp.creation_date
                                  customer_since,
                              get_last_payment_date (hp.party_id)
                                  last_payment_paid_on,
                              get_last_payment_due_date (hp.party_id)
                                  last_payment_due_on,
                              get_last_payment_amt (hp.party_id)
                                  last_payment_amount,
                              return_last_credit_date (hp.party_id,
                                                       gl.currency_code)
                                  last_credit_review_date,
                              --  cred.last_credit_review_date,
                              return_next_credit_date (hp.party_id,
                                                       gl.currency_code)
                                  next_credit_review_date,
                              --  cred.next_credit_review_date,
                              return_credit_limit (hp.party_id,
                                                   gl.currency_code)
                                  credit_limit,
                              -- cred.overall_credit_limit   credit_limit,
                              (SELECT iso_language
                                 FROM fnd_languages_vl
                                WHERE     language_code = sites.attribute9
                                      AND ROWNUM = 1)
                                  language,
                              (SELECT phone_number
                                 FROM hz_contact_points
                                WHERE     contact_point_type = 'PHONE'
                                      AND owner_table_name = 'HZ_PARTIES'
                                      AND phone_line_type = 'GEN'
                                      AND status = 'A'
                                      AND owner_table_id = hp.party_id)
                                  tel,
                              (SELECT phone_number
                                 FROM hz_contact_points
                                WHERE     contact_point_type = 'PHONE'
                                      AND owner_table_name = 'HZ_PARTIES'
                                      AND phone_line_type = 'MOBILE'
                                      AND status = 'A'
                                      AND owner_table_id = hp.party_id)
                                  mobile_phone,
                              (SELECT phone_number
                                 FROM hz_contact_points
                                WHERE     contact_point_type = 'PHONE'
                                      AND owner_table_name = 'HZ_PARTIES'
                                      AND phone_line_type = 'FAX'
                                      AND status = 'A'
                                      AND owner_table_id = hp.party_id)
                                  fax,
                              (SELECT email_address
                                 FROM hz_contact_points
                                WHERE     contact_point_type = 'EMAIL'
                                      AND owner_table_name = 'HZ_PARTIES'
                                      AND primary_flag = 'Y'
                                      AND status = 'A'
                                      AND owner_table_id = hp.party_id)
                                  email
                         FROM apps.hz_party_sites psites, apps.hz_locations loc, apps.hz_cust_acct_sites_all sites,
                              apps.hr_operating_units hou, apps.gl_ledgers gl, apps.hz_cust_accounts cust_acct,
                              apps.hz_parties hp
                        WHERE     sites.party_site_id = psites.party_site_id
                              --  AND sites.cust_acct_site_id  = hsu.cust_acct_site_id
                              AND loc.location_id = psites.location_id
                              AND sites.cust_account_id =
                                  cust_acct.cust_account_id
                              AND cust_acct.party_id = hp.party_id
                              AND psites.party_id = hp.party_id
                              AND sites.status = 'A'
                              --   AND psites.identifying_address_flag = 'Y' -- missing customers
                              AND sites.org_id = hou.organization_id
                              AND hou.set_of_books_id = gl.ledger_id
                              --  AND hsu.primary_flag = 'Y'
                              --   AND hsu.status = 'A'
                              --   AND hsu.site_use_code = 'BILL_TO'
                              AND hp.status = 'A'
                              --    AND cust_acct.status ='A'
                              AND sites.bill_to_flag = 'P'
                              AND cust_acct.attribute1 = 'ALL BRAND') nb_cust
                WHERE     1 = 1
                      --   AND 'Y' = NVL(p_include_receipts, 'Y') --Get OnAccount details only if this parameter is 'Yes'
                      AND app.display = 'Y'
                      AND app.cash_receipt_id = cr.cash_receipt_id
                      AND app.org_id = cr.org_id
                      AND app.org_id = NVL (p_org_id, app.org_id)
                      AND app.applied_payment_schedule_id =
                          ps_inv.payment_schedule_id
                      AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                      AND ffvs.flex_value_set_name =
                          'XXDOAR_B2B_OPERATING_UNITS'
                      AND ffv.enabled_flag = 'Y'
                      AND NVL (ffv.start_date_active, SYSDATE) <= SYSDATE
                      AND NVL (ffv.end_date_active, SYSDATE + 1) > SYSDATE
                      AND cr.org_id = TO_NUMBER (ffv.flex_value)
                      AND ps_inv.status = 'OP'
                      AND ps_inv.payment_schedule_id = -1 --On Account (ON_ACC)---4 --Claims (CLAIM_INV)
                      AND NVL (app.amount_applied, 0) <> 0
                      AND app.application_type = 'CASH'
                      AND app.status = 'ACC'                      --On Account
                      AND cr.pay_from_customer = hca.cust_account_id
                      AND hca.party_id = hp.party_id
                      AND cr.customer_site_use_id = hcsua.site_use_id
                      AND cr.org_id = hcsua.org_id
                      AND hcsua.cust_acct_site_id = hcasa.cust_acct_site_id
                      AND hcasa.party_site_id = hps.party_site_id
                      AND hps.location_id = hl.location_id
                      AND cr.org_id = hou.organization_id
                      AND hca.party_id = nb_cust.party_id
                      AND hou.organization_id = nb_cust.organization_id
             GROUP BY cr.receipt_number,
                      cr.amount,
                      cr.receipt_date,
                      CASE
                          WHEN REGEXP_COUNT (hca.account_number, '-', 1,
                                             'i') > 0
                          THEN
                              SUBSTR (hca.account_number,
                                      1,
                                      INSTR (hca.account_number, '-', 1) - 1)
                          ELSE
                              hca.account_number
                      END,
                      nb_cust.party_id,
                      nb_cust.cust_account_id,
                      --     nb_cust.site_use_id,
                      hca.account_number,
                      hp.party_name,
                      hl.address1,
                      hl.address2,
                      hl.address3,
                      hl.address4,
                      hl.city,
                      NVL (hl.state, hl.province),
                      hl.postal_code,
                      hl.country,
                      hou.name,
                      cr.currency_code,
                      cr.org_id,
                      app.customer_trx_id,
                      cr.cash_receipt_id,
                      cr.pay_from_customer,
                      cr.customer_site_use_id,
                      nb_cust.account_number,
                      nb_cust.party_name,
                      nb_cust.currency_code,
                      nb_cust.address1,
                      nb_cust.address2,
                      nb_cust.address3,
                      nb_cust.address4,
                      nb_cust.city,
                      nb_cust.state,
                      nb_cust.postal_Code,
                      nb_cust.country,
                      nb_cust.tel,
                      nb_cust.mobile_phone,
                      nb_cust.fax,
                      nb_cust.email,
                      nb_cust.credit_limit,
                      nb_cust.profile_class,
                      nb_cust.ultimate_parent,
                      nb_cust.collector_name,
                      nb_cust.researcher,
                      nb_cust.credit_analyst,
                      nb_cust.parent_number,
                      nb_cust.alias,
                      nb_cust.language,
                      nb_cust.buying_group_customer_number,
                      nb_cust.customer_membership_number,
                      nb_cust.buying_group_vat_number,
                      nb_cust.customer_since,
                      Last_Payment_Paid_On,
                      Last_Payment_Due_On,
                      Last_Payment_Amount,
                      nb_cust.last_credit_review_date,
                      nb_cust.next_credit_review_date
               HAVING SUM (NVL (app.amount_applied, 0)) <> 0
             UNION
               SELECT cr.receipt_number
                          invoice_number                       --InvoiceNumber
                                        ,
                      -1 * cr.amount
                          invoice_amount                       --InvoiceAmount
                                        ,
                      -1 * SUM (app.amount_applied)
                          open_amount                             --OpenAmount
                                     ,
                      cr.receipt_date
                          invoice_date --InvoiceDate --format data while creating file(TO_CHAR(date, 'MM/DD/YYYY'))
                                      ,
                      cr.receipt_date
                          due_date,
                      NULL
                          po_number                                 --PONumber
                                   ,
                      NULL
                          statement_number --StatementNumber --Do not send this field --Need clarification
                                          ,
                      0.00
                          statement_amount --StatementAmount --Do not send this field(If Yes, Send '0.00') --Need clarification
                                          ,
                      nb_cust.party_id,
                      nb_cust.cust_account_id--   ,nb_cust.site_use_id
                                             ,
                      nb_cust.account_number
                          nb_account_number,
                      nb_cust.party_name
                          nb_party_name,
                      nb_cust.currency_code
                          nb_currency,
                      (nb_cust.address1 || '' || nb_cust.address2 || '' || nb_cust.address3 || nb_cust.address4)
                          nb_address_lines,
                      nb_cust.city
                          nb_city,
                      nb_cust.state
                          nb_state,
                      nb_cust.postal_Code
                          nb_postal_code,
                      nb_cust.country
                          nb_country,
                      nb_cust.tel,
                      nb_cust.mobile_phone,
                      nb_cust.fax,
                      nb_cust.email,
                      nb_cust.credit_limit,
                      nb_cust.profile_class,
                      nb_cust.ultimate_parent,
                      nb_cust.collector_name,
                      nb_cust.researcher,
                      nb_cust.credit_analyst,
                      nb_cust.parent_number,
                      nb_cust.alias--  ,nb_cust.language
                                   ,
                      get_language (cr.pay_from_customer, cr.customer_site_use_id, cr.org_id
                                    , nb_cust.party_id)
                          language,
                      nb_cust.buying_group_customer_number,
                      nb_cust.customer_membership_number,
                      nb_cust.buying_group_vat_number,
                      nb_cust.customer_since,
                      nb_cust.Last_Payment_Paid_On,
                      nb_cust.last_payment_due_on,
                      nb_cust.Last_Payment_Amount,
                      nb_cust.last_credit_review_date,
                      nb_cust.next_credit_review_date,
                      CASE
                          WHEN REGEXP_COUNT (hca.account_number, '-', 1,
                                             'i') > 0
                          THEN
                              SUBSTR (hca.account_number,
                                      1,
                                      INSTR (hca.account_number, '-', 1) - 1)
                          ELSE
                              hca.account_number
                      END
                          nonbrand_customer_number --ParentCustomerNumber --Non-Brand Customer Number
                                                  ,
                      hca.account_number
                          bill_to_customer_number             --CustomerNumber
                                                 ,
                      hp.party_name
                          bill_to_customer_name                 --CustomerName
                                               ,
                      hl.address1
                          bill_to_address1 --CustomerAddress1 --Bill TO Address1
                                          ,
                      hl.address2
                          bill_to_address2 --CustomerAddress2 --Bill To Address 2 and 3
                                          ,
                      hl.address3
                          bill_to_address3 --CustomerAddress2 --Bill To Address 2 and 3
                                          ,
                      hl.address4
                          bill_to_address4     --bill_to_address4 --No Mapping
                                          ,
                      hl.city
                          bill_to_city           --CustomerCity --Bill To City
                                      ,
                      NVL (hl.state, hl.province)
                          bill_to_state_or_prov --CustomerState --Bill To State or Province
                                               ,
                      hl.postal_code
                          bill_to_zip_code   --CustomerZip  --Bill To Zip Code
                                          ,
                      hl.country
                          bill_to_country    --CustomField1  --Bill To Country
                                         ,
                      'CASHCLAIM'
                          document_type         --CustomField2 --Document Type
                                       ,
                      NULL
                          sales_order_number --CustomField3 --SO Number (Write a function to concatenate SO# from RCT lines table)
                                            ,
                      NULL
                          bill_of_lading --CustomField4 --Bill Of Lading --Need clarification
                                        ,
                      NULL
                          delivery,
                      NULL
                          waybill,
                      NULL
                          dispute_amount,
                      NULL
                          dispute_date,
                      NULL
                          comments,
                      NULL
                          brand,
                      NULL
                          sales_rep,
                      NULL
                          interface_header_context,
                      NULL
                          claim_number,
                      NULL
                          claim_id,
                      NULL
                          claim_reason,
                      NULL
                          claim_owner,
                      NULL
                          buying_agent_group_num --CustomField5 --Buying Agent/Group Number --x_cpo_acc --Need Clarification --
                                                ,
                      NULL
                          buying_membership_num --CustomField6 --Buying Membership Number --Logic to derive  - TBD
                                               ,
                      hou.name
                          operating_unit  --CustomField7 --Operating Unit Name
                                        ,
                      NULL
                          ship_to_customer_number --Customfield8 --Ship To Customer Number
                                                 ,
                      NULL
                          ship_to_customer_name --Customfield9 --Ship To Customer Name--      ,NULL customfield17 --No Mapping
                                               ,
                      NULL
                          ship_to_address1  --CustomField10 --Ship To address1
                                          ,
                      NULL
                          ship_to_address2 --CustomField11 --Ship To address 2 and 3
                                          ,
                      NULL
                          ship_to_address3 --CustomField11 --Ship To address 2 and 3
                                          ,
                      NULL
                          ship_to_address4                        --No Mapping
                                          ,
                      NULL
                          ship_to_city          --CustomField12 --Ship To City
                                      ,
                      NULL
                          ship_to_state_or_prov --CustomField13 --Ship To State/Province
                                               ,
                      NULL
                          ship_to_zip_code  --CustomField14 --Ship To Zip Code
                                          ,
                      NULL
                          ship_to_country    --CustomField15 --Ship To Country
                                         ,
                      cr.currency_code
                          invoice_currency_code --CustomField16 --Currency Code
                                               ,
                      NULL
                          payment_term          --CustomField17 --Payment Term
                                      ,
                      NULL
                          consolidated_invoice_number --CustomField18 --Consolidated Inv #
                                                     ,
                      NULL
                          record_identifier --CustomField18 --Dummy Record Identifier to be sent in CustomField18
                                           ,
                      cr.org_id,
                      CONCAT (cr.cash_receipt_id, 2)
                          unique_trx_id,
                      cr.cash_receipt_id
                          customer_trx_id,
                      NULL
                          cust_trx_type_id,
                      cr.cash_receipt_id,
                      cr.pay_from_customer
                          bill_to_customer_id,
                      cr.customer_site_use_id
                          bill_to_site_use_id,
                      NULL
                          ship_to_site_use_id,
                      NULL
                          payment_term_id
                 FROM apps.ar_receivable_applications_all app,
                      apps.ar_cash_receipts_all cr,
                      apps.fnd_flex_value_sets ffvs,
                      apps.fnd_flex_values ffv,
                      apps.ar_payment_schedules_all ps_inv,
                      hz_cust_accounts hca,
                      hz_parties hp,
                      apps.hz_cust_site_uses_all hcsua,
                      apps.hz_cust_acct_sites_all hcasa,
                      apps.hz_party_sites hps,
                      apps.hz_locations hl,
                      apps.hr_operating_units hou,
                      (SELECT hp.party_name,
                              cust_acct.account_number,
                              cust_acct.cust_account_id,
                              --  hsu.site_use_id,
                              cust_acct.party_id,
                              hou.organization_id,
                              loc.address1,
                              loc.address2,
                              loc.address3,
                              loc.address4,
                              loc.city,
                              loc.postal_code,
                              loc.state,
                              loc.country,
                              -- cred.currency_code,
                              get_profile_currency (hp.party_id,
                                                    gl.currency_code)
                                  currency_code,
                              -- cred.profile_class,
                              return_profile_class (hp.party_id)
                                  profile_class,
                              hp.attribute15
                                  ultimate_parent,
                              return_collector (hp.party_id)
                                  collector_name,
                              -- ar.name                     collector_name,
                              -- jrr1.source_name         researcher,
                              return_deduction_reseacher (hp.party_id)
                                  researcher,
                              return_credit_analyst (hp.party_id)
                                  credit_analyst,
                              --jrr.source_name          credit_analyst,
                              hp.attribute14
                                  parent_number,
                              hp.known_as
                                  alias,
                              hp.attribute16
                                  buying_group_customer_number,
                              hp.attribute17
                                  customer_membership_number,
                              hp.attribute18
                                  buying_group_vat_number,
                              hp.creation_date
                                  customer_since,
                              get_last_payment_date (hp.party_id)
                                  last_payment_paid_on,
                              get_last_payment_due_date (hp.party_id)
                                  last_payment_due_on,
                              get_last_payment_amt (hp.party_id)
                                  last_payment_amount,
                              return_last_credit_date (hp.party_id,
                                                       gl.currency_code)
                                  last_credit_review_date,
                              --  cred.last_credit_review_date,
                              return_next_credit_date (hp.party_id,
                                                       gl.currency_code)
                                  next_credit_review_date,
                              --  cred.next_credit_review_date,
                              return_credit_limit (hp.party_id,
                                                   gl.currency_code)
                                  credit_limit,
                              -- cred.overall_credit_limit   credit_limit,
                              (SELECT iso_language
                                 FROM fnd_languages_vl
                                WHERE     language_code = sites.attribute9
                                      AND ROWNUM = 1)
                                  language,
                              (SELECT phone_number
                                 FROM hz_contact_points
                                WHERE     contact_point_type = 'PHONE'
                                      AND owner_table_name = 'HZ_PARTIES'
                                      AND phone_line_type = 'GEN'
                                      AND status = 'A'
                                      AND owner_table_id = hp.party_id)
                                  tel,
                              (SELECT phone_number
                                 FROM hz_contact_points
                                WHERE     contact_point_type = 'PHONE'
                                      AND owner_table_name = 'HZ_PARTIES'
                                      AND phone_line_type = 'MOBILE'
                                      AND status = 'A'
                                      AND owner_table_id = hp.party_id)
                                  mobile_phone,
                              (SELECT phone_number
                                 FROM hz_contact_points
                                WHERE     contact_point_type = 'PHONE'
                                      AND owner_table_name = 'HZ_PARTIES'
                                      AND phone_line_type = 'FAX'
                                      AND status = 'A'
                                      AND owner_table_id = hp.party_id)
                                  fax,
                              (SELECT email_address
                                 FROM hz_contact_points
                                WHERE     contact_point_type = 'EMAIL'
                                      AND owner_table_name = 'HZ_PARTIES'
                                      AND primary_flag = 'Y'
                                      AND status = 'A'
                                      AND owner_table_id = hp.party_id)
                                  email
                         FROM apps.hz_party_sites psites, apps.hz_locations loc, apps.hz_cust_acct_sites_all sites,
                              apps.hr_operating_units hou, apps.gl_ledgers gl, apps.hz_cust_accounts cust_acct,
                              apps.hz_parties hp
                        WHERE     sites.party_site_id = psites.party_site_id
                              --  AND sites.cust_acct_site_id  = hsu.cust_acct_site_id
                              AND loc.location_id = psites.location_id
                              AND sites.cust_account_id =
                                  cust_acct.cust_account_id
                              AND cust_acct.party_id = hp.party_id
                              AND psites.party_id = hp.party_id
                              AND sites.status = 'A'
                              --   AND psites.identifying_address_flag = 'Y' -- missing customers
                              AND sites.org_id = hou.organization_id
                              AND hou.set_of_books_id = gl.ledger_id
                              --  AND hsu.primary_flag = 'Y'
                              --   AND hsu.status = 'A'
                              --   AND hsu.site_use_code = 'BILL_TO'
                              AND hp.status = 'A'
                              --    AND cust_acct.status ='A'
                              AND sites.bill_to_flag = 'P'
                              AND cust_acct.attribute1 = 'ALL BRAND') nb_cust
                WHERE     1 = 1
                      AND app.org_id = NVL (p_org_id, app.org_id) --Operating Unit Parameter
                      AND app.display = 'Y'
                      AND app.cash_receipt_id = cr.cash_receipt_id
                      AND app.org_id = cr.org_id
                      AND app.applied_payment_schedule_id =
                          ps_inv.payment_schedule_id
                      AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                      AND ffvs.flex_value_set_name =
                          'XXDOAR_B2B_OPERATING_UNITS'
                      AND ffv.enabled_flag = 'Y'
                      AND NVL (ffv.start_date_active, SYSDATE) <= SYSDATE
                      AND NVL (ffv.end_date_active, SYSDATE + 1) > SYSDATE
                      AND cr.org_id = TO_NUMBER (ffv.flex_value)
                      AND ps_inv.payment_schedule_id = -4 --Claims (CLAIM_INV)--     -1 --On Account (ON_ACC)
                      AND app.application_type = 'CASH'
                      AND app.status = 'OTHER ACC'               --Cash Claims
                      AND NVL (app.amount_applied, 0) <> 0
                      --   AND ps_inv.status = 'OP'
                      AND cr.pay_from_customer = hca.cust_account_id
                      AND hca.party_id = hp.party_id
                      AND cr.customer_site_use_id = hcsua.site_use_id
                      AND cr.org_id = hcsua.org_id
                      AND hcsua.cust_acct_site_id = hcasa.cust_acct_site_id
                      AND hcasa.party_site_id = hps.party_site_id
                      AND hps.location_id = hl.location_id
                      AND cr.org_id = hou.organization_id
                      AND hca.party_id = nb_cust.party_id
                      AND hou.organization_id = nb_cust.organization_id
             GROUP BY cr.receipt_number,
                      cr.amount,
                      cr.receipt_date,
                      CASE
                          WHEN REGEXP_COUNT (hca.account_number, '-', 1,
                                             'i') > 0
                          THEN
                              SUBSTR (hca.account_number,
                                      1,
                                      INSTR (hca.account_number, '-', 1) - 1)
                          ELSE
                              hca.account_number
                      END,
                      hca.account_number,
                      nb_cust.cust_account_id,
                      --   nb_cust.site_use_id,
                      hp.party_name,
                      hl.address1,
                      hl.address2,
                      hl.address3,
                      hl.address4,
                      hl.city,
                      NVL (hl.state, hl.province),
                      hl.postal_code,
                      hl.country,
                      hou.name,
                      cr.currency_code,
                      cr.org_id,
                      app.customer_trx_id,
                      cr.cash_receipt_id,
                      cr.pay_from_customer,
                      cr.customer_site_use_id,
                      nb_cust.party_id,
                      nb_cust.account_number,
                      nb_cust.party_name,
                      nb_cust.currency_code,
                      nb_cust.address1,
                      nb_cust.address2,
                      nb_cust.address3,
                      nb_cust.address4,
                      nb_cust.city,
                      nb_cust.state,
                      nb_cust.postal_Code,
                      nb_cust.country,
                      nb_cust.tel,
                      nb_cust.mobile_phone,
                      nb_cust.fax,
                      nb_cust.email,
                      nb_cust.credit_limit,
                      nb_cust.profile_class,
                      nb_cust.ultimate_parent,
                      nb_cust.collector_name,
                      nb_cust.researcher,
                      nb_cust.credit_analyst,
                      nb_cust.parent_number,
                      nb_cust.alias,
                      nb_cust.language,
                      nb_cust.buying_group_customer_number,
                      nb_cust.customer_membership_number,
                      nb_cust.buying_group_vat_number,
                      nb_cust.customer_since,
                      Last_Payment_Paid_On,
                      Last_Payment_Due_On,
                      Last_Payment_Amount,
                      nb_cust.last_credit_review_date,
                      nb_cust.next_credit_review_date
               HAVING SUM (NVL (app.amount_applied, 0)) <> 0
             UNION
               SELECT cr.receipt_number
                          invoice_number                       --InvoiceNumber
                                        ,
                      -1 * cr.amount
                          invoice_amount                       --InvoiceAmount
                                        ,
                      -1 * SUM (app.amount_applied)
                          open_amount                             --OpenAmount
                                     ,
                      cr.receipt_date
                          invoice_date --InvoiceDate --format data while creating file(TO_CHAR(date, 'MM/DD/YYYY'))
                                      ,
                      cr.receipt_date
                          due_date,
                      NULL
                          po_number                                 --PONumber
                                   ,
                      NULL
                          statement_number --StatementNumber --Do not send this field --Need clarification
                                          ,
                      0.00
                          statement_amount --StatementAmount --Do not send this field(If Yes, Send '0.00') --Need clarification
                                          ,
                      nb_cust.party_id,
                      nb_cust.cust_account_id--   ,nb_cust.site_use_id
                                             ,
                      nb_cust.account_number
                          nb_account_number,
                      nb_cust.party_name
                          nb_party_name,
                      nb_cust.currency_code
                          nb_currency,
                      (nb_cust.address1 || '' || nb_cust.address2 || '' || nb_cust.address3 || nb_cust.address4)
                          nb_address_lines,
                      nb_cust.city
                          nb_city,
                      nb_cust.state
                          nb_state,
                      nb_cust.postal_Code
                          nb_postal_code,
                      nb_cust.country
                          nb_country,
                      nb_cust.tel,
                      nb_cust.mobile_phone,
                      nb_cust.fax,
                      nb_cust.email,
                      nb_cust.credit_limit,
                      nb_cust.profile_class,
                      nb_cust.ultimate_parent,
                      nb_cust.collector_name,
                      nb_cust.researcher,
                      nb_cust.credit_analyst,
                      nb_cust.parent_number,
                      nb_cust.alias--  ,nb_cust.language
                                   ,
                      get_language (cr.pay_from_customer, cr.customer_site_use_id, cr.org_id
                                    , nb_cust.party_id)
                          language,
                      nb_cust.buying_group_customer_number,
                      nb_cust.customer_membership_number,
                      nb_cust.buying_group_vat_number,
                      nb_cust.customer_since,
                      nb_cust.Last_Payment_Paid_On,
                      nb_cust.last_payment_due_on,
                      nb_cust.Last_Payment_Amount,
                      nb_cust.last_credit_review_date,
                      nb_cust.next_credit_review_date,
                      CASE
                          WHEN REGEXP_COUNT (hca.account_number, '-', 1,
                                             'i') > 0
                          THEN
                              SUBSTR (hca.account_number,
                                      1,
                                      INSTR (hca.account_number, '-', 1) - 1)
                          ELSE
                              hca.account_number
                      END
                          nonbrand_customer_number --ParentCustomerNumber --Non-Brand Customer Number
                                                  ,
                      hca.account_number
                          bill_to_customer_number             --CustomerNumber
                                                 ,
                      hp.party_name
                          bill_to_customer_name                 --CustomerName
                                               ,
                      hl.address1
                          bill_to_address1 --CustomerAddress1 --Bill TO Address1
                                          ,
                      hl.address2
                          bill_to_address2 --CustomerAddress2 --Bill To Address 2 and 3
                                          ,
                      hl.address3
                          bill_to_address3 --CustomerAddress2 --Bill To Address 2 and 3
                                          ,
                      hl.address4
                          bill_to_address4     --bill_to_address4 --No Mapping
                                          ,
                      hl.city
                          bill_to_city           --CustomerCity --Bill To City
                                      ,
                      NVL (hl.state, hl.province)
                          bill_to_state_or_prov --CustomerState --Bill To State or Province
                                               ,
                      hl.postal_code
                          bill_to_zip_code   --CustomerZip  --Bill To Zip Code
                                          ,
                      hl.country
                          bill_to_country    --CustomField1  --Bill To Country
                                         ,
                      'UNAPP'
                          document_type         --CustomField2 --Document Type
                                       ,
                      NULL
                          sales_order_number --CustomField3 --SO Number (Write a function to concatenate SO# from RCT lines table)
                                            ,
                      NULL
                          bill_of_lading --CustomField4 --Bill Of Lading --Need clarification
                                        ,
                      NULL
                          delivery,
                      NULL
                          waybill,
                      NULL
                          dispute_amount,
                      NULL
                          dispute_date,
                      NULL
                          comments,
                      NULL
                          brand,
                      NULL
                          sales_rep,
                      NULL
                          interface_header_context,
                      NULL
                          claim_number,
                      NULL
                          claim_id,
                      NULL
                          claim_reason,
                      NULL
                          claim_owner,
                      NULL
                          buying_agent_group_num --CustomField5 --Buying Agent/Group Number --x_cpo_acc --Need Clarification --
                                                ,
                      NULL
                          buying_membership_num --CustomField6 --Buying Membership Number --Logic to derive  - TBD
                                               ,
                      hou.name
                          operating_unit  --CustomField7 --Operating Unit Name
                                        ,
                      NULL
                          ship_to_customer_number --Customfield8 --Ship To Customer Number
                                                 ,
                      NULL
                          ship_to_customer_name --Customfield9 --Ship To Customer Name--      ,NULL customfield17 --No Mapping
                                               ,
                      NULL
                          ship_to_address1  --CustomField10 --Ship To address1
                                          ,
                      NULL
                          ship_to_address2 --CustomField11 --Ship To address 2 and 3
                                          ,
                      NULL
                          ship_to_address3 --CustomField11 --Ship To address 2 and 3
                                          ,
                      NULL
                          ship_to_address4                        --No Mapping
                                          ,
                      NULL
                          ship_to_city          --CustomField12 --Ship To City
                                      ,
                      NULL
                          ship_to_state_or_prov --CustomField13 --Ship To State/Province
                                               ,
                      NULL
                          ship_to_zip_code  --CustomField14 --Ship To Zip Code
                                          ,
                      NULL
                          ship_to_country    --CustomField15 --Ship To Country
                                         ,
                      cr.currency_code
                          invoice_currency_code --CustomField16 --Currency Code
                                               ,
                      NULL
                          payment_term          --CustomField17 --Payment Term
                                      ,
                      NULL
                          consolidated_invoice_number --CustomField18 --Consolidated Inv #
                                                     ,
                      NULL
                          record_identifier --CustomField18 --Dummy Record Identifier to be sent in CustomField18
                                           ,
                      cr.org_id,
                      CONCAT (cr.cash_receipt_id, 3)
                          unique_trx_id,
                      cr.cash_receipt_id
                          customer_trx_id,
                      NULL
                          cust_trx_type_id,
                      cr.cash_receipt_id,
                      cr.pay_from_customer
                          bill_to_customer_id,
                      cr.customer_site_use_id
                          bill_to_site_use_id,
                      NULL
                          ship_to_site_use_id,
                      NULL
                          payment_term_id
                 FROM apps.ar_receivable_applications_all app,
                      apps.ar_cash_receipts_all cr,
                      apps.fnd_flex_value_sets ffvs,
                      apps.fnd_flex_values ffv,
                      apps.ar_payment_schedules_all ps_inv,
                      hz_cust_accounts hca,
                      hz_parties hp,
                      apps.hz_cust_site_uses_all hcsua,
                      apps.hz_cust_acct_sites_all hcasa,
                      apps.hz_party_sites hps,
                      apps.hz_locations hl,
                      apps.hr_operating_units hou,
                      (SELECT hp.party_name,
                              cust_acct.account_number,
                              cust_acct.cust_account_id,
                              --  hsu.site_use_id,
                              cust_acct.party_id,
                              hou.organization_id,
                              loc.address1,
                              loc.address2,
                              loc.address3,
                              loc.address4,
                              loc.city,
                              loc.postal_code,
                              loc.state,
                              loc.country,
                              -- cred.currency_code,
                              get_profile_currency (hp.party_id,
                                                    gl.currency_code)
                                  currency_code,
                              -- cred.profile_class,
                              return_profile_class (hp.party_id)
                                  profile_class,
                              hp.attribute15
                                  ultimate_parent,
                              return_collector (hp.party_id)
                                  collector_name,
                              -- ar.name                     collector_name,
                              -- jrr1.source_name         researcher,
                              return_deduction_reseacher (hp.party_id)
                                  researcher,
                              return_credit_analyst (hp.party_id)
                                  credit_analyst,
                              --jrr.source_name          credit_analyst,
                              hp.attribute14
                                  parent_number,
                              hp.known_as
                                  alias,
                              hp.attribute16
                                  buying_group_customer_number,
                              hp.attribute17
                                  customer_membership_number,
                              hp.attribute18
                                  buying_group_vat_number,
                              hp.creation_date
                                  customer_since,
                              get_last_payment_date (hp.party_id)
                                  last_payment_paid_on,
                              get_last_payment_due_date (hp.party_id)
                                  last_payment_due_on,
                              get_last_payment_amt (hp.party_id)
                                  last_payment_amount,
                              return_last_credit_date (hp.party_id,
                                                       gl.currency_code)
                                  last_credit_review_date,
                              --  cred.last_credit_review_date,
                              return_next_credit_date (hp.party_id,
                                                       gl.currency_code)
                                  next_credit_review_date,
                              --  cred.next_credit_review_date,
                              return_credit_limit (hp.party_id,
                                                   gl.currency_code)
                                  credit_limit,
                              -- cred.overall_credit_limit   credit_limit,
                              (SELECT iso_language
                                 FROM fnd_languages_vl
                                WHERE     language_code = sites.attribute9
                                      AND ROWNUM = 1)
                                  language,
                              (SELECT phone_number
                                 FROM hz_contact_points
                                WHERE     contact_point_type = 'PHONE'
                                      AND owner_table_name = 'HZ_PARTIES'
                                      AND phone_line_type = 'GEN'
                                      AND status = 'A'
                                      AND owner_table_id = hp.party_id)
                                  tel,
                              (SELECT phone_number
                                 FROM hz_contact_points
                                WHERE     contact_point_type = 'PHONE'
                                      AND owner_table_name = 'HZ_PARTIES'
                                      AND phone_line_type = 'MOBILE'
                                      AND status = 'A'
                                      AND owner_table_id = hp.party_id)
                                  mobile_phone,
                              (SELECT phone_number
                                 FROM hz_contact_points
                                WHERE     contact_point_type = 'PHONE'
                                      AND owner_table_name = 'HZ_PARTIES'
                                      AND phone_line_type = 'FAX'
                                      AND status = 'A'
                                      AND owner_table_id = hp.party_id)
                                  fax,
                              (SELECT email_address
                                 FROM hz_contact_points
                                WHERE     contact_point_type = 'EMAIL'
                                      AND owner_table_name = 'HZ_PARTIES'
                                      AND primary_flag = 'Y'
                                      AND status = 'A'
                                      AND owner_table_id = hp.party_id)
                                  email
                         FROM apps.hz_party_sites psites, apps.hz_locations loc, apps.hz_cust_acct_sites_all sites,
                              apps.hr_operating_units hou, apps.gl_ledgers gl, apps.hz_cust_accounts cust_acct,
                              apps.hz_parties hp
                        WHERE     sites.party_site_id = psites.party_site_id
                              --  AND sites.cust_acct_site_id  = hsu.cust_acct_site_id
                              AND loc.location_id = psites.location_id
                              AND sites.cust_account_id =
                                  cust_acct.cust_account_id
                              AND cust_acct.party_id = hp.party_id
                              AND psites.party_id = hp.party_id
                              AND sites.status = 'A'
                              --   AND psites.identifying_address_flag = 'Y' -- missing customers
                              AND sites.org_id = hou.organization_id
                              AND hou.set_of_books_id = gl.ledger_id
                              --  AND hsu.primary_flag = 'Y'
                              --   AND hsu.status = 'A'
                              --   AND hsu.site_use_code = 'BILL_TO'
                              AND hp.status = 'A'
                              --    AND cust_acct.status ='A'
                              AND sites.bill_to_flag = 'P'
                              AND cust_acct.attribute1 = 'ALL BRAND') nb_cust
                WHERE     1 = 1
                      AND app.org_id = NVL (p_org_id, app.org_id) --Operating Unit Parameter
                      --  AND app.display = 'Y'
                      AND app.cash_receipt_id = cr.cash_receipt_id
                      AND app.org_id = cr.org_id
                      AND app.payment_schedule_id = ps_inv.payment_schedule_id
                      AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                      AND ffvs.flex_value_set_name =
                          'XXDOAR_B2B_OPERATING_UNITS'
                      AND ffv.enabled_flag = 'Y'
                      AND NVL (ffv.start_date_active, SYSDATE) <= SYSDATE
                      AND NVL (ffv.end_date_active, SYSDATE + 1) > SYSDATE
                      AND cr.org_id = TO_NUMBER (ffv.flex_value)
                      --  AND ps_inv.payment_schedule_id = -4 --Claims (CLAIM_INV)--     -1 --On Account (ON_ACC)
                      -- AND app.application_type = 'CASH'
                      AND app.status = 'UNAPP'                   --Cash Claims
                      --  AND app.amount_applied <> 0
                      -- AND ps_inv.status = 'OP'
                      AND cr.pay_from_customer = hca.cust_account_id
                      AND hca.party_id = hp.party_id
                      AND cr.customer_site_use_id = hcsua.site_use_id
                      AND cr.org_id = hcsua.org_id
                      AND hcsua.cust_acct_site_id = hcasa.cust_acct_site_id
                      AND hcasa.party_site_id = hps.party_site_id
                      AND hps.location_id = hl.location_id
                      AND cr.org_id = hou.organization_id
                      AND hca.party_id = nb_cust.party_id
                      AND hou.organization_id = nb_cust.organization_id
             GROUP BY cr.receipt_number,
                      cr.amount,
                      cr.receipt_date,
                      CASE
                          WHEN REGEXP_COUNT (hca.account_number, '-', 1,
                                             'i') > 0
                          THEN
                              SUBSTR (hca.account_number,
                                      1,
                                      INSTR (hca.account_number, '-', 1) - 1)
                          ELSE
                              hca.account_number
                      END,
                      hca.account_number,
                      nb_cust.cust_account_id,
                      --   nb_cust.site_use_id,
                      hp.party_name,
                      hl.address1,
                      hl.address2,
                      hl.address3,
                      hl.address4,
                      hl.city,
                      NVL (hl.state, hl.province),
                      hl.postal_code,
                      hl.country,
                      hou.name,
                      cr.currency_code,
                      cr.org_id,
                      app.customer_trx_id,
                      cr.cash_receipt_id,
                      cr.pay_from_customer,
                      cr.customer_site_use_id,
                      nb_cust.party_id,
                      nb_cust.account_number,
                      nb_cust.party_name,
                      nb_cust.currency_code,
                      nb_cust.address1,
                      nb_cust.address2,
                      nb_cust.address3,
                      nb_cust.address4,
                      nb_cust.city,
                      nb_cust.state,
                      nb_cust.postal_Code,
                      nb_cust.country,
                      nb_cust.tel,
                      nb_cust.mobile_phone,
                      nb_cust.fax,
                      nb_cust.email,
                      nb_cust.credit_limit,
                      nb_cust.profile_class,
                      nb_cust.ultimate_parent,
                      nb_cust.collector_name,
                      nb_cust.researcher,
                      nb_cust.credit_analyst,
                      nb_cust.parent_number,
                      nb_cust.alias,
                      nb_cust.language,
                      nb_cust.buying_group_customer_number,
                      nb_cust.customer_membership_number,
                      nb_cust.buying_group_vat_number,
                      nb_cust.customer_since,
                      Last_Payment_Paid_On,
                      Last_Payment_Due_On,
                      Last_Payment_Amount,
                      nb_cust.last_credit_review_date,
                      nb_cust.next_credit_review_date
               HAVING SUM (NVL (app.amount_applied, 0)) <> 0);

        CURSOR c_contacts IS
            (  SELECT MAX (contact_point_id) contact_point_id, party_id, account_number,
                      first_name, last_name, email_address,
                      phone_number, mobile_number, job_title,
                      job_role
                 FROM (SELECT DISTINCT
                              hcp.contact_point_id,
                              hca.party_id,
                              CASE
                                  WHEN REGEXP_COUNT (hca.account_number, '-', 1
                                                     , 'i') > 0
                                  THEN
                                      SUBSTR (
                                          hca.account_number,
                                          1,
                                            INSTR (hca.account_number,
                                                   '-',
                                                   1)
                                          - 1)
                                  ELSE
                                      hca.account_number
                              END account_number,
                              NULL first_name,
                              NULL last_name,
                              hcp.email_Address,
                              DECODE (
                                  DECODE (hcp.phone_line_type,
                                          'MOBILE', NULL,
                                          hcp.phone_number),
                                  NULL, NULL,
                                     DECODE (
                                         hcp.phone_country_code,
                                         NULL, NULL,
                                         '+' || hcp.phone_country_code)
                                  || DECODE (
                                         hcp.phone_area_code,
                                         NULL, NULL,
                                            '('
                                         || hcp.phone_area_code
                                         || ')')
                                  || DECODE (hcp.phone_line_type,
                                             'MOBILE', NULL,
                                             hcp.phone_number)) phone_number,
                              DECODE (
                                  DECODE (hcp.phone_line_type,
                                          'MOBILE', hcp.phone_number,
                                          NULL),
                                  NULL, NULL,
                                     DECODE (hcp.phone_country_code,
                                             NULL, NULL,
                                             '+' || hcp.phone_country_code)
                                  || DECODE (hcp.phone_area_code,
                                             NULL, NULL,
                                             '(' || hcp.phone_area_code || ')')
                                  || DECODE (hcp.phone_line_type,
                                             'MOBILE', hcp.phone_number,
                                             NULL)) mobile_number,
                              --  DECODE(hcp.phone_line_type,'MOBILE',null,hcp.phone_number) phone_number,
                              --  DECODE(hcp.phone_line_type,'MOBILE',hcp.phone_number,null)mobile_number,
                              NULL job_title,
                              NULL job_role
                         FROM hz_contact_points hcp, hz_parties hp, hz_cust_accounts hca
                        WHERE     1 = 1       -- hp.party_id      = p_party_id
                              AND hcp.owner_table_id = hp.party_id
                              AND hcp.owner_table_name = 'HZ_PARTIES'
                              AND hp.party_id = hca.party_id
                              AND hcp.status = 'A'
                              --and hca.status  ='A'
                              AND EXISTS
                                      (SELECT 1
                                         FROM xxd_ar_ext_coll_cust_trx_stg_t trx
                                        WHERE     trx.conc_request_id =
                                                  gn_conc_request_id
                                              AND trx.party_id = hp.party_id)
                       -- and hp.party_id =1255466680
                       UNION
                       SELECT DISTINCT
                              hcp.contact_point_id,
                              hca.party_id,
                              CASE
                                  WHEN REGEXP_COUNT (hca.account_number, '-', 1
                                                     , 'i') > 0
                                  THEN
                                      SUBSTR (
                                          hca.account_number,
                                          1,
                                            INSTR (hca.account_number,
                                                   '-',
                                                   1)
                                          - 1)
                                  ELSE
                                      hca.account_number
                              END account_number,
                              NULL first_name,
                              NULL last_name,
                              hcp.email_Address,
                              DECODE (
                                  DECODE (hcp.phone_line_type,
                                          'MOBILE', NULL,
                                          hcp.phone_number),
                                  NULL, NULL,
                                     DECODE (
                                         hcp.phone_country_code,
                                         NULL, NULL,
                                         '+' || hcp.phone_country_code)
                                  || DECODE (
                                         hcp.phone_area_code,
                                         NULL, NULL,
                                            '('
                                         || hcp.phone_area_code
                                         || ')')
                                  || DECODE (hcp.phone_line_type,
                                             'MOBILE', NULL,
                                             hcp.phone_number)) phone_number,
                              DECODE (
                                  DECODE (hcp.phone_line_type,
                                          'MOBILE', hcp.phone_number,
                                          NULL),
                                  NULL, NULL,
                                     DECODE (hcp.phone_country_code,
                                             NULL, NULL,
                                             '+' || hcp.phone_country_code)
                                  || DECODE (hcp.phone_area_code,
                                             NULL, NULL,
                                             '(' || hcp.phone_area_code || ')')
                                  || DECODE (hcp.phone_line_type,
                                             'MOBILE', hcp.phone_number,
                                             NULL)) mobile_number,
                              -- DECODE(hcp.phone_line_type,'MOBILE',null,hcp.phone_number) phone_number,
                              --  DECODE(hcp.phone_line_type,'MOBILE',hcp.phone_number,null)mobile_number,
                              NULL job_title,
                              NULL job_role
                         FROM hz_party_sites hps, hz_contact_points hcp, hz_parties hp,
                              hz_cust_accounts hca
                        WHERE     1 = 1 --hps.party_id      =  p_party_id --p_party_id
                              AND hcp.owner_table_id = hps.party_site_id
                              AND hcp.owner_table_name = 'HZ_PARTY_SITES'
                              AND hps.party_id = hp.party_id
                              AND hp.party_id = hca.party_id
                              AND hcp.status = 'A'
                              -- and hca.status  ='A'
                              -- and hp.party_id =1255466680
                              AND EXISTS
                                      (SELECT 1
                                         FROM xxd_ar_ext_coll_cust_trx_stg_t trx
                                        WHERE     trx.conc_request_id =
                                                  gn_conc_request_id
                                              AND trx.party_id = hp.party_id)
                       UNION
                       SELECT hcp.contact_point_id,
                              act.party_id,
                              CASE
                                  WHEN REGEXP_COUNT (act.account_number, '-', 1
                                                     , 'i') > 0
                                  THEN
                                      SUBSTR (
                                          act.account_number,
                                          1,
                                            INSTR (act.account_number, '-', 1)
                                          - 1)
                                  ELSE
                                      act.account_number
                              END account_number,
                              --    hpsub.party_name Contact_Name,
                              hpsub.person_first_name,
                              hpsub.person_last_name,
                              hcp.email_Address,
                              DECODE (
                                  DECODE (hcp.phone_line_type,
                                          'MOBILE', NULL,
                                          hcp.phone_number),
                                  NULL, NULL,
                                     DECODE (hcp.phone_country_code,
                                             NULL, NULL,
                                             '+' || hcp.phone_country_code)
                                  || DECODE (hcp.phone_area_code,
                                             NULL, NULL,
                                             '(' || hcp.phone_area_code || ')')
                                  || DECODE (hcp.phone_line_type,
                                             'MOBILE', NULL,
                                             hcp.phone_number)) phone_number,
                              DECODE (
                                  DECODE (hcp.phone_line_type,
                                          'MOBILE', hcp.phone_number,
                                          NULL),
                                  NULL, NULL,
                                     DECODE (hcp.phone_country_code,
                                             NULL, NULL,
                                             '+' || hcp.phone_country_code)
                                  || DECODE (hcp.phone_area_code,
                                             NULL, NULL,
                                             '(' || hcp.phone_area_code || ')')
                                  || DECODE (hcp.phone_line_type,
                                             'MOBILE', hcp.phone_number,
                                             NULL)) mobile_number,
                              --   DECODE(hcp.phone_line_type,'MOBILE',null,hcp.phone_number) phone_number,
                              --  DECODE(hcp.phone_line_type,'MOBILE',hcp.phone_number,null)mobile_number,
                              hoc.job_title,
                              (SELECT arl.meaning
                                 FROM hz_role_responsibility hrr, ar_lookups arl
                                WHERE     hrr.cust_account_role_id =
                                          hcar.cust_account_role_id
                                      AND hrr.responsibility_type =
                                          arl.lookup_Code
                                      AND arl.lookup_type = 'SITE_USE_CODE'
                                      AND primary_flag = 'Y') job_role
                         FROM hz_cust_account_roles hcar, hz_parties hpsub, hz_parties hprel,
                              hz_org_contacts hoc, hz_relationships hr, hz_party_sites hps,
                              fnd_territories_vl ftv, fnd_lookup_values_vl lookups, hz_cust_accounts act,
                              hz_contact_points hcp
                        WHERE     1 = 1
                              --  AND act.party_id =1255466680
                              AND hcar.role_type = 'CONTACT'
                              AND hcar.party_id = hr.party_id
                              AND hr.party_id = hprel.party_id
                              AND hr.subject_id = hpsub.party_id
                              AND hoc.party_relationship_id =
                                  hr.relationship_id
                              AND hcar.cust_account_id = act.cust_account_id
                              AND act.party_id = hr.object_id
                              AND hps.party_id(+) = hprel.party_id
                              AND NVL (hps.identifying_address_flag(+), 'Y') =
                                  'Y'
                              AND NVL (hps.status(+), 'A') = 'A'
                              AND hprel.country = ftv.territory_code(+)
                              AND hcar.cust_acct_site_id IS NULL
                              AND lookups.lookup_type(+) = 'RESPONSIBILITY'
                              AND lookups.lookup_code(+) = hoc.job_title_code
                              AND hcp.owner_table_id = hcar.party_id
                              AND hcp.owner_table_name = 'HZ_PARTIES'
                              AND hcp.status = 'A'
                              AND EXISTS
                                      (SELECT 1
                                         FROM xxd_ar_ext_coll_cust_trx_stg_t trx
                                        WHERE     trx.conc_request_id =
                                                  gn_conc_request_id
                                              AND trx.party_id = act.party_id)
                       UNION
                       SELECT hcp.contact_point_id,
                              act.party_id,
                              CASE
                                  WHEN REGEXP_COUNT (act.account_number, '-', 1
                                                     , 'i') > 0
                                  THEN
                                      SUBSTR (
                                          act.account_number,
                                          1,
                                            INSTR (act.account_number, '-', 1)
                                          - 1)
                                  ELSE
                                      act.account_number
                              END account_number,
                              hpsub.person_first_name,
                              hpsub.person_last_name,
                              hcp.email_Address,
                              DECODE (
                                  DECODE (hcp.phone_line_type,
                                          'MOBILE', NULL,
                                          hcp.phone_number),
                                  NULL, NULL,
                                     DECODE (hcp.phone_country_code,
                                             NULL, NULL,
                                             '+' || hcp.phone_country_code)
                                  || DECODE (hcp.phone_area_code,
                                             NULL, NULL,
                                             '(' || hcp.phone_area_code || ')')
                                  || DECODE (hcp.phone_line_type,
                                             'MOBILE', NULL,
                                             hcp.phone_number)) phone_number,
                              DECODE (
                                  DECODE (hcp.phone_line_type,
                                          'MOBILE', hcp.phone_number,
                                          NULL),
                                  NULL, NULL,
                                     DECODE (hcp.phone_country_code,
                                             NULL, NULL,
                                             '+' || hcp.phone_country_code)
                                  || DECODE (hcp.phone_area_code,
                                             NULL, NULL,
                                             '(' || hcp.phone_area_code || ')')
                                  || DECODE (hcp.phone_line_type,
                                             'MOBILE', hcp.phone_number,
                                             NULL)) mobile_number,
                              -- DECODE(hcp.phone_line_type,'MOBILE',null,hcp.phone_number) phone_number,
                              -- DECODE(hcp.phone_line_type,'MOBILE',hcp.phone_number,null)mobile_number,
                              hoc.job_title,
                              (SELECT arl.meaning
                                 FROM hz_role_responsibility hrr, ar_lookups arl
                                WHERE     hrr.cust_account_role_id =
                                          hcar.cust_account_role_id
                                      AND hrr.responsibility_type =
                                          arl.lookup_Code
                                      AND arl.lookup_type = 'SITE_USE_CODE'
                                      AND primary_flag = 'Y') job_role
                         FROM hz_cust_account_roles hcar, hz_parties hpsub, hz_parties hprel,
                              hz_org_contacts hoc, hz_relationships hr, hz_party_sites hps,
                              fnd_territories_vl ftv, fnd_lookup_values_vl lookups, hz_cust_accounts act,
                              hz_contact_points hcp
                        WHERE     1 = 1
                              --    AND act.party_id =1255466680
                              AND hcar.role_type = 'CONTACT'
                              AND hcar.party_id = hr.party_id
                              AND hr.party_id = hprel.party_id
                              AND hr.subject_id = hpsub.party_id
                              AND hoc.party_relationship_id =
                                  hr.relationship_id
                              AND hcar.cust_account_id = act.cust_account_id
                              AND act.party_id = hr.object_id
                              AND hps.party_id(+) = hprel.party_id
                              AND NVL (hps.identifying_address_flag(+), 'Y') =
                                  'Y'
                              AND NVL (hps.status(+), 'A') = 'A'
                              AND hprel.country = ftv.territory_code(+)
                              AND hcar.cust_acct_site_id IS NOT NULL
                              AND lookups.lookup_type(+) = 'RESPONSIBILITY'
                              AND lookups.lookup_code(+) = hoc.job_title_code
                              AND hcp.owner_table_id = hcar.party_id
                              AND hcp.owner_table_name = 'HZ_PARTIES'
                              AND hcp.status = 'A'
                              AND EXISTS
                                      (SELECT 1
                                         FROM xxd_ar_ext_coll_cust_trx_stg_t trx
                                        WHERE     trx.conc_request_id =
                                                  gn_conc_request_id
                                              AND trx.party_id = act.party_id))
                WHERE 1 = 1
             GROUP BY party_id, account_number, first_name,
                      last_name, email_address, phone_number,
                      mobile_number, job_title, job_role);

        TYPE tb_rec IS TABLE OF open_ar_cur%ROWTYPE;

        v_tb_rec            tb_rec;
        v_bulk_limit        NUMBER := 5000;
        le_bulk_inst_exe    EXCEPTION;
        PRAGMA EXCEPTION_INIT (le_bulk_inst_exe, -24381);

        TYPE tb_cont_rec IS TABLE OF c_contacts%ROWTYPE;

        v_tb_cont_rec       tb_cont_rec;

        ld_trx_date_from    DATE;
        ld_trx_date_to      DATE;
        ld_payment_date     DATE;
        ln_payment_amount   NUMBER;
        lv_status           VARCHAR2 (2000);
        ln_error_num        NUMBER;
        lv_error_code       VARCHAR2 (2000);
        lv_error_msg        VARCHAR2 (2000);
    BEGIN
        --execute immediate 'truncate table xxdo.xxd_ar_ext_coll_contacts_stg_t';
        OPEN open_ar_cur (p_org_id);

        LOOP
            FETCH open_ar_cur BULK COLLECT INTO v_tb_rec LIMIT v_bulk_limit;

            BEGIN
                IF v_tb_rec.COUNT > 0
                THEN
                    --  dbms_output.put_line ('Record Count: ' || v_tb_rec.COUNT);

                    FORALL i IN 1 .. v_tb_rec.COUNT SAVE EXCEPTIONS
                        INSERT INTO XXDO.XXD_AR_EXT_COLL_CUST_TRX_STG_T (
                                        CUSTOMER_TRX_ID,
                                        UNIQUE_TRX_ID,
                                        INVOICE_NUMBER,
                                        TRX_DATE,
                                        DUE_DATE,
                                        INVOICE_AMOUNT,
                                        INVOICE_CURRENCY_CODE,
                                        ORIGINAL_CURRENCY,
                                        BASE_CURRENCY,
                                        DENOMINATION_IN_BASE_CURRENCY,
                                        DENOMINATION_IN_ORIGINAL_CURRENCY,
                                        ORIG_DENOM_ORIG_CURRENCY,
                                        ORIG_DENOM_BASE_CURRENCY,
                                        CUST_TRX_TYPE_ID,
                                        OPEN_AMOUNT,
                                        PO_NUMBER,
                                        PAYMENT_TERM,
                                        PAYMENT_TERM_ID,
                                        PARTY_ID,
                                        nb_cust_account_id,
                                        NB_CUSTOMER_NUMBER,
                                        NB_PARTY_NAME,
                                        NB_CURRENCY,
                                        NB_ADDRESS_LINES,
                                        NB_CITY,
                                        NB_ZIP_CODE,
                                        NB_COUNTRY--   , NB_BILL_TO_SITE_USE_ID
                                                  ,
                                        BILL_TO_CUSTOMER_ID,
                                        BILL_TO_CUSTOMER_NUM,
                                        BILL_TO_CUSTOMER_NAME,
                                        BILL_TO_ADDRESS1,
                                        BILL_TO_ADDRESS2,
                                        BILL_TO_ADDRESS3,
                                        BILL_TO_ADDRESS4,
                                        BILL_TO_CITY,
                                        BILL_TO_STATE,
                                        BILL_TO_ZIP_CODE,
                                        BILL_TO_COUNTRY,
                                        DOCUMENT_TYPE,
                                        SO_NUMBER,
                                        BOL,
                                        DELIVERY,
                                        WAYBILL_NUMBER,
                                        DISPUTE_DATE,
                                        DISPUTE_AMOUNT,
                                        COMMENTS,
                                        BRAND,
                                        SALES_REP,
                                        INTERFACE_HEADER_CONTEXT,
                                        CLAIM_NUMBER,
                                        CLAIM_REASON,
                                        CLAIM_OWNER,
                                        BUYING_AGENT_GROUP_NUM,
                                        BUYING_MEMBERSHIP_NUM,
                                        BUYING_GROUP_VAT_NUM,
                                        ORG_ID,
                                        OPERATING_UNIT,
                                        SHIP_TO_CUSTOMER_NUM,
                                        SHIP_TO_CUSTOMER_NAME,
                                        SHIP_TO_ADDRESS1,
                                        SHIP_TO_ADDRESS2,
                                        SHIP_TO_ADDRESS3,
                                        SHIP_TO_ADDRESS4,
                                        SHIP_TO_CITY,
                                        SHIP_TO_STATE,
                                        SHIP_TO_ZIP_CODE,
                                        SHIP_TO_COUNTRY,
                                        BILL_TO_SITE_USE_ID,
                                        SHIP_TO_SITE_USE_ID,
                                        LANGUAGE,
                                        TEL,
                                        MOBILE_PHONE,
                                        FAX,
                                        EMAIl_ADDRESS,
                                        CREDIT_LIMIT,
                                        PROFILE_CLASS,
                                        ULTIMATE_PARENT,
                                        COLLECTOR_NAME,
                                        RESEARCHER,
                                        CREDIT_ANALYST,
                                        PARENT_NUMBER,
                                        ALIAS,
                                        CUSTOMER_SINCE,
                                        LAST_PAYMENT_PAID_ON,
                                        LAST_PAYMENT_DUE_ON,
                                        LAST_PAYMENT_AMOUNT,
                                        LAST_CREDIT_REVIEW,
                                        NEXT_CREDIT_REVIEW,
                                        CONC_REQUEST_ID,
                                        CREATED_BY,
                                        CREATION_DATE,
                                        LAST_UPDATED_BY,
                                        LAST_UPDATE_DATE)
                             VALUES (v_tb_rec (i).customer_trx_id, v_tb_rec (i).unique_trx_id, v_tb_rec (i).invoice_number, v_tb_rec (i).invoice_date, v_tb_rec (i).due_date, TO_CHAR (v_tb_rec (i).invoice_amount, 'fm9999990.00'), v_tb_rec (i).invoice_currency_code, v_tb_rec (i).invoice_currency_code, v_tb_rec (i).invoice_currency_code, TO_CHAR (v_tb_rec (i).open_amount, 'fm9999990.00'), TO_CHAR (v_tb_rec (i).open_amount, 'fm9999990.00'), TO_CHAR (v_tb_rec (i).invoice_amount, 'fm9999990.00'), TO_CHAR (v_tb_rec (i).invoice_amount, 'fm9999990.00'), v_tb_rec (i).cust_trx_type_id, v_tb_rec (i).open_amount, v_tb_rec (i).po_number, v_tb_rec (i).payment_term, v_tb_rec (i).payment_term_id, v_tb_rec (i).party_id, v_tb_rec (i).cust_account_id, v_tb_rec (i).nb_account_number, v_tb_rec (i).nb_party_name, v_tb_rec (i).nb_currency, v_tb_rec (i).nb_address_lines, v_tb_rec (i).nb_city, v_tb_rec (i).nb_postal_code, v_tb_rec (i).nb_country--    ,v_tb_rec(i).site_use_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     , v_tb_rec (i).bill_to_customer_id, v_tb_rec (i).bill_to_customer_number, v_tb_rec (i).bill_to_customer_name, v_tb_rec (i).bill_to_address1, v_tb_rec (i).bill_to_address2, v_tb_rec (i).bill_to_address3, v_tb_rec (i).bill_to_address4, v_tb_rec (i).bill_to_city, v_tb_rec (i).bill_to_state_or_prov, v_tb_rec (i).bill_to_zip_code, v_tb_rec (i).bill_to_country, v_tb_rec (i).document_type, v_tb_rec (i).sales_order_number, v_tb_rec (i).bill_of_lading, v_tb_rec (i).delivery, v_tb_rec (i).waybill, v_tb_rec (i).dispute_date, v_tb_rec (i).dispute_amount, v_tb_rec (i).comments, v_tb_rec (i).brand, v_tb_rec (i).sales_rep, v_tb_rec (i).interface_header_context, v_tb_rec (i).claim_number, v_tb_rec (i).claim_reason, v_tb_rec (i).claim_owner, v_tb_rec (i).buying_group_customer_number --buying_agent_group_num
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             , v_tb_rec (i).customer_membership_number --buying_membership_num
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      , v_tb_rec (i).buying_group_vat_number --buying_group_vat_number -- buying_vat_number
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            , v_tb_rec (i).org_id, v_tb_rec (i).operating_unit, v_tb_rec (i).ship_to_customer_number, v_tb_rec (i).ship_to_customer_name, v_tb_rec (i).ship_to_address1, v_tb_rec (i).ship_to_address2, v_tb_rec (i).ship_to_address3, v_tb_rec (i).ship_to_address4, v_tb_rec (i).ship_to_city, v_tb_rec (i).ship_to_state_or_prov, v_tb_rec (i).ship_to_zip_code, v_tb_rec (i).ship_to_country, v_tb_rec (i).bill_to_site_use_id, v_tb_rec (i).ship_to_site_use_id, v_tb_rec (i).language, v_tb_rec (i).tel, v_tb_rec (i).mobile_phone, v_tb_rec (i).fax, v_tb_rec (i).email, v_tb_rec (i).credit_limit, v_tb_rec (i).profile_class, v_tb_rec (i).ultimate_parent, v_tb_rec (i).collector_name, v_tb_rec (i).researcher, v_tb_rec (i).credit_analyst, v_tb_rec (i).parent_number, v_tb_rec (i).alias, v_tb_rec (i).customer_since, v_tb_rec (i).last_payment_paid_on, v_tb_rec (i).last_payment_due_on, v_tb_rec (i).last_payment_amount, v_tb_rec (i).last_credit_review_date, v_tb_rec (i).next_credit_review_date, gn_conc_request_id, fnd_global.user_id
                                     , SYSDATE, fnd_global.user_id, SYSDATE);
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                    LOOP
                        ln_error_num    := SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                        lv_error_code   :=
                            SQLERRM (-1 * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                        lv_error_msg    :=
                            SUBSTR (
                                (lv_error_msg || ' Error While Insert into Table ' || v_tb_rec (ln_error_num).invoice_number || ' ' || lv_error_code || CHR (10)),
                                1,
                                4000);

                        fnd_file.put_line (fnd_file.LOG, lv_error_msg);
                        lv_status       := 'E';
                    END LOOP;

                    RAISE le_bulk_inst_exe;
            END;

            v_tb_rec.delete;
            EXIT WHEN open_ar_cur%NOTFOUND;
        END LOOP;

        COMMIT;

        CLOSE open_ar_cur;


        OPEN c_contacts;

        LOOP
            FETCH c_contacts
                BULK COLLECT INTO v_tb_cont_rec
                LIMIT v_bulk_limit;

            BEGIN
                IF v_tb_cont_rec.COUNT > 0
                THEN
                    FORALL j IN 1 .. v_tb_cont_rec.COUNT SAVE EXCEPTIONS
                        INSERT INTO XXDO.XXD_AR_EXT_COLL_CONTACTS_STG_T (
                                        CONTACT_POINT_ID,
                                        PARTY_ID,
                                        ACCOUNT_NUMBER,
                                        FIRST_NAME,
                                        LAST_NAME,
                                        JOB_TITLE,
                                        JOB_ROLE,
                                        PHONE_NUMBER,
                                        MOBILE_NUMBER,
                                        FAX,
                                        EMAIL,
                                        CONC_REQUEST_ID,
                                        CREATED_BY,
                                        CREATION_DATE,
                                        LAST_UPDATED_BY,
                                        LAST_UPDATE_DATE)
                             VALUES (v_tb_cont_rec (j).contact_point_id, v_tb_cont_rec (j).party_id, v_tb_cont_rec (j).account_number, v_tb_cont_rec (j).first_name, v_tb_cont_rec (j).last_name, v_tb_cont_rec (j).job_title, v_tb_cont_rec (j).job_role, v_tb_cont_rec (j).phone_number, v_tb_cont_rec (j).mobile_number, NULL, v_tb_cont_rec (j).email_address, gn_conc_request_id, fnd_global.user_id, SYSDATE, fnd_global.user_id
                                     , SYSDATE);
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    FOR k IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                    LOOP
                        ln_error_num    := SQL%BULK_EXCEPTIONS (k).ERROR_INDEX;
                        lv_error_code   :=
                            SQLERRM (-1 * SQL%BULK_EXCEPTIONS (k).ERROR_CODE);
                        lv_error_msg    :=
                            SUBSTR (
                                (lv_error_msg || ' Error While Insert into Table ' || v_tb_rec (ln_error_num).invoice_number || ' ' || lv_error_code || CHR (10)),
                                1,
                                4000);

                        fnd_file.put_line (fnd_file.LOG, lv_error_msg);
                        lv_status       := 'E';
                    END LOOP;

                    RAISE le_bulk_inst_exe;
            END;

            v_tb_cont_rec.delete;
            EXIT WHEN c_contacts%NOTFOUND;
        END LOOP;

        COMMIT;

        CLOSE c_contacts;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Failed to insert the data into invoice table:' || SQLERRM);
    END insert_open_ar_staging;

    PROCEDURE main (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id IN NUMBER
                    , p_file_path IN VARCHAR2)
    AS
        lv_ret_code      VARCHAR2 (30) := NULL;
        lv_ret_message   VARCHAR2 (2000) := NULL;
        lv_file_name     VARCHAR2 (500);
        lv_ou_name       VARCHAR2 (250);
    BEGIN
        --Print Input Parameters
        print_log ('Printing Input Parameters');
        print_log (' ');
        print_log ('p_org_id                         :' || p_org_id);
        print_log (' ');

        insert_open_ar_staging (p_org_id, lv_ret_code, lv_ret_message);

        BEGIN
            SELECT name
              INTO lv_ou_name
              FROM hr_operating_units
             WHERE organization_id = p_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_ou_name   := 'Deckers ';
        END;

        lv_file_name   :=
            lv_ou_name || '_' || 'AR_Transactions_Data' || '.xml';

        createxml (gn_conc_request_id, p_file_path, lv_file_name);
    END main;
END XXD_AR_EXT_COLL_OUT_PKG;
/
