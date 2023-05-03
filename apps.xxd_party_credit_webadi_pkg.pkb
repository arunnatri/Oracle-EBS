--
-- XXD_PARTY_CREDIT_WEBADI_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:02 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PARTY_CREDIT_WEBADI_PKG"
IS
    /*************************************************************************************************************
      Package      : XXD_PARTY_CREDIT_WEBADI_PKG
      Design       : This package is called by "Deckers Party WEBADI - Credit"
                     Package is used to update/create credit profile at party level and
                     also update's customer category on party if required
      Notes        :
      Modification :
     ======================================================================================
      Date          Version#   Name                    Comments
     ======================================================================================
      25-May-2017    1.0       Kranthi Bollam           Initial Version
      26-SEP-2017    1.1       Srinath Siricilla        CCR0006648    Additional Columns to WEBADI
      04-04-2019     1.2       Srinath Siricilla        CCR0007819    Adding Columns and enabling
                                                                      Multiple currency upload
      19-12-2019     1.3       Tejaswi gangumalla       CCR0008343    Credit Line field is going to NULL,
                                                                      if there is a change in Profile class in Webadi
      06-MAY-2020    1.4       Showkath Ali             UAT Defect#28 Party level credit limit created with USD
                                                                      currency instead of Profile currency
    ****************************************************************************************************************/

    --Global Variables
    --    gn_seq_id                       NUMBER          :=  0;
    --Constants
    gv_package_name   CONSTANT VARCHAR2 (30)
                                   := 'XXD_PARTY_CREDIT_WEBADI_PKG.' ;
    gn_user_id        CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id       CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id         CONSTANT NUMBER := fnd_profile.VALUE ('ORG_ID');  -- 95;
    gn_resp_id        CONSTANT NUMBER := fnd_global.resp_id;          --51166;
    gn_resp_appl_id   CONSTANT NUMBER := fnd_global.resp_appl_id;       --222;
    gn_request_id     CONSTANT NUMBER := fnd_global.conc_request_id;
    ex_no_recips               EXCEPTION;
    v_def_mail_recips          do_mail_utils.tbl_recips;


    /*Start of Change for CCR0006648*/
    FUNCTION is_researcher_valid (pv_researcher_name IN VARCHAR2, x_researcher_id OUT NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    --l_researcher_id NUMBER;
    BEGIN
        SELECT jrre.resource_id
          INTO x_researcher_id
          FROM jtf_rs_resource_extns_vl jrre
         WHERE     1 = 1
               AND TRUNC (SYSDATE) BETWEEN jrre.start_date_active
                                       AND TRUNC (
                                               NVL (jrre.end_date_active,
                                                    SYSDATE))
               AND jrre.resource_id > 0
               AND (jrre.category = 'EMPLOYEE' OR jrre.category = 'PARTNER' OR jrre.category = 'PARTY')
               AND UPPER (TRIM (jrre.resource_name)) =
                   UPPER (TRIM (pv_researcher_name));

        --dbms_output.put_line('Value Fetching - Function '||x_researcher_id);
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid researcher name ' || pv_researcher_name;
            --dbms_output.put_line('Value Fetching - No data Function');
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' Multiple names exist with same researcher name. '
                || pv_researcher_name;
            --dbms_output.put_line('Value Fetching - Too Many Function');
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   ' '
                || 'Exception - Invalid researcher name : '
                || pv_researcher_name
                || ' '
                || SQLERRM;
            --dbms_output.put_line('Value Fetching - Exception Function '||SQLERRM);
            RETURN FALSE;
    END;

    /*End of Change for CCR0006648*/

    --Get email ID Function
    FUNCTION get_email_ids (pv_lookup_type VARCHAR2, pv_inst_name VARCHAR2)
        RETURN do_mail_utils.tbl_recips
    IS
        v_def_mail_recips   do_mail_utils.tbl_recips;

        CURSOR recips_cur IS
            SELECT xx.email_id
              FROM (SELECT flv.meaning email_id
                      FROM fnd_lookup_values flv
                     WHERE     1 = 1
                           AND flv.lookup_type = pv_lookup_type
                           AND flv.enabled_flag = 'Y'
                           AND flv.language = USERENV ('LANG')
                           AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                           NVL (
                                                               flv.start_date_active,
                                                               SYSDATE))
                                                   AND TRUNC (
                                                           NVL (
                                                               flv.end_date_active,
                                                               SYSDATE))
                    UNION
                    SELECT NVL (fu.email_address, ppx.email_address) email_id
                      FROM fnd_user fu, per_people_x ppx
                     WHERE     1 = 1
                           AND fu.user_id = gn_user_id
                           AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                           NVL (
                                                               fu.start_date,
                                                               SYSDATE))
                                                   AND TRUNC (
                                                           NVL (fu.end_date,
                                                                SYSDATE))
                           AND fu.employee_id = ppx.person_id(+)) xx
             WHERE xx.email_id IS NOT NULL;

        CURSOR submitted_by_cur IS
            SELECT NVL (fu.email_address, ppx.email_address) email_id
              FROM fnd_user fu, per_people_x ppx
             WHERE     1 = 1
                   AND fu.user_id = gn_user_id
                   AND TRUNC (SYSDATE) BETWEEN fu.start_date
                                           AND TRUNC (
                                                   NVL (fu.end_date, SYSDATE))
                   AND fu.employee_id = ppx.person_id(+);
    BEGIN
        v_def_mail_recips.DELETE;

        IF pv_inst_name = 'PRODUCTION'
        THEN
            FOR recips_rec IN recips_cur
            LOOP
                v_def_mail_recips (v_def_mail_recips.COUNT + 1)   :=
                    recips_rec.email_id;
            END LOOP;

            RETURN v_def_mail_recips;
        ELSE
            FOR submitted_by_rec IN submitted_by_cur
            LOOP
                v_def_mail_recips (v_def_mail_recips.COUNT + 1)   :=
                    submitted_by_rec.email_id;
            END LOOP;

            RETURN v_def_mail_recips;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            v_def_mail_recips (1)   := '';
            RETURN v_def_mail_recips;
    END get_email_ids;

    PROCEDURE send_email_proc (pn_batch_id IN NUMBER)
    IS
        lv_inst_name   VARCHAR2 (30) := NULL;
        lv_msg         VARCHAR2 (4000) := NULL;
        ln_ret_val     NUMBER := 0;
        lv_out_line    VARCHAR2 (4000);

        CURSOR email_cur IS
            SELECT stg.*--,fu.user_name
                        , DECODE (stg.status,  'E', 'Error',  'S', 'Success',  'N', 'New',  'Error') status_desc
              FROM xxdo.xxd_party_credit_prof_upd_stg stg
             --,apps.fnd_user fu
             WHERE     1 = 1
                   --AND stg.created_by = fu.user_id
                   AND stg.created_by = gn_user_id
                   AND stg.batch_id = pn_batch_id;
    BEGIN
        BEGIN
            SELECT DECODE (applications_system_name, 'EBSPROD', 'PRODUCTION', 'TEST(' || applications_system_name || ')') applications_system_name
              INTO lv_inst_name
              FROM fnd_product_groups;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_inst_name   := '';
                lv_msg         :=
                       'Error getting the instance name in send_email_proc procedure. Error is '
                    || SQLERRM;
                raise_application_error (-20010, lv_msg);
        END;

        v_def_mail_recips   :=
            get_email_ids ('XXD_CUST_CREDIT_PROF_UPD_EMAIL', lv_inst_name);

        IF v_def_mail_recips.COUNT < 1
        THEN
            RAISE ex_no_recips;
        END IF;

        apps.do_mail_utils.send_mail_header (fnd_profile.VALUE ('DO_DEF_ALERT_SENDER'), v_def_mail_recips, 'Deckers Party WEBADI - Credit Upload Result. ' || ' Email generated from ' || lv_inst_name || ' instance'
                                             , ln_ret_val);

        do_mail_utils.send_mail_line (
            'Content-Type: multipart/mixed; boundary=boundarystring',
            ln_ret_val);
        do_mail_utils.send_mail_line ('', ln_ret_val);                 --Added
        do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
        do_mail_utils.send_mail_line ('', ln_ret_val);                 --Added
        --            do_mail_utils.send_mail_line ('Content-Type: text/plain', ln_ret_val); --Not Required
        --            do_mail_utils.send_mail_line ('', ln_ret_val); --Not Required
        do_mail_utils.send_mail_line (
            'Please see attached the result of the Deckers Party credit profile update WEBADI upload program.',
            ln_ret_val);
        do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
        do_mail_utils.send_mail_line ('Content-Type: text/xls', ln_ret_val);
        do_mail_utils.send_mail_line (
               'Content-Disposition: attachment; filename="Deckers_Party_webadi_credit_'
            || TO_CHAR (SYSDATE, 'RRRRMMDD_HH24MISS')
            || '.xls"',
            ln_ret_val);
        do_mail_utils.send_mail_line ('', ln_ret_val);

        apps.do_mail_utils.send_mail_line (
               'Non Brand Customer Number'              --Added for change 1.1
            || CHR (9)
            || 'Credit Analyst'
            || CHR (9)
            || 'Next Scheduled Review Date'
            || CHR (9)
            || 'Customer Category'
            || CHR (9)
            /*Start of Change for CCR0006648*/
            || 'Profile Class Name'
            || CHR (9)
            || 'Currency'
            || CHR (9)
            || 'Credit Limit'
            || CHR (9)
            || 'Order Credit Limit'
            || CHR (9)
            || 'Credit Classification'
            || CHR (9)
            || 'Review Cycle'
            || CHR (9)
            || 'US Ven Vio Researcher'
            || CHR (9)
            || 'US Freight Researcher'
            || CHR (9)
            || 'US Discount Researcher'
            || CHR (9)
            || 'US Credit Memo Researcher'
            || CHR (9)
            || 'US Short Payment Researcher'
            || CHR (9)
            /*End of Change for CCR0006648*/
            /* Start of change for 1.2 */
            || 'Last Review Date'
            || CHR (9)
            || 'Safe Number'
            || CHR (9)
            || 'Parent Number'
            || CHR (9)
            || 'Ultimate Parent Number'
            || CHR (9)
            || 'Credit Check Flag'
            || CHR (9)
            || 'Buying Group Customer Number'
            || CHR (9)
            || 'Customer Membership Number'
            || CHR (9)
            || 'Buying group VAT Number'
            || CHR (9)
            /* End of change for 1.2 */
            || 'Status'
            || CHR (9)
            || 'Error Message'
            || CHR (9),
            ln_ret_val);

        FOR email_rec IN email_cur
        LOOP
            lv_out_line   := NULL;
            lv_out_line   :=
                   email_rec.nonbrand_cust_no      --Non Brand Customer Number
                || CHR (9)
                || email_rec.credit_analyst                   --Credit Analyst
                || CHR (9)
                || email_rec.next_scheduled_review_date --Next Credit Review Data
                || CHR (9)
                || email_rec.customer_category             --Customer Category
                || CHR (9)
                /*Start of Change for CCR0006648*/
                || email_rec.profile_class
                || CHR (9)
                || email_rec.currency_code
                || CHR (9)
                || email_rec.credit_limit
                || CHR (9)
                || email_rec.order_credit_limit
                || CHR (9)
                || email_rec.credit_classification
                || CHR (9)
                || email_rec.review_cycle
                || CHR (9)
                || email_rec.us_ven_vio_researcher
                || CHR (9)
                || email_rec.us_freight_researcher
                || CHR (9)
                || email_rec.us_discount_researcher
                || CHR (9)
                || email_rec.us_credit_memo_researcher
                || CHR (9)
                || email_rec.us_short_payment_researcher
                || CHR (9)
                /*End of Change for CCR0006648*/
                /* Start of change for 1.2 */
                || email_rec.Last_Review_Date
                || CHR (9)
                || email_rec.Safe_Number
                || CHR (9)
                || email_rec.Parent_Number
                || CHR (9)
                || email_rec.Ultimate_Parent_Number
                || CHR (9)
                || email_rec.credit_checking
                || CHR (9)
                || email_rec.buying_group_cust_num
                || CHR (9)
                || email_rec.cust_membership_num
                || CHR (9)
                || email_rec.buying_group_vat_num
                || CHR (9)
                /* End of change for 1.2 */
                || email_rec.status_desc                              --Status
                || CHR (9)
                || email_rec.error_message                     --Error Message
                || CHR (9);

            apps.do_mail_utils.send_mail_line (lv_out_line, ln_ret_val);
        END LOOP;

        apps.do_mail_utils.send_mail_close (ln_ret_val);
    EXCEPTION
        WHEN OTHERS
        THEN
            do_mail_utils.send_mail_close (ln_ret_val);
            lv_msg   :=
                   'In When others exception in email_to_dir_payables procedure. Error is: '
                || SQLERRM;
            raise_application_error (-20010, lv_msg);
    END send_email_proc;

    --procedure to update profile
    PROCEDURE update_profile (pn_cust_account_profile_id IN NUMBER, pn_object_version_number IN NUMBER, pn_credit_analyst_id IN NUMBER, pv_next_sched_review_date IN VARCHAR2, pv_last_sched_review_date IN VARCHAR2 -- Added for 1.2 Change
                                                                                                                                                                                                                    , pv_credit_checking IN VARCHAR2 -- Added for 1.2 Change
                                                                                                                                                                                                                                                    , pn_profile_class_id IN NUMBER -- Added for CCR0006648
                                                                                                                                                                                                                                                                                   , pv_credit_classification IN VARCHAR2 -- Added for CCR0006648
                                                                                                                                                                                                                                                                                                                         , pv_review_cycle IN VARCHAR2 -- Added for CCR0006648
                              , pn_tolerance IN NUMBER -- Added for CCR0006648
                                                      , xv_api_ret_status OUT VARCHAR2, xv_api_ret_message OUT VARCHAR2)
    IS
        p_customer_profile_rec_type   hz_customer_profile_v2pub.customer_profile_rec_type;
        p_cust_account_profile_id     NUMBER := NULL;
        p_object_version_number       NUMBER := NULL;
        x_return_status               VARCHAR2 (2000) := NULL;
        x_msg_count                   NUMBER := 0;
        x_msg_data                    VARCHAR2 (2000) := NULL;
    BEGIN
        --        mo_global.init('AR');
        --        fnd_global.apps_initialize(
        --                                   user_id      => gn_user_id
        --                                  ,resp_id      => gn_resp_id
        --                                  ,resp_appl_id => gn_resp_appl_id
        --                                  );
        --        mo_global.set_policy_context('S',gn_org_id);

        p_customer_profile_rec_type.cust_account_profile_id   :=
            pn_cust_account_profile_id;
        p_object_version_number   := pn_object_version_number; --Pass the current object version number for the cust account profile ID

        IF pv_next_sched_review_date IS NOT NULL
        THEN
            p_customer_profile_rec_type.next_credit_review_date   :=
                TRUNC (TO_DATE (pv_next_sched_review_date, 'DD-MON-RRRR'));
        END IF;

        IF pn_credit_analyst_id IS NOT NULL
        THEN
            p_customer_profile_rec_type.credit_analyst_id   :=
                pn_credit_analyst_id;
        ELSE
            p_customer_profile_rec_type.credit_analyst_id   := NULL;
        END IF;

        /* Start of Change for CCR0006648 */
        IF pn_profile_class_id IS NOT NULL
        THEN
            p_customer_profile_rec_type.profile_class_id   :=
                pn_profile_class_id;
        END IF;

        IF pv_credit_classification IS NOT NULL
        THEN
            p_customer_profile_rec_type.credit_classification   :=
                pv_credit_classification;
        END IF;

        IF pv_review_cycle IS NOT NULL
        THEN
            p_customer_profile_rec_type.review_cycle   := pv_review_cycle;
        END IF;

        IF pn_tolerance IS NOT NULL
        THEN
            p_customer_profile_rec_type.tolerance   := pn_tolerance;
        END IF;

        /* End of Change for CCR0006648 */

        -- Start of 1.2 change

        IF pv_last_sched_review_date IS NOT NULL
        THEN
            p_customer_profile_rec_type.last_credit_review_date   :=
                TRUNC (TO_DATE (pv_last_sched_review_date, 'DD-MON-RRRR'));
        END IF;

        IF pv_credit_checking IS NOT NULL
        THEN
            p_customer_profile_rec_type.credit_checking   :=
                pv_credit_checking;
        END IF;

        -- End of 1.2 Change

        --API Call to update credit profile at party level
        hz_customer_profile_v2pub.update_customer_profile (
            p_init_msg_list           => fnd_api.g_true,
            p_customer_profile_rec    => p_customer_profile_rec_type,
            p_object_version_number   => p_object_version_number,
            x_return_status           => x_return_status,
            x_msg_count               => x_msg_count,
            x_msg_data                => x_msg_data);

        IF x_return_status = fnd_api.g_ret_sts_success
        THEN
            xv_api_ret_status    := x_return_status;
            xv_api_ret_message   := NULL;
        ELSE
            xv_api_ret_status    := x_return_status;

            FOR i IN 1 .. x_msg_count
            LOOP
                x_msg_data   :=
                       x_msg_data
                    || '.'
                    || fnd_msg_pub.get (p_msg_index   => i,
                                        p_encoded     => fnd_api.g_false); --'F');
            END LOOP;

            xv_api_ret_message   := SUBSTR (x_msg_data, 1, 2000);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            xv_api_ret_status   := 'Z';
            xv_api_ret_message   :=
                   'Exception while updating profile. Error is '
                || SUBSTR (SQLERRM, 1, 1900);
    END update_profile;

    --Procedure to create profile at party level
    PROCEDURE create_profile (pn_party_id                 IN     NUMBER,
                              pn_credit_analyst_id        IN     NUMBER,
                              pv_next_sched_review_date   IN     VARCHAR2,
                              pv_last_sched_review_date   IN     VARCHAR2 -- Added for 1.2 Change
                                                                         ,
                              pv_credit_checking          IN     VARCHAR2 -- Added for 1.2 Change
                                                                         ,
                              pn_profile_class_id         IN     NUMBER /*Added for CCR0006648*/
                                                                       ,
                              pv_credit_classification    IN     VARCHAR2 /*Added for CCR0006648*/
                                                                         ,
                              pv_review_cycle             IN     VARCHAR2 /*Added for CCR0006648*/
                                                                         ,
                              xn_cust_acct_prof_id           OUT NUMBER,
                              xv_api_ret_status              OUT VARCHAR2,
                              xv_api_ret_message             OUT VARCHAR2)
    IS
        p_customer_profile_rec_type   hz_customer_profile_v2pub.customer_profile_rec_type;
        x_cust_account_profile_id     NUMBER := NULL;
        x_return_status               VARCHAR2 (2000) := NULL;
        x_msg_count                   NUMBER := 0;
        x_msg_data                    VARCHAR2 (2000) := NULL;
    --        -- < Variables added to suppress ARHDQMSS error >------------------------
    --        MSGDATA varchar2(32000);
    --        MSGNAME varchar2(30);
    --        MSGAPP varchar2(50);
    --        MSGENCODED varchar2(32100);
    --        MSGENCODEDLEN number(6);
    --        MSGNAMELOC number(6);
    --        MSGTEXTLOC number(6);
    --------------------------------------------------------------------

    BEGIN
        --        mo_global.init('AR');
        --        fnd_global.apps_initialize(
        --                                   user_id      => gn_user_id
        --                                  ,resp_id      => gn_resp_id
        --                                  ,resp_appl_id => gn_resp_appl_id
        --                                  );
        --        mo_global.set_policy_context('S',gn_org_id);
        p_customer_profile_rec_type.party_id            := pn_party_id; --Creating profile at party level

        IF pv_next_sched_review_date IS NOT NULL
        THEN
            p_customer_profile_rec_type.next_credit_review_date   :=
                TRUNC (TO_DATE (pv_next_sched_review_date, 'DD-MON-RRRR')); --'01-JUN-2017';
        END IF;

        IF pn_credit_analyst_id IS NOT NULL
        THEN
            p_customer_profile_rec_type.credit_analyst_id   :=
                pn_credit_analyst_id;                             --100011199;
        END IF;

        /*Start of Change for CCR0006648*/
        IF pn_profile_class_id IS NOT NULL
        THEN
            p_customer_profile_rec_type.profile_class_id   :=
                pn_profile_class_id;                              --100011199;
        END IF;

        IF pv_credit_classification IS NOT NULL
        THEN
            p_customer_profile_rec_type.credit_classification   :=
                pv_credit_classification;
        END IF;

        IF pv_review_cycle IS NOT NULL
        THEN
            p_customer_profile_rec_type.review_cycle   := pv_review_cycle;
        END IF;

        /*End of Change for CCR0006648*/

        -- Start of 1.2 Change

        IF pv_next_sched_review_date IS NOT NULL
        THEN
            p_customer_profile_rec_type.last_credit_review_date   :=
                TRUNC (TO_DATE (pv_last_sched_review_date, 'DD-MON-RRRR')); --'01-JUN-2017';
        END IF;

        IF pv_credit_checking IS NOT NULL
        THEN
            p_customer_profile_rec_type.credit_checking   :=
                pv_credit_checking;
        END IF;

        -- End of 1.2 Change

        p_customer_profile_rec_type.created_by_module   := 'TCA_V2_API';
        hz_customer_profile_v2pub.create_customer_profile (
            p_init_msg_list             => fnd_api.g_true,
            p_customer_profile_rec      => p_customer_profile_rec_type,
            p_create_profile_amt        => fnd_api.g_true,
            x_cust_account_profile_id   => x_cust_account_profile_id,
            x_return_status             => x_return_status,
            x_msg_count                 => x_msg_count,
            x_msg_data                  => x_msg_data);

        IF x_return_status = fnd_api.g_ret_sts_success
        THEN
            xv_api_ret_status      := x_return_status;
            xv_api_ret_message     := NULL;
            xn_cust_acct_prof_id   := x_cust_account_profile_id;
        ELSE
            xv_api_ret_status    := x_return_status;

            FOR i IN 1 .. x_msg_count
            LOOP
                x_msg_data   :=
                       x_msg_data
                    || '.'
                    || fnd_msg_pub.get (p_msg_index   => i,
                                        p_encoded     => fnd_api.g_false); --'F');
            END LOOP;

            xv_api_ret_message   := SUBSTR (x_msg_data, 1, 2000);
        END IF;
    --        --< This part of the code is added to suppress the error "Only one pending Concurrent Request is allowed for ARHDQMSS at any given time"------
    --        MSGENCODED := fnd_message.get_encoded();
    --        MSGENCODEDLEN := LENGTH(MSGENCODED);
    --        MSGNAMELOC := INSTR(MSGENCODED, chr(0));
    --        MSGAPP := SUBSTR(MSGENCODED, 1, MSGNAMELOC-1);
    --        MSGENCODED := SUBSTR(MSGENCODED, MSGNAMELOC+1, MSGENCODEDLEN);
    --        MSGENCODEDLEN := LENGTH(MSGENCODED);
    --        MSGTEXTLOC := INSTR(MSGENCODED, chr(0));
    --        MSGNAME := SUBSTR(MSGENCODED, 1, MSGTEXTLOC-1);
    --        IF(MSGNAME <> 'CONC-SINGLE PENDING REQUEST')
    --        THEN
    --            xv_api_ret_message := xv_api_ret_message;
    --        --fnd_message.set_name(MSGAPP, MSGNAME);
    --        ELSE
    --            xv_api_ret_message := NULL;
    --        END IF;

    ---End of suppression of error message

    --commit;
    EXCEPTION
        WHEN OTHERS
        THEN
            xv_api_ret_status   := 'Z';
            xv_api_ret_message   :=
                   'Exception while creating profile. Error is '
                || SUBSTR (SQLERRM, 1, 1900);
    END create_profile;

    -- Procedure to create Customer Profile Amounts

    PROCEDURE create_cust_profile_amts (pn_cust_acct_profile_id IN NUMBER, pn_trx_credit_limit IN NUMBER, pn_overall_credit_limit IN NUMBER, pv_Currency_code IN VARCHAR2, xn_cust_acct_profile_amt_id OUT NUMBER, xv_api_ret_status OUT VARCHAR2
                                        , xv_api_ret_message OUT VARCHAR2)
    IS
        p_cust_profile_amt_rec_type   hz_customer_profile_v2pub.cust_profile_amt_rec_type;
        x_return_status               VARCHAR2 (2000) := NULL;
        x_msg_count                   NUMBER := 0;
        x_msg_data                    VARCHAR2 (2000) := NULL;
    BEGIN
        IF pn_cust_acct_profile_id IS NOT NULL
        THEN
            p_cust_profile_amt_rec_type.cust_account_profile_id   :=
                pn_cust_acct_profile_id;
        END IF;

        IF pn_trx_credit_limit IS NOT NULL
        THEN
            p_cust_profile_amt_rec_type.trx_credit_limit   :=
                pn_trx_credit_limit;
        END IF;

        IF pn_overall_credit_limit IS NOT NULL
        THEN
            p_cust_profile_amt_rec_type.overall_credit_limit   :=
                pn_overall_credit_limit;
        END IF;

        IF pv_currency_code IS NOT NULL
        THEN
            p_cust_profile_amt_rec_type.currency_code   := pv_currency_code;
        END IF;

        p_cust_profile_amt_rec_type.cust_account_id   := -1;

        --API Call to create proflie amounts at party level

        hz_customer_profile_v2pub.create_cust_profile_amt (
            p_init_msg_list              => FND_API.G_FALSE,
            p_check_foreign_key          => FND_API.G_TRUE,
            p_cust_profile_amt_rec       => p_cust_profile_amt_rec_type,
            x_cust_acct_profile_amt_id   => xn_cust_acct_profile_amt_id,
            x_return_status              => x_return_status,
            x_msg_count                  => x_msg_count,
            x_msg_data                   => x_msg_data);

        IF x_return_status = fnd_api.g_ret_sts_success
        THEN
            xv_api_ret_status    := x_return_status;
            xv_api_ret_message   := NULL;
        ELSE
            xv_api_ret_status    := x_return_status;

            FOR i IN 1 .. x_msg_count
            LOOP
                x_msg_data   :=
                       x_msg_data
                    || '.'
                    || fnd_msg_pub.get (p_msg_index   => i,
                                        p_encoded     => fnd_api.g_false); --'F');
            END LOOP;

            xv_api_ret_message   := SUBSTR (x_msg_data, 1, 2000);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            xv_api_ret_status   := 'Z';
            xv_api_ret_message   :=
                   'Exception while creating Customer profile amounts. Error is '
                || SUBSTR (SQLERRM, 1, 1900);
    END create_cust_profile_amts;

    -- procedure to update Customer profile amounts
    /*Start of Change for CCR0006648*/
    PROCEDURE update_cust_profile_amts (pn_cust_acct_profile_amt_id IN NUMBER, pn_object_version_number IN NUMBER, pn_trx_credit_limit IN NUMBER, pn_overall_credit_limit IN NUMBER, pv_Currency_code IN VARCHAR2, xv_api_ret_status OUT VARCHAR2
                                        , xv_api_ret_message OUT VARCHAR2)
    IS
        p_cust_profile_amt_rec_type   hz_customer_profile_v2pub.cust_profile_amt_rec_type;
        p_cust_acct_profile_amt_id    NUMBER := NULL;
        p_object_version_number       NUMBER := NULL;
        x_return_status               VARCHAR2 (2000) := NULL;
        x_msg_count                   NUMBER := 0;
        x_msg_data                    VARCHAR2 (2000) := NULL;
    BEGIN
        --        mo_global.init('AR');
        --        fnd_global.apps_initialize(
        --                                   user_id      => gn_user_id
        --                                  ,resp_id      => gn_resp_id
        --                                  ,resp_appl_id => gn_resp_appl_id
        --                                  );
        --        mo_global.set_policy_context('S',gn_org_id);

        p_cust_profile_amt_rec_type.cust_acct_profile_amt_id   :=
            pn_cust_acct_profile_amt_id;
        p_object_version_number   := pn_object_version_number; --Pass the current object version number for the cust account profile amount ID

        IF pn_trx_credit_limit IS NOT NULL
        THEN
            p_cust_profile_amt_rec_type.trx_credit_limit   :=
                pn_trx_credit_limit;
        END IF;

        IF pn_overall_credit_limit IS NOT NULL
        THEN
            p_cust_profile_amt_rec_type.overall_credit_limit   :=
                pn_overall_credit_limit;
        END IF;

        IF pv_currency_code IS NOT NULL
        THEN
            p_cust_profile_amt_rec_type.currency_code   := pv_currency_code;
        END IF;

        --API Call to update Customer credit profile at party level

        hz_customer_profile_v2pub.update_cust_profile_amt (
            p_init_msg_list           => fnd_api.g_true,
            p_cust_profile_amt_rec    => p_cust_profile_amt_rec_type,
            p_object_version_number   => p_object_version_number,
            x_return_status           => x_return_status,
            x_msg_count               => x_msg_count,
            x_msg_data                => x_msg_data);

        IF x_return_status = fnd_api.g_ret_sts_success
        THEN
            xv_api_ret_status    := x_return_status;
            xv_api_ret_message   := NULL;
        ELSE
            xv_api_ret_status    := x_return_status;

            FOR i IN 1 .. x_msg_count
            LOOP
                x_msg_data   :=
                       x_msg_data
                    || '.'
                    || fnd_msg_pub.get (p_msg_index   => i,
                                        p_encoded     => fnd_api.g_false); --'F');
            END LOOP;

            xv_api_ret_message   := SUBSTR (x_msg_data, 1, 2000);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            xv_api_ret_status   := 'Z';
            xv_api_ret_message   :=
                   'Exception while updating Customer profile amounts. Error is '
                || SUBSTR (SQLERRM, 1, 1900);
    END update_cust_profile_amts;

    /*End of Change for CCR0006648*/

    --Procedure to update party's customer category
    PROCEDURE update_party (pn_party_id IN NUMBER, pv_customer_category IN VARCHAR2, xv_api_ret_status OUT VARCHAR2
                            , xv_api_ret_message OUT VARCHAR2)
    IS
        l_organization_rec               hz_party_v2pub.organization_rec_type;
        l_party_rec                      hz_party_v2pub.party_rec_type;
        ln_party_object_version_number   NUMBER := NULL;
        x_profile_id                     NUMBER := NULL;
        x_return_status                  VARCHAR2 (200) := NULL;
        x_msg_count                      NUMBER := 0;
        x_msg_data                       VARCHAR2 (200) := NULL;
    BEGIN
        l_party_rec.party_id           := pn_party_id; --1258049861; --SLIMPICKINS OUTFITTERS LLC
        l_party_rec.category_code      := pv_customer_category; --'CUSTOMER'; --Earlier it was PROSPECT
        l_organization_rec.party_rec   := l_party_rec;

        BEGIN
            SELECT object_version_number
              INTO ln_party_object_version_number
              FROM hz_parties hp
             WHERE hp.party_id = l_party_rec.party_id AND hp.status = 'A';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_party_object_version_number   := NULL;
        END;

        IF ln_party_object_version_number IS NOT NULL
        THEN
            hz_party_v2pub.update_organization (p_init_msg_list => apps.fnd_api.g_true, p_organization_rec => l_organization_rec, p_party_object_version_number => ln_party_object_version_number, x_profile_id => x_profile_id, x_return_status => x_return_status, x_msg_count => x_msg_count
                                                , x_msg_data => x_msg_data);

            IF x_return_status = fnd_api.g_ret_sts_success
            THEN
                xv_api_ret_status    := x_return_status;
                xv_api_ret_message   := NULL;
            ELSE
                xv_api_ret_status    := x_return_status;

                FOR i IN 1 .. x_msg_count
                LOOP
                    x_msg_data   :=
                           x_msg_data
                        || '.'
                        || fnd_msg_pub.get (p_msg_index   => i,
                                            p_encoded     => fnd_api.g_false); --'F');
                END LOOP;

                xv_api_ret_message   := SUBSTR (x_msg_data, 1, 2000);
            END IF;
        ELSE
            xv_api_ret_status   := 'Z';
            xv_api_ret_message   :=
                'Unable to derive object version number of party';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            xv_api_ret_status   := 'Z';
            xv_api_ret_message   :=
                   'Exception while updating party''s customer category. Error is '
                || SUBSTR (SQLERRM, 1, 1900);
    END update_party;

    --Procedure to create data into the staging table for Audit purpose
    PROCEDURE insert_into_stg_table (
        pv_customer_number                      hz_cust_accounts.account_number%TYPE,
        pv_credit_analyst                       per_all_people_f.full_name%TYPE,
        pd_next_sched_review_date               DATE,
        pv_customer_category                    hz_parties.category_code%TYPE/*Start of Change for CCR0006648*/
                                                                             ,
        pv_profile_class                        hz_cust_profile_classes.NAME%TYPE,
        pv_currency_code                        hz_cust_profile_amts.currency_code%TYPE,
        pn_credit_limit                         hz_cust_profile_amts.overall_credit_limit%TYPE,
        pn_order_credit_limit                   hz_cust_profile_amts.trx_credit_limit%TYPE,
        pv_credit_classification                hz_customer_profiles.credit_classification%TYPE,
        pv_review_cycle                         hz_customer_profiles.review_cycle%TYPE,
        pv_US_Ven_Vio_Researcher                hz_parties.attribute4%TYPE,
        pv_US_Freight_Researcher                hz_parties.attribute5%TYPE,
        pv_US_Discount_Researcher               hz_parties.attribute9%TYPE,
        pv_US_Credit_Memo_Researcher            hz_parties.attribute10%TYPE,
        pv_US_Short_Payment_Researcher          hz_parties.attribute11%TYPE,
        /*End of Change for CCR0006648*/
        -- Start of Change 1.2
        pv_last_sched_review_date               VARCHAR2,
        pv_safe_number                          hz_parties.attribute13%TYPE,
        pv_parent_number                        hz_parties.attribute14%TYPE,
        pv_ultimate_parent_number               hz_parties.attribute15%TYPE,
        pv_credit_checking                      hz_customer_profiles.credit_checking%TYPE,
        pv_buying_group_cust_num                hz_parties.attribute16%TYPE,
        pv_cust_membership_num                  hz_parties.attribute17%TYPE,
        pv_buying_group_vat_num                 hz_parties.attribute18%TYPE-- End of Change 1.2
                                                                           ,
        pv_return_status                 IN     VARCHAR2,
        pv_error_message                 IN     VARCHAR2,
        xv_error_message                    OUT VARCHAR2)
    IS
        --PRAGMA autonomous_transaction;
        ln_seq_id   NUMBER := 0;
    BEGIN
        BEGIN
            SELECT xxdo.xxd_party_credit_prof_upd_s.NEXTVAL
              INTO ln_seq_id
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                xv_error_message   :=
                       'Error while getting seq id from XXD_PARTY_CREDIT_PROF_UPD_S sequence. Error is: '
                    || SUBSTR (SQLERRM, 1, 1900);
        END;

        INSERT INTO xxdo.xxd_party_credit_prof_upd_stg (
                        seq_id,
                        nonbrand_cust_no,
                        credit_analyst,
                        next_scheduled_review_date,
                        customer_category,
                        status,
                        error_message,
                        request_id,
                        created_by,
                        creation_date,
                        last_updated_by,
                        last_update_date,
                        last_update_login,
                        profile_class,
                        currency_code,
                        credit_limit,
                        order_credit_limit,
                        credit_classification,
                        review_cycle,
                        US_Ven_Vio_Researcher,
                        US_Freight_Researcher,
                        US_Discount_Researcher,
                        US_Credit_Memo_Researcher,
                        US_Short_Payment_Researcher-- Start of Change 1.2
                                                   ,
                        last_review_date,
                        safe_number,
                        parent_number,
                        ultimate_parent_number,
                        credit_checking,
                        buying_group_cust_num,
                        cust_membership_num,
                        buying_group_vat_num-- End of Change 1.2
                                            )
             VALUES (ln_seq_id --xxdo.xxd_party_credit_prof_upd_s.NEXTVAL --seq_id
                              , pv_customer_number          --nonbrand_cust_no
                                                  , pv_credit_analyst --credit_analyst
                                                                     ,
                     pd_next_sched_review_date   --next_scheduled_review_daSte
                                              , pv_customer_category --customer_category
                                                                    , pv_return_status --status
                                                                                      , pv_error_message --error_message
                                                                                                        , gn_request_id --request_id
                                                                                                                       , gn_user_id --created_by
                                                                                                                                   , SYSDATE --creation_date
                                                                                                                                            , gn_user_id --last_updated_by
                                                                                                                                                        , SYSDATE --last_update_date
                                                                                                                                                                 , gn_login_id --last_update_login
                                                                                                                                                                              , pv_profile_class -- profile_class
                                                                                                                                                                                                , pv_currency_code, pn_credit_limit, pn_order_credit_limit, pv_credit_classification, pv_review_cycle, pv_US_Ven_Vio_Researcher, pv_US_Freight_Researcher, pv_US_Discount_Researcher, pv_US_Credit_Memo_Researcher, pv_US_Short_Payment_Researcher-- Start of Change 1.2
                                                                                                                                                                                                                                                                                                                                                                                                                                                  , pv_last_sched_review_date, pv_safe_number, pv_parent_number, pv_ultimate_parent_number, pv_credit_checking, pv_buying_group_cust_num
                     , pv_cust_membership_num, pv_buying_group_vat_num-- End of Change 1.2
                                                                      );
    --COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            xv_error_message   :=
                   'Error while inserting data into staging table. Error is: '
                || SUBSTR (SQLERRM, 1, 1900);
    END insert_into_stg_table;

    --Procedure to update staging table
    PROCEDURE update_stg_table (pn_seq_id NUMBER, pv_return_status IN VARCHAR2, pv_error_message IN VARCHAR2
                                , xv_error_message OUT VARCHAR2)
    IS
    --PRAGMA autonomous_transaction;
    BEGIN
        UPDATE xxdo.xxd_party_credit_prof_upd_stg
           SET status = pv_return_status, error_message = pv_error_message, last_updated_by = gn_user_id,
               last_update_date = SYSDATE, last_update_login = gn_login_id
         WHERE seq_id = pn_seq_id;
    --COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            xv_error_message   :=
                   'Error while updating staging table. Error is: '
                || SUBSTR (SQLERRM, 1, 1900);
    END update_stg_table;

    --Main Procedure called by WebADI (Uploader)
    PROCEDURE driving_proc (pv_customer_number hz_cust_accounts.account_number%TYPE, pv_credit_analyst per_all_people_f.full_name%TYPE, pd_next_sched_review_date DATE, pv_customer_category hz_parties.category_code%TYPE, /*Start of Change for CCR0006648*/
                                                                                                                                                                                                                            pv_profile_class hz_cust_profile_classes.NAME%TYPE, pv_currency_code hz_cust_profile_amts.currency_code%TYPE, pn_credit_limit hz_cust_profile_amts.overall_credit_limit%TYPE, pn_order_credit_limit hz_cust_profile_amts.trx_credit_limit%TYPE, pv_credit_classification hz_customer_profiles.credit_classification%TYPE, pv_review_cycle hz_customer_profiles.review_cycle%TYPE, pv_US_Ven_Vio_Researcher hz_parties.attribute4%TYPE, pv_US_Freight_Researcher hz_parties.attribute5%TYPE, pv_US_Discount_Researcher hz_parties.attribute9%TYPE, pv_US_Credit_Memo_Researcher hz_parties.attribute10%TYPE, pv_US_Short_Payment_Researcher hz_parties.attribute11%TYPE, pv_attribute1 VARCHAR, -- Last_Review_date
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           pv_attribute2 VARCHAR, -- safe_number
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  pv_attribute3 VARCHAR, -- parent_number
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         pv_attribute4 VARCHAR, -- ultimate_parent_number
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                pv_attribute5 VARCHAR, -- Credit Checking
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       pv_attribute6 VARCHAR, -- Buying Group Customer Number
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              pv_attribute7 VARCHAR, -- Customer Membership Number
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     pv_attribute8 VARCHAR, -- Buying Group VAT Number
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            pv_attribute9 VARCHAR
                            , pv_attribute10 VARCHAR/*End of Change for CCR0006648*/
                                                    )
    IS
        --Local Variables
        --        lv_proc_name                VARCHAR2(30)    :=  NULL;
        lv_error_message      VARCHAR2 (2000) := NULL;
        lv_return_status      VARCHAR2 (1) := NULL;
        lv_create_err_msg     VARCHAR2 (2000) := NULL;
        lv_upd_err_message    VARCHAR2 (2000) := NULL;
        --        ln_cust_cat_exists          NUMBER          :=  NULL;

        --User Defined Exceptions
        le_webadi_exception   EXCEPTION;
    BEGIN
        lv_return_status   := g_ret_success;
        lv_error_message   := NULL;

        --dbms_output.put_line('TEST1');

        --Insert the record into the staging table
        insert_into_stg_table (pv_customer_number, pv_credit_analyst, pd_next_sched_review_date, pv_customer_category, pv_profile_class, pv_currency_code, pn_credit_limit, pn_order_credit_limit, pv_credit_classification, pv_review_cycle, pv_US_Ven_Vio_Researcher, pv_US_Freight_Researcher, pv_US_Discount_Researcher, pv_US_Credit_Memo_Researcher, pv_US_Short_Payment_Researcher-- Start of change 1.2
                                                                                                                                                                                                                                                                                                                                                                                         , pv_attribute1 -- Last_Review_date
                                                                                                                                                                                                                                                                                                                                                                                                        , pv_attribute2 -- safe_number
                                                                                                                                                                                                                                                                                                                                                                                                                       , pv_attribute3 -- parent_number
                                                                                                                                                                                                                                                                                                                                                                                                                                      , pv_attribute4 -- ultimate_parent_number
                                                                                                                                                                                                                                                                                                                                                                                                                                                     , pv_attribute5 -- Credit_checking
                                                                                                                                                                                                                                                                                                                                                                                                                                                                    , pv_attribute6 -- buying_group_cust_num
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   , pv_attribute7 -- cust_membership_num
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  , pv_attribute8 -- buying_group_vat_num
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 -- End of Change 1.2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 , 'N' --lv_return_status
                               , NULL                       --lv_error_message
                                     , lv_create_err_msg);

        --dbms_output.put_line('TEST2');

        IF lv_create_err_msg IS NOT NULL
        THEN
            lv_return_status   := g_ret_error;
            lv_error_message   := lv_error_message || lv_create_err_msg;
            --dbms_output.put_line('TEST3');
            RAISE le_webadi_exception; -- Raise exception as we cannot proceed with out inserting the record into the staging table as it is necessary for AUDIT purpose
        END IF;
    EXCEPTION
        WHEN le_webadi_exception
        THEN
            --dbms_output.put_line('TEST4');
            lv_error_message   := SUBSTR (lv_error_message, 1, 2000);
            fnd_message.set_name ('XXDO', 'XXD_PARTY_CREDIT_WEBADI_MSG');
            fnd_message.set_token ('ERROR_MESSAGE', lv_error_message);
            lv_error_message   := fnd_message.get ();
            raise_application_error (-20000, lv_error_message);
        WHEN OTHERS
        THEN
            --dbms_output.put_line('TEST5');
            lv_error_message   :=
                SUBSTR (lv_error_message || '.' || SQLERRM, 1, 2000);
            raise_application_error (-20001, lv_error_message);
    END driving_proc;

    --This will be called at the end after loading all the records into the staging table(Importer part of WebADI call this procedure)
    PROCEDURE importer_proc
    IS
        --Local Variables
        lv_proc_name                    VARCHAR2 (30) := NULL;
        lv_error_message                VARCHAR2 (2000) := NULL;
        lv_return_status                VARCHAR2 (1) := NULL;
        ln_party_id                     NUMBER := NULL;
        ln_cust_account_id              NUMBER := NULL;
        ln_credit_analyst_id            NUMBER := NULL;
        ln_old_credit_analyst_id        NUMBER := NULL;
        ln_n_credit_analyst_id          NUMBER := NULL;
        ln_old_tolerance                NUMBER := NULL;
        lv_customer_category            VARCHAR2 (30) := NULL;
        lv_attr_category                VARCHAR2 (150) := NULL;
        lv_next_sched_review_date       VARCHAR2 (30) := NULL;
        ln_cust_account_profile_id      NUMBER := NULL;
        ln_object_version_number        NUMBER := NULL;
        lv_credit_profile_exists        VARCHAR2 (5) := 'N';
        ln_bill_to_site_cnt             NUMBER := NULL;
        ln_credit_prof_exists_cnt       NUMBER := NULL;
        lv_api_ret_status               VARCHAR2 (1) := NULL;
        lv_api_ret_message              VARCHAR2 (2000) := NULL;
        ln_cust_acct_prof_id            NUMBER := NULL;
        lv_create_err_msg               VARCHAR2 (2000) := NULL;
        lv_upd_err_message              VARCHAR2 (2000) := NULL;
        ln_cust_cat_exists              NUMBER := NULL;
        ln_batch_id                     NUMBER := 0;
        ln_profile_class_id             NUMBER := NULL;
        ln_n_profile_class_id           NUMBER := NULL;
        ln_old_profile_class_id         NUMBER := NULL;
        lv_currency_code                VARCHAR2 (15) := NULL;
        ln_order_credit_limit           NUMBER := NULL;
        ln_trx_credit_limit             NUMBER := NULL;
        ln_p_trx_credit_limit           NUMBER := NULL;
        ln_overall_credit_limit         NUMBER := NULL;
        ln_p_overall_credit_limit       NUMBER := NULL;
        lv_p_old_currency_code          VARCHAR2 (15) := NULL;
        ln_p_cust_acct_prof_ovn         NUMBER := NULL;
        ln_p_cust_acct_profile_amt_id   NUMBER := NULL;
        lv_old_currency_code            VARCHAR2 (15) := NULL;
        lv_n_currency_code              VARCHAR2 (15) := NULL;
        ln_cust_acct_prof_ovn           NUMBER := NULL;
        ln_n_cust_acct_prof_ovn         NUMBER := NULL;
        ln_n_cust_acct_profile_amt_id   NUMBER := NULL;
        ln_cust_acct_profile_amt_id     NUMBER := NULL;
        ln_credit_limit                 NUMBER := NULL;
        ln_n_credit_limit               NUMBER := NULL;
        ln_n_order_credit_limit         NUMBER := NULL;
        lv_credit_classification        VARCHAR2 (80) := NULL;
        lv_review_cycle                 VARCHAR2 (80) := NULL;
        ln_US_Ven_Vio_Researcher_id     NUMBER := NULL;
        ln_US_Freight_Researcher_id     NUMBER := NULL;
        ln_US_Discount_Researcher_id    NUMBER := NULL;
        ln_US_Credit_Memo_Research_id   NUMBER := NULL;
        ln_US_Short_Pay_Research_id     NUMBER := NULL;
        ln_attr4                        NUMBER := NULL;
        ln_attr5                        NUMBER := NULL;
        ln_attr9                        NUMBER := NULL;
        ln_attr10                       NUMBER := NULL;
        ln_attr11                       NUMBER := NULL;
        l_boolean                       BOOLEAN;
        l_ret_msg                       VARCHAR (2000) := NULL;
        lv_error                        VARCHAR2 (10) := 'N';
        -- Start of Change 1.2
        lv_last_sched_review_date       VARCHAR2 (30) := NULL;
        lv_safe_number                  VARCHAR2 (240) := NULL;
        lv_parent_number                VARCHAR2 (240) := NULL;
        lv_ultimate_parent_number       VARCHAR2 (240) := NULL;
        lv_attr13                       VARCHAR2 (240) := NULL;
        lv_attr14                       VARCHAR2 (240) := NULL;
        lv_attr15                       VARCHAR2 (240) := NULL;
        lv_credit_checking              VARCHAR2 (30) := NULL;
        lv_old_credit_checking          VARCHAR2 (30) := NULL;
        lv_n_credit_checking            VARCHAR2 (30) := NULL;
        lv_buying_group_cust_num        VARCHAR2 (240) := NULL;
        lv_cust_membership_num          VARCHAR2 (240) := NULL;
        lv_buying_group_vat_num         VARCHAR2 (240) := NULL;
        lv_attr16                       VARCHAR2 (240) := NULL;
        lv_attr17                       VARCHAR2 (240) := NULL;
        lv_attr18                       VARCHAR2 (240) := NULL;
        l_cust_acct_profile_amt_id      NUMBER;
        create_curr_flag                VARCHAR2 (10) := NULL;
        -- End of Change 1.2
        --Start of change 1.3
        ln_old_trx_credit_limit         NUMBER := NULL;
        ln_old_overall_credit_limit     NUMBER := NULL;
        lv_old_prof_currency_code       VARCHAR2 (240) := NULL;
        ln_old_cust_acct_prof_amt_id    NUMBER := NULL;

        --End of change 1.3


        CURSOR sel_cur (cv_batch_id NUMBER)
        IS
              SELECT *
                FROM xxdo.xxd_party_credit_prof_upd_stg stg
               WHERE     stg.status = 'N'
                     AND stg.created_by = gn_user_id
                     AND stg.batch_id = cv_batch_id
            ORDER BY seq_id;
    BEGIN
        mo_global.init ('AR');
        fnd_global.apps_initialize (user_id        => gn_user_id,
                                    resp_id        => gn_resp_id,
                                    resp_appl_id   => gn_resp_appl_id);
        mo_global.set_policy_context ('S', gn_org_id);

        BEGIN
            SELECT xxdo.xxd_party_credit_prof_batch_s.NEXTVAL
              INTO ln_batch_id
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_message   :=
                       'Error while getting Batch id from XXD_PARTY_CREDIT_PROF_BATCH_S sequence. Error is: '
                    || SUBSTR (SQLERRM, 1, 1900);
        END;


        BEGIN
            UPDATE xxdo.xxd_party_credit_prof_upd_stg stg
               SET stg.batch_id   = ln_batch_id
             WHERE     stg.created_by = gn_user_id
                   AND stg.status = 'N'
                   AND stg.batch_id IS NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_message   :=
                       'Error while updating staging table with Batch id. Error is: '
                    || SUBSTR (SQLERRM, 1, 1900);
        END;

        FOR sel_rec IN sel_cur (ln_batch_id)
        LOOP
            /*Start of changes for CCR CCR0006824*/
            lv_error_message   := NULL;
            lv_return_status   := NULL;
            lv_error           := 'N';

            /* End of changes for CCR CCR0006824*/
            --START - Validate if the customer number is a Non-Brand customer number or not
            IF sel_rec.nonbrand_cust_no IS NOT NULL
            THEN
                BEGIN
                    SELECT hca.party_id, hca.cust_account_id, hzp.attribute_category
                      INTO ln_party_id, ln_cust_account_id, lv_attr_category
                      FROM apps.hz_cust_accounts hca, apps.hz_parties hzp
                     WHERE     1 = 1
                           AND hca.status = 'A'
                           AND hca.attribute1 = 'ALL BRAND'
                           AND hzp.party_id = hca.party_id
                           AND hca.attribute18 IS NULL --Not an Ecomm Customer
                           AND hca.account_number = sel_rec.nonbrand_cust_no;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_party_id          := NULL;
                        ln_cust_account_id   := NULL;
                        lv_return_status     := g_ret_error;
                        lv_error             := 'Y';
                        lv_error_message     :=
                               lv_error_message
                            || 'Customer Number entered is not a Non-Brand Customer Number.';
                    WHEN OTHERS
                    THEN
                        ln_party_id          := NULL;
                        ln_cust_account_id   := NULL;
                        lv_return_status     := g_ret_error;
                        lv_error             := 'Y';
                        lv_error_message     :=
                               lv_error_message
                            || 'Exception Occurred while validating Customer Number.'
                            || SUBSTR (SQLERRM, 1, 1900 || '.');
                END;
            ELSE
                lv_return_status   := g_ret_error;
                lv_error_message   :=
                       lv_error_message
                    || 'Non-Brand Customer Number is not provided.';
            END IF;

            --END - Validate if the customer numnber is a Non-Brand customer number or not

            --Validate if customer has atleast one BILL_TO site
            IF ln_cust_account_id IS NOT NULL
            THEN
                SELECT COUNT (*)
                  INTO ln_bill_to_site_cnt
                  FROM hz_cust_acct_sites_all hcasa, hz_cust_site_uses_all hcsua
                 WHERE     1 = 1
                       AND hcasa.cust_account_id = ln_cust_account_id
                       AND hcsua.org_id = gn_org_id
                       AND hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
                       AND hcasa.org_id = hcsua.org_id
                       AND hcasa.status = 'A'
                       AND hcsua.status = 'A'
                       AND hcsua.site_use_code = 'BILL_TO'
                       AND hcsua.primary_flag = 'Y';

                IF ln_bill_to_site_cnt <= 0
                THEN
                    lv_return_status   := g_ret_error;
                    lv_error           := 'Y';
                    lv_error_message   :=
                           lv_error_message
                        || 'There is no BILL_TO site in this operating unit for the customer provided.';
                END IF;
            END IF;

            --START - Get the party level Attributes
            /*Start of Change for CCR0006648*/
            IF     ln_party_id IS NOT NULL
               AND NVL (lv_attr_category, 'ABCXYZ') = 'Customer'
            THEN
                BEGIN
                    SELECT attribute4, attribute5, attribute9,
                           attribute10, attribute11-- Start of Change 1.2
                                                   , attribute13,
                           attribute14, attribute15, attribute16,
                           attribute17, attribute18
                      -- End of Change 1.2
                      INTO ln_attr4, ln_attr5, ln_attr9, ln_attr10,
                                   ln_attr11-- Start of Chnage 1.2
                                            , lv_attr13, lv_attr14,
                                   lv_attr15, lv_attr16, lv_attr17,
                                   lv_attr18
                      -- End of Change 1.2
                      FROM apps.hz_parties
                     WHERE party_id = ln_party_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_attr4    := NULL;
                        ln_attr5    := NULL;
                        ln_attr9    := NULL;
                        ln_attr10   := NULL;
                        ln_attr11   := NULL;
                        lv_attr13   := NULL;           -- Added for Change 1.2
                        lv_attr14   := NULL;           -- Added for Change 1.2
                        lv_attr15   := NULL;           -- Added for Change 1.2
                        lv_attr16   := NULL;           -- Added for Change 1.2
                        lv_attr17   := NULL;           -- Added for Change 1.2
                        lv_attr18   := NULL;           -- Added for Change 1.2
                END;
            END IF;

            /*Start of Change for CCR0006648*/
            --END - Get the party level Attributes

            --START - Validate if the credit analyst entered is valid
            IF sel_rec.credit_analyst IS NOT NULL
            THEN
                BEGIN
                    SELECT jrre.resource_id
                      INTO ln_credit_analyst_id
                      FROM jtf_rs_resource_extns jrre, per_all_people_f per
                     WHERE     1 = 1
                           AND jrre.category = 'EMPLOYEE'
                           AND jrre.source_id = per.person_id
                           AND TRUNC (SYSDATE) BETWEEN per.effective_start_date
                                                   AND per.effective_end_date
                           AND TRUNC (SYSDATE) BETWEEN jrre.start_date_active
                                                   AND TRUNC (
                                                           NVL (
                                                               jrre.end_date_active,
                                                               SYSDATE))
                           AND per.full_name = sel_rec.credit_analyst;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_credit_analyst_id   := NULL;
                        lv_return_status       := g_ret_error;
                        lv_error               := 'Y';
                        lv_error_message       :=
                               lv_error_message
                            || 'Credit Analyst name entered is not valid.';
                    WHEN TOO_MANY_ROWS
                    THEN
                        ln_credit_analyst_id   := NULL;
                        lv_return_status       := g_ret_error;
                        lv_error               := 'Y';
                        lv_error_message       :=
                               lv_error_message
                            || 'Credit Analyst name returned multiple rows.';
                    WHEN OTHERS
                    THEN
                        ln_credit_analyst_id   := NULL;
                        lv_return_status       := g_ret_error;
                        lv_error               := 'Y';
                        lv_error_message       :=
                               lv_error_message
                            || 'Exception Occurred while validating Credit Analyst name.'
                            || SUBSTR (SQLERRM, 1, 1900 || '.');
                END;
            ELSE
                ln_credit_analyst_id   := NULL;
            END IF;

            --END - Validate if the credit analyst entered is valid

            --START - Validate if the customer category  entered is valid
            IF sel_rec.customer_category IS NOT NULL
            THEN
                BEGIN
                    SELECT flv.lookup_code
                      INTO lv_customer_category
                      FROM fnd_lookup_values flv
                     WHERE     1 = 1
                           AND flv.language = 'US'
                           AND flv.lookup_type = 'CUSTOMER_CATEGORY'
                           AND flv.enabled_flag = 'Y'
                           AND TRUNC (SYSDATE) BETWEEN flv.start_date_active
                                                   AND TRUNC (
                                                           NVL (
                                                               flv.end_date_active,
                                                               SYSDATE))
                           AND UPPER (lookup_code) =
                               UPPER (sel_rec.customer_category);
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        lv_customer_category   := NULL;
                        lv_error               := 'Y';
                        lv_return_status       := g_ret_error;
                        lv_error_message       :=
                               lv_error_message
                            || 'Customer Category entered is not valid.';
                    WHEN OTHERS
                    THEN
                        lv_customer_category   := NULL;
                        lv_error               := 'Y';
                        lv_return_status       := g_ret_error;
                        lv_error_message       :=
                               lv_error_message
                            || 'Exception Occurred while validating Customer Category'
                            || SUBSTR (SQLERRM, 1, 1900 || '.');
                END;
            ELSE
                lv_customer_category   := NULL;
            END IF;

            --END - Validate if the customer category entered is a valid

            --START - Validate the entered New Schedule Review Date and convert into correct format
            IF sel_rec.next_scheduled_review_date IS NOT NULL
            THEN
                BEGIN
                    SELECT TO_CHAR (sel_rec.next_scheduled_review_date, 'DD-MON-RRRR')
                      INTO lv_next_sched_review_date
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_next_sched_review_date   := NULL;
                        lv_error                    := 'Y';
                        lv_return_status            := g_ret_error;
                        lv_error_message            :=
                               lv_error_message
                            || 'Exception Occurred while validating Next scheduled Review Date'
                            || SUBSTR (SQLERRM, 1, 1900 || '.');
                END;
            ELSE
                lv_next_sched_review_date   := NULL;
            END IF;

            --END - Validate if the entered New Schedule Review Date and convert into correct format

            -- Start of Change 1.2

            IF sel_rec.last_review_date IS NOT NULL
            THEN
                BEGIN
                    SELECT TO_CHAR (TO_DATE (sel_rec.last_review_date, 'DD-MON-RRRR'), 'DD-MON-RRRR')
                      INTO lv_last_sched_review_date
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_last_sched_review_date   := NULL;

                        BEGIN
                            SELECT TO_CHAR (TO_DATE (sel_rec.last_review_date, 'MM/DD/RRRR'), 'DD-MON-RRRR')
                              INTO lv_last_sched_review_date
                              FROM DUAL;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_last_sched_review_date   := NULL;
                                lv_error                    := 'Y';
                                lv_return_status            := g_ret_error;
                                lv_error_message            :=
                                       lv_error_message
                                    || 'Exception Occurred while validating Last scheduled Review Date'
                                    || SUBSTR (SQLERRM, 1, 1900 || '.');
                        END;
                END;
            ELSE
                lv_last_sched_review_date   := NULL;
            END IF;

            IF sel_rec.credit_checking IS NOT NULL
            THEN
                BEGIN
                    SELECT lookup_code
                      INTO lv_credit_checking
                      FROM apps.fnd_lookup_values
                     WHERE     lookup_type = 'YES/NO'
                           AND enabled_flag = 'Y'
                           AND SYSDATE BETWEEN NVL (start_date_active,
                                                    SYSDATE)
                                           AND NVL (end_date_active, SYSDATE)
                           AND language = USERENV ('LANG')
                           AND view_application_id = 222
                           AND lookup_code = sel_rec.credit_checking;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        lv_error           := 'Y';
                        lv_return_status   := g_ret_error;
                        lv_error_message   :=
                               lv_error_message
                            || 'Credit Checking entered is not valid.';
                    WHEN OTHERS
                    THEN
                        lv_error           := 'Y';
                        lv_return_status   := g_ret_error;
                        lv_error_message   :=
                               lv_error_message
                            || 'Exception Occurred while validating Credit Checking Flag'
                            || SUBSTR (SQLERRM, 1, 1900 || '.');
                END;
            ELSE
                lv_credit_checking   := NULL;
            END IF;

            -- End of Change 1.2

            --START - Validate if the profile class entered is valid
            /*Start of Change for CCR0006648*/
            IF sel_rec.profile_class IS NOT NULL
            THEN
                BEGIN
                    SELECT hpc.profile_class_id
                      INTO ln_profile_class_id
                      FROM apps.hz_cust_profile_classes hpc
                     WHERE     1 = 1
                           AND UPPER (TRIM (hpc.name)) =
                               UPPER (TRIM (sel_rec.profile_class));
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_profile_class_id   := NULL;
                        lv_error              := 'Y';
                        lv_return_status      := g_ret_error;
                        lv_error_message      :=
                               lv_error_message
                            || 'Profile class name entered is not valid.';
                    WHEN TOO_MANY_ROWS
                    THEN
                        ln_profile_class_id   := NULL;
                        lv_error              := 'Y';
                        lv_return_status      := g_ret_error;
                        lv_error_message      :=
                               lv_error_message
                            || 'Profile class name returned multiple rows.';
                    WHEN OTHERS
                    THEN
                        ln_profile_class_id   := NULL;
                        lv_error              := 'Y';
                        lv_return_status      := g_ret_error;
                        lv_error_message      :=
                               lv_error_message
                            || 'Exception Occurred while validating Profile class name.'
                            || SUBSTR (SQLERRM, 1, 1900 || '.');
                END;
            ELSE
                ln_profile_class_id   := NULL;
            END IF;

            --END - Validate if the profile class entered is valid

            --START - Validate if the Currency code entered is valid
            IF sel_rec.currency_code IS NOT NULL
            THEN
                BEGIN
                    SELECT currency_code
                      INTO lv_currency_code
                      FROM apps.fnd_currencies
                     WHERE     1 = 1
                           AND enabled_flag = 'Y'
                           AND UPPER (TRIM (currency_code)) =
                               UPPER (TRIM (sel_rec.currency_code));
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        lv_currency_code   := NULL;
                        lv_error           := 'Y';
                        lv_return_status   := g_ret_error;
                        lv_error_message   :=
                               lv_error_message
                            || 'Currency code entered is not valid.';
                    WHEN TOO_MANY_ROWS
                    THEN
                        lv_currency_code   := NULL;
                        lv_error           := 'Y';
                        lv_return_status   := g_ret_error;
                        lv_error_message   :=
                               lv_error_message
                            || 'Currency code returned multiple rows.';
                    WHEN OTHERS
                    THEN
                        lv_currency_code   := NULL;
                        lv_error           := 'Y';
                        lv_return_status   := g_ret_error;
                        lv_error_message   :=
                               lv_error_message
                            || 'Exception Occurred while validating Currency code.'
                            || SUBSTR (SQLERRM, 1, 1900 || '.');
                END;
            ELSE
                lv_currency_code   := NULL;
            END IF;

            --END - Validate the Currency code entered is valid

            --START - Validate the overall credit limit
            IF sel_rec.credit_limit IS NOT NULL
            THEN
                ln_credit_limit   := sel_rec.credit_limit;
            ELSE
                ln_credit_limit   := NULL;
            END IF;

            --END - Validate the overall credit limit

            --START - Validate the order credit limit
            IF sel_rec.order_credit_limit IS NOT NULL
            THEN
                ln_order_credit_limit   := sel_rec.order_credit_limit;
            ELSE
                ln_order_credit_limit   := NULL;
            END IF;

            --END - Validate the overall credit limit

            -- Currency cannot be NULL if credit limits are provided

            IF    sel_rec.credit_limit IS NOT NULL
               OR sel_rec.order_credit_limit IS NOT NULL
            THEN
                IF sel_rec.currency_code IS NULL
                THEN
                    lv_error           := 'Y';
                    lv_return_status   := g_ret_error;
                    lv_error_message   :=
                           lv_error_message
                        || 'Currency code has to be available for Credit limit updates';
                END IF;
            ELSIF sel_rec.currency_code IS NOT NULL
            THEN
                IF     sel_rec.credit_limit IS NULL
                   AND sel_rec.order_credit_limit IS NULL
                THEN
                    lv_error           := 'Y';
                    lv_return_status   := g_ret_error;
                    lv_error_message   :=
                           lv_error_message
                        || ' Provide atleast Credit limit/ Order Credit limit with Currency ';
                END IF;
            END IF;


            --START - Validate if the Credit Classification entered is valid
            IF sel_rec.credit_classification IS NOT NULL
            THEN
                BEGIN
                    SELECT flv.lookup_code
                      INTO lv_credit_classification
                      FROM fnd_lookup_values flv
                     WHERE     1 = 1
                           AND flv.language = 'US'
                           AND flv.lookup_type =
                               'AR_CMGT_CREDIT_CLASSIFICATION'
                           AND flv.enabled_flag = 'Y'
                           AND TRUNC (SYSDATE) BETWEEN flv.start_date_active
                                                   AND TRUNC (
                                                           NVL (
                                                               flv.end_date_active,
                                                               SYSDATE))
                           AND UPPER (TRIM (meaning)) =
                               UPPER (TRIM (sel_rec.credit_classification));
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        lv_credit_classification   := NULL;
                        lv_error                   := 'Y';
                        lv_return_status           := g_ret_error;
                        lv_error_message           :=
                               lv_error_message
                            || 'Credit Classification entered is not valid.';
                    WHEN OTHERS
                    THEN
                        lv_credit_classification   := NULL;
                        lv_error                   := 'Y';
                        lv_return_status           := g_ret_error;
                        lv_error_message           :=
                               lv_error_message
                            || 'Exception Occurred while validating Credit Classification'
                            || SUBSTR (SQLERRM, 1, 1900 || '.');
                END;
            ELSE
                lv_credit_classification   := NULL;
            END IF;

            --END - Validate if the Credit Classification entered is a valid

            --START - Validate if the Credit Classification entered is valid
            IF sel_rec.review_cycle IS NOT NULL
            THEN
                BEGIN
                    SELECT flv.lookup_code
                      INTO lv_review_cycle
                      FROM fnd_lookup_values flv
                     WHERE     1 = 1
                           AND flv.language = 'US'
                           AND flv.lookup_type = 'PERIODIC_REVIEW_CYCLE'
                           AND flv.enabled_flag = 'Y'
                           AND TRUNC (SYSDATE) BETWEEN flv.start_date_active
                                                   AND TRUNC (
                                                           NVL (
                                                               flv.end_date_active,
                                                               SYSDATE))
                           AND UPPER (TRIM (meaning)) =
                               UPPER (TRIM (sel_rec.review_cycle));
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        lv_review_cycle    := NULL;
                        lv_error           := 'Y';
                        lv_return_status   := g_ret_error;
                        lv_error_message   :=
                               lv_error_message
                            || 'Review Cycle entered is not valid.';
                    WHEN OTHERS
                    THEN
                        lv_review_cycle    := NULL;
                        lv_error           := 'Y';
                        lv_return_status   := g_ret_error;
                        lv_error_message   :=
                               lv_error_message
                            || 'Exception Occurred while validating Review Cycle'
                            || SUBSTR (SQLERRM, 1, 1900 || '.');
                END;
            ELSE
                lv_review_cycle   := NULL;
            END IF;

            --END - Validate if the Credit Classification entered is a valid

            -- Validation for Context DFFs
            IF     (sel_rec.us_ven_vio_researcher IS NOT NULL OR sel_rec.us_freight_researcher IS NOT NULL OR sel_rec.us_discount_researcher IS NOT NULL OR sel_rec.us_credit_memo_researcher IS NOT NULL OR sel_rec.us_short_payment_researcher IS NOT NULL OR sel_rec.safe_number IS NOT NULL OR sel_rec.parent_number IS NOT NULL OR sel_rec.ultimate_parent_number IS NOT NULL -- Added for Change 1.2
                                                                                                                                                                                                                                                                                                                                                                                   OR sel_rec.buying_group_cust_num IS NOT NULL OR sel_rec.cust_membership_num IS NOT NULL OR sel_rec.buying_group_vat_num IS NOT NULL -- Added for Change 1.2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      )
               AND NVL (lv_attr_category, 'ABCXYZ') <> 'Customer'
            THEN
                lv_return_status   := g_ret_error;
                lv_error_message   :=
                       lv_error_message
                    || ' - '
                    || ' Values in DFFs can be updated only for Party with valid context value as Customer ';
                lv_error           := 'Y';
            END IF;

            -- End of Validtaion

            --START - Validate if ln_us_ven_vio_researcher name entered is valid
            IF sel_rec.us_ven_vio_researcher IS NOT NULL
            THEN
                --dbms_output.put_line('Fetching researcher');
                l_boolean   := NULL;
                l_boolean   :=
                    is_researcher_valid (
                        pv_researcher_name   => sel_rec.us_ven_vio_researcher,
                        x_researcher_id      => ln_us_ven_vio_researcher_id,
                        x_ret_msg            => l_ret_msg);

                --dbms_output.put_line('Researcher Value - '||ln_us_ven_vio_researcher_id);
                IF l_boolean = FALSE OR ln_us_ven_vio_researcher_id IS NULL
                THEN
                    lv_return_status   := g_ret_error;
                    lv_error           := 'Y';
                    lv_error_message   :=
                        lv_error_message || ' - ' || l_ret_msg;
                --dbms_output.put_line('Error Fetching researcher');
                --dbms_output.put_line('Boolean Value1 - '||l_boolean);
                --dbms_output.put_line('Researcher Value1 - '||ln_us_ven_vio_researcher_id);
                END IF;
            ELSE
                ln_us_ven_vio_researcher_id   := ln_attr4;
            --dbms_output.put_line('Fetching researcher as NULL');
            --dbms_output.put_line('Attribute4: '||ln_attr4);
            END IF;

            --END - Validate if the ln_us_ven_vio_researcher name entered is valid

            --START - Validate if US Freight Researcher name entered is valid
            IF sel_rec.us_freight_researcher IS NOT NULL
            THEN
                l_boolean   := NULL;
                l_boolean   :=
                    is_researcher_valid (
                        pv_researcher_name   => sel_rec.us_freight_researcher,
                        x_researcher_id      => ln_us_freight_researcher_id,
                        x_ret_msg            => l_ret_msg);

                IF l_boolean = FALSE OR ln_us_freight_researcher_id IS NULL
                THEN
                    lv_return_status   := g_ret_error;
                    lv_error           := 'Y';
                    lv_error_message   :=
                        lv_error_message || ' - ' || l_ret_msg;
                END IF;
            ELSE
                ln_us_freight_researcher_id   := ln_attr5;
            --dbms_output.put_line('Attribute5: '||ln_attr5);
            END IF;

            --END - Validate if the ln_us_ven_vio_researcher name entered is valid

            --START - Validate if US Discount Researcher name entered is valid
            IF sel_rec.us_discount_researcher IS NOT NULL
            THEN
                l_boolean   := NULL;
                l_boolean   :=
                    is_researcher_valid (
                        pv_researcher_name   => sel_rec.us_discount_researcher,
                        x_researcher_id      => ln_us_discount_researcher_id,
                        x_ret_msg            => l_ret_msg);

                IF l_boolean = FALSE OR ln_us_discount_researcher_id IS NULL
                THEN
                    lv_return_status   := g_ret_error;
                    lv_error           := 'Y';
                    lv_error_message   :=
                        lv_error_message || ' - ' || l_ret_msg;
                END IF;
            ELSE
                ln_us_discount_researcher_id   := ln_attr9;
            --dbms_output.put_line('Attribute9: '||ln_attr9);
            END IF;

            --END - Validate if the US Discount Researcher name entered is valid

            --START - Validate if US Credit Memo researcher name entered is valid
            IF sel_rec.us_credit_memo_researcher IS NOT NULL
            THEN
                l_boolean   := NULL;
                l_boolean   :=
                    is_researcher_valid (
                        pv_researcher_name   =>
                            sel_rec.us_credit_memo_researcher,
                        x_researcher_id   => ln_us_credit_memo_research_id,
                        x_ret_msg         => l_ret_msg);

                IF l_boolean = FALSE OR ln_us_credit_memo_research_id IS NULL
                THEN
                    lv_return_status   := g_ret_error;
                    lv_error           := 'Y';
                    lv_error_message   :=
                        lv_error_message || ' - ' || l_ret_msg;
                END IF;
            ELSE
                ln_us_credit_memo_research_id   := ln_attr10;
            --dbms_output.put_line('Attribute10: '||ln_attr10);
            END IF;

            --END - Validate if the US Credit Memo_researcher name entered is valid

            --START - Validate if US Short Payment researcher name entered is valid
            IF sel_rec.us_short_payment_researcher IS NOT NULL
            THEN
                l_boolean   := NULL;
                l_boolean   :=
                    is_researcher_valid (
                        pv_researcher_name   =>
                            sel_rec.us_short_payment_researcher,
                        x_researcher_id   => ln_us_short_pay_research_id,
                        x_ret_msg         => l_ret_msg);

                IF l_boolean = FALSE OR ln_us_short_pay_research_id IS NULL
                THEN
                    lv_return_status   := g_ret_error;
                    lv_error           := 'Y';
                    lv_error_message   :=
                        lv_error_message || ' - ' || l_ret_msg;
                END IF;
            ELSE
                ln_us_short_pay_research_id   := ln_attr11;
            --dbms_output.put_line('Attribute11: '||ln_attr11);
            END IF;

            --END - Validate if the US Short Payment researcher name entered is valid
            /*End of Change for CCR0006648*/

            -- Start of Change 1.2

            IF sel_rec.safe_number IS NOT NULL
            THEN
                lv_safe_number   := sel_rec.safe_number;
            ELSE
                lv_safe_number   := lv_attr13;
            END IF;

            IF sel_rec.parent_number IS NOT NULL
            THEN
                lv_parent_number   := sel_rec.parent_number;
            ELSE
                lv_parent_number   := lv_attr14;
            END IF;

            IF sel_rec.ultimate_parent_number IS NOT NULL
            THEN
                lv_ultimate_parent_number   := sel_rec.ultimate_parent_number;
            ELSE
                lv_ultimate_parent_number   := lv_attr15;
            END IF;

            IF sel_rec.buying_group_cust_num IS NOT NULL
            THEN
                lv_buying_group_cust_num   := sel_rec.buying_group_cust_num;
            ELSE
                lv_buying_group_cust_num   := lv_attr16;
            END IF;

            IF sel_rec.cust_membership_num IS NOT NULL
            THEN
                lv_cust_membership_num   := sel_rec.cust_membership_num;
            ELSE
                lv_cust_membership_num   := lv_attr17;
            END IF;

            IF sel_rec.buying_group_vat_num IS NOT NULL
            THEN
                lv_buying_group_vat_num   := sel_rec.buying_group_vat_num;
            ELSE
                lv_buying_group_vat_num   := lv_attr18;
            END IF;

            -- End of Change 1.2

            --START - Check if credit profile exists or not for the customer at party level

            IF lv_error = 'N'
            THEN
                IF ln_party_id IS NOT NULL
                THEN
                    SELECT COUNT (*)
                      INTO ln_credit_prof_exists_cnt
                      FROM hz_customer_profiles hcp
                     WHERE     1 = 1
                           AND hcp.status = 'A'
                           AND hcp.cust_account_id = -1 --For party profile, cust acct id is -1
                           AND hcp.party_id = ln_party_id;

                    IF ln_credit_prof_exists_cnt > 0
                    THEN
                        BEGIN
                            SELECT hcp.cust_account_profile_id, hcp.object_version_number, 'Y',
                                   hcp.credit_analyst_id, hcp.tolerance, hcp.profile_class_id,
                                   hcp.credit_checking -- Added for Change 1.2
                              INTO ln_cust_account_profile_id, ln_object_version_number, lv_credit_profile_exists, ln_old_credit_analyst_id, -- Added for CCR0006648
                                                             ln_old_tolerance, -- Added for CCR0006648
                                                                               ln_old_profile_class_id, -- Added for CCR0006648
                                                                                                        lv_old_credit_checking -- Added for Change 1.2
                              FROM hz_customer_profiles hcp
                             WHERE     1 = 1
                                   AND hcp.status = 'A'
                                   AND hcp.cust_account_id = -1 --For party profile, cust acct id is -1
                                   AND hcp.party_id = ln_party_id; --1255466448
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ln_cust_account_profile_id   := NULL;
                                lv_credit_profile_exists     := 'N';
                                ln_old_credit_analyst_id     := NULL;
                                ln_old_tolerance             := NULL;
                                ln_old_profile_class_id      := NULL;
                                lv_old_credit_checking       := NULL; -- Added for Change 1.2
                                lv_return_status             := g_ret_error;
                                lv_error                     := 'Y';
                                lv_error_message             :=
                                       lv_error_message
                                    || 'Exception Occurred while getting the credit profile ID.'
                                    || SUBSTR (SQLERRM, 1, 1900 || '.');
                        END;
                    ELSE
                        ln_cust_account_profile_id   := NULL;
                        lv_credit_profile_exists     := 'N';
                        ln_old_credit_analyst_id     := NULL;
                        ln_object_version_number     := NULL;
                        ln_old_profile_class_id      := NULL;
                        lv_old_credit_checking       := NULL; -- Added for Change 1.2
                    END IF;
                END IF;

                --END - Check if credit profile exists or not for the customer at party level

                /*Start of Change for CCR0006648 */
                --            IF ln_cust_account_profile_id IS NOT NULL
                --                THEN
                --                    BEGIN
                --                      SELECT  hcpa.trx_credit_limit,
                --                              hcpa.overall_credit_limit,
                --                              hcpa.currency_code,
                --                              hcpa.object_version_number,
                --                              hcpa.cust_acct_profile_amt_id
                --                       INTO   ln_p_trx_credit_limit,
                --                              ln_p_overall_credit_limit,
                --                              lv_p_old_currency_code,
                --                              ln_p_cust_acct_prof_ovn,
                --                              ln_p_cust_acct_profile_amt_id
                --                       FROM   apps.hz_cust_profile_amts hcpa
                --                      WHERE   hcpa.cust_account_id = -1
                --                        AND   hcpa.cust_account_profile_id = ln_cust_account_profile_id;
                --                    EXCEPTION
                --                          WHEN OTHERS THEN
                --                              ln_p_trx_credit_limit := NULL;
                --                              ln_p_overall_credit_limit := NULL;
                --                              lv_p_old_currency_code := NULL;
                --                              ln_p_cust_acct_prof_ovn := NULL;
                --                              ln_p_cust_acct_profile_amt_id := NULL;
                --                              lv_return_status := g_ret_error;
                --                              lv_error_message := lv_error_message ||'Exception Occurred while getting the Cust Account profile Amount ID.'||SUBSTR(SQLERRM, 1, 1900||'.');
                --                    END;
                --                ELSE
                --                    ln_p_trx_credit_limit := NULL;
                --                    ln_p_overall_credit_limit := NULL;
                --                    lv_p_old_currency_code := NULL;
                --                    ln_p_cust_acct_prof_ovn := NULL;
                --                    ln_p_cust_acct_profile_amt_id := NULL;
                --                END IF;

                -- As profile is changing the credit analyst, making sure to retain the old value

                IF     ln_credit_analyst_id IS NULL
                   AND ln_old_credit_analyst_id IS NOT NULL
                THEN
                    -- ln_n_credit_analyst_id := NULL;
                    ln_n_credit_analyst_id   := ln_old_credit_analyst_id;
                ELSIF ln_credit_analyst_id IS NOT NULL
                THEN
                    ln_n_credit_analyst_id   := ln_credit_analyst_id;
                END IF;

                IF ln_profile_class_id IS NULL
                THEN
                    ln_n_profile_class_id   := NULL;
                --ELSIF (ln_profile_class_id IS NOT NULL AND ln_profile_class_id <> ln_old_profile_class_id) -- 1.4
                ELSIF (ln_profile_class_id IS NOT NULL AND ln_profile_class_id <> NVL (ln_old_profile_class_id, 99999)) --1.4
                THEN
                    ln_n_profile_class_id   := ln_profile_class_id;
                --ELSIF (ln_profile_class_id IS NOT NULL AND ln_profile_class_id = ln_old_profile_class_id) --1.4
                ELSIF (ln_profile_class_id IS NOT NULL AND ln_profile_class_id = NVL (ln_old_profile_class_id, 99999)) --1.4
                THEN
                    ln_n_profile_class_id   := NULL;
                END IF;

                /*End of Change for CCR0006648 */

                --ln_credit_analyst_id := NVL(ln_credit_analyst_id,ln_old_credit_analyst_id);

                -- Start of Change 1.2

                IF lv_credit_checking IS NULL
                THEN
                    --                lv_n_credit_checking := lv_old_credit_checking;--NULL;
                    lv_n_credit_checking   := NULL;
                --ELSIF (lv_credit_checking IS NOT NULL AND lv_credit_checking <> lv_old_credit_checking)  --1.4
                ELSIF (lv_credit_checking IS NOT NULL AND lv_credit_checking <> NVL (lv_old_credit_checking, 'X')) --1.4
                THEN
                    lv_n_credit_checking   := lv_credit_checking;
                --ELSIF (lv_credit_checking IS NOT NULL AND lv_credit_checking = lv_old_credit_checking) --1.4
                ELSIF (lv_credit_checking IS NOT NULL AND lv_credit_checking = NVL (lv_old_credit_checking, 'X')) -- 1.4
                THEN
                    --                lv_n_credit_checking := lv_old_credit_checking;--NULL;
                    lv_n_credit_checking   := NULL;
                END IF;

                -- End of Change 1.2

                --If profile does not exists and customer category value is provided then create a profile at party level and
                --Update the customer category at the party level
                IF     ln_cust_account_profile_id IS NULL
                   AND lv_customer_category IS NOT NULL
                   AND lv_error = 'N'
                --(
                --ln_credit_analyst_id IS NOT NULL OR
                --lv_next_sched_review_date IS NOT NULL
                --)
                THEN
                    --call the procedure to create profile
                    create_profile (ln_party_id, ln_n_credit_analyst_id, lv_next_sched_review_date, lv_last_sched_review_date -- Added for Change 1.2
                                                                                                                             , lv_n_credit_checking -- Added for Change 1.2
                                                                                                                                                   , ln_n_profile_class_id, lv_credit_classification, lv_review_cycle, ln_cust_acct_prof_id
                                    , lv_api_ret_status, lv_api_ret_message);

                    IF     lv_api_ret_status = g_ret_success
                       AND ln_cust_acct_prof_id IS NOT NULL
                    THEN
                        SELECT COUNT (*)
                          INTO ln_cust_cat_exists
                          FROM apps.hz_parties hp
                         WHERE     1 = 1
                               AND hp.party_id = ln_party_id
                               AND hp.status = 'A'
                               AND NVL (hp.category_code, 'X') =
                                   lv_customer_category;

                        IF ln_cust_cat_exists <= 0
                        THEN
                            --dbms_output.put_line('Update');
                            lv_api_ret_status    := NULL;
                            lv_api_ret_message   := NULL;

                            --If the customer category does not exists or not same as the one given then update the customer category at party level
                            --else do nothing
                            --Call the procedure which updates the credit profile
                            update_party (ln_party_id, lv_customer_category--,ln_us_ven_vio_researcher_id
                                                                           , lv_api_ret_status
                                          , lv_api_ret_message);

                            --if api return status is not success then print the error
                            IF lv_api_ret_status <> g_ret_success
                            THEN
                                lv_return_status   := g_ret_error;
                                lv_error           := 'Y';
                                lv_error_message   :=
                                       lv_error_message
                                    || 'API Error while updating party''s customer category '
                                    || SUBSTR (lv_api_ret_message,
                                               1,
                                               1900 || '.');
                            --dbms_output.put_line('API Error1 - '|| lv_error_message);
                            ELSE
                                lv_return_status   := g_ret_success;
                            --dbms_output.put_line('No Error1');
                            END IF;
                        END IF;
                    ELSE
                        --if api return status is not success then print the error
                        lv_return_status   := g_ret_error;
                        lv_error           := 'Y';
                        lv_error_message   :=
                               lv_error_message
                            || 'API Error while updating credit profile '
                            || SUBSTR (lv_api_ret_message, 1, 1900 || '.');
                    END IF;
                ELSIF     ln_cust_account_profile_id IS NOT NULL
                      AND lv_customer_category IS NULL
                      AND lv_error = 'N'
                      AND (ln_credit_analyst_id IS NOT NULL OR lv_next_sched_review_date IS NOT NULL OR ln_profile_class_id IS NOT NULL OR lv_credit_classification IS NOT NULL OR lv_review_cycle IS NOT NULL OR lv_last_sched_review_date IS NOT NULL -- Added for Change 1.2
                                                                                                                                                                                                                                                        OR lv_credit_checking IS NOT NULL -- Added for Change 1.2
                                                                                                                                                                                                                                                                                         )
                THEN
                    --dbms_output.put_line('Update2');
                    --Start of change for 1.3
                    --get profile amts before profile update
                    BEGIN
                        SELECT hcpa.trx_credit_limit trx_credit_limit, hcpa.overall_credit_limit overall_credit_limit, hcpa.currency_code currency_code,
                               hcpa.cust_acct_profile_amt_id cust_acct_profile_amt_id
                          INTO ln_old_trx_credit_limit, ln_old_overall_credit_limit, lv_old_prof_currency_code, ln_old_cust_acct_prof_amt_id
                          FROM apps.hz_cust_profile_amts hcpa
                         WHERE     hcpa.cust_account_id = -1 --For party profile, cust acct id is -1
                               AND hcpa.cust_account_profile_id =
                                   ln_cust_account_profile_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_return_status   := g_ret_error;
                            lv_error           := 'Y';
                            lv_error_message   :=
                                   lv_error_message
                                || 'Error while getting profile amouts before profile update. '
                                || SUBSTR (SQLERRM, 1, 1900 || '.');
                    END;

                    --End of change for 1.3
                    --Call the procedure which updates the credit profile
                    update_profile (ln_cust_account_profile_id,
                                    ln_object_version_number,
                                    ln_n_credit_analyst_id,
                                    lv_next_sched_review_date,
                                    lv_last_sched_review_date -- Added for Change 1.2
                                                             ,
                                    lv_n_credit_checking -- Added for Change 1.2
                                                        ,
                                    ln_n_profile_class_id,
                                    lv_credit_classification,
                                    lv_review_cycle,
                                    ln_old_tolerance,
                                    lv_api_ret_status,
                                    lv_api_ret_message);

                    --if api return status is not success then print the error
                    IF lv_api_ret_status <> g_ret_success
                    THEN
                        lv_return_status   := g_ret_error;
                        lv_error           := 'Y';
                        lv_error_message   :=
                               lv_error_message
                            || 'API Error while updating credit profile '
                            || SUBSTR (lv_api_ret_message, 1, 1900 || '.');
                    ELSE
                        --Getting profile amount latest object version after profile update
                        --Start of Change for CCR0006824
                        BEGIN
                            SELECT MAX (hcpa.object_version_number) --hcpa.object_version_number
                              INTO ln_p_cust_acct_prof_ovn
                              FROM apps.hz_cust_profile_amts hcpa
                             WHERE     hcpa.cust_account_id = -1
                                   AND hcpa.cust_account_profile_id =
                                       ln_cust_account_profile_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_error_message   :=
                                       lv_error_message
                                    || 'Exception Occurred while getting the Cust Account profile Amount version.'
                                    || SUBSTR (SQLERRM, 1, 1900 || '.');
                                lv_error   := 'Y';
                        END;

                        --End of Change for CCR0006824
                        lv_return_status   := g_ret_success;
                        --Start of change for 1.3
                        --When profile is updated,profile values are updated to default values. Updating profile amts back to orginal values
                        update_cust_profile_amts (ln_old_cust_acct_prof_amt_id, ln_p_cust_acct_prof_ovn, ln_old_trx_credit_limit, ln_old_overall_credit_limit, lv_old_prof_currency_code, lv_api_ret_status
                                                  , lv_api_ret_message);

                        --if api return status is not success then print the error
                        IF lv_api_ret_status <> g_ret_success
                        THEN
                            lv_return_status   := g_ret_error;
                            lv_error_message   :=
                                   lv_error_message
                                || 'API Error while updating credit profile amounts '
                                || SUBSTR (lv_api_ret_message,
                                           1,
                                           1900 || '.');
                        ELSE
                            lv_return_status   := g_ret_success;
                        --dbms_output.put_line('Update4 - Cust profile amounts');
                        END IF;
                    --End of change for 1.3
                    --dbms_output.put_line('Update4');
                    END IF;
                ELSIF     ln_cust_account_profile_id IS NULL
                      AND lv_customer_category IS NULL
                THEN
                    lv_return_status   := g_ret_error;
                    lv_error           := 'Y';
                    lv_error_message   :=
                           lv_error_message
                        || 'Profile does not exists and also Customer Category is not provided';
                ELSIF     ln_cust_account_profile_id IS NOT NULL
                      AND lv_customer_category IS NOT NULL
                THEN
                    lv_return_status   := g_ret_error;
                    lv_error           := 'Y';
                    lv_error_message   :=
                           lv_error_message
                        || 'Profile exists, and Customer Category is also provided. Do not provide customer category';
                END IF;

                /*Start of Change for CCR0006648 */
                IF ln_cust_acct_prof_id IS NOT NULL
                THEN
                    ln_trx_credit_limit           := NULL;
                    ln_overall_credit_limit       := NULL;
                    lv_old_currency_code          := NULL;
                    ln_cust_acct_prof_ovn         := NULL;
                    ln_cust_acct_profile_amt_id   := NULL;

                    BEGIN
                        SELECT hcpa.trx_credit_limit, hcpa.overall_credit_limit, hcpa.currency_code,
                               hcpa.object_version_number, hcpa.cust_acct_profile_amt_id
                          INTO ln_trx_credit_limit, ln_overall_credit_limit, lv_old_currency_code, ln_cust_acct_prof_ovn,
                                                  ln_cust_acct_profile_amt_id
                          FROM apps.hz_cust_profile_amts hcpa
                         WHERE     hcpa.cust_account_id = -1
                               AND hcpa.cust_account_profile_id =
                                   ln_cust_acct_prof_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_trx_credit_limit           := NULL;
                            ln_overall_credit_limit       := NULL;
                            lv_old_currency_code          := NULL;
                            ln_cust_acct_prof_ovn         := NULL;
                            ln_cust_acct_profile_amt_id   := NULL;
                            lv_return_status              := g_ret_error;
                            lv_error                      := 'Y';
                            lv_error_message              :=
                                   lv_error_message
                                || 'Exception Occurred while getting the Cust Account profile Amount ID.'
                                || SUBSTR (SQLERRM, 1, 1900 || '.');
                    END;
                ELSE
                    ln_trx_credit_limit           := NULL;
                    ln_overall_credit_limit       := NULL;
                    lv_old_currency_code          := NULL;
                    ln_cust_acct_prof_ovn         := NULL;
                    ln_cust_acct_profile_amt_id   := NULL;
                END IF;

                IF lv_currency_code IS NOT NULL
                THEN
                    IF ln_cust_account_profile_id IS NOT NULL
                    THEN
                        ln_p_trx_credit_limit           := NULL;
                        ln_p_overall_credit_limit       := NULL;
                        lv_p_old_currency_code          := NULL;
                        ln_p_cust_acct_prof_ovn         := NULL;
                        ln_p_cust_acct_profile_amt_id   := NULL;
                        create_curr_flag                := 'N';

                        BEGIN
                            SELECT hcpa.trx_credit_limit trx_credit_limit, hcpa.overall_credit_limit overall_credit_limit, hcpa.currency_code currency_code,
                                   hcpa.object_version_number object_version_number, hcpa.cust_acct_profile_amt_id cust_acct_profile_amt_id
                              INTO ln_p_trx_credit_limit, ln_p_overall_credit_limit, lv_p_old_currency_code, ln_p_cust_acct_prof_ovn,
                                                        ln_p_cust_acct_profile_amt_id
                              FROM apps.hz_cust_profile_amts hcpa
                             WHERE     hcpa.cust_account_id = -1
                                   AND hcpa.cust_account_profile_id =
                                       ln_cust_account_profile_id
                                   AND hcpa.currency_code = lv_currency_code;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                create_curr_flag   := 'Y';
                        END;

                        --                    FOR i in
                        --                      (SELECT  hcpa.trx_credit_limit trx_credit_limit,
                        --                              hcpa.overall_credit_limit overall_credit_limit,
                        --                              hcpa.currency_code currency_code,
                        --                              hcpa.object_version_number object_version_number,
                        --                              hcpa.cust_acct_profile_amt_id cust_acct_profile_amt_id
                        --                       INTO   ln_p_trx_credit_limit,
                        --                              ln_p_overall_credit_limit,
                        --                              lv_p_old_currency_code,
                        --                              ln_p_cust_acct_prof_ovn,
                        --                              ln_p_cust_acct_profile_amt_id
                        --                       FROM   apps.hz_cust_profile_amts hcpa
                        --                      WHERE   hcpa.cust_account_id = -1
                        --                        AND   hcpa.cust_account_profile_id = ln_cust_account_profile_id
                        --                        AND   hcpa.currency_code = lv_currency_code)
                        --                    LOOP
                        --
                        --                              ln_p_trx_credit_limit := i.trx_credit_limit;
                        --                              ln_p_overall_credit_limit := i.overall_credit_limit;
                        --                              lv_p_old_currency_code := i.currency_code;
                        --                              ln_p_cust_acct_prof_ovn := i.object_version_number;
                        --                              ln_p_cust_acct_profile_amt_id := i.cust_acct_profile_amt_id;
                        ----                              lv_return_status := g_ret_error;
                        ----                              lv_error_message := lv_error_message ||'Exception Occurred while getting the Cust Account profile Amount ID.'||SUBSTR(SQLERRM, 1, 1900||'.');

                        --                    IF lv_currency_code IS NOT NULL
                        --                    THEN

                        IF NVL (lv_currency_code, 'ABC') =
                           NVL (lv_p_old_currency_code, 'ABC')
                        THEN
                            --                            create_curr_flag := 'N';
                            ln_n_cust_acct_prof_ovn   :=
                                ln_p_cust_acct_prof_ovn;
                            ln_n_cust_acct_profile_amt_id   :=
                                ln_p_cust_acct_profile_amt_id;
                            lv_n_currency_code   := lv_old_currency_code;

                            IF     ln_order_credit_limit IS NULL
                               AND ln_p_trx_credit_limit IS NOT NULL
                            THEN
                                ln_n_order_credit_limit   :=
                                    ln_p_trx_credit_limit;
                            ELSIF ln_order_credit_limit IS NOT NULL
                            THEN
                                ln_n_order_credit_limit   :=
                                    ln_order_credit_limit;
                            END IF;

                            IF     ln_credit_limit IS NULL
                               AND ln_p_overall_credit_limit IS NOT NULL
                            THEN
                                ln_n_credit_limit   :=
                                    ln_p_overall_credit_limit;
                            ELSIF ln_credit_limit IS NOT NULL
                            THEN
                                ln_n_credit_limit   := ln_credit_limit;
                            END IF;

                            IF     (ln_profile_class_id IS NOT NULL OR ln_order_credit_limit IS NOT NULL OR ln_credit_limit IS NOT NULL)
                               AND lv_error = 'N'
                            THEN
                                --dbms_output.put_line('Update2 - Cust Profile Amounts');
                                --Call the procedure which updates the customer profile amounts
                                update_cust_profile_amts (
                                    ln_n_cust_acct_profile_amt_id,
                                    ln_n_cust_acct_prof_ovn,
                                    ln_n_order_credit_limit,
                                    ln_n_credit_limit,
                                    lv_n_Currency_code,
                                    lv_api_ret_status,
                                    lv_api_ret_message);

                                --if api return status is not success then print the error
                                IF lv_api_ret_status <> g_ret_success
                                THEN
                                    lv_return_status   := g_ret_error;
                                    lv_error_message   :=
                                           lv_error_message
                                        || 'API Error while updating credit profile amounts '
                                        || SUBSTR (lv_api_ret_message,
                                                   1,
                                                   1900 || '.');
                                ELSE
                                    lv_return_status   := g_ret_success;
                                --dbms_output.put_line('Update4 - Cust profile amounts');
                                END IF;
                            END IF;
                        ELSIF NVL (lv_currency_code, 'ABC') <>
                              NVL (lv_p_old_currency_code, 'ABC')
                        THEN
                            --                            create_curr_flag := 'Y';
                            ln_n_cust_acct_profile_amt_id   :=
                                ln_p_cust_acct_profile_amt_id;
                            lv_n_currency_code   := lv_currency_code;

                            IF    ln_order_credit_limit IS NULL
                               OR ln_credit_limit IS NULL
                            THEN
                                lv_return_status   := g_ret_error;
                                lv_error_message   :=
                                       lv_error_message
                                    || ' Order Credit Limit and Overall Credit limit has to be provided for new currency ';
                                lv_error           := 'Y';
                            ELSE
                                ln_n_order_credit_limit   :=
                                    ln_order_credit_limit;
                                ln_n_credit_limit   := ln_credit_limit;
                            END IF;

                            IF     (ln_order_credit_limit IS NOT NULL AND ln_credit_limit IS NOT NULL AND create_curr_flag = 'Y')
                               AND lv_error = 'N'
                            THEN
                                --dbms_output.put_line('Update2 - Cust Profile Amounts');
                                --Call the procedure which updates the customer profile amounts

                                create_cust_profile_amts (
                                    pn_cust_acct_profile_id   =>
                                        ln_cust_account_profile_id,
                                    pn_trx_credit_limit   =>
                                        ln_n_order_credit_limit,
                                    pn_overall_credit_limit   =>
                                        ln_n_credit_limit,
                                    pv_Currency_code     => lv_n_Currency_code,
                                    xn_cust_acct_profile_amt_id   =>
                                        l_cust_acct_profile_amt_id,
                                    xv_api_ret_status    => lv_api_ret_status,
                                    xv_api_ret_message   => lv_api_ret_message);

                                --if api return status is not success then print the error
                                IF lv_api_ret_status <> g_ret_success
                                THEN
                                    lv_return_status   := g_ret_error;
                                    lv_error_message   :=
                                           lv_error_message
                                        || 'API Error while creating credit profile amounts '
                                        || SUBSTR (lv_api_ret_message,
                                                   1,
                                                   1900 || '.');
                                ELSE
                                    lv_return_status   := g_ret_success;
                                --dbms_output.put_line('Update4 - Cust profile amounts');
                                END IF;
                            END IF;
                        END IF;
                    --                    END LOOP;

                    ELSIF ln_cust_acct_prof_id IS NOT NULL
                    THEN
                        ln_n_cust_acct_prof_ovn   := ln_cust_acct_prof_ovn; --ln_p_cust_acct_prof_ovn;--Changed as per CCR  CCR0006824
                        ln_n_cust_acct_profile_amt_id   :=
                            ln_cust_acct_profile_amt_id;

                        IF     ln_order_credit_limit IS NULL
                           AND ln_trx_credit_limit IS NOT NULL
                        THEN
                            --ln_n_order_credit_limit := NULL;
                            ln_n_order_credit_limit   := ln_trx_credit_limit;
                        ELSIF ln_order_credit_limit IS NOT NULL
                        THEN
                            ln_n_order_credit_limit   :=
                                ln_order_credit_limit;
                        END IF;

                        IF     ln_credit_limit IS NULL
                           AND ln_overall_credit_limit IS NOT NULL
                        THEN
                            ln_n_credit_limit   := ln_overall_credit_limit;
                        ELSIF ln_credit_limit IS NOT NULL
                        THEN
                            ln_n_credit_limit   := ln_credit_limit;
                        END IF;

                        IF     (ln_profile_class_id IS NOT NULL OR ln_order_credit_limit IS NOT NULL OR ln_credit_limit IS NOT NULL OR lv_currency_code IS NOT NULL)
                           AND lv_error = 'N'
                        THEN
                            --dbms_output.put_line('Update2 - Cust Profile Amounts');
                            --Call the procedure which updates the customer profile amounts
                            update_cust_profile_amts (ln_n_cust_acct_profile_amt_id, ln_n_cust_acct_prof_ovn, ln_n_order_credit_limit, ln_n_credit_limit, lv_n_Currency_code, lv_api_ret_status
                                                      , lv_api_ret_message);

                            --if api return status is not success then print the error
                            IF lv_api_ret_status <> g_ret_success
                            THEN
                                lv_return_status   := g_ret_error;
                                lv_error_message   :=
                                       lv_error_message
                                    || 'API Error while updating credit profile amounts '
                                    || SUBSTR (lv_api_ret_message,
                                               1,
                                               1900 || '.');
                            ELSE
                                lv_return_status   := g_ret_success;
                            --dbms_output.put_line('Update4 - Cust profile amounts');
                            END IF;
                        END IF;
                    --dbms_output.put_line('Order Credit Limit is '||ln_n_order_credit_limit);
                    --dbms_output.put_line('Overall Credit Limit is '||ln_n_credit_limit);
                    END IF;
                END IF;
            END IF;

            /*End of Change for CCR0006648 */

            IF    lv_error_message IS NOT NULL
               OR lv_return_status <> 'S'
               OR lv_error = 'Y'
            THEN
                --If any validation errors, Insert the data into the staging table with appropriate status and error messages
                lv_return_status   := g_ret_error;

                --Update the staging table with the error message and status
                update_stg_table (pn_seq_id => sel_rec.seq_id, pv_return_status => lv_return_status, pv_error_message => SUBSTR (lv_error_message, 1, 2000)
                                  , xv_error_message => lv_upd_err_message);
            ELSIF     lv_return_status = 'S'
                  AND ln_party_id IS NOT NULL
                  AND lv_error = 'N'
            THEN
                lv_return_status   := g_ret_success;

                IF     lv_attr_category = 'Customer'
                   AND (sel_rec.us_ven_vio_researcher IS NOT NULL OR sel_rec.us_freight_researcher IS NOT NULL OR sel_rec.us_discount_researcher IS NOT NULL OR sel_rec.us_credit_memo_researcher IS NOT NULL OR sel_rec.us_short_payment_researcher IS NOT NULL OR sel_rec.safe_number IS NOT NULL OR sel_rec.parent_number IS NOT NULL OR sel_rec.ultimate_parent_number IS NOT NULL -- Added for Change 1.2
                                                                                                                                                                                                                                                                                                                                                                                       OR sel_rec.buying_group_cust_num IS NOT NULL OR sel_rec.cust_membership_num IS NOT NULL OR sel_rec.buying_group_vat_num IS NOT NULL -- Added for Change 1.2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          )
                THEN
                    UPDATE apps.hz_parties
                       SET attribute4 = ln_us_ven_vio_researcher_id, attribute5 = ln_us_freight_researcher_id, attribute9 = ln_us_discount_researcher_id,
                           attribute10 = ln_us_credit_memo_research_id, attribute11 = ln_us_short_pay_research_id, attribute13 = lv_safe_number, -- added for Change 1.2
                           attribute14 = lv_parent_number, -- added for Change 1.2
                                                           attribute15 = lv_ultimate_parent_number, -- added for Change 1.2
                                                                                                    attribute16 = lv_buying_group_cust_num, -- added for Change 1.2
                           attribute17 = lv_cust_membership_num, -- added for Change 1.2
                                                                 attribute18 = lv_buying_group_vat_num, -- added for Change 1.2
                                                                                                        last_updated_by = gn_user_id,
                           last_update_date = SYSDATE
                     WHERE party_id = ln_party_id;
                --  COMMIT;
                END IF;

                --Update the staging table with Success status
                update_stg_table (pn_seq_id => sel_rec.seq_id, pv_return_status => lv_return_status, pv_error_message => NULL
                                  , xv_error_message => lv_upd_err_message);
            ELSIF     lv_return_status IS NULL
                  AND ln_party_id IS NOT NULL
                  AND lv_error = 'N'
                  AND (sel_rec.us_ven_vio_researcher IS NOT NULL OR sel_rec.us_freight_researcher IS NOT NULL OR sel_rec.us_discount_researcher IS NOT NULL OR sel_rec.us_credit_memo_researcher IS NOT NULL OR sel_rec.us_short_payment_researcher IS NOT NULL OR sel_rec.safe_number IS NOT NULL OR sel_rec.parent_number IS NOT NULL OR sel_rec.ultimate_parent_number IS NOT NULL -- Added for Change 1.2
                                                                                                                                                                                                                                                                                                                                                                                      OR sel_rec.buying_group_cust_num IS NOT NULL OR sel_rec.cust_membership_num IS NOT NULL OR sel_rec.buying_group_vat_num IS NOT NULL -- Added for Change 1.2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         )
            THEN
                lv_return_status   := g_ret_success;

                IF lv_attr_category = 'Customer'
                THEN
                    UPDATE apps.hz_parties
                       SET attribute4 = ln_us_ven_vio_researcher_id, attribute5 = ln_us_freight_researcher_id, attribute9 = ln_us_discount_researcher_id,
                           attribute10 = ln_us_credit_memo_research_id, attribute11 = ln_us_short_pay_research_id, attribute13 = lv_safe_number, -- added for Change 1.2
                           attribute14 = lv_parent_number, -- added for Change 1.2
                                                           attribute15 = lv_ultimate_parent_number, -- added for Change 1.2
                                                                                                    attribute16 = lv_buying_group_cust_num, -- added for Change 1.2
                           attribute17 = lv_cust_membership_num, -- added for Change 1.2
                                                                 attribute18 = lv_buying_group_vat_num, -- added for Change 1.2
                                                                                                        last_updated_by = gn_user_id,
                           last_update_date = SYSDATE
                     WHERE party_id = ln_party_id;
                --COMMIT;
                END IF;

                --Update the staging table with Success status
                update_stg_table (pn_seq_id => sel_rec.seq_id, pv_return_status => lv_return_status, pv_error_message => NULL
                                  , xv_error_message => lv_upd_err_message);
            END IF;
        END LOOP;

        --Call procedure which sends the program processing details as an email to the user who submitted it and
        --to the email ids configured in the lookup 'XXD_CUST_CREDIT_PROF_UPD_EMAIL'
        send_email_proc (ln_batch_id);
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_error_message   :=
                SUBSTR (lv_error_message || '.' || SQLERRM, 1, 2000);
    --raise_application_error (-20001, lv_error_message);

    END importer_proc;
END XXD_PARTY_CREDIT_WEBADI_PKG;
/
