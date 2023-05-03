--
-- XXD_AR_LCX_INVOICES_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:24 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AR_LCX_INVOICES_PKG"
AS
    --  ####################################################################################################
    --  Author(s)       : Srinath Siricilla
    --  System          : Oracle Applications
    --  Subsystem       : EBS
    --  Change          : CCR0007668
    --  Schema          : APPS
    --  Purpose         : Lucernex AR Inbound
    --                  : Package is used to create AR transactions
    --  Dependency      : None
    --  Change History
    --  --------------
    --  Date            Name                Ver     Change          Description
    --  ----------      --------------      -----   -------------   ---------------------
    --  02-OCT-2019     Srinath Siricilla   1.0     NA              Initial Version
    --  02-NOV-2021     Laltu Sah           1.1     NA              CCR0009680-AR credit memo in incorrect period
    --  ####################################################################################################
    --Global Variables declaration

    gv_package_name      CONSTANT VARCHAR2 (30) := 'XXD_AR_LCX_INVOICES_PKG.';
    gn_user_id           CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id          CONSTANT NUMBER := fnd_global.login_id;
    gn_resp_id           CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id      CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_conc_request_id   CONSTANT NUMBER := fnd_global.conc_request_id;
    gd_sysdate           CONSTANT DATE := SYSDATE;
    gv_as_of_date                 VARCHAR2 (30) := NULL;
    gv_brand                      VARCHAR2 (30) := NULL;
    gd_as_of_date                 DATE := NULL;
    gv_trx_date_from              VARCHAR2 (30) := NULL;
    gv_trx_date_to                VARCHAR2 (30) := NULL;
    gd_trx_date_from              DATE := NULL;
    gd_trx_date_to                DATE := NULL;
    gv_reprocess_flag             VARCHAR2 (1) := NULL;
    g_interfaced                  VARCHAR2 (1) := 'I';
    g_errored                     VARCHAR2 (1) := 'E';
    g_validated                   VARCHAR2 (1) := 'V';
    g_processed                   VARCHAR2 (1) := 'P';
    g_created                     VARCHAR2 (1) := 'C';
    g_new                         VARCHAR2 (1) := 'N';
    g_other                       VARCHAR2 (1) := 'O';
    g_tax_line                    VARCHAR2 (1) := 'T';
    g_ignore                      VARCHAR2 (1) := 'U';
    gn_resp_name                  VARCHAR2 (120)
                                      := 'Deckers Receivables Super User';

    --Procedure to print messages into either log or output files
    --Parameters
    --PV_MSG        Message to be printed
    --PV_TIME       Print time or not. Default is no.
    --PV_FILE       Print to LOG or OUTPUT file. Default write it to LOG file
    PROCEDURE msg (pv_msg    IN VARCHAR2,
                   pv_time   IN VARCHAR2 DEFAULT 'N',
                   pv_file   IN VARCHAR2 DEFAULT 'LOG')
    IS
        --Local Variables
        lv_proc_name    VARCHAR2 (30) := 'MSG';
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

        IF UPPER (pv_file) = 'OUT'
        THEN
            IF gn_user_id = -1
            THEN
                DBMS_OUTPUT.put_line (lv_msg);
            ELSE
                fnd_file.put_line (fnd_file.output, lv_msg);
            END IF;
        ELSE
            IF gn_user_id = -1
            THEN
                DBMS_OUTPUT.put_line (lv_msg);
            ELSE
                fnd_file.put_line (fnd_file.LOG, lv_msg);
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'In When Others exception in '
                || gv_package_name
                || '.'
                || lv_proc_name
                || ' procedure. Error is: '
                || SQLERRM);
    END msg;

    FUNCTION get_responsibility_id (p_org_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_resp_id   NUMBER;
    BEGIN
        SELECT frv.responsibility_id
          INTO ln_resp_id
          FROM apps.fnd_profile_options_vl fpo, apps.fnd_responsibility_vl frv, apps.fnd_profile_option_values fpov,
               apps.hr_organization_units hou
         WHERE     1 = 1
               AND hou.organization_id = p_org_id
               AND fpov.profile_option_value = TO_CHAR (hou.organization_id)
               AND fpo.profile_option_id = fpov.profile_option_id
               AND fpo.user_profile_option_name = 'MO: Operating Unit'
               AND frv.responsibility_id = fpov.level_value
               AND frv.application_id = 222                               --AR
               AND frv.responsibility_name LIKE gn_resp_name || '%' --Deckers Receivables Super User Responsibility
               AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                               NVL (frv.start_date, SYSDATE))
                                       AND TRUNC (
                                               NVL (frv.end_date, SYSDATE))
               AND ROWNUM = 1;

        RETURN ln_resp_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_responsibility_id;

    -- Get Org_id for a given operating unit

    FUNCTION get_org_id (p_org_name   IN     VARCHAR2,
                         x_org_id        OUT NUMBER,
                         x_ret_msg       OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        ln_org_id   NUMBER;
    BEGIN
        SELECT hrou.organization_id
          INTO x_org_id
          FROM apps.hr_operating_units hrou
         WHERE     1 = 1
               AND UPPER (TRIM (hrou.name)) = UPPER (TRIM (p_org_name))
               AND NVL (hrou.date_from, SYSDATE) <= SYSDATE
               AND NVL (hrou.date_to, SYSDATE) >= SYSDATE;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                ' Invalid Operating Unit Name for OU: ' || p_org_name;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple Operating Units exist for OU: ' || p_org_name;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   ' '
                || ' Operating Unit Exception : '
                || p_org_name
                || ' : '
                || SUBSTR (SQLERRM, 1, 200);
            RETURN FALSE;
    END get_org_id;

    -- get AR batch source id for Operating Unit

    FUNCTION get_batch_source_id (p_org_id IN NUMBER, p_org_name IN VARCHAR2, x_batch_source_id OUT NUMBER
                                  , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT ffvl.attribute2
          INTO x_batch_source_id
          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
         WHERE     1 = 1
               AND ffvs.flex_value_set_name = 'XXD_AR_LCX_SOURCE_OU_VS'
               AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
               AND NVL (ffvl.enabled_flag, 'Y') = 'Y'
               AND ffvl.attribute1 = p_org_id
               AND NVL (ffvl.start_date_active, SYSDATE) <= SYSDATE
               AND NVL (ffvl.end_date_active, SYSDATE) >= SYSDATE;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                   ' Batch source is not found in valueset for OU : '
                || p_org_name;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple batch sources exist for OU: ' || p_org_name;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   ' '
                || ' Batch source exception : '
                || p_org_name
                || ' : '
                || SUBSTR (SQLERRM, 1, 200);
            RETURN FALSE;
    END get_batch_source_id;

    -- Get Batch Source name from ID

    FUNCTION get_batch_source_name (p_batch_source_id IN NUMBER, p_org_id IN NUMBER, x_batch_source_name OUT VARCHAR2
                                    , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT name
          INTO x_batch_source_name
          FROM ra_batch_sources_all
         WHERE     1 = 1
               AND batch_source_id = p_batch_source_id
               AND org_id = p_org_id
               AND NVL (start_date, SYSDATE) <= SYSDATE
               AND NVL (end_date, SYSDATE) >= SYSDATE;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                   ' Batch source does not exist for source ID : '
                || p_batch_source_id;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' Multiple batch sources exist for Source ID : '
                || p_batch_source_id;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   ' '
                || ' Batch Source ID exception : '
                || p_batch_source_id
                || ' : '
                || SUBSTR (SQLERRM, 1, 200);
            RETURN FALSE;
    END get_batch_source_name;

    --Get Currency code for the OU

    FUNCTION get_currency_code (p_org_id IN NUMBER, p_org_name IN VARCHAR2, x_curr_code OUT VARCHAR2
                                , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    --        ln_org_id    NUMBER;
    BEGIN
        SELECT gs.currency_code
          INTO x_curr_code
          FROM apps.gl_ledgers gs, apps.financials_system_params_all os, apps.hr_operating_units ho
         WHERE     os.set_of_books_id = gs.ledger_id
               AND ho.organization_id = os.org_id
               AND ho.organization_id = p_org_id;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' No currecny found for OU: ' || p_org_name;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple currencies exist for OU: ' || p_org_name;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   ' '
                || ' Currency Exception : '
                || p_org_name
                || ' : '
                || SUBSTR (SQLERRM, 1, 200);
            RETURN FALSE;
    END get_currency_code;


    -- Fetch Customer Transaction Type ID

    FUNCTION get_cust_trx_type (p_trx_type_name IN VARCHAR2, p_org_id IN NUMBER, x_trx_type_id OUT NUMBER
                                , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT rctta.cust_trx_type_id
          INTO x_trx_type_id
          FROM apps.ra_cust_trx_types_all rctta
         WHERE     1 = 1
               AND UPPER (TRIM (rctta.name)) = UPPER (TRIM (p_trx_type_name))
               AND NVL (rctta.end_date, SYSDATE) >= SYSDATE
               AND rctta.org_id = p_org_id;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                ' Customer transaction type not found : ' || p_trx_type_name;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' Multiple Customer transaction types exist for OU: '
                || p_trx_type_name;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   ' '
                || ' Customer transaction type Exception : '
                || p_trx_type_name
                || ' : '
                || SUBSTR (SQLERRM, 1, 200);
            RETURN FALSE;
    END get_cust_trx_type;

    -- Get the Credit Memo Reason type

    FUNCTION get_reason_code (p_reason_name IN VARCHAR2, x_reason_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT lookup_code
          INTO x_reason_code
          FROM apps.ar_lookups
         WHERE     1 = 1
               AND lookup_type = 'CREDIT_MEMO_REASON'
               AND UPPER (meaning) = TRIM (UPPER (p_reason_name))
               AND enabled_flag = 'Y'
               AND NVL (start_date_active, SYSDATE) <= SYSDATE
               AND NVL (end_date_active, SYSDATE) >= SYSDATE;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid Reason Name: ' || p_reason_name;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   := ' Multiple Reason names exist : ' || p_reason_name;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   ' '
                || 'Reason name Exception : '
                || p_reason_name
                || ' : '
                || SUBSTR (SQLERRM, 1, 200);
            RETURN FALSE;
    END get_reason_code;

    -- Validate Customer Account Number

    FUNCTION get_cust_account_id (p_cust_acct_num    IN     VARCHAR2,
                                  x_cust_acct_id        OUT NUMBER,
                                  x_party_id            OUT NUMBER,
                                  x_cust_acct_name      OUT VARCHAR2,
                                  x_ret_msg             OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT hca.cust_account_id, hzp.party_id, hzp.party_name
          INTO x_cust_acct_id, x_party_id, x_cust_acct_name
          FROM apps.hz_cust_accounts hca, apps.hz_parties hzp
         WHERE     1 = 1
               AND hca.party_id = hzp.party_id
               AND NVL (hca.status, 'A') = 'A'
               AND hca.account_number = p_cust_acct_num;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                ' Customer account number is not found : ' || p_cust_acct_num;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple customer accounts exist : ' || p_cust_acct_num;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   ' '
                || 'Customer account number Exception : '
                || p_cust_acct_num
                || ' : '
                || SUBSTR (SQLERRM, 1, 200);
            RETURN FALSE;
    END get_cust_account_id;

    --Get the Customer Bill to address id

    FUNCTION get_orig_bill_address_id (p_cust_acct_id IN NUMBER, p_cust_acct_num IN VARCHAR2, p_org_name IN VARCHAR2
                                       , p_org_id IN NUMBER, x_orig_bill_address_id OUT NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT hcasa.cust_acct_site_id
          INTO x_orig_bill_address_id
          FROM hz_cust_accounts hca, hz_cust_acct_sites_all hcasa, hz_cust_site_uses_all hcsua
         WHERE     1 = 1
               AND hcasa.cust_account_id = hca.cust_account_id
               AND hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
               AND hcsua.site_use_code = 'BILL_TO'
               AND hcsua.primary_flag = 'Y'
               AND hcasa.org_id = hcsua.org_id
               AND hca.status = 'A'
               AND hcasa.status = 'A'
               AND hcsua.status = 'A'
               AND hca.cust_account_id = p_cust_acct_id
               AND hcasa.org_id = p_org_id;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                   ' Primary billing address is not found for Account: '
                || p_cust_acct_num
                || ' in OU: '
                || p_org_name;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple primary address exists : ' || p_cust_acct_num;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   ' '
                || 'Primary address Exception for Customer: '
                || p_cust_acct_num
                || ' : '
                || SUBSTR (SQLERRM, 1, 200);
            RETURN FALSE;
    END get_orig_bill_address_id;


    -- Check whether the Brand is valid or Not

    FUNCTION is_brand_valid (p_brand     IN     VARCHAR2,
                             x_brand        OUT VARCHAR2,
                             x_ret_msg      OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT lookup_code
          INTO x_brand
          FROM apps.FND_LOOKUP_VALUES
         WHERE     1 = 1
               AND lookup_type = 'DO_BRANDS'
               AND NVL (start_date_active, SYSDATE) <= SYSDATE
               AND NVL (end_date_active, SYSDATE) >= SYSDATE
               AND enabled_flag = 'Y'
               AND language = USERENV ('LANG')
               AND TRIM (UPPER (lookup_code)) = TRIM (UPPER (p_brand));

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Brand is not found : ' || p_brand;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple brands exist with same name : ' || p_brand;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   ' '
                || 'Brand Name Exception : '
                || p_brand
                || ' : '
                || SUBSTR (SQLERRM, 1, 200);
            RETURN FALSE;
    END is_brand_valid;

    --- Check if the date is in closed period then get the first day of open period

    FUNCTION is_trx_date_valid (p_gl_date   IN     DATE,
                                p_org_id    IN     NUMBER,
                                x_ret_msg      OUT VARCHAR2)
        RETURN DATE
    IS
        l_valid_date   DATE := NULL;
        ln_count       NUMBER := 0;
    BEGIN
        SELECT p_gl_date
          INTO l_valid_date
          FROM apps.gl_period_statuses gps, apps.hr_operating_units hrou
         WHERE     1 = 1
               AND gps.application_id = 222                               --AR
               AND gps.ledger_id = hrou.set_of_books_id
               AND hrou.organization_id = p_org_id
               AND gps.start_date <= p_gl_date
               AND gps.end_date >= p_gl_date
               AND gps.closing_status IN ('O');

        RETURN l_valid_date;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            BEGIN
                --               Getting latest period start date if there are multiple peiords open

                /* SELECT MAX (gps.start_date)
                   INTO l_valid_date
                   FROM apps.gl_period_statuses gps, apps.hr_operating_units hrou
                  WHERE     1 = 1
                        AND gps.application_id = 222                           --AR
                        AND gps.ledger_id = hrou.set_of_books_id
                        AND hrou.organization_id = p_org_id
                        --               AND      gps.start_date      <= p_date
                        --               AND      gps.end_date        >= p_date
                        AND gps.closing_status IN ('O');*/
                -- Comment for CCR0009680
                ---Start Change for CCR0009680
                SELECT gps.start_date
                  INTO l_valid_date
                  FROM apps.gl_period_statuses gps, apps.hr_operating_units hrou
                 WHERE     1 = 1
                       AND gps.application_id = 222                       --AR
                       AND gps.ledger_id = hrou.set_of_books_id
                       AND hrou.organization_id = p_org_id
                       AND SYSDATE BETWEEN gps.start_date AND gps.end_date
                       AND gps.closing_status IN ('O');

                RETURN l_valid_date;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    BEGIN
                        SELECT MIN (gps.start_date)
                          INTO l_valid_date
                          FROM apps.gl_period_statuses gps, apps.hr_operating_units hrou
                         WHERE     1 = 1
                               AND gps.application_id = 222
                               AND gps.ledger_id = hrou.set_of_books_id
                               AND hrou.organization_id = p_org_id
                               AND gps.closing_status IN ('O');

                        RETURN l_valid_date;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            x_ret_msg      :=
                                   ' Exception in getting first open period date for org id : '
                                || p_org_id;
                            l_valid_date   := NULL;
                    END;
                ---End Change for CCR0009680
                WHEN OTHERS
                THEN
                    x_ret_msg      :=
                           ' Exception in getting current open period date for org id : '
                        || p_org_id;
                    l_valid_date   := NULL;
            END;

            RETURN l_valid_date;
        WHEN OTHERS
        THEN
            x_ret_msg      :=
                   ' Exception in getting open period date : '
                || p_gl_date
                || ' for org id : '
                || p_org_id;
            l_valid_date   := NULL;
            RETURN l_valid_date;
    END is_trx_date_valid;

    -- Check if the transaction amount is valid

    FUNCTION is_trx_amt_valid (p_trx_amt IN NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        ln_value   NUMBER := 0;
    BEGIN
        SELECT p_trx_amt / 1 INTO ln_value FROM DUAL;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   ' Exception in Transaction Amount : '
                || p_trx_amt
                || ' : '
                || SUBSTR (SQLERRM, 1, 200);
            RETURN FALSE;
    END is_trx_amt_valid;

    -- Validate Flag (Yes/No)

    FUNCTION is_flag_valid (p_tax_flag   IN     VARCHAR2,
                            x_tax_flag      OUT VARCHAR2,
                            x_ret_msg       OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT lookup_code
          INTO x_tax_flag
          FROM apps.fnd_lookups
         WHERE     lookup_type = 'YES_NO'
               AND enabled_flag = 'Y'
               AND UPPER (meaning) = UPPER (TRIM (p_tax_flag));

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                   ' Invalid - Value can be either Yes or No only : '
                || p_tax_flag;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' Multiple Lookup values exist with same code : '
                || p_tax_flag;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                ' ' || 'Exception Lookup Code: ' || SUBSTR (SQLERRM, 1, 200);
            RETURN FALSE;
    END is_flag_valid;

    -- Validate print option

    FUNCTION is_print_option_valid (p_print_option IN VARCHAR2, x_print_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT lookup_code
          INTO x_print_code
          FROM apps.ar_lookups
         WHERE     1 = 1
               AND lookup_type = 'INVOICE_PRINT_OPTIONS'
               AND UPPER (meaning) = TRIM (UPPER (p_print_option))
               AND enabled_flag = 'Y'
               AND NVL (start_date_active, SYSDATE) <= SYSDATE
               AND NVL (end_date_active, SYSDATE) >= SYSDATE;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid Reason Name: ' || p_print_option;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple Reason names exist : ' || p_print_option;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   ' '
                || ' Reason name Exception : '
                || p_print_option
                || ' : '
                || SUBSTR (SQLERRM, 1, 200);
            RETURN FALSE;
    END is_print_option_valid;

    -- Validate Salesrep name

    FUNCTION is_sales_rep_valid (p_sales_per_name IN VARCHAR2, p_org_id IN NUMBER, x_sales_rep_id OUT NUMBER
                                 , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT jss.salesrep_id
          INTO x_sales_rep_id
          FROM apps.jtf_rs_salesreps jss, apps.jtf_rs_resource_extns_vl jrext
         WHERE     jss.resource_id = jrext.resource_id
               AND NVL (jss.start_date_active, SYSDATE) <= SYSDATE
               AND NVL (jss.end_date_active, SYSDATE) >= SYSDATE
               AND jss.status = 'A'
               AND jss.org_id = p_org_id
               AND NVL (jrext.start_date_active, SYSDATE) <= SYSDATE
               AND NVL (jrext.end_date_active, SYSDATE) >= SYSDATE
               AND TRIM (UPPER (jrext.resource_name)) =
                   TRIM (UPPER (p_sales_per_name));

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Sales Rep not found : ' || p_sales_per_name;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple Salesrep names exist : ' || p_sales_per_name;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   ' '
                || ' Salesrep name Exception : '
                || p_sales_per_name
                || ' : '
                || SUBSTR (SQLERRM, 1, 200);
            RETURN FALSE;
    END is_sales_rep_valid;

    -- Get the GL Code Combination ID

    FUNCTION is_gl_code_valid (p_gl_code   IN     VARCHAR2,
                               x_ccid         OUT NUMBER,
                               x_ret_msg      OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT code_combination_id
          INTO x_ccid
          FROM gl_code_combinations_kfv
         WHERE     1 = 1
               AND enabled_flag = 'Y'
               AND concatenated_segments = p_gl_code;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                ' Please check the GL Code segments provided = ' || p_gl_code;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple Code Combinations exist = ' || p_gl_code;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   ' '
                || 'Code Combination Exception : '
                || SUBSTR (SQLERRM, 1, 200);
            RETURN FALSE;
    END is_gl_code_valid;

    -- Procedure to Insert data into  Staging table

    PROCEDURE insert_staging (x_ret_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2, p_file_name IN VARCHAR2, p_org_name IN VARCHAR2, p_trx_type IN VARCHAR2, p_brand IN VARCHAR2, p_account_num IN VARCHAR2, p_trx_date_from IN VARCHAR2, p_trx_date_to IN VARCHAR2
                              , p_reprocess IN VARCHAR2)
    IS
        CURSOR lcx_hdr_line_cur IS
              SELECT *
                FROM xxdo.xxd_ar_lcx_invoices_t
               WHERE     1 = 1
                     AND file_name = NVL (p_file_name, file_name)
                     AND operating_unit = NVL (p_org_name, operating_unit)
                     AND transaction_type = NVL (p_trx_type, transaction_type)
                     AND brand = NVL (p_brand, brand)
                     AND account_number = NVL (p_account_num, account_number)
                     AND TO_CHAR (transaction_date, 'RRRR/MM/DD HH24:MI:SS') BETWEEN NVL (
                                                                                         p_trx_date_from,
                                                                                         TO_CHAR (
                                                                                             transaction_date,
                                                                                             'RRRR/MM/DD HH24:MI:SS'))
                                                                                 AND NVL (
                                                                                         p_trx_date_to,
                                                                                         TO_CHAR (
                                                                                             transaction_date,
                                                                                             'RRRR/MM/DD HH24:MI:SS'))
                     AND NVL (status, 'N') =
                         DECODE (p_reprocess, 'Y', 'E', 'N')
            ORDER BY operating_unit, account_number, transaction_type;

        lv_proc_name   VARCHAR2 (30) := 'INSERT_STAGING';
    BEGIN
        msg ('Inserting into Table', 'N', 'LOG');

        FOR trx_rec IN lcx_hdr_line_cur
        LOOP
            --msg('Inserting into Table', 'N', 'LOG');
            BEGIN
                INSERT INTO xxdo.xxd_ar_lcx_invoices_stg_t (
                                record_id,
                                file_name,
                                file_processed_date,
                                status,
                                error_msg,
                                request_id,
                                operating_unit,
                                transaction_type,
                                reason_code,
                                account_number,
                                customer,
                                brand,
                                transaction_date,
                                amount,
                                tax_exempt,
                                print_option,
                                sales_representative,
                                cust_po_number,
                                gl_code,
                                comments,
                                GROUPING,
                                creation_date,
                                created_by,
                                last_update_date,
                                last_updated_by,
                                last_update_login,
                                org_id,
                                batch_source_name,
                                batch_source_id,
                                cust_trx_type_name,
                                cust_trx_type_id,
                                cust_account_id,
                                party_id,
                                bill_to_location_id,
                                term_name,
                                term_id,
                                line_description)
                     VALUES (trx_rec.record_id, trx_rec.file_name, trx_rec.file_processed_date, trx_rec.status, trx_rec.error_msg, trx_rec.request_id, trx_rec.operating_unit, trx_rec.transaction_type, trx_rec.reason_code, trx_rec.account_number, trx_rec.customer, trx_rec.brand, TO_DATE (trx_rec.transaction_date), trx_rec.amount, trx_rec.tax_exempt, trx_rec.print_option, trx_rec.sales_representative, trx_rec.cust_po_number, trx_rec.gl_code, SUBSTRB (TRIM (trx_rec.comments), 1, 1760), SUBSTRB (TRIM (trx_rec.GROUPING), 1, 240), gd_sysdate, gn_user_id, gd_sysdate, gn_user_id, gn_login_id, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
                             , NULL);
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_code   := '2';
                    x_ret_msg    :=
                        SUBSTR (
                               'Exception while Inserting the staging Data within Loop '
                            || gv_package_name
                            || lv_proc_name
                            || '. Error is : '
                            || SQLERRM,
                            1,
                            2000);
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code   := '2';
            x_ret_msg    :=
                SUBSTR (
                       'Exception while Inserting the staging Data outside Loop '
                    || gv_package_name
                    || lv_proc_name
                    || '. Error is : '
                    || SQLERRM,
                    1,
                    2000);
    END Insert_Staging;

    PROCEDURE update_staging (x_ret_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2, p_file_name IN VARCHAR2, p_org_name IN VARCHAR2, p_trx_type IN VARCHAR2, p_brand IN VARCHAR2, p_account_num IN VARCHAR2, p_trx_date_from IN VARCHAR2, p_trx_date_to IN VARCHAR2
                              , p_reprocess IN VARCHAR2)
    IS
        CURSOR lcx_hdr_lin_upd_cur IS
              SELECT *
                FROM xxdo.xxd_ar_lcx_invoices_t
               WHERE     1 = 1
                     AND file_name = NVL (p_file_name, file_name)
                     AND operating_unit = NVL (p_org_name, operating_unit)
                     AND transaction_type = NVL (p_trx_type, transaction_type)
                     AND brand = NVL (p_brand, brand)
                     AND account_number = NVL (p_account_num, account_number)
                     AND TO_CHAR (transaction_date, 'RRRR/MM/DD HH24:MI:SS') BETWEEN NVL (
                                                                                         p_trx_date_from,
                                                                                         TO_CHAR (
                                                                                             transaction_date,
                                                                                             'RRRR/MM/DD HH24:MI:SS'))
                                                                                 AND NVL (
                                                                                         p_trx_date_to,
                                                                                         TO_CHAR (
                                                                                             transaction_date,
                                                                                             'RRRR/MM/DD HH24:MI:SS'))
                     AND NVL (status, 'N') =
                         DECODE (p_reprocess, 'Y', 'E', 'N')
            ORDER BY operating_unit, account_number, transaction_type;

        lv_proc_name   VARCHAR2 (30) := 'UPDATE_STAGING';
    BEGIN
        FOR i IN lcx_hdr_lin_upd_cur
        LOOP
            UPDATE xxdo.xxd_ar_lcx_invoices_t
               SET Status = 'N', request_id = gn_conc_request_id
             WHERE record_id = i.record_id;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code   := '2';
            x_ret_msg    :=
                SUBSTR (
                       'Exception while updating the staging table '
                    || gv_package_name
                    || lv_proc_name
                    || '. Error is : '
                    || SQLERRM,
                    1,
                    2000);
    END update_staging;

    -- Procedure to validate the columns and update the data in Staging table

    PROCEDURE validate_staging (x_ret_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2, p_file_name IN VARCHAR2, p_org_name IN VARCHAR2, p_trx_type IN VARCHAR2, p_brand IN VARCHAR2, p_account_num IN VARCHAR2, p_trx_date_from IN VARCHAR2, p_trx_date_to IN VARCHAR2
                                , p_reprocess IN VARCHAR2)
    IS
        CURSOR lcx_hdr_line_cur                         --(pv_org IN VARCHAR2)
                                IS
              SELECT *
                FROM xxdo.xxd_ar_lcx_invoices_stg_t
               WHERE     1 = 1
                     AND file_name = NVL (p_file_name, file_name)
                     AND operating_unit = NVL (p_org_name, operating_unit)
                     AND transaction_type = NVL (p_trx_type, transaction_type)
                     AND brand = NVL (p_brand, brand)
                     AND account_number = NVL (p_account_num, account_number)
                     AND TO_CHAR (transaction_date, 'RRRR/MM/DD HH24:MI:SS') BETWEEN NVL (
                                                                                         p_trx_date_from,
                                                                                         TO_CHAR (
                                                                                             transaction_date,
                                                                                             'RRRR/MM/DD HH24:MI:SS'))
                                                                                 AND NVL (
                                                                                         p_trx_date_to,
                                                                                         TO_CHAR (
                                                                                             transaction_date,
                                                                                             'RRRR/MM/DD HH24:MI:SS'))
                     AND NVL (status, 'N') =
                         DECODE (p_reprocess, 'Y', 'E', 'N')
            ORDER BY operating_unit, account_number, transaction_type;

        -- Header level variable declarations

        ln_org_id                 hr_operating_units.organization_id%TYPE;
        ln_cust_account_id        hz_cust_accounts.cust_account_id%TYPE;
        lv_party_name             hz_parties.party_name%TYPE;
        ln_party_id               hz_parties.party_id%TYPE;
        ln_salesrep_id            jtf_rs_salesreps.salesrep_id%TYPE;
        lv_reason_code            ar_lookups.lookup_code%TYPE;
        lv_trx_code               ar_lookups.lookup_code%TYPE;
        ln_cust_trx_type_id       ra_cust_trx_types_all.cust_trx_type_id%TYPE;
        ln_batch_source_id        ra_batch_sources_all.batch_source_id%TYPE;
        lv_batch_source_name      ra_batch_sources_all.name%TYPE;
        lv_curr_code              fnd_currencies.currency_code%TYPE;
        lv_brand                  fnd_lookup_values.lookup_code%TYPE;
        lv_tax_flag               fnd_lookup_values.lookup_code%TYPE;
        lv_print_option           ar_lookups.lookup_code%TYPE;
        ln_ccid                   gl_code_combinations.code_combination_id%TYPE;
        ld_trx_date               ra_customer_trx_all.trx_date%TYPE;
        ln_orig_bill_address_id   hz_cust_acct_sites_all.cust_acct_site_id%TYPE;
        lv_grouping               VARCHAR2 (100);
        lv_ret_msg                VARCHAR2 (4000);
        lv_msg                    VARCHAR2 (4000);
        lv_status                 VARCHAR2 (10);
        l_boolean                 BOOLEAN;

        lv_proc_name              VARCHAR2 (30) := 'VALIDATE_STAGING';
    BEGIN
        BEGIN
            UPDATE xxdo.xxd_ar_lcx_invoices_stg_t
               SET status = 'E', error_msg = ' One or more mandatory columns from the Data file are NULL, Please check. '
             WHERE     1 = 1
                   AND request_id = gn_conc_request_id
                   AND (operating_unit IS NULL OR transaction_type IS NULL OR Account_number IS NULL OR Brand IS NULL OR amount IS NULL OR transaction_date IS NULL OR gl_code IS NULL);
        EXCEPTION
            WHEN OTHERS
            THEN                                     -- Revisit to update this
                UPDATE xxdo.xxd_ar_lcx_invoices_stg_t
                   SET status = 'E', error_msg = ' Intial Update statement is failed '
                 WHERE 1 = 1 AND request_id = gn_conc_request_id;
        END;


        FOR trx_rec IN lcx_hdr_line_cur
        LOOP
            l_boolean   := NULL;
            lv_msg      := NULL;
            lv_status   := NULL;
            ln_org_id   := NULL;

            -- Get Org_ID

            IF trx_rec.operating_unit IS NOT NULL
            THEN
                l_boolean    := NULL;
                lv_ret_msg   := NULL;
                ln_org_id    := NULL;
                l_boolean    :=
                    get_org_id (p_org_name   => trx_rec.operating_unit,
                                x_org_id     => ln_org_id,
                                x_ret_msg    => lv_ret_msg);

                IF l_boolean = FALSE OR lv_ret_msg IS NOT NULL
                THEN
                    lv_status   := g_errored;
                    lv_msg      := lv_msg || ' - ' || lv_ret_msg;
                END IF;
            ELSE
                lv_msg   := ' Operating Unit cannot be NULL ';
            END IF;

            -- get Customer transaction type

            IF trx_rec.transaction_type IS NOT NULL --AND ln_org_id IS NOT NULL
            THEN
                IF ln_org_id IS NOT NULL
                THEN
                    l_boolean             := NULL;
                    lv_ret_msg            := NULL;
                    ln_cust_trx_type_id   := NULL;
                    l_boolean             :=
                        get_cust_trx_type (p_trx_type_name => trx_rec.transaction_type, p_org_id => ln_org_id, x_trx_type_id => ln_cust_trx_type_id
                                           , x_ret_msg => lv_ret_msg);

                    IF l_boolean = FALSE OR lv_ret_msg IS NOT NULL
                    THEN
                        lv_status   := g_errored;
                        lv_msg      := lv_msg || ' - ' || lv_ret_msg;
                    END IF;
                ELSE
                    lv_msg   :=
                        ' Customer Transaction type cannot be derived without a Valid OU ';
                END IF;
            ELSE
                lv_msg   := ' Customer Transaction type cannot be NULL ';
            END IF;

            -- Get Currency code

            IF ln_org_id IS NOT NULL
            THEN
                l_boolean      := NULL;
                lv_ret_msg     := NULL;
                lv_curr_code   := NULL;
                l_boolean      :=
                    get_currency_code (p_org_id => ln_org_id, p_org_name => trx_rec.operating_unit, x_curr_code => lv_curr_code
                                       , x_ret_msg => lv_ret_msg);

                IF l_boolean = FALSE OR lv_ret_msg IS NOT NULL
                THEN
                    lv_status   := g_errored;
                    lv_msg      := lv_msg || ' - ' || lv_ret_msg;
                END IF;
            ELSE
                lv_msg   := ' OU should be valid for currency derivation ';
            END IF;

            -- Get batch source and batch name

            IF ln_org_id IS NOT NULL
            THEN
                l_boolean            := NULL;
                lv_ret_msg           := NULL;
                ln_batch_source_id   := NULL;
                l_boolean            :=
                    get_batch_source_id (p_org_id => ln_org_id, p_org_name => trx_rec.operating_unit, x_batch_source_id => ln_batch_source_id
                                         , x_ret_msg => lv_ret_msg);

                IF l_boolean = FALSE OR lv_ret_msg IS NOT NULL
                THEN
                    lv_status   := g_errored;
                    lv_msg      := lv_msg || ' - ' || lv_ret_msg;
                ELSIF ln_batch_source_id IS NOT NULL
                THEN
                    l_boolean              := NULL;
                    lv_ret_msg             := NULL;
                    lv_batch_source_name   := NULL;
                    l_boolean              :=
                        get_batch_source_name (p_batch_source_id => ln_batch_source_id, p_org_id => ln_org_id, x_batch_source_name => lv_batch_source_name
                                               , x_ret_msg => lv_ret_msg);

                    IF l_boolean = FALSE OR lv_ret_msg IS NOT NULL
                    THEN
                        lv_status   := g_errored;
                        lv_msg      := lv_msg || ' - ' || lv_ret_msg;
                    END IF;
                END IF;
            ELSE
                lv_msg   := ' OU cannot be NULL for derving batch source ';
            END IF;


            -- Get reason code

            IF trx_rec.reason_code IS NOT NULL
            THEN
                l_boolean        := NULL;
                lv_ret_msg       := NULL;
                lv_reason_code   := NULL;
                l_boolean        :=
                    get_reason_code (p_reason_name   => trx_rec.reason_code,
                                     x_reason_code   => lv_reason_code,
                                     x_ret_msg       => lv_ret_msg);

                IF l_boolean = FALSE OR lv_ret_msg IS NOT NULL
                THEN
                    lv_status   := g_errored;
                    lv_msg      := lv_msg || ' - ' || lv_ret_msg;
                END IF;
            --        ELSE
            --            lv_msg := ' Reason code Cannot be NULL ';
            END IF;

            -- Get Customer Name and Account ID

            IF trx_rec.account_number IS NOT NULL
            THEN
                l_boolean            := NULL;
                lv_ret_msg           := NULL;
                ln_party_id          := NULL;
                lv_party_name        := NULL;
                ln_cust_account_id   := NULL;
                l_boolean            :=
                    get_cust_account_id (
                        p_cust_acct_num    => trx_rec.account_number,
                        x_cust_acct_id     => ln_cust_account_id,
                        x_party_id         => ln_party_id,
                        x_cust_acct_name   => lv_party_name,
                        x_ret_msg          => lv_ret_msg);

                IF l_boolean = FALSE OR lv_ret_msg IS NOT NULL
                THEN
                    lv_status   := g_errored;
                    lv_msg      := lv_msg || ' - ' || lv_ret_msg;
                END IF;
            ELSE
                lv_msg   := ' Customer account number cannot be NULL ';
            END IF;

            -- Get Customer Name and Account ID

            IF trx_rec.account_number IS NOT NULL
            THEN
                IF ln_cust_account_id IS NOT NULL AND ln_org_id IS NOT NULL
                THEN
                    l_boolean                 := NULL;
                    lv_ret_msg                := NULL;
                    ln_orig_bill_address_id   := NULL;
                    l_boolean                 :=
                        get_orig_bill_address_id (
                            p_cust_acct_id           => ln_cust_account_id,
                            p_cust_acct_num          => trx_rec.account_number,
                            p_org_name               => trx_rec.operating_unit,
                            p_org_id                 => ln_org_id,
                            x_orig_bill_address_id   =>
                                ln_orig_bill_address_id,
                            x_ret_msg                => lv_ret_msg);

                    IF l_boolean = FALSE OR lv_ret_msg IS NOT NULL
                    THEN
                        lv_status   := g_errored;
                        lv_msg      := lv_msg || ' - ' || lv_ret_msg;
                    END IF;
                ELSE
                    lv_status   := g_errored;
                    lv_msg      :=
                           lv_msg
                        || ' - '
                        || ' Derived Cust Acct ID or OU ID is NULL';
                END IF;
            END IF;

            -- Validate Brand

            IF trx_rec.brand IS NOT NULL
            THEN
                l_boolean    := NULL;
                lv_ret_msg   := NULL;
                lv_brand     := NULL;
                l_boolean    :=
                    is_brand_valid (p_brand     => trx_rec.brand,
                                    x_brand     => lv_brand,
                                    x_ret_msg   => lv_ret_msg);

                IF l_boolean = FALSE OR lv_ret_msg IS NOT NULL
                THEN
                    lv_status   := g_errored;
                    lv_msg      := lv_msg || ' - ' || lv_ret_msg;
                END IF;
            ELSE
                lv_msg   := ' Brand cannot be NULL ';
            END IF;

            -- Get Transaction date

            IF trx_rec.transaction_date IS NOT NULL
            THEN
                lv_ret_msg    := NULL;
                ld_trx_date   := NULL;

                ld_trx_date   :=
                    is_trx_date_valid (
                        p_gl_date   => trx_rec.transaction_date,
                        p_org_id    => ln_org_id,
                        x_ret_msg   => lv_ret_msg);

                IF ld_trx_date IS NULL OR lv_ret_msg IS NOT NULL
                THEN
                    lv_status   := g_errored;
                    lv_msg      := lv_msg || ' - ' || lv_ret_msg;
                END IF;
            END IF;

            -- Validate Transaction amount

            IF trx_rec.amount IS NOT NULL
            THEN
                l_boolean    := NULL;
                lv_ret_msg   := NULL;
                l_boolean    :=
                    is_trx_amt_valid (p_trx_amt   => trx_rec.amount,
                                      x_ret_msg   => lv_ret_msg);

                IF l_boolean = FALSE OR lv_ret_msg IS NOT NULL
                THEN
                    lv_status   := g_errored;
                    lv_msg      := lv_msg || ' - ' || lv_ret_msg;
                END IF;
            ELSE
                lv_msg   := ' Transaction amount cannot be NULL ';
            END IF;

            -- Validate tax exempt flag

            IF trx_rec.tax_exempt IS NOT NULL
            THEN
                l_boolean     := NULL;
                lv_tax_flag   := NULL;
                lv_ret_msg    := NULL;
                l_boolean     :=
                    is_flag_valid (p_tax_flag   => trx_rec.tax_exempt,
                                   x_tax_flag   => lv_tax_flag,
                                   x_ret_msg    => lv_ret_msg);

                IF l_boolean = FALSE OR lv_ret_msg IS NOT NULL
                THEN
                    lv_status   := g_errored;
                    lv_msg      := lv_msg || ' - ' || lv_ret_msg;
                END IF;
            END IF;

            -- Validate print option

            IF trx_rec.print_option IS NOT NULL
            THEN
                l_boolean         := NULL;
                lv_print_option   := NULL;
                lv_ret_msg        := NULL;
                l_boolean         :=
                    is_print_option_valid (
                        p_print_option   => trx_rec.print_option,
                        x_print_code     => lv_print_option,
                        x_ret_msg        => lv_ret_msg);

                IF l_boolean = FALSE OR lv_ret_msg IS NOT NULL
                THEN
                    lv_status   := g_errored;
                    lv_msg      := lv_msg || ' - ' || lv_ret_msg;
                END IF;
            END IF;

            -- Validate sales representative

            IF trx_rec.sales_representative IS NOT NULL
            THEN
                l_boolean        := NULL;
                ln_salesrep_id   := NULL;
                lv_ret_msg       := NULL;
                l_boolean        :=
                    is_sales_rep_valid (p_sales_per_name => trx_rec.sales_representative, p_org_id => ln_org_id, x_sales_rep_id => ln_salesrep_id
                                        , x_ret_msg => lv_ret_msg);

                IF l_boolean = FALSE OR lv_ret_msg IS NOT NULL
                THEN
                    lv_status   := g_errored;
                    lv_msg      := lv_msg || ' - ' || lv_ret_msg;
                END IF;
            END IF;

            -- Get Code Combination ID

            IF trx_rec.gl_code IS NOT NULL
            THEN
                l_boolean    := NULL;
                ln_ccid      := NULL;
                lv_ret_msg   := NULL;
                l_boolean    :=
                    is_gl_code_valid (p_gl_code   => trx_rec.gl_code,
                                      x_ccid      => ln_ccid,
                                      x_ret_msg   => lv_ret_msg);

                IF l_boolean = FALSE OR lv_ret_msg IS NOT NULL
                THEN
                    lv_status   := g_errored;
                    lv_msg      := lv_msg || ' - ' || lv_ret_msg;
                END IF;
            ELSE
                lv_msg   := ' Transaction amount cannot be NULL ';
            END IF;

            IF lv_status = g_errored
            THEN
                --            msg(' Errored while doing line validation, header is processed ');
                BEGIN
                    UPDATE xxdo.xxd_ar_lcx_invoices_stg_t stg
                       SET stg.status = g_errored, stg.error_msg = SUBSTR (lv_msg, 1, 4000), stg.creation_date = gd_sysdate,
                           stg.last_updated_by = gn_user_id, stg.last_update_login = gn_login_id, stg.last_update_date = gd_sysdate,
                           stg.request_id = gn_conc_request_id, stg.org_id = ln_org_id, stg.batch_source_name = lv_batch_source_name,
                           stg.batch_source_id = ln_batch_source_id, stg.cust_trx_type_id = ln_cust_trx_type_id, stg.currency_code = lv_curr_code,
                           stg.Cust_account_id = ln_cust_account_id, stg.party_id = ln_party_id, stg.bill_to_location_id = ln_orig_bill_address_id,
                           stg.reason_short_code = lv_reason_code, stg.dist_ccid = ln_ccid, stg.tax_flag = lv_tax_flag,
                           stg.salesrep_id = ln_salesrep_id, stg.trx_new_date = ld_trx_date
                     WHERE stg.record_id = trx_rec.record_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_status    := g_errored;
                        lv_msg       :=
                               lv_msg
                            || ' - '
                            || ' Exception1 while updating the Staging Table: '
                            || gv_package_name
                            || lv_proc_name
                            || ' Error is : '
                            || SUBSTR (SQLERRM, 1, 200);
                        msg (lv_msg);
                        x_ret_code   := '2';
                        x_ret_msg    := SUBSTR (lv_msg, 1, 2000);
                END;
            ELSE
                BEGIN
                    UPDATE xxdo.xxd_ar_lcx_invoices_stg_t stg
                       SET stg.status = g_validated, stg.error_msg = SUBSTR (lv_msg, 1, 4000), stg.creation_date = gd_sysdate,
                           stg.last_updated_by = gn_user_id, stg.last_update_login = gn_login_id, stg.last_update_date = gd_sysdate,
                           stg.request_id = gn_conc_request_id, stg.org_id = ln_org_id, stg.batch_source_name = lv_batch_source_name,
                           stg.batch_source_id = ln_batch_source_id, stg.cust_trx_type_id = ln_cust_trx_type_id, stg.currency_code = lv_curr_code,
                           stg.Cust_account_id = ln_cust_account_id, stg.party_id = ln_party_id, stg.bill_to_location_id = ln_orig_bill_address_id,
                           stg.reason_short_code = lv_reason_code, stg.dist_ccid = ln_ccid, stg.tax_flag = lv_tax_flag,
                           stg.salesrep_id = ln_salesrep_id, stg.trx_new_date = ld_trx_date
                     WHERE stg.record_id = trx_rec.record_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_status    := g_errored;
                        lv_msg       :=
                               lv_msg
                            || ' - '
                            || ' Exception2 while updating the Staging Table: '
                            || gv_package_name
                            || lv_proc_name
                            || ' Error is : '
                            || SUBSTR (SQLERRM, 1, 200);
                        msg (lv_msg);
                        x_ret_code   := '2';
                        x_ret_msg    := SUBSTR (lv_msg, 1, 2000);
                END;
            END IF;
        END LOOP;
    END validate_staging;


    PROCEDURE load_interface (x_ret_code   OUT VARCHAR2,
                              x_ret_msg    OUT VARCHAR2)
    IS
        CURSOR c_valid_lines IS
            SELECT stg.*
              FROM xxdo.xxd_ar_lcx_invoices_stg_t stg
             WHERE     1 = 1
                   AND status = g_validated
                   AND request_id = gn_conc_request_id;

        CURSOR c_valid_dist (p_org_id IN NUMBER, p_batch_source_id IN NUMBER, p_cust_trx_type_id IN NUMBER, p_bill_to_location_id IN NUMBER, p_cust_account_id IN NUMBER, p_transaction_date IN DATE
                             , p_record_id IN NUMBER)
        IS
            SELECT stg.*
              FROM xxdo.xxd_ar_lcx_invoices_stg_t stg
             WHERE     1 = 1
                   AND status = g_validated
                   AND request_id = gn_conc_request_id
                   AND org_id = p_org_id
                   AND batch_source_id = p_batch_source_id
                   AND cust_trx_type_id = p_cust_trx_type_id
                   AND bill_to_location_id = p_bill_to_location_id
                   AND cust_account_id = p_cust_account_id
                   --AND transaction_date = p_transaction_date
                   AND trx_new_date = p_transaction_date
                   AND record_id = p_record_id;

        l_dist_status   VARCHAR2 (10);
        l_line_status   VARCHAR2 (10);
        lc_err_msg      VARCHAR2 (4000);
        lv_proc_name    VARCHAR2 (30) := 'LOAD_INTERFACE';
    BEGIN
        FOR line_rec IN c_valid_lines
        LOOP
            lc_err_msg      := NULL;
            l_line_status   := NULL;

            BEGIN
                INSERT INTO ra_interface_lines_all (interface_line_context, interface_line_attribute1, interface_line_attribute2, interface_line_attribute3, interface_line_attribute4, interface_line_attribute5, interface_line_attribute6, amount, batch_source_name, conversion_type, currency_code, cust_trx_type_id, description, gl_date, trx_date, line_type, orig_system_bill_address_id, orig_system_bill_customer_id, taxable_flag, org_id, header_attribute5, header_attribute13, reason_code, primary_salesrep_id
                                                    , comments)
                     VALUES ('LUCERNEX', SUBSTR (line_rec.GROUPING, 1, 30), SUBSTR (line_rec.transaction_type, 1, 30), line_rec.record_id, line_rec.brand, TO_CHAR (gd_sysdate, 'MMDDRRRR'), gn_conc_request_id, line_rec.amount * -1, line_rec.batch_source_name, 'Corporate', line_rec.currency_code, line_rec.cust_trx_type_id, SUBSTR (TRIM (line_rec.comments), 1, 240), line_rec.trx_new_date --line_rec.transaction_date
                                                                                                                                                                                                                                                                                                                                                                                                   , line_rec.trx_new_date --line_rec.transaction_date
                                                                                                                                                                                                                                                                                                                                                                                                                          , 'LINE', line_rec.bill_to_location_id, line_rec.cust_account_id, DECODE (line_rec.tax_flag, 'Y', 'N', NULL), line_rec.org_id, line_rec.brand, line_rec.reason_short_code, line_rec.reason_short_code, line_rec.salesrep_id
                             , line_rec.comments);

                msg (
                    ' Inserted into lines Interface table : ' || line_rec.record_id);

                BEGIN
                    UPDATE xxdo.xxd_ar_lcx_invoices_stg_t
                       SET line_interfaced   = 'Y'
                     WHERE     1 = 1
                           AND record_id = line_rec.record_id
                           AND request_id = gn_conc_request_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        x_ret_code   := '2';
                        x_ret_msg    :=
                            SUBSTR (
                                   'Error while updating Staging table for Line Interface Flag in '
                                || gv_package_name
                                || lv_proc_name
                                || ' Error is : '
                                || SQLERRM,
                                1,
                                2000);
                        msg (x_ret_msg);
                END;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_line_status   := g_errored;
                    lc_err_msg      :=
                        SUBSTR (
                               'Exception while inserting data into RA_INTERFACE_LINES_ALL in : '
                            || gv_package_name
                            || lv_proc_name
                            || ' Error is : '
                            || SUBSTR (SQLERRM, 1, 200),
                            1,
                            4000);
                    msg (lc_err_msg);
                    x_ret_code      := '2';
                    x_ret_msg       := SUBSTR (lc_err_msg, 1, 2000);
            END;


            IF l_line_status IS NULL
            THEN
                FOR dist_rec IN c_valid_dist (line_rec.org_id, line_rec.batch_source_id, line_rec.cust_trx_type_id, line_rec.bill_to_location_id, line_rec.cust_account_id, line_rec.trx_new_date
                                              , line_rec.record_id)
                LOOP
                    l_dist_status   := NULL;

                    BEGIN
                        INSERT INTO ra_interface_distributions_all (
                                        account_class,
                                        code_combination_id,
                                        percent,
                                        interface_line_context,
                                        interface_line_attribute1,
                                        interface_line_attribute2,
                                        interface_line_attribute3,
                                        interface_line_attribute4,
                                        interface_line_attribute5,
                                        interface_line_attribute6,
                                        org_id)
                             VALUES ('REV', dist_rec.dist_ccid, 100,
                                     'LUCERNEX', SUBSTR (line_rec.GROUPING, 1, 30), SUBSTR (line_rec.transaction_type, 1, 30), dist_rec.record_id, dist_rec.brand, TO_CHAR (gd_sysdate, 'MMDDRRRR')
                                     , gn_conc_request_id, line_rec.org_id);

                        msg (
                               ' Inserted into distribution Interface table : '
                            || dist_rec.record_id);

                        BEGIN
                            UPDATE xxdo.xxd_ar_lcx_invoices_stg_t
                               SET dist_interfaced   = 'Y'
                             WHERE     1 = 1
                                   AND record_id = dist_rec.record_id
                                   AND request_id = gn_conc_request_id
                                   AND org_id = line_rec.org_id
                                   AND batch_source_id =
                                       line_rec.batch_source_id
                                   AND cust_trx_type_id =
                                       line_rec.cust_trx_type_id
                                   AND bill_to_location_id =
                                       line_rec.bill_to_location_id
                                   AND cust_account_id =
                                       line_rec.cust_account_id
                                   AND trx_new_date = line_rec.trx_new_date;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                x_ret_code   := '2';
                                x_ret_msg    :=
                                    SUBSTR (
                                           'Error while updating Staging table for Dist Interface Flag in '
                                        || gv_package_name
                                        || lv_proc_name
                                        || ' Error is : '
                                        || SQLERRM,
                                        1,
                                        2000);
                                msg (x_ret_msg);
                        END;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_dist_status   := g_errored;
                            lc_err_msg      :=
                                SUBSTR (
                                       'Exception while inserting data into RA_INTERFACE_DISTRIBUTIONS_ALL in : '
                                    || gv_package_name
                                    || lv_proc_name
                                    || ' Error is : '
                                    || SUBSTR (SQLERRM, 1, 200),
                                    1,
                                    4000);
                            msg (lc_err_msg);
                            x_ret_code      := '2';
                            x_ret_msg       := SUBSTR (lc_err_msg, 1, 2000);
                    END;
                END LOOP;
            END IF;

            IF l_line_status IS NULL AND l_dist_status IS NULL
            THEN
                msg (
                    ' Inserted into lines and distribution Interface table ');

                BEGIN
                    UPDATE xxdo.xxd_ar_lcx_invoices_stg_t
                       SET status   = g_interfaced
                     WHERE     1 = 1
                           AND request_id = gn_conc_request_id
                           AND status = g_validated
                           AND line_interfaced = 'Y'
                           AND dist_interfaced = 'Y'
                           AND record_id = line_rec.record_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        x_ret_code   := '2';
                        x_ret_msg    :=
                            SUBSTR (
                                   'Error while updating Staging table for status as Interface Flag in '
                                || gv_package_name
                                || lv_proc_name
                                || ' Error is : '
                                || SQLERRM,
                                1,
                                2000);
                        msg (x_ret_msg);
                END;
            ELSE
                msg (
                    ' Error occurred while Inserting data into lines and distribution Interface ');

                BEGIN
                    UPDATE xxdo.xxd_ar_lcx_invoices_stg_t
                       SET status = g_errored, error_msg = SUBSTR ('Interface Error - ', 1, 4000)
                     WHERE     1 = 1
                           AND request_id = gn_conc_request_id
                           AND status = g_validated
                           AND record_id = line_rec.record_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        x_ret_code   := '2';
                        x_ret_msg    :=
                            SUBSTR (
                                   'Error while updating Staging table with Error status after interface insertion in '
                                || gv_package_name
                                || lv_proc_name
                                || ' Error is : '
                                || SQLERRM,
                                1,
                                2000);
                        msg (x_ret_msg);
                END;
            END IF;
        END LOOP;
    END load_interface;

    PROCEDURE create_transactions (x_ret_code   OUT VARCHAR2,
                                   x_ret_msg    OUT VARCHAR2)
    IS
        l_request_id        NUMBER;
        l_req_boolean       BOOLEAN;
        l_req_phase         VARCHAR2 (30);
        l_req_status        VARCHAR2 (30);
        l_req_dev_phase     VARCHAR2 (30);
        l_req_dev_status    VARCHAR2 (30);
        l_req_message       VARCHAR2 (4000);
        l_invoice_count     NUMBER := 0;
        l_batch_source_id   NUMBER;
        ex_no_invoices      EXCEPTION;
        ln_resp_id          NUMBER;

        CURSOR c_inv IS
            SELECT DISTINCT rila.org_id, rila.batch_source_name, rila.trx_date
              FROM apps.ra_interface_lines_all rila
             WHERE     1 = 1
                   AND rila.interface_line_context = 'LUCERNEX'
                   AND rila.interface_line_id IS NULL
                   AND EXISTS
                           (SELECT 1
                              FROM xxdo.xxd_ar_lcx_invoices_stg_t stg
                             WHERE     stg.record_id =
                                       rila.interface_line_attribute3
                                   AND stg.status = g_interfaced);

        lv_proc_name        VARCHAR2 (30) := 'CREATE_TRANSACTIONS';
    BEGIN
        FOR rec IN c_inv
        LOOP
            ln_resp_id          := NULL;
            l_batch_source_id   := NULL;

            ln_resp_id          := get_responsibility_id (rec.org_id);

            IF ln_resp_id IS NOT NULL
            THEN
                fnd_global.apps_initialize (
                    user_id        => FND_GLOBAL.user_id,
                    resp_id        => ln_resp_id,
                    resp_appl_id   => FND_GLOBAL.resp_appl_id);
            END IF;

            mo_global.init ('AR');
            mo_global.set_policy_context ('S', rec.org_id);
            l_batch_source_id   := NULL;

            BEGIN
                SELECT batch_source_id
                  INTO l_batch_source_id
                  FROM ra_batch_sources_all
                 WHERE     1 = 1
                       AND TRIM (UPPER (name)) =
                           TRIM (UPPER (rec.batch_source_name))
                       AND org_id = rec.org_id
                       AND NVL (start_date, SYSDATE) <= SYSDATE
                       AND NVL (end_date, SYSDATE) >= SYSDATE;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_batch_source_id   := NULL;
            END;


            --         apps.mo_global.set_policy_context ('S', rec.org_id);
            --         apps.mo_global.init ('AR');

            l_request_id        :=
                apps.fnd_request.submit_request (
                    application   => 'AR',
                    program       => 'RAXMTR',
                    description   =>
                        'Interface your transactions to Oracle Receivables' -- 'Autoinvoice Master Program'
                                                                           ,
                    start_time    => NULL,
                    sub_request   => FALSE,
                    argument1     => 1                  -- Number of Instances
                                      ,
                    argument2     => rec.org_id,
                    argument3     => l_batch_source_id       --Batch Source Id
                                                      ,
                    argument4     => rec.batch_source_name --Batch Source Name
                                                          ,
                    argument5     =>
                        TO_CHAR (TRUNC (rec.trx_date),
                                 'YYYY/MM/DD HH24:MI:SS')       --Default Date
                                                         ,
                    argument6     => NULL              --Transaction Flexfield
                                         ,
                    argument7     => NULL                   --Transaction Type
                                         ,
                    argument8     => NULL      --(Low) Bill To Customer Number
                                         ,
                    argument9     => NULL     --(High) Bill To Customer Number
                                         ,
                    argument10    => NULL        --(Low) Bill To Customer Name
                                         ,
                    argument11    => NULL       --(High) Bill To Customer Name
                                         ,
                    argument12    => NULL                      --(Low) GL Date
                                         ,
                    argument13    => NULL                     --(High) GL Date
                                         ,
                    argument14    => NULL                    --(Low) Ship Date
                                         ,
                    argument15    => NULL                   --(High) Ship Date
                                         ,
                    argument16    => NULL           --(Low) Transaction Number
                                         ,
                    argument17    => NULL         --(High) Transaction  Number
                                         ,
                    argument18    => NULL           --(Low) Sales Order Number
                                         ,
                    argument19    => NULL          --(High) Sales Order Number
                                         ,
                    argument20    => NULL                 --(Low) Invoice Date
                                         ,
                    argument21    => NULL                --(High) Invoice Date
                                         ,
                    argument22    => NULL      --(Low) Ship To Customer Number
                                         ,
                    argument23    => NULL     --(High) Ship To Customer Number
                                         ,
                    argument24    => NULL        --(Low) Ship To Customer Name
                                         ,
                    argument25    => NULL       --(High) Ship To Customer Name
                                         ,
                    argument26    => 'Y'           --Base Due Date on Trx Date
                                        ,
                    argument27    => NULL           --Due Date Adjustment Days
                                         );

            IF l_request_id <> 0
            THEN
                COMMIT;
                --NULL;
                msg ('AR Request ID= ' || l_request_id);
            ELSIF l_request_id = 0
            THEN
                msg (
                       'Request Not Submitted due to "'
                    || apps.fnd_message.get
                    || '".');
            END IF;

            --===IF successful RETURN ar customer trx id as OUT parameter;
            IF l_request_id > 0
            THEN
                LOOP
                    l_req_boolean   :=
                        apps.fnd_concurrent.wait_for_request (
                            l_request_id,
                            15,
                            0,
                            l_req_phase,
                            l_req_status,
                            l_req_dev_phase,
                            l_req_dev_status,
                            l_req_message);
                    EXIT WHEN    UPPER (l_req_phase) = 'COMPLETED'
                              OR UPPER (l_req_status) IN
                                     ('CANCELLED', 'ERROR', 'TERMINATED');
                END LOOP;

                IF     UPPER (l_req_phase) = 'COMPLETED'
                   AND UPPER (l_req_status) = 'ERROR'
                THEN
                    msg (
                           'Auto Invoice master program completed in error. See log for request id:'
                        || l_request_id);
                    msg (SQLERRM);
                    x_ret_code   := '2';
                    x_ret_msg    :=
                           'Auto Invoice Master Program request failed.Review log for Oracle request id '
                        || l_request_id;
                ELSIF     UPPER (l_req_phase) = 'COMPLETED'
                      AND UPPER (l_req_status) = 'NORMAL'
                THEN
                    msg (
                           'Auto Invoice Master Program request id: '
                        || l_request_id);
                ELSE
                    msg (
                           'Auto Invoice Master Program failed.Review log for Oracle request id '
                        || l_request_id);
                    msg (SQLERRM);
                    x_ret_code   := '2';
                    x_ret_msg    :=
                           'Auto Invoice Master Program request failed.Review log for Oracle request id '
                        || l_request_id;
                END IF;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN ex_no_invoices
        THEN
            x_ret_msg    :=
                SUBSTR (
                       x_ret_msg
                    || ' No data available for invoice creation in : '
                    || gv_package_name
                    || lv_proc_name
                    || ' Error is - '
                    || SQLERRM,
                    1,
                    3000);
            x_ret_code   := '2';
            msg (' No Invoices Exception - ' || x_ret_msg);
        WHEN OTHERS
        THEN
            x_ret_msg    :=
                SUBSTR (
                       x_ret_msg
                    || ' Error in create_transactions:'
                    || gv_package_name
                    || lv_proc_name
                    || ' Error is - '
                    || SQLERRM,
                    1,
                    3000);
            x_ret_code   := '2';
            msg (' When No Others Exception - ' || x_ret_msg);
    END create_transactions;

    FUNCTION is_trasaction_created (
        p_cust_account_id             IN     NUMBER,
        p_org_id                      IN     NUMBER,
        p_interface_line_context      IN     VARCHAR2,
        p_interface_line_attribute1   IN     VARCHAR2,
        p_interface_line_attribute2   IN     VARCHAR2,
        p_interface_line_attribute3   IN     VARCHAR2,
        p_interface_line_attribute4   IN     VARCHAR2,
        p_interface_line_attribute5   IN     VARCHAR2,
        p_interface_line_attribute6   IN     VARCHAR2,
        x_trx_number                     OUT VARCHAR2,
        x_customer_trx_id                OUT NUMBER)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT rcta.trx_number, rcta.customer_trx_id
          INTO x_trx_number, x_customer_trx_id
          FROM apps.ra_customer_trx_all rcta, apps.ra_customer_trx_lines_all rctla
         WHERE     1 = 1
               AND rcta.org_id = rctla.org_id
               AND rcta.customer_trx_id = rctla.customer_trx_id
               AND rcta.bill_to_customer_id = p_cust_account_id
               AND rctla.org_id = p_org_id
               AND rctla.interface_line_context = p_interface_line_context
               AND rctla.interface_line_attribute1 =
                   p_interface_line_attribute1
               AND rctla.interface_line_attribute2 =
                   p_interface_line_attribute2
               AND rctla.interface_line_attribute3 =
                   p_interface_line_attribute3
               AND rctla.interface_line_attribute4 =
                   p_interface_line_attribute4
               AND rctla.interface_line_attribute5 =
                   p_interface_line_attribute5
               AND rctla.interface_line_attribute6 =
                   p_interface_line_attribute6;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_trx_number        := NULL;
            x_customer_trx_id   := NULL;
            RETURN FALSE;
    END is_trasaction_created;

    FUNCTION is_trx_line_created (p_customer_trx_id IN NUMBER, p_interface_line_context IN VARCHAR2, p_interface_line_att3 IN VARCHAR2
                                  , x_customer_trx_line_id OUT NUMBER)
        RETURN BOOLEAN
    IS
        l_count   NUMBER := 0;
    BEGIN
        SELECT customer_trx_line_id
          INTO x_customer_trx_line_id
          FROM apps.ra_customer_trx_lines_all
         WHERE     customer_trx_id = p_customer_trx_id
               AND interface_line_context = p_interface_line_context
               AND interface_line_attribute3 = p_interface_line_att3
               AND line_type = 'LINE';

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_customer_trx_line_id   := NULL;
            RETURN FALSE;
    END is_trx_line_created;

    FUNCTION is_trx_dist_created (p_customer_trx_id            IN     NUMBER,
                                  p_customer_trx_line_id       IN     NUMBER,
                                  p_account_class              IN     VARCHAR2,
                                  p_ccid                       IN     NUMBER,
                                  x_cust_trx_line_gl_dist_id      OUT NUMBER)
        RETURN BOOLEAN
    IS
        l_count   NUMBER := 0;
    BEGIN
        SELECT cust_trx_line_gl_dist_id
          INTO x_cust_trx_line_gl_dist_id
          FROM apps.ra_cust_trx_line_gl_dist_all
         WHERE     customer_trx_id = p_customer_trx_id
               AND customer_trx_line_id = p_customer_trx_line_id
               AND account_class = p_account_class
               AND code_combination_id = p_ccid;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_cust_trx_line_gl_dist_id   := NULL;
            RETURN FALSE;
    END is_trx_dist_created;

    PROCEDURE check_data (x_ret_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
    IS
        CURSOR c_hdr IS
            SELECT *
              FROM xxdo.xxd_ar_lcx_invoices_stg_t
             WHERE     1 = 1
                   AND Status = g_interfaced
                   AND request_id = gn_conc_request_id;

        CURSOR c_int_hdr IS
            SELECT *
              FROM xxdo.xxd_ar_lcx_invoices_stg_t
             WHERE     1 = 1
                   AND Status = g_errored
                   AND (line_interfaced = 'Y' OR dist_interfaced = 'Y')
                   AND request_id = gn_conc_request_id;

        CURSOR c_int_lines (p_interface_line_context IN VARCHAR2, p_interface_line_attribute1 IN VARCHAR2, p_interface_line_attribute2 IN VARCHAR2, p_interface_line_attribute3 IN VARCHAR2, p_interface_line_attribute4 IN VARCHAR2, p_interface_line_attribute5 IN VARCHAR2
                            , p_interface_line_attribute6 IN VARCHAR2)
        IS
            SELECT interface_line_id
              FROM ra_interface_lines_all
             WHERE     interface_line_context = p_interface_line_context
                   AND interface_line_attribute1 =
                       p_interface_line_attribute1
                   AND interface_line_attribute2 =
                       p_interface_line_attribute2
                   AND interface_line_attribute3 =
                       p_interface_line_attribute3
                   AND interface_line_attribute4 =
                       p_interface_line_attribute4
                   AND interface_line_attribute5 =
                       p_interface_line_attribute5
                   AND interface_line_attribute6 =
                       p_interface_line_attribute6
                   AND interface_line_id IS NOT NULL;

        CURSOR c_int_dists (p_interface_line_id IN NUMBER)
        IS
            SELECT interface_distribution_id
              FROM ra_interface_distributions_all
             WHERE interface_line_id = p_interface_line_id;

        CURSOR c_int_errors (p_interface_line_id IN NUMBER)
        IS
            SELECT MESSAGE_TEXT, invalid_value
              FROM ra_interface_errors_all
             WHERE interface_line_id = p_interface_line_id;

        CURSOR c_dist_errors (p_interface_dist_id IN NUMBER)
        IS
            SELECT MESSAGE_TEXT, invalid_value
              FROM ra_interface_errors_all
             WHERE interface_distribution_id = p_interface_dist_id;


        lv_trx_number             VARCHAR2 (20) := NULL;
        ln_customer_trx_id        NUMBER := NULL;
        ln_customer_trx_line_id   NUMBER := NULL;
        ln_customer_trx_dist_id   NUMBER := NULL;
        l_hdr_boolean             BOOLEAN := NULL;
        l_line_boolean            BOOLEAN := NULL;
        l_dist_boolean            BOOLEAN := NULL;
        l_error_msg               VARCHAR2 (4000);
        l_line_error              VARCHAR2 (32000);
        l_status                  VARCHAR2 (30);
        l_data_msg                VARCHAR2 (4000);
        lv_proc_name              VARCHAR2 (30) := 'CHECK_DATA';
    BEGIN
        FOR hdr IN c_hdr
        LOOP
            l_error_msg               := NULL;

            l_status                  := NULL;
            ln_customer_trx_id        := NULL;
            ln_customer_trx_line_id   := NULL;
            ln_customer_trx_dist_id   := NULL;
            lv_trx_number             := NULL;

            l_hdr_boolean             := NULL;
            l_data_msg                := NULL;
            l_line_boolean            := NULL;
            l_dist_boolean            := NULL;

            Msg ('Error Interface record : ' || hdr.record_id);

            l_hdr_boolean             :=
                is_trasaction_created (
                    p_cust_account_id             => hdr.cust_account_id,
                    p_org_id                      => hdr.org_id,
                    p_interface_line_context      => 'LUCERNEX',
                    p_interface_line_attribute1   =>
                        SUBSTR (hdr.GROUPING, 1, 30),
                    p_interface_line_attribute2   =>
                        SUBSTR (hdr.transaction_type, 1, 30),
                    p_interface_line_attribute3   => hdr.record_id,
                    p_interface_line_attribute4   => hdr.brand,
                    p_interface_line_attribute5   =>
                        TO_CHAR (gd_sysdate, 'MMDDRRRR'),
                    p_interface_line_attribute6   => gn_conc_request_id,
                    x_trx_number                  => lv_trx_number,
                    x_customer_trx_id             => ln_customer_trx_id);

            IF l_hdr_boolean = TRUE
            THEN
                msg (
                       ' Import is done and Invoice is created : '
                    || lv_trx_number);


                BEGIN
                    UPDATE xxdo.xxd_ar_lcx_invoices_stg_t
                       SET trx_created = 'Y', trx_number = lv_trx_number, customer_trx_id = ln_customer_trx_id
                     WHERE record_id = hdr.record_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        x_ret_code   := '2';
                        x_ret_msg    :=
                            SUBSTR (
                                   'Error while updating Staging table with TRX_NUMBER in '
                                || gv_package_name
                                || lv_proc_name
                                || ' Error is : '
                                || SQLERRM,
                                1,
                                2000);
                        msg (x_ret_msg);
                END;

                -- Call the line transaction created function

                l_line_boolean            := NULL;
                ln_customer_trx_line_id   := NULL;

                l_line_boolean            :=
                    is_trx_line_created (
                        p_customer_trx_id          => ln_customer_trx_id,
                        p_interface_line_context   => 'LUCERNEX',
                        p_interface_line_att3      => hdr.record_id,
                        x_customer_trx_line_id     => ln_customer_trx_line_id);


                IF l_line_boolean = TRUE
                THEN
                    msg (
                           ' Import is done and Transaction line is created : '
                        || ln_customer_trx_line_id);

                    BEGIN
                        UPDATE xxdo.xxd_ar_lcx_invoices_stg_t
                           SET trx_line_created = 'Y', customer_trx_line_id = ln_customer_trx_line_id
                         WHERE record_id = hdr.record_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            x_ret_code   := '2';
                            x_ret_msg    :=
                                SUBSTR (
                                       'Error while updating Staging table with Trx Line ID in '
                                    || gv_package_name
                                    || lv_proc_name
                                    || ' Error is : '
                                    || SQLERRM,
                                    1,
                                    2000);
                            msg (x_ret_msg);
                    END;


                    l_dist_boolean            := NULL;
                    ln_customer_trx_dist_id   := NULL;
                    l_dist_boolean            := NULL;

                    l_dist_boolean            :=
                        is_trx_dist_created (
                            p_customer_trx_id   => ln_customer_trx_id,
                            p_customer_trx_line_id   =>
                                ln_customer_trx_line_id,
                            p_account_class     => 'REV',
                            p_ccid              => hdr.dist_ccid,
                            x_cust_trx_line_gl_dist_id   =>
                                ln_customer_trx_dist_id);

                    IF l_dist_boolean = TRUE
                    THEN
                        msg (
                               ' Import is done and Transaction dist is created : '
                            || ln_customer_trx_dist_id);

                        BEGIN
                            UPDATE xxdo.xxd_ar_lcx_invoices_stg_t
                               SET trx_line_dist_created = 'Y', customer_trx_dist_id = ln_customer_trx_dist_id
                             WHERE record_id = hdr.record_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                x_ret_code   := '2';
                                x_ret_msg    :=
                                    SUBSTR (
                                           'Error while updating Staging table with Trx Dist Line ID in '
                                        || gv_package_name
                                        || lv_proc_name
                                        || ' Error is : '
                                        || SQLERRM,
                                        1,
                                        2000);
                                msg (x_ret_msg);
                        END;
                    END IF;
                END IF;
            END IF;

            IF     l_hdr_boolean = TRUE
               AND l_line_boolean = TRUE
               AND l_dist_boolean = TRUE
            THEN
                msg (
                    ' Transaction, line and Dist are created, refer to table for details ');

                BEGIN
                    UPDATE xxdo.xxd_ar_lcx_invoices_stg_t
                       SET status   = g_processed
                     WHERE record_id = hdr.record_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        x_ret_code   := '2';
                        x_ret_msg    :=
                            SUBSTR (
                                   'Error while updating Staging table with status as processed in '
                                || gv_package_name
                                || lv_proc_name
                                || ' Error is : '
                                || SQLERRM,
                                1,
                                2000);
                        msg (x_ret_msg);
                END;
            ELSE
                Msg ('Track Error Interface record : ' || hdr.record_id);

                FOR line
                    IN c_int_lines (
                           p_interface_line_context      => 'LUCERNEX',
                           p_interface_line_attribute1   =>
                               SUBSTR (hdr.GROUPING, 1, 30),
                           p_interface_line_attribute2   =>
                               SUBSTR (hdr.transaction_type, 1, 30),
                           p_interface_line_attribute3   => hdr.record_id,
                           p_interface_line_attribute4   => hdr.brand,
                           p_interface_line_attribute5   =>
                               TO_CHAR (gd_sysdate, 'MMDDRRRR'),
                           p_interface_line_attribute6   => gn_conc_request_id)
                LOOP
                    FOR err IN c_int_errors (line.interface_line_id)
                    LOOP
                        Msg (
                            'Interface line ID error record : ' || line.interface_line_id);
                        l_error_msg   :=
                            SUBSTR (
                                   l_error_msg
                                || '. '
                                || err.MESSAGE_TEXT
                                || ' - '
                                || err.invalid_value,
                                1,
                                4000);
                    END LOOP;
                END LOOP;

                BEGIN
                    UPDATE xxdo.xxd_ar_lcx_invoices_stg_t
                       SET status = g_errored, error_msg = SUBSTR ('Interface Error - ' || l_error_msg, 1, 3000)
                     WHERE record_id = hdr.record_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        x_ret_code   := '2';
                        x_ret_msg    :=
                            SUBSTR (
                                   'Error while updating Staging table with status as Interface Error in '
                                || gv_package_name
                                || lv_proc_name
                                || ' Error is : '
                                || SQLERRM,
                                1,
                                2000);
                        msg (x_ret_msg);
                END;
            END IF;
        END LOOP;

        FOR del_hdr IN c_int_hdr
        LOOP
            FOR del_line
                IN c_int_lines (
                       p_interface_line_context      => 'LUCERNEX',
                       p_interface_line_attribute1   =>
                           SUBSTR (del_hdr.GROUPING, 1, 30),
                       p_interface_line_attribute2   =>
                           SUBSTR (del_hdr.transaction_type, 1, 30),
                       p_interface_line_attribute3   => del_hdr.record_id,
                       p_interface_line_attribute4   => del_hdr.brand,
                       p_interface_line_attribute5   =>
                           TO_CHAR (gd_sysdate, 'MMDDRRRR'),
                       p_interface_line_attribute6   => gn_conc_request_id)
            LOOP
                FOR del_dists IN c_int_dists (del_line.interface_line_id)
                LOOP
                    msg (
                        'Deleting Interface Errors and records at Distribution level');

                    BEGIN
                        DELETE apps.ra_interface_errors_all
                         WHERE interface_distribution_id =
                               del_dists.interface_distribution_id;

                        DELETE apps.ra_interface_distributions_all
                         WHERE interface_distribution_id =
                               del_dists.interface_distribution_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            x_ret_code   := '2';
                            x_ret_msg    :=
                                SUBSTR (
                                       'Error while deleting records from Interface dists and errors in '
                                    || gv_package_name
                                    || lv_proc_name
                                    || ' Error is : '
                                    || SQLERRM,
                                    1,
                                    2000);
                            msg (x_ret_msg);
                    END;
                END LOOP;

                msg ('Deleting Interface Errors and records at line level');


                BEGIN
                    DELETE apps.ra_interface_errors_all
                     WHERE interface_line_id = del_line.interface_line_id;

                    DELETE apps.ra_interface_lines_all
                     WHERE interface_line_id = del_line.interface_line_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        x_ret_code   := '2';
                        x_ret_msg    :=
                            SUBSTR (
                                   'Error while deleting records from Interface Lines and errors in '
                                || gv_package_name
                                || lv_proc_name
                                || ' Error is : '
                                || SQLERRM,
                                1,
                                2000);
                        msg (x_ret_msg);
                END;
            END LOOP;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg    :=
                SUBSTR (
                       x_ret_msg
                    || ' Final Exception Error in check_data: '
                    || gv_package_name
                    || lv_proc_name
                    || ' Error is : '
                    || SQLERRM,
                    1,
                    2000);
            x_ret_code   := '2';
            msg (x_ret_msg);
    END check_data;

    PROCEDURE Update_act_data (x_ret_code OUT NOCOPY VARCHAR2, x_ret_msg OUT NOCOPY VARCHAR2, p_conc_request_id IN NUMBER)
    IS
        CURSOR Update_act_data IS
            SELECT *
              FROM xxdo.xxd_ar_lcx_invoices_stg_t
             WHERE 1 = 1 AND request_id = p_conc_request_id;

        lv_proc_name   VARCHAR2 (30) := 'UPDATE_ACT_DATA';
    BEGIN
        FOR upd IN Update_act_data
        LOOP
            UPDATE xxdo.xxd_ar_lcx_invoices_t lcx
               SET trx_number = upd.trx_number, status = upd.status, error_msg = upd.error_msg,
                   request_id = p_conc_request_id, last_update_date = upd.last_update_date
             WHERE lcx.record_id = upd.record_id;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code   := '2';
            x_ret_msg    :=
                SUBSTR (
                       'Exception while updating the actual table Data : '
                    || gv_package_name
                    || lv_proc_name
                    || ' Error is : '
                    || SQLERRM,
                    1,
                    2000);
            msg (x_ret_msg);
    END Update_act_data;

    PROCEDURE display_data (x_ret_code OUT NOCOPY VARCHAR2, x_ret_msg OUT NOCOPY VARCHAR2, p_request_id IN NUMBER)
    IS
        ln_total_cnt       NUMBER := 0;
        ln_processed_cnt   NUMBER := 0;
        ln_error_cnt       NUMBER := 0;
        lv_proc_name       VARCHAR2 (30) := 'DISPLAY_DATA';
    BEGIN
        SELECT COUNT (*)
          INTO ln_total_cnt
          FROM xxdo.xxd_ar_lcx_invoices_t
         WHERE request_id = p_request_id;

        SELECT COUNT (*)
          INTO ln_processed_cnt
          FROM xxdo.xxd_ar_lcx_invoices_t
         WHERE request_id = p_request_id AND status = 'P';

        SELECT COUNT (*)
          INTO ln_error_cnt
          FROM xxdo.xxd_ar_lcx_invoices_t
         WHERE request_id = p_request_id AND status = 'E';

        msg (' Total records count for this request is : ' || ln_total_cnt,
             'N',
             'OUT');
        msg (
               ' Total success records for this request is : '
            || ln_processed_cnt,
            'N',
            'OUT');
        msg (' Total error records for this request is : ' || ln_error_cnt,
             'N',
             'OUT');
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code   := '2';
            x_ret_msg    :=
                SUBSTR (
                       'Exception while displaying the data count : '
                    || gv_package_name
                    || lv_proc_name
                    || ' Error is : '
                    || SQLERRM,
                    1,
                    2000);
            msg (x_ret_msg);
    END display_data;

    PROCEDURE MAIN (x_retcode OUT VARCHAR2, x_errbuf OUT VARCHAR2, p_file_name IN VARCHAR2, p_org_name IN VARCHAR2, p_trx_type IN VARCHAR2, p_brand IN VARCHAR2, p_account_num IN VARCHAR2, p_trx_date_from IN VARCHAR2, p_trx_date_to IN VARCHAR2
                    , p_reprocess IN VARCHAR2)
    IS
        l_ret_code          VARCHAR2 (10);
        l_err_msg           VARCHAR2 (4000);
        ex_load_interface   EXCEPTION;
        ex_create_trxn      EXCEPTION;
        ex_val_staging      EXCEPTION;
        ex_check_data       EXCEPTION;
        ex_insert_stg       EXCEPTION;
        ex_upd_data         EXCEPTION;
        ex_display_data     EXCEPTION;
        l_org_name          apps.hr_operating_units.name%TYPE;
        l_account_num       apps.hz_cust_accounts.account_number%TYPE;
        l_trx_type          apps.ra_cust_trx_types_all.name%TYPE;
        l_trx_date_from     VARCHAR2 (100);
        l_trx_date_to       VARCHAR2 (100);
    BEGIN
        l_org_name      := NULL;
        l_account_num   := NULL;

        IF p_org_name IS NOT NULL
        THEN
            BEGIN
                SELECT name
                  INTO l_org_name
                  FROM HR_OPERATING_UNITS
                 WHERE organization_id = p_org_name;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_org_name   := NULL;
            END;
        ELSE
            l_org_name   := p_org_name;
        END IF;

        IF p_account_num IS NOT NULL
        THEN
            BEGIN
                SELECT account_number
                  INTO l_account_num
                  FROM hz_cust_accounts
                 WHERE cust_account_id = p_account_num;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_account_num   := NULL;
            END;
        ELSE
            l_account_num   := p_account_num;
        END IF;

        IF p_trx_type IS NOT NULL
        THEN
            BEGIN
                SELECT rctt.name
                  INTO l_trx_type
                  FROM ra_cust_trx_types_all rctt
                 WHERE cust_trx_type_id = p_trx_type;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_trx_type   := NULL;
            END;
        ELSE
            l_trx_type   := p_trx_type;
        END IF;

        msg (
            'Deckers Receivables Lucernex Transaction Import Program - Started',
            'Y');
        msg ('Parameters passed are as below ');
        msg (
            '--------------------------------------------------------------');
        msg ('File Name is                : ' || p_file_name);
        msg ('OU Name is                  : ' || l_org_name);
        msg ('Transaction Type is         : ' || l_trx_type);
        msg ('Brand is                    : ' || p_brand);
        msg ('Account Number is           : ' || l_account_num);
        msg ('From Transaction Date is    : ' || p_trx_date_from);
        msg ('To Transaction Date is      : ' || p_trx_date_to);
        msg ('Reprocess Flag is           : ' || p_reprocess);
        msg (
            '--------------------------------------------------------------');

        l_ret_code      := NULL;
        l_err_msg       := NULL;

        msg ('Start of Data Insertion');

        IF NVL (p_reprocess, 'N') = 'N'
        THEN
            insert_staging (x_ret_code => l_ret_code, x_ret_msg => l_err_msg, p_file_name => p_file_name, p_org_name => l_org_name, p_trx_type => l_trx_type, p_brand => p_brand, p_account_num => l_account_num, p_trx_date_from => p_trx_date_from, p_trx_date_to => p_trx_date_to
                            , p_reprocess => p_reprocess);
        ELSIF NVL (p_reprocess, 'N') = 'Y'
        THEN
            update_staging (x_ret_code => l_ret_code, x_ret_msg => l_err_msg, p_file_name => p_file_name, p_org_name => l_org_name, p_trx_type => l_trx_type, p_brand => p_brand, p_account_num => l_account_num, p_trx_date_from => p_trx_date_from, p_trx_date_to => p_trx_date_to
                            , p_reprocess => p_reprocess);
        END IF;

        IF l_ret_code = '2'
        THEN
            RAISE ex_insert_stg;
        END IF;

        l_ret_code      := NULL;
        l_err_msg       := NULL;

        msg ('Start of Data Validation ');

        validate_staging (x_ret_code => l_ret_code, x_ret_msg => l_err_msg, p_file_name => p_file_name, p_org_name => l_org_name, p_trx_type => l_trx_type, p_brand => p_brand, p_account_num => l_account_num, p_trx_date_from => p_trx_date_from, p_trx_date_to => p_trx_date_to
                          , p_reprocess => p_reprocess);

        IF l_ret_code = '2'
        THEN
            RAISE ex_val_staging;
        END IF;

        l_ret_code      := NULL;
        l_err_msg       := NULL;

        msg ('Start of Interface Loading');

        load_interface (x_ret_code => l_ret_code, x_ret_msg => l_err_msg);

        IF l_ret_code = '2'
        THEN
            RAISE ex_load_interface;
        END IF;

        l_ret_code      := NULL;
        l_err_msg       := NULL;

        msg ('Start of Transaction Creation');

        create_transactions (x_ret_code => l_ret_code, x_ret_msg => l_err_msg);

        IF l_ret_code = '2'
        THEN
            RAISE ex_create_trxn;
        END IF;

        l_ret_code      := NULL;
        l_err_msg       := NULL;

        msg ('Validating Transactions created');

        check_data (x_ret_code => l_ret_code, x_ret_msg => l_err_msg);

        IF l_ret_code = '2'
        THEN
            RAISE ex_check_data;
        END IF;

        l_ret_code      := NULL;
        l_err_msg       := NULL;

        msg ('Updating SOA Staging table');

        update_act_data (x_ret_code          => l_ret_code,
                         x_ret_msg           => l_err_msg,
                         p_conc_request_id   => gn_conc_request_id);

        IF l_ret_code = '2'
        THEN
            RAISE ex_upd_data;
        END IF;

        l_ret_code      := NULL;
        l_err_msg       := NULL;

        msg ('Display record count in output');

        display_data (x_ret_code     => l_ret_code,
                      x_ret_msg      => l_err_msg,
                      p_request_id   => gn_conc_request_id);

        IF l_ret_code = '2'
        THEN
            RAISE ex_display_data;
        END IF;
    EXCEPTION
        WHEN ex_insert_stg
        THEN
            --         x_retcode := l_ret_code;
            --         x_errbuf := l_err_msg;
            msg ('Error Inserting data into Staging:' || l_err_msg);
        WHEN ex_val_staging
        THEN
            --         x_retcode := l_ret_code;
            --         x_errbuf := l_err_msg;
            msg ('Error Validating Staging Data:' || l_err_msg);
        WHEN ex_load_interface
        THEN
            --         x_retcode := l_ret_code;
            --         x_errbuf := l_err_msg;
            msg ('Error Populating RA_INTERFACE tables:' || l_err_msg);
        WHEN ex_create_trxn
        THEN
            --         x_retcode := l_ret_code;
            --         x_errbuf := l_err_msg;
            msg (
                   'Error Submitting Program - Auto Invoice Master program :'
                || l_err_msg);
        WHEN ex_check_data
        THEN
            --         x_retcode := l_ret_code;
            --         x_errbuf := l_err_msg;
            msg ('Error while checking Transaction creation:' || l_err_msg);
        WHEN ex_upd_data
        THEN
            --         x_retcode := l_ret_code;
            --         x_errbuf := l_err_msg;
            msg ('Error while updating Actual table data:' || l_err_msg);
        WHEN ex_display_data
        THEN
            --         x_retcode := l_ret_code;
            --         x_errbuf := l_err_msg;
            msg ('Error while displaying output data:' || l_err_msg);
        WHEN OTHERS
        THEN
            --         x_retcode := '2';
            --         x_errbuf := SQLERRM;
            msg (' Error in Main:' || SUBSTR (SQLERRM, 1, 2000));
    END;
END XXD_AR_LCX_INVOICES_PKG;
/
