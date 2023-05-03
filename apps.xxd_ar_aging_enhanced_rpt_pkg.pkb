--
-- XXD_AR_AGING_ENHANCED_RPT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:38 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AR_AGING_ENHANCED_RPT_PKG"
AS
    --  ####################################################################################################
    --  Package      : XXD_AR_AGING_ENHANCED_RPT_PKG
    --  Design       : This package provides XML extract for Receivables Enhance Aging Report.
    --  Notes        :
    --  Modification :
    --  ======================================================================================
    --  Date            Version#   Name                    Comments
    --  ======================================================================================
    --  05-Apr-2017     1.0        Deckers IT Team          Intial Version 1.0
    --  27-Apr-2017     1.1        Prakash Vangari          CCR0006140
    --  23-Jan-2018     1.2        Infosys                  ENHC0013499 - CCR0006871
    --  05-APR-2019     1.3        Gaurav Joshi             Updated for CCR0007823
    --  05-Jun-2020     1.4        Showkath Ali             Updated for CCR0008685
    --  27-Oct-2021     1.5        Laltu Sah                Updated for CCR0009092
    --  ####################################################################################################
    PROCEDURE LOG (pv_msgtxt_in IN VARCHAR2)
    IS
    BEGIN
        IF fnd_global.conc_login_id = -1
        THEN
            DBMS_OUTPUT.put_line (pv_msgtxt_in);
        --         fnd_file.put_line (fnd_file.LOG, pv_msgtxt_in);
        ELSE
            fnd_file.put_line (fnd_file.LOG, pv_msgtxt_in);
        END IF;
    END LOG;

    -- +---------------------------------------------+
    -- | Procedure to print messages or notes in the |
    -- | OUTPUT file of the concurrent program       |
    -- +---------------------------------------------+

    PROCEDURE output (pv_msgtxt_in IN VARCHAR2)
    IS
    BEGIN
        IF fnd_global.conc_login_id = -1
        THEN
            DBMS_OUTPUT.put_line (pv_msgtxt_in);
        ELSE
            fnd_file.put_line (fnd_file.output, pv_msgtxt_in);
        END IF;
    END output;

    FUNCTION remove_junk_characters (pv_msg_tx_in IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_corrected_value   VARCHAR2 (4000);
    BEGIN
        lv_corrected_value   :=
            TRANSLATE (
                TRANSLATE (
                    REGEXP_REPLACE (LTRIM (RTRIM (pv_msg_tx_in)),
                                    '([^[:graph:] | ^[:blank:]])',
                                    ' '),
                    CHR (10),
                    ' '),
                CHR (9),
                ' ');

        RETURN lv_corrected_value;
    EXCEPTION
        WHEN OTHERS
        THEN
            -- LOG ('Error while removing special / junk characters' || SQLERRM);
            RETURN NULL;
    END;

    -- CCR0006140

    FUNCTION get_bucket_desc (pn_aging_bucket_id   IN NUMBER,
                              pn_bucket_seq_num    IN NUMBER)
        RETURN VARCHAR2
    IS
        l_desc   VARCHAR2 (240);
    BEGIN
        SELECT report_heading1
          INTO l_desc
          FROM apps.ar_aging_bucket_lines aabl
         WHERE     1 = 1
               AND aabl.aging_bucket_id = pn_aging_bucket_id
               AND aabl.bucket_sequence_num = pn_bucket_seq_num;

        RETURN l_desc;
    EXCEPTION
        WHEN OTHERS
        THEN
            -- LOG ('Unable to get_bucket_desc ' || SQLERRM);
            RETURN NULL;
    END;

    -- CCR0006140

    FUNCTION return_credit_limit (pv_summary_detail_level VARCHAR2, pn_party_id NUMBER, pn_customer_id NUMBER)
        RETURN NUMBER
    IS
        ln_credit_limit   NUMBER := 0;
    BEGIN
        IF pv_summary_detail_level = 'Party'
        THEN
            BEGIN
                SELECT overall_credit_limit
                  INTO ln_credit_limit
                  FROM hz_customer_profiles hcp, xxd_ra_customers_v xrc, hz_cust_profile_amts hcpa
                 WHERE     1 = 1
                       AND hcp.party_id = xrc.party_id
                       AND hcp.cust_account_profile_id =
                           hcpa.cust_account_profile_id
                       AND hcp.cust_account_id = -1 --xrc.customer_id Modified by Madhav
                       AND hcp.site_use_id IS NULL           --Added by Madhav
                       AND xrc.party_id = pn_party_id
                       AND xrc.attribute1 = 'ALL BRAND';
            EXCEPTION
                WHEN OTHERS
                THEN
                    -- LOG ('Error while fetching credit limit for party : ' || TO_CHAR(pn_party_id) || SQLERRM);
                    RETURN NULL;
            END;
        ELSIF pv_summary_detail_level = 'Account'
        THEN
            --overall credit limit @ customer account level
            BEGIN
                SELECT overall_credit_limit
                  INTO ln_credit_limit
                  FROM hz_customer_profiles hcp, xxd_ra_customers_v xrc, hz_cust_profile_amts hcpa
                 WHERE     1 = 1
                       AND hcp.party_id = xrc.party_id
                       AND hcp.cust_account_profile_id =
                           hcpa.cust_account_profile_id
                       AND hcp.cust_account_id = xrc.customer_id
                       AND hcp.site_use_id IS NULL           --Added by Madhav
                       AND xrc.customer_id = pn_customer_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    -- LOG ('Error while fetching credit limit for account : ' || TO_CHAR(pn_customer_id) || SQLERRM);
                    RETURN NULL;
            END;
        END IF;

        RETURN ln_credit_limit;
    EXCEPTION
        WHEN OTHERS
        THEN
            -- LOG ('Error while fetching credit limit' || SQLERRM);
            RETURN NULL;
    END;

    FUNCTION return_collector (pv_summary_detail_level VARCHAR2, pn_party_id NUMBER, pn_customer_id NUMBER)
        RETURN VARCHAR2
    IS
        lv_collector   VARCHAR2 (150) := '';
    BEGIN
        IF NVL (pv_summary_detail_level, 'N') = 'Party'
        THEN
            --Collector @ Party level
            BEGIN
                SELECT RTRIM (XMLAGG (XMLELEMENT (e, ac.name || ',')).EXTRACT ('//text()'), ',') ---- Added by Infosys for ENHC0013499
                           --ac.NAME   -- Commented by Infosys for ENHC0013499
                  INTO lv_collector
                  FROM hz_customer_profiles hcp, xxd_ra_customers_v xrc, --hz_cust_profile_amts hcpa,
                                                                         ar_collectors ac
                 WHERE     1 = 1
                       AND hcp.party_id = xrc.party_id
                       --AND hcp.cust_account_profile_id = hcpa.cust_account_profile_id
                       --  AND hcp.cust_account_id = -1 --xrc.customer_id Modified by Madhav -- Commented by Infosys for ENHC0013499
                       AND hcp.collector_id = ac.collector_id
                       AND hcp.site_use_id IS NULL           --Added by Madhav
                       AND xrc.customer_id = hcp.cust_account_id -- Added by Infosys for ENHC0013499
                       AND xrc.attribute1 = 'ALL BRAND'
                       AND hcp.party_id = pn_party_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    -- LOG ('Unable to collector for party : ' || TO_CHAR(pn_party_id) || SQLERRM);
                    RETURN NULL;
            END;
        --      ELSIF PV_SUMMARY_DETAIL_LEVEL = 'Account'
        --      THEN
        -- LOG ('The value of lv_collector in if:' || lv_collector);
        ELSE
            --overall credit limit @ customer account level
            BEGIN
                SELECT ac.name
                  INTO lv_collector
                  FROM hz_customer_profiles hcp, xxd_ra_customers_v xrc, --hz_cust_profile_amts hcpa,
                                                                         ar_collectors ac
                 WHERE     1 = 1
                       AND hcp.party_id = xrc.party_id
                       --AND hcp.cust_account_profile_id = hcpa.cust_account_profile_id
                       AND hcp.cust_account_id = xrc.customer_id
                       AND hcp.collector_id = ac.collector_id
                       AND hcp.site_use_id IS NULL
                       AND xrc.customer_id = pn_customer_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    -- LOG ('Unable to collector for account : ' || TO_CHAR(pn_customer_id) || SQLERRM);
                    RETURN NULL;
            END;
        END IF;

        -- LOG ('The value of lv_collector in else:' || lv_collector);

        RETURN lv_collector;
    EXCEPTION
        WHEN OTHERS
        THEN
            -- LOG ('Error while fetching lv_collector' || SQLERRM);
            RETURN NULL;
    END;

    FUNCTION return_credit_analyst (pv_summary_detail_level VARCHAR2, pn_party_id NUMBER, pn_customer_id NUMBER)
        RETURN VARCHAR2
    IS
        lv_credit_analyst   VARCHAR2 (200) := '';
    BEGIN
        IF NVL (pv_summary_detail_level, 'N') = 'Party'
        THEN
            -- Credit Analyst @ Party Level
            SELECT jrd.resource_name
              INTO lv_credit_analyst
              FROM hz_customer_profiles hcp, xxd_ra_customers_v xrc, jtf_rs_defresources_vl jrd
             WHERE     1 = 1
                   AND hcp.party_id = xrc.party_id
                   AND hcp.credit_analyst_id = jrd.resource_id
                   AND hcp.cust_account_id = -1 --xrc.customer_id Modified by Madhav
                   AND hcp.site_use_id IS NULL               --Added by Madhav
                   AND xrc.party_id = pn_party_id
                   AND xrc.attribute1 = 'ALL BRAND';
        --      ELSIF PV_SUMMARY_DETAIL_LEVEL = 'Account'
        --      THEN

        ELSE
            -- Credit Analyst @ Account Level
            SELECT jrd.resource_name
              INTO lv_credit_analyst
              FROM hz_customer_profiles hcp, xxd_ra_customers_v xrc, jtf_rs_defresources_vl jrd
             WHERE     1 = 1
                   AND hcp.party_id = xrc.party_id
                   AND hcp.credit_analyst_id = jrd.resource_id
                   AND hcp.cust_account_id = xrc.customer_id
                   AND hcp.site_use_id IS NULL               --Added by Madhav
                   AND xrc.customer_id = pn_customer_id;
        END IF;

        RETURN lv_credit_analyst;
    EXCEPTION
        WHEN OTHERS
        THEN
            -- LOG ('Error while fetching credit analyst' || SQLERRM);
            RETURN NULL;
    END;

    FUNCTION return_chargeback_analyst (pv_summary_detail_level VARCHAR2, pn_party_id NUMBER, pn_customer_id NUMBER)
        RETURN VARCHAR2
    IS
        lv_chargeback_analyst   VARCHAR2 (150) := '';
    BEGIN
        IF NVL (pv_summary_detail_level, 'N') = 'Party'
        THEN
            -- Chargeback Analyst @ Party Level
            SELECT jrd.resource_name
              INTO lv_chargeback_analyst
              FROM hz_parties hp, xxd_ra_customers_v xrc, jtf_rs_resource_extns_vl jrd
             WHERE     1 = 1
                   AND hp.party_id = xrc.party_id
                   AND hp.attribute9 = TO_CHAR (jrd.resource_id)
                   AND hp.party_id = xrc.party_id
                   AND xrc.party_id = pn_party_id
                   AND xrc.attribute1 = 'ALL BRAND';
        --      ELSIF PV_SUMMARY_DETAIL_LEVEL = 'Account'
        --      THEN

        ELSE
            --overall credit limit @ customer account level
            SELECT jrd.resource_name
              INTO lv_chargeback_analyst
              FROM hz_parties hp, xxd_ra_customers_v xrc, jtf_rs_resource_extns_vl jrd
             WHERE     1 = 1
                   AND hp.party_id = xrc.party_id
                   AND hp.attribute9 = TO_CHAR (jrd.resource_id)
                   AND hp.party_id = xrc.party_id
                   AND xrc.customer_id = pn_customer_id;
        END IF;

        RETURN lv_chargeback_analyst;
    EXCEPTION
        WHEN OTHERS
        THEN
            -- LOG ('Error while fetching chargeback Analyst' || SQLERRM);
            RETURN NULL;
    END;

    FUNCTION return_profile_class (pv_summary_detail_level VARCHAR2, pn_party_id NUMBER, pn_customer_id NUMBER)
        RETURN VARCHAR2
    IS
        lv_profile_class   VARCHAR2 (200) := '';
    BEGIN
        IF pv_summary_detail_level = 'Account'
        THEN
            --overall credit limit @ customer account level
            --Profile Class @ Customer Account Level -- Party Level it should be null
            SELECT hcpc.name
              INTO lv_profile_class
              FROM hz_customer_profiles hcp, xxd_ra_customers_v xrc, hz_cust_profile_classes hcpc
             WHERE     1 = 1
                   AND hcp.party_id = xrc.party_id
                   AND hcp.profile_class_id = hcpc.profile_class_id
                   AND hcp.cust_account_id = xrc.customer_id
                   AND hcp.site_use_id IS NULL               --Added by Madhav
                   AND xrc.customer_id = pn_customer_id;
        ELSE
            SELECT hcpc.name
              INTO lv_profile_class
              FROM hz_customer_profiles hcp, xxd_ra_customers_v xrc, hz_cust_profile_classes hcpc
             WHERE     1 = 1
                   AND hcp.party_id = xrc.party_id
                   AND hcp.profile_class_id = hcpc.profile_class_id
                   AND hcp.cust_account_id = -1 --xrc.customer_id Modified by Madhav
                   AND hcp.site_use_id IS NULL               --Added by Madhav
                   AND xrc.customer_id = pn_customer_id;
        END IF;

        RETURN lv_profile_class;
    EXCEPTION
        WHEN OTHERS
        THEN
            -- LOG ('Error while fetching profile class' || SQLERRM);
            RETURN NULL;
    END;

    -- CCR0006140

    FUNCTION get_balance_due_as_of_date (p_applied_payment_schedule_id IN NUMBER, p_as_of_date IN DATE, p_class IN VARCHAR2
                                         , pn_operating_unit NUMBER)
        RETURN NUMBER
    IS
        p_amount_applied       NUMBER;
        /*Bug 2453245 */
        p_adj_amount_applied   NUMBER;
        p_actual_amount        NUMBER;
        p_amt_due_original     NUMBER;
        /* Bug 2610716 */
        p_cm_amount_applied    NUMBER;
    BEGIN
        SELECT NVL (SUM (NVL (amount_applied, 0) + NVL (earned_discount_taken, 0) + NVL (unearned_discount_taken, 0)), 0)
          INTO p_amount_applied
          FROM ar_receivable_applications_all
         WHERE     applied_payment_schedule_id =
                   p_applied_payment_schedule_id
               AND org_id = NVL (pn_operating_unit, org_id)
               AND status = 'APP'
               AND NVL (confirmed_flag, 'Y') = 'Y'
               AND apply_date <= p_as_of_date;

        /* Added the  query to take care of On-Account CM applications Bug 2610716*/

        IF p_class = 'CM'
        THEN
            SELECT NVL (SUM (amount_applied), 0)
              INTO p_cm_amount_applied
              FROM ar_receivable_applications_all
             WHERE     payment_schedule_id = p_applied_payment_schedule_id
                   AND org_id = NVL (pn_operating_unit, org_id)
                   AND apply_date <= p_as_of_date;
        END IF;

        /* Bug 2453245 Added the query to retrieve the Adjustment
           Amount applied to the Invoice */

        SELECT NVL (SUM (amount), 0)
          INTO p_adj_amount_applied
          FROM ar_adjustments_all
         WHERE     payment_schedule_id = p_applied_payment_schedule_id
               AND org_id = NVL (pn_operating_unit, org_id)
               AND status = 'A'
               AND apply_date <= p_as_of_date;

        SELECT amount_due_original
          INTO p_amt_due_original
          FROM ar_payment_schedules_all
         WHERE     payment_schedule_id = p_applied_payment_schedule_id
               AND org_id = NVL (pn_operating_unit, org_id);

        /*Bug 2453245 Added p_adj_amount_applied so that
         Adjustment amount is also taken into account while
         computing the Balance */
        /* bug4085823: Added nvl for p_cm_amount_applied */

        p_actual_amount   :=
              p_amt_due_original
            + p_adj_amount_applied
            - p_amount_applied
            + NVL (p_cm_amount_applied, 0);
        RETURN (p_actual_amount);
    EXCEPTION
        /* bug3544286 added NO_DATA_FOUND */
        WHEN NO_DATA_FOUND
        THEN
            RETURN (NULL);
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_balance_due_as_of_date;

    --1.4 changes start
    -- Function to get resource number

    FUNCTION get_resource_number (p_resource_id   IN NUMBER,
                                  p_namenum       IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_resource_name     jtf_rs_resource_extns_tl.resource_name%TYPE;
        lv_resource_number   jtf_rs_resource_extns.resource_number%TYPE;
    BEGIN
        IF p_namenum = 'NUM'
        THEN
            BEGIN
                SELECT resource_number
                  INTO lv_resource_number
                  FROM jtf_rs_resource_extns
                 WHERE resource_id = p_resource_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_resource_number   := NULL;
            END;

            RETURN lv_resource_number;
        ELSE
            BEGIN
                SELECT resource_name
                  INTO lv_resource_name
                  FROM jtf_rs_resource_extns_tl
                 WHERE resource_id = p_resource_id AND language = 'US';
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_resource_name   := NULL;
            END;

            RETURN lv_resource_name;
        END IF;
    END get_resource_number;

    -- 1.4 changes end

    -- CCR0006140

    FUNCTION beforereport
        RETURN BOOLEAN
    AS
        l_index                 NUMBER := 0;
        dml_errors              EXCEPTION;
        PRAGMA EXCEPTION_INIT (dml_errors, -24381);
        lv_err_msg              VARCHAR2 (1000);
        l_error_index           NUMBER := 0;
        ld_as_of_date           DATE := fnd_date.canonical_to_date (pv_as_of_date);
        lv_all_aging_buckets    VARCHAR2 (2000);
        -- CCR0006140
        l_aging_bucket1         NUMBER;                -- added for CCR0006140
        l_aging_bucket2         NUMBER;                -- added for CCR0006140
        l_aging_bucket3         NUMBER;                -- added for CCR0006140
        l_aging_bucket4         NUMBER;                -- added for CCR0006140
        l_aging_bucket5         NUMBER;                -- added for CCR0006140
        l_aging_bucket6         NUMBER;                -- added for CCR0006140
        l_days_start_from       NUMBER;
        l_days_start_to         NUMBER;
        l_comm_req_id           NUMBER := 9999999999;

        -- CCR0006140
        TYPE t_ar_aging_rpt_gt_rec
            IS RECORD
        (
            brand                          xxd_ar_aging_report_gt.brand%TYPE,
            org_name                       xxd_ar_aging_report_gt.org_name%TYPE,
            account_number                 xxd_ar_aging_report_gt.account_number%TYPE,
            customer_number                xxd_ar_aging_report_gt.customer_number%TYPE,
            customer_name                  xxd_ar_aging_report_gt.customer_name%TYPE,
            cust_address1                  xxd_ar_aging_report_gt.cust_address1%TYPE,
            cust_state                     xxd_ar_aging_report_gt.cust_state%TYPE,
            cust_zip                       xxd_ar_aging_report_gt.cust_zip%TYPE,
            collector                      xxd_ar_aging_report_gt.collector%TYPE,
            credit_analyst                 xxd_ar_aging_report_gt.credit_analyst%TYPE,
            chargeback_analyst             xxd_ar_aging_report_gt.chargeback_analyst%TYPE,
            profile_class                  xxd_ar_aging_report_gt.profile_class%TYPE,
            overall_credit_limit           xxd_ar_aging_report_gt.overall_credit_limit%TYPE,
            TYPE                           xxd_ar_aging_report_gt.TYPE%TYPE,
            transaction_name               xxd_ar_aging_report_gt.transaction_name%TYPE,
            term                           xxd_ar_aging_report_gt.term%TYPE,
            description                    xxd_ar_aging_report_gt.description%TYPE,
            invoice_currency_code          xxd_ar_aging_report_gt.invoice_currency_code%TYPE,
            due_date                       xxd_ar_aging_report_gt.due_date%TYPE,
            gl_date                        xxd_ar_aging_report_gt.gl_date%TYPE,
            payment_schedule_id            xxd_ar_aging_report_gt.payment_schedule_id%TYPE,
            class                          xxd_ar_aging_report_gt.class%TYPE,
            trx_rcpt_number                xxd_ar_aging_report_gt.trx_rcpt_number%TYPE,
            interface_header_attribute1    xxd_ar_aging_report_gt.interface_header_attribute1%TYPE,
            purchase_order                 xxd_ar_aging_report_gt.purchase_order%TYPE,
            salesrep_number                xxd_ar_aging_report_gt.salesrep_number%TYPE, --1.4
            salesrep_name                  xxd_ar_aging_report_gt.salesrep_name%TYPE,
            trx_date                       xxd_ar_aging_report_gt.trx_date%TYPE,
            amount_due_original            xxd_ar_aging_report_gt.amount_due_original%TYPE,
            amount_applied                 xxd_ar_aging_report_gt.amount_applied%TYPE,
            amount_adjusted                xxd_ar_aging_report_gt.amount_adjusted%TYPE,
            --         STATUS                        XXD_AR_AGING_REPORT_GT.STATUS%TYPE,
            amount_credited                xxd_ar_aging_report_gt.amount_credited%TYPE,
            --         REASON_CODE                   XXD_AR_AGING_REPORT_GT.REASON_CODE%TYPE,
            amount_in_dispute              xxd_ar_aging_report_gt.amount_in_dispute%TYPE,
            --1.4 changes start
            sales_channel_code             xxd_ar_aging_report_gt.sales_channel%TYPE,
            customer_class_code            xxd_ar_aging_report_gt.cust_classification%TYPE,
            payment_terms                  xxd_ar_aging_report_gt.payment_terms%TYPE,
            --1.4 changes end
            amount_due                     xxd_ar_aging_report_gt.amount_due%TYPE,
            days_past_due                  xxd_ar_aging_report_gt.days_past_due%TYPE,
            --         AGING_REPORT_HEADING1         XXD_AR_AGING_REPORT_GT.AGING_REPORT_HEADING1%TYPE,
            --         AGING_REPORT_HEADING2         XXD_AR_AGING_REPORT_GT.AGING_REPORT_HEADING2%TYPE
            --         AGING_BUCKET_NAME             VARCHAR2 (60)
            -- CCR0006140
            aging_bucket1                  xxd_ar_aging_report_gt.aging_bucket1%TYPE,
            aging_bucket2                  xxd_ar_aging_report_gt.aging_bucket2%TYPE,
            aging_bucket3                  xxd_ar_aging_report_gt.aging_bucket3%TYPE,
            aging_bucket4                  xxd_ar_aging_report_gt.aging_bucket4%TYPE,
            aging_bucket5                  xxd_ar_aging_report_gt.aging_bucket5%TYPE,
            aging_bucket6                  xxd_ar_aging_report_gt.aging_bucket6%TYPE
        -- CCR0006140
        );

        TYPE t_ar_aging_rpt_gt_tab_typ IS TABLE OF t_ar_aging_rpt_gt_rec
            INDEX BY BINARY_INTEGER;

        t_ar_aging_rpt_gt_tab   t_ar_aging_rpt_gt_tab_typ;

        CURSOR cur_aging_buckets IS
              SELECT days_start days_start, days_to days_to, report_heading1,
                     report_heading2, bucket_sequence_num
                FROM ar_aging_bucket_lines
               WHERE 1 = 1 AND aging_bucket_id = pn_aging_bucket_id
            --AND TYPE <> 'DISPUTE_ONLY'
            ORDER BY bucket_sequence_num;

        CURSOR cur_aging_details (pn_days_from NUMBER, pn_days_to NUMBER)
        IS
            /*---------- 1 ------------*/
            SELECT brand, org_name, account_number,
                   party_number, customer_name, cust_address1,
                   cust_state, cust_zip, collector,
                   credit_analyst, chargeback_analyst, profile_class,
                   credit_limit, TYPE name, TYPE transaction_name,
                   NULL term, description, invoice_currency_code,
                   due_date, NULL gl_date, payment_schedule_id,
                   class, trx_rcpt_number, interface_header_attribute1,
                   purchase_order, salesrep_number, salesrep_name,
                   trx_date, 0 amount_due_original, 0 amount_applied,
                   0 amount_adjusted, 0 amount_credited, 0 amount_in_dispute,
                   --1.4 changes start
                   sales_channel_code, customer_class_code, payment_terms,
                   --1.4 changes end
                   NVL (NVL (x.ara_amount, 0), 0) amount_due, ((TO_DATE (ld_as_of_date, 'DD-MON-YY')) - due_date) days_past_due, NULL,
                   NULL, NULL, NULL,
                   NULL, NULL
              FROM (SELECT hca.attribute1
                               brand,
                           hrou.name
                               AS org_name,
                           rac.customer_number
                               account_number,
                           (SELECT ('''' || TO_CHAR (RTRIM (XMLAGG (XMLELEMENT (e, account_number || ',')).EXTRACT ('//text()'), ',')))
                              FROM apps.hz_cust_accounts_all
                             WHERE     party_id = rac.party_id
                                   AND attribute1 = 'ALL BRAND'
                                   AND status = 'A')
                               party_number, --Added for  ENHC0013499 - CCR0006871
                           --rac.party_number, --commented for  ENHC0013499 - CCR0006871
                           rac.customer_name,
                           NVL (raa.address1, '-')
                               cust_address1,
                           NVL (raa.state, '-')
                               cust_state,
                           NVL (raa.postal_code, '-')
                               cust_zip,
                           xxd_ar_aging_enhanced_rpt_pkg.return_collector (
                               pv_summary_detail_level,
                               rac.party_id,
                               rac.customer_id)
                               collector,
                           xxd_ar_aging_enhanced_rpt_pkg.return_credit_analyst (
                               pv_summary_detail_level,
                               rac.party_id,
                               rac.customer_id)
                               credit_analyst,
                           xxd_ar_aging_enhanced_rpt_pkg.return_chargeback_analyst (
                               pv_summary_detail_level,
                               rac.party_id,
                               rac.customer_id)
                               chargeback_analyst,
                           xxd_ar_aging_enhanced_rpt_pkg.return_profile_class (
                               pv_summary_detail_level,
                               rac.party_id,
                               rac.customer_id)
                               profile_class,
                           xxd_ar_aging_enhanced_rpt_pkg.return_credit_limit (
                               pv_summary_detail_level,
                               rac.party_id,
                               rac.customer_id)
                               credit_limit,
                           cta.trx_number
                               trx_rcpt_number,
                           rtt.TYPE,
                           rtt.name
                               transaction_name,
                           cta.interface_header_attribute1
                               interface_header_attribute1,
                           cta.purchase_order,
                           -- 1.4 changes start
                           -- rep.salesrep_number,
                           --rep.NAME AS salesrep_name,
                           xxd_ar_aging_enhanced_rpt_pkg.get_resource_number (
                               rep.resource_id,
                               'NUM')
                               salesrep_number,
                           xxd_ar_aging_enhanced_rpt_pkg.get_resource_number (
                               rep.resource_id,
                               'NAME')
                               salesrep_name,
                           --1.4 changes end
                           cta.trx_date,
                           pt.name
                               term,
                           pt.description,
                           sched.due_date,
                           sched.payment_schedule_id,
                           sched.amount_due_original,
                           sched.amount_applied,
                           sched.amount_adjusted,
                           sched.amount_in_dispute,
                           sched.amount_credited,
                           cta.reason_code
                               AS reason_code,
                           ac.name
                               collectr,
                           sched.invoice_currency_code,
                           sched.class
                               class,
                           sched.exchange_rate,
                           (  SELECT NVL (SUM (-NVL (app.amount_applied_from, app.amount_applied + NVL (earned_discount_taken, 0) + NVL (unearned_discount_taken, 0))), 0) ara_amount
                                FROM ar_receivable_applications_all app
                               WHERE     1 = 1
                                     AND app.status = 'APP'
                                     AND app.gl_date <=
                                         (TO_DATE (ld_as_of_date, 'DD-MON-YY'))
                                     AND app.applied_payment_schedule_id =
                                         sched.payment_schedule_id
                            GROUP BY app.applied_payment_schedule_id)
                               ara_amount,
                           --1.4 changes start
                           hca.sales_channel_code,
                           hca.customer_class_code,
                           pt.name
                               payment_terms
                      --1.4 changes end
                      FROM ar.ar_payment_schedules_all sched, apps.xxd_ra_customers_v rac, apps.ra_cust_trx_types_all rtt,
                           apps.ra_customer_trx_all cta, ar.hz_customer_profiles cp, ar.ar_collectors ac,
                           apps.ra_terms_tl pt, jtf.jtf_rs_salesreps rep, apps.xle_le_ou_ledger_v xlol,
                           apps.hr_operating_units hrou, apps.xxd_ra_addresses_morg_v raa, apps.hz_cust_accounts hca
                     WHERE     pt.term_id(+) = cta.term_id
                           AND 1 = 1
                           AND hca.attribute1 =
                               NVL (pv_brand, hca.attribute1)
                           AND ac.collector_id =
                               NVL (pn_collector_id, ac.collector_id)
                           AND pt.language(+) = USERENV ('LANG')
                           AND rac.customer_id = cta.bill_to_customer_id
                           AND rtt.cust_trx_type_id = cta.cust_trx_type_id
                           AND rtt.org_id = cta.org_id
                           AND rep.salesrep_id(+) = cta.primary_salesrep_id
                           AND rep.org_id(+) = cta.org_id
                           AND cp.cust_account_id = cta.bill_to_customer_id
                           AND cp.site_use_id IS NULL
                           AND ac.collector_id = cp.collector_id
                           AND cta.bill_to_customer_id = hca.cust_account_id
                           AND sched.org_id = cta.org_id
                           AND sched.customer_trx_id = cta.customer_trx_id
                           AND hrou.organization_id = cta.org_id
                           --AND sched.org_id = hrou.organization_id --Comment for CCR0009092
                           AND xlol.operating_unit_id = hrou.organization_id
                           AND raa.customer_id = cta.bill_to_customer_id
                           AND raa.org_id = cta.org_id
                           AND raa.bill_to_flag = 'P'
                           AND raa.status = 'A'
                           AND sched.class <> 'PMT'
                           AND xlol.legal_entity_id =
                               hrou.default_legal_context_id
                           AND xlol.operating_unit_id IN
                                   (SELECT organization_id
                                      FROM hr_operating_units
                                     WHERE name IN
                                               (SELECT ffv.flex_value
                                                  FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
                                                 WHERE     ffvs.flex_value_set_id =
                                                           ffv.flex_value_set_id
                                                       AND flex_value_set_name =
                                                           'XXDO_REGION_BASED_OU'
                                                       AND parent_flex_value_low =
                                                           NVL (
                                                               pn_region,
                                                               parent_flex_value_low)
                                                       AND flex_value =
                                                           NVL (
                                                               pn_operating_unit,
                                                               flex_value)
                                                       AND (pn_ex_ecomm_ous = 'Y' AND UPPER (ffv.flex_value) NOT LIKE '%ECOMM%' OR pn_ex_ecomm_ous = 'N' AND ffv.flex_value = ffv.flex_value OR pn_ex_ecomm_ous IS NULL AND ffv.flex_value = ffv.flex_value)
                                                       AND ffv.enabled_flag =
                                                           'Y')) -- Added by Infosys for ENHC0013499 - CCR0006871
                           /* =
                                  NVL (TO_NUMBER (pn_operating_unit),
                                       xlol.operating_unit_id
                                      ) */
                           -- Commented by Infosys for ENHC0013499 - CCR0006871
                           AND sched.trx_date <=
                               (TO_DATE (ld_as_of_date, 'DD-MON-YY')) -- Added for P_AS_OF_DATE
                           AND TRUNC (sched.gl_date) <=
                               (TO_DATE (ld_as_of_date, 'DD-MON-YY')) -- Added for P_AS_OF_DATE
                           AND sched.gl_date_closed >
                               TO_DATE (ld_as_of_date, 'DD-MON-YY')
                           AND CEIL (
                                     TO_DATE (ld_as_of_date, 'DD-MON-YY')
                                   - sched.due_date) BETWEEN pn_days_from
                                                         AND pn_days_to
                           AND EXISTS
                                   (SELECT appa.payment_schedule_id
                                      FROM ar_receivable_applications_all appa
                                     WHERE     1 = 1
                                           AND appa.status = 'APP'
                                           AND appa.gl_date <=
                                               (TO_DATE (ld_as_of_date, 'DD-MON-YY'))
                                           AND appa.payment_schedule_id =
                                               sched.payment_schedule_id)) x
            UNION
            /*---------- 2 ------------*/
            SELECT brand, org_name, account_number,
                   party_number, customer_name, cust_address1,
                   cust_state, cust_zip, collector,
                   credit_analyst, chargeback_analyst, profile_class,
                   credit_limit, TYPE name, TYPE transaction_name,
                   NULL term, description, invoice_currency_code,
                   due_date, NULL gl_date, payment_schedule_id,
                   class, trx_rcpt_number, interface_header_attribute1,
                   purchase_order, salesrep_number, salesrep_name,
                   trx_date, NVL (x.amount_due_original, 0) amount_due_original, NVL (amount_applied, 0) amount_applied,
                   NVL (amount_adjusted, 0) amount_adjusted, NVL (amount_credited, 0) amount_credited, NVL (amount_in_dispute, 0) amount_in_dispute,
                   --1.4 changes start
                   sales_channel_code, customer_class_code, payment_terms,
                   --1.4 changes end
                   NVL ((x.amount_due_original + (NVL (NVL (ara_amount, 0) + NVL (adj_amount, 0) + NVL (adj_freight_amount, 0), 0))), 0) amount_due, ((TO_DATE (ld_as_of_date, 'DD-MON-YY')) - due_date) days_past_due, NULL,
                   NULL, NULL, NULL,
                   NULL, NULL
              FROM (SELECT hca.attribute1
                               brand,
                           hrou.name
                               AS org_name,
                           rac.customer_number
                               account_number,
                           (SELECT ('''' || TO_CHAR (RTRIM (XMLAGG (XMLELEMENT (e, account_number || ',')).EXTRACT ('//text()'), ',')))
                              FROM apps.hz_cust_accounts_all
                             WHERE     party_id = rac.party_id
                                   AND attribute1 = 'ALL BRAND'
                                   AND status = 'A')
                               party_number, --Added for  ENHC0013499 - CCR0006871
                           --rac.party_number, --commented for  ENHC0013499 - CCR0006871
                           rac.customer_name,
                           NVL (raa.address1, '-')
                               cust_address1,
                           NVL (raa.state, '-')
                               cust_state,
                           NVL (raa.postal_code, '-')
                               cust_zip,
                           xxd_ar_aging_enhanced_rpt_pkg.return_collector (
                               pv_summary_detail_level,
                               rac.party_id,
                               rac.customer_id)
                               collector,
                           xxd_ar_aging_enhanced_rpt_pkg.return_credit_analyst (
                               pv_summary_detail_level,
                               rac.party_id,
                               rac.customer_id)
                               credit_analyst,
                           xxd_ar_aging_enhanced_rpt_pkg.return_chargeback_analyst (
                               pv_summary_detail_level,
                               rac.party_id,
                               rac.customer_id)
                               chargeback_analyst,
                           xxd_ar_aging_enhanced_rpt_pkg.return_profile_class (
                               pv_summary_detail_level,
                               rac.party_id,
                               rac.customer_id)
                               profile_class,
                           xxd_ar_aging_enhanced_rpt_pkg.return_credit_limit (
                               pv_summary_detail_level,
                               rac.party_id,
                               rac.customer_id)
                               credit_limit,
                           cta.trx_number
                               trx_rcpt_number,
                           rtt.TYPE,
                           cta.interface_header_attribute1
                               interface_header_attribute1,
                           cta.purchase_order,
                           -- 1.4 changes start
                           -- rep.salesrep_number,
                           -- rep.NAME AS salesrep_name,
                           xxd_ar_aging_enhanced_rpt_pkg.get_resource_number (
                               rep.resource_id,
                               'NUM')
                               salesrep_number,
                           xxd_ar_aging_enhanced_rpt_pkg.get_resource_number (
                               rep.resource_id,
                               'NAME')
                               salesrep_name,
                           --1.4 changes end
                           cta.trx_date,
                           pt.description,
                           sched.due_date,
                           sched.payment_schedule_id,
                           sched.amount_due_original,
                           sched.amount_applied,
                           sched.amount_adjusted,
                           sched.amount_in_dispute,
                           sched.amount_credited,
                           cta.reason_code
                               AS reason_code,
                           ac.name
                               collectr,
                           sched.invoice_currency_code,
                           sched.class
                               class,
                           sched.exchange_rate,
                           (  SELECT NVL (SUM (-NVL (app.amount_applied_from, app.amount_applied + NVL (earned_discount_taken, 0) + NVL (unearned_discount_taken, 0))), 0) ara_amount
                                FROM ar_receivable_applications_all app
                               WHERE     1 = 1
                                     AND app.status = 'APP'
                                     AND app.gl_date <=
                                         (TO_DATE (ld_as_of_date, 'DD-MON-YY'))
                                     AND app.applied_payment_schedule_id =
                                         sched.payment_schedule_id
                            GROUP BY app.applied_payment_schedule_id)
                               ara_amount,
                           -- Start changes for CCR0007823
                           -- (SELECT   SUM (NVL (ara.line_adjusted, 0)
                           (  SELECT SUM (NVL (ara.amount, 0)-- End changes for CCR0007823
                                                             ) adj_amount
                                FROM ar.ar_adjustments_all ara
                               WHERE     1 = 1
                                     --AND ara.status = 'APP'
                                     AND ara.status = 'A' -- Added for CCR0007823
                                     AND ara.gl_date <=
                                         (TO_DATE (ld_as_of_date, 'DD-MON-YY'))
                                     AND ara.payment_schedule_id =
                                         sched.payment_schedule_id
                            GROUP BY ara.payment_schedule_id)
                               adj_amount,
                           (  SELECT SUM (NVL (ara.freight_adjusted, 0)) adj_freight_amount
                                FROM ar.ar_adjustments_all ara
                               WHERE     1 = 1
                                     --AND ara.status = 'APP'
                                     AND ara.gl_date <=
                                         (TO_DATE (ld_as_of_date, 'DD-MON-YY'))
                                     AND ara.payment_schedule_id =
                                         sched.payment_schedule_id
                            GROUP BY ara.payment_schedule_id)
                               adj_freight_amount,
                           --1.4 changes start
                           hca.sales_channel_code,
                           hca.customer_class_code,
                           pt.name
                               payment_terms
                      --1.4 changes end
                      FROM ar.ar_payment_schedules_all sched, apps.xxd_ra_customers_v rac, apps.ra_cust_trx_types_all rtt,
                           apps.ra_customer_trx_all cta, ar.hz_customer_profiles cp, ar.ar_collectors ac,
                           apps.ra_terms_tl pt, jtf.jtf_rs_salesreps rep, apps.xle_le_ou_ledger_v xlol,
                           apps.hr_operating_units hrou, apps.xxd_ra_addresses_morg_v raa, apps.hz_cust_accounts hca
                     WHERE     pt.term_id(+) = cta.term_id
                           AND 1 = 1
                           AND hca.attribute1 =
                               NVL (pv_brand, hca.attribute1)
                           AND ac.collector_id =
                               NVL (pn_collector_id, ac.collector_id)
                           AND pt.language(+) = USERENV ('LANG')
                           AND rac.customer_id = cta.bill_to_customer_id
                           AND rtt.cust_trx_type_id = cta.cust_trx_type_id
                           AND rtt.org_id = cta.org_id
                           AND rep.salesrep_id(+) = cta.primary_salesrep_id
                           AND rep.org_id(+) = cta.org_id
                           AND cp.cust_account_id = cta.bill_to_customer_id
                           AND cp.site_use_id IS NULL
                           AND ac.collector_id = cp.collector_id
                           AND cta.bill_to_customer_id = hca.cust_account_id
                           AND sched.org_id = cta.org_id
                           AND sched.customer_trx_id = cta.customer_trx_id
                           AND hrou.organization_id = cta.org_id
                           --AND sched.class             = NVL (P_CLASS, sched.class)
                           --AND sched.org_id = hrou.organization_id --Comment for CCR0009092
                           AND xlol.operating_unit_id = hrou.organization_id
                           AND raa.customer_id = cta.bill_to_customer_id
                           AND raa.org_id = cta.org_id
                           AND raa.bill_to_flag = 'P'
                           AND raa.status = 'A'
                           AND sched.class <> 'PMT'
                           AND xlol.legal_entity_id =
                               hrou.default_legal_context_id
                           AND xlol.operating_unit_id IN
                                   (SELECT organization_id
                                      FROM hr_operating_units
                                     WHERE name IN
                                               (SELECT ffv.flex_value
                                                  FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
                                                 WHERE     ffvs.flex_value_set_id =
                                                           ffv.flex_value_set_id
                                                       AND flex_value_set_name =
                                                           'XXDO_REGION_BASED_OU'
                                                       AND parent_flex_value_low =
                                                           NVL (
                                                               pn_region,
                                                               parent_flex_value_low)
                                                       AND flex_value =
                                                           NVL (
                                                               pn_operating_unit,
                                                               flex_value)
                                                       AND (pn_ex_ecomm_ous = 'Y' AND UPPER (ffv.flex_value) NOT LIKE '%ECOMM%' OR pn_ex_ecomm_ous = 'N' AND ffv.flex_value = ffv.flex_value OR pn_ex_ecomm_ous IS NULL AND ffv.flex_value = ffv.flex_value)
                                                       AND ffv.enabled_flag =
                                                           'Y')) -- Added by Infosys for ENHC0013499 - CCR0006871
                           /*=
                                    NVL (pn_operating_unit, xlol.operating_unit_id) */
                            -- Commented by Infosys for ENHC0013499 - CCR0006871
                           AND sched.trx_date <=
                               (TO_DATE (ld_as_of_date, 'DD-MON-YY')) -- Added for P_AS_OF_DATE
                           AND TRUNC (sched.gl_date) <=
                               (TO_DATE (ld_as_of_date, 'DD-MON-YY')) -- Added for P_AS_OF_DATE
                           AND sched.gl_date_closed >
                               TO_DATE (ld_as_of_date, 'DD-MON-YY')
                           AND CEIL (
                                     TO_DATE (ld_as_of_date, 'DD-MON-YY')
                                   - sched.due_date) BETWEEN pn_days_from
                                                         AND pn_days_to
                           AND NOT EXISTS
                                   (SELECT appa.payment_schedule_id
                                      FROM ar_receivable_applications_all appa
                                     WHERE     1 = 1
                                           AND appa.status = 'APP'
                                           AND appa.gl_date <=
                                               (TO_DATE (ld_as_of_date, 'DD-MON-YY'))
                                           AND appa.payment_schedule_id =
                                               sched.payment_schedule_id)) x
            UNION
            /*---------- 3 ------------*/
            SELECT hca.attribute1
                       brand,
                   hrou.name
                       AS org_name,
                   rac.customer_number
                       account_number,
                   (SELECT ('''' || TO_CHAR (RTRIM (XMLAGG (XMLELEMENT (e, account_number || ',')).EXTRACT ('//text()'), ',')))
                      FROM apps.hz_cust_accounts_all
                     WHERE     party_id = rac.party_id
                           AND attribute1 = 'ALL BRAND'
                           AND status = 'A')
                       party_number,     --Added for  ENHC0013499 - CCR0006871
                   --rac.party_number, --commented for  ENHC0013499 - CCR0006871
                   rac.customer_name,
                   NVL (raa.address1, '-')
                       cust_address1,
                   NVL (raa.state, '-')
                       cust_state,
                   NVL (raa.postal_code, '-')
                       cust_zip,
                   xxd_ar_aging_enhanced_rpt_pkg.return_collector (
                       pv_summary_detail_level,
                       rac.party_id,
                       rac.customer_id)
                       collector,
                   xxd_ar_aging_enhanced_rpt_pkg.return_credit_analyst (
                       pv_summary_detail_level,
                       rac.party_id,
                       rac.customer_id)
                       credit_analyst,
                   xxd_ar_aging_enhanced_rpt_pkg.return_chargeback_analyst (
                       pv_summary_detail_level,
                       rac.party_id,
                       rac.customer_id)
                       chargeback_analyst,
                   xxd_ar_aging_enhanced_rpt_pkg.return_profile_class (
                       pv_summary_detail_level,
                       rac.party_id,
                       rac.customer_id)
                       profile_class,
                   xxd_ar_aging_enhanced_rpt_pkg.return_credit_limit (
                       pv_summary_detail_level,
                       rac.party_id,
                       rac.customer_id)
                       credit_limit,
                   rtt.TYPE
                       name,
                   rtt.TYPE
                       transaction_name,
                   NULL
                       term,
                   pt.description,
                   sched.invoice_currency_code,
                   sched.due_date,
                   NULL
                       gl_date,
                   sched.payment_schedule_id,
                   sched.class
                       class,
                   cta.trx_number
                       trx_rcpt_number,
                   cta.interface_header_attribute1
                       interface_header_attribute1,
                   cta.purchase_order,
                   --1.4 changes start
                   --rep.salesrep_number,
                   --rep.NAME AS salesrep_name,
                   xxd_ar_aging_enhanced_rpt_pkg.get_resource_number (
                       rep.resource_id,
                       'NUM')
                       salesrep_number,
                   xxd_ar_aging_enhanced_rpt_pkg.get_resource_number (
                       rep.resource_id,
                       'NAME')
                       salesrep_name,
                   -- 1.4 changes end
                   cta.trx_date,
                   NVL (sched.amount_due_original, 0)
                       amount_due_original,
                   NVL (sched.amount_applied, 0)
                       amount_applied,
                   NVL (sched.amount_adjusted, 0)
                       amount_adjusted,
                   NVL (sched.amount_credited, 0)
                       amount_credited,
                   NVL (NVL (sched.amount_in_dispute, 0), 0)
                       amount_in_dispute,
                   --1.4 changes start
                   hca.sales_channel_code,
                   hca.customer_class_code,
                   pt.name
                       payment_terms,
                   --1.4 changes end
                   -- Adding below, amount_adjusted for amount_due for CCR0007823
                   NVL (
                         sched.amount_due_original
                       + NVL (test1.amount1, 0)
                       + NVL (sched.amount_adjusted, 0),
                       0)
                       amount_due,
                   ((TO_DATE (ld_as_of_date, 'DD-MON-YY')) - sched.due_date)
                       days_past_due,
                   NULL,
                   NULL,
                   NULL,
                   NULL,
                   NULL,
                   NULL
              FROM ar.ar_payment_schedules_all sched,
                   apps.xxd_ra_customers_v rac,
                   apps.ra_cust_trx_types_all rtt,
                   apps.ra_customer_trx_all cta,
                   ar.hz_customer_profiles cp,
                   ar.ar_collectors ac,
                   apps.ra_terms_tl pt,
                   jtf.jtf_rs_salesreps rep,
                   apps.xle_le_ou_ledger_v xlol,
                   apps.hr_operating_units hrou,
                   apps.xxd_ra_addresses_morg_v raa,
                   apps.hz_cust_accounts hca,
                   (  SELECT app.payment_schedule_id, NVL (SUM (NVL (app.amount_applied_from, app.amount_applied)), 0) amount1
                        FROM ar_receivable_applications_all app
                       WHERE     1 = 1
                             AND app.status = 'APP'
                             AND app.gl_date <=
                                 (TO_DATE (ld_as_of_date, 'DD-MON-YY'))
                    GROUP BY app.payment_schedule_id) test1
             WHERE     pt.term_id(+) = cta.term_id
                   AND 1 = 1
                   AND hca.attribute1 = NVL (pv_brand, hca.attribute1)
                   AND ac.collector_id =
                       NVL (pn_collector_id, ac.collector_id)
                   AND pt.language(+) = USERENV ('LANG')
                   AND rac.customer_id = cta.bill_to_customer_id
                   AND rtt.cust_trx_type_id = cta.cust_trx_type_id
                   AND rtt.org_id = cta.org_id
                   AND rep.salesrep_id(+) = cta.primary_salesrep_id
                   AND rep.org_id(+) = cta.org_id
                   AND cp.cust_account_id = cta.bill_to_customer_id
                   AND cp.site_use_id IS NULL
                   AND ac.collector_id = cp.collector_id
                   AND cta.bill_to_customer_id = hca.cust_account_id
                   AND test1.payment_schedule_id = sched.payment_schedule_id
                   AND sched.org_id = cta.org_id
                   AND sched.customer_trx_id = cta.customer_trx_id
                   AND hrou.organization_id = cta.org_id
                   --AND sched.org_id = hrou.organization_id --Comment for CCR0009092
                   AND xlol.operating_unit_id = hrou.organization_id
                   AND raa.customer_id = cta.bill_to_customer_id
                   AND raa.org_id = cta.org_id
                   AND raa.bill_to_flag = 'P'
                   AND raa.status = 'A'
                   AND sched.class <> 'PMT'
                   AND xlol.legal_entity_id = hrou.default_legal_context_id
                   AND xlol.operating_unit_id IN
                           (SELECT organization_id
                              FROM hr_operating_units
                             WHERE name IN
                                       (SELECT ffv.flex_value
                                          FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
                                         WHERE     ffvs.flex_value_set_id =
                                                   ffv.flex_value_set_id
                                               AND flex_value_set_name =
                                                   'XXDO_REGION_BASED_OU'
                                               AND parent_flex_value_low =
                                                   NVL (
                                                       pn_region,
                                                       parent_flex_value_low)
                                               AND flex_value =
                                                   NVL (pn_operating_unit,
                                                        flex_value)
                                               AND (pn_ex_ecomm_ous = 'Y' AND UPPER (ffv.flex_value) NOT LIKE '%ECOMM%' OR pn_ex_ecomm_ous = 'N' AND ffv.flex_value = ffv.flex_value OR pn_ex_ecomm_ous IS NULL AND ffv.flex_value = ffv.flex_value)
                                               AND ffv.enabled_flag = 'Y')) -- Added by Infosys for ENHC0013499 - CCR0006871
                   /*=
                                    NVL (pn_operating_unit, xlol.operating_unit_id) */
                          -- Commented by Infosys for ENHC0013499 - CCR0006871
                   AND sched.trx_date <=
                       (TO_DATE (ld_as_of_date, 'DD-MON-YY'))
                   AND TRUNC (sched.gl_date) <=
                       (TO_DATE (ld_as_of_date, 'DD-MON-YY'))
                   AND sched.gl_date_closed >
                       TO_DATE (ld_as_of_date, 'DD-MON-YY')
                   AND CEIL (
                           TO_DATE (ld_as_of_date, 'DD-MON-YY') - sched.due_date) BETWEEN pn_days_from
                                                                                      AND pn_days_to
            UNION
              /*---------- 4 ------------*/
              SELECT rc.attribute1
                         brand,
                     hrou.name
                         AS org_name,
                     rc.customer_number
                         account_number,
                     (SELECT ('''' || TO_CHAR (RTRIM (XMLAGG (XMLELEMENT (e, account_number || ',')).EXTRACT ('//text()'), ',')))
                        FROM apps.hz_cust_accounts_all
                       WHERE     party_id = rc.party_id
                             AND attribute1 = 'ALL BRAND'
                             AND status = 'A')
                         party_number,   --Added for  ENHC0013499 - CCR0006871
                     --rc.party_number, --commented for  ENHC0013499 - CCR0006871
                     rc.customer_name,
                     NVL (raa.address1, '-')
                         cust_address1,
                     NVL (raa.state, '-')
                         cust_state,
                     NVL (raa.postal_code, '-')
                         cust_zip,
                     xxd_ar_aging_enhanced_rpt_pkg.return_collector (
                         pv_summary_detail_level,
                         rc.party_id,
                         rc.customer_id)
                         collector,
                     xxd_ar_aging_enhanced_rpt_pkg.return_credit_analyst (
                         pv_summary_detail_level,
                         rc.party_id,
                         rc.customer_id)
                         credit_analyst,
                     xxd_ar_aging_enhanced_rpt_pkg.return_chargeback_analyst (
                         pv_summary_detail_level,
                         rc.party_id,
                         rc.customer_id)
                         chargeback_analyst,
                     xxd_ar_aging_enhanced_rpt_pkg.return_profile_class (
                         pv_summary_detail_level,
                         rc.party_id,
                         rc.customer_id)
                         profile_class,
                     xxd_ar_aging_enhanced_rpt_pkg.return_credit_limit (
                         pv_summary_detail_level,
                         rc.party_id,
                         rc.customer_id)
                         credit_limit,
                     'ON ACCOUNT'
                         name,
                     'ON ACCOUNT'
                         transaction_name,
                     NULL
                         term,
                     NULL
                         description,
                     apsa.invoice_currency_code,
                     apsa.due_date,
                     NULL
                         gl_date,
                     apsa.payment_schedule_id,
                     apsa.class,
                     acr.receipt_number
                         trx_rcpt_number,
                     ---- Added for P_AS_OF_DATE
                     TO_CHAR (NULL)
                         interface_header_attribute1,
                     TO_CHAR (NULL)
                         purchase_order,
                     TO_CHAR (NULL)
                         salesrep_number,
                     TO_CHAR (NULL)
                         salesrep_name,
                     acr.receipt_date
                         trx_date,
                     NVL (apsa.amount_due_original, 0)
                         AS amount_due_original,
                     NVL (apsa.amount_applied, 0)
                         AS amount_applied,
                     NVL (apsa.amount_adjusted, 0)
                         AS amount_adjusted,
                     NVL (apsa.amount_credited, 0)
                         AS amount_credited,
                     NVL (apsa.amount_in_dispute, 0)
                         AS amount_in_dispute,
                     --1.4 changes start
                     hca.sales_channel_code,
                     hca.customer_class_code,
                     rtt.name
                         payment_terms,
                     --1.4 changes end
                     (-1) * SUM (NVL (ara.amount_applied, 0))
                         amount_due,
                     ((TO_DATE (ld_as_of_date, 'DD-MON-YY')) - apsa.due_date)
                         days_past_due,
                     NULL,
                     NULL,
                     NULL,
                     NULL,
                     NULL,
                     NULL
                FROM xxd_ra_customers_v rc, hz_cust_accounts hca, ar_adjustments_all adj,
                     ar_receivables_trx_all rt, ra_customer_trx_all ct, ar_payment_schedules_all apsa,
                     ra_cust_trx_types_all types, ra_terms_tl rtt, apps.xle_le_ou_ledger_v xlol,
                     apps.hr_operating_units hrou, apps.xxd_ra_addresses_morg_v raa, ar.ar_collectors ac,
                     ar.hz_customer_profiles cp, apps.ar_cash_receipts_all acr, apps.ar_receivable_applications_all ara,
                     apps.hz_cust_site_uses_all site_uses, ra_terms_lines_discounts rtld
               WHERE     adj.status = 'A'
                     AND 1 = 1
                     AND hca.attribute1 = NVL (pv_brand, hca.attribute1) --1.4
                     AND ac.collector_id =
                         NVL (pn_collector_id, ac.collector_id)
                     AND adj.org_id = rt.org_id
                     AND adj.org_id = apsa.org_id
                     AND adj.receivables_trx_id = rt.receivables_trx_id(+)
                     AND raa.customer_id = ct.bill_to_customer_id
                     AND raa.org_id = ct.org_id
                     AND raa.bill_to_flag = 'P'
                     AND raa.status = 'A'
                     AND adj.customer_trx_id = ct.customer_trx_id(+)
                     AND ct.customer_trx_id = apsa.customer_trx_id
                     AND apsa.customer_id = rc.customer_id
                     AND hca.cust_account_id = rc.customer_id
                     AND rtld.term_id(+) = apsa.term_id
                     AND rtt.term_id(+) = apsa.term_id
                     AND rtt.language(+) = 'US'
                     --   AND apsa.org_id = fnd_profile.VALUE ('ORG_ID')  -- Commented by Infosys for ENHC0013499 - CCR0006871
                     AND apsa.payment_schedule_id = ara.payment_schedule_id(+)
                     AND ara.cash_receipt_id = acr.cash_receipt_id(+)
                     AND apsa.cash_receipt_id = ara.cash_receipt_id(+)
                     AND acr.customer_site_use_id = site_uses.site_use_id(+)
                     AND types.cust_trx_type_id(+) = apsa.cust_trx_type_id
                     AND types.org_id(+) = apsa.org_id
                     AND adj.gl_date >
                         TO_CHAR ((TO_DATE (ld_as_of_date, 'DD-MON-YY')),
                                  'DD-MON-RRRR')
                     AND ct.creation_date <=
                         TO_CHAR ((TO_DATE (ld_as_of_date, 'DD-MON-YY')),
                                  'DD-MON-RRRR')
                     AND apsa.gl_date <=
                         TO_CHAR ((TO_DATE (ld_as_of_date, 'DD-MON-YY')),
                                  'DD-MON-RRRR')
                     --AND apsa.class                = NVL (P_CLASS, apsa.class)
                     AND adj.org_id = hrou.organization_id -- Added for CCR0009092
                     AND xlol.operating_unit_id = hrou.organization_id
                     AND xlol.legal_entity_id = hrou.default_legal_context_id
                     AND xlol.operating_unit_id IN
                             (SELECT organization_id
                                FROM hr_operating_units
                               WHERE name IN
                                         (SELECT ffv.flex_value
                                            FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
                                           WHERE     ffvs.flex_value_set_id =
                                                     ffv.flex_value_set_id
                                                 AND flex_value_set_name =
                                                     'XXDO_REGION_BASED_OU'
                                                 AND parent_flex_value_low =
                                                     NVL (
                                                         pn_region,
                                                         parent_flex_value_low)
                                                 AND flex_value =
                                                     NVL (pn_operating_unit,
                                                          flex_value)
                                                 AND (pn_ex_ecomm_ous = 'Y' AND UPPER (ffv.flex_value) NOT LIKE '%ECOMM%' OR pn_ex_ecomm_ous = 'N' AND ffv.flex_value = ffv.flex_value OR pn_ex_ecomm_ous IS NULL AND ffv.flex_value = ffv.flex_value)
                                                 AND ffv.enabled_flag = 'Y')) -- Added by Infosys for ENHC0013499 - CCR0006871
                     /* =
                                      NVL (pn_operating_unit, xlol.operating_unit_id) */
                     AND cp.cust_account_id = ct.bill_to_customer_id
                     AND cp.site_use_id IS NULL
                     AND ac.collector_id = cp.collector_id
                     AND CEIL (
                             TO_DATE (ld_as_of_date, 'DD-MON-YY') - apsa.due_date) BETWEEN pn_days_from
                                                                                       AND pn_days_to
              HAVING SUM (NVL (ara.amount_applied, 0)) <> 0
            GROUP BY hrou.NAME, rc.attribute1, rc.customer_number,
                     rc.party_id,        --Added for  ENHC0013499 - CCR0006871
                                  --rc.party_number,      --commented for  ENHC0013499 - CCR0006871
                                  rc.customer_name, raa.address1,
                     raa.state, raa.postal_code, rc.customer_id,
                     rc.party_id, acr.receipt_number, apsa.due_date,
                     apsa.payment_schedule_id, apsa.CLASS, ((TO_DATE (ld_as_of_date, 'DD-MON-YY')) - apsa.due_date),
                     apsa.amount_due_original, apsa.amount_applied, apsa.amount_adjusted,
                     apsa.amount_in_dispute, apsa.amount_credited, ac.NAME,
                     apsa.invoice_currency_code, acr.receipt_date, acr.comments,
                     --1.4 changes start
                     hca.customer_class_code, hca.sales_channel_code, rtt.name
            --1.4 changes end
            UNION
              /*---------- 5 ------------*/
              SELECT rac.attribute1
                         brand,
                     hrou.NAME
                         org_name,
                     rac.customer_number
                         account_number,
                     (SELECT ('''' || TO_CHAR (RTRIM (XMLAGG (XMLELEMENT (e, account_number || ',')).EXTRACT ('//text()'), ',')))
                        FROM apps.hz_cust_accounts_all
                       WHERE     party_id = rac.party_id
                             AND attribute1 = 'ALL BRAND'
                             AND status = 'A')
                         party_number,   --Added for  ENHC0013499 - CCR0006871
                     --rac.party_number, --commented for  ENHC0013499 - CCR0006871
                     rac.customer_name,
                     NVL (raa.address1, '-')
                         cust_address1,
                     NVL (raa.state, '-')
                         cust_state,
                     NVL (raa.postal_code, '-')
                         cust_zip,
                     xxd_ar_aging_enhanced_rpt_pkg.return_collector (
                         pv_summary_detail_level,
                         rac.party_id,
                         rac.customer_id)
                         collector,
                     xxd_ar_aging_enhanced_rpt_pkg.return_credit_analyst (
                         pv_summary_detail_level,
                         rac.party_id,
                         rac.customer_id)
                         credit_analyst,
                     xxd_ar_aging_enhanced_rpt_pkg.return_chargeback_analyst (
                         pv_summary_detail_level,
                         rac.party_id,
                         rac.customer_id)
                         chargeback_analyst,
                     xxd_ar_aging_enhanced_rpt_pkg.return_profile_class (
                         pv_summary_detail_level,
                         rac.party_id,
                         rac.customer_id)
                         profile_class,
                     xxd_ar_aging_enhanced_rpt_pkg.return_credit_limit (
                         pv_summary_detail_level,
                         rac.party_id,
                         rac.customer_id)
                         credit_limit,
                     'ON ACCOUNT'
                         NAME,
                     'ON ACCOUNT'
                         transaction_name,
                     NULL
                         term,
                     NULL
                         description,
                     sched.invoice_currency_code,
                     sched.due_date,
                     NULL
                         gl_date,
                     sched.payment_schedule_id,
                     sched.CLASS,
                     acr.receipt_number
                         trx_rcpt_number,
                     NULL
                         interface_header_attribute1,
                     NULL
                         purchase_order,
                     NULL
                         salesrep_number,
                     NULL
                         salesrep_name,
                     acr.receipt_date
                         trx_date,
                     NVL (sched.amount_due_original, 0)
                         amount_due_original,
                     NVL (sched.amount_applied, 0)
                         amount_applied,
                     NVL (sched.amount_adjusted, 0)
                         amount_adjusted,
                     NVL (sched.amount_credited, 0)
                         amount_credited,
                     NVL (sched.amount_in_dispute, 0)
                         amount_in_dispute,
                     --1.4 changes start
                     rac.sales_channel_code,
                     rac.customer_class_code,
                     rtt.name
                         payment_terms,
                     --1.4 changes end
                     (-1) * SUM (NVL (ara.amount_applied, 0))
                         amount_due,
                     (TO_DATE (ld_as_of_date, 'DD-MON-YY') - sched.due_date)
                         days_past_due,
                     NULL,
                     NULL,
                     NULL,
                     NULL,
                     NULL,
                     NULL
                FROM ar.ar_payment_schedules_all sched, apps.xxd_ra_customers_v rac, ar.hz_customer_profiles cp,
                     ar.ar_collectors ac, apps.ar_receivable_applications_all ara, apps.ar_cash_receipts_all acr,
                     apps.xxd_ra_addresses_morg_v raa, apps.xle_le_ou_ledger_v xlol, apps.hr_operating_units hrou,
                     apps.hz_cust_site_uses_all site_uses, apps.ra_terms_tl rtt, -- 1.4
                                                                                 XXDO.XXD_AR_AGING_REPORT_GT gt -- Added for CCR0009092
               WHERE     1 = 1
                     AND gt.request_id = l_comm_req_id -- Added for CCR0009092
                     AND gt.payment_schedule_id = sched.payment_schedule_id -- Added for CCR0009092
                     AND ara.status = gt.status        -- Added for CCR0009092
                     AND gt.org_id = sched.org_id      -- Added for CCR0009092
                     --AND hca.attribute1 = NVL (pv_brand, cust_acct.attribute1)
                     AND rac.attribute1 = NVL (pv_brand, rac.attribute1) --1.4
                     AND ac.collector_id =
                         NVL (pn_collector_id, ac.collector_id)
                     AND sched.cash_receipt_id = acr.cash_receipt_id
                     AND sched.customer_id = rac.customer_id
                     AND sched.payment_schedule_id = ara.payment_schedule_id
                     AND cp.site_use_id IS NULL
                     AND acr.customer_site_use_id = site_uses.site_use_id
                     AND ac.collector_id = cp.collector_id
                     AND acr.pay_from_customer = rac.customer_id
                     AND acr.org_id = ara.org_id
                     AND cp.cust_account_id = rac.customer_id
                     AND ara.cash_receipt_id = acr.cash_receipt_id
                     AND sched.cash_receipt_id = ara.cash_receipt_id
                     AND ara.org_id = sched.org_id
                     AND ara.status = 'ACC'
                     AND gt.org_id = hrou.organization_id -- Added for CCR0009092
                     AND raa.customer_id = acr.pay_from_customer
                     AND raa.org_id = acr.org_id
                     AND raa.bill_to_flag = 'P'
                     AND raa.status = 'A'
                     AND site_uses.org_id = sched.org_id
                     AND xlol.operating_unit_id = hrou.organization_id
                     AND xlol.legal_entity_id = hrou.default_legal_context_id
                     AND xlol.operating_unit_id IN
                             (SELECT organization_id
                                FROM hr_operating_units
                               WHERE name IN
                                         (SELECT ffv.FLEX_VALUE
                                            FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
                                           WHERE     ffvs.FLEX_VALUE_SET_ID =
                                                     ffv.flex_value_set_id
                                                 AND flex_value_set_name =
                                                     'XXDO_REGION_BASED_OU'
                                                 AND PARENT_FLEX_VALUE_LOW =
                                                     NVL (
                                                         PN_REGION,
                                                         PARENT_FLEX_VALUE_LOW)
                                                 AND flex_value =
                                                     NVL (PN_OPERATING_UNIT,
                                                          flex_value)
                                                 AND (PN_EX_ECOMM_OUS = 'Y' AND UPPER (ffv.flex_value) NOT LIKE '%ECOMM%' OR PN_EX_ECOMM_OUS = 'N' AND ffv.flex_value = ffv.flex_value OR PN_EX_ECOMM_OUS IS NULL AND ffv.flex_value = ffv.flex_value)
                                                 AND ffv.enabled_flag = 'Y')) -- Added by Infosys for ENHC0013499 - CCR0006871
                     /*=
                                      NVL (pn_operating_unit, xlol.operating_unit_id) */
                          -- Commented by Infosys for ENHC0013499 - CCR0006871
                     AND sched.CLASS NOT IN ('INV', 'CM', 'CB',
                                             'DM')
                     AND ara.gl_date <= (TO_DATE (ld_as_of_date, 'DD-MON-YY'))
                     AND sched.gl_date <=
                         (TO_DATE (ld_as_of_date, 'DD-MON-YY'))
                     AND CEIL (
                             TO_DATE (ld_as_of_date, 'DD-MON-YY') - sched.due_date) BETWEEN pn_days_from
                                                                                        AND pn_days_to
                     --1.4 changes start
                     AND rtt.term_id(+) = sched.term_id
                     AND rtt.LANGUAGE(+) = 'US'
              --1.4 changes end
              HAVING SUM (NVL (ara.amount_applied, 0)) <> 0
            GROUP BY hrou.NAME, rac.attribute1, rac.customer_number,
                     rac.party_id,       --Added for  ENHC0013499 - CCR0006871
                                   --rac.party_number, --commented for  ENHC0013499 - CCR0006871,
                                   rac.customer_name, raa.address1,
                     raa.state, raa.postal_code, rac.customer_id,
                     rac.party_id, acr.receipt_number, sched.due_date,
                     sched.payment_schedule_id, sched.CLASS, (TO_DATE (ld_as_of_date, 'DD-MON-YY') - sched.due_date),
                     NVL (sched.amount_due_original, 0), NVL (sched.amount_applied, 0), NVL (sched.amount_adjusted, 0),
                     NVL (sched.amount_in_dispute, 0), NVL (sched.amount_credited, 0), ac.NAME,
                     sched.invoice_currency_code, acr.receipt_date, acr.comments,
                     --1.4 changes start
                     rac.customer_class_code, rac.sales_channel_code, rtt.name
            --1.4 changes end
            UNION
              /*---------- 6 ------------*/
              SELECT rac.attribute1
                         brand,
                     hrou.NAME
                         org_name,
                     rac.customer_number
                         account_number,
                     (SELECT ('''' || TO_CHAR (RTRIM (XMLAGG (XMLELEMENT (e, account_number || ',')).EXTRACT ('//text()'), ',')))
                        FROM apps.hz_cust_accounts_all
                       WHERE     party_id = rac.party_id
                             AND attribute1 = 'ALL BRAND'
                             AND status = 'A')
                         party_number,   --Added for  ENHC0013499 - CCR0006871
                     --rac.party_number, --commented for  ENHC0013499 - CCR0006871
                     rac.customer_name,
                     NVL (raa.address1, '-')
                         cust_address1,
                     NVL (raa.state, '-')
                         cust_state,
                     NVL (raa.postal_code, '-')
                         cust_zip,
                     xxd_ar_aging_enhanced_rpt_pkg.return_collector (
                         pv_summary_detail_level,
                         rac.party_id,
                         rac.customer_id)
                         collector,
                     xxd_ar_aging_enhanced_rpt_pkg.return_credit_analyst (
                         pv_summary_detail_level,
                         rac.party_id,
                         rac.customer_id)
                         credit_analyst,
                     xxd_ar_aging_enhanced_rpt_pkg.return_chargeback_analyst (
                         pv_summary_detail_level,
                         rac.party_id,
                         rac.customer_id)
                         chargeback_analyst,
                     xxd_ar_aging_enhanced_rpt_pkg.return_profile_class (
                         pv_summary_detail_level,
                         rac.party_id,
                         rac.customer_id)
                         profile_class,
                     xxd_ar_aging_enhanced_rpt_pkg.return_credit_limit (
                         pv_summary_detail_level,
                         rac.party_id,
                         rac.customer_id)
                         credit_limit,
                     'CASH CLAIMS'
                         NAME,
                     'CASH CLAIMS'
                         transaction_name,
                     NULL
                         term,
                     NULL
                         description,
                     sched.invoice_currency_code,
                     sched.due_date,
                     NULL
                         gl_date,
                     sched.payment_schedule_id,
                     sched.CLASS,
                     acr.receipt_number
                         trx_rcpt_number,
                     TO_CHAR (NULL)
                         interface_header_attribute1,
                     TO_CHAR (NULL)
                         purchase_order,
                     TO_CHAR (NULL)
                         salesrep_number,
                     TO_CHAR (NULL)
                         salesrep_name,
                     acr.receipt_date
                         trx_date,
                     NVL (sched.amount_due_original, 0)
                         amount_due_original,
                     NVL (sched.amount_applied, 0)
                         amount_applied,
                     NVL (sched.amount_adjusted, 0)
                         amount_adjusted,
                     NVL (sched.amount_credited, 0)
                         amount_credited,
                     NVL (sched.amount_in_dispute, 0)
                         amount_in_dispute,
                     --1.4 changes start
                     rac.sales_channel_code,
                     rac.customer_class_code,
                     rtt.name
                         payment_terms,
                     --1.4 changes end
                     (-1) * SUM (NVL (ara.amount_applied, 0))
                         amount_due,
                     ((TO_DATE (ld_as_of_date, 'DD-MON-YY')) - sched.due_date)
                         days_past_due,
                     NULL,
                     NULL,
                     NULL,
                     NULL,
                     NULL,
                     NULL
                FROM ar.ar_payment_schedules_all sched, apps.xxd_ra_customers_v rac, ar.hz_customer_profiles cp,
                     ar.ar_collectors ac, apps.ar_receivable_applications_all ara, apps.ar_cash_receipts_all acr,
                     apps.xxd_ra_addresses_morg_v raa, apps.xle_le_ou_ledger_v xlol, apps.hr_operating_units hrou,
                     apps.hz_cust_site_uses_all site_uses, ra_terms_tl rtt, -- 1.4
                                                                            XXDO.XXD_AR_AGING_REPORT_GT gt -- Added for CCR0009092
               WHERE     1 = 1
                     AND gt.request_id = l_comm_req_id -- Added for CCR0009092
                     AND gt.payment_schedule_id = sched.payment_schedule_id -- Added for CCR0009092
                     AND ara.status = gt.status        -- Added for CCR0009092
                     AND gt.org_id = sched.org_id      -- Added for CCR0009092
                     AND rac.attribute1 = NVL (pv_brand, rac.attribute1)
                     AND ac.collector_id =
                         NVL (pn_collector_id, ac.collector_id)
                     AND sched.cash_receipt_id = acr.cash_receipt_id
                     AND sched.customer_id = rac.customer_id
                     AND sched.payment_schedule_id = ara.payment_schedule_id
                     AND cp.site_use_id IS NULL
                     AND acr.customer_site_use_id = site_uses.site_use_id
                     AND ac.collector_id = cp.collector_id
                     AND acr.pay_from_customer = rac.customer_id
                     AND acr.org_id = ara.org_id
                     AND cp.cust_account_id = rac.customer_id
                     AND ara.cash_receipt_id = acr.cash_receipt_id
                     AND sched.cash_receipt_id = ara.cash_receipt_id
                     AND ara.org_id = sched.org_id
                     AND ara.status = 'OTHER ACC'
                     AND gt.org_id = hrou.organization_id -- Added for CCR0009092
                     AND raa.customer_id = acr.pay_from_customer
                     AND raa.org_id = acr.org_id
                     AND raa.bill_to_flag = 'P'
                     AND raa.status = 'A'
                     AND site_uses.org_id = sched.org_id
                     AND xlol.operating_unit_id = hrou.organization_id
                     AND xlol.legal_entity_id = hrou.default_legal_context_id
                     AND xlol.operating_unit_id IN
                             (SELECT organization_id
                                FROM hr_operating_units
                               WHERE name IN
                                         (SELECT ffv.FLEX_VALUE
                                            FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
                                           WHERE     ffvs.FLEX_VALUE_SET_ID =
                                                     ffv.flex_value_set_id
                                                 AND flex_value_set_name =
                                                     'XXDO_REGION_BASED_OU'
                                                 AND PARENT_FLEX_VALUE_LOW =
                                                     NVL (
                                                         PN_REGION,
                                                         PARENT_FLEX_VALUE_LOW)
                                                 AND flex_value =
                                                     NVL (PN_OPERATING_UNIT,
                                                          flex_value)
                                                 AND (PN_EX_ECOMM_OUS = 'Y' AND UPPER (ffv.flex_value) NOT LIKE '%ECOMM%' OR PN_EX_ECOMM_OUS = 'N' AND ffv.flex_value = ffv.flex_value OR PN_EX_ECOMM_OUS IS NULL AND ffv.flex_value = ffv.flex_value)
                                                 AND ffv.enabled_flag = 'Y')) -- Added by Infosys for ENHC0013499 - CCR0006871
                     /*=
                                      NVL (pn_operating_unit, xlol.operating_unit_id) */
                          -- Commented by Infosys for ENHC0013499 - CCR0006871
                     AND sched.CLASS NOT IN ('INV', 'CM', 'CB',
                                             'DM')
                     AND ara.gl_date <=
                         TO_CHAR (TO_DATE (ld_as_of_date, 'DD-MON-YY'),
                                  'DD-MON-RRRR')
                     AND sched.gl_date <=
                         TO_CHAR (TO_DATE (ld_as_of_date, 'DD-MON-YY'),
                                  'DD-MON-RRRR')
                     AND CEIL (
                             TO_DATE (ld_as_of_date, 'DD-MON-YY') - sched.due_date) BETWEEN pn_days_from
                                                                                        AND pn_days_to
                     --1.4 changes start
                     AND rtt.term_id(+) = sched.term_id
                     AND rtt.LANGUAGE(+) = 'US'
            --1.4 changes end
            GROUP BY rac.attribute1, hrou.NAME, rac.customer_number,
                     rac.party_id,       --Added for  ENHC0013499 - CCR0006871
                                   --rac.party_number, --commented for  ENHC0013499 - CCR0006871
                                   rac.customer_name, raa.address1,
                     raa.state, raa.postal_code, rac.customer_id,
                     rac.party_id, acr.receipt_number, sched.due_date,
                     sched.payment_schedule_id, sched.CLASS, ((TO_DATE (ld_as_of_date, 'DD-MON-YY')) - sched.due_date),
                     NVL (sched.amount_due_original, 0), NVL (sched.amount_applied, 0), NVL (sched.amount_adjusted, 0),
                     NVL (sched.amount_in_dispute, 0), NVL (sched.amount_credited, 0), ac.NAME,
                     sched.invoice_currency_code, acr.receipt_date, acr.comments,
                     --1.4 changes start
                     rac.customer_class_code, rac.sales_channel_code, rtt.name
              --1.4 changes end
              HAVING SUM (NVL (ara.amount_applied, 0)) <> 0
            UNION
              /*---------- 7 ------------*/
              SELECT rac.attribute1
                         brand,
                     hrou.NAME
                         org_name,
                     rac.customer_number
                         account_number,
                     (SELECT ('''' || TO_CHAR (RTRIM (XMLAGG (XMLELEMENT (e, account_number || ',')).EXTRACT ('//text()'), ',')))
                        FROM apps.hz_cust_accounts_all
                       WHERE     party_id = rac.party_id
                             AND attribute1 = 'ALL BRAND'
                             AND status = 'A')
                         party_number,   --Added for  ENHC0013499 - CCR0006871
                     --rac.party_number, --commented for  ENHC0013499 - CCR0006871
                     rac.customer_name,
                     NVL (raa.address1, '-')
                         cust_address1,
                     NVL (raa.state, '-')
                         cust_state,
                     NVL (raa.postal_code, '-')
                         cust_zip,
                     xxd_ar_aging_enhanced_rpt_pkg.return_collector (
                         pv_summary_detail_level,
                         rac.party_id,
                         rac.customer_id)
                         collector,
                     xxd_ar_aging_enhanced_rpt_pkg.return_credit_analyst (
                         pv_summary_detail_level,
                         rac.party_id,
                         rac.customer_id)
                         credit_analyst,
                     xxd_ar_aging_enhanced_rpt_pkg.return_chargeback_analyst (
                         pv_summary_detail_level,
                         rac.party_id,
                         rac.customer_id)
                         chargeback_analyst,
                     xxd_ar_aging_enhanced_rpt_pkg.return_profile_class (
                         pv_summary_detail_level,
                         rac.party_id,
                         rac.customer_id)
                         profile_class,
                     xxd_ar_aging_enhanced_rpt_pkg.return_credit_limit (
                         pv_summary_detail_level,
                         rac.party_id,
                         rac.customer_id)
                         credit_limit,
                     'UNIDENTIFIED'
                         NAME,
                     'UNIDENTIFIED'
                         transaction_name,
                     NULL
                         term,
                     NULL
                         description,
                     sched.invoice_currency_code,
                     sched.due_date,
                     NULL
                         gl_date,
                     sched.payment_schedule_id,
                     sched.CLASS,
                     acr.receipt_number
                         trx_rcpt_number,
                     TO_CHAR (NULL)
                         interface_header_attribute1,
                     TO_CHAR (NULL)
                         purchase_order,
                     TO_CHAR (NULL)
                         salesrep_number,
                     TO_CHAR (NULL)
                         salesrep_name,
                     acr.receipt_date
                         trx_date,
                     NVL (sched.amount_due_original, 0)
                         amount_due_original,
                     NVL (sched.amount_applied, 0)
                         amount_applied,
                     NVL (sched.amount_adjusted, 0)
                         amount_adjusted,
                     NVL (sched.amount_credited, 0)
                         amount_credited,
                     NVL (sched.amount_in_dispute, 0)
                         amount_in_dispute,
                     --1.4 changes start
                     rac.sales_channel_code,
                     rac.customer_class_code,
                     rtt.name
                         payment_terms,
                     --1.4 changes end
                     (-1) * SUM (NVL (ara.amount_applied, 0))
                         amount_due,
                     ((TO_DATE (ld_as_of_date, 'DD-MON-YY')) - sched.due_date)
                         days_past_due,              -- Added for P_AS_OF_DATE
                     NULL,
                     NULL,
                     NULL,
                     NULL,
                     NULL,
                     NULL
                FROM ar.ar_payment_schedules_all sched, apps.xxd_ra_customers_v rac, ar.hz_customer_profiles cp,
                     ar.ar_collectors ac, apps.ar_receivable_applications_all ara, apps.ar_cash_receipts_all acr,
                     apps.xxd_ra_addresses_morg_v raa, apps.xle_le_ou_ledger_v xlol, apps.hr_operating_units hrou,
                     apps.hz_cust_site_uses_all site_uses, ra_terms_tl rtt, -- 1.4
                                                                            XXDO.XXD_AR_AGING_REPORT_GT gt -- Added for CCR0009092
               WHERE     1 = 1
                     AND gt.request_id = l_comm_req_id -- Added for CCR0009092
                     AND gt.payment_schedule_id = sched.payment_schedule_id -- Added for CCR0009092
                     AND ara.status = gt.status        -- Added for CCR0009092
                     AND gt.org_id = sched.org_id      -- Added for CCR0009092
                     AND rac.attribute1 = NVL (pv_brand, rac.attribute1)
                     AND ac.collector_id =
                         NVL (pn_collector_id, ac.collector_id)
                     AND sched.cash_receipt_id = acr.cash_receipt_id
                     AND sched.customer_id = rac.customer_id
                     AND sched.payment_schedule_id = ara.payment_schedule_id
                     AND cp.site_use_id IS NULL
                     AND acr.customer_site_use_id = site_uses.site_use_id
                     AND ac.collector_id = cp.collector_id
                     --AND sched.status = 'OP'
                     AND acr.pay_from_customer = rac.customer_id
                     AND acr.org_id = ara.org_id
                     AND cp.cust_account_id = rac.customer_id
                     AND ara.cash_receipt_id = acr.cash_receipt_id
                     AND sched.cash_receipt_id = ara.cash_receipt_id
                     AND ara.org_id = sched.org_id
                     AND ara.status = 'UNID'
                     --AND sched.class            = NVL (P_CLASS, sched.class)
                     AND gt.org_id = hrou.organization_id -- Added for CCR0009092
                     AND raa.customer_id = acr.pay_from_customer
                     AND raa.org_id = acr.org_id
                     AND raa.bill_to_flag = 'P'
                     AND raa.status = 'A'
                     AND site_uses.org_id = sched.org_id
                     AND xlol.operating_unit_id = hrou.organization_id
                     AND xlol.legal_entity_id = hrou.default_legal_context_id
                     AND xlol.operating_unit_id IN
                             (SELECT organization_id
                                FROM hr_operating_units
                               WHERE name IN
                                         (SELECT ffv.FLEX_VALUE
                                            FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
                                           WHERE     ffvs.FLEX_VALUE_SET_ID =
                                                     ffv.flex_value_set_id
                                                 AND flex_value_set_name =
                                                     'XXDO_REGION_BASED_OU'
                                                 AND PARENT_FLEX_VALUE_LOW =
                                                     NVL (
                                                         PN_REGION,
                                                         PARENT_FLEX_VALUE_LOW)
                                                 AND flex_value =
                                                     NVL (PN_OPERATING_UNIT,
                                                          flex_value)
                                                 AND (PN_EX_ECOMM_OUS = 'Y' AND UPPER (ffv.flex_value) NOT LIKE '%ECOMM%' OR PN_EX_ECOMM_OUS = 'N' AND ffv.flex_value = ffv.flex_value OR PN_EX_ECOMM_OUS IS NULL AND ffv.flex_value = ffv.flex_value)
                                                 AND ffv.enabled_flag = 'Y')) -- Added by Infosys for ENHC0013499 - CCR0006871
                     /*=
                                      NVL (pn_operating_unit, xlol.operating_unit_id)*/
                          -- Commented by Infosys for ENHC0013499 - CCR0006871
                     AND sched.CLASS NOT IN ('INV', 'CM', 'CB',
                                             'DM')
                     AND ara.gl_date <=
                         TO_CHAR (TO_DATE (ld_as_of_date, 'DD-MON-YY'),
                                  'DD-MON-RRRR')
                     AND sched.gl_date <=
                         TO_CHAR (TO_DATE (ld_as_of_date, 'DD-MON-YY'),
                                  'DD-MON-RRRR')
                     AND CEIL (
                             TO_DATE (ld_as_of_date, 'DD-MON-YY') - sched.due_date) BETWEEN pn_days_from
                                                                                        AND pn_days_to
                     --1.4 changes start
                     AND rtt.term_id(+) = sched.term_id
                     AND rtt.LANGUAGE(+) = 'US'
            -- 1.4 changes end
            GROUP BY rac.attribute1, hrou.NAME, rac.customer_number,
                     rac.party_id,       --Added for  ENHC0013499 - CCR0006871
                                   --rac.party_number, --commented for  ENHC0013499 - CCR0006871
                                   rac.customer_name, raa.address1,
                     raa.state, raa.postal_code, rac.customer_id,
                     rac.party_id, acr.receipt_number, sched.due_date,
                     sched.payment_schedule_id, sched.CLASS, ((TO_DATE (ld_as_of_date, 'DD-MON-YY')) - sched.due_date), -- Added for P_AS_OF_DATE
                     NVL (sched.amount_due_original, 0), NVL (sched.amount_applied, 0), NVL (sched.amount_adjusted, 0),
                     NVL (sched.amount_in_dispute, 0), NVL (sched.amount_credited, 0), ac.NAME,
                     sched.invoice_currency_code, acr.receipt_date, acr.comments,
                     --1.4 changes start
                     rac.customer_class_code, rac.sales_channel_code, rtt.name
              --1.4 changes end
              HAVING SUM (NVL (ara.amount_applied, 0)) <> 0
            UNION
              /*---------- 8 ------------*/
              SELECT rac.attribute1
                         brand,
                     hrou.NAME
                         org_name,
                     rac.customer_number
                         account_number,
                     (SELECT ('''' || TO_CHAR (RTRIM (XMLAGG (XMLELEMENT (e, account_number || ',')).EXTRACT ('//text()'), ',')))
                        FROM apps.hz_cust_accounts_all
                       WHERE     party_id = rac.party_id
                             AND attribute1 = 'ALL BRAND'
                             AND status = 'A')
                         party_number,   --Added for  ENHC0013499 - CCR0006871
                     --rac.party_number, --commented for  ENHC0013499 - CCR0006871
                     rac.customer_name,
                     NVL (raa.address1, '-')
                         cust_address1,
                     NVL (raa.state, '-')
                         cust_state,
                     NVL (raa.postal_code, '-')
                         cust_zip,
                     xxd_ar_aging_enhanced_rpt_pkg.return_collector (
                         pv_summary_detail_level,
                         rac.party_id,
                         rac.customer_id)
                         collector,
                     xxd_ar_aging_enhanced_rpt_pkg.return_credit_analyst (
                         pv_summary_detail_level,
                         rac.party_id,
                         rac.customer_id)
                         credit_analyst,
                     xxd_ar_aging_enhanced_rpt_pkg.return_chargeback_analyst (
                         pv_summary_detail_level,
                         rac.party_id,
                         rac.customer_id)
                         chargeback_analyst,
                     xxd_ar_aging_enhanced_rpt_pkg.return_profile_class (
                         pv_summary_detail_level,
                         rac.party_id,
                         rac.customer_id)
                         profile_class,
                     xxd_ar_aging_enhanced_rpt_pkg.return_credit_limit (
                         pv_summary_detail_level,
                         rac.party_id,
                         rac.customer_id)
                         credit_limit,
                     'UNAPPLIED'
                         NAME,
                     'UNAPPLIED'
                         transaction_name,
                     NULL
                         term,
                     NULL
                         description,
                     sched.invoice_currency_code,
                     --Code Added by BT Technology Team on 24-DEC-2014
                     sched.due_date,
                     NULL
                         gl_date,
                     sched.payment_schedule_id,
                     sched.CLASS,
                     acr.receipt_number
                         trx_rcpt_number,
                     TO_CHAR (NULL)
                         interface_header_attribute1,
                     TO_CHAR (NULL)
                         purchase_order,
                     TO_CHAR (NULL)
                         salesrep_number,
                     TO_CHAR (NULL)
                         salesrep_name,
                     acr.receipt_date
                         trx_date,
                     NVL (sched.amount_due_original, 0)
                         amount_due_original,
                     NVL (sched.amount_applied, 0)
                         amount_applied,
                     NVL (sched.amount_adjusted, 0)
                         amount_adjusted,
                     NVL (sched.amount_credited, 0)
                         amount_credited,
                     NVL (sched.amount_in_dispute, 0)
                         amount_in_dispute,
                     --1.4 changes start
                     rac.sales_channel_code,
                     rac.customer_class_code,
                     rtt.name
                         payment_terms,
                     --1.4 changes end
                     (-1) * SUM (NVL (ara.amount_applied, 0))
                         amount_due,
                     ((TO_DATE (ld_as_of_date, 'DD-MON-YY')) - sched.due_date)
                         days_past_due,              -- Added for P_AS_OF_DATE
                     NULL,
                     NULL,
                     NULL,
                     NULL,
                     NULL,
                     NULL
                FROM ar.ar_payment_schedules_all sched, apps.xxd_ra_customers_v rac, ar.hz_customer_profiles cp,
                     ar.ar_collectors ac, apps.ar_receivable_applications_all ara, apps.ar_cash_receipts_all acr,
                     apps.xxd_ra_addresses_morg_v raa, apps.hz_cust_site_uses_all site_uses, apps.xle_le_ou_ledger_v xlol,
                     apps.hr_operating_units hrou, ra_terms_tl rtt,     -- 1.4
                                                                    XXDO.XXD_AR_AGING_REPORT_GT gt -- Added for CCR0009092
               WHERE     1 = 1
                     AND gt.request_id = l_comm_req_id -- Added for CCR0009092
                     AND gt.payment_schedule_id = sched.payment_schedule_id -- Added for CCR0009092
                     AND ara.status = gt.status        -- Added for CCR0009092
                     AND gt.org_id = sched.org_id      -- Added for CCR0009092
                     --AND hca.attribute1 = NVL (pv_brand, cust_acct.attribute1)
                     AND rac.attribute1 = NVL (pv_brand, rac.attribute1) --1.4
                     AND ac.collector_id =
                         NVL (pn_collector_id, ac.collector_id)
                     AND sched.cash_receipt_id = acr.cash_receipt_id
                     --Code Added by BT Technology Team on 24-DEC-2014
                     AND sched.customer_id = rac.customer_id
                     AND sched.payment_schedule_id = ara.payment_schedule_id
                     AND cp.site_use_id IS NULL
                     AND acr.customer_site_use_id = site_uses.site_use_id
                     AND ac.collector_id = cp.collector_id
                     AND acr.pay_from_customer = rac.customer_id
                     AND acr.org_id = ara.org_id
                     AND cp.cust_account_id = rac.customer_id
                     AND ara.cash_receipt_id = acr.cash_receipt_id
                     AND sched.cash_receipt_id = ara.cash_receipt_id
                     AND ara.org_id = sched.org_id
                     AND ara.status = 'UNAPP'
                     --AND sched.class                           = NVL (P_CLASS, sched.class)
                     AND gt.org_id = hrou.organization_id -- Added for CCR0009092
                     AND raa.customer_id = acr.pay_from_customer
                     AND raa.org_id = acr.org_id
                     AND raa.bill_to_flag = 'P'
                     AND raa.status = 'A'
                     AND site_uses.org_id = sched.org_id
                     AND xlol.operating_unit_id = hrou.organization_id
                     AND xlol.legal_entity_id = hrou.default_legal_context_id
                     AND sched.CLASS NOT IN ('INV', 'CM', 'CB',
                                             'DM')
                     AND xlol.operating_unit_id IN
                             (SELECT organization_id
                                FROM hr_operating_units
                               WHERE name IN
                                         (SELECT ffv.FLEX_VALUE
                                            FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
                                           WHERE     ffvs.FLEX_VALUE_SET_ID =
                                                     ffv.flex_value_set_id
                                                 AND flex_value_set_name =
                                                     'XXDO_REGION_BASED_OU'
                                                 AND PARENT_FLEX_VALUE_LOW =
                                                     NVL (
                                                         PN_REGION,
                                                         PARENT_FLEX_VALUE_LOW)
                                                 AND flex_value =
                                                     NVL (PN_OPERATING_UNIT,
                                                          flex_value)
                                                 AND (PN_EX_ECOMM_OUS = 'Y' AND UPPER (ffv.flex_value) NOT LIKE '%ECOMM%' OR PN_EX_ECOMM_OUS = 'N' AND ffv.flex_value = ffv.flex_value OR PN_EX_ECOMM_OUS IS NULL AND ffv.flex_value = ffv.flex_value)
                                                 AND ffv.enabled_flag = 'Y')) -- Added by Infosys for ENHC0013499 - CCR0006871
                     /*=
                                      NVL (pn_operating_unit, xlol.operating_unit_id) */
                          -- Commented by Infosys for ENHC0013499 - CCR0006871
                     AND ara.gl_date <=
                         TO_CHAR (TO_DATE (ld_as_of_date, 'DD-MON-YY'),
                                  'DD-MON-RRRR')
                     AND sched.gl_date <=
                         TO_CHAR (TO_DATE (ld_as_of_date, 'DD-MON-YY'),
                                  'DD-MON-RRRR')
                     AND CEIL (
                             TO_DATE (ld_as_of_date, 'DD-MON-YY') - sched.due_date) BETWEEN pn_days_from
                                                                                        AND pn_days_to
                     --1.4 changes starat
                     AND rtt.term_id(+) = sched.term_id
                     AND rtt.LANGUAGE(+) = 'US'
              --1.4 changes end
              HAVING SUM (NVL (ara.amount_applied, 0)) <> 0
            GROUP BY rac.attribute1, hrou.NAME, rac.customer_number,
                     rac.party_id,       --Added for  ENHC0013499 - CCR0006871
                                   --rac.party_number, --commented for  ENHC0013499 - CCR0006871
                                   rac.customer_name, raa.address1,
                     raa.state, raa.postal_code, rac.customer_id,
                     rac.party_id, acr.receipt_number, sched.due_date,
                     sched.payment_schedule_id, sched.CLASS, ((TO_DATE (ld_as_of_date, 'DD-MON-YY')) - sched.due_date),
                     NVL (sched.amount_due_original, 0), NVL (sched.amount_applied, 0), NVL (sched.amount_adjusted, 0),
                     NVL (sched.amount_in_dispute, 0), NVL (sched.amount_credited, 0), ac.NAME,
                     sched.invoice_currency_code, acr.receipt_date, --Code Added by BT Technology Team on 24-DEC-2014
                                                                    --1.4 changes start
                                                                    rac.customer_class_code,
                     rac.sales_channel_code, rtt.name
            --1.4 changes end
            ORDER BY account_number, trx_rcpt_number;

        --   ORDER BY --org_name,
        --   customer_name, trx_rcpt_number;
        --and cust_acct.account_number = NVL(p_cust_num,cust_acct.account_number);

        -- CCR0006140
        CURSOR c1 IS
            SELECT *
              FROM xxdo.xxd_ar_aging_report_gt xaarg;

        commit_ctr              NUMBER;
        l_customer_number       xxd_ar_aging_report_gt.customer_number%TYPE;
        l_payment_schedule_id   xxd_ar_aging_report_gt.payment_schedule_id%TYPE;
    -- CCR0006140
    BEGIN
        --   mo_global.set_policy_context ('S', pn_operating_unit); --Commented by Infosys for ENHC0013499 - CCR0006871

        EXECUTE IMMEDIATE ('TRUNCATE TABLE XXDO.XXD_AR_AGING_REPORT_GT');

        -- Start for CCR0009092----
        BEGIN
            SELECT MIN (days_start), MAX (days_to)
              INTO l_days_start_from, l_days_start_to
              FROM ar_aging_bucket_lines
             WHERE 1 = 1 AND aging_bucket_id = pn_aging_bucket_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_days_start_from   := -9999;
                l_days_start_to     := 99999;
        END;

        -- End for CCR0009092----

        LOG ('PN_AGING_BUCKET_ID   -  - ' || pn_aging_bucket_id);
        COMMIT;

        -- Start for CCR0009092----
        INSERT INTO xxdo.xxd_ar_aging_report_gt (payment_schedule_id, org_id, status
                                                 , request_id)
            (SELECT payment_schedule_id, org_id, status,
                    l_comm_req_id request_id
               FROM (  SELECT sched.payment_schedule_id, sched.org_id, ara.status,
                              (-1) * SUM (NVL (ara.amount_applied, 0)) amount_due
                         FROM ar.ar_payment_schedules_all sched, apps.ar_receivable_applications_all ara, apps.ar_cash_receipts_all acr
                        WHERE     1 = 1
                              AND sched.cash_receipt_id = acr.cash_receipt_id
                              AND sched.payment_schedule_id =
                                  ara.payment_schedule_id
                              AND sched.cash_receipt_id = ara.cash_receipt_id
                              AND ara.cash_receipt_id = acr.cash_receipt_id
                              AND ara.org_id = sched.org_id
                              AND ara.status IN ('UNAPP', 'UNID', 'ACC',
                                                 'OTHER ACC')
                              AND sched.CLASS NOT IN ('INV', 'CM', 'CB',
                                                      'DM')
                              AND ara.gl_date <=
                                  TO_CHAR (
                                      TO_DATE (ld_as_of_date, 'DD-MON-YY'),
                                      'DD-MON-RRRR')
                              AND sched.gl_date <=
                                  TO_CHAR (
                                      TO_DATE (ld_as_of_date, 'DD-MON-YY'),
                                      'DD-MON-RRRR')
                              AND CEIL (
                                        TO_DATE (ld_as_of_date, 'DD-MON-YY')
                                      - sched.due_date) BETWEEN l_days_start_from
                                                            AND l_days_start_to
                     GROUP BY sched.payment_schedule_id, sched.org_id, ara.status
                       HAVING SUM (NVL (ara.amount_applied, 0)) <> 0));

        -- Start for CCR0009092----
        COMMIT;

        FOR rec_aging_buckets IN cur_aging_buckets
        LOOP
            LOG ('1');
            lv_all_aging_buckets   :=
                   lv_all_aging_buckets
                || ','
                || rec_aging_buckets.report_heading1;


            OPEN cur_aging_details (rec_aging_buckets.days_start,
                                    rec_aging_buckets.days_to);

            LOG ('2');

            LOOP
                l_index   := 0;

                -- LOG ('3');

                FETCH cur_aging_details
                    BULK COLLECT INTO t_ar_aging_rpt_gt_tab
                    LIMIT 500;

                -- LOG ('4');
                --LOG ('ld_as_of_date   --->  ' || ld_as_of_date);

                BEGIN
                    FORALL l_index IN 1 .. t_ar_aging_rpt_gt_tab.COUNT
                      SAVE EXCEPTIONS
                        INSERT INTO xxd_ar_aging_report_gt (brand, org_name, account_number, customer_number, customer_name, cust_address1, cust_state, cust_zip, collector, credit_analyst, chargeback_analyst, profile_class, overall_credit_limit, TYPE, transaction_name, term, description, invoice_currency_code, due_date, gl_date, payment_schedule_id, CLASS, trx_rcpt_number, interface_header_attribute1, purchase_order, salesrep_name, salesrep_number, trx_date, amount_due_original, amount_applied, amount_adjusted, amount_credited, amount_in_dispute, amount_due, days_past_due, aging_report_heading1, aging_report_heading2, bucket_sequence_num, creation_date, created_by, last_update_date, last_updated_by, request_id, -- CCR0006140
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 aging_bucket1, aging_bucket2, aging_bucket3, aging_bucket4, aging_bucket5, aging_bucket6, -- CCR0006140
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           --1.4 changes
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           sales_channel, cust_classification
                                                            , payment_terms--1.4 changes
                                                                           )
                                 VALUES (
                                            t_ar_aging_rpt_gt_tab (l_index).brand,
                                            t_ar_aging_rpt_gt_tab (l_index).org_name,
                                            t_ar_aging_rpt_gt_tab (l_index).account_number,
                                            t_ar_aging_rpt_gt_tab (l_index).customer_number,
                                            t_ar_aging_rpt_gt_tab (l_index).customer_name,
                                            t_ar_aging_rpt_gt_tab (l_index).cust_address1,
                                            t_ar_aging_rpt_gt_tab (l_index).cust_state,
                                            t_ar_aging_rpt_gt_tab (l_index).cust_zip,
                                            t_ar_aging_rpt_gt_tab (l_index).collector,
                                            t_ar_aging_rpt_gt_tab (l_index).credit_analyst,
                                            t_ar_aging_rpt_gt_tab (l_index).chargeback_analyst,
                                            t_ar_aging_rpt_gt_tab (l_index).profile_class,
                                            t_ar_aging_rpt_gt_tab (l_index).overall_credit_limit,
                                            t_ar_aging_rpt_gt_tab (l_index).TYPE,
                                            t_ar_aging_rpt_gt_tab (l_index).transaction_name,
                                            t_ar_aging_rpt_gt_tab (l_index).term,
                                            t_ar_aging_rpt_gt_tab (l_index).description,
                                            t_ar_aging_rpt_gt_tab (l_index).invoice_currency_code,
                                            t_ar_aging_rpt_gt_tab (l_index).due_date,
                                            t_ar_aging_rpt_gt_tab (l_index).gl_date,
                                            t_ar_aging_rpt_gt_tab (l_index).payment_schedule_id,
                                            t_ar_aging_rpt_gt_tab (l_index).CLASS,
                                            t_ar_aging_rpt_gt_tab (l_index).trx_rcpt_number,
                                            t_ar_aging_rpt_gt_tab (l_index).interface_header_attribute1,
                                            t_ar_aging_rpt_gt_tab (l_index).purchase_order,
                                            t_ar_aging_rpt_gt_tab (l_index).salesrep_name,
                                            t_ar_aging_rpt_gt_tab (l_index).salesrep_number,
                                            t_ar_aging_rpt_gt_tab (l_index).trx_date,
                                            t_ar_aging_rpt_gt_tab (l_index).amount_due_original,
                                            t_ar_aging_rpt_gt_tab (l_index).amount_applied,
                                            t_ar_aging_rpt_gt_tab (l_index).amount_adjusted,
                                            --                               t_ar_aging_rpt_gt_tab (l_index).STATUS,
                                            t_ar_aging_rpt_gt_tab (l_index).amount_credited,
                                            --                               t_ar_aging_rpt_gt_tab (l_index).REASON_CODE,
                                            t_ar_aging_rpt_gt_tab (l_index).amount_in_dispute,
                                            t_ar_aging_rpt_gt_tab (l_index).amount_due,
                                            t_ar_aging_rpt_gt_tab (l_index).days_past_due,
                                            rec_aging_buckets.report_heading1,
                                            rec_aging_buckets.report_heading2,
                                            rec_aging_buckets.bucket_sequence_num,
                                            SYSDATE,
                                            fnd_global.user_id,
                                            SYSDATE,
                                            fnd_global.user_id,
                                            fnd_global.conc_request_id,
                                            -- CCR0006140
                                            t_ar_aging_rpt_gt_tab (l_index).aging_bucket1,
                                            t_ar_aging_rpt_gt_tab (l_index).aging_bucket2,
                                            t_ar_aging_rpt_gt_tab (l_index).aging_bucket3,
                                            t_ar_aging_rpt_gt_tab (l_index).aging_bucket4,
                                            t_ar_aging_rpt_gt_tab (l_index).aging_bucket5,
                                            t_ar_aging_rpt_gt_tab (l_index).aging_bucket6,
                                            -- CCR0006140
                                            --1.4 changes start
                                            t_ar_aging_rpt_gt_tab (l_index).sales_channel_code,
                                            t_ar_aging_rpt_gt_tab (l_index).customer_class_code,
                                            t_ar_aging_rpt_gt_tab (l_index).payment_terms--1.4 changes end
                                                                                         );

                    --LOG ('No of records inserted - ' || SQL%ROWCOUNT);
                    --LOG ('5');
                    COMMIT;
                EXCEPTION
                    WHEN dml_errors
                    THEN
                        l_error_index   := 0;

                        FOR l_error_index IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                        LOOP
                            lv_err_msg   :=
                                   'Error while Inserting XXD_AR_AGING_REPORT_GT Table : '
                                || SQLCODE
                                || ' ---> '
                                || SQLERRM;
                            LOG (
                                   'Error while  INSERTING into XXD_AR_AGING_REPORT_GT Table : '
                                || t_ar_aging_rpt_gt_tab (
                                       SQL%BULK_EXCEPTIONS (l_error_index).ERROR_INDEX).payment_schedule_id
                                || ' -- '
                                || t_ar_aging_rpt_gt_tab (
                                       SQL%BULK_EXCEPTIONS (l_error_index).ERROR_INDEX).CLASS
                                || ' -- '
                                || SQLERRM
                                || '-----> '
                                || SQLCODE);
                        --                  lv_status := 3;
                        END LOOP;
                    WHEN OTHERS
                    THEN
                        lv_err_msg   :=
                               'Error Others while inserting into XXD_MSC_MASS_UPDATE_GT table'
                            || SQLERRM;

                        FOR l_error_index IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                        LOOP
                            lv_err_msg   :=
                                   'when others Error while Inserting XXD_AR_AGING_REPORT_GT Table : '
                                || SQLCODE
                                || ' ---> '
                                || SQLERRM;
                            LOG (
                                   'when others  Error while INSERTING into XXD_AR_AGING_REPORT_GT Table : '
                                || t_ar_aging_rpt_gt_tab (
                                       SQL%BULK_EXCEPTIONS (l_error_index).ERROR_INDEX).payment_schedule_id
                                || ' -- '
                                || t_ar_aging_rpt_gt_tab (
                                       SQL%BULK_EXCEPTIONS (l_error_index).ERROR_INDEX).class
                                || ' -- '
                                || SQLERRM
                                || '-----> '
                                || SQLCODE);
                        END LOOP;
                END;

                EXIT WHEN t_ar_aging_rpt_gt_tab.COUNT = 0;
            END LOOP;

            CLOSE cur_aging_details;
        END LOOP;

        -- Start for CCR0009092----
        DELETE FROM xxdo.xxd_ar_aging_report_gt gt
              WHERE 1 = 1 AND gt.request_id = l_comm_req_id;

        -- End for CCR0009092----



        -- CCR0006140

        commit_ctr   := 0;

        -- CCR0006140
        --FOR x IN c1  Comment for CCR0009092
        --LOOP  Comment for CCR0009092
        /*
              IF UPPER (x.aging_report_heading1) = UPPER ('Dispute Bucket')
                 THEN
                    IF x.bucket_sequence_num = 0
                    THEN
                       UPDATE xxdo.xxd_ar_aging_report_gt xaarg
                          SET aging_bucket1 = x.amount_in_dispute
                        WHERE xaarg.customer_number = x.customer_number
                          AND xaarg.payment_schedule_id = x.payment_schedule_id;
                    ELSIF x.bucket_sequence_num = 1
                    THEN
                       UPDATE xxdo.xxd_ar_aging_report_gt xaarg
                          SET aging_bucket2 = x.amount_due
                        WHERE xaarg.customer_number = x.customer_number
                          AND xaarg.payment_schedule_id = x.payment_schedule_id;
                    ELSIF x.bucket_sequence_num = 2
                    THEN
                       UPDATE xxdo.xxd_ar_aging_report_gt xaarg
                          SET aging_bucket3 = x.amount_due
                        WHERE xaarg.customer_number = x.customer_number
                          AND xaarg.payment_schedule_id = x.payment_schedule_id;
                    ELSIF x.bucket_sequence_num = 3
                    THEN
                       UPDATE xxdo.xxd_ar_aging_report_gt xaarg
                          SET aging_bucket4 = x.amount_due
                        WHERE xaarg.customer_number = x.customer_number
                          AND xaarg.payment_schedule_id = x.payment_schedule_id;
                    ELSIF x.bucket_sequence_num = 4
                    THEN
                       UPDATE xxdo.xxd_ar_aging_report_gt xaarg
                          SET aging_bucket5 = x.amount_due
                        WHERE xaarg.customer_number = x.customer_number
                          AND xaarg.payment_schedule_id = x.payment_schedule_id;
                    ELSIF x.bucket_sequence_num = 5
                    THEN
                       UPDATE xxdo.xxd_ar_aging_report_gt xaarg
                          SET aging_bucket6 = x.amount_due
                        WHERE xaarg.customer_number = x.customer_number
                          AND xaarg.payment_schedule_id = x.payment_schedule_id;
                    ELSIF x.bucket_sequence_num = 6
                    THEN
                       UPDATE xxdo.xxd_ar_aging_report_gt xaarg
                          SET aging_bucket7 = x.amount_due
                        WHERE xaarg.customer_number = x.customer_number
                          AND xaarg.payment_schedule_id = x.payment_schedule_id;
                    ELSIF x.bucket_sequence_num = 7
                    THEN
                       UPDATE xxdo.xxd_ar_aging_report_gt xaarg
                          SET aging_bucket8 = x.amount_due
                        WHERE xaarg.customer_number = x.customer_number
                          AND xaarg.payment_schedule_id = x.payment_schedule_id;
                    ELSIF x.bucket_sequence_num = 8
                    THEN
                       UPDATE xxdo.xxd_ar_aging_report_gt xaarg
                          SET aging_bucket9 = x.amount_due
                        WHERE xaarg.customer_number = x.customer_number
                          AND xaarg.payment_schedule_id = x.payment_schedule_id;
                    ELSIF x.bucket_sequence_num = 9
                    THEN
                       UPDATE xxdo.xxd_ar_aging_report_gt xaarg
                          SET aging_bucket10 = x.amount_due
                        WHERE xaarg.customer_number = x.customer_number
                          AND xaarg.payment_schedule_id = x.payment_schedule_id;
                    END IF;
                 ELSE
        */
        ---Start Comment for CCR0009092
        /* IF x.bucket_sequence_num = 0
         THEN
            UPDATE xxdo.xxd_ar_aging_report_gt xaarg
               SET aging_bucket1 = x.amount_due
             WHERE xaarg.customer_number = x.customer_number
               AND xaarg.payment_schedule_id = x.payment_schedule_id
               AND transaction_name = x.transaction_name
               AND amount_due = x.amount_due;
         ELSIF x.bucket_sequence_num = 1
         THEN
            UPDATE xxdo.xxd_ar_aging_report_gt xaarg
               SET aging_bucket2 = x.amount_due
             WHERE xaarg.customer_number = x.customer_number
               AND xaarg.payment_schedule_id = x.payment_schedule_id
               AND transaction_name = x.transaction_name
               AND amount_due = x.amount_due;
         ELSIF x.bucket_sequence_num = 2
         THEN
            UPDATE xxdo.xxd_ar_aging_report_gt xaarg
               SET aging_bucket3 = x.amount_due
             WHERE xaarg.customer_number = x.customer_number
               AND xaarg.payment_schedule_id = x.payment_schedule_id
                and transaction_name = x.transaction_name
               AND amount_due = x.amount_due;
         ELSIF x.bucket_sequence_num = 3
         THEN
            UPDATE xxdo.xxd_ar_aging_report_gt xaarg
               SET aging_bucket4 = x.amount_due
             WHERE xaarg.customer_number = x.customer_number
               AND xaarg.payment_schedule_id = x.payment_schedule_id
                and transaction_name = x.transaction_name
               AND amount_due = x.amount_due;
         ELSIF x.bucket_sequence_num = 4
         THEN
            UPDATE xxdo.xxd_ar_aging_report_gt xaarg
               SET aging_bucket5 = x.amount_due
             WHERE xaarg.customer_number = x.customer_number
               AND xaarg.payment_schedule_id = x.payment_schedule_id
                and transaction_name = x.transaction_name
               AND amount_due = x.amount_due;
         ELSIF x.bucket_sequence_num = 5
         THEN
            UPDATE xxdo.xxd_ar_aging_report_gt xaarg
               SET aging_bucket6 = x.amount_due
             WHERE xaarg.customer_number = x.customer_number
               AND xaarg.payment_schedule_id = x.payment_schedule_id
                and transaction_name = x.transaction_name
               AND amount_due = x.amount_due;
         ELSIF x.bucket_sequence_num = 6
         THEN
            UPDATE xxdo.xxd_ar_aging_report_gt xaarg
               SET aging_bucket7 = x.amount_due
             WHERE xaarg.customer_number = x.customer_number
               AND xaarg.payment_schedule_id = x.payment_schedule_id
                and transaction_name = x.transaction_name
               AND amount_due = x.amount_due;
         ELSIF x.bucket_sequence_num = 7
         THEN
            UPDATE xxdo.xxd_ar_aging_report_gt xaarg
               SET aging_bucket8 = x.amount_due
             WHERE xaarg.customer_number = x.customer_number
               AND xaarg.payment_schedule_id = x.payment_schedule_id
                and transaction_name = x.transaction_name
               AND amount_due = x.amount_due;
         ELSIF x.bucket_sequence_num = 8
         THEN
            UPDATE xxdo.xxd_ar_aging_report_gt xaarg
               SET aging_bucket9 = x.amount_due
             WHERE xaarg.customer_number = x.customer_number
               AND xaarg.payment_schedule_id = x.payment_schedule_id
                and transaction_name = x.transaction_name
               AND amount_due = x.amount_due;
         ELSIF x.bucket_sequence_num = 9
         THEN
            UPDATE xxdo.xxd_ar_aging_report_gt xaarg
               SET aging_bucket10 = x.amount_due
             WHERE xaarg.customer_number = x.customer_number
               AND xaarg.payment_schedule_id = x.payment_schedule_id
                and transaction_name = x.transaction_name
               AND amount_due = x.amount_due;
         END IF;
      commit_ctr := commit_ctr + 1;

      IF commit_ctr > 1000
      THEN
         COMMIT;
         commit_ctr := 0;
      END IF;
   END LOOP;*/
        ---End Comment for CCR0009092
        ---Start Change for  CCR0009092

        UPDATE xxdo.xxd_ar_aging_report_gt xaarg
           SET aging_bucket1   = amount_due
         WHERE 1 = 1 AND bucket_sequence_num = 0;

        UPDATE xxdo.xxd_ar_aging_report_gt xaarg
           SET aging_bucket2   = amount_due
         WHERE 1 = 1 AND bucket_sequence_num = 1;

        UPDATE xxdo.xxd_ar_aging_report_gt xaarg
           SET aging_bucket3   = amount_due
         WHERE 1 = 1 AND bucket_sequence_num = 2;

        UPDATE xxdo.xxd_ar_aging_report_gt xaarg
           SET aging_bucket4   = amount_due
         WHERE 1 = 1 AND bucket_sequence_num = 3;

        UPDATE xxdo.xxd_ar_aging_report_gt xaarg
           SET aging_bucket5   = amount_due
         WHERE 1 = 1 AND bucket_sequence_num = 4;

        UPDATE xxdo.xxd_ar_aging_report_gt xaarg
           SET aging_bucket6   = amount_due
         WHERE 1 = 1 AND bucket_sequence_num = 5;

        UPDATE xxdo.xxd_ar_aging_report_gt xaarg
           SET aging_bucket7   = amount_due
         WHERE 1 = 1 AND bucket_sequence_num = 6;

        UPDATE xxdo.xxd_ar_aging_report_gt xaarg
           SET aging_bucket8   = amount_due
         WHERE 1 = 1 AND bucket_sequence_num = 7;

        UPDATE xxdo.xxd_ar_aging_report_gt xaarg
           SET aging_bucket9   = amount_due
         WHERE 1 = 1 AND bucket_sequence_num = 8;

        UPDATE xxdo.xxd_ar_aging_report_gt xaarg
           SET aging_bucket10   = amount_due
         WHERE 1 = 1 AND bucket_sequence_num = 9;

        ---End Change for  CCR0009092

        COMMIT;
        --         END IF;
        commit_ctr   := 0;


        FOR rec_aging_buckets IN cur_aging_buckets
        LOOP
            FOR x IN c1
            LOOP
                --IF rec_aging_buckets.report_heading1 = 'Dispute Bucket' THEN
                IF UPPER (rec_aging_buckets.report_heading1) =
                   UPPER ('Dispute Bucket')
                THEN
                    UPDATE xxdo.xxd_ar_aging_report_gt xaarg
                       SET aging_bucket1   = x.amount_in_dispute
                     WHERE     xaarg.customer_number = x.customer_number
                           AND xaarg.payment_schedule_id =
                               x.payment_schedule_id
                           AND transaction_name = x.transaction_name
                           AND amount_due = x.amount_due;
                END IF;

                commit_ctr   := commit_ctr + 1;

                IF commit_ctr > 100
                THEN
                    COMMIT;
                    commit_ctr   := 0;
                END IF;
            END LOOP;
        END LOOP;



        COMMIT;
        -- end for CCR0006140
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            LOG ('Error in Before Report Package - ' || SQLERRM);
            RETURN NULL;
    END;
END xxd_ar_aging_enhanced_rpt_pkg;
/
