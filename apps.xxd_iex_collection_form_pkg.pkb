--
-- XXD_IEX_COLLECTION_FORM_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:45 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_IEX_COLLECTION_FORM_PKG"
AS
    -- #########################################################################################
    -- Author(s) : Tejaswi Gangumalla
    -- System    : Oracle Applications
    -- Subsystem :
    -- Schema    : APPS
    -- Purpose   : This package is used in collections form
    -- Dependency : None
    -- Change History
    -- --------------
    -- Date         Name                  Ver   Change               Description
    -- ----------   --------------        ----- -------------------- ---------------------
    -- 27-SEP-2021  Tejaswi Gangumalla    1.0   NA                   Initial Version
    -- 29-MAR-2023  Kishan Kouru          1.1   CCR0009817- Credit
    --                                          limit fetching from
    --                                          party level profile
    -- #########################################################################################
    gn_user_id   NUMBER := fnd_global.user_id;

    PROCEDURE insert_party_data (pn_party_id          NUMBER,
                                 pn_cust_account_id   NUMBER,
                                 pn_org_id            NUMBER,
                                 pn_currency_code     VARCHAR2,
                                 pn_session_id        NUMBER)
    AS
        ln_credit_score              NUMBER;
        ln_pqa                       NUMBER;
        lv_nsf_c2b                   VARCHAR2 (2000);
        ld_next_credit_review_date   DATE;
        ln_party_level_ou_cnt        NUMBER;
        ln_overall_credit_limit      NUMBER;
        ln_profile_class             VARCHAR2 (200);
        gn_user_id                   NUMBER := fnd_global.user_id;
        lv_sales_channel             VARCHAR2 (100);
        lv_currency                  VARCHAR2 (30);
    BEGIN
        BEGIN
            SELECT attribute1, attribute2, attribute3
              INTO ln_credit_score, ln_pqa, lv_nsf_c2b
              FROM apps.hz_parties hp
             WHERE     hp.party_id = pn_party_id
                   AND UPPER (hp.attribute_category) = 'CUSTOMER';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_credit_score   := NULL;
                ln_pqa            := NULL;
                lv_nsf_c2b        := NULL;
            WHEN OTHERS
            THEN
                ln_credit_score   := NULL;
                ln_pqa            := NULL;
                lv_nsf_c2b        := NULL;
        END;

        -- as part of this CCR0009817, code changes start
        IF pn_cust_account_id IS NOT NULL
        THEN
            BEGIN
                SELECT sales_channel_code
                  INTO lv_sales_channel
                  FROM hz_cust_accounts
                 WHERE cust_account_id = pn_cust_account_id;    -- 1281920054;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_sales_channel   := NULL;
                WHEN OTHERS
                THEN
                    lv_sales_channel   := NULL;
            END;
        ELSIF pn_cust_account_id IS NULL
        THEN
            BEGIN
                SELECT sales_channel_code
                  INTO lv_sales_channel
                  FROM hz_cust_accounts
                 WHERE party_id = pn_party_id AND ROWNUM = 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_sales_channel   := NULL;
            END;
        END IF;


        BEGIN
            SELECT hz_amt.currency_code
              INTO lv_currency
              FROM apps.hz_cust_profile_amts hz_amt, apps.hz_customer_profiles hz_prof
             WHERE     hz_amt.cust_account_id = -1
                   AND hz_prof.party_id = pn_party_id
                   AND hz_amt.site_use_id IS NULL
                   AND hz_amt.cust_account_profile_id =
                       hz_prof.cust_account_profile_id
                   AND hz_prof.site_use_id IS NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_currency   := NULL;
        END;

        -- CCR0009817  end of code changes

        BEGIN
            SELECT next_credit_review_date
              INTO ld_next_credit_review_date
              FROM apps.hz_customer_profiles
             WHERE     next_credit_review_date IS NOT NULL
                   AND cust_account_id = -1
                   AND party_id = pn_party_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ld_next_credit_review_date   := NULL;
            WHEN OTHERS
            THEN
                ld_next_credit_review_date   := NULL;
        END;

        BEGIN
            SELECT COUNT (*)
              INTO ln_party_level_ou_cnt
              FROM apps.fnd_flex_values_vl ffvl, apps.fnd_flex_value_sets ffvs, apps.hr_operating_units hr
             WHERE     hr.organization_id = pn_org_id
                   AND hr.NAME = ffvl.flex_value
                   AND ffvl.flex_value_set_id = ffvs.flex_value_set_id
                   AND ffvs.flex_value_set_name = 'XXDO_COLL_PARTY_LEVEL_OU'
                   AND ffvl.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (ffvl.start_date_active, SYSDATE)
                                   AND NVL (ffvl.end_date_active, SYSDATE);
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_party_level_ou_cnt   := 0;
        END;

        IF ln_party_level_ou_cnt > 0
        THEN
            -- as part of this CCR0009817, code changes start
            IF (NVL (lv_currency, 'XX') = 'HKD' AND NVL (lv_sales_channel, 'XX') = 'WHOLESALE' AND pn_org_id = 97)
            THEN
                BEGIN
                    SELECT NVL (SUM (hz_amt.overall_credit_limit), 0) overall_credit_limit
                      INTO ln_overall_credit_limit
                      FROM apps.hz_cust_profile_amts hz_amt, apps.hz_customer_profiles hz_prof, apps.hz_cust_profile_classes hz_class
                     WHERE     hz_amt.cust_account_id = -1
                           AND hz_prof.party_id = pn_party_id
                           AND hz_amt.site_use_id IS NULL
                           AND hz_amt.cust_account_profile_id =
                               hz_prof.cust_account_profile_id
                           AND hz_prof.site_use_id IS NULL
                           AND hz_amt.currency_code = lv_currency
                           AND hz_prof.profile_class_id =
                               hz_class.profile_class_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_overall_credit_limit   := 0;
                    WHEN OTHERS
                    THEN
                        ln_overall_credit_limit   := 0;
                END;
            -- CCR0009817  end of code changes
            ELSE
                BEGIN
                    SELECT NVL (SUM (hz_amt.overall_credit_limit), 0) overall_credit_limit
                      INTO ln_overall_credit_limit
                      FROM apps.hz_cust_profile_amts hz_amt, apps.hz_customer_profiles hz_prof, apps.hz_cust_profile_classes hz_class
                     WHERE     hz_amt.cust_account_id = -1
                           AND hz_prof.party_id = pn_party_id
                           AND hz_amt.site_use_id IS NULL
                           AND hz_amt.cust_account_profile_id =
                               hz_prof.cust_account_profile_id
                           AND hz_prof.site_use_id IS NULL
                           AND hz_amt.currency_code = pn_currency_code
                           AND hz_prof.profile_class_id =
                               hz_class.profile_class_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_overall_credit_limit   := 0;
                    WHEN OTHERS
                    THEN
                        ln_overall_credit_limit   := 0;
                END;
            END IF;
        ELSE
            BEGIN
                SELECT NVL (SUM (hz_amt.overall_credit_limit), 0) overall_credit_limit
                  INTO ln_overall_credit_limit
                  FROM apps.hz_cust_profile_amts hz_amt, apps.hz_customer_profiles hz_prof, apps.hz_cust_profile_classes hz_class,
                       apps.hz_cust_accounts hz
                 WHERE     hz.party_id = pn_party_id
                       AND hz_amt.cust_account_id = hz.cust_account_id
                       AND hz_amt.site_use_id IS NULL
                       AND hz_amt.cust_account_profile_id =
                           hz_prof.cust_account_profile_id
                       AND hz_prof.site_use_id IS NULL
                       AND hz_prof.profile_class_id =
                           hz_class.profile_class_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_overall_credit_limit   := 0;
                WHEN OTHERS
                THEN
                    ln_overall_credit_limit   := 0;
            END;
        END IF;

        IF pn_cust_account_id IS NULL
        THEN
            BEGIN
                SELECT hcpc.NAME
                  INTO ln_profile_class
                  FROM hz_customer_profiles hcp, hz_cust_profile_classes hcpc
                 WHERE     hcp.profile_class_id = hcpc.profile_class_id
                       AND hcp.cust_account_id = -1
                       AND hcp.party_id = pn_party_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_profile_class   := NULL;
            END;
        END IF;

        IF pn_cust_account_id IS NOT NULL
        THEN
            BEGIN
                SELECT hcpc.NAME
                  INTO ln_profile_class
                  FROM hz_customer_profiles hcp, hz_cust_profile_classes hcpc
                 WHERE     hcp.profile_class_id = hcpc.profile_class_id
                       AND hcp.cust_account_id = pn_cust_account_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_profile_class   := NULL;
            END;
        END IF;

        BEGIN
            UPDATE xxd_iex_collect_form_party_t
               SET credit_score = ln_credit_score, pqa = ln_pqa, nsf_c2b = lv_nsf_c2b,
                   next_credit_review_date = ld_next_credit_review_date, overall_credit_limit = ln_overall_credit_limit, profile_name = ln_profile_class
             WHERE session_id = pn_session_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END insert_party_data;

    PROCEDURE insert_cust_account_data (pn_party_id          NUMBER,
                                        pn_cust_account_id   NUMBER,
                                        pn_org_id            NUMBER,
                                        pn_currency_code     VARCHAR2,
                                        pn_session_id        NUMBER)
    AS
        CURSOR cust_cur IS
            SELECT cust_account_id, account_number
              FROM hz_cust_accounts
             WHERE     party_id = pn_party_id
                   AND cust_account_id =
                       NVL (pn_cust_account_id, cust_account_id);

        ln_credit_rule                   NUMBER;
        ln_horizon_days                  NUMBER;
        pn_open_ar_bal_net               NUMBER;
        pn_open_release_orders           NUMBER;
        ld_prev_year                     DATE := NULL;
        pn_sales_current_ytd             NUMBER;
        pn_sales_prior_year_period_ytd   NUMBER;
        pn_sales_prior_year_ytd          NUMBER;
        pn_highest_credit_amt            NUMBER;
        pd_highest_credit_date           DATE;
        pn_cust_acct_credit_limit        NUMBER;
        pn_open_release_orders_g21       NUMBER;
        ln_order_onhold                  NUMBER;

        SUBTYPE cust IS cust_cur%ROWTYPE;

        TYPE custlist IS TABLE OF cust;

        cust_record                      custlist;
        ln_cust_id                       NUMBER;
    BEGIN
        OPEN cust_cur;

        FETCH cust_cur BULK COLLECT INTO cust_record;

        CLOSE cust_cur;

        FOR cust_rec IN cust_record.FIRST .. cust_record.LAST
        LOOP
            pn_open_ar_bal_net               := NULL;
            pn_open_release_orders           := NULL;
            pn_sales_current_ytd             := NULL;
            pn_sales_prior_year_period_ytd   := NULL;
            pn_sales_prior_year_ytd          := NULL;
            pn_highest_credit_amt            := NULL;
            pd_highest_credit_date           := NULL;
            pn_cust_acct_credit_limit        := NULL;
            pn_open_release_orders_g21       := NULL;
            ln_order_onhold                  := NULL;
            ln_cust_id                       :=
                cust_record (cust_rec).cust_account_id;

            BEGIN
                SELECT NVL (SUM (sched.amount_due_remaining), 0) open_ar_bal
                  INTO pn_open_ar_bal_net
                  FROM ar.ar_payment_schedules_all sched
                 WHERE     sched.status = 'OP'
                       AND sched.customer_id = ln_cust_id
                       AND sched.org_id = pn_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    pn_open_ar_bal_net   := NULL;
            END;

            BEGIN
                SELECT cum_balance, as_of_date
                  INTO pn_highest_credit_amt, pd_highest_credit_date
                  FROM (SELECT customer_id, customer_site_use_id, invoice_currency_code,
                               as_of_date, cum_balance, RANK () OVER (ORDER BY cum_balance DESC) RANK
                          FROM (SELECT customer_id, customer_site_use_id, invoice_currency_code,
                                       as_of_date, SUM (net_amount) OVER (PARTITION BY customer_id, customer_site_use_id, invoice_currency_code ORDER BY customer_id, customer_site_use_id, invoice_currency_code ROWS UNBOUNDED PRECEDING) cum_balance
                                  FROM (  SELECT customer_id, customer_site_use_id, invoice_currency_code,
                                                 as_of_date, SUM (net_amount) net_amount
                                            FROM (  SELECT ps.customer_id, ps.customer_site_use_id, ps.invoice_currency_code,
                                                           ps.trx_date as_of_date, SUM (ps.amount_due_original) net_amount
                                                      FROM apps.ar_payment_schedules_all ps
                                                     WHERE     ps.CLASS IN
                                                                   ('INV', 'CM', 'DM',
                                                                    'DEP', 'BR', 'CB')
                                                           AND ps.customer_id =
                                                               ln_cust_id
                                                  GROUP BY ps.customer_id, ps.customer_site_use_id, ps.invoice_currency_code,
                                                           ps.trx_date
                                                  UNION ALL
                                                    SELECT ps.customer_id, ps.customer_site_use_id, ps.invoice_currency_code,
                                                           ra.apply_date as_of_date, SUM (-ra.amount_applied - NVL (ra.earned_discount_taken, 0) - NVL (ra.unearned_discount_taken, 0)) net_amount
                                                      FROM apps.ar_payment_schedules_all ps, apps.ar_receivable_applications_all ra
                                                     WHERE     ps.payment_schedule_id =
                                                               ra.applied_payment_schedule_id
                                                           AND ps.customer_id =
                                                               ln_cust_id
                                                           AND ra.status = 'APP'
                                                           AND ra.application_type =
                                                               'CASH'
                                                           AND NVL (
                                                                   ra.confirmed_flag,
                                                                   'Y') =
                                                               'Y'
                                                           AND ps.CLASS IN
                                                                   ('INV', 'CM', 'DM',
                                                                    'DEP', 'BR', 'CB')
                                                  GROUP BY ps.customer_id, ps.customer_site_use_id, ps.invoice_currency_code,
                                                           ra.apply_date
                                                  UNION ALL
                                                    SELECT ps.customer_id, ps.customer_site_use_id, ps.invoice_currency_code,
                                                           adj.apply_date as_of_date, SUM (adj.amount)
                                                      FROM apps.ar_payment_schedules_all ps, apps.ar_adjustments_all adj
                                                     WHERE     ps.payment_schedule_id =
                                                               adj.payment_schedule_id
                                                           AND ps.CLASS IN
                                                                   ('INV', 'CM', 'DM',
                                                                    'DEP', 'BR', 'CB')
                                                           AND adj.status = 'A'
                                                           AND ps.customer_id =
                                                               ln_cust_id
                                                  GROUP BY ps.customer_id, ps.customer_site_use_id, ps.invoice_currency_code,
                                                           adj.apply_date)
                                        GROUP BY customer_id, customer_site_use_id, invoice_currency_code,
                                                 as_of_date))
                         WHERE as_of_date > ADD_MONTHS (SYSDATE, -24))
                 WHERE RANK = 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    pn_highest_credit_amt    := NULL;
                    pd_highest_credit_date   := NULL;
            END;

            BEGIN
                SELECT NVL (SUM (hz_amt.overall_credit_limit), 0) overall_credit_limit
                  INTO pn_cust_acct_credit_limit
                  FROM apps.hz_cust_profile_amts hz_amt, apps.hz_customer_profiles hz_prof, apps.hz_cust_profile_classes hz_class
                 WHERE     hz_amt.cust_account_id = ln_cust_id
                       AND hz_amt.site_use_id IS NULL
                       AND hz_amt.cust_account_profile_id =
                           hz_prof.cust_account_profile_id
                       AND hz_prof.site_use_id IS NULL
                       AND hz_prof.profile_class_id =
                           hz_class.profile_class_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    pn_cust_acct_credit_limit   := NULL;
            END;

            BEGIN
                SELECT NVL (SUM (ROUND ((oola.ordered_quantity - NVL (oola.shipped_quantity, NVL (oola.fulfilled_quantity, 0))) * NVL (oola.unit_selling_price, 0) + DECODE ('Y', 'Y', NVL (NVL (oola.tax_line_value, oola.tax_value), 0), 0), fc.PRECISION)), 0) num_of_salesord_amt
                  INTO ln_order_onhold
                  FROM apps.oe_order_headers_all ooha, apps.oe_order_lines_all oola, fnd_currencies fc
                 WHERE     oola.header_id = ooha.header_id
                       AND ooha.transactional_curr_code = fc.currency_code
                       AND ooha.sold_to_org_id = ln_cust_id
                       AND ooha.org_id = pn_org_id
                       --AND cust_acct.status = 'A'
                       AND oola.open_flag = 'Y'
                       AND ooha.open_flag = 'Y'
                       AND oola.booked_flag = 'Y'
                       AND oola.line_category_code = 'ORDER'     --<> 'RETURN'
                       AND EXISTS
                               (SELECT 1
                                  FROM oe_order_holds_all holds, oe_hold_sources_all ohsa, oe_hold_definitions ohd
                                 WHERE     holds.hold_source_id =
                                           ohsa.hold_source_id
                                       AND ohsa.hold_id = ohd.hold_id
                                       AND holds.header_id = ooha.header_id
                                       AND holds.released_flag = 'N'
                                       AND ohsa.released_flag = 'N'
                                       AND ohd.type_code = 'CREDIT'
                                       AND holds.header_id = ooha.header_id)
                       AND oola.flow_status_code IN
                               ('PO_CREATED', 'BOOKED', 'AWAITING_SHIPPING',
                                'AWAITING_RECEIPT', 'INVOICED', 'SUPPLY_ELIGIBLE',
                                'PO_REQ_CREATED', 'PO_OPEN')--AND ooha.flow_status_code NOT IN ('CANCELLED', 'CLOSED')
                                                            ;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_order_onhold   := 0;
            END;

            BEGIN
                INSERT INTO xxd_iex_collectfrm_custacct_t
                     VALUES (pn_party_id, ln_cust_id, ln_cust_id,
                             pn_open_ar_bal_net, pn_highest_credit_amt, pd_highest_credit_date, pn_cust_acct_credit_limit, ln_order_onhold, pn_session_id, SYSDATE, gn_user_id, SYSDATE
                             , gn_user_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END insert_cust_account_data;

    PROCEDURE insert_cust_account_sales_ytd_data (pn_party_id NUMBER, pn_cust_account_id NUMBER, pn_org_id NUMBER
                                                  , pn_currency_code VARCHAR2, pn_session_id NUMBER)
    AS
        CURSOR cust_cur IS
            SELECT cust_account_id, account_number
              FROM hz_cust_accounts
             WHERE     party_id = pn_party_id
                   AND cust_account_id =
                       NVL (pn_cust_account_id, cust_account_id);

        SUBTYPE cust IS cust_cur%ROWTYPE;

        TYPE custlist IS TABLE OF cust;

        cust_record                      custlist;
        ln_cust_id                       NUMBER;
        ln_credit_rule                   NUMBER;
        ln_horizon_days                  NUMBER;
        pn_open_ar_bal_net               NUMBER;
        pn_open_release_orders           NUMBER;
        ld_prev_year                     DATE := NULL;
        pn_sales_current_ytd             NUMBER;
        pn_sales_prior_year_period_ytd   NUMBER;
        pn_sales_prior_year_ytd          NUMBER;
        pn_highest_credit_amt            NUMBER;
        pd_highest_credit_date           DATE;
        pn_cust_acct_credit_limit        NUMBER;
        pn_open_release_orders_g21       NUMBER;
        ln_order_onhold                  NUMBER;
        lv_year_start                    DATE;
    BEGIN
        BEGIN
            SELECT DISTINCT TRUNC (year_start_date)
              INTO lv_year_start
              FROM apps.gl_periods
             WHERE     1 = 1
                   AND SYSDATE BETWEEN start_date AND end_date
                   AND period_set_name = 'DO_FY_CALENDAR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_year_start   := NULL;
        END;

        BEGIN
            SELECT SUM (rctl.extended_amount)
              INTO pn_sales_current_ytd
              FROM apps.hz_cust_accounts hca, apps.ra_customer_trx_all rct, apps.ra_customer_trx_lines_all rctl
             WHERE     hca.party_id = pn_party_id
                   AND hca.cust_account_id =
                       NVL (pn_cust_account_id, hca.cust_account_id)
                   AND rct.bill_to_customer_id = hca.cust_account_id
                   AND rct.org_id = pn_org_id
                   AND rct.org_id = rctl.org_id
                   AND rct.customer_trx_id = rctl.customer_trx_id
                   AND rct.trx_date BETWEEN lv_year_start AND SYSDATE;
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_sales_current_ytd   := 0;
        END;

        BEGIN
            UPDATE xxd_iex_collect_form_party_t
               SET sales_current_ytd   = pn_sales_current_ytd
             WHERE party_id = pn_party_id AND session_id = pn_session_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        COMMIT;
    END insert_cust_account_sales_ytd_data;

    PROCEDURE insert_cust_account_sales_prevytd_data (pn_party_id NUMBER, pn_cust_account_id NUMBER, pn_org_id NUMBER
                                                      , pn_currency_code VARCHAR2, pn_session_id NUMBER)
    AS
        CURSOR cust_cur IS
            SELECT cust_account_id, account_number
              FROM hz_cust_accounts
             WHERE     party_id = pn_party_id
                   AND cust_account_id =
                       NVL (pn_cust_account_id, cust_account_id);

        ln_credit_rule                   NUMBER;
        ln_horizon_days                  NUMBER;
        pn_open_ar_bal_net               NUMBER;
        pn_open_release_orders           NUMBER;
        ld_prev_year                     DATE := NULL;
        pn_sales_current_ytd             NUMBER;
        pn_sales_prior_year_period_ytd   NUMBER;
        pn_sales_prior_year_ytd          NUMBER;
        pn_highest_credit_amt            NUMBER;
        pd_highest_credit_date           DATE;
        pn_cust_acct_credit_limit        NUMBER;
        pn_open_release_orders_g21       NUMBER;
        ln_order_onhold                  NUMBER;
        lv_year_start                    DATE;

        SUBTYPE cust IS cust_cur%ROWTYPE;

        TYPE custlist IS TABLE OF cust;

        cust_record                      custlist;
        ln_cust_id                       NUMBER;
    BEGIN
        BEGIN
            SELECT DISTINCT TRUNC (year_start_date)
              INTO ld_prev_year
              FROM apps.gl_periods
             WHERE     1 = 1
                   AND (SYSDATE - 366) BETWEEN start_date AND end_date
                   AND period_set_name = 'DO_FY_CALENDAR';
        EXCEPTION
            WHEN OTHERS
            THEN
                ld_prev_year   := NULL;
        END;

        BEGIN
            SELECT SUM (rctl.extended_amount)
              INTO pn_sales_prior_year_period_ytd
              FROM apps.hz_cust_accounts hca, apps.ra_customer_trx_all rct, apps.ra_customer_trx_lines_all rctl
             WHERE     hca.party_id = pn_party_id
                   AND hca.cust_account_id =
                       NVL (pn_cust_account_id, hca.cust_account_id)
                   AND rct.bill_to_customer_id = hca.cust_account_id
                   AND rct.org_id = pn_org_id
                   AND rct.org_id = rctl.org_id
                   AND rct.customer_trx_id = rctl.customer_trx_id
                   AND rct.trx_date BETWEEN ld_prev_year AND (SYSDATE - 366);
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_sales_prior_year_period_ytd   := 0;
        END;

        BEGIN
            UPDATE xxd_iex_collect_form_party_t
               SET sales_prior_year_period_ytd = pn_sales_prior_year_period_ytd
             WHERE party_id = pn_party_id AND session_id = pn_session_id;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;
    END insert_cust_account_sales_prevytd_data;

    PROCEDURE insert_cust_account_sales_prev_data (pn_party_id NUMBER, pn_cust_account_id NUMBER, pn_org_id NUMBER
                                                   , pn_currency_code VARCHAR2, pn_session_id NUMBER)
    AS
        CURSOR cust_cur IS
            SELECT cust_account_id, account_number
              FROM hz_cust_accounts
             WHERE     party_id = pn_party_id
                   AND cust_account_id =
                       NVL (pn_cust_account_id, cust_account_id);

        SUBTYPE cust IS cust_cur%ROWTYPE;

        TYPE custlist IS TABLE OF cust;

        cust_record                      custlist;
        ln_cust_id                       NUMBER;
        ln_credit_rule                   NUMBER;
        ln_horizon_days                  NUMBER;
        pn_open_ar_bal_net               NUMBER;
        pn_open_release_orders           NUMBER;
        ld_prev_year                     DATE := NULL;
        pn_sales_current_ytd             NUMBER;
        pn_sales_prior_year_period_ytd   NUMBER;
        pn_sales_prior_year_ytd          NUMBER;
        pn_highest_credit_amt            NUMBER;
        pd_highest_credit_date           DATE;
        pn_cust_acct_credit_limit        NUMBER;
        pn_open_release_orders_g21       NUMBER;
        ln_order_onhold                  NUMBER;
        lv_year_start                    DATE;
    BEGIN
        BEGIN
            SELECT DISTINCT TRUNC (year_start_date)
              INTO ld_prev_year
              FROM apps.gl_periods
             WHERE     1 = 1
                   AND (SYSDATE - 366) BETWEEN start_date AND end_date
                   AND period_set_name = 'DO_FY_CALENDAR';
        EXCEPTION
            WHEN OTHERS
            THEN
                ld_prev_year   := NULL;
        END;

        BEGIN
            SELECT SUM (rctl.extended_amount)
              INTO pn_sales_prior_year_ytd
              FROM apps.hz_cust_accounts hca, apps.ra_customer_trx_all rct, apps.ra_customer_trx_lines_all rctl
             WHERE     hca.party_id = pn_party_id
                   AND hca.cust_account_id =
                       NVL (pn_cust_account_id, hca.cust_account_id)
                   AND rct.bill_to_customer_id = hca.cust_account_id
                   AND rct.org_id = pn_org_id
                   AND rct.org_id = rctl.org_id
                   AND rct.customer_trx_id = rctl.customer_trx_id
                   AND rct.trx_date BETWEEN ld_prev_year
                                        AND ((ADD_MONTHS (ld_prev_year, 12)) - 1);
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_sales_prior_year_ytd   := 0;
        END;

        BEGIN
            UPDATE xxd_iex_collect_form_party_t
               SET sales_prior_year_ytd   = pn_sales_prior_year_ytd
             WHERE party_id = pn_party_id AND session_id = pn_session_id;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;
    END insert_cust_account_sales_prev_data;

    PROCEDURE insert_cust_account_release_orders_data (pn_party_id NUMBER, pn_cust_account_id NUMBER, pn_org_id NUMBER
                                                       , pn_currency_code VARCHAR2, pn_session_id NUMBER)
    AS
        CURSOR cust_cur IS
            SELECT cust_account_id, account_number
              FROM hz_cust_accounts
             WHERE     party_id = pn_party_id
                   AND cust_account_id =
                       NVL (pn_cust_account_id, cust_account_id);

        ln_credit_rule                   NUMBER;
        ln_horizon_days                  NUMBER;
        pn_open_ar_bal_net               NUMBER;
        pn_open_release_orders           NUMBER;
        ld_prev_year                     DATE := NULL;
        pn_sales_current_ytd             NUMBER;
        pn_sales_prior_year_period_ytd   NUMBER;
        pn_sales_prior_year_ytd          NUMBER;
        pn_highest_credit_amt            NUMBER;
        pd_highest_credit_date           DATE;
        pn_cust_acct_credit_limit        NUMBER;
        pn_open_release_orders_g21       NUMBER;
        ln_order_onhold                  NUMBER;

        SUBTYPE cust IS cust_cur%ROWTYPE;

        TYPE custlist IS TABLE OF cust;

        cust_record                      custlist;
        ln_cust_id                       NUMBER;
    BEGIN
        BEGIN
            SELECT ffv.attribute1
              INTO ln_credit_rule
              FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values ffv
             WHERE     ffvs.flex_value_set_id = ffv.flex_value_set_id
                   AND ffvs.flex_value_set_name =
                       'XXD_OU_CREDIT_RULE_MAPPING'
                   AND ffv.value_category = 'XXD_OU_CREDIT_RULE_MAPPING'
                   AND NVL (ffv.enabled_flag, 'Y') = 'Y'
                   AND SYSDATE BETWEEN NVL (ffv.start_date_active, SYSDATE)
                                   AND NVL (ffv.end_date_active, SYSDATE)
                   AND flex_value = pn_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_credit_rule   := 0;
        END;

        IF ln_credit_rule IS NOT NULL AND NVL (ln_credit_rule, 0) <> 0
        THEN
            BEGIN
                SELECT shipping_interval
                  INTO ln_horizon_days
                  FROM apps.oe_credit_check_rules
                 WHERE credit_check_rule_id = ln_credit_rule;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_horizon_days   := 21;
            END;
        ELSE
            ln_horizon_days   := 21;
        END IF;

        OPEN cust_cur;

        FETCH cust_cur BULK COLLECT INTO cust_record;

        CLOSE cust_cur;

        FOR cust_rec IN cust_record.FIRST .. cust_record.LAST
        LOOP
            ln_cust_id                       := cust_record (cust_rec).cust_account_id;
            pn_open_ar_bal_net               := NULL;
            pn_open_release_orders           := NULL;
            pn_sales_current_ytd             := NULL;
            pn_sales_prior_year_period_ytd   := NULL;
            pn_sales_prior_year_ytd          := NULL;
            pn_highest_credit_amt            := NULL;
            pd_highest_credit_date           := NULL;
            pn_cust_acct_credit_limit        := NULL;
            pn_open_release_orders_g21       := NULL;
            ln_order_onhold                  := NULL;

            BEGIN
                SELECT NVL (SUM (NVL ((ROUND ((oola.ordered_quantity - NVL (oola.shipped_quantity, NVL (oola.fulfilled_quantity, 0))) * NVL (oola.unit_selling_price, 0) + DECODE ('Y', 'Y', NVL (NVL (oola.tax_line_value, oola.tax_value), 0), 0), fc.PRECISION)), 0)), 0) abc
                  INTO pn_open_release_orders
                  FROM apps.oe_order_headers_all ooh, apps.oe_order_lines_all oola, apps.fnd_currencies fc
                 WHERE     ooh.sold_to_org_id = ln_cust_id
                       AND ooh.org_id = pn_org_id
                       AND ooh.open_flag = 'Y'
                       AND ooh.org_id = oola.org_id
                       AND ooh.header_id = oola.header_id
                       AND ooh.transactional_curr_code = fc.currency_code
                       AND oola.flow_status_code IN
                               ('PO_CREATED', 'BOOKED', 'AWAITING_SHIPPING',
                                'AWAITING_RECEIPT', 'INVOICED', 'SUPPLY_ELIGIBLE',
                                'PO_REQ_CREATED', 'PO_OPEN')
                       AND oola.open_flag = 'Y'
                       AND oola.booked_flag = 'Y'
                       AND oola.line_category_code = 'ORDER'     --<> 'RETURN'
                       AND ((oola.schedule_ship_date BETWEEN (SYSDATE) AND (TRUNC (SYSDATE) + ln_horizon_days)) OR (oola.schedule_ship_date < TRUNC (SYSDATE)))
                       AND NOT EXISTS
                               (SELECT 1
                                  FROM apps.oe_order_holds_all oohold, apps.oe_hold_sources_all ohs, apps.oe_hold_definitions ohd
                                 WHERE     oohold.header_id = oola.header_id
                                       --AND NVL (oohold.line_id, oola.line_id) = oola.line_id
                                       AND oohold.hold_source_id =
                                           ohs.hold_source_id
                                       AND ohs.hold_id = ohd.hold_id
                                       AND oohold.released_flag = 'N'
                                       AND ohd.type_code = 'CREDIT');
            EXCEPTION
                WHEN OTHERS
                THEN
                    pn_open_release_orders   := 0;
            END;

            BEGIN
                UPDATE xxd_iex_collectfrm_relorder_t
                   SET open_release_orders   = pn_open_release_orders
                 WHERE     party_id = pn_party_id
                       AND cust_account_id = ln_cust_id
                       AND session_id = pn_session_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END insert_cust_account_release_orders_data;

    PROCEDURE insert_cust_account_release_orders21_data (pn_party_id NUMBER, pn_cust_account_id NUMBER, pn_org_id NUMBER
                                                         , pn_currency_code VARCHAR2, pn_session_id NUMBER)
    AS
        CURSOR cust_cur IS
            SELECT cust_account_id, account_number
              FROM hz_cust_accounts
             WHERE     party_id = pn_party_id
                   AND cust_account_id =
                       NVL (pn_cust_account_id, cust_account_id);

        SUBTYPE cust IS cust_cur%ROWTYPE;

        TYPE custlist IS TABLE OF cust;

        cust_record                      custlist;
        ln_cust_id                       NUMBER;
        ln_credit_rule                   NUMBER;
        ln_horizon_days                  NUMBER;
        pn_open_ar_bal_net               NUMBER;
        pn_open_release_orders           NUMBER;
        ld_prev_year                     DATE := NULL;
        pn_sales_current_ytd             NUMBER;
        pn_sales_prior_year_period_ytd   NUMBER;
        pn_sales_prior_year_ytd          NUMBER;
        pn_highest_credit_amt            NUMBER;
        pd_highest_credit_date           DATE;
        pn_cust_acct_credit_limit        NUMBER;
        pn_open_release_orders_g21       NUMBER;
        ln_order_onhold                  NUMBER;
    BEGIN
        BEGIN
            SELECT ffv.attribute1
              INTO ln_credit_rule
              FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values ffv
             WHERE     ffvs.flex_value_set_id = ffv.flex_value_set_id
                   AND ffvs.flex_value_set_name =
                       'XXD_OU_CREDIT_RULE_MAPPING'
                   AND ffv.value_category = 'XXD_OU_CREDIT_RULE_MAPPING'
                   AND NVL (ffv.enabled_flag, 'Y') = 'Y'
                   AND SYSDATE BETWEEN NVL (ffv.start_date_active, SYSDATE)
                                   AND NVL (ffv.end_date_active, SYSDATE)
                   AND flex_value = pn_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_credit_rule   := 0;
        END;

        IF ln_credit_rule IS NOT NULL AND NVL (ln_credit_rule, 0) <> 0
        THEN
            BEGIN
                SELECT shipping_interval
                  INTO ln_horizon_days
                  FROM apps.oe_credit_check_rules
                 WHERE credit_check_rule_id = ln_credit_rule;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_horizon_days   := 21;
            END;
        ELSE
            ln_horizon_days   := 21;
        END IF;

        OPEN cust_cur;

        FETCH cust_cur BULK COLLECT INTO cust_record;

        CLOSE cust_cur;

        FOR cust_rec IN cust_record.FIRST .. cust_record.LAST
        LOOP
            ln_cust_id                       := cust_record (cust_rec).cust_account_id;
            pn_open_ar_bal_net               := NULL;
            pn_open_release_orders           := NULL;
            pn_sales_current_ytd             := NULL;
            pn_sales_prior_year_period_ytd   := NULL;
            pn_sales_prior_year_ytd          := NULL;
            pn_highest_credit_amt            := NULL;
            pd_highest_credit_date           := NULL;
            pn_cust_acct_credit_limit        := NULL;
            pn_open_release_orders_g21       := NULL;
            ln_order_onhold                  := NULL;

            BEGIN
                SELECT NVL (SUM (NVL ((ROUND ((oola.ordered_quantity - NVL (oola.shipped_quantity, NVL (oola.fulfilled_quantity, 0))) * NVL (oola.unit_selling_price, 0) + DECODE ('Y', 'Y', NVL (NVL (oola.tax_line_value, oola.tax_value), 0), 0), fc.PRECISION)), 0)), 0) abc
                  INTO pn_open_release_orders_g21
                  FROM apps.oe_order_headers_all ooh, apps.oe_order_lines_all oola, apps.fnd_currencies fc
                 WHERE     ooh.sold_to_org_id = ln_cust_id
                       AND ooh.org_id = pn_org_id
                       AND ooh.org_id = oola.org_id
                       AND ooh.header_id = oola.header_id
                       AND ooh.transactional_curr_code = fc.currency_code
                       AND oola.flow_status_code IN
                               ('PO_CREATED', 'BOOKED', 'AWAITING_SHIPPING',
                                'AWAITING_RECEIPT', 'INVOICED', 'SUPPLY_ELIGIBLE',
                                'PO_REQ_CREATED', 'PO_OPEN')
                       AND ooh.open_flag = 'Y'
                       AND oola.open_flag = 'Y'
                       AND oola.booked_flag = 'Y'
                       AND oola.line_category_code = 'ORDER'     --<> 'RETURN'
                       AND (oola.schedule_ship_date IS NULL OR (oola.schedule_ship_date > (TRUNC (SYSDATE) + ln_horizon_days)))
                       AND NOT EXISTS
                               (SELECT 1
                                  FROM apps.oe_order_holds_all oohold, apps.oe_hold_sources_all ohs, apps.oe_hold_definitions ohd
                                 WHERE     oohold.header_id = oola.header_id
                                       --AND NVL (oohold.line_id, oola.line_id) = oola.line_id
                                       AND oohold.hold_source_id =
                                           ohs.hold_source_id
                                       AND ohs.hold_id = ohd.hold_id
                                       AND oohold.released_flag = 'N'
                                       AND ohd.type_code = 'CREDIT');
            EXCEPTION
                WHEN OTHERS
                THEN
                    pn_open_release_orders_g21   := 0;
            END;

            BEGIN
                UPDATE xxd_iex_collectfrm_relorder_t
                   SET open_release_orders_g21   = pn_open_release_orders_g21
                 WHERE     party_id = pn_party_id
                       AND cust_account_id = ln_cust_id
                       AND session_id = pn_session_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END insert_cust_account_release_orders21_data;

    PROCEDURE insert_cust_account_order_value_data (pn_party_id NUMBER, pn_cust_account_id NUMBER, pn_org_id NUMBER
                                                    , pn_currency_code VARCHAR2, pn_session_id NUMBER)
    AS
        CURSOR cust_cur IS
            SELECT cust_account_id, account_number
              FROM hz_cust_accounts
             WHERE     party_id = pn_party_id
                   AND cust_account_id =
                       NVL (pn_cust_account_id, cust_account_id);

        ln_order_tot_value   NUMBER;
        ln_sihp_tot_value    NUMBER;

        SUBTYPE cust IS cust_cur%ROWTYPE;

        TYPE custlist IS TABLE OF cust;

        cust_record          custlist;
        ln_cust_id           NUMBER;
        gn_user_id           NUMBER := fnd_global.user_id;
    BEGIN
        OPEN cust_cur;

        FETCH cust_cur BULK COLLECT INTO cust_record;

        CLOSE cust_cur;

        FOR cust_rec IN cust_record.FIRST .. cust_record.LAST
        LOOP
            ln_cust_id   := cust_record (cust_rec).cust_account_id;

            BEGIN
                SELECT SUM (ROUND ((oola.unit_selling_price * oola.pricing_quantity) + NVL (oola.tax_line_value, 0), fc.PRECISION)) abc
                  INTO ln_order_tot_value
                  FROM oe_order_headers_all ooha, oe_order_lines_all oola, fnd_currencies fc
                 WHERE     ooha.sold_to_org_id = ln_cust_id
                       AND ooha.org_id = pn_org_id
                       AND ooha.creation_date >=
                           ADD_MONTHS (TRUNC (SYSDATE, 'month'), -12)
                       AND ooha.creation_date < TRUNC (SYSDATE - 1)
                       AND ooha.header_id = oola.header_id
                       AND ooha.org_id = oola.org_id
                       AND oola.flow_status_code NOT IN
                               ('RETURNED', 'CANCELLED')
                       AND oola.line_category_code = 'ORDER'
                       AND fc.currency_code = ooha.transactional_curr_code;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_order_tot_value   := 0;
            END;

            BEGIN
                INSERT INTO xxd_iex_collectfrm_orderval_t
                     VALUES (pn_party_id, ln_cust_id, ln_cust_id,
                             ln_order_tot_value, pn_session_id, SYSDATE,
                             gn_user_id, SYSDATE, gn_user_id--,ln_sihp_tot_value
                                                            );
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END insert_cust_account_order_value_data;

    PROCEDURE insert_cust_account_ship_value_data (pn_party_id NUMBER, pn_cust_account_id NUMBER, pn_org_id NUMBER
                                                   , pn_currency_code VARCHAR2, pn_session_id NUMBER)
    AS
        CURSOR cust_cur IS
            SELECT cust_account_id, account_number
              FROM hz_cust_accounts
             WHERE     party_id = pn_party_id
                   AND cust_account_id =
                       NVL (pn_cust_account_id, cust_account_id);

        ln_order_tot_value   NUMBER;
        ln_sihp_tot_value    NUMBER;

        SUBTYPE cust IS cust_cur%ROWTYPE;

        TYPE custlist IS TABLE OF cust;

        cust_record          custlist;
        ln_cust_id           NUMBER;
        gn_user_id           NUMBER := fnd_global.user_id;
    BEGIN
        OPEN cust_cur;

        FETCH cust_cur BULK COLLECT INTO cust_record;

        CLOSE cust_cur;

        FOR cust_rec IN cust_record.FIRST .. cust_record.LAST
        LOOP
            ln_cust_id   := cust_record (cust_rec).cust_account_id;

            BEGIN
                SELECT SUM (ROUND ((oola.unit_selling_price * oola.pricing_quantity) + NVL (oola.tax_line_value, 0), fc.PRECISION)) abc
                  INTO ln_sihp_tot_value
                  FROM oe_order_headers_all ooha, oe_order_lines_all oola, fnd_currencies fc
                 WHERE     ooha.sold_to_org_id = ln_cust_id
                       AND ooha.org_id = pn_org_id
                       AND ooha.creation_date >=
                           ADD_MONTHS (TRUNC (SYSDATE, 'month'), -12)
                       AND ooha.creation_date < TRUNC (SYSDATE - 1)
                       AND ooha.header_id = oola.header_id
                       AND ooha.org_id = oola.org_id
                       AND oola.flow_status_code IN ('SHIPPED', 'CLOSED')
                       AND oola.line_category_code = 'ORDER'
                       AND fc.currency_code = ooha.transactional_curr_code;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_sihp_tot_value   := 0;
            END;

            BEGIN
                INSERT INTO xxd_iex_collectfrm_shipval_t
                     VALUES (pn_party_id, ln_cust_id, ln_cust_id--,ln_order_tot_value
                                                                ,
                             ln_sihp_tot_value, pn_session_id, SYSDATE,
                             gn_user_id, SYSDATE, gn_user_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END insert_cust_account_ship_value_data;

    PROCEDURE insert_cust_account_tot_order_value_data (pn_party_id NUMBER, pn_cust_account_id NUMBER, pn_org_id NUMBER
                                                        , pn_currency_code VARCHAR2, pn_session_id NUMBER)
    AS
        CURSOR cust_cur IS
            SELECT cust_account_id, account_number
              FROM hz_cust_accounts
             WHERE     party_id = pn_party_id
                   AND cust_account_id =
                       NVL (pn_cust_account_id, cust_account_id);

        ln_order_tot_value   NUMBER;
        ln_sihp_tot_value    NUMBER;

        SUBTYPE cust IS cust_cur%ROWTYPE;

        TYPE custlist IS TABLE OF cust;

        cust_record          custlist;
        ln_cust_id           NUMBER;
        gn_user_id           NUMBER := fnd_global.user_id;
    BEGIN
        OPEN cust_cur;

        FETCH cust_cur BULK COLLECT INTO cust_record;

        CLOSE cust_cur;

        FOR cust_rec IN cust_record.FIRST .. cust_record.LAST
        LOOP
            ln_cust_id   := cust_record (cust_rec).cust_account_id;

            BEGIN
                SELECT SUM (ROUND ((oola.unit_selling_price * oola.pricing_quantity) + NVL (oola.tax_line_value, 0), fc.PRECISION)) abc
                  INTO ln_order_tot_value
                  FROM oe_order_headers_all ooha, oe_order_lines_all oola, fnd_currencies fc
                 WHERE     ooha.sold_to_org_id = ln_cust_id
                       AND ooha.org_id = pn_org_id
                       AND ooha.header_id = oola.header_id
                       AND ooha.org_id = oola.org_id
                       AND oola.flow_status_code NOT IN
                               ('RETURNED', 'CANCELLED')
                       AND oola.line_category_code = 'ORDER'
                       AND fc.currency_code = ooha.transactional_curr_code;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_order_tot_value   := 0;
            END;

            BEGIN
                INSERT INTO xxdo.xxd_iex_collfrm_ordtot_val_t
                     VALUES (pn_party_id, ln_cust_id, ln_cust_id,
                             ln_order_tot_value, pn_session_id, SYSDATE,
                             gn_user_id, SYSDATE, gn_user_id--,ln_sihp_tot_value
                                                            );
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END insert_cust_account_tot_order_value_data;

    PROCEDURE insert_cust_account_tot_ship_value_data (pn_party_id NUMBER, pn_cust_account_id NUMBER, pn_org_id NUMBER
                                                       , pn_currency_code VARCHAR2, pn_session_id NUMBER)
    AS
        CURSOR cust_cur IS
            SELECT cust_account_id, account_number
              FROM hz_cust_accounts
             WHERE     party_id = pn_party_id
                   AND cust_account_id =
                       NVL (pn_cust_account_id, cust_account_id);

        ln_order_tot_value   NUMBER;
        ln_sihp_tot_value    NUMBER;

        SUBTYPE cust IS cust_cur%ROWTYPE;

        TYPE custlist IS TABLE OF cust;

        cust_record          custlist;
        ln_cust_id           NUMBER;
        gn_user_id           NUMBER := fnd_global.user_id;
    BEGIN
        OPEN cust_cur;

        FETCH cust_cur BULK COLLECT INTO cust_record;

        CLOSE cust_cur;

        FOR cust_rec IN cust_record.FIRST .. cust_record.LAST
        LOOP
            ln_cust_id   := cust_record (cust_rec).cust_account_id;

            BEGIN
                SELECT SUM (ROUND ((oola.unit_selling_price * oola.pricing_quantity) + NVL (oola.tax_line_value, 0), fc.PRECISION)) abc
                  INTO ln_sihp_tot_value
                  FROM oe_order_headers_all ooha, oe_order_lines_all oola, fnd_currencies fc
                 WHERE     ooha.sold_to_org_id = ln_cust_id
                       AND ooha.org_id = pn_org_id
                       AND ooha.header_id = oola.header_id
                       AND ooha.org_id = oola.org_id
                       AND oola.flow_status_code IN ('SHIPPED', 'CLOSED')
                       AND oola.line_category_code = 'ORDER'
                       AND fc.currency_code = ooha.transactional_curr_code;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_sihp_tot_value   := 0;
            END;

            BEGIN
                INSERT INTO xxd_iex_collfrm_shiptot_val_t
                     VALUES (pn_party_id, ln_cust_id, ln_cust_id--,ln_order_tot_value
                                                                ,
                             ln_sihp_tot_value, pn_session_id, SYSDATE,
                             gn_user_id, SYSDATE, gn_user_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END insert_cust_account_tot_ship_value_data;

    PROCEDURE submit_job (pn_party_id NUMBER, pn_cust_account_id NUMBER, pn_org_id NUMBER
                          , pn_currency_code VARCHAR2, pn_session_id NUMBER)
    IS
        ln_job1        NUMBER;
        ln_count       NUMBER := 0;
        ln_count_job   NUMBER := 0;
        gn_user_id     NUMBER := fnd_global.user_id;
    BEGIN
        BEGIN
            DELETE FROM xxd_iex_collect_form_party_t
                  WHERE session_id = pn_session_id;

            DELETE FROM xxdo.xxd_iex_collectfrm_custacct_t
                  WHERE session_id = pn_session_id;

            DELETE FROM xxdo.xxd_iex_collectfrm_relorder_t
                  WHERE session_id = pn_session_id;

            DELETE FROM xxdo.xxd_iex_collectfrm_orderval_t
                  WHERE session_id = pn_session_id;

            DELETE FROM xxdo.xxd_iex_collectfrm_shipval_t
                  WHERE session_id = pn_session_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        BEGIN
            BEGIN
                SELECT COUNT (*)
                  INTO ln_count_job
                  FROM dba_jobs
                 WHERE job IN
                           (SELECT job_id
                              FROM xxd_iex_collect_form_job_id_t
                             WHERE     procedure_name IN
                                           ('insert_cust_account_tot_ship_value_data', 'insert_cust_account_tot_order_value_data')
                                   AND party_id = pn_party_id
                                   AND cust_account_id IS NULL
                                   AND session_id = pn_session_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_count_job   := 0;
            END;

            IF ln_count_job = 0 AND pn_cust_account_id IS NOT NULL
            THEN
                BEGIN
                    SELECT COUNT (*)
                      INTO ln_count_job
                      FROM dba_jobs
                     WHERE job IN
                               (SELECT job_id
                                  FROM xxd_iex_collect_form_job_id_t
                                 WHERE     procedure_name IN
                                               ('insert_cust_account_tot_ship_value_data', 'insert_cust_account_tot_order_value_data')
                                       AND party_id = pn_party_id
                                       AND cust_account_id =
                                           pn_cust_account_id
                                       AND session_id = pn_session_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_count_job   := 0;
                END;
            END IF;

            IF ln_count_job = 0
            THEN
                BEGIN
                    DELETE FROM xxdo.xxd_iex_collect_form_job_id_t
                          WHERE session_id = pn_session_id;

                    DELETE FROM xxdo.xxd_iex_collfrm_ordtot_val_t
                          WHERE session_id = pn_session_id;

                    DELETE FROM xxdo.xxd_iex_collfrm_shiptot_val_t
                          WHERE session_id = pn_session_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;
            END IF;
        END;

        BEGIN
            INSERT INTO xxd_iex_collect_form_party_t
                 VALUES (pn_party_id, '', '',
                         '', '', '',
                         '', '', '',
                         '', pn_session_id, SYSDATE,
                         gn_user_id, SYSDATE, gn_user_id);

            INSERT INTO xxd_iex_collectfrm_relorder_t
                (SELECT party_id, cust_account_id, account_number,
                        '', '', pn_session_id,
                        SYSDATE, gn_user_id, SYSDATE,
                        gn_user_id
                   FROM hz_cust_accounts
                  WHERE     party_id = pn_party_id
                        AND cust_account_id =
                            NVL (pn_cust_account_id, cust_account_id));

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        IF pn_cust_account_id IS NULL
        THEN
            DBMS_JOB.submit (
                ln_job1,
                   ' 
    begin
      xxd_iex_collection_form_pkg.insert_party_data('
                || pn_party_id
                || ','
                || ''''
                || ''''
                || ','
                || pn_org_id
                || ','
                || ''''
                || pn_currency_code
                || ''''
                || ','
                || pn_session_id
                || '); end; ');

            BEGIN
                INSERT INTO xxd_iex_collect_form_job_id_t
                     VALUES ('insert_party_data', ln_job1, pn_party_id,
                             pn_cust_account_id, pn_session_id, SYSDATE,
                             gn_user_id, SYSDATE, gn_user_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            COMMIT;
            DBMS_JOB.submit (
                ln_job1,
                   ' 
    begin
      xxd_iex_collection_form_pkg.insert_cust_account_data('
                || pn_party_id
                || ','
                || ''''
                || ''''
                || ','
                || pn_org_id
                || ','
                || ''''
                || pn_currency_code
                || ''''
                || ','
                || pn_session_id
                || '); end; ');

            BEGIN
                INSERT INTO xxd_iex_collect_form_job_id_t
                     VALUES ('insert_cust_account_data', ln_job1, pn_party_id, pn_cust_account_id, pn_session_id, SYSDATE
                             , gn_user_id, SYSDATE, gn_user_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            COMMIT;
            DBMS_JOB.submit (
                ln_job1,
                   ' 
    begin
      xxd_iex_collection_form_pkg.insert_cust_account_sales_ytd_data('
                || pn_party_id
                || ','
                || ''''
                || ''''
                || ','
                || pn_org_id
                || ','
                || ''''
                || pn_currency_code
                || ''''
                || ','
                || pn_session_id
                || '); end; ');

            BEGIN
                INSERT INTO xxd_iex_collect_form_job_id_t
                     VALUES ('insert_cust_account_sales_ytd_data', ln_job1, pn_party_id, pn_cust_account_id, pn_session_id, SYSDATE
                             , gn_user_id, SYSDATE, gn_user_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            COMMIT;
            DBMS_JOB.submit (
                ln_job1,
                   ' 
    begin
      xxd_iex_collection_form_pkg.insert_cust_account_sales_prevytd_data('
                || pn_party_id
                || ','
                || ''''
                || ''''
                || ','
                || pn_org_id
                || ','
                || ''''
                || pn_currency_code
                || ''''
                || ','
                || pn_session_id
                || '); end; ');

            BEGIN
                INSERT INTO xxd_iex_collect_form_job_id_t
                     VALUES ('insert_cust_account_sales_prevytd_data', ln_job1, pn_party_id, pn_cust_account_id, pn_session_id, SYSDATE
                             , gn_user_id, SYSDATE, gn_user_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            COMMIT;
            DBMS_JOB.submit (
                ln_job1,
                   ' 
    begin
      xxd_iex_collection_form_pkg.insert_cust_account_sales_prev_data('
                || pn_party_id
                || ','
                || ''''
                || ''''
                || ','
                || pn_org_id
                || ','
                || ''''
                || pn_currency_code
                || ''''
                || ','
                || pn_session_id
                || '); end; ');

            BEGIN
                INSERT INTO xxd_iex_collect_form_job_id_t
                     VALUES ('insert_cust_account_sales_prev_data', ln_job1, pn_party_id, pn_cust_account_id, pn_session_id, SYSDATE
                             , gn_user_id, SYSDATE, gn_user_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            COMMIT;
            DBMS_JOB.submit (
                ln_job1,
                   ' 
    begin
      xxd_iex_collection_form_pkg.insert_cust_account_release_orders_data('
                || pn_party_id
                || ','
                || ''''
                || ''''
                || ','
                || pn_org_id
                || ','
                || ''''
                || pn_currency_code
                || ''''
                || ','
                || pn_session_id
                || '); end; ');

            BEGIN
                INSERT INTO xxd_iex_collect_form_job_id_t
                     VALUES ('insert_cust_account_release_orders_data', ln_job1, pn_party_id, pn_cust_account_id, pn_session_id, SYSDATE
                             , gn_user_id, SYSDATE, gn_user_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            COMMIT;
            DBMS_JOB.submit (
                ln_job1,
                   ' 
    begin
      xxd_iex_collection_form_pkg.insert_cust_account_release_orders21_data('
                || pn_party_id
                || ','
                || ''''
                || ''''
                || ','
                || pn_org_id
                || ','
                || ''''
                || pn_currency_code
                || ''''
                || ','
                || pn_session_id
                || '); end; ');

            BEGIN
                INSERT INTO xxd_iex_collect_form_job_id_t
                     VALUES ('insert_cust_account_release_orders21_data', ln_job1, pn_party_id, pn_cust_account_id, pn_session_id, SYSDATE
                             , gn_user_id, SYSDATE, gn_user_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            COMMIT;
            DBMS_JOB.submit (
                ln_job1,
                   ' 
    begin
      xxd_iex_collection_form_pkg.insert_cust_account_order_value_data('
                || pn_party_id
                || ','
                || ''''
                || ''''
                || ','
                || pn_org_id
                || ','
                || ''''
                || pn_currency_code
                || ''''
                || ','
                || pn_session_id
                || '); end; ');

            BEGIN
                INSERT INTO xxd_iex_collect_form_job_id_t
                     VALUES ('insert_cust_account_order_value_data', ln_job1, pn_party_id, pn_cust_account_id, pn_session_id, SYSDATE
                             , gn_user_id, SYSDATE, gn_user_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            COMMIT;
            DBMS_JOB.submit (
                ln_job1,
                   ' 
    begin
      xxd_iex_collection_form_pkg.insert_cust_account_ship_value_data('
                || pn_party_id
                || ','
                || ''''
                || ''''
                || ','
                || pn_org_id
                || ','
                || ''''
                || pn_currency_code
                || ''''
                || ','
                || pn_session_id
                || '); end; ');

            BEGIN
                INSERT INTO xxd_iex_collect_form_job_id_t
                     VALUES ('insert_cust_account_ship_value_data', ln_job1, pn_party_id, pn_cust_account_id, pn_session_id, SYSDATE
                             , gn_user_id, SYSDATE, gn_user_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            COMMIT;

            IF ln_count_job = 0
            THEN
                DBMS_JOB.submit (
                    ln_job1,
                       ' 
    begin
      xxd_iex_collection_form_pkg.insert_cust_account_tot_order_value_data('
                    || pn_party_id
                    || ','
                    || ''''
                    || ''''
                    || ','
                    || pn_org_id
                    || ','
                    || ''''
                    || pn_currency_code
                    || ''''
                    || ','
                    || pn_session_id
                    || '); end; ');

                BEGIN
                    INSERT INTO xxd_iex_collect_form_job_id_t
                         VALUES ('insert_cust_account_tot_order_value_data', ln_job1, pn_party_id, pn_cust_account_id, pn_session_id, SYSDATE
                                 , gn_user_id, SYSDATE, gn_user_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;

                COMMIT;
                DBMS_JOB.submit (
                    ln_job1,
                       ' 
    begin
      xxd_iex_collection_form_pkg.insert_cust_account_tot_ship_value_data('
                    || pn_party_id
                    || ','
                    || ''''
                    || ''''
                    || ','
                    || pn_org_id
                    || ','
                    || ''''
                    || pn_currency_code
                    || ''''
                    || ','
                    || pn_session_id
                    || '); end; ');

                BEGIN
                    INSERT INTO xxd_iex_collect_form_job_id_t
                         VALUES ('insert_cust_account_tot_ship_value_data', ln_job1, pn_party_id, pn_cust_account_id, pn_session_id, SYSDATE
                                 , gn_user_id, SYSDATE, gn_user_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;

                COMMIT;
            END IF;

            LOOP
                ln_count   := 0;

                BEGIN
                    SELECT COUNT (*)
                      INTO ln_count
                      FROM dba_jobs
                     WHERE job IN
                               (SELECT job_id
                                  FROM xxd_iex_collect_form_job_id_t
                                 WHERE     procedure_name NOT IN
                                               ('insert_cust_account_tot_ship_value_data', 'insert_cust_account_tot_order_value_data')
                                       AND session_id = pn_session_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_count   := 0;
                END;

                DBMS_LOCK.sleep (5);
                EXIT WHEN ln_count = 0;
            END LOOP;
        END IF;

        IF pn_cust_account_id IS NOT NULL
        THEN
            DBMS_JOB.submit (
                ln_job1,
                   ' 
    begin
      xxd_iex_collection_form_pkg.insert_party_data('
                || pn_party_id
                || ','
                || pn_cust_account_id
                || ','
                || pn_org_id
                || ','
                || ''''
                || pn_currency_code
                || ''''
                || ','
                || pn_session_id
                || '); end; ');

            BEGIN
                INSERT INTO xxd_iex_collect_form_job_id_t
                     VALUES ('insert_party_data', ln_job1, pn_party_id,
                             pn_cust_account_id, pn_session_id, SYSDATE,
                             gn_user_id, SYSDATE, gn_user_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            COMMIT;
            DBMS_JOB.submit (
                ln_job1,
                   ' 
    begin
      xxd_iex_collection_form_pkg.insert_cust_account_data('
                || pn_party_id
                || ','
                || pn_cust_account_id
                || ','
                || pn_org_id
                || ','
                || ''''
                || pn_currency_code
                || ''''
                || ','
                || pn_session_id
                || '); end; ');

            BEGIN
                INSERT INTO xxd_iex_collect_form_job_id_t
                     VALUES ('insert_cust_account_data', ln_job1, pn_party_id, pn_cust_account_id, pn_session_id, SYSDATE
                             , gn_user_id, SYSDATE, gn_user_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            COMMIT;
            DBMS_JOB.submit (
                ln_job1,
                   ' 
    begin
      xxd_iex_collection_form_pkg.insert_cust_account_sales_ytd_data('
                || pn_party_id
                || ','
                || pn_cust_account_id
                || ','
                || pn_org_id
                || ','
                || ''''
                || pn_currency_code
                || ''''
                || ','
                || pn_session_id
                || '); end; ');

            BEGIN
                INSERT INTO xxd_iex_collect_form_job_id_t
                     VALUES ('insert_cust_account_sales_ytd_data', ln_job1, pn_party_id, pn_cust_account_id, pn_session_id, SYSDATE
                             , gn_user_id, SYSDATE, gn_user_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            COMMIT;
            DBMS_JOB.submit (
                ln_job1,
                   ' 
    begin
      xxd_iex_collection_form_pkg.insert_cust_account_sales_prevytd_data('
                || pn_party_id
                || ','
                || pn_cust_account_id
                || ','
                || pn_org_id
                || ','
                || ''''
                || pn_currency_code
                || ''''
                || ','
                || pn_session_id
                || '); end; ');

            BEGIN
                INSERT INTO xxd_iex_collect_form_job_id_t
                     VALUES ('insert_cust_account_sales_prevytd_data', ln_job1, pn_party_id, pn_cust_account_id, pn_session_id, SYSDATE
                             , gn_user_id, SYSDATE, gn_user_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            COMMIT;
            DBMS_JOB.submit (
                ln_job1,
                   ' 
    begin
      xxd_iex_collection_form_pkg.insert_cust_account_sales_prev_data('
                || pn_party_id
                || ','
                || pn_cust_account_id
                || ','
                || pn_org_id
                || ','
                || ''''
                || pn_currency_code
                || ''''
                || ','
                || pn_session_id
                || '); end; ');

            BEGIN
                INSERT INTO xxd_iex_collect_form_job_id_t
                     VALUES ('insert_cust_account_sales_prev_data', ln_job1, pn_party_id, pn_cust_account_id, pn_session_id, SYSDATE
                             , gn_user_id, SYSDATE, gn_user_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            COMMIT;
            DBMS_JOB.submit (
                ln_job1,
                   ' 
    begin
      xxd_iex_collection_form_pkg.insert_cust_account_release_orders_data('
                || pn_party_id
                || ','
                || pn_cust_account_id
                || ','
                || pn_org_id
                || ','
                || ''''
                || pn_currency_code
                || ''''
                || ','
                || pn_session_id
                || '); end; ');

            BEGIN
                INSERT INTO xxd_iex_collect_form_job_id_t
                     VALUES ('insert_cust_account_release_orders_data', ln_job1, pn_party_id, pn_cust_account_id, pn_session_id, SYSDATE
                             , gn_user_id, SYSDATE, gn_user_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            COMMIT;
            DBMS_JOB.submit (
                ln_job1,
                   ' 
    begin
      xxd_iex_collection_form_pkg.insert_cust_account_release_orders21_data('
                || pn_party_id
                || ','
                || pn_cust_account_id
                || ','
                || pn_org_id
                || ','
                || ''''
                || pn_currency_code
                || ''''
                || ','
                || pn_session_id
                || '); end; ');

            BEGIN
                INSERT INTO xxd_iex_collect_form_job_id_t
                     VALUES ('insert_cust_account_release_orders21_data', ln_job1, pn_party_id, pn_cust_account_id, pn_session_id, SYSDATE
                             , gn_user_id, SYSDATE, gn_user_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            COMMIT;
            DBMS_JOB.submit (
                ln_job1,
                   ' 
    begin
      xxd_iex_collection_form_pkg.insert_cust_account_order_value_data('
                || pn_party_id
                || ','
                || pn_cust_account_id
                || ','
                || pn_org_id
                || ','
                || ''''
                || pn_currency_code
                || ''''
                || ','
                || pn_session_id
                || '); end; ');

            BEGIN
                INSERT INTO xxd_iex_collect_form_job_id_t
                     VALUES ('insert_cust_account_order_value_data', ln_job1, pn_party_id, pn_cust_account_id, pn_session_id, SYSDATE
                             , gn_user_id, SYSDATE, gn_user_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            COMMIT;
            DBMS_JOB.submit (
                ln_job1,
                   ' 
    begin
      xxd_iex_collection_form_pkg.insert_cust_account_ship_value_data('
                || pn_party_id
                || ','
                || pn_cust_account_id
                || ','
                || pn_org_id
                || ','
                || ''''
                || pn_currency_code
                || ''''
                || ','
                || pn_session_id
                || '); end; ');

            BEGIN
                INSERT INTO xxd_iex_collect_form_job_id_t
                     VALUES ('insert_cust_account_ship_value_data', ln_job1, pn_party_id, pn_cust_account_id, pn_session_id, SYSDATE
                             , gn_user_id, SYSDATE, gn_user_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            COMMIT;

            IF ln_count_job = 0
            THEN
                DBMS_JOB.submit (
                    ln_job1,
                       ' 
    begin
      xxd_iex_collection_form_pkg.insert_cust_account_tot_order_value_data('
                    || pn_party_id
                    || ','
                    || pn_cust_account_id
                    || ','
                    || pn_org_id
                    || ','
                    || ''''
                    || pn_currency_code
                    || ''''
                    || ','
                    || pn_session_id
                    || '); end; ');

                BEGIN
                    INSERT INTO xxd_iex_collect_form_job_id_t
                         VALUES ('insert_cust_account_tot_order_value_data', ln_job1, pn_party_id, pn_cust_account_id, pn_session_id, SYSDATE
                                 , gn_user_id, SYSDATE, gn_user_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;

                COMMIT;
                DBMS_JOB.submit (
                    ln_job1,
                       ' 
    begin
      xxd_iex_collection_form_pkg.insert_cust_account_tot_ship_value_data('
                    || pn_party_id
                    || ','
                    || pn_cust_account_id
                    || ','
                    || pn_org_id
                    || ','
                    || ''''
                    || pn_currency_code
                    || ''''
                    || ','
                    || pn_session_id
                    || '); end; ');

                BEGIN
                    INSERT INTO xxd_iex_collect_form_job_id_t
                         VALUES ('insert_cust_account_tot_ship_value_data', ln_job1, pn_party_id, pn_cust_account_id, pn_session_id, SYSDATE
                                 , gn_user_id, SYSDATE, gn_user_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;

                COMMIT;
            END IF;

            -- COMMIT;
            LOOP
                ln_count   := 0;

                BEGIN
                    SELECT COUNT (*)
                      INTO ln_count
                      FROM dba_jobs
                     WHERE job IN
                               (SELECT job_id
                                  FROM xxd_iex_collect_form_job_id_t
                                 WHERE     procedure_name NOT IN
                                               ('insert_cust_account_tot_ship_value_data', 'insert_cust_account_tot_order_value_data')
                                       AND session_id = pn_session_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_count   := 0;
                END;

                DBMS_LOCK.sleep (1);
                EXIT WHEN ln_count = 0;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END submit_job;

    PROCEDURE check_job_completion (pn_session_id     NUMBER,
                                    pn_party_id       NUMBER,
                                    pn_cust_acct_id   NUMBER)
    IS
        ln_count   NUMBER := 0;
    BEGIN
        LOOP
            ln_count   := 0;

            BEGIN
                SELECT COUNT (*)
                  INTO ln_count
                  FROM dba_jobs
                 WHERE job IN
                           (SELECT job_id
                              FROM xxd_iex_collect_form_job_id_t
                             WHERE     procedure_name IN
                                           ('insert_cust_account_tot_ship_value_data', 'insert_cust_account_tot_order_value_data')
                                   AND session_id = pn_session_id
                                   AND party_id = pn_party_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_count   := 0;
            END;

            DBMS_LOCK.sleep (2);
            EXIT WHEN ln_count = 0;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END check_job_completion;

    PROCEDURE purge_staging_tables (x_retcode      OUT NOCOPY VARCHAR2,
                                    x_errbuf       OUT NOCOPY VARCHAR2)
    IS
    BEGIN
        BEGIN
            DELETE FROM
                xxd_iex_collectfrm_custacct_t
                  WHERE creation_date <
                          SYSDATE
                        - NVL (
                              fnd_profile.VALUE (
                                  'XXD_IEX_PURG_COLLECT_FRM_STG'),
                              2);
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        BEGIN
            DELETE FROM
                xxd_iex_collectfrm_orderval_t
                  WHERE creation_date <
                          SYSDATE
                        - NVL (
                              fnd_profile.VALUE (
                                  'XXD_IEX_PURG_COLLECT_FRM_STG'),
                              2);
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        BEGIN
            DELETE FROM
                xxd_iex_collectfrm_shipval_t
                  WHERE creation_date <
                          SYSDATE
                        - NVL (
                              fnd_profile.VALUE (
                                  'XXD_IEX_PURG_COLLECT_FRM_STG'),
                              2);
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        BEGIN
            DELETE FROM
                xxd_iex_collfrm_ordtot_val_t
                  WHERE creation_date <
                          SYSDATE
                        - NVL (
                              fnd_profile.VALUE (
                                  'XXD_IEX_PURG_COLLECT_FRM_STG'),
                              2);
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        BEGIN
            DELETE FROM
                xxd_iex_collfrm_shiptot_val_t
                  WHERE creation_date <
                          SYSDATE
                        - NVL (
                              fnd_profile.VALUE (
                                  'XXD_IEX_PURG_COLLECT_FRM_STG'),
                              2);
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        BEGIN
            DELETE FROM
                xxd_iex_collect_form_party_t
                  WHERE creation_date <
                          SYSDATE
                        - NVL (
                              fnd_profile.VALUE (
                                  'XXD_IEX_PURG_COLLECT_FRM_STG'),
                              2);
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        BEGIN
            DELETE FROM
                xxd_iex_collectfrm_relorder_t
                  WHERE creation_date <
                          SYSDATE
                        - NVL (
                              fnd_profile.VALUE (
                                  'XXD_IEX_PURG_COLLECT_FRM_STG'),
                              2);
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        BEGIN
            DELETE FROM
                xxd_iex_collect_form_job_id_t
                  WHERE creation_date <
                          SYSDATE
                        - NVL (
                              fnd_profile.VALUE (
                                  'XXD_IEX_PURG_COLLECT_FRM_STG'),
                              2);
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            x_retcode   := '2';
            x_errbuf    := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                'OTHERS Exception in purge_staging_tables:' || x_errbuf);
    END;
END;
/
