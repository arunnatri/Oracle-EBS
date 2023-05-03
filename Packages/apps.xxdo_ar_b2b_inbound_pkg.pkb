--
-- XXDO_AR_B2B_INBOUND_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:28 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_AR_B2B_INBOUND_PKG"
/***************************************************************************************
* Program Name : XXDO_AR_B2B_INBOUND_PKG                                               *
* Language     : PL/SQL                                                                *
* Description  : Package to Consume and Process Inbound files for B2B Portal           *
*                integration                                                           *
* History      :                                                                       *
*                                                                                      *
* WHO          :       WHAT      Desc                                    WHEN          *
* -------------- ----------------------------------------------------------------------*
* Madhav Dhurjaty      1.0      Initial Version                         06-DEC-2017    *
* Madhav Dhurjaty      2.0      B2B Phase 2 EMEA Changes(CCR0006692)    28-MAY-2018    *
* Kranthi Bollam       2.1      CCR0007634 - Creating a unique receipt  18-Sep-2019
*                               number even if Date-Amount-Type are
*                               same. CCR0007964-Fixed Unable to get
*                               receivable application id error.
* Tejaswi Gangumalla   2.2      CCR0008689 -When selecting to use a     09-Jun-2020
                                partial credit memo in Billtrust,
                                it applied the full credit memo
                                amount in Oracle
* Damodara Gupta       2.3      CCR0009930                              13-Apr-2022
* -------------------------------------------------------------------------------------*/
AS
    gv_package_name    CONSTANT VARCHAR (30) := 'XXDO_AR_B2B_INBOUND_PKG';
    gv_time_stamp               VARCHAR2 (40)
                                    := TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS');
    gn_user_id         CONSTANT NUMBER := fnd_global.user_id;
    gv_default_email   CONSTANT VARCHAR2 (50)
                                    := 'jithender.komuravall@deckers.com' ;
    --JK to initiate a request to create BSA.finance@deckers.com mail ID.
    gn_input_notif_req_id       NUMBER := NULL;
    --lg_stub_batch_name    VARCHAR2(100) := 'DI CREDIT BATCH';
    lg_stub_batch_id            NUMBER := -100;
    lg_stub_cash_rcpt_id        NUMBER := -200;
    gn_reprocess_flag           VARCHAR2 (1) DEFAULT 'N';
    gn_resp_name                VARCHAR2 (120)
                                    := 'Deckers Receivables Super User';

    -----
    -----
    --Write messages into LOG file
    --Parameters
    --PV_MSG        Message to be printed
    --PV_TIME       Print timestamp or not. Default is NO.
    PROCEDURE print_log (pv_msg          IN VARCHAR2,
                         pv_time         IN VARCHAR2 DEFAULT 'N',
                         pv_debug_mode   IN NUMBER DEFAULT 1)
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
            print_log (lv_msg);
        ELSE
            IF pv_debug_mode > gn_debug_level
            THEN
                fnd_file.put_line (fnd_file.LOG, lv_msg);
            END IF;
        END IF;
    --fnd_file.put_line (fnd_file.LOG, msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Unable to print log:' || SQLERRM);
    END print_log;

    ----
    ----
    --Write messages into output file
    --Parameters
    --PV_MSG        Message to be printed
    --PV_TIME       Print timestamp or not. Default is NO.
    PROCEDURE print_out (pv_msg IN VARCHAR2, pv_time IN VARCHAR2 DEFAULT 'N')
    IS
        lv_proc_name    VARCHAR2 (30) := 'PRINT_OUT';
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
            print_log (lv_msg);
        ELSE
            fnd_file.put_line (fnd_file.output, lv_msg);
        END IF;
    --fnd_file.put_line (fnd_file.output, msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Unable to print output:' || SQLERRM);
    END print_out;

    ----
    ----
    FUNCTION get_email_ids (p_email_lkp_name IN VARCHAR2--                          ,p_notif_type         IN  VARCHAR2
                                                        )
        RETURN VARCHAR2
    IS
        CURSOR recipients_cur IS
            SELECT ffvs.flex_value_set_name, ffv.description email_id
              FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffv
             WHERE     1 = 1
                   AND ffvs.flex_value_set_name = p_email_lkp_name
                   AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                   AND ffv.enabled_flag = 'Y'
                   AND ffv.enabled_flag = 'Y'
                   AND NVL (ffv.start_date_active, SYSDATE) <= SYSDATE
                   AND NVL (ffv.end_date_active, SYSDATE + 1) > SYSDATE;

        lv_email       VARCHAR2 (500) := NULL;
        lv_proc_name   VARCHAR2 (30) := 'GET_EMAIL_IDS';
    BEGIN
        FOR recipients_rec IN recipients_cur
        LOOP
            lv_email   := lv_email || ',' || recipients_rec.email_id;
        END LOOP;

        IF (lv_email IS NOT NULL AND LENGTH (lv_email) > 1)
        THEN
            lv_email   := SUBSTR (lv_email, 2);
        ELSE
            lv_email   := gv_default_email;
        END IF;

        RETURN lv_email;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_email   := gv_default_email;
            RETURN lv_email;
    END get_email_ids;

    ----
    ----
    ----
    ----
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

    ----
    ----
    ---- Procedure to send notifications
    ----
    PROCEDURE send_notification (p_program_name IN VARCHAR2, p_log_or_out IN VARCHAR2 DEFAULT NULL, p_conc_request_id IN NUMBER
                                 , p_email_lkp_name IN VARCHAR2, x_ret_code OUT NUMBER, x_ret_message OUT VARCHAR2)
    IS
        lv_proc_name          VARCHAR2 (30) := 'SEND_NOTIFICATION';
        lv_err_msg            VARCHAR2 (2000) := NULL;
        lv_logfile_name       VARCHAR2 (30) := NULL;
        lv_logfile_path       VARCHAR2 (255) := NULL;
        lv_outfile_name       VARCHAR2 (30) := NULL;
        lv_outfile_path       VARCHAR2 (255) := NULL;
        lv_status_code        VARCHAR2 (1) := NULL;
        lv_phase_code         VARCHAR2 (1) := NULL;
        lv_status_meaning     VARCHAR2 (80) := NULL;
        lv_phase_meaning      VARCHAR2 (80) := NULL;
        lv_notif_type         VARCHAR2 (30) := NULL;
        lv_file_path          VARCHAR2 (255) := NULL;
        lv_file_name          VARCHAR2 (30) := NULL;
        lv_email_ids          VARCHAR2 (500) := NULL;
        lv_email_sub          VARCHAR2 (2000) := NULL;
        lv_email_body         VARCHAR2 (2000) := NULL;
        ln_email_req_id       NUMBER := 0;
        l_req_return_status   BOOLEAN;
        lc_phase              VARCHAR2 (30) := NULL;
        lc_status             VARCHAR2 (30) := NULL;
        lc_dev_phase          VARCHAR2 (30) := NULL;
        lc_dev_status         VARCHAR2 (30) := NULL;
        lc_message            VARCHAR2 (30) := NULL;
    BEGIN
        print_log ('Parameters passed to Send Notifications Procedure',
                   'N',
                   1);
        print_log ('Program Name: ' || p_program_name, 'N', 1);
        print_log ('Request ID: ' || p_conc_request_id, 'N', 1);
        print_log ('Email Lookup Name: ' || p_email_lkp_name, 'N', 1);

        IF p_conc_request_id <> 0 OR p_conc_request_id IS NOT NULL
        THEN
            BEGIN
                SELECT SUBSTR (fcr.logfile_name, 1, INSTR (fcr.logfile_name, '/', -1) - 1) logfile_path, SUBSTR (fcr.logfile_name, INSTR (fcr.logfile_name, '/', -1) + 1) logfile_name, SUBSTR (fcr.outfile_name, 1, INSTR (fcr.outfile_name, '/', -1) - 1) outfile_path,
                       SUBSTR (fcr.outfile_name, INSTR (fcr.outfile_name, '/', -1) + 1) outfile_name, flv_s.lookup_code status_code, flv_s.meaning status_meaning,
                       flv_p.lookup_code phase_code, flv_p.meaning phase_meaning
                  INTO lv_logfile_path, lv_logfile_name, lv_outfile_path, lv_outfile_name,
                                      lv_status_code, lv_status_meaning, lv_phase_code,
                                      lv_phase_meaning
                  FROM fnd_concurrent_requests fcr, fnd_lookup_values flv_s, fnd_lookup_values flv_p
                 WHERE     1 = 1
                       AND fcr.status_code = flv_s.lookup_code
                       AND flv_s.lookup_type = 'CP_STATUS_CODE'
                       AND flv_s.enabled_flag = 'Y'
                       AND flv_s.view_application_id = 0
                       AND flv_s.LANGUAGE = 'US'
                       AND fcr.phase_code = flv_p.lookup_code
                       AND flv_p.lookup_type = 'CP_PHASE_CODE'
                       AND flv_p.enabled_flag = 'Y'
                       AND flv_p.view_application_id = 0
                       AND flv_p.LANGUAGE = 'US'
                       AND fcr.request_id = p_conc_request_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    NULL;
                WHEN OTHERS
                THEN
                    NULL;
            END;
        ELSE
            print_log ('Concurrent request id passed is null or zero',
                       'N',
                       1);
            RETURN;
        END IF;

        --Based on the program status send success or failure email
        --Assigning the values variables which are passed as parameters to the email program
        IF UPPER (p_log_or_out) = 'LOG'
        THEN
            lv_notif_type   := 'LOG';
            lv_file_path    := lv_logfile_path;
            lv_file_name    := lv_logfile_name;
            lv_email_ids    := get_email_ids (p_email_lkp_name);
            --, lv_notif_type);
            lv_email_body   :=
                'Please check the attached LOG file for program Errors/Warnings';
        ELSIF UPPER (p_log_or_out) = 'OUT'
        THEN
            lv_notif_type   := 'OUTPUT';
            lv_file_path    := lv_outfile_path;
            lv_file_name    := lv_outfile_name;
            lv_email_ids    := get_email_ids (p_email_lkp_name);
            --, lv_notif_type);
            lv_email_body   :=
                'Please see attached Output file for program Output';
        ELSE
            IF UPPER (lv_status_meaning) = UPPER ('Normal')
            THEN
                lv_notif_type   := 'SUCCESS';
                lv_file_path    := lv_outfile_path;
                lv_file_name    := lv_outfile_name;
                lv_email_ids    := get_email_ids (p_email_lkp_name);
                --, lv_notif_type);
                lv_email_body   :=
                    'Please see attached Output file for program Output';
            ELSE
                lv_notif_type   := 'ERROR';
                lv_file_path    := lv_logfile_path;
                lv_file_name    := lv_logfile_name;
                lv_email_ids    := get_email_ids (p_email_lkp_name);
                --, lv_notif_type);
                lv_email_body   :=
                    'Please check the attached LOG file for program Errors/Warnings';
            END IF;
        END IF;

        IF p_program_name = 'OPEN_AR_FILE'
        THEN
            lv_email_sub   :=
                   lv_notif_type
                || ' - B2B - Open AR File Program Notification on '
                || gv_time_stamp;
        ELSIF p_program_name = 'STATEMENT_FILE'
        THEN
            lv_email_sub   :=
                   lv_notif_type
                || ' - B2B - Statements File Program Notification on '
                || gv_time_stamp;
        ELSIF p_program_name = 'BILLING_FILE'
        THEN
            lv_email_sub   :=
                   lv_notif_type
                || ' - B2B - Billing File Program Notification on '
                || gv_time_stamp;
        ELSIF p_program_name = 'CASHAPP_INBOUND'
        THEN
            lv_email_sub   :=
                   lv_notif_type
                || ' - B2B - Inbound Cash App File Program Notification on '
                || gv_time_stamp;
        ELSIF p_program_name = 'LOAD_CASHAPP_FILE'
        THEN
            lv_email_sub   :=
                   lv_notif_type
                || ' - B2B - Load File Program Notification on '
                || gv_time_stamp;
        END IF;

        --Submit concurrent program to send an email
        ln_email_req_id   :=
            fnd_request.submit_request (application => 'XXDO', program => 'XXDOAR_B2B_SEND_NOTIFICATIONS', description => 'Send Email Notification', start_time => SYSDATE, sub_request => FALSE, argument1 => lv_file_path, argument2 => lv_file_name, argument3 => lv_email_body, argument4 => lv_email_ids
                                        , argument5 => lv_email_sub);
        COMMIT;

        IF ln_email_req_id = 0
        THEN
            --print_log('Send Email Notification concurrent request failed to submit', 'Y');
            lv_err_msg      :=
                SUBSTR (
                       'Send Email Notification concurrent request failed to submit. Please check SEND_NOTIFICATION procedure.'
                    || SQLERRM,
                    1,
                    2000);
            print_log (lv_err_msg, 'N', 1);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
        ELSE
            print_log (
                   'Successfully Submitted the Send Email Notification Concurrent Request with request ID: '
                || ln_email_req_id,
                'N',
                1);
        END IF;

        IF ln_email_req_id > 0
        THEN
            LOOP
                --To make process execution to wait for 1st program to complete
                l_req_return_status   :=
                    fnd_concurrent.wait_for_request (
                        request_id   => ln_email_req_id,
                        INTERVAL     => 5,
                        --Interval Number of seconds to wait between checks
                        max_wait     => 600,
                        --Maximum number of seconds to wait for the request completion
                        -- out arguments
                        phase        => lc_phase,
                        status       => lc_status,
                        dev_phase    => lc_dev_phase,
                        dev_status   => lc_dev_status,
                        MESSAGE      => lc_message);
                EXIT WHEN    UPPER (lc_phase) = 'COMPLETED'
                          OR UPPER (lc_status) IN
                                 ('CANCELLED', 'ERROR', 'TERMINATED');
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_err_msg      :=
                SUBSTR (
                       'When Others exception while sending notification in '
                    || lv_proc_name
                    || ' procedure. Error is: '
                    || SQLERRM,
                    1,
                    2000);
            print_log (lv_err_msg, 'N', 1);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
    END send_notification;

    ----
    ----
    ---- Function to get status meaning
    ----
    FUNCTION get_status_meaning (p_status_code IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_status_meaning   VARCHAR2 (50) := 'UNKNOWN';
        lv_proc_name        VARCHAR2 (30) := 'GET_STATUS_MEANING';
    BEGIN
        SELECT ffv.description
          INTO lv_status_meaning
          FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffv
         WHERE     1 = 1
               AND ffvs.flex_value_set_id = ffv.flex_value_set_id
               AND ffvs.flex_value_set_name =
                   'XXDOAR_B2B_INBOUND_STATUSES_VS'
               AND NVL (ffv.start_date_active, SYSDATE) <= SYSDATE
               AND NVL (ffv.end_date_active, SYSDATE) >= SYSDATE
               AND ffv.enabled_flag = 'Y'
               AND ffv.flex_value = p_status_code;

        RETURN lv_status_meaning;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN lv_status_meaning;
    END get_status_meaning;

    /*B2B Phase 2 EMEA Changes(CCR0006692) - Start*/
    ----
    ----Procedure to get Org ID and Bank Account Id based
    ----on the position5 of Inbound file
    ----
    PROCEDURE get_position5_details (p_position5         IN     VARCHAR2,
                                     x_bank_account_id      OUT NUMBER,
                                     x_org_id               OUT NUMBER,
                                     x_ret_code             OUT NUMBER,
                                     x_ret_message          OUT VARCHAR2)
    IS
    BEGIN
        SELECT TO_NUMBER (ffvv.attribute1), TO_NUMBER (ffvv.attribute2)
          INTO x_bank_account_id, x_org_id
          FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffvv
         WHERE     1 = 1
               AND ffvs.flex_value_set_id = ffvv.flex_value_set_id
               AND ffvs.flex_value_set_name = 'XXDOAR_B2B_CASHAPP_BT_POS5_VS'
               AND ffvv.enabled_flag = 'Y'
               AND NVL (ffvv.start_date_active, SYSDATE) <= SYSDATE
               AND NVL (ffvv.end_date_active, SYSDATE + 1) > SYSDATE
               AND flex_value = p_position5;

        IF x_org_id IS NULL
        THEN
            x_ret_code   := gn_error;
            x_ret_message   :=
                ' Null OrgID for Position5 value:' || p_position5;
            print_log (x_ret_message, 'N', 1);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_bank_account_id   := NULL;
            x_org_id            := NULL;
            x_ret_code          := gn_error;
            x_ret_message       :=
                   ' Error getting OrgID for Position5 value:'
                || p_position5
                || ' '
                || SQLERRM;
            print_log (x_ret_message, 'N', 1);
    END get_position5_details;

    /*B2B Phase 2 EMEA Changes(CCR0006692) - End*/
    ----
    ----
    ---- Check if this is an open payment
    ----
    FUNCTION is_open_payment (p_org_id           IN NUMBER,
                              p_receipt_number   IN VARCHAR2)
        RETURN VARCHAR2
    IS
        ln_count       NUMBER := 0;
        lv_proc_name   VARCHAR2 (60) := 'IS_OPEN_PAYMENT';
    BEGIN
        SELECT COUNT (1)
          INTO ln_count
          FROM ar_cash_receipts_all cr, ar_payment_schedules_all ps
         WHERE     1 = 1
               AND cr.cash_receipt_id = ps.cash_receipt_id
               AND cr.org_id = p_org_id
               AND cr.receipt_number = p_receipt_number
               AND ps.CLASS = 'PMT'
               AND ps.amount_due_remaining <> 0;

        IF ln_count > 0
        THEN
            RETURN p_receipt_number;
        ELSE
            RETURN NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Error in is_open_payment - ' || SQLERRM);
            RETURN NULL;
    END is_open_payment;

    ----
    ----
    ---- Check if this is an open payment
    ----
    PROCEDURE is_open_trx (p_org_id IN NUMBER, p_customer_trx_id IN NUMBER, x_ret_code OUT NUMBER
                           , x_ret_message OUT VARCHAR2)
    IS
        ln_count       NUMBER := 0;
        lv_proc_name   VARCHAR2 (60) := 'IS_OPEN_TRX';
    BEGIN
        SELECT COUNT (1)
          INTO ln_count
          FROM ra_customer_trx_all ct, ar_payment_schedules_all ps
         WHERE     1 = 1
               AND ct.customer_trx_id = ps.customer_trx_id
               AND ct.org_id = p_org_id
               AND ct.customer_trx_id = p_customer_trx_id
               AND ps.CLASS <> 'PMT'
               AND ps.amount_due_remaining <> 0;

        IF ln_count = 1
        THEN
            x_ret_code   := gn_success;
        ELSE
            x_ret_code      := gn_error;
            x_ret_message   := ' Invalid/ Closed Transaction.';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code      := gn_error;
            x_ret_message   := ' Error in is_open_trx - ' || SQLERRM;
            print_log ('Error in is_open_trx - ' || SQLERRM);
    END is_open_trx;

    ----
    ----
    ----Validation Procedure1 - Operating Unit
    ----
    PROCEDURE get_org_id (p_org_name IN VARCHAR2, x_org_id OUT NUMBER, x_ret_code OUT NUMBER
                          , x_ret_message OUT VARCHAR2)
    IS
        lv_proc_name   VARCHAR2 (30) := 'GET_ORG_ID';
    BEGIN
        SELECT organization_id
          INTO x_org_id
          FROM hr_operating_units
         WHERE UPPER (NAME) = UPPER (p_org_name);

        x_ret_code      := gn_success;
        x_ret_message   := NULL;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_org_id        := NULL;
            x_ret_code      := gn_error;
            x_ret_message   := 'OrgID not found for ' || p_org_name;
            print_log (x_ret_message, 'N', 1);
        WHEN TOO_MANY_ROWS
        THEN
            x_org_id        := NULL;
            x_ret_code      := gn_error;
            x_ret_message   := 'Too may OrgIDs found for ' || p_org_name;
            print_log (x_ret_message, 'N', 1);
        WHEN OTHERS
        THEN
            x_org_id     := NULL;
            x_ret_code   := gn_error;
            x_ret_message   :=
                ' Error getting OrgID for ' || p_org_name || ' ' || SQLERRM;
            print_log (x_ret_message, 'N', 1);
    END get_org_id;

    ----
    ----
    ----Validation Procedure1 - Customer Number
    ----
    PROCEDURE get_customer_id (p_customer_num IN VARCHAR2, x_cust_account_id OUT NUMBER, x_ret_code OUT NUMBER
                               , x_ret_message OUT VARCHAR2)
    IS
        lv_proc_name   VARCHAR2 (30) := 'GET_CUSTOMER_ID';
    BEGIN
        SELECT cust_account_id
          INTO x_cust_account_id
          FROM hz_cust_accounts
         WHERE 1 = 1 --AND UPPER(account_number) = UPPER(p_customer_num)
                     AND account_number = p_customer_num --Modified for performance fix
                                                         AND status = 'A';

        x_ret_code      := gn_success;
        x_ret_message   := NULL;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_cust_account_id   := NULL;
            x_ret_code          := gn_error;
            x_ret_message       :=
                'CustomerID not found for ' || p_customer_num;
            print_log (x_ret_message, 'N', 1);
        WHEN TOO_MANY_ROWS
        THEN
            x_cust_account_id   := NULL;
            x_ret_code          := gn_error;
            x_ret_message       :=
                'Too many CustomerIDs found for ' || p_customer_num;
            print_log (x_ret_message, 'N', 1);
        WHEN OTHERS
        THEN
            x_cust_account_id   := NULL;
            x_ret_code          := gn_error;
            x_ret_message       :=
                   ' Error getting CustomerID for '
                || p_customer_num
                || ' '
                || SQLERRM;
            print_log (x_ret_message, 'N', 1);
    END get_customer_id;

    ----
    ----
    ----Procedure to get customer id
    ----
    PROCEDURE get_customer_num (p_osbatch_id     IN     NUMBER,
                                p_checkno        IN     VARCHAR2,
                                p_depositdate    IN     VARCHAR2,
                                p_checkamount    IN     NUMBER,
                                p_use_branded    IN     VARCHAR2,
                                x_customer_num      OUT NUMBER,
                                x_ret_code          OUT NUMBER,
                                x_ret_message       OUT VARCHAR2)
    IS
        CURSOR c_customer IS
            SELECT DECODE (p_use_branded, 'Y', custno, parentcustno)
              FROM xxdo.xxdoar_b2b_cashapp_stg
             WHERE 1 = 1 AND oraclerequestid = gn_conc_request_id;       --AND
    BEGIN
        NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_customer_num   := NULL;
            x_ret_code       := gn_error;
            x_ret_message    := ' Error getting CustomerID for ' || SQLERRM;
            print_log (x_ret_message, 'N', 1);
    END get_customer_num;

    ----
    ----
    ----Procedure to get OU region
    ----
    PROCEDURE get_ou_region (p_org_id        IN     NUMBER,
                             x_ou_region        OUT VARCHAR2,
                             x_use_branded      OUT VARCHAR2,
                             x_ret_code         OUT NUMBER,
                             x_ret_message      OUT VARCHAR2)
    IS
        lv_proc_name   VARCHAR2 (30) := 'GET_OU_REGION';
    BEGIN
        SELECT ffv.attribute1, NVL (ffv.attribute2, 'Y')
          INTO x_ou_region, x_use_branded
          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values ffv
         WHERE     1 = 1
               AND ffvs.flex_value_set_id = ffv.flex_value_set_id
               AND ffvs.flex_value_set_name = 'XXDOAR_B2B_OPERATING_UNITS'
               AND ffv.flex_value = TO_CHAR (p_org_id);

        IF x_ou_region IS NULL
        THEN
            x_ret_code   := gn_error;
            x_ret_message   :=
                ' Error getting OU Region for ' || p_org_id || ' ' || SQLERRM;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ou_region     := NULL;
            x_use_branded   := NULL;
            x_ret_code      := gn_error;
            x_ret_message   :=
                ' Error getting OU Region for ' || p_org_id || ' ' || SQLERRM;
            print_log (x_ret_message, 'N', 1);
    END get_ou_region;

    ----
    ----
    ---- Procedure to get invoice balance details
    ----
    PROCEDURE get_trx_balance (p_customer_trx_id     IN     NUMBER,
                               x_amt_due_remaining      OUT NUMBER,
                               x_class                  OUT VARCHAR2, --Added new parameter for change 2.2
                               x_ret_code               OUT NUMBER,
                               x_ret_message            OUT NUMBER)
    IS
        lv_proc_name   VARCHAR2 (30) := 'GET_TRX_BALANCE';
    BEGIN
        SELECT amount_due_remaining, CLASS      --Getting class for change 2.2
          INTO x_amt_due_remaining, x_class       --Added class for change 2.2
          FROM ar_payment_schedules_all aps
         WHERE customer_trx_id = p_customer_trx_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_amt_due_remaining   := NULL;
            x_ret_code            := gn_error;
            x_ret_message         :=
                   ' Error in get_trx_balance for '
                || p_customer_trx_id
                || ' '
                || SQLERRM;
            print_log (x_ret_message, 'N', 1);
    END get_trx_balance;

    ----
    ----
    ---- Procedure to create receipt number
    ----
    PROCEDURE create_receipt_num (p_org_id IN NUMBER, p_receipt_date IN DATE, p_receipt_amt IN NUMBER, p_payment_type IN VARCHAR2, p_receipt_num IN VARCHAR2 DEFAULT NULL, p_receipt_id IN NUMBER DEFAULT NULL, p_checkno IN VARCHAR2, --p_auto_num        IN NUMBER ,
                                                                                                                                                                                                                                       x_receipt_num OUT VARCHAR2, x_ret_code OUT NUMBER
                                  , x_ret_message OUT VARCHAR2)
    IS
        lv_receipt_num     VARCHAR2 (30) := p_receipt_num;
        ln_receipt_count   NUMBER := 0;
        ln_ret_code        NUMBER := 0;
        lv_ret_message     VARCHAR2 (2000) := NULL;
        lv_ou_region       VARCHAR2 (30) := NULL;
        lv_use_branded     VARCHAR2 (1) := NULL;
        lv_proc_name       VARCHAR2 (30) := 'CREATE_RECEIPT_NUM';

        CURSOR cur_receipt_count (p_receipt_num IN VARCHAR2)
        IS
            SELECT COUNT (1)
              FROM ar_cash_receipts_all
             WHERE     org_id = p_org_id
                   AND receipt_number LIKE p_receipt_num || '%';
    BEGIN
        IF p_receipt_id IS NULL
        THEN
            get_ou_region (p_org_id        => p_org_id,
                           x_ou_region     => lv_ou_region,
                           x_use_branded   => lv_use_branded,
                           x_ret_code      => ln_ret_code,
                           x_ret_message   => lv_ret_message);

            IF lv_receipt_num IS NULL
            THEN
                /*B2B Phase 2 EMEA Changes(CCR0006692) - Start*/
                /*
                IF NVL(lv_ou_region,'NA') = 'NA'
                THEN
                  IF UPPER(p_payment_type) = 'CHECK'
                  THEN
                    lv_receipt_num         := SUBSTR(TO_CHAR(p_receipt_date,'DDMMYY')
                                            ||'-'||TO_CHAR(ROUND(p_receipt_amt,2))
                                            ||'-'||'CK'
                                            ||p_checkno
                                            ,1,27);
                  ELSE
                    lv_receipt_num         := SUBSTR(TO_CHAR(p_receipt_date,'DDMMYY')
                                            ||'-'||TO_CHAR(ROUND(p_receipt_amt,2))
                                            ||'-'||p_payment_type,1,27)
                                            ;

                  END IF;
                ELSE
                  lv_receipt_num := SUBSTR(TO_CHAR(p_receipt_date,'DDMMYY') ||'-' ||TO_CHAR(ROUND(p_receipt_amt,2)),1,25);
                END IF;
                */
                --Both NA and EMEA regions will now have same
                --Receipt numbering convention
                --Rest of the logic remains as is
                IF UPPER (p_payment_type) = 'CHECK'
                THEN
                    lv_receipt_num   :=
                        SUBSTR (
                               TO_CHAR (p_receipt_date, 'DDMMYY')
                            || '-'
                            || TO_CHAR (ROUND (p_receipt_amt, 2))
                            || '-'
                            || 'CK'
                            || p_checkno,
                            1,
                            27);
                ELSE
                    lv_receipt_num   :=
                        SUBSTR (
                               TO_CHAR (p_receipt_date, 'DDMMYY')
                            || '-'
                            || TO_CHAR (ROUND (p_receipt_amt, 2))
                            || '-'
                            || p_payment_type,
                            1,
                            27);
                END IF;
            /*B2B Phase 2 EMEA Changes(CCR0006692) - End*/
            END IF;

            OPEN cur_receipt_count (lv_receipt_num);

            FETCH cur_receipt_count INTO ln_receipt_count;

            CLOSE cur_receipt_count;

            IF ln_receipt_count > 0
            THEN
                lv_receipt_num   := lv_receipt_num || '-' || ln_receipt_count;
            END IF;
        END IF;

        IF LENGTH (lv_receipt_num) <= 30
        THEN
            x_receipt_num   := lv_receipt_num;
        ELSE
            x_receipt_num   := NULL;
            x_ret_code      := gn_error;
            x_ret_message   :=
                ' Receipt Number too long - ' || lv_receipt_num;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_receipt_num   := NULL;
            x_ret_code      := gn_error;
            x_ret_message   := ' Error in create_receipt_num - ' || SQLERRM;
            print_log (x_ret_message, 'N', 1);
    END create_receipt_num;

    ----
    ----
    ---- Procedure to validate receipt numbers and check if they are duplicate for a customer in the same session.
    -----If yes append '-1 or -2 or -3' to the receipt so that the receipt number is unique
    ----Added for change 2.1
    PROCEDURE validate_receipt_num
    IS
        --Cursors declaration
        --Cursor to get Receipt Number by envelope id
        CURSOR rcpt_cur IS
              SELECT stg.org_id,
                     stg.oraclerequestid,
                     stg.envelopeid,
                     stg.checkno,
                     stg.checkamount,
                     stg.depositdate + gn_grace_days
                         deposit_date,
                     NVL (stg.creditidentifier3, stg.default_payment_type)
                         payment_type,
                     CASE
                         WHEN UPPER (
                                  NVL (stg.creditidentifier3,
                                       stg.default_payment_type)) =
                              'CHECK'
                         THEN
                             SUBSTR (
                                    TO_CHAR (stg.depositdate + gn_grace_days,
                                             'DDMMYY')
                                 || '-'
                                 || TO_CHAR (ROUND (stg.checkamount, 2))
                                 || '-'
                                 || 'CK'
                                 || stg.checkno,
                                 1,
                                 27)
                         ELSE
                             SUBSTR (
                                    TO_CHAR (stg.depositdate + gn_grace_days,
                                             'DDMMYY')
                                 || '-'
                                 || TO_CHAR (ROUND (stg.checkamount, 2))
                                 || '-'
                                 || NVL (stg.creditidentifier3,
                                         stg.default_payment_type),
                                 1,
                                 27)
                     END
                         receipt_number
                FROM xxdo.xxdoar_b2b_cashapp_stg stg
               WHERE     1 = 1
                     --AND oracleprocessflag IN ('V')
                     AND oraclerequestid = gn_conc_request_id
                     AND oracle_receipt_num IS NULL
                     AND oracle_receipt_id IS NULL
            GROUP BY stg.org_id, stg.oraclerequestid, stg.envelopeid,
                     stg.checkno, stg.checkamount, stg.depositdate + gn_grace_days,
                     NVL (stg.creditidentifier3, stg.default_payment_type)
            ORDER BY stg.envelopeid, stg.checkno;

        --Cursor to check if the receipt number passed exists in oracle
        CURSOR cur_receipt_count (cn_org_id        IN NUMBER,
                                  cv_receipt_num   IN VARCHAR2)
        IS
            SELECT COUNT (1)
              FROM ar_cash_receipts_all acr
             WHERE     acr.org_id = cn_org_id
                   AND acr.receipt_number LIKE cv_receipt_num || '%';

        --Cursor to check if the receipt number passed exists in the staging table
        --If yes, Get the Record which has max envelope id
        CURSOR rcpt_exists_in_stg_cur (cn_org_id IN NUMBER, cv_receipt_num IN VARCHAR2, cn_envelope_id IN NUMBER
                                       , cv_checkno IN VARCHAR2)
        IS
            SELECT yy.*
              FROM (SELECT xx.*, RANK () OVER (PARTITION BY xx.org_id, xx.oraclerequestid, xx.envelopeid ORDER BY xx.envelopeid DESC) rnk
                      FROM (  SELECT stg.org_id, stg.oraclerequestid, stg.envelopeid,
                                     stg.oracle_receipt_num
                                --                              ,CASE WHEN UPPER(NVL(stg.CreditIdentifier3, stg.default_payment_type)) = 'CHECK'
                                --                                THEN SUBSTR(TO_CHAR(stg.DepositDate + gn_grace_days, 'DDMMYY')
                                --                                            ||'-'||TO_CHAR(ROUND(stg.CheckAmount, 2))
                                --                                            ||'-'||'CK'
                                --                                            || stg.CheckNo
                                --                                           , 1, 27
                                --                                           )
                                --                                ELSE SUBSTR(TO_CHAR(stg.DepositDate + gn_grace_days, 'DDMMYY')
                                --                                            ||'-'||TO_CHAR(ROUND(stg.CheckAmount, 2))
                                --                                            ||'-'||NVL(stg.CreditIdentifier3, stg.default_payment_type)
                                --                                            , 1, 27
                                --                                            )
                                --                               END receipt_number
                                FROM xxdo.xxdoar_b2b_cashapp_stg stg
                               WHERE     1 = 1
                                     --AND oracleprocessflag IN ('V')
                                     AND stg.org_id = cn_org_id
                                     AND stg.oraclerequestid =
                                         gn_conc_request_id
                                     AND stg.oracle_receipt_num IS NOT NULL
                                     AND stg.oracle_receipt_id IS NULL
                                     AND stg.oracle_receipt_num LIKE
                                             cv_receipt_num || '%'
                                     --                           AND (CASE WHEN UPPER(NVL(stg.CreditIdentifier3, stg.default_payment_type)) = 'CHECK'
                                     --                                THEN SUBSTR(TO_CHAR(stg.DepositDate + gn_grace_days, 'DDMMYY')
                                     --                                            ||'-'||TO_CHAR(ROUND(stg.CheckAmount, 2))
                                     --                                            ||'-'||'CK'
                                     --                                            || stg.CheckNo
                                     --                                           , 1, 27
                                     --                                           )
                                     --                                ELSE SUBSTR(TO_CHAR(stg.DepositDate + gn_grace_days, 'DDMMYY')
                                     --                                            ||'-'||TO_CHAR(ROUND(stg.CheckAmount, 2))
                                     --                                            ||'-'||NVL(stg.CreditIdentifier3, stg.default_payment_type)
                                     --                                            , 1, 27
                                     --                                            )
                                     --                            END) LIKE cv_receipt_num||'%'
                                     AND stg.envelopeid || '-' || stg.checkno <>
                                         cn_envelope_id || '-' || cv_checkno
                            GROUP BY stg.org_id, stg.oraclerequestid, stg.envelopeid,
                                     stg.oracle_receipt_num--                              ,CASE WHEN UPPER(NVL(stg.CreditIdentifier3, stg.default_payment_type)) = 'CHECK'
                                                           --                                THEN SUBSTR(TO_CHAR(stg.DepositDate + gn_grace_days, 'DDMMYY')
                                                           --                                            ||'-'||TO_CHAR(ROUND(stg.CheckAmount, 2))
                                                           --                                            ||'-'||'CK'
                                                           --                                            || stg.CheckNo
                                                           --                                           , 1, 27
                                                           --                                           )
                                                           --                                ELSE SUBSTR(TO_CHAR(stg.DepositDate + gn_grace_days, 'DDMMYY')
                                                           --                                            ||'-'||TO_CHAR(ROUND(stg.CheckAmount, 2))
                                                           --                                            ||'-'||NVL(stg.CreditIdentifier3, stg.default_payment_type)
                                                           --                                            , 1, 27
                                                           --                                            )
                                                           --                               END
                                                           ) xx) yy
             WHERE 1 = 1 AND yy.rnk = 1;

        --Local Variables Declaration
        lv_proc_name                VARCHAR2 (30) := 'VALIDATE_RECEIPT_NUM';
        ln_receipt_count            NUMBER := 0;
        lv_receipt_num              VARCHAR2 (30) := NULL;
        ln_3rd_hiphen_cnt           NUMBER := 0;
        ln_4th_hiphen_cnt           NUMBER := 0;
        ln_suffix                   NUMBER := 0;
        ln_rcpt_cnt                 NUMBER := 0;
        ln_max_rcpt_id              NUMBER := 0;
        ln_rcpt_exists_in_stg_cnt   NUMBER := 0;
        ln_org_id                   NUMBER := 0;
        ln_oraclerequestid          NUMBER := 0;
        ln_envelopeid               NUMBER := 0;
        lv_oracle_receipt_num       VARCHAR2 (30) := NULL;
    BEGIN
        FOR rcpt_rec IN rcpt_cur
        LOOP
            print_log (
                   ' Validating Receipt Number'
                || rcpt_rec.receipt_number
                || 'for EnvelopeId - '
                || rcpt_rec.envelopeid,
                'N',
                1);
            lv_receipt_num              := rcpt_rec.receipt_number;
            ln_receipt_count            := 0;

            --Check if the receipt number exists or not in Oracle
            OPEN cur_receipt_count (
                cn_org_id        => rcpt_rec.org_id,
                cv_receipt_num   => rcpt_rec.receipt_number);

            FETCH cur_receipt_count INTO ln_receipt_count;

            CLOSE cur_receipt_count;

            --Check if the receipt number exists in staging table or not
            ln_org_id                   := 0;
            ln_oraclerequestid          := 0;
            ln_envelopeid               := 0;
            lv_oracle_receipt_num       := NULL;
            ln_rcpt_exists_in_stg_cnt   := 0;

            BEGIN
                FOR rcpt_exists_in_stg_rec
                    IN rcpt_exists_in_stg_cur (
                           cn_org_id        => rcpt_rec.org_id,
                           cv_receipt_num   => rcpt_rec.receipt_number,
                           cn_envelope_id   => rcpt_rec.envelopeid,
                           cv_checkno       => rcpt_rec.checkno)
                LOOP
                    ln_org_id                   := rcpt_exists_in_stg_rec.org_id;
                    ln_oraclerequestid          :=
                        rcpt_exists_in_stg_rec.oraclerequestid;
                    ln_envelopeid               := rcpt_exists_in_stg_rec.envelopeid;
                    lv_oracle_receipt_num       :=
                        rcpt_exists_in_stg_rec.oracle_receipt_num;
                    ln_rcpt_exists_in_stg_cnt   := rcpt_exists_in_stg_rec.rnk;
                END LOOP;
            EXCEPTION
                WHEN OTHERS
                THEN
                    print_log ('Error in for loop. Error is' || SQLERRM,
                               'N',
                               2);
            END;

            print_log (
                   'ln_receipt_count='
                || ln_receipt_count
                || ' ln_rcpt_exists_in_stg_cnt='
                || ln_rcpt_exists_in_stg_cnt,
                'N',
                1);

            --If receipt number already exists in oracle and does not exists in staging table
            IF     ln_receipt_count > 0                     --Exists in Oracle
               AND NVL (ln_rcpt_exists_in_stg_cnt, 0) = 0
            --Does not exists in staging table
            THEN
                --If only one receipt exists in Oracle
                IF ln_receipt_count = 1
                THEN
                    --Get the position of the third and fourth hiphens (Normally these receipts contain only 2 hiphens)
                    SELECT INSTR (acr.receipt_number, '-', 1,
                                  3) third_hiphen_cnt,
                           INSTR (acr.receipt_number, '-', 1,
                                  4) fourth_hiphen_cnt
                      INTO ln_3rd_hiphen_cnt, ln_4th_hiphen_cnt
                      FROM ar_cash_receipts_all acr
                     WHERE     acr.org_id = rcpt_rec.org_id
                           AND acr.receipt_number LIKE lv_receipt_num || '%';

                    --If third hiphen does not exists then append '-1' (i.e. hiphen 1) to the receipt number
                    IF ln_3rd_hiphen_cnt = 0
                    THEN
                        lv_receipt_num   := lv_receipt_num || '-' || '1';
                    --If third hiphen exists and 4th hiphen does not exists then get the value after hiphen and add one to it
                    ELSIF (ln_3rd_hiphen_cnt > 0 AND ln_4th_hiphen_cnt = 0)
                    THEN
                        --Get the value after the third hiphen
                        BEGIN
                            SELECT TO_NUMBER (SUBSTR (acr.receipt_number,
                                                        INSTR (acr.receipt_number, '-', 1
                                                               , 3)
                                                      + 1)) suffix_after_3rd_hiphen
                              INTO ln_suffix
                              FROM ar_cash_receipts_all acr
                             WHERE     acr.org_id = rcpt_rec.org_id
                                   AND acr.receipt_number LIKE
                                           lv_receipt_num || '%';
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ln_suffix   := NULL;
                        END;

                        --If value exists after third hiphen then add 1 to it
                        IF ln_suffix IS NOT NULL
                        THEN
                            ln_suffix   := ln_suffix + 1;
                            lv_receipt_num   :=
                                lv_receipt_num || '-' || ln_suffix;
                        ELSE
                            lv_receipt_num   := lv_receipt_num || '-' || '1';
                        END IF;
                    END IF;                         --ln_3rd_hiphen_cnt end if
                ----If multiple receipts exists(ln_receipt_count > 1)
                ELSE
                    ln_rcpt_cnt      := 0;
                    ln_max_rcpt_id   := 0;

                    --Get the count and max receipt id of the receipts having third hiphen but not fourth hiphen in receipt number
                    SELECT COUNT (*) rcpt_cnt, MAX (acr.cash_receipt_id)
                      INTO ln_rcpt_cnt, ln_max_rcpt_id
                      FROM ar_cash_receipts_all acr
                     WHERE     1 = 1
                           AND acr.org_id = rcpt_rec.org_id
                           AND acr.receipt_number LIKE lv_receipt_num || '%'
                           AND INSTR (acr.receipt_number, '-', 1,
                                      3) > 0
                           AND INSTR (acr.receipt_number, '-', 1,
                                      4) = 0;

                    --If the receipts with above condition exists
                    IF ln_rcpt_cnt > 0
                    THEN
                        ln_suffix   := NULL;

                        --Get the value after the 3rd hiphen of the receipt number which is created last (Taking Max Cash receipt ID)
                        BEGIN
                            SELECT TO_NUMBER (SUBSTR (acr.receipt_number,
                                                        INSTR (acr.receipt_number, '-', 1
                                                               , 3)
                                                      + 1))
                              INTO ln_suffix
                              FROM ar_cash_receipts_all acr
                             WHERE     1 = 1
                                   AND acr.org_id = rcpt_rec.org_id
                                   AND acr.cash_receipt_id = ln_max_rcpt_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ln_suffix   := NULL;
                        END;

                        IF ln_suffix IS NOT NULL
                        THEN
                            ln_suffix   := ln_suffix + 1;
                            lv_receipt_num   :=
                                lv_receipt_num || '-' || ln_suffix;
                        ELSE
                            lv_receipt_num   := lv_receipt_num || '-' || '1';
                        END IF;
                    END IF;                           --ln_rcpt_cnt > 0 end if
                END IF;                          --ln_receipt_count = 1 end if
            ELSIF     ln_receipt_count > 0                  --Exists in Oracle
                  AND NVL (ln_rcpt_exists_in_stg_cnt, 0) > 0
            --Exists in staging table (New Receipt number is already stamped to one of the previous envelope id's. Get the receipt number of max envelope id)
            THEN
                ln_suffix   := 0;

                BEGIN
                    SELECT TO_NUMBER (SUBSTR (lv_oracle_receipt_num,
                                                INSTR (lv_oracle_receipt_num, '-', 1
                                                       , 3)
                                              + 1)) suffix
                      INTO ln_suffix
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_suffix   := NULL;
                END;

                IF ln_suffix IS NOT NULL
                THEN
                    ln_suffix   := ln_suffix + 1;
                    lv_receipt_num   :=
                        lv_receipt_num || '-' || TO_CHAR (ln_suffix);
                ELSE
                    lv_receipt_num   := lv_receipt_num || '-' || '1';
                END IF;
            ELSIF     ln_receipt_count = 0         --Does not Exists in Oracle
                  AND NVL (ln_rcpt_exists_in_stg_cnt, 0) > 0
            --Exists in staging table (New Receipt number is already stamped to one of the previous envelope id's. Get the receipt number of max envelope id)
            THEN
                ln_suffix   := 0;

                BEGIN
                    SELECT INSTR (lv_oracle_receipt_num, '-', 1,
                                  3)
                      INTO ln_suffix
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_suffix   := 0;
                END;

                IF ln_suffix > 0
                THEN
                    BEGIN
                        SELECT TO_NUMBER (SUBSTR (lv_oracle_receipt_num,
                                                    INSTR (lv_oracle_receipt_num, '-', 1
                                                           , 3)
                                                  + 1)) suffix
                          INTO ln_suffix
                          FROM DUAL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_suffix   := NULL;
                    END;

                    IF ln_suffix IS NOT NULL
                    THEN
                        ln_suffix   := ln_suffix + 1;
                        lv_receipt_num   :=
                            lv_receipt_num || '-' || TO_CHAR (ln_suffix);
                    ELSE
                        lv_receipt_num   := lv_receipt_num || '-' || '1';
                    END IF;
                ELSE
                    lv_receipt_num   := lv_receipt_num || '-' || '1';
                END IF;
            --Does not Exists in Oracle and also in staging table
            ELSE
                lv_receipt_num   := lv_receipt_num;
            END IF;    --ln_receipt_count and ln_rcpt_exists_in_stg_cnt end if

            IF LENGTH (lv_receipt_num) <= 30
            THEN
                lv_receipt_num   := lv_receipt_num;
                ln_rcpt_cnt      := 0;

                --Check if the new receipt number exists in Oracle
                SELECT COUNT (*)
                  INTO ln_rcpt_cnt
                  FROM ar_cash_receipts_all acr
                 WHERE     1 = 1
                       AND acr.org_id = rcpt_rec.org_id
                       AND acr.receipt_number = lv_receipt_num;

                IF ln_rcpt_cnt <= 0
                THEN
                    lv_receipt_num   := lv_receipt_num;
                ELSE
                    lv_receipt_num   := NULL;
                END IF;
            ELSE
                lv_receipt_num   := NULL;
            END IF;

            --Update the staging table with the receipt number
            UPDATE xxdo.xxdoar_b2b_cashapp_stg stg
               SET stg.oracle_receipt_num = lv_receipt_num, last_update_date = SYSDATE, last_updated_by = gn_user_id
             WHERE     1 = 1
                   --AND oracleprocessflag IN ('V')
                   AND stg.org_id = rcpt_rec.org_id
                   AND stg.oraclerequestid = gn_conc_request_id
                   AND stg.oracle_receipt_num IS NULL
                   AND stg.oracle_receipt_id IS NULL
                   AND stg.envelopeid = rcpt_rec.envelopeid
                   AND stg.checkno = rcpt_rec.checkno;

            COMMIT;
        END LOOP;                                          --rcpt_cur end loop

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log (' Error in validate_receipt_num - ' || SQLERRM,
                       'N',
                       1);
    END validate_receipt_num;

    ----
    ----
    ---- Procedure to check if the deposit date is in open period
    ----As part of change 2.1, this is repurposed to return only set of books id
    ----Code to validate Deposit date is moved to VALIDATE_RECEIPT_DATE procedure which is added as part of change 2.1
    PROCEDURE validate_gl_accounting_date (
        p_accounting_date   IN     DATE,
        p_org_id            IN     NUMBER,
        x_sob_id               OUT NUMBER,
        x_ret_code             OUT NUMBER,
        x_ret_message          OUT VARCHAR2)
    IS
        ln_count       NUMBER := 0;
        ln_sob_id      NUMBER;
        lv_proc_name   VARCHAR2 (30) := 'VALIDATE_GL_ACCOUNTING_DATE';
    BEGIN
        SELECT set_of_books_id
          INTO x_sob_id
          FROM hr_operating_units
         WHERE 1 = 1 AND organization_id = p_org_id;
    /*--Commented for change 2.1 -START
    (Validation is not needed here. Also receipt has to be created in next open period if accounting date is in closed period.
    So Removing the check to validate if the accounting date is in open period or not
    SELECT COUNT ( * )
      INTO ln_count
      FROM gl_period_statuses gps
     WHERE gps.application_id = 222  --g_gl_application_id Receivables
       AND gps.set_of_books_id = x_sob_id
       AND gps.closing_status IN ( 'O', 'F' )
       AND p_accounting_date BETWEEN NVL ( gps.start_date, p_accounting_date )
               AND NVL ( gps.end_date, p_accounting_date );

    IF ln_count > 0 THEN
       x_ret_code := gn_success;
       x_ret_message := NULL;
    ELSE
       x_ret_code := gn_error;
       x_ret_message := 'Receivables Period Not Open for the date :'||TO_CHAR(p_accounting_date,'DD-MON-YYYY');
    END IF;
    --Commented for change 2.1 -END*/
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code   := gn_error;
            --x_ret_message := 'Receivables Period Not Open for the date :'||TO_CHAR(p_accounting_date,'DD-MON-YYYY'); --Commented for change 2.1
            x_ret_message   :=
                'Unable to get set of books id for Org ID :' || p_org_id;
            --Added for change 2.1
            print_log (x_ret_message, 'N', 1);
    END validate_gl_accounting_date;

    ----
    ----
    ---- Procedure to check if the deposit date is in open period or not, if not return the open period start date for sysdate
    -----Added for change 2.1 (procedure added)
    PROCEDURE validate_receipt_date (p_deposit_date   IN     DATE,
                                     p_org_id         IN     NUMBER,
                                     x_receipt_date      OUT DATE,
                                     x_ret_code          OUT NUMBER,
                                     x_ret_message       OUT VARCHAR2)
    IS
        ln_count       NUMBER := 0;
        ln_sob_id      NUMBER;
        lv_proc_name   VARCHAR2 (30) := 'VALIDATE_RECEIPT_DATE';
    BEGIN
        --Get the set of books id
        SELECT set_of_books_id
          INTO ln_sob_id
          FROM hr_operating_units
         WHERE 1 = 1 AND organization_id = p_org_id;

        SELECT COUNT (*)
          INTO ln_count
          FROM gl_period_statuses gps
         WHERE     gps.application_id = 222  --g_gl_application_id Receivables
               AND gps.set_of_books_id = ln_sob_id
               AND gps.closing_status IN ('O', 'F')
               AND p_deposit_date BETWEEN NVL (gps.start_date,
                                               p_deposit_date)
                                      AND NVL (gps.end_date, p_deposit_date);

        IF ln_count > 0
        THEN
            x_receipt_date   := p_deposit_date;
            x_ret_code       := gn_success;
            x_ret_message    := NULL;
        ELSE
            --Get the open period start date for sysdate and create receipt on that date
            BEGIN
                SELECT gps.start_date
                  INTO x_receipt_date
                  FROM gl_period_statuses gps
                 WHERE     gps.application_id = 222 --g_gl_application_id Receivables
                       AND gps.set_of_books_id = ln_sob_id
                       AND gps.closing_status IN ('O', 'F')
                       AND TRUNC (SYSDATE) BETWEEN NVL (gps.start_date,
                                                        TRUNC (SYSDATE))
                                               AND NVL (gps.end_date,
                                                        TRUNC (SYSDATE));

                x_ret_code      := gn_success;
                x_ret_message   := NULL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_receipt_date   := NULL;
                    x_ret_code       := gn_error;
                    x_ret_message    :=
                           'Error getting Receivables Open Period start date for current date :'
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY');
                    print_log (x_ret_message, 'N', 1);
            END;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_receipt_date   := NULL;
            x_ret_code       := gn_error;
            x_ret_message    :=
                   'Receivables Period Not Open for the date :'
                || TO_CHAR (p_deposit_date, 'DD-MON-YYYY');
            print_log (x_ret_message, 'N', 1);
    END validate_receipt_date;

    ----
    ----
    ---- Procedure to get receipt class details
    ----
    PROCEDURE get_receipt_class (p_receipt_method_id IN NUMBER, x_receipt_class_id OUT NUMBER, x_ret_code OUT NUMBER
                                 , x_ret_message OUT VARCHAR2)
    IS
        lv_proc_name   VARCHAR2 (30) := 'GET_RECEIPT_CLASS';
    BEGIN
        SELECT arc.receipt_class_id
          INTO x_receipt_class_id
          FROM apps.ar_receipt_methods arm, apps.ar_receipt_classes arc
         WHERE     1 = 1
               AND arm.receipt_class_id = arc.receipt_class_id
               AND arm.receipt_method_id = p_receipt_method_id;

        x_ret_code      := gn_success;
        x_ret_message   := NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_receipt_class_id   := NULL;
            x_ret_code           := gn_error;
            x_ret_message        :=
                   ' Error in get_receipt_class for p_receipt_method_id#'
                || p_receipt_method_id
                || ' - '
                || SQLERRM;
            print_log (x_ret_message, 'N', 1);
    END get_receipt_class;

    ----
    ----
    ---- Procedure to get bank details
    ----
    PROCEDURE get_bank_details (p_bank_account_num IN VARCHAR2 DEFAULT NULL, p_bank_account_id IN NUMBER DEFAULT NULL, x_bank_id OUT NUMBER, x_bank_branch_id OUT NUMBER, x_bank_account_id OUT NUMBER, x_ret_code OUT NUMBER
                                , x_ret_message OUT VARCHAR2)
    IS
        lv_proc_name   VARCHAR2 (30) := 'GET_BANK_DETAILS';
    BEGIN
        IF p_bank_account_num IS NOT NULL AND p_bank_account_id IS NOT NULL
        THEN
            SELECT cbv.bank_party_id, cbbv.branch_party_id, cba.bank_account_id
              INTO x_bank_id, x_bank_branch_id, x_bank_account_id
              FROM apps.ce_banks_v cbv, apps.ce_bank_branches_v cbbv, apps.ce_bank_accounts cba
             WHERE     1 = 1
                   AND cbv.bank_party_id = cbbv.bank_party_id
                   AND cbbv.branch_party_id = cba.bank_branch_id
                   AND cba.bank_account_num = p_bank_account_num;
        ELSIF p_bank_account_num IS NOT NULL AND p_bank_account_id IS NULL
        THEN
            SELECT cbv.bank_party_id, cbbv.branch_party_id, cba.bank_account_id
              INTO x_bank_id, x_bank_branch_id, x_bank_account_id
              FROM apps.ce_banks_v cbv, apps.ce_bank_branches_v cbbv, apps.ce_bank_accounts cba
             WHERE     1 = 1
                   AND cbv.bank_party_id = cbbv.bank_party_id
                   AND cbbv.branch_party_id = cba.bank_branch_id
                   AND cba.bank_account_num = p_bank_account_num;
        ELSIF p_bank_account_id IS NOT NULL AND p_bank_account_num IS NULL
        THEN
            SELECT cbv.bank_party_id, cbbv.branch_party_id, cba.bank_account_id
              INTO x_bank_id, x_bank_branch_id, x_bank_account_id
              FROM apps.ce_banks_v cbv, apps.ce_bank_branches_v cbbv, apps.ce_bank_accounts cba
             WHERE     1 = 1
                   AND cbv.bank_party_id = cbbv.bank_party_id
                   AND cbbv.branch_party_id = cba.bank_branch_id
                   AND cba.bank_account_id = p_bank_account_id;
        ELSIF p_bank_account_id IS NULL AND p_bank_account_num IS NULL
        THEN
            x_ret_code      := gn_error;
            x_ret_message   := 'No Bank Account Details';
        END IF;

        x_ret_code      := gn_success;
        x_ret_message   := NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_bank_id           := NULL;
            x_bank_branch_id    := NULL;
            x_bank_account_id   := NULL;
            x_ret_code          := gn_error;
            x_ret_message       :=
                   ' Error in get_bank_details for Account#'
                || p_bank_account_num
                || ' - '
                || SQLERRM;
            print_log (x_ret_message, 'N', 1);
    END get_bank_details;

    ----
    ----
    ---- Procedure to validate the customer trx number
    ----
    PROCEDURE get_invoice_id (p_trx_number IN VARCHAR2, p_org_id IN NUMBER, p_customer_id IN NUMBER, x_customer_trx_id OUT NUMBER, x_receipt_number OUT VARCHAR2, x_ret_code OUT NUMBER
                              , x_ret_message OUT VARCHAR2)
    IS
        lv_proc_name   VARCHAR2 (30) := 'GET_INVOICE_ID';
        ln_trx_count   NUMBER := 0;
        ln_rct_count   NUMBER := 0;
    BEGIN
        IF p_trx_number IS NOT NULL
        THEN
            SELECT COUNT (1)
              INTO ln_trx_count
              FROM ra_customer_trx_all ct
             WHERE     1 = 1
                   AND ct.trx_number = p_trx_number
                   AND ct.org_id = p_org_id;

            IF ln_trx_count = 0
            THEN
                SELECT COUNT (1)
                  INTO ln_rct_count
                  FROM ar_cash_receipts_all ct
                 WHERE     1 = 1
                       AND ct.receipt_number = p_trx_number
                       AND ct.org_id = p_org_id
                       AND ct.pay_from_customer = p_customer_id;

                IF ln_rct_count = 0
                THEN
                    x_receipt_number   := NULL;
                    x_ret_code         := gn_error;
                    x_ret_message      :=
                        ' Invalid Invoice/ ReceiptNumber= ' || p_trx_number;
                ELSE
                    BEGIN
                        SELECT cr.receipt_number
                          INTO x_receipt_number
                          FROM ar_cash_receipts_all cr, ar_payment_schedules_all ps
                         WHERE     1 = 1
                               AND cr.cash_receipt_id = ps.cash_receipt_id
                               AND ps.CLASS = 'PMT'
                               AND ps.amount_due_remaining <> 0
                               AND cr.receipt_number = p_trx_number
                               AND cr.pay_from_customer = p_customer_id
                               AND cr.org_id = p_org_id;

                        x_ret_code      := gn_success;
                        x_ret_message   := NULL;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            x_ret_code         := gn_error;
                            x_ret_message      :=
                                   ' ReceiptNumber '
                                || p_trx_number
                                || ' is not open.';
                            x_receipt_number   := NULL;
                        WHEN OTHERS
                        THEN
                            x_ret_code         := gn_error;
                            x_ret_message      :=
                                   ' ReceiptNumber '
                                || p_trx_number
                                || ' error='
                                || SQLERRM;
                            x_receipt_number   := NULL;
                    END;
                END IF;
            ELSE
                BEGIN
                    SELECT ct.customer_trx_id
                      INTO x_customer_trx_id
                      FROM ra_customer_trx_all ct, ar_payment_schedules_all ps
                     WHERE     1 = 1
                           AND ct.customer_trx_id = ps.customer_trx_id
                           AND ps.CLASS <> 'PMT'
                           --AND ps.amount_due_remaining <> 0 --Commented for B2B Phase 2 EMEA Changes(CCR0006692)
                           --This condition is not required because the invoice id
                           --needs to be selected irrespective of whether or not trx is open
                           --validation should happen post-receipt creation
                           AND ct.trx_number = p_trx_number
                           AND ct.org_id = p_org_id;

                    x_ret_code      := gn_success;
                    x_ret_message   := NULL;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        x_ret_code          := gn_error;
                        x_ret_message       :=
                               ' Transaction '
                            || p_trx_number
                            || ' is not open.';
                        x_customer_trx_id   := NULL;
                    WHEN OTHERS
                    THEN
                        x_ret_code          := gn_error;
                        x_ret_message       :=
                               ' Transaction '
                            || p_trx_number
                            || ' error='
                            || SQLERRM;
                        x_customer_trx_id   := NULL;
                END;
            END IF;
        ELSE
            x_ret_code      := gn_success;
            x_ret_message   := NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_customer_trx_id   := NULL;
            x_ret_code          := gn_error;
            x_ret_message       :=
                   ' Error in get_invoice_id for Invoice#'
                || p_trx_number
                || ' - '
                || SQLERRM;
            print_log (x_ret_message, 'N', 1);
    END get_invoice_id;

    ----
    ----
    ---- Procedure to get the receipt method
    ----
    PROCEDURE get_invoice_balance (p_customer_trx_id IN NUMBER, x_amt_due_remaining OUT NUMBER, x_ret_code OUT NUMBER
                                   , x_ret_message OUT VARCHAR2)
    IS
        lv_proc_name   VARCHAR2 (30) := 'GET_INVOICE_BALANCE';
    BEGIN
        SELECT amount_due_remaining
          INTO x_amt_due_remaining
          FROM ar_payment_schedules_all
         WHERE     1 = 1
               AND customer_trx_id = p_customer_trx_id
               --AND status <> 'CL' --Commented for B2B Phase 2 EMEA Changes(CCR0006692)
               AND CLASS <> 'PMT';
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code      := gn_error;
            x_ret_message   := ' Error in get_invoice_balance - ' || SQLERRM;
            print_log (x_ret_message);
    END get_invoice_balance;

    ----
    ----
    ---- Procedure to get the receipt method
    ----
    PROCEDURE get_receipt_method (p_org_id IN NUMBER, p_payment_type IN VARCHAR2, p_currency_code IN VARCHAR2, p_lockbox_number IN VARCHAR2 DEFAULT NULL, x_bank_id OUT NUMBER, x_bank_branch_id OUT NUMBER, x_bank_account_id OUT NUMBER, x_receipt_source_id OUT NUMBER, x_receipt_method_id OUT NUMBER
                                  , x_receipt_writeoff_id OUT NUMBER, x_ret_code OUT NUMBER, x_ret_message OUT VARCHAR2)
    IS
        ln_bank_id           NUMBER;
        ln_bank_branch_id    NUMBER;
        ln_bank_account_id   NUMBER;
        ln_ret_code          NUMBER;
        lv_ret_message       VARCHAR2 (2000);
        lv_writeoff_id       VARCHAR2 (100);
        lv_bank_id           VARCHAR2 (100);
        lv_branch_id         VARCHAR2 (100);
        lv_account_id        VARCHAR2 (100);
        lv_source_id         VARCHAR2 (100);
        lv_method_id         VARCHAR2 (100);
        lv_proc_name         VARCHAR2 (30) := 'GET_RECEIPT_METHOD';
    BEGIN
        print_log (
               'Inside get_receipt_method - '
            || 'p_org_id='
            || TO_CHAR (p_org_id)
            || 'p_payment_type='
            || p_payment_type
            || 'p_currency_code='
            || p_currency_code
            || 'p_lockbox_number='
            || p_lockbox_number);

        SELECT TO_NUMBER (ffv.attribute10)                 --Receipt Method ID
                                          , TO_NUMBER (ffv.attribute9) --AR Batch Source ID
                                                                      , TO_NUMBER (ffv.attribute2) --BANK ID
                                                                                                  ,
               TO_NUMBER (ffv.attribute3)                     --BANK BRANCH ID
                                         , TO_NUMBER (ffv.attribute4) --BANK ACCOUNT ID
                                                                     , TO_NUMBER (ffv.attribute11) --Receivables Trx ID for WRITEOFF
          INTO lv_method_id, lv_source_id, lv_bank_id, lv_branch_id,
                           lv_account_id, lv_writeoff_id
          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values ffv
         WHERE     1 = 1
               AND ffvs.flex_value_set_id = ffv.flex_value_set_id
               AND ffv.enabled_flag = 'Y'
               AND NVL (ffv.start_date_active, SYSDATE) <= SYSDATE
               AND NVL (ffv.end_date_active, SYSDATE + 1) > SYSDATE
               AND ffvs.flex_value_set_name = 'XXDOAR_B2B_RECEIPT_METHODS_VS'
               AND ffv.attribute1 = TO_CHAR (p_org_id)
               --AND ffv.attribute2 = TO_CHAR (p_bank_id)
               --AND ffv.attribute3 = TO_CHAR (p_bank_branch_id)
               --AND ffv.attribute4 = TO_CHAR (p_bank_account_id)
               AND ffv.attribute5 = p_currency_code
               AND NVL (ffv.attribute6, 'XXX') = NVL (p_payment_type, 'XXX')
               AND NVL (ffv.attribute8, 'XXX') =
                   NVL (p_lockbox_number, 'XXX');

        IF lv_method_id IS NOT NULL
        THEN
            x_receipt_method_id   := TO_NUMBER (lv_method_id);
        END IF;

        IF lv_source_id IS NOT NULL
        THEN
            x_receipt_source_id   := TO_NUMBER (lv_source_id);
        END IF;

        IF lv_bank_id IS NOT NULL
        THEN
            x_bank_id   := TO_NUMBER (lv_bank_id);
        END IF;

        IF lv_branch_id IS NOT NULL
        THEN
            x_bank_branch_id   := TO_NUMBER (lv_branch_id);
        END IF;

        IF lv_account_id IS NOT NULL
        THEN
            x_bank_account_id   := TO_NUMBER (lv_account_id);
        END IF;

        IF lv_writeoff_id IS NOT NULL
        THEN
            x_receipt_writeoff_id   := TO_NUMBER (lv_writeoff_id);
        END IF;

        print_log (
               'x_receipt_method_id='
            || TO_CHAR (x_receipt_method_id)
            || 'x_receipt_source_id='
            || TO_CHAR (x_receipt_source_id)
            || 'x_bank_id='
            || TO_CHAR (x_bank_id)
            || 'x_bank_branch_id='
            || TO_CHAR (x_bank_branch_id)
            || 'x_bank_account_id='
            || TO_CHAR (x_bank_account_id)
            || 'x_receipt_writeoff_id='
            || TO_CHAR (x_receipt_writeoff_id));
        x_ret_code      := gn_success;
        x_ret_message   := NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_receipt_method_id   := NULL;
            x_ret_code            := gn_error;
            x_ret_message         :=
                ' Error in get_receipt_method - ' || SQLERRM;
            print_log (x_ret_message, 'N', 1);
    END get_receipt_method;

    ----
    ----
    ---- Procedure to Get Job ID details
    ----
    PROCEDURE get_jobid_details (p_bt_job_id IN VARCHAR2, x_default_payment_type OUT VARCHAR2, x_default_currency OUT VARCHAR2
                                 , x_default_org_id OUT NUMBER--,x_receipt_source_id    OUT  NUMBER
                                                              --,x_default_bank_acc_id  OUT  NUMBER
                                                              , x_ret_code OUT NUMBER, x_ret_message OUT VARCHAR2)
    IS
        lv_err_msg        VARCHAR2 (2000) := NULL;
        ln_job_id_count   NUMBER := 0;
        lv_proc_name      VARCHAR2 (30) := 'GET_JOBID_DETAILS';
    BEGIN
        print_log (
            'Inside get_jobid_details - ' || 'p_bt_job_id=' || p_bt_job_id);

        SELECT ffv.attribute1                                   --payment type
                             , ffv.attribute2                  --currency code
                                             , TO_NUMBER (ffv.attribute5) --Operating Unit ID
          --, TO_NUMBER(ffv.attribute3) --Receipt Source ID
          --, TO_NUMBER (ffv.attribute4) --Default Bank Account ID
          INTO x_default_payment_type, x_default_currency, x_default_org_id
          --, x_receipt_source_id
          --, x_default_bank_acc_id
          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values ffv
         WHERE     1 = 1
               AND ffvs.flex_value_set_id = ffv.flex_value_set_id
               AND ffvs.flex_value_set_name =
                   'XXDOAR_B2B_CASHAPP_BT_JOBID_VS'
               AND ffv.enabled_flag = 'Y'
               AND NVL (ffv.start_date_active, SYSDATE) <= SYSDATE
               AND NVL (ffv.end_date_active, SYSDATE + 1) > SYSDATE
               AND ffv.flex_value = p_bt_job_id;

        x_ret_code      := gn_success;
        x_ret_message   := NULL;
        print_log (
               'x_default_payment_type='
            || x_default_payment_type
            || 'x_default_currency='
            || x_default_currency
            || 'x_default_org_id='
            || TO_CHAR (x_default_org_id));
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code      := gn_error;
            x_ret_message   := ' Error in get_jobid_details - ' || SQLERRM;
            print_log (x_ret_message, 'N', 1);
    END get_jobid_details;

    ----
    ----
    ---- Procedure to get the batch type
    ----
    PROCEDURE get_batch_type (p_batch_source_id IN NUMBER, x_batch_type OUT VARCHAR2, x_ret_code OUT NUMBER
                              , x_ret_message OUT VARCHAR2)
    IS
        lv_proc_name   VARCHAR2 (30) := 'GET_BATCH_TYPE';
    BEGIN
        print_log (
               'Inside get_batch_type - '
            || 'p_batch_source_id='
            || TO_CHAR (p_batch_source_id));

        SELECT TYPE
          INTO x_batch_type
          FROM ar_batch_sources_all
         WHERE 1 = 1 AND batch_source_id = p_batch_source_id;

        x_ret_code      := gn_success;
        x_ret_message   := NULL;
        print_log ('x_batch_type=' || x_batch_type);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code      := gn_error;
            x_ret_message   := ' Error in get_batch_type - ' || SQLERRM;
            print_log (x_ret_message, 'N', 1);
    END get_batch_type;

    ----
    ----
    ---- Procedure to get primary bill to site use id
    ----
    PROCEDURE get_site_use (p_customer_id IN NUMBER, p_org_id IN NUMBER, p_site_use_code IN VARCHAR2
                            , x_site_use_id OUT NUMBER, x_ret_code OUT NUMBER, x_ret_message OUT VARCHAR2)
    IS
        lv_proc_name   VARCHAR2 (30) := 'GET_SITE_USE';
    BEGIN
        /*
        SELECT hcsu.site_use_id
          INTO x_site_use_id
          FROM apps.hz_cust_accounts hca
             , apps.hz_cust_acct_sites_all hcas
             , apps.hz_cust_site_uses_all hcsu
         WHERE 1=1
           AND hca.cust_account_id = hcas.cust_account_id
           AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
           AND hcsu.primary_flag = 'Y'
           AND hcsu.site_use_code = p_site_use_code--'BILL_TO'
           AND hca.status = 'A'
           AND hcas.status = 'A'
           AND hcsu.status = 'A'
           AND hcas.org_id = p_org_id
           AND hca.cust_account_id = p_customer_id
           ;
        */
        SELECT hcsu.site_use_id
          INTO x_site_use_id
          FROM apps.hz_cust_acct_sites_all hcas, apps.hz_cust_site_uses_all hcsu
         WHERE     1 = 1
               AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
               AND hcsu.primary_flag = 'Y'
               AND hcsu.site_use_code = p_site_use_code
               AND ((hcsu.site_use_code = 'BILL_TO' AND hcas.bill_to_flag = 'P') OR (hcsu.site_use_code = 'SHIP_TO' AND hcas.ship_to_flag = 'P'))
               AND hcas.status = 'A'
               AND hcsu.status = 'A'
               AND hcas.org_id = p_org_id
               AND hcsu.org_id = p_org_id
               AND hcas.cust_account_id = p_customer_id;

        x_ret_code      := gn_success;
        x_ret_message   := NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code      := gn_error;
            x_ret_message   := ' Error in get_site_use - ' || SQLERRM;
            print_log (x_ret_message, 'N', 1);
    END get_site_use;

    ----
    ----
    ---- Procedure to get receivable application id
    ----
    PROCEDURE get_receivable_app_id (p_org_id IN NUMBER, p_cash_receipt_id IN NUMBER, p_customer_trx_id IN NUMBER
                                     , x_receivable_app_id OUT NUMBER, x_ret_code OUT NUMBER, x_ret_message OUT VARCHAR2)
    IS
        lv_proc_name   VARCHAR2 (30) := 'GET_RECEIVABLE_APP_ID';
    BEGIN
        SELECT receivable_application_id
          INTO x_receivable_app_id
          FROM ar_receivable_applications_all
         WHERE     1 = 1
               AND status = 'APP'
               AND display = 'Y'
               AND applied_customer_trx_id = p_customer_trx_id
               AND org_id = p_org_id
               AND cash_receipt_id = p_cash_receipt_id;

        x_ret_code   := gn_success;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code   := gn_error;
            x_ret_message   :=
                ' Error in get_receivable_app_id - ' || SQLERRM;
            print_log (x_ret_message, 'N', 1);
    END get_receivable_app_id;

    PROCEDURE validate_invoice_balance (p_customer_trx_id   IN     NUMBER,
                                        p_applied_amount    IN     NUMBER,
                                        x_status               OUT VARCHAR2,
                                        x_ret_code             OUT NUMBER,
                                        x_ret_message          OUT VARCHAR2)
    IS
        ln_amt_due_rem   NUMBER;
        lv_proc_name     VARCHAR2 (30) := 'VALIDATE_INVOICE_BALANCE';
    BEGIN
        SELECT NVL (amount_due_remaining, 0)
          INTO ln_amt_due_rem
          FROM ar_payment_schedules_all
         WHERE 1 = 1 AND customer_trx_id = p_customer_trx_id;

        IF ln_amt_due_rem >= p_applied_amount
        THEN
            x_status   := 'VALID';
        ELSE
            x_status     := 'INVALID';
            x_ret_code   := gn_error;
            x_ret_message   :=
                   'Amount Due Remaining on Invoice = '
                || TO_CHAR (NVL (ln_amt_due_rem, 0))
                || ' is less than the amount being applied '
                || TO_CHAR (NVL (p_applied_amount, 0));
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_status     := 'INVALID';
            x_ret_code   := gn_error;
            x_ret_message   :=
                'Error in validate_invoice_balance - ' || SQLERRM;
    END validate_invoice_balance;

    ----
    ----
    ---- Procedure to validate customer relationship
    ----
    PROCEDURE validate_customer_relation (p_customer_id IN NUMBER, p_customer_trx_id IN NUMBER, x_ret_code OUT NUMBER
                                          , x_ret_message OUT VARCHAR2)
    IS
        ln_count       NUMBER := 0;
        lv_proc_name   VARCHAR2 (30) := 'VALIDATE_CUSTOMER_RELATION';
    BEGIN
        BEGIN
            SELECT COUNT (1)
              INTO ln_count
              FROM hz_cust_accounts hca, ra_customer_trx_all rct
             WHERE     1 = 1
                   AND hca.cust_account_id = rct.bill_to_customer_id
                   AND rct.bill_to_customer_id = p_customer_id
                   AND rct.customer_trx_id = p_customer_trx_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_count   := 0;
        END;

        IF ln_count = 0
        THEN
            BEGIN
                SELECT COUNT (1)
                  INTO ln_count
                  FROM hz_cust_acct_relate_all hcar, ra_customer_trx_all rct
                 WHERE     1 = 1
                       AND hcar.cust_account_id = p_customer_id
                       AND hcar.related_cust_account_id =
                           rct.bill_to_customer_id
                       AND rct.customer_trx_id = p_customer_trx_id
                       AND hcar.status = 'A';
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_count   := 0;
            END;
        END IF;

        IF ln_count = 0
        THEN
            x_ret_message   :=
                ' Invalid Receipt Customer to Invoice Customer relationship ';
            x_ret_code   := gn_error;
        ELSE
            x_ret_code      := gn_success;
            x_ret_message   := NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code   := gn_error;
            x_ret_message   :=
                'Error in validate_customer_relation - ' || SQLERRM;
    END validate_customer_relation;

    ----
    ----
    ---- Procedure to validate customer relationship
    ----
    PROCEDURE validate_customer_relation (p_customer_id      IN     NUMBER,
                                          p_receipt_number   IN     VARCHAR2,
                                          p_org_id           IN     NUMBER,
                                          x_ret_code            OUT NUMBER,
                                          x_ret_message         OUT VARCHAR2)
    IS
        ln_count       NUMBER := 0;
        lv_proc_name   VARCHAR2 (30) := 'VALIDATE_CUSTOMER_RELATION';
    BEGIN
        BEGIN
            SELECT COUNT (1)
              INTO ln_count
              FROM hz_cust_accounts hca, ar_cash_receipts_all acr
             WHERE     1 = 1
                   AND acr.org_id = p_org_id
                   AND hca.cust_account_id = acr.pay_from_customer
                   AND acr.pay_from_customer = p_customer_id
                   AND acr.receipt_number = p_receipt_number;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_count   := 0;
        END;

        IF ln_count = 0
        THEN
            BEGIN
                SELECT COUNT (1)
                  INTO ln_count
                  FROM hz_cust_acct_relate_all hcar, ar_cash_receipts_all acr
                 WHERE     1 = 1
                       AND hcar.cust_account_id = p_customer_id
                       AND hcar.related_cust_account_id =
                           acr.pay_from_customer
                       AND acr.receipt_number = p_receipt_number
                       AND hcar.status = 'A';
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_count   := 0;
            END;
        END IF;

        IF ln_count = 0
        THEN
            x_ret_message   :=
                ' Invalid Receipt Customer to Receipt Customer relationship ';
            x_ret_code   := gn_error;
        ELSE
            x_ret_code      := gn_success;
            x_ret_message   := NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code   := gn_error;
            x_ret_message   :=
                ' Error in validate_customer_relation2 - ' || SQLERRM;
    END validate_customer_relation;

    ----
    ----
    ---- Function to Check if the Reason Code is Excluded
    ----
    FUNCTION excluded_reason (p_reason_code IN VARCHAR2)
        RETURN BOOLEAN
    IS
        ln_count   NUMBER := 0;
    BEGIN
        SELECT COUNT (1)
          INTO ln_count
          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values ffv
         WHERE     1 = 1
               AND ffvs.flex_value_set_id = ffv.flex_value_set_id
               AND ffvs.flex_value_set_name =
                   'XXDOAR_B2B_BT_EXCLUDED_REASON_CODES_VS'
               AND ffv.enabled_flag = 'Y'
               AND NVL (ffv.start_date_active, SYSDATE) <= SYSDATE
               AND NVL (ffv.end_date_active, SYSDATE) >= SYSDATE
               AND UPPER (ffv.flex_value) = UPPER (p_reason_code);

        IF ln_count > 0
        THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    EXCEPTION
        WHEN TOO_MANY_ROWS
        THEN
            RETURN TRUE;
        WHEN OTHERS
        THEN
            RETURN FALSE;
    END excluded_reason;

    ----
    ----
    ---- Procedure to get reason code id
    ---- takes the BT deduction code
    PROCEDURE get_reason_code_id (p_org_id IN NUMBER, p_reason_code IN VARCHAR2, p_amount IN NUMBER
                                  , x_reason_code_id OUT NUMBER, x_ret_code OUT NUMBER, x_ret_message OUT VARCHAR2)
    IS
        lv_proc_name   VARCHAR2 (30) := 'GET_REASON_CODE_ID';
    BEGIN
        print_log (
            ' p_org_id=' || p_org_id || ' p_reason_code=' || p_reason_code);

        BEGIN
            SELECT ffv.attribute2                      --Oracle Reason Code ID
              INTO x_reason_code_id
              FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values ffv
             WHERE     1 = 1
                   AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                   AND ffvs.flex_value_set_name =
                       'XXDOAR_B2B_REASON_CODES_VS'
                   AND ffv.enabled_flag = 'Y'
                   AND ffv.attribute3 = p_reason_code
                   AND TO_NUMBER (ffv.attribute1) = p_org_id
                   AND NVL (ffv.start_date_active, SYSDATE) <= SYSDATE
                   AND NVL (ffv.end_date_active, SYSDATE + 1) > SYSDATE;
        EXCEPTION
            WHEN OTHERS
            THEN
                x_reason_code_id   := NULL;
        END;

        IF x_reason_code_id IS NULL
        THEN
            BEGIN
                IF p_amount < 0
                THEN
                    SELECT ffv.attribute2              --Oracle Reason Code ID
                      INTO x_reason_code_id
                      FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values ffv
                     WHERE     1 = 1
                           AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                           AND ffvs.flex_value_set_name =
                               'XXDOAR_B2B_REASON_CODES_VS'
                           AND ffv.enabled_flag = 'Y'
                           --AND ffv.attribute3 = p_reason_code
                           AND NVL (ffv.attribute4, 'N') = 'Y' --Deduction Default Flag
                           AND TO_NUMBER (ffv.attribute1) = p_org_id
                           AND NVL (ffv.start_date_active, SYSDATE) <=
                               SYSDATE
                           AND NVL (ffv.end_date_active, SYSDATE + 1) >
                               SYSDATE;
                ELSE
                    SELECT ffv.attribute2              --Oracle Reason Code ID
                      INTO x_reason_code_id
                      FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values ffv
                     WHERE     1 = 1
                           AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                           AND ffvs.flex_value_set_name =
                               'XXDOAR_B2B_REASON_CODES_VS'
                           AND ffv.enabled_flag = 'Y'
                           --AND ffv.attribute3 = p_reason_code
                           AND NVL (ffv.attribute5, 'N') = 'Y'
                           --Overpayment Default Flag
                           AND TO_NUMBER (ffv.attribute1) = p_org_id
                           AND NVL (ffv.start_date_active, SYSDATE) <=
                               SYSDATE
                           AND NVL (ffv.end_date_active, SYSDATE + 1) >
                               SYSDATE;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_reason_code_id   := NULL;
            END;
        END IF;

        print_log (' x_reason_code_id=' || x_reason_code_id, 'N', 1);

        IF x_reason_code_id IS NULL
        THEN
            x_ret_code   := gn_error;
            x_ret_message   :=
                'Deduction Code:"' || p_reason_code || '" not found.';
        ELSE
            x_ret_code   := gn_success;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code      := gn_error;
            x_ret_message   := ' Error in get_reason_code_id - ' || SQLERRM;
            print_log (x_ret_message, 'Y', 2);
    END get_reason_code_id;

    ----
    ----
    ---- Procedure to get receivables trxid
    ---- used for claim investigation creation
    PROCEDURE get_receivables_trx_id (p_customer_id IN NUMBER, p_org_id IN NUMBER, p_type IN VARCHAR2 DEFAULT 'CLAIM_INVESTIGATION'
                                      , x_receivables_trx_id OUT NUMBER, x_ret_code OUT NUMBER, x_ret_message OUT VARCHAR2)
    IS
        lv_brand                VARCHAR2 (30);
        ln_receivables_trx_id   NUMBER;
        lv_proc_name            VARCHAR2 (30) := 'GET_RECEIVABLES_TRX_ID';
    BEGIN
        print_log (
               ' p_org_id='
            || p_org_id
            || ' p_customer_id='
            || p_customer_id
            || ' p_type='
            || p_type);

        BEGIN
            SELECT attribute1
              INTO lv_brand
              FROM hz_cust_accounts
             WHERE 1 = 1 AND cust_account_id = p_customer_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_brand   := NULL;
        END;

        print_log ('lv_brand=' || lv_brand, 'N', 1);

        IF NVL (lv_brand, 'ALL BRAND') <> 'ALL BRAND'
        THEN
            SELECT receivables_trx_id
              INTO x_receivables_trx_id
              FROM ar_receivables_trx_all
             WHERE     org_id = p_org_id                              --ORG_ID
                   AND status = 'A'
                   AND NVL (start_date_active, SYSDATE) <= SYSDATE
                   AND NVL (end_date_active, SYSDATE + 1) > SYSDATE
                   AND TYPE = p_type
                   AND UPPER (NAME) LIKE UPPER (lv_brand || '%');
        ELSE
            SELECT receivables_trx_id
              INTO x_receivables_trx_id
              FROM ar_receivables_trx_all
             WHERE     org_id = p_org_id                              --ORG_ID
                   AND status = 'A'
                   AND NVL (start_date_active, SYSDATE) <= SYSDATE
                   AND NVL (end_date_active, SYSDATE + 1) > SYSDATE
                   AND TYPE = p_type
                   AND UPPER (NAME) LIKE UPPER ('DECKERS' || '%');
        END IF;

        IF x_receivables_trx_id IS NOT NULL
        THEN
            x_ret_code   := gn_success;
        ELSE
            x_ret_message   := gn_error;
            x_ret_message   := ' Error getting receivables_trx_id ';
        END IF;

        print_log (' x_receivables_trx_id=' || x_receivables_trx_id, 'N', 1);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code   := gn_error;
            x_ret_message   :=
                ' Error in get_receivables_trx_id - ' || SQLERRM;
            print_log (x_ret_message, 'Y', 2);
    END get_receivables_trx_id;

    /*Added for B2B Phase 2 EMEA Changes(CCR0006692) - START*/
    ----
    ----
    ---- Procedure to get receivables trxid
    ---- used for claim investigation creation
    PROCEDURE get_receivables_trx_id2 (p_customer_id IN NUMBER, p_org_id IN NUMBER, p_type IN VARCHAR2 DEFAULT 'CLAIM_INVESTIGATION'
                                       , x_receivables_trx_id OUT NUMBER, x_ret_code OUT NUMBER, x_ret_message OUT VARCHAR2)
    IS
        lv_brand                VARCHAR2 (30);
        ln_receivables_trx_id   NUMBER;
        lv_proc_name            VARCHAR2 (30) := 'GET_RECEIVABLES_TRX_ID2';
    BEGIN
        print_log (
               ' p_org_id='
            || p_org_id
            || ' p_customer_id='
            || p_customer_id
            || ' p_type='
            || p_type);

        BEGIN
            SELECT attribute1
              INTO lv_brand
              FROM hz_cust_accounts
             WHERE 1 = 1 AND cust_account_id = p_customer_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_brand   := NULL;
        END;

        print_log ('lv_brand=' || lv_brand, 'N', 1);

        BEGIN
            SELECT t.receivables_trx_id
              INTO x_receivables_trx_id
              FROM apps.fnd_flex_value_sets s, apps.fnd_flex_values_vl v, apps.ar_receivables_trx_all t
             WHERE     1 = 1
                   AND s.flex_value_set_id = v.flex_value_set_id
                   AND s.flex_value_set_name = 'XXDOAR_B2B_BRAND_TRX_MAP_VS'
                   AND v.enabled_flag = 'Y'
                   AND NVL (v.start_date_active, SYSDATE) <= SYSDATE
                   AND NVL (v.end_date_active, SYSDATE + 1) > SYSDATE
                   AND t.status = 'A'
                   AND t.TYPE = p_type
                   AND v.attribute1 = p_org_id
                   AND v.attribute2 = lv_brand
                   AND t.receivables_trx_id = v.attribute3;
        EXCEPTION
            WHEN OTHERS
            THEN
                x_receivables_trx_id   := NULL;
        END;

        IF x_receivables_trx_id IS NULL
        THEN
            BEGIN
                SELECT t.receivables_trx_id
                  INTO x_receivables_trx_id
                  FROM apps.fnd_flex_value_sets s, apps.fnd_flex_values_vl v, apps.ar_receivables_trx_all t
                 WHERE     1 = 1
                       AND s.flex_value_set_id = v.flex_value_set_id
                       AND s.flex_value_set_name =
                           'XXDOAR_B2B_BRAND_TRX_MAP_VS'
                       AND v.enabled_flag = 'Y'
                       AND NVL (v.start_date_active, SYSDATE) <= SYSDATE
                       AND NVL (v.end_date_active, SYSDATE + 1) > SYSDATE
                       AND t.status = 'A'
                       AND t.TYPE = p_type
                       AND v.attribute1 = p_org_id
                       AND v.attribute2 = 'ALL BRAND'               --lv_brand
                       AND t.receivables_trx_id = v.attribute3;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_receivables_trx_id   := NULL;
            END;
        END IF;

        IF x_receivables_trx_id IS NOT NULL
        THEN
            x_ret_code   := gn_success;
        ELSE
            x_ret_message   := gn_error;
            x_ret_message   := ' Error getting receivables_trx_id ';
        END IF;

        print_log (' x_receivables_trx_id=' || x_receivables_trx_id, 'N', 1);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code   := gn_error;
            x_ret_message   :=
                ' Error in get_receivables_trx_id2 - ' || SQLERRM;
            print_log (x_ret_message, 'Y', 2);
    END get_receivables_trx_id2;

    /*Added for B2B Phase 2 EMEA Changes(CCR0006692) - END*/
    ----
    ----
    ---- Procedure to get claim type id
    ----
    PROCEDURE get_claim_type_id (p_customer_id IN NUMBER, p_org_id IN NUMBER, p_reason_code_id IN NUMBER
                                 , x_claim_type_id OUT VARCHAR2, x_ret_code OUT NUMBER, x_ret_message OUT VARCHAR2)
    IS
        lv_brand           VARCHAR2 (30);
        ln_claim_type_id   NUMBER;
        lv_reason_code     VARCHAR2 (60);
        lv_proc_name       VARCHAR2 (30) := 'GET_CLAIM_TYPE_ID';
    BEGIN
        print_log (
               ' p_org_id='
            || p_org_id
            || ' p_customer_id='
            || p_customer_id
            || ' p_reason_code_id='
            || p_reason_code_id);

        BEGIN
            SELECT attribute1
              INTO lv_brand
              FROM hz_cust_accounts
             WHERE 1 = 1 AND cust_account_id = p_customer_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_brand   := NULL;
        END;

        /*
        BEGIN
          SELECT name
            INTO lv_reason_code
            FROM apps.ozf_reason_codes_all_tl
           WHERE 1=1
             AND language = 'US'
             AND org_id = p_org_id
             AND reason_code_id = p_reason_code_id;
        EXCEPTION
          WHEN OTHERS THEN
            lv_reason_code := NULL;
        END; */
        IF lv_brand IS NOT NULL AND p_reason_code_id IS NOT NULL
        THEN
            BEGIN
                /*
                SELECT claim_type_id
                  INTO x_claim_type_id
                  FROM apps.ozf_claim_types_all_tl
                 WHERE 1=1
                   AND language = 'US'
                   AND org_id = p_org_id
                   AND UPPER(name) like UPPER('%'||lv_brand||'%'||lv_reason_code||'%');
                */
                SELECT oct.claim_type_id
                  INTO x_claim_type_id
                  FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values ffv, apps.ozf_claim_types_all_vl oct,
                       apps.ozf_reason_codes_all_vl orc
                 WHERE     1 = 1
                       AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                       AND ffvs.flex_value_set_name =
                           'XXDOAR_B2B_CLAIM_TYPE_MAP_VS'
                       AND ffv.attribute1 = TO_CHAR (p_org_id)
                       AND ffv.attribute3 = orc.NAME
                       AND orc.org_id = p_org_id
                       AND orc.reason_code_id = p_reason_code_id
                       AND ffv.attribute2 = lv_brand
                       AND ffv.attribute4 = oct.NAME
                       AND oct.org_id = p_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_claim_type_id   := NULL;
                    x_ret_code        := gn_error;
                    x_ret_message     :=
                        ' Error getting claim_type_id - ' || SQLERRM;
            END;
        ELSE
            x_claim_type_id   := NULL;
            x_ret_code        := gn_error;
            x_ret_message     := ' Error Calim Type.';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code      := gn_error;
            x_ret_message   := ' Error in get_claim_type_id - ' || SQLERRM;
            print_log (x_ret_message, 'Y', 2);
    END get_claim_type_id;

    ----
    ----
    ---- Function to get OnAccount Balance of a receipt
    ----
    FUNCTION get_onaccount (p_org_id           IN NUMBER,
                            p_customer_id      IN NUMBER,
                            p_receipt_number   IN VARCHAR2)
        RETURN NUMBER
    IS
        ln_onaccount_amt   NUMBER;
        lv_proc_name       VARCHAR2 (60) := 'GET_ONACCOUNT';
    BEGIN
        SELECT SUM (ra.amount_applied) onaccount_amount
          --, (ps.amount_due_remaining)
          INTO ln_onaccount_amt
          FROM apps.ar_cash_receipts_all cr, apps.ar_receivable_applications_all ra
         WHERE     1 = 1
               AND cr.cash_receipt_id = ra.cash_receipt_id
               AND ra.display = 'Y'
               AND ra.status = 'ACC'
               AND ra.applied_payment_schedule_id = -1
               AND cr.org_id = p_org_id
               AND cr.receipt_number = p_receipt_number
               AND cr.pay_from_customer = p_customer_id;

        RETURN ln_onaccount_amt;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END get_onaccount;

    ----
    ----
    ---- Function to get Unapplied Balance of a receipt
    ----
    FUNCTION get_unapplied (p_org_id           IN NUMBER,
                            p_customer_id      IN NUMBER,
                            p_receipt_number   IN VARCHAR2)
        RETURN NUMBER
    IS
        ln_unapplied_amt   NUMBER;
        lv_proc_name       VARCHAR2 (60) := 'GET_UNAPPLIED';
    BEGIN
        SELECT SUM (ra.amount_applied) unapplied_amount
          --, (ps.amount_due_remaining)
          INTO ln_unapplied_amt
          FROM apps.ar_cash_receipts_all cr, apps.ar_receivable_applications_all ra
         WHERE     1 = 1
               AND cr.cash_receipt_id = ra.cash_receipt_id
               AND ra.display != 'Y'
               AND ra.status = 'UNAPP'
               AND cr.org_id = p_org_id
               AND cr.receipt_number = p_receipt_number
               AND cr.pay_from_customer = p_customer_id;

        RETURN ln_unapplied_amt;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END get_unapplied;

    ----
    ----
    ---- Procedure to Create Receipt Batches
    ----
    PROCEDURE create_receipt_batch (
        p_org_id               IN     NUMBER,
        p_batch_source_id      IN     NUMBER,
        p_bank_branch_id       IN     NUMBER,
        p_batch_type           IN     VARCHAR2,
        p_currency_code        IN     VARCHAR2,
        p_bank_account_id      IN     VARCHAR2,
        p_batch_date           IN     DATE,
        p_receipt_class_id     IN     NUMBER,
        p_control_count        IN     NUMBER,
        p_gl_date              IN     DATE,
        p_receipt_method_id    IN     NUMBER,
        p_control_amount       IN     NUMBER,
        p_deposit_date         IN     DATE,
        p_lockbox_batch_name   IN     VARCHAR2,
        p_comments             IN     VARCHAR2,
        p_auto_commit          IN     VARCHAR2 := 'Y',
        x_batch_id                OUT NUMBER,
        x_batch_name              OUT VARCHAR2,
        x_ret_code                OUT NUMBER,
        x_ret_message             OUT VARCHAR2)
    IS
        l_organization_id          NUMBER;
        l_set_of_books_id          NUMBER;
        l_field                    VARCHAR2 (70);
        l_remit_bank_acct_use_id   NUMBER;
        ex_create_receipt_batch    EXCEPTION;
        ex_increment_batch_name    EXCEPTION;
        --PRAGMA                   AUTONOMOUS_TRANSACTION;
        lv_proc_name               VARCHAR2 (30) := 'CREATE_RECEIPT_BATCH';
    BEGIN
        print_log (
               'Inside '
            || lv_proc_name
            || ' - '
            || ' p_org_id='
            || TO_CHAR (p_org_id)
            || ' p_Batch_Source_ID='
            || TO_CHAR (p_batch_source_id)
            || ' p_Bank_Branch_ID='
            || TO_CHAR (p_bank_branch_id)
            || ' p_Batch_Type='
            || p_batch_type
            || ' p_Currency_Code='
            || p_currency_code
            || ' p_Bank_Account_ID='
            || TO_CHAR (p_bank_account_id)
            || ' p_Batch_Date='
            || TO_CHAR (p_batch_date, 'DD-MON-YYYY')
            || ' p_Receipt_Class_ID='
            || TO_CHAR (p_receipt_class_id)
            || ' p_Control_Count='
            || TO_CHAR (p_control_count)
            || ' p_Receipt_Method_ID='
            || TO_CHAR (p_receipt_method_id));
        --print_log('1.0','N',1);
        l_field   := 'batch_id';

        SELECT ar_batches_s.NEXTVAL INTO x_batch_id FROM DUAL;

        --print_log('2.0','N',1);
        l_field   := 'organization_id or set_of_books_id';

        SELECT organization_id, set_of_books_id
          INTO l_organization_id, l_set_of_books_id
          FROM hr_operating_units
         WHERE     organization_id = p_org_id
               AND NVL (date_from, SYSDATE) <= SYSDATE
               AND NVL (date_to, SYSDATE) > TRUNC (SYSDATE - 1);

        --print_log('3.0','N',1);
        l_field   := 'name';

        SELECT last_batch_num + 1
          INTO x_batch_name
          FROM ar_batch_sources_all
         WHERE     batch_source_id = p_batch_source_id
               AND NVL (start_date_active, SYSDATE) <= SYSDATE
               AND NVL (end_date_active, SYSDATE) > TRUNC (SYSDATE - 1);

        --print_log('4.0','N',1);
        l_field   := 'remit_bank_acct_use_id';

        SELECT remit_bank_acct_use_id
          INTO l_remit_bank_acct_use_id
          FROM ar_receipt_method_accounts_all
         WHERE     receipt_method_id = p_receipt_method_id
               AND org_id = p_org_id
               AND NVL (start_date, SYSDATE) <= SYSDATE
               AND NVL (end_date, SYSDATE) > TRUNC (SYSDATE - 1)
               AND primary_flag = 'Y';

        --print_log('5.0');
        INSERT INTO ar_batches_all (batch_id, last_updated_by, last_update_date, last_update_login, created_by, creation_date, NAME, batch_date, gl_date, status, deposit_date, TYPE, batch_source_id, control_count, control_amount, batch_applied_status, currency_code, comments, receipt_method_id, receipt_class_id, remittance_bank_branch_id, remittance_bank_account_id, remit_bank_acct_use_id, set_of_books_id
                                    , org_id, lockbox_batch_name)
             VALUES (x_batch_id, apps.fnd_global.user_id, SYSDATE,
                     apps.fnd_global.user_id, apps.fnd_global.user_id, SYSDATE, x_batch_name, TRUNC (p_batch_date), TRUNC (p_gl_date), 'NB', TRUNC (p_deposit_date), p_batch_type, p_batch_source_id, p_control_count, p_control_amount, 'PROCESSED', p_currency_code, p_comments, p_receipt_method_id, p_receipt_class_id, p_bank_branch_id, p_bank_account_id, l_remit_bank_acct_use_id, l_set_of_books_id
                     , l_organization_id, p_lockbox_batch_name);

        IF SQL%ROWCOUNT != 1
        THEN
            RAISE ex_create_receipt_batch;
        ELSE
            /*increment batch name - does not do automatically */
            UPDATE ar_batch_sources_all
               SET last_batch_num   = last_batch_num + 1
             WHERE batch_source_id = p_batch_source_id;

            IF SQL%ROWCOUNT != 1
            THEN
                RAISE ex_increment_batch_name;
            END IF;

            IF NVL (p_auto_commit, 'Y') = 'Y'
            THEN
                COMMIT;
            END IF;

            print_log (
                   ' x_Batch_ID='
                || TO_CHAR (x_batch_id)
                || ' x_Batch_Name='
                || TO_CHAR (x_batch_name));
        END IF;
    EXCEPTION
        WHEN ex_create_receipt_batch
        THEN
            x_batch_id     := -1;
            x_batch_name   := NULL;
            x_ret_code     := gn_error;
            x_ret_message   :=
                   'Unable to create receipt batch. The Error was:'
                || ' '
                || SQLERRM;
            print_log (x_ret_message, 'Y', 1);
        WHEN ex_increment_batch_name
        THEN
            x_batch_id     := -1;
            x_batch_name   := NULL;
            x_ret_code     := gn_error;
            x_ret_message   :=
                ' Error incrementing batch name in CREATE_RECEIPT_BATCH';
            print_log (x_ret_message, 'Y', 1);
        WHEN NO_DATA_FOUND
        THEN
            x_batch_id     := -1;
            x_batch_name   := NULL;
            x_ret_code     := gn_error;
            x_ret_message   :=
                'No data found when attempting to populate : ' || l_field;
            print_log (x_ret_message, 'Y', 1);
        WHEN OTHERS
        THEN
            x_batch_id     := -1;
            x_batch_name   := NULL;
            x_ret_code     := gn_error;
            x_ret_message   :=
                   'Error in CREATE_RECEIPT_BATCH. '
                || l_field
                || ' '
                || SQLERRM;
            print_log (x_ret_message, 'Y', 1);
    END create_receipt_batch;

    ----
    ----
    ---- Procedure to Create Receipts
    ---- calls the public API AR_RECEIPT_API_PUB
    PROCEDURE create_receipt (
        p_batch_id                   IN     NUMBER,
        p_receipt_number             IN     VARCHAR2,
        p_receipt_amt                IN     NUMBER,
        p_transaction_num            IN     VARCHAR2 := apps.fnd_api.g_miss_char,
        p_customer_number            IN     VARCHAR2 := apps.fnd_api.g_miss_char,
        p_customer_name              IN     VARCHAR2 := apps.fnd_api.g_miss_char,
        p_customer_id                IN     NUMBER DEFAULT NULL,
        p_comments                   IN     VARCHAR2 := apps.fnd_api.g_miss_char,
        p_payment_server_order_num   IN     VARCHAR2 := apps.fnd_api.g_miss_char,
        p_currency_code              IN     VARCHAR2,
        p_location                   IN     VARCHAR2 := apps.fnd_api.g_miss_char,
        p_bill_to_site_use_id        IN     NUMBER DEFAULT NULL,
        p_receipt_date               IN     DATE DEFAULT NULL,
        p_exchange_rate_type         IN     VARCHAR2 DEFAULT NULL,
        p_exchange_rate              IN     NUMBER DEFAULT NULL,
        p_exchange_rate_date         IN     DATE DEFAULT NULL,
        p_auto_commit                IN     VARCHAR2 DEFAULT 'Y',
        x_cash_receipt_id               OUT NUMBER,
        x_ret_code                      OUT NUMBER,
        x_ret_message                   OUT VARCHAR2)
    IS
        l_return_status            VARCHAR2 (1);
        l_msg_count                NUMBER;
        l_msg_data                 VARCHAR2 (500);
        l_msg_output               VARCHAR2 (500) := NULL;
        l_msg_index_out            NUMBER;
        ex_create_receipt          EXCEPTION;
        l_remit_bank_acct_use_id   NUMBER;
        l_rcpt_date                DATE;
        l_gl_date                  DATE;
        l_rcpt_method_id           NUMBER;
        l_bank_acct_id             NUMBER;
        --PRAGMA                   AUTONOMOUS_TRANSACTION;
        lv_proc_name               VARCHAR2 (30) := 'CREATE_RECEIPT';
        ln_org_id                  NUMBER;
        ln_resp_id                 NUMBER;
        lv_comments                VARCHAR2 (2000);
    BEGIN
        print_log (
               'Inside '
            || lv_proc_name
            || ' - '
            || ' p_Batch_ID='
            || TO_CHAR (p_batch_id)
            || ' p_Receipt_Number='
            || p_receipt_number
            || ' p_Receipt_Amt='
            || TO_CHAR (p_receipt_amt)
            || ' p_Customer_Number='
            || p_customer_number
            || ' p_Comments='
            || p_comments
            || ' p_receipt_date='
            || TO_CHAR (p_receipt_date, 'DD-MON-YYYY'));

        IF NVL (p_receipt_amt, 0) < 0
        THEN
            print_log (' Negative payment detected.  Returning stub ID.',
                       'N',
                       1);
            x_cash_receipt_id   := lg_stub_cash_rcpt_id;
            x_ret_message       := NULL;
            RETURN;
        END IF;

        SAVEPOINT before_create_receipt;

        SELECT batch_date, gl_date, receipt_method_id,
               remit_bank_acct_use_id, org_id
          INTO l_rcpt_date, l_gl_date, l_rcpt_method_id, l_bank_acct_id,
                          ln_org_id
          FROM ar_batches_all
         WHERE batch_id = p_batch_id;

        ln_resp_id   := get_responsibility_id (ln_org_id);

        IF ln_resp_id IS NOT NULL
        THEN
            fnd_global.apps_initialize (
                user_id        => fnd_global.user_id,
                resp_id        => ln_resp_id,
                resp_appl_id   => fnd_global.resp_appl_id);
        END IF;

        mo_global.init ('AR');
        mo_global.set_policy_context ('S', ln_org_id);

        --Remove email+datestamp from comments
        IF p_comments IS NOT NULL
        THEN
            SELECT --regexp_replace(p_comments,'\[[^ ]+\]','') as txt
                   REGEXP_REPLACE (p_comments, '\[.+?\]\:') AS txt
              INTO lv_comments
              FROM DUAL;
        END IF;

        /*
        if fnd_global.org_id = 212 then
        l_bank_acct_id:= null;
        end if;
        */
        -- 1.0 : Commented for BT.
        ar_receipt_api_pub.create_cash (p_api_version => 1.0, p_init_msg_list => fnd_api.g_true, p_receipt_number => p_receipt_number, p_receipt_date => TRUNC (l_rcpt_date), p_amount => p_receipt_amt, p_gl_date => TRUNC (l_gl_date), p_receipt_method_id => l_rcpt_method_id, p_customer_receipt_reference => p_transaction_num, p_customer_id => p_customer_id, p_customer_number => p_customer_number, p_customer_site_use_id => p_bill_to_site_use_id, p_remittance_bank_account_id => l_bank_acct_id, p_currency_code => p_currency_code, p_location => p_location, p_comments => lv_comments--p_Comments
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     , p_cr_id => x_cash_receipt_id, p_exchange_rate_type => p_exchange_rate_type, p_exchange_rate => p_exchange_rate, p_exchange_rate_date => p_exchange_rate_date, x_return_status => l_return_status, x_msg_count => l_msg_count
                                        , x_msg_data => l_msg_data);

        IF l_return_status <> gv_ret_success
        THEN
            FOR i IN 1 .. l_msg_count
            LOOP
                x_ret_code   := gn_error;
                x_ret_message   :=
                       x_ret_message
                    || ' Error '
                    || i
                    || ' is: '
                    || ' '
                    || fnd_msg_pub.get (i, 'F');                 --X_MSG_DATA;
            END LOOP;

            RAISE ex_create_receipt;
        ELSE
            /* Create Receipt was sucessful, link receipt to batch */
            UPDATE ar_cash_receipt_history_all
               SET batch_id   = p_batch_id
             WHERE cash_receipt_id = x_cash_receipt_id;

            IF NVL (p_auto_commit, 'Y') = 'Y'
            THEN
                COMMIT;
            END IF;
        END IF;
    EXCEPTION
        WHEN ex_create_receipt
        THEN
            x_ret_code   := gn_error;
            x_ret_message   :=
                ' Error occured creating receipt. ' || ' ' || x_ret_message;
            print_log (x_ret_message, 'N', 1);
        WHEN NO_DATA_FOUND
        THEN
            x_ret_code   := gn_error;
            x_ret_message   :=
                   'No Data Found error occured when creating receipt. '
                || ' '
                || SUBSTR (SQLERRM, 1, 500);
            print_log (x_ret_message, 'N', 1);
        WHEN OTHERS
        THEN
            x_ret_code   := gn_error;
            x_ret_message   :=
                   'Error in CREATE_RECEIPT. '
                || ' '
                || SUBSTR (SQLERRM, 1, 500);
            print_log (x_ret_message, 'N', 1);
    END create_receipt;

    ----
    ----
    ---- Procedure to apply receipt to transaction
    ---- calls the public API AR_RECEIPT_API_PUB
    PROCEDURE apply_transaction (p_cash_receipt_id IN NUMBER, p_customer_trx_id IN NUMBER, p_trx_number IN VARCHAR2, p_applied_amt IN NUMBER, p_discount IN NUMBER, p_customer_reference IN VARCHAR2 DEFAULT NULL
                                 , p_auto_commit IN VARCHAR2 DEFAULT 'Y', x_ret_code OUT NUMBER, x_ret_message OUT VARCHAR2)
    IS
        l_return_status              VARCHAR2 (1);
        l_msg_count                  NUMBER;
        l_msg_data                   VARCHAR2 (500);
        l_msg_output                 VARCHAR2 (500) := NULL;
        l_msg_index_out              NUMBER;
        --l_Receipt_Number           VARCHAR2(100);
        l_cust_trx_line_id           NUMBER;
        l_line_number                NUMBER;
        l_installment                NUMBER;
        l_applied_payment_sched_id   NUMBER;
        l_amount_applied_from        NUMBER;
        l_trans_receipt_rate         NUMBER;
        l_ussgl_transaction_code     VARCHAR2 (30);
        l_comments                   VARCHAR2 (240);
        l_payment_set_id             NUMBER;
        l_application_ref_type       VARCHAR2 (30);
        l_application_ref_id         NUMBER;
        l_application_ref_num        VARCHAR2 (30);
        l_secondary_app_ref_id       NUMBER;
        l_application_ref_reason     VARCHAR2 (30);
        l_customer_reference         VARCHAR2 (100);
        l_gl_date                    DATE;
        l_receipt_date               DATE;
        l_trans_gl_date              DATE;
        l_apply_gl_date              DATE;
        ex_apply                     EXCEPTION;
        ex_trx_closed                EXCEPTION;
        lv_proc_name                 VARCHAR2 (30) := 'APPLY_TRANSACTION';
        ln_org_id                    NUMBER;
        ln_resp_id                   NUMBER;
        lv_customer_reference        VARCHAR2 (100);
        ln_ret_code                  NUMBER := NULL;
        lv_ret_message               VARCHAR2 (2000) := NULL;
    BEGIN
        print_log (
               'Inside '
            || lv_proc_name
            || ' - '
            || ' p_Cash_Receipt_ID='
            || TO_CHAR (p_cash_receipt_id)
            || ' p_Customer_Trx_ID='
            || p_customer_trx_id
            || ' p_Applied_Amt='
            || TO_CHAR (p_applied_amt)
            || ' p_customer_reference='
            || p_customer_reference);

        /*
        IF p_Cash_Receipt_ID = LG_STUB_CASH_RCPT_ID THEN
          msg(' Refund a credit memo.');
          REFUND_CREDIT_MEMO(p_Customer_Trx_ID => p_Customer_Trx_ID ,
                             p_Refund_Amount => ABS(p_Applied_Amt) ,
                             x_Ret_Stat => l_return_status ,
                             x_Error_Msg => x_error_msg );
          RETURN;
        END IF;

        SELECT GL_Date, greatest(receipt_date, TRUNC(sysdate))
        INTO l_GL_Date,
          l_receipt_date
        FROM DO_CUSTOM.DO_RECEIPT_V
        WHERE Cash_Receipt_ID = p_Cash_Receipt_ID;
        */
        SELECT crh.gl_date, GREATEST (cr.receipt_date, TRUNC (SYSDATE)), cr.org_id
          INTO l_gl_date, l_receipt_date, ln_org_id
          FROM apps.ar_cash_receipts_all cr, apps.ar_cash_receipt_history_all crh
         WHERE     1 = 1
               AND cr.cash_receipt_id = crh.cash_receipt_id
               AND cr.cash_receipt_id = p_cash_receipt_id
               AND crh.current_record_flag = 'Y';

        ln_resp_id   := get_responsibility_id (ln_org_id);
        /*B2B Phase 2 EMEA Changes(CCR0006692) - Start*/
        --Check if the transaction has open balance for application
        is_open_trx (p_org_id => ln_org_id, p_customer_trx_id => p_customer_trx_id, x_ret_code => ln_ret_code
                     , x_ret_message => lv_ret_message);

        IF ln_ret_code = gn_error
        THEN
            RAISE ex_trx_closed;
        END IF;

        /*B2B Phase 2 EMEA Changes(CCR0006692) - End*/
        IF ln_resp_id IS NOT NULL
        THEN
            fnd_global.apps_initialize (
                user_id        => fnd_global.user_id,
                resp_id        => ln_resp_id,
                resp_appl_id   => fnd_global.resp_appl_id);
        END IF;

        mo_global.init ('AR');
        mo_global.set_policy_context ('S', ln_org_id);

        /*
        SELECT org_id
          INTO ln_org_id
          FROM ar_cash_receipts_all
         WHERE 1=1
           AND cash_receipt_id = p_Cash_Receipt_ID;
        */
        IF p_customer_reference IS NOT NULL
        THEN
            --Added BEGIN and END for change
            BEGIN
                SELECT --SUBSTR(regexp_replace(p_customer_reference,'\[[^ ]+\]',''),1,100) as txt
                       SUBSTR (REGEXP_REPLACE (p_customer_reference, '\[.+?\]\:'), 1, 100) AS txt
                  INTO lv_customer_reference
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    print_log (
                           'Error getting customer reference. Error is:'
                        || SQLERRM);
            END;
        END IF;

        SELECT gl_date
          INTO l_trans_gl_date
          FROM apps.ar_payment_schedules_all
         WHERE customer_trx_id = p_customer_trx_id;

        -- Apply GL date will be the greater of Receipt GL Date or Applied Invoice GL Date
        -- This is needed because some receipts are PREPAID with dates PRIOR to the applied invoice.
        -- In this case, apply date will be INVOICE gl date.
        SELECT GREATEST (l_gl_date, l_trans_gl_date)
          INTO l_apply_gl_date
          FROM DUAL;

        ar_receipt_api_pub.APPLY (                 -- Standard API parameters.
            p_api_version            => 1.0,
            p_init_msg_list          => fnd_api.g_false,
            p_commit                 => fnd_api.g_true,
            p_validation_level       => fnd_api.g_valid_level_full,
            x_return_status          => l_return_status,
            x_msg_count              => l_msg_count,
            x_msg_data               => l_msg_data,
            p_cash_receipt_id        => p_cash_receipt_id,
            p_customer_trx_id        => p_customer_trx_id,
            p_trx_number             => p_trx_number,
            p_amount_applied         => p_applied_amt,
            p_discount               => p_discount,
            p_apply_date             => l_receipt_date + gn_grace_days,
            --p_Apply_Date,
            p_apply_gl_date          => TRUNC (l_apply_gl_date + gn_grace_days),
            -- Updated 16-SEP-2013 - Was l_gl_date prior (receipt gl date only) ,
            p_show_closed_invoices   => 'N',
            --IN VARCHAR2 DEFAULT 'N', /* Bug fix 2462013 */
            p_called_from            => 'N',
            --       IN VARCHAR2 DEFAULT NULL,
            p_move_deferred_tax      => 'Y',      --  IN VARCHAR2 DEFAULT 'Y',
            p_customer_reference     => lv_customer_reference--p_customer_reference
                                                             );

        IF l_return_status <> gv_ret_success
        THEN
            x_ret_code   := gn_error;

            FOR i IN 1 .. l_msg_count
            LOOP
                x_ret_message   :=
                       x_ret_message
                    || 'Error '
                    || i
                    || ' is: '
                    || ' '
                    || fnd_msg_pub.get (i, 'F');                 --X_MSG_DATA;
            END LOOP;

            RAISE ex_apply;
        ELSE
            x_ret_code   := gn_success;

            IF NVL (p_auto_commit, 'Y') = 'Y'
            THEN
                COMMIT;
            END IF;
        END IF;
    EXCEPTION
        /*B2B Phase 2 EMEA Changes(CCR0006692) - Start*/
        WHEN ex_trx_closed
        THEN
            x_ret_code      := ln_ret_code;
            x_ret_message   := lv_ret_message;
            print_log (x_ret_message, 'Y', 2);
        /*B2B Phase 2 EMEA Changes(CCR0006692) - End*/
        WHEN ex_apply
        THEN
            x_ret_code   := gn_error;
            x_ret_message   :=
                'Error occured applying transaction.' || ' ' || x_ret_message;
            print_log (x_ret_message, 'N', 1);
        WHEN NO_DATA_FOUND
        THEN
            x_ret_code   := gn_error;
            x_ret_message   :=
                   'No Data Found in Apply Transaction.'
                || ' '
                || SUBSTR (SQLERRM, 1, 500);
            print_log (x_ret_message, 'N', 1);
        WHEN OTHERS
        THEN
            x_ret_code   := gn_error;
            x_ret_message   :=
                   'Error in Apply Transaction.'
                || ' '
                || SUBSTR (SQLERRM, 1, 500);
            print_log (x_ret_message, 'N', 1);
    END apply_transaction;

    ----
    ----
    ---- Procedure to apply receipt on account
    ---- calls the public API AR_RECEIPT_API_PUB
    PROCEDURE apply_on_account (p_cash_receipt_id IN NUMBER, p_amt_applied IN NUMBER, p_customer_id IN NUMBER, p_apply_date IN DATE, p_customer_reference IN VARCHAR2 DEFAULT NULL, x_ret_code OUT NUMBER
                                , x_ret_message OUT VARCHAR2)
    IS
        l_return_status          VARCHAR2 (1);
        l_msg_count              NUMBER;
        l_msg_data               VARCHAR2 (500);
        l_msg_output             VARCHAR2 (500) := NULL;
        l_msg_index_out          NUMBER;
        l_gl_date                DATE;
        ex_apply_onaccount       EXCEPTION;
        --PRAGMA             AUTONOMOUS_TRANSACTION;
        lv_proc_name             VARCHAR2 (30) := 'APPLY_ON_ACCOUNT';
        ln_org_id                NUMBER;
        ln_resp_id               NUMBER;
        ln_ret_code              NUMBER;
        lv_ret_message           VARCHAR2 (2000);
        ln_bill_to_site_use_id   NUMBER;
        lv_customer_reference    VARCHAR2 (100);
    BEGIN
        print_log (
               'Inside '
            || lv_proc_name
            || ' - '
            || ' p_Cash_Receipt_ID='
            || TO_CHAR (p_cash_receipt_id)
            || ' p_Amt_Applied='
            || TO_CHAR (p_amt_applied)
            || ' p_apply_date='
            || TO_CHAR (p_apply_date, 'DD-MON-YYYY')
            || ' p_customer_reference='
            || p_customer_reference);

        SELECT org_id
          INTO ln_org_id
          FROM ar_cash_receipts_all
         WHERE cash_receipt_id = p_cash_receipt_id;

        ln_resp_id       := get_responsibility_id (ln_org_id);

        IF ln_resp_id IS NOT NULL
        THEN
            fnd_global.apps_initialize (
                user_id        => fnd_global.user_id,
                resp_id        => ln_resp_id,
                resp_appl_id   => fnd_global.resp_appl_id);
        END IF;

        mo_global.init ('AR');
        mo_global.set_policy_context ('S', ln_org_id);

        IF p_customer_reference IS NOT NULL
        THEN
            SELECT --SUBSTR(regexp_replace(p_customer_reference,'\[[^ ]+\]',''),1,100) as txt
                   SUBSTR (REGEXP_REPLACE (p_customer_reference, '\[.+?\]\:'), 1, 100) AS txt
              INTO lv_customer_reference
              FROM DUAL;
        END IF;

        ln_ret_code      := NULL;
        lv_ret_message   := NULL;
        get_site_use (p_customer_id     => p_customer_id,
                      p_org_id          => ln_org_id,
                      p_site_use_code   => 'BILL_TO',
                      x_site_use_id     => ln_bill_to_site_use_id,
                      x_ret_code        => ln_ret_code,
                      x_ret_message     => lv_ret_message);
        print_log (
               ' p_customer_id='
            || p_customer_id
            || ' p_org_id     ='
            || ln_org_id
            || ' x_site_use_id='
            || ln_bill_to_site_use_id
            || ' x_ret_code   ='
            || ln_ret_code
            || ' x_ret_message='
            || lv_ret_message);

        IF ln_ret_code <> gn_error
        THEN
            ar_receipt_api_pub.apply_on_account (
                p_api_version          => 1.0,
                p_init_msg_list        => fnd_api.g_false,
                p_commit               => fnd_api.g_true,
                p_validation_level     => fnd_api.g_valid_level_full,
                x_return_status        => l_return_status,
                x_msg_count            => l_msg_count,
                x_msg_data             => l_msg_data,
                p_cash_receipt_id      => p_cash_receipt_id,
                p_amount_applied       => p_amt_applied,
                p_apply_date           => p_apply_date,
                p_apply_gl_date        => p_apply_date,
                p_customer_reference   => lv_customer_reference-- p_ussgl_transaction_code  IN ar_receivable_applications.ussgl_transaction_code%TYPE DEFAULT NULL,
                                                               );

            IF l_return_status <> gv_ret_success
            THEN
                x_ret_code   := gn_error;

                FOR i IN 1 .. l_msg_count
                LOOP
                    x_ret_message   :=
                           x_ret_message
                        || 'Error '
                        || i
                        || ' is: '
                        || ' '
                        || fnd_msg_pub.get (i, 'F');             --X_MSG_DATA;
                END LOOP;

                RAISE ex_apply_onaccount;
            ELSE
                COMMIT;

                BEGIN
                    --Update AR Receivable Applications All
                    UPDATE ar_receivable_applications_all
                       SET on_acct_cust_id = p_customer_id, on_acct_cust_site_use_id = ln_bill_to_site_use_id, last_update_date = SYSDATE,
                           last_updated_by = fnd_global.user_id
                     WHERE     1 = 1
                           --AND receivable_application_id = ln_rec_application_id
                           AND application_type = 'CASH'
                           AND status = 'ACC'
                           AND display = 'Y'
                           AND cash_receipt_id = p_cash_receipt_id
                           AND amount_applied = p_amt_applied
                           AND apply_date = p_apply_date
                           AND applied_payment_schedule_id = -1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        print_log (
                               ' Error updating On Account Receivables Application:'
                            || SQLERRM,
                            'N',
                            1);
                END;

                x_ret_code   := gn_success;
                COMMIT;
            END IF;
        ELSE
            x_ret_code   := gn_error;
            x_ret_message   :=
                   ' Unable to get customer bill to site use for customerid#'
                || p_customer_id;
        END IF;
    EXCEPTION
        WHEN ex_apply_onaccount
        THEN
            x_ret_code   := gn_error;
            x_ret_message   :=
                'Error occured applying on account.' || ' ' || x_ret_message;
            print_log (x_ret_message, 'N', 1);
        WHEN NO_DATA_FOUND
        THEN
            x_ret_code   := gn_error;
            x_ret_message   :=
                   'No Data Found error occured in apply_on_account.'
                || ' '
                || SUBSTR (SQLERRM, 1, 1000);
            print_log (x_ret_message, 'N', 1);
        WHEN OTHERS
        THEN
            x_ret_code   := gn_error;
            x_ret_message   :=
                   'An unexpected error occured in apply_on_account.'
                || ' '
                || SUBSTR (SQLERRM, 1, 1000);
            print_log (x_ret_message, 'N', 1);
    END apply_on_account;

    ----
    ----
    ---- Procedure to unapply receipt on account
    ---- calls the public API AR_RECEIPT_API_PUB
    PROCEDURE unapply_on_account (p_org_id           IN     NUMBER,
                                  p_customer_id      IN     NUMBER,
                                  p_receipt_number   IN     VARCHAR2,
                                  x_ret_code            OUT NUMBER,
                                  x_ret_message         OUT VARCHAR2)
    IS
        lv_return_status       VARCHAR2 (1);
        ln_msg_count           NUMBER;
        lv_msg_data            VARCHAR2 (500);
        lv_msg_output          VARCHAR2 (500) := NULL;
        ln_msg_index_out       NUMBER;
        ld_gl_date             DATE;
        ex_unapply_onaccount   EXCEPTION;
        --PRAGMA             AUTONOMOUS_TRANSACTION;
        lv_proc_name           VARCHAR2 (30) := 'UNAPPLY_ON_ACCOUNT';
        ln_org_id              NUMBER := p_org_id;
        ln_resp_id             NUMBER;
        ln_ret_code            NUMBER;
        lv_ret_message         VARCHAR2 (2000);
        ln_rec_app_id          NUMBER;
        ln_cash_receipt_id     NUMBER;
    BEGIN
        print_log (
               'Inside '
            || lv_proc_name
            || ' - '
            || ' p_receipt_number='
            || p_receipt_number
            || ' p_org_id='
            || TO_CHAR (p_org_id));
        ln_resp_id   := get_responsibility_id (ln_org_id);

        IF ln_resp_id IS NOT NULL
        THEN
            fnd_global.apps_initialize (
                user_id        => fnd_global.user_id,
                resp_id        => ln_resp_id,
                resp_appl_id   => fnd_global.resp_appl_id);
        END IF;

        mo_global.init ('AR');
        mo_global.set_policy_context ('S', ln_org_id);

        SELECT receivable_application_id, cr.cash_receipt_id
          INTO ln_rec_app_id, ln_cash_receipt_id
          FROM ar_receivable_applications_all ra, ar_cash_receipts_all cr
         WHERE     1 = 1
               AND ra.cash_receipt_id = cr.cash_receipt_id
               AND ra.status = 'ACC'
               AND ra.display = 'Y'
               AND ra.applied_payment_schedule_id = -1
               AND cr.receipt_number = p_receipt_number
               AND cr.org_id = p_org_id
               AND cr.pay_from_customer = p_customer_id;

        IF ln_rec_app_id IS NOT NULL
        THEN
            ar_receipt_api_pub.unapply_on_account (
                -- Standard API parameters.
                p_api_version                 => 1.0,
                p_init_msg_list               => fnd_api.g_false,
                p_commit                      => fnd_api.g_true,
                p_validation_level            => fnd_api.g_valid_level_full,
                x_return_status               => lv_return_status,
                x_msg_count                   => ln_msg_count,
                x_msg_data                    => lv_msg_data,
                -- *** Receipt Info. parameters *****
                p_receipt_number              => NULL,
                --p_receipt_number,
                p_cash_receipt_id             => ln_cash_receipt_id,
                p_receivable_application_id   => ln_rec_app_id,
                p_reversal_gl_date            => NULL,
                p_org_id                      => ln_org_id                --95
                                                          );

            IF lv_return_status <> gv_ret_success
            THEN
                x_ret_code   := gn_error;

                FOR i IN 1 .. ln_msg_count
                LOOP
                    x_ret_message   :=
                           x_ret_message
                        || 'Error '
                        || i
                        || ' is: '
                        || ' '
                        || fnd_msg_pub.get (i, 'F');             --X_MSG_DATA;
                END LOOP;

                RAISE ex_unapply_onaccount;
            ELSE
                x_ret_code   := gn_success;
                COMMIT;
            END IF;
        ELSE
            x_ret_code   := gn_error;
            x_ret_message   :=
                ' Unable to get OnAccount receivable application';
        END IF;
    EXCEPTION
        WHEN ex_unapply_onaccount
        THEN
            x_ret_code   := gn_error;
            x_ret_message   :=
                   'Error occured unapplying on account.'
                || ' '
                || x_ret_message;
            print_log (x_ret_message, 'N', 1);
        WHEN NO_DATA_FOUND
        THEN
            x_ret_code   := gn_error;
            x_ret_message   :=
                   'No Data Found error occured in UNapply_on_account.'
                || ' '
                || SUBSTR (SQLERRM, 1, 1000);
            print_log (x_ret_message, 'N', 1);
        WHEN OTHERS
        THEN
            x_ret_code   := gn_error;
            x_ret_message   :=
                   'An unexpected error occured in UNapply_on_account.'
                || ' '
                || SUBSTR (SQLERRM, 1, 1000);
            print_log (x_ret_message, 'N', 1);
    END unapply_on_account;

    ----
    ----
    ---- Procedure to TRX based claims
    ----
    PROCEDURE create_trx_claim (
        p_org_id               IN     NUMBER,
        p_receivable_app_id    IN     NUMBER,
        p_amount               IN     NUMBER,
        p_reason               IN     VARCHAR2,
        p_customer_reference   IN     VARCHAR2 DEFAULT NULL,
        x_deduction_number        OUT VARCHAR2,
        x_ret_code                OUT NUMBER,
        x_ret_message             OUT VARCHAR2)
    IS
        --Primary cursor for processing TRX based claims
        CURSOR get_ra_rec (p_rec_app_id NUMBER)
        IS
            SELECT DISTINCT ra.applied_payment_schedule_id
              FROM ar_receivable_applications ra
             WHERE     ra.applied_payment_schedule_id NOT IN (-4, -1)
                   AND ra.status = 'APP'
                   AND ra.display = 'Y'
                   --AND ra.request_id                         = p_request_id
                   AND ra.receivable_application_id = p_rec_app_id;

        CURSOR get_trx_app_info (p_rec_application_id NUMBER)
        IS
            SELECT SUM (ra.amount_applied), MAX (ra.apply_date)
              FROM ar_receivable_applications_all ra
             WHERE     1 = 1
                   AND ra.receivable_application_id = p_rec_application_id
                   --and    ra.applied_payment_schedule_id = p_trx_ps_id
                   --AND    ra.request_id = p_request_id
                   AND ra.status = 'APP'
                   AND ra.display = 'Y';

        --Fetch receipt info using applied payment schedule id of the trx
        CURSOR get_receipt_num (p_rec_application_id NUMBER)
        IS
            SELECT ps.cash_receipt_id                        --cash_receipt_id
                                     , cr.receipt_number      --receipt_number
              FROM ar_payment_schedules_all ps, ar_cash_receipts_all cr, ar_receivable_applications_all ra
             WHERE     1 = 1
                   AND ra.receivable_application_id = p_rec_application_id
                   AND ps.payment_schedule_id = ra.payment_schedule_id
                   AND cr.cash_receipt_id = ps.cash_receipt_id;

        --Get TRX based info from ra_customer_trx and ar_payment_schedules
        --Exclude CLASS=PMT
        CURSOR get_ps_trx_info (
            p_trx_ps_id   ar_receivable_applications.applied_payment_schedule_id%TYPE)
        IS
            SELECT ct.customer_trx_id,                       --customer_trx_id
                                       ct.trx_number,             --trx_number
                                                      ct.cust_trx_type_id,
                   --trx_type_id
                   ct.invoice_currency_code,                   --currency_code
                                             ct.exchange_rate_type, --exchange_rate_type
                                                                    ct.exchange_date, --exchange_date
                   ct.exchange_rate,                           --exchange_rate
                                     ct.bill_to_customer_id, --customer_id
                                                             ct.bill_to_site_use_id, --bill_to_site_use_id
                   ct.ship_to_site_use_id, --ship_to_site_use_id
                                           ct.primary_salesrep_id, --salesrep_id
                                                                   ps.amount_due_remaining,
                   --amount_due_remaining
                   ps.amount_due_original,               --amount_due_original
                                           ps.CLASS,                   --class
                                                     ps.active_claim_flag,
                   --active_claim_flag
                   ct.legal_entity_id
              FROM ra_customer_trx ct, ar_payment_schedules ps
             WHERE     ct.customer_trx_id = ps.customer_trx_id
                   AND ps.payment_schedule_id = p_trx_ps_id
                   AND ps.CLASS <> 'PMT';

        --Cursor to fetch RA info based on the applied PS id retreived by the
        --primary cursor to process TRX based claims
        CURSOR get_ra_info (
            p_trx_ps_id   ar_receivable_applications.applied_payment_schedule_id%TYPE)
        IS
            SELECT ra.receivable_application_id, ra.amount_applied, ra.payment_schedule_id,
                   ra.applied_payment_schedule_id, ra.applied_customer_trx_id, ra.comments,
                   ra.attribute_category, ra.attribute1, ra.attribute2,
                   ra.attribute3, ra.attribute4, ra.attribute5,
                   ra.attribute6, ra.attribute7, ra.attribute8,
                   ra.attribute9, ra.attribute10, ra.attribute11,
                   ra.attribute12, ra.attribute13, ra.attribute14,
                   ra.attribute15, ra.application_ref_num, ra.secondary_application_ref_id,
                   ra.application_ref_reason, ra.customer_reason, ra.customer_reference,
                   NULL, -- x_return_status
                         NULL, -- x_msg_count
                               NULL,
                   -- x_msg_data
                   NULL                                 -- x_claim_reason_name
              FROM ar_receivable_applications_all ra
             WHERE     ra.applied_payment_schedule_id = p_trx_ps_id
                   --AND    ra.request_id = p_request_id
                   AND ra.display = 'Y'
                   AND ra.receivable_application_id =
                       (SELECT MAX (ra1.receivable_application_id)
                          FROM ar_receivable_applications_all ra1
                         WHERE ra1.applied_payment_schedule_id =
                               ra.applied_payment_schedule_id);

        ln_customer_trx_id        NUMBER;
        lv_trx_number             VARCHAR2 (50);
        ln_cust_trx_type_id       NUMBER;
        lv_currency_code          VARCHAR2 (30);
        lv_exchange_rate_type     VARCHAR2 (30);
        ld_exchange_date          DATE;
        ln_exchange_rate          NUMBER;
        ln_customer_id            NUMBER;
        ln_bill_to_site_use_id    NUMBER;
        ln_ship_to_site_use_id    NUMBER;
        ln_salesrep_id            NUMBER;
        ln_amount_due_remaining   NUMBER;
        ln_amount_due_original    NUMBER;
        lv_class                  VARCHAR2 (30);
        lv_active_claim_flag      VARCHAR2 (1);
        ln_legal_entity_id        NUMBER;
        ln_applied_ps_id          NUMBER;
        lv_return_status          VARCHAR2 (30);
        ln_msg_count              NUMBER;
        lv_msg_data               VARCHAR2 (2000);
        ln_claim_id               NUMBER;
        lv_claim_number           VARCHAR2 (60);
        lv_claim_reason_name      VARCHAR2 (240);
        p_count                   NUMBER := 0;
        ln_amount_applied         NUMBER;
        ld_applied_date           DATE;
        ln_cash_receipt_id        NUMBER;
        lv_receipt_number         VARCHAR2 (60);
        ln_reason_code_id         NUMBER;                            --CB-DISC
        ln_receivable_app_id      NUMBER := p_receivable_app_id;
        ln_amount_applied1        NUMBER := p_amount;
        ln_org_id                 NUMBER := p_org_id;
        ex_reason_code            EXCEPTION;
        ln_ret_code               NUMBER;
        lv_ret_message            VARCHAR2 (2000);
        --PRAGMA                  AUTONOMOUS_TRANSACTION;
        lv_proc_name              VARCHAR2 (30) := 'CREATE_TRX_CLAIM';
        --ln_reason_code_id       NUMBER := 75; --CB-DISC
        ln_resp_id                NUMBER;
        lv_customer_reference     VARCHAR2 (100);
    BEGIN
        print_log (
               'Inside '
            || lv_proc_name
            || ' - '
            || ' p_org_id='
            || TO_CHAR (p_org_id)
            || ' p_receivable_app_id='
            || TO_CHAR (p_receivable_app_id)
            || ' p_amount='
            || TO_CHAR (p_amount)
            || ' p_reason='
            || p_reason
            || ' p_customer_reference='
            || p_customer_reference);
        /*
        -- 1) Set the applications context
        fnd_global.apps_initialize(1697, --USER ID --Kranthi.bollam DEV2
        20678,                           --Resp ID -- Receivables Manager
        222,                             --RESP_APPL_ID --Receivables
        0);*/
        ln_resp_id   := get_responsibility_id (ln_org_id);

        IF ln_resp_id IS NOT NULL
        THEN
            fnd_global.apps_initialize (
                user_id        => fnd_global.user_id,
                resp_id        => ln_resp_id,
                resp_appl_id   => fnd_global.resp_appl_id);
        END IF;

        mo_global.init ('AR');
        mo_global.set_policy_context ('S', ln_org_id);
        get_reason_code_id (p_org_id           => ln_org_id,
                            p_reason_code      => p_reason,
                            p_amount           => p_amount,
                            x_reason_code_id   => ln_reason_code_id,
                            x_ret_code         => ln_ret_code,
                            x_ret_message      => lv_ret_message);
        print_log (
               lv_proc_name
            || ' '
            || ' x_reason_code_id='
            || TO_CHAR (ln_reason_code_id));

        IF ln_ret_code = gn_error
        THEN
            RAISE ex_reason_code;
        END IF;

        IF p_customer_reference IS NOT NULL
        THEN
            SELECT --SUBSTR(regexp_replace(p_customer_reference,'\[[^ ]+\]',''),1,100) as txt
                   SUBSTR (REGEXP_REPLACE (p_customer_reference, '\[.+?\]\:'), 1, 100) AS txt
              INTO lv_customer_reference
              FROM DUAL;
        END IF;

        OPEN get_ra_rec (ln_receivable_app_id);                  --(13251819);

        FETCH get_ra_rec INTO ln_applied_ps_id;

        CLOSE get_ra_rec;

        OPEN get_trx_app_info (ln_receivable_app_id);            --(13251819);

        FETCH get_trx_app_info INTO ln_amount_applied, ld_applied_date;

        CLOSE get_trx_app_info;

        OPEN get_receipt_num (ln_receivable_app_id);             --(13251819);

        FETCH get_receipt_num INTO ln_cash_receipt_id, lv_receipt_number;

        CLOSE get_receipt_num;

        print_log (
               ' ln_amount_applied '
            || ln_amount_applied
            || ' ln_applied_ps_id '
            || ln_applied_ps_id
            || ' ln_cash_receipt_id '
            || ln_cash_receipt_id
            || ' lv_receipt_number '
            || lv_receipt_number);

        OPEN get_ps_trx_info (ln_applied_ps_id);

        FETCH get_ps_trx_info
            INTO ln_customer_trx_id, lv_trx_number, ln_cust_trx_type_id, lv_currency_code,
                 lv_exchange_rate_type, ld_exchange_date, ln_exchange_rate,
                 ln_customer_id, ln_bill_to_site_use_id, ln_ship_to_site_use_id,
                 ln_salesrep_id, ln_amount_due_remaining, ln_amount_due_original,
                 lv_class, lv_active_claim_flag, ln_legal_entity_id;

        CLOSE get_ps_trx_info;

        print_log (
               ' ln_amount_due_remaining '
            || ln_amount_due_remaining
            || ' ln_amount_due_original '
            || ln_amount_due_original);
        arp_process_application.create_claim (
            p_amount                => ln_amount_applied1,
            p_amount_applied        => ln_amount_applied1,
            p_currency_code         => lv_currency_code,
            p_exchange_rate_type    => lv_exchange_rate_type,
            p_exchange_rate_date    => ld_exchange_date,
            p_exchange_rate         => ln_exchange_rate,
            p_customer_trx_id       => ln_customer_trx_id,
            p_invoice_ps_id         => ln_applied_ps_id,
            p_cust_trx_type_id      => ln_cust_trx_type_id,
            p_trx_number            => lv_trx_number,
            p_cust_account_id       => ln_customer_id,
            p_bill_to_site_id       => ln_bill_to_site_use_id,
            p_ship_to_site_id       => ln_ship_to_site_use_id,
            p_salesrep_id           => ln_salesrep_id,
            p_customer_ref_date     => NULL,
            --p_customer_ref_number => lv_customer_reference,--claim_rec.customer_reference , --Commented for change 2.1
            p_customer_ref_number   => SUBSTR (lv_customer_reference, 1, 30),
            --Added for change 2.1
            p_cash_receipt_id       => ln_cash_receipt_id,
            --3812018,--ln_cash_receipt_id ,
            p_receipt_number        => lv_receipt_number,
            -- 'test_surcharge_1',--lv_receipt_number ,
            p_reason_id             => ln_reason_code_id,
            --CB-ALLOW --to_number(claim_rec.application_ref_reason) ,
            p_customer_reason       => NULL,       --claim_rec.customer_reason
            p_comments              => lv_customer_reference,
            --claim_rec.comments
            p_apply_date            => ld_applied_date,          --Bug 5495310
            p_attribute_category    => NULL,    --claim_rec.attribute_category
            p_attribute1            => NULL,            --claim_rec.attribute1
            p_attribute2            => NULL,            --claim_rec.attribute2
            p_attribute3            => NULL,            --claim_rec.attribute3
            p_attribute4            => NULL,            --claim_rec.attribute4
            p_attribute5            => NULL,            --claim_rec.attribute5
            p_attribute6            => NULL,            --claim_rec.attribute6
            p_attribute7            => NULL,            --claim_rec.attribute7
            p_attribute8            => NULL,            --claim_rec.attribute8
            p_attribute9            => NULL,            --claim_rec.attribute9
            p_attribute10           => NULL,           --claim_rec.attribute10
            p_attribute11           => NULL,           --claim_rec.attribute11
            p_attribute12           => NULL,           --claim_rec.attribute12
            p_attribute13           => NULL,           --claim_rec.attribute13
            p_attribute14           => NULL,           --claim_rec.attribute14
            p_attribute15           => NULL,           --claim_rec.attribute15
            x_return_status         => lv_return_status,
            x_msg_count             => ln_msg_count,
            x_msg_data              => lv_msg_data,
            x_claim_id              => ln_claim_id,
            x_claim_number          => lv_claim_number,
            x_claim_reason_name     => lv_claim_reason_name,
            p_legal_entity_id       => ln_legal_entity_id);
        -- 3) Review the API output
        print_log (
               'Status '
            || lv_return_status
            || ' Message count '
            || ln_msg_count
            || ' ln_claim_id '
            || ln_claim_id
            || ' lv_claim_number '
            || lv_claim_number
            || 'lv_claim_reason_name '
            || lv_claim_reason_name);

        IF lv_return_status <> gv_ret_success                            --'S'
        THEN
            x_ret_code      := gn_error;

            IF ln_msg_count = 1
            THEN
                print_log ('l_msg_data ' || lv_msg_data);
            ELSIF ln_msg_count > 1
            THEN
                LOOP
                    p_count   := p_count + 1;
                    lv_msg_data   :=
                        fnd_msg_pub.get (fnd_msg_pub.g_next, fnd_api.g_false);

                    IF lv_msg_data IS NULL
                    THEN
                        EXIT;
                    END IF;

                    print_log ('Message ' || p_count || '. ' || lv_msg_data);
                END LOOP;
            END IF;

            x_ret_message   := lv_msg_data;
        ELSE
            UPDATE ar_receivable_applications_all
               SET application_ref_type = 'CLAIM', application_ref_num = lv_claim_number, secondary_application_ref_id = ln_claim_id,
                   application_ref_reason = ln_reason_code_id, last_update_date = SYSDATE, last_updated_by = fnd_global.user_id
             WHERE     1 = 1
                   AND receivable_application_id = ln_receivable_app_id
                   AND status = 'APP'
                   AND display = 'Y';

            COMMIT;
            --END IF;
            x_deduction_number   := lv_claim_number;
            x_ret_code           := gn_success;
            x_ret_message        :=
                ' Trx Deduction#' || lv_claim_number || ' created';
        END IF;
    EXCEPTION
        WHEN ex_reason_code
        THEN
            x_ret_code   := gn_error;
            x_ret_message   :=
                ' Error in getting reason code id:' || lv_ret_message;
            print_log (x_ret_message, 'N', 2);
        WHEN OTHERS
        THEN
            x_ret_code   := gn_error;
            x_ret_message   :=
                   ' Error in create_trx_claim.'
                || ' '
                || SUBSTR (SQLERRM, 1, 1000);
            print_log (x_ret_message, 'N', 2);
    END create_trx_claim;

    ----
    ----
    ---- Procedure to create misc receipt
    ---- calls the public API AR_RECEIPT_API_PUB
    PROCEDURE create_misc (
        p_org_id              IN            NUMBER,
        p_batch_id            IN            NUMBER,
        p_currency_code       IN            VARCHAR2,
        p_amount              IN            NUMBER,
        p_receipt_date        IN            DATE,
        p_gl_date             IN            DATE,
        p_receipt_method_id   IN            NUMBER,
        p_activity            IN            VARCHAR2,
        p_comments            IN            VARCHAR2 DEFAULT NULL,
        p_receipt_number      IN OUT NOCOPY VARCHAR2,
        p_auto_commit         IN            VARCHAR2 DEFAULT 'Y',
        x_misc_receipt_id        OUT        NUMBER,
        x_ret_code               OUT        NUMBER,
        x_ret_message            OUT        VARCHAR2)
    IS
        lv_return_status   VARCHAR2 (1);
        ln_msg_count       NUMBER;
        lv_msg_data        VARCHAR2 (20000);
        lv_ret_message     VARCHAR2 (2000);
        --PRAGMA                    AUTONOMOUS_TRANSACTION;
        lv_proc_name       VARCHAR2 (30) := 'CREATE_MISC';
        ln_org_id          NUMBER := p_org_id;
        ln_resp_id         NUMBER;
        lv_comments        VARCHAR2 (2000);
    BEGIN
        print_log (
               'Inside '
            || lv_proc_name
            || ' - '
            || ' p_currency_code= '
            || p_currency_code
            || ' p_amount= '
            || TO_CHAR (p_amount)
            || ' p_receipt_date= '
            || TO_CHAR (p_receipt_date, 'DD-MON-YYYY')
            || ' p_gl_date= '
            || TO_CHAR (p_gl_date, 'DD-MON-YYYY')
            || ' p_comments= '
            || p_comments
            || ' p_receipt_method_id= '
            || TO_CHAR (p_receipt_method_id)
            || ' p_activity= '
            || p_activity
            || ' p_receipt_number= '
            || p_receipt_number);
        ln_resp_id   := get_responsibility_id (ln_org_id);

        IF ln_resp_id IS NOT NULL
        THEN
            fnd_global.apps_initialize (
                user_id        => fnd_global.user_id,
                resp_id        => ln_resp_id,
                resp_appl_id   => fnd_global.resp_appl_id);
        END IF;

        mo_global.init ('AR');
        mo_global.set_policy_context ('S', ln_org_id);

        IF p_comments IS NOT NULL
        THEN
            SELECT --regexp_replace(p_comments,'\[[^ ]+\]','') as txt
                   --regexp_replace(p_comments,'\[.+?\]\:') as txt --Commented for change 2.1
                   SUBSTR (REGEXP_REPLACE (p_comments, '\[.+?\]\:'), 1, 2000) AS txt
              --Added for change 2.1
              INTO lv_comments
              FROM DUAL;
        END IF;

        ar_receipt_api_pub.create_cash (p_api_version => 1.0, p_init_msg_list => fnd_api.g_true, p_commit => fnd_api.g_true, p_validation_level => fnd_api.g_valid_level_full, x_return_status => lv_return_status, x_msg_count => ln_msg_count, x_msg_data => lv_msg_data, p_currency_code => p_currency_code, p_comments => lv_comments, --p_comments,
                                                                                                                                                                                                                                                                                                                                           p_amount => p_amount, p_receipt_number => p_receipt_number, p_receipt_date => p_receipt_date, p_gl_date => p_gl_date, p_customer_number => NULL, --'1007',
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            p_receipt_method_id => p_receipt_method_id
                                        , p_cr_id => x_misc_receipt_id);

        IF lv_return_status <> gv_ret_success
        THEN
            IF ln_msg_count > 0
            THEN
                FOR i IN 1 .. ln_msg_count
                LOOP
                    fnd_msg_pub.get (i, fnd_api.g_false, lv_msg_data,
                                     ln_msg_count);
                    lv_ret_message   := lv_ret_message || lv_msg_data;
                    print_log ('Error Message : ' || lv_msg_data, 'N', 1);
                END LOOP;
            END IF;

            x_ret_code      := gn_error;
            x_ret_message   := lv_ret_message;
            print_log ('Error occured while creating misc receipt', 'N', 1);
        ELSE
            /* Create Receipt was sucessful, link receipt to batch */
            UPDATE ar_cash_receipt_history_all
               SET batch_id   = p_batch_id
             WHERE cash_receipt_id = x_misc_receipt_id;

            x_ret_code      := gn_success;
            x_ret_message   := 'Misc Receipt ID:' || x_misc_receipt_id;

            IF NVL (p_auto_commit, 'Y') = 'Y'
            THEN
                COMMIT;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code   := gn_error;
            x_ret_message   :=
                ' Error in create_misc.' || ' ' || SUBSTR (SQLERRM, 1, 1000);
            print_log (x_ret_message, 'N', 2);
    END create_misc;

    ----
    ----
    ---- Procedure to process deductions
    ---- creates writeoff application
    PROCEDURE activity_application (
        p_cash_receipt_id             IN     NUMBER,
        p_receivables_trx_id          IN     NUMBER,
        p_amount_applied              IN     NUMBER,
        p_apply_date                  IN     DATE,
        p_customer_reference          IN     VARCHAR2,
        x_receivable_application_id      OUT NUMBER,
        x_ret_code                       OUT NUMBER,
        x_ret_message                    OUT VARCHAR2)
    IS
        lv_return_status               VARCHAR2 (1);
        ln_msg_count                   NUMBER;
        lv_msg_data                    VARCHAR2 (240);
        ln_cash_receipt_id             NUMBER;
        ln_count                       NUMBER := 0;
        lv_application_ref_type        ar_receivable_applications.application_ref_type%TYPE;
        ln_application_ref_id          ar_receivable_applications.application_ref_id%TYPE;
        lv_application_ref_num         ar_receivable_applications.application_ref_num%TYPE;
        ln_sec_application_ref_id      ar_receivable_applications.secondary_application_ref_id%TYPE;
        ln_receivable_application_id   ar_receivable_applications.receivable_application_id%TYPE;
        --PRAGMA                           AUTONOMOUS_TRANSACTION;
        lv_proc_name                   VARCHAR2 (30)
                                           := 'ACTIVITY_APPLICATION';
        ln_org_id                      NUMBER;
        ln_resp_id                     NUMBER;
        lv_customer_reference          VARCHAR2 (100);
    BEGIN
        print_log (
               'Inside '
            || lv_proc_name
            || ' - '
            || ' p_cash_receipt_id= '
            || TO_CHAR (p_cash_receipt_id)
            || ' p_receivables_trx_id= '
            || TO_CHAR (p_receivables_trx_id)
            || ' p_amount_applied= '
            || TO_CHAR (p_amount_applied)
            || ' p_apply_date= '
            || TO_CHAR (p_apply_date, 'DD-MON-YYYY')
            || ' p_customer_reference= '
            || p_customer_reference);

        SELECT org_id
          INTO ln_org_id
          FROM ar_cash_receipts_all
         WHERE 1 = 1 AND cash_receipt_id = p_cash_receipt_id;

        ln_resp_id   := get_responsibility_id (ln_org_id);

        IF ln_resp_id IS NOT NULL
        THEN
            fnd_global.apps_initialize (
                user_id        => fnd_global.user_id,
                resp_id        => ln_resp_id,
                resp_appl_id   => fnd_global.resp_appl_id);
        END IF;

        mo_global.init ('AR');
        mo_global.set_policy_context ('S', ln_org_id);

        IF p_customer_reference IS NOT NULL
        THEN
            SELECT --SUBSTR(regexp_replace(p_customer_reference,'\[[^ ]+\]',''),1,100) as txt
                   SUBSTR (REGEXP_REPLACE (p_customer_reference, '\[.+?\]\:'), 1, 100) AS txt
              INTO lv_customer_reference
              FROM DUAL;
        END IF;

        ar_receipt_api_pub.activity_application (
            p_api_version                    => 1.0,
            p_init_msg_list                  => fnd_api.g_true,
            p_commit                         => fnd_api.g_true,
            p_validation_level               => fnd_api.g_valid_level_full,
            x_return_status                  => lv_return_status,
            x_msg_count                      => ln_msg_count,
            x_msg_data                       => lv_msg_data,
            p_cash_receipt_id                => p_cash_receipt_id,
            p_applied_payment_schedule_id    => -3,
            p_apply_date                     => p_apply_date + gn_grace_days,
            p_apply_gl_date                  => p_apply_date + gn_grace_days,
            p_amount_applied                 => p_amount_applied,
            p_receivables_trx_id             => p_receivables_trx_id,
            p_customer_reference             => lv_customer_reference,
            --p_customer_reference,
            p_receivable_application_id      => ln_receivable_application_id,
            p_application_ref_type           => lv_application_ref_type,
            p_application_ref_id             => ln_application_ref_id,
            p_application_ref_num            => lv_application_ref_num,
            p_secondary_application_ref_id   => ln_sec_application_ref_id);
        print_log (
               'Status '
            || lv_return_status
            || ' Message count '
            || ln_msg_count
            || ' Application ID '
            || ln_receivable_application_id);

        IF lv_return_status = gv_ret_success
        THEN
            x_ret_code                    := gn_success;
            x_ret_message                 := NULL;
            x_receivable_application_id   := ln_receivable_application_id;
            COMMIT;
        ELSE
            IF ln_msg_count = 1
            THEN
                x_ret_code      := gn_error;
                x_ret_message   := lv_msg_data;
                print_log (
                    'Receipt Writeoff Creation Error: ' || lv_msg_data,
                    'N',
                    1);
            ELSIF ln_msg_count > 1
            THEN
                x_ret_code   := gn_error;

                LOOP
                    ln_count        := ln_count + 1;
                    lv_msg_data     :=
                        fnd_msg_pub.get (fnd_msg_pub.g_next, fnd_api.g_false);
                    x_ret_message   := x_ret_message || lv_msg_data;

                    IF lv_msg_data IS NULL
                    THEN
                        EXIT;
                    END IF;

                    print_log (
                           'Receipt Writeoff Error: '
                        || ln_count
                        || '. '
                        || lv_msg_data,
                        'N',
                        1);
                END LOOP;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code      := gn_error;
            x_ret_message   := ' Error in activity_application - ' || SQLERRM;
            print_log (x_ret_message, 'Y', 2);
    END activity_application;

    ----
    ----
    ---- Procedure to process non-trx deductions
    ----
    PROCEDURE apply_other_account (p_reason_code IN VARCHAR2, p_customer_id IN NUMBER, p_org_id IN NUMBER DEFAULT NULL, p_type IN VARCHAR2, p_cash_receipt_id IN ar_cash_receipts.cash_receipt_id%TYPE DEFAULT NULL, p_receipt_number IN ar_cash_receipts.receipt_number%TYPE DEFAULT NULL, p_amount_applied IN ar_receivable_applications.amount_applied%TYPE DEFAULT NULL, --p_receivables_trx_id               IN  ar_receivable_applications.receivables_trx_id%TYPE DEFAULT NULL,
                                                                                                                                                                                                                                                                                                                                                                             p_applied_payment_schedule_id IN ar_receivable_applications.applied_payment_schedule_id%TYPE DEFAULT NULL, p_apply_date IN ar_receivable_applications.apply_date%TYPE DEFAULT NULL, p_apply_gl_date IN ar_receivable_applications.gl_date%TYPE DEFAULT NULL, --p_ussgl_transaction_code           IN  ar_receivable_applications.ussgl_transaction_code%TYPE DEFAULT NULL,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          p_application_ref_type IN ar_receivable_applications.application_ref_type%TYPE DEFAULT NULL, p_application_ref_id IN OUT NOCOPY ar_receivable_applications.application_ref_id%TYPE, p_application_ref_num IN OUT NOCOPY ar_receivable_applications.application_ref_num%TYPE, p_secondary_application_ref_id IN OUT NOCOPY ar_receivable_applications.secondary_application_ref_id%TYPE, p_payment_set_id IN ar_receivable_applications.payment_set_id%TYPE DEFAULT NULL, p_comments IN ar_receivable_applications.comments%TYPE DEFAULT NULL, --p_application_ref_reason           IN  ar_receivable_applications.application_ref_reason%TYPE DEFAULT NULL,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        p_customer_reference IN ar_receivable_applications.customer_reference%TYPE DEFAULT NULL, p_customer_reason IN ar_receivable_applications.customer_reason%TYPE DEFAULT NULL, p_called_from IN VARCHAR2 DEFAULT NULL, x_receivable_application_id OUT NOCOPY ar_receivable_applications.receivable_application_id%TYPE, x_ret_code OUT NUMBER
                                   , x_ret_message OUT VARCHAR2)
    IS
        lv_return_status            VARCHAR2 (1);
        ln_msg_count                NUMBER;
        lv_msg_data                 VARCHAR2 (20000);
        ln_rec_application_id       NUMBER;
        ln_receivables_trx_id       NUMBER := NULL;
        ln_ret_code                 NUMBER := NULL;
        lv_ret_message              VARCHAR2 (2000) := NULL;
        ln_reason_code_id           NUMBER := NULL;
        ln_application_ref_id       NUMBER := NULL;
        lv_application_ref_num      VARCHAR2 (240) := NULL;
        ln_sec_application_ref_id   NUMBER := NULL;
        --PRAGMA                    AUTONOMOUS_TRANSACTION;
        lv_proc_name                VARCHAR2 (30) := 'APPLY_OTHER_ACCOUNT';
        lv_error_message            VARCHAR2 (1000);
        ln_org_id                   NUMBER := p_org_id;
        ln_resp_id                  NUMBER;
        ln_bill_to_site_use_id      NUMBER := NULL;
        ln_claim_type_id            NUMBER := NULL;
        lv_customer_reference       VARCHAR2 (100);
    BEGIN
        print_log (
               'Inside '
            || lv_proc_name
            || ' - '
            || ' p_reason_code= '
            || p_reason_code
            || ' p_customer_id= '
            || TO_CHAR (p_customer_id)
            || ' p_type= '
            || p_type
            || ' p_org_id= '
            || TO_CHAR (p_org_id)
            || ' p_cash_receipt_id= '
            || TO_CHAR (p_cash_receipt_id)
            || ' p_amount_applied= '
            || TO_CHAR (p_amount_applied)
            || ' p_apply_date= '
            || TO_CHAR (p_apply_date, 'DD-MON-YYYY')
            || ' p_customer_reference= '
            || p_customer_reference);
        ln_resp_id       := get_responsibility_id (ln_org_id);

        IF ln_resp_id IS NOT NULL
        THEN
            fnd_global.apps_initialize (
                user_id        => fnd_global.user_id,
                resp_id        => ln_resp_id,
                resp_appl_id   => fnd_global.resp_appl_id);
        END IF;

        mo_global.init ('AR');
        mo_global.set_policy_context ('S', ln_org_id);

        IF p_customer_reference IS NOT NULL
        THEN
            SELECT --SUBSTR(regexp_replace(p_customer_reference,'\[[^ ]+\]',''),1,100) as txt
                   --SUBSTR(regexp_replace(p_customer_reference,'\[.+?\]\:'),1,100) as txt --Commented for change 2.1
                   SUBSTR (REGEXP_REPLACE (p_customer_reference, '\[.+?\]\:'), 1, 30) AS txt --Added for change 2.1
              INTO lv_customer_reference
              FROM DUAL;
        END IF;

        ln_ret_code      := NULL;
        lv_ret_message   := NULL;
        get_reason_code_id (p_org_id           => p_org_id,
                            p_reason_code      => p_reason_code,
                            p_amount           => p_amount_applied,
                            x_reason_code_id   => ln_reason_code_id,
                            x_ret_code         => ln_ret_code,
                            x_ret_message      => lv_ret_message);

        --print_log('ln_reason_code_id:'||ln_reason_code_id);
        IF ln_ret_code = gn_error
        THEN
            lv_error_message   := lv_error_message || lv_ret_message;
        END IF;

        ln_ret_code      := NULL;
        lv_ret_message   := NULL;
        --Modified the below call from get_receivables_trx_id to
        --get_receivables_trx_id2 for B2B Phase 2 EMEA Changes(CCR0006692)
        --get_receivables_trx_id (p_customer_id        => p_customer_id
        get_receivables_trx_id2 (
            p_customer_id          => p_customer_id,
            p_org_id               => p_org_id,
            p_type                 => p_type,
            x_receivables_trx_id   => ln_receivables_trx_id,
            x_ret_code             => ln_ret_code,
            x_ret_message          => lv_ret_message);

        --print_log('ln_receivables_trx_id:'||ln_receivables_trx_id);
        IF ln_ret_code = gn_error
        THEN
            lv_error_message   := lv_error_message || lv_ret_message;
        END IF;

        ln_ret_code      := NULL;
        lv_ret_message   := NULL;
        get_site_use (p_customer_id     => p_customer_id,
                      p_org_id          => p_org_id,
                      p_site_use_code   => 'BILL_TO',
                      x_site_use_id     => ln_bill_to_site_use_id,
                      x_ret_code        => ln_ret_code,
                      x_ret_message     => lv_ret_message);

        IF ln_ret_code = gn_error
        THEN
            lv_error_message   := lv_error_message || lv_ret_message;
        END IF;

        ln_ret_code      := NULL;
        lv_ret_message   := NULL;
        get_claim_type_id (p_customer_id      => p_customer_id,
                           p_org_id           => p_org_id,
                           p_reason_code_id   => ln_reason_code_id,
                           x_claim_type_id    => ln_claim_type_id,
                           x_ret_code         => ln_ret_code,
                           x_ret_message      => lv_ret_message);

        --print_log('ln_reason_code_id:'||ln_reason_code_id);
        /*
        IF ln_ret_code = gn_error
        THEN
          lv_error_message := lv_error_message||lv_ret_message;
        END IF;*/
        IF     ln_reason_code_id IS NOT NULL
           AND ln_receivables_trx_id IS NOT NULL
           AND ln_bill_to_site_use_id IS NOT NULL
        THEN
            ar_receipt_api_pub.apply_other_account (p_api_version => 1.0, p_init_msg_list => fnd_api.g_true, p_commit => fnd_api.g_true, p_validation_level => fnd_api.g_valid_level_full, x_return_status => lv_return_status, x_msg_count => ln_msg_count, x_msg_data => lv_msg_data, p_receivable_application_id => ln_rec_application_id, p_cash_receipt_id => p_cash_receipt_id, --3812014,
                                                                                                                                                                                                                                                                                                                                                                                      p_receivables_trx_id => ln_receivables_trx_id, --1249,
                                                                                                                                                                                                                                                                                                                                                                                                                                     p_applied_payment_schedule_id => -4, p_application_ref_type => 'CLAIM', p_customer_reference => lv_customer_reference, --p_comments       => lv_customer_reference,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            p_amount_applied => p_amount_applied, ---59,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  p_application_ref_id => ln_application_ref_id, p_application_ref_num => lv_application_ref_num, p_secondary_application_ref_id => ln_sec_application_ref_id, p_application_ref_reason => ln_reason_code_id
                                                    , --82,
                                                      p_called_from => NULL);

            IF lv_return_status <> gv_ret_success
            THEN
                x_ret_code   := gn_error;

                IF ln_msg_count > 0
                THEN
                    FOR i IN 1 .. ln_msg_count
                    LOOP
                        fnd_msg_pub.get (i, fnd_api.g_false, lv_msg_data,
                                         ln_msg_count);
                        print_log ('Error Message : ' || lv_msg_data, 'N', 1);
                        lv_ret_message   := lv_ret_message || lv_msg_data;
                    END LOOP;

                    x_ret_message   := lv_ret_message;
                END IF;

                print_log ('Error occured while updating claim id', 'N', 1);
            ELSE
                COMMIT;

                BEGIN
                    print_log (
                           'on_acct_cust_id:'
                        || TO_CHAR (p_customer_id)
                        || ' on_acct_cust_site_use_id:'
                        || TO_CHAR (ln_bill_to_site_use_id)
                        || ' ln_rec_application_id:'
                        || TO_CHAR (ln_rec_application_id));

                    --Update AR Receivable Applications All
                    UPDATE ar_receivable_applications_all
                       SET on_acct_cust_id = p_customer_id, on_acct_cust_site_use_id = ln_bill_to_site_use_id, last_update_date = SYSDATE,
                           last_updated_by = fnd_global.user_id
                     WHERE     1 = 1
                           AND receivable_application_id =
                               ln_rec_application_id
                           AND application_type = 'CASH'
                           AND status = 'OTHER ACC'
                           AND display = 'Y'
                           AND applied_payment_schedule_id = -4;

                    print_log (
                           'cust_account_id:'
                        || TO_CHAR (p_customer_id)
                        || ' cust_billto_acct_site_id:'
                        || TO_CHAR (ln_bill_to_site_use_id)
                        || ' ln_sec_application_ref_id:'
                        || TO_CHAR (ln_sec_application_ref_id)
                        || ' lv_application_ref_num:'
                        || lv_application_ref_num);

                    --Update OZF Claims All
                    UPDATE ozf_claims_all
                       SET cust_account_id = p_customer_id, cust_billto_acct_site_id = ln_bill_to_site_use_id, claim_type_id = NVL (ln_claim_type_id, claim_type_id),
                           cust_shipto_acct_site_id = NULL, ship_to_cust_account_id = NULL, last_update_date = SYSDATE,
                           last_updated_by = fnd_global.user_id
                     WHERE 1 = 1 --AND claim_id = ln_sec_application_ref_id
                                 AND claim_number = lv_application_ref_num;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        print_log (
                               ' Error updating Customer details to claim:'
                            || SQLERRM);
                END;

                COMMIT;
                x_ret_code      := gn_success;
                x_ret_message   := ' Claim Creation Successful.';
                print_log (' Claim Creation Successful.' || lv_ret_message);
            END IF;
        ELSE
            x_ret_code   := gn_error;
            x_ret_message   :=
                   ' Error getting reason code id, receivable trx id or bill to site use id.'
                || lv_error_message;
            print_log (x_ret_message);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code   := gn_error;
            x_ret_message   :=
                   'Error occured in apply_other_account.'
                || ' '
                || SUBSTR (SQLERRM, 1, 1000);
            print_log (x_ret_message, 'N', 2);
    END apply_other_account;

    ----
    ----
    ---- Procedure for payment netting
    ----
    PROCEDURE apply_open_receipt (p_org_id IN NUMBER, p_customer_id IN NUMBER, p_cash_receipt_id IN NUMBER DEFAULT NULL, p_receipt_number IN VARCHAR2, p_open_cash_receipt_id IN NUMBER DEFAULT NULL, p_open_receipt_number IN VARCHAR2, p_amount_applied IN NUMBER, p_apply_date IN DATE, p_comments IN VARCHAR2 DEFAULT NULL
                                  , x_receivable_application_id OUT NUMBER, x_ret_code OUT NUMBER, x_ret_message OUT VARCHAR2)
    IS
        lv_return_status               VARCHAR2 (1);
        ln_msg_count                   NUMBER;
        lv_msg_data                    VARCHAR2 (240);
        ln_count                       NUMBER := 0;
        lv_application_ref_num         VARCHAR2 (30);
        ln_receivable_application_id   NUMBER;
        ln_applied_rec_app_id          NUMBER;
        ln_acctd_amount_applied_from   NUMBER;
        lv_acctd_amount_applied_to     VARCHAR2 (30);
        lv_proc_name                   VARCHAR2 (60) := 'APPLY_OPEN_RECEIPT';
        ln_org_id                      NUMBER := p_org_id;
        ln_resp_id                     NUMBER;
        lv_comments                    VARCHAR2 (100);
        ln_open_rct_onaccount          NUMBER;
        ln_open_rct_unapplied          NUMBER;
        ex_insufficient_balance        EXCEPTION;
        ex_unapply_error               EXCEPTION;
        ex_multi_open_receipts         EXCEPTION;
        ex_no_open_receipt             EXCEPTION;
        ln_ret_code                    NUMBER;
        lv_ret_message                 VARCHAR2 (2000);
        ln_open_receipt_id             NUMBER;
    BEGIN
        print_log (
               'Inside '
            || lv_proc_name
            || ' - '
            || ' p_org_id= '
            || TO_CHAR (p_org_id)
            || ' p_receipt_number= '
            || p_receipt_number
            || ' p_open_receipt_number= '
            || p_open_receipt_number
            || ' p_amount_applied= '
            || TO_CHAR (p_amount_applied)
            || ' p_apply_date= '
            || TO_CHAR (p_apply_date, 'DD-MON-YYYY'));
        ln_resp_id   := get_responsibility_id (ln_org_id);

        IF ln_resp_id IS NOT NULL
        THEN
            fnd_global.apps_initialize (
                user_id        => fnd_global.user_id,
                resp_id        => ln_resp_id,
                resp_appl_id   => fnd_global.resp_appl_id);
        END IF;

        mo_global.init ('AR');
        mo_global.set_policy_context ('S', ln_org_id);

        IF p_comments IS NOT NULL
        THEN
            SELECT --SUBSTR(regexp_replace(p_comments,'\[[^ ]+\]',''),1,100) as txt
                   SUBSTR (REGEXP_REPLACE (p_comments, '\[.+?\]\:'), 1, 100) AS txt
              INTO lv_comments
              FROM DUAL;
        END IF;

        BEGIN
            SELECT cr.cash_receipt_id
              INTO ln_open_receipt_id
              FROM apps.ar_cash_receipts_all cr
             WHERE     1 = 1
                   AND cr.pay_from_customer = p_customer_id
                   AND cr.receipt_number = p_open_receipt_number
                   AND cr.org_id = ln_org_id;

            print_log ('ln_open_receipt_id=' || TO_CHAR (ln_open_receipt_id));
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                RAISE ex_no_open_receipt;
            WHEN OTHERS
            THEN
                RAISE ex_multi_open_receipts;
        END;

        --get unapplied receipt balance
        ln_open_rct_unapplied   :=
            get_unapplied (p_org_id           => ln_org_id,
                           p_customer_id      => p_customer_id,
                           p_receipt_number   => p_open_receipt_number);

        --get_unapplied(ln_org_id,p_customer_id, p_open_receipt_number);
        IF ln_open_rct_unapplied < p_amount_applied * -1
        THEN
            --get onaccount balance
            ln_open_rct_onaccount   :=
                get_onaccount (p_org_id           => ln_org_id,
                               p_customer_id      => p_customer_id,
                               p_receipt_number   => p_open_receipt_number);

            IF ln_open_rct_onaccount + ln_open_rct_unapplied <
               p_amount_applied * -1
            THEN
                RAISE ex_insufficient_balance;
            ELSE
                ln_ret_code      := NULL;
                lv_ret_message   := NULL;
                unapply_on_account (
                    p_org_id           => ln_org_id,
                    p_customer_id      => p_customer_id,
                    p_receipt_number   => p_open_receipt_number,
                    x_ret_code         => ln_ret_code,
                    x_ret_message      => lv_ret_message);

                IF ln_ret_code <> gn_success
                THEN
                    RAISE ex_unapply_error;
                END IF;
            END IF;
        END IF;

        ar_receipt_api_pub.apply_open_receipt (
            p_api_version                 => 1.0,
            p_init_msg_list               => fnd_api.g_true,
            p_commit                      => fnd_api.g_true,
            p_validation_level            => fnd_api.g_valid_level_full,
            x_return_status               => lv_return_status,
            x_msg_count                   => ln_msg_count,
            x_msg_data                    => lv_msg_data,
            p_amount_applied              => p_amount_applied,
            p_cash_receipt_id             => p_cash_receipt_id,
            --p_receipt_number => p_receipt_number,--'receipt_on_receipt4',
            p_open_cash_receipt_id        => ln_open_receipt_id,
            --p_open_cash_receipt_id,
            --p_open_receipt_number => p_open_receipt_number,--'receipt_on_receipt3',
            p_apply_date                  => p_apply_date,
            p_apply_gl_date               => p_apply_date,
            p_comments                    => lv_comments,
            x_application_ref_num         => lv_application_ref_num,
            x_receivable_application_id   => ln_receivable_application_id,
            x_applied_rec_app_id          => ln_applied_rec_app_id,
            x_acctd_amount_applied_from   => ln_acctd_amount_applied_from,
            x_acctd_amount_applied_to     => lv_acctd_amount_applied_to);

        IF lv_return_status <> gv_ret_success                            --'S'
        THEN
            IF ln_msg_count = 1
            THEN
                print_log ('lv_msg_data ' || lv_msg_data);
                x_ret_code      := gn_error;
                x_ret_message   := lv_msg_data;
            ELSIF ln_msg_count > 1
            THEN
                LOOP
                    ln_count        := ln_count + 1;
                    lv_msg_data     :=
                        fnd_msg_pub.get (fnd_msg_pub.g_next, fnd_api.g_false);

                    IF lv_msg_data IS NULL
                    THEN
                        EXIT;
                    END IF;

                    print_log ('Message ' || ln_count || '. ' || lv_msg_data);
                    x_ret_code      := gn_error;
                    x_ret_message   := lv_msg_data;
                END LOOP;
            END IF;
        ELSE
            COMMIT;
            x_ret_code                    := gn_success;
            x_receivable_application_id   := ln_receivable_application_id;
        END IF;
    EXCEPTION
        WHEN ex_no_open_receipt
        THEN
            x_ret_code   := gn_error;
            x_ret_message   :=
                   ' Error in apply_open_receipt - Invalid Open Receipt ='
                || p_open_receipt_number;
            print_log (x_ret_message);
        WHEN ex_multi_open_receipts
        THEN
            x_ret_code   := gn_error;
            x_ret_message   :=
                   ' Error in apply_open_receipt - Multiple Open Receipts ='
                || p_open_receipt_number;
            print_log (x_ret_message);
        WHEN ex_insufficient_balance
        THEN
            x_ret_code   := gn_error;
            x_ret_message   :=
                   ' Error in apply_open_receipt - Insufficient Unapplied ='
                || TO_CHAR (ln_open_rct_unapplied)
                || ' and OnAccount ='
                || TO_CHAR (ln_open_rct_onaccount)
                || ' for payment netting';
            print_log (x_ret_message);
        WHEN ex_unapply_error
        THEN
            x_ret_code   := gn_error;
            x_ret_message   :=
                   ' Error in apply_open_receipt - Error Unapplying OnAccount for Receipt#'
                || p_open_receipt_number
                || ' OrgID#'
                || TO_CHAR (ln_org_id);
            print_log (x_ret_message);
        WHEN OTHERS
        THEN
            x_ret_code      := gn_error;
            x_ret_message   := ' Error in apply_open_receipt - ' || SQLERRM;
            print_log (x_ret_message);
    END apply_open_receipt;

    ----
    ----
    ---- Procedure to process receipt batches
    ----
    PROCEDURE process_batches (x_ret_code      OUT NUMBER,
                               x_ret_message   OUT VARCHAR2)
    IS
        CURSOR c_batch_cur IS
              SELECT a.org_id                                             --ou
                             , a.receipt_source_id, a.oracle_bank_branch_id,
                     a.receipt_batch_type, a.default_currency, a.oracle_bank_account_id,
                     a.depositdate                              --p_Batch_Date
                                  , a.receipt_class_id, a.receipt_method_id,
                     a.osbatchid, a.bankbatchid, COUNT (1) control_count,
                     SUM (a.checkamount) control_amount
                FROM (  SELECT org_id                                     --ou
                                     , receipt_source_id, oracle_bank_branch_id,
                               receipt_batch_type, default_currency, oracle_bank_account_id,
                               depositdate                      --p_Batch_Date
                                          , receipt_class_id, receipt_method_id,
                               checkno, checkamount, oracle_receipt_num,
                               osbatchid, bankbatchid
                          --, count(1) control_count
                          --, sum(checkamount) control_amount
                          FROM xxdo.xxdoar_b2b_cashapp_stg
                         WHERE     1 = 1
                               AND oracleprocessflag = 'V'
                               --AND org_id = NVL(p_org_id, org_id)
                               --AND jobid = NVL(p_bt_job_id, jobid)
                               AND oracle_batch_id IS NULL
                               AND oraclerequestid = gn_conc_request_id
                      GROUP BY org_id                                     --ou
                                     , receipt_source_id, oracle_bank_branch_id,
                               receipt_batch_type, default_currency, oracle_bank_account_id,
                               depositdate                      --p_Batch_Date
                                          , receipt_class_id, receipt_method_id,
                               checkno, checkamount, oracle_receipt_num,
                               osbatchid, bankbatchid) a
            GROUP BY a.org_id                                             --ou
                             , a.receipt_source_id, a.oracle_bank_branch_id,
                     a.receipt_batch_type, a.default_currency, a.oracle_bank_account_id,
                     a.depositdate                              --p_Batch_Date
                                  , a.receipt_class_id, a.receipt_method_id,
                     a.osbatchid, a.bankbatchid
            ORDER BY a.org_id;

        ex_batch_creation    EXCEPTION;
        ln_ret_code          NUMBER;
        lv_ret_message       VARCHAR2 (2000);
        lv_process_flag      VARCHAR2 (1);
        lv_process_message   VARCHAR2 (2000);
        ln_count             NUMBER := 0;
        ln_s_count           NUMBER := 0;
        ln_e_count           NUMBER := 0;
        lv_batch_name        VARCHAR2 (60);
        ln_batch_id          NUMBER;
        lv_proc_name         VARCHAR2 (30) := 'PROCESS_BATCHES';
        ld_receipt_date      DATE;
    BEGIN
        print_log ('--------------------process_batches--------------------');
        print_log ('Inside ' || lv_proc_name);

        FOR c_batch_rec IN c_batch_cur
        LOOP
            ln_count             := ln_count + 1;
            lv_batch_name        := NULL;
            ln_batch_id          := NULL;
            lv_process_flag      := NULL;
            lv_process_message   := NULL;
            --Added for change 2.1 - START
            --If deposit date is not in open period, then get the next open period start date and use it as receipt date
            validate_receipt_date (
                p_deposit_date   => c_batch_rec.depositdate + gn_grace_days,
                p_org_id         => c_batch_rec.org_id,
                x_receipt_date   => ld_receipt_date,
                x_ret_code       => ln_ret_code,
                x_ret_message    => lv_ret_message);

            --Added for change 2.1 - END
            --Added below if condition for change 2.1
            IF (ln_ret_code = gn_success AND ld_receipt_date IS NOT NULL)
            THEN
                BEGIN
                    mo_global.set_policy_context ('S', c_batch_rec.org_id);
                    create_receipt_batch (
                        p_org_id               => c_batch_rec.org_id,
                        p_batch_source_id      => c_batch_rec.receipt_source_id,
                        p_bank_branch_id       =>
                            c_batch_rec.oracle_bank_branch_id,
                        p_batch_type           => c_batch_rec.receipt_batch_type,
                        p_currency_code        => c_batch_rec.default_currency,
                        p_bank_account_id      =>
                            c_batch_rec.oracle_bank_account_id,
                        --p_Batch_Date        => c_batch_rec.depositdate+gn_grace_days  , --Commented for change 2.1
                        p_batch_date           => ld_receipt_date,
                        --Added for change 2.1
                        p_receipt_class_id     => c_batch_rec.receipt_class_id,
                        p_control_count        => c_batch_rec.control_count,
                        --p_GL_Date           => c_batch_rec.depositdate+gn_grace_days , --Commented for change 2.1
                        p_gl_date              => ld_receipt_date,
                        --Added for change 2.1
                        p_receipt_method_id    => c_batch_rec.receipt_method_id,
                        p_control_amount       => c_batch_rec.control_amount,
                        --p_Deposit_Date      => c_batch_rec.depositdate+gn_grace_days, --Commented for change 2.1
                        p_deposit_date         => ld_receipt_date,
                        --Added for change 2.1
                        p_lockbox_batch_name   =>
                            SUBSTR (c_batch_rec.bankbatchid, 1, 25),
                        p_comments             => c_batch_rec.osbatchid,
                        p_auto_commit          => 'Y',
                        x_batch_id             => ln_batch_id,
                        x_batch_name           => lv_batch_name,
                        x_ret_code             => ln_ret_code,
                        x_ret_message          => lv_ret_message);

                    IF ln_ret_code <> gn_success
                    THEN
                        lv_process_flag      := 'E';
                        lv_process_message   :=
                            'Batch Creation failed ' || lv_ret_message;
                        ln_e_count           := ln_e_count + 1;
                    ELSE
                        lv_process_flag      := 'B';
                        lv_process_message   := 'Batch#' || lv_batch_name;
                        ln_s_count           := ln_s_count + 1;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_process_flag      := 'E';
                        lv_process_message   :=
                            'Batch Creation failed ' || SQLERRM;
                        ln_e_count           := ln_e_count + 1;
                END;

                UPDATE xxdo.xxdoar_b2b_cashapp_stg
                   SET oracleprocessflag = lv_process_flag, oracleerrormessage = lv_process_message, oracle_batch_id = ln_batch_id
                 WHERE     1 = 1
                       AND org_id = c_batch_rec.org_id
                       AND receipt_source_id = c_batch_rec.receipt_source_id
                       AND oracle_bank_branch_id =
                           c_batch_rec.oracle_bank_branch_id
                       AND receipt_batch_type =
                           c_batch_rec.receipt_batch_type
                       AND default_currency = c_batch_rec.default_currency
                       AND oracle_bank_account_id =
                           c_batch_rec.oracle_bank_account_id
                       AND depositdate = c_batch_rec.depositdate
                       AND receipt_method_id = c_batch_rec.receipt_method_id
                       AND oraclerequestid = gn_conc_request_id
                       AND osbatchid = c_batch_rec.osbatchid
                       AND bankbatchid = c_batch_rec.bankbatchid
                       AND oracleprocessflag = 'V';
            END IF;            --ld_receipt_date end if --Added for change 2.1
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code      := gn_error;
            x_ret_message   := ' Error in process_batches - ' || SQLERRM;
            print_log (x_ret_message, 'Y', 2);
    END process_batches;

    ----
    ----
    ---- Procedure to create and process receipts
    ----
    PROCEDURE process_receipts (x_ret_code      OUT NUMBER,
                                x_ret_message   OUT VARCHAR2)
    IS
        CURSOR c_receipt_cur IS
              --Select Processed Batch Receipts
              SELECT org_id, receipt_source_id, oracle_bank_branch_id,
                     receipt_batch_type, default_currency, oracle_bank_account_id,
                     depositdate, receipt_class_id, receipt_method_id,
                     checkamount, checkno, envelopeid--, parentcustno
                                                     --, custno
                                                     ,
                     grand_billto_site_use_id, grandcustno--, use_brand_cust_flag
                                                          --, DECODE(use_brand_cust_flag,'Y',custno,parentcustno) customer_number
                                                          --, DECODE(use_brand_cust_flag,'Y',customer_id,parent_customer_id) receipt_customer_id
                                                          , creditidentifier2,
                     oracle_receipt_num, oracle_batch_id, envelopenotes
                FROM xxdo.xxdoar_b2b_cashapp_stg
               WHERE     1 = 1
                     AND oracleprocessflag IN ('B', 'V')
                     --AND org_id = NVL(p_org_id,org_id)--ou
                     --AND jobid = NVL(p_bt_job_id, jobid)
                     AND oracle_receipt_id IS NULL
                     AND oracle_batch_id IS NOT NULL
                     AND oraclerequestid = gn_conc_request_id
            GROUP BY org_id, receipt_source_id, oracle_bank_branch_id,
                     receipt_batch_type, default_currency, oracle_bank_account_id,
                     depositdate, receipt_class_id, receipt_method_id,
                     checkamount, checkno, envelopeid--, parentcustno
                                                     --, custno
                                                     ,
                     grand_billto_site_use_id, grandcustno--, use_brand_cust_flag
                                                          --, DECODE(use_brand_cust_flag,'Y',custno,parentcustno)
                                                          --, DECODE(use_brand_cust_flag,'Y',customer_id,parent_customer_id)
                                                          , creditidentifier2,
                     oracle_receipt_num, oracle_batch_id, envelopenotes;

        ex_receipt_creation   EXCEPTION;
        ln_ret_code           NUMBER;
        lv_ret_message        VARCHAR2 (2000);
        lv_process_flag       VARCHAR2 (1);
        lv_process_message    VARCHAR2 (2000);
        ln_count              NUMBER := 0;
        ln_s_count            NUMBER := 0;
        ln_e_count            NUMBER := 0;
        lv_batch_name         VARCHAR2 (60);
        ln_cash_receipt_id    NUMBER;
        lv_customer_number    VARCHAR2 (30);
        lv_proc_name          VARCHAR2 (30) := 'PROCESS_RECEIPTS';
        ld_receipt_date       DATE := NULL;
    BEGIN
        print_log (
            '--------------------process_receipts--------------------');
        print_log ('Inside ' || lv_proc_name);

        FOR c_receipt_rec IN c_receipt_cur
        LOOP
            mo_global.set_policy_context ('S', c_receipt_rec.org_id);
            print_log (
                'Oracle Receipt Num# ' || c_receipt_rec.oracle_receipt_num);
            ln_count             := ln_count + 1;
            lv_batch_name        := NULL;
            ln_cash_receipt_id   := NULL;
            lv_customer_number   := NULL;
            lv_process_flag      := NULL;
            lv_process_message   := NULL;
            /*
            IF c_receipt_rec.use_brand_cust_flag = 'N'
            THEN
              lv_customer_number := c_receipt_rec.parentcustno;
            ELSE
              lv_customer_number := c_receipt_rec.custno;
            END IF;
            */

            --Added for change 2.1 - START
            --If deposit date is not in open period, then get the next open period start date and use it as receipt date
            validate_receipt_date (
                p_deposit_date   => c_receipt_rec.depositdate + gn_grace_days,
                p_org_id         => c_receipt_rec.org_id,
                x_receipt_date   => ld_receipt_date,
                x_ret_code       => ln_ret_code,
                x_ret_message    => lv_ret_message);

            --Added for change 2.1 - END
            --Added below if condition for change 2.1
            IF (ln_ret_code = gn_success AND ld_receipt_date IS NOT NULL)
            THEN
                BEGIN
                    IF c_receipt_rec.grandcustno IS NOT NULL
                    THEN
                        --Create Receipts for Payments with customer/ Invoice information
                        create_receipt (
                            p_batch_id              => c_receipt_rec.oracle_batch_id,
                            p_receipt_number        =>
                                c_receipt_rec.oracle_receipt_num,
                            p_receipt_amt           => c_receipt_rec.checkamount,
                            p_customer_number       => c_receipt_rec.grandcustno,
                            --lv_customer_number ,
                            --p_customer_id              => c_receipt_rec.receipt_customer_id,
                            p_comments              =>
                                SUBSTR (c_receipt_rec.envelopenotes, 1, 2000),
                            p_currency_code         =>
                                c_receipt_rec.default_currency,
                            p_bill_to_site_use_id   =>
                                c_receipt_rec.grand_billto_site_use_id,
                            --p_receipt_date             => c_receipt_rec.depositdate + gn_grace_days, --Commented for change 2.1
                            p_receipt_date          => ld_receipt_date,
                            --Added for change 2.1
                            p_auto_commit           => 'Y',
                            x_cash_receipt_id       => ln_cash_receipt_id,
                            x_ret_code              => ln_ret_code,
                            x_ret_message           => lv_ret_message);

                        IF ln_ret_code <> gn_success
                        THEN
                            lv_process_flag      := 'E';
                            lv_process_message   :=
                                'Receipt Creation failed ' || lv_ret_message;
                            ln_e_count           := ln_e_count + 1;
                        ELSE
                            lv_process_flag      := 'R';
                            lv_process_message   :=
                                   'Receipt#'
                                || c_receipt_rec.oracle_receipt_num;
                            ln_s_count           := ln_s_count + 1;
                        END IF;
                    ELSE
                        --Create Miscellaneous Receipts for Payments without customer/ Invoice information
                        create_misc (
                            p_org_id            => c_receipt_rec.org_id,
                            p_batch_id          => c_receipt_rec.oracle_batch_id,
                            p_currency_code     =>
                                c_receipt_rec.default_currency,
                            p_amount            => c_receipt_rec.checkamount--,p_receipt_date         => c_receipt_rec.depositdate + gn_grace_days --Commented for change 2.1
                                                                            --,p_gl_date              => c_receipt_rec.depositdate + gn_grace_days --Commented for change 2.1
                                                                            ,
                            p_receipt_date      => ld_receipt_date--Added for change 2.1
                                                                  ,
                            p_gl_date           => ld_receipt_date--Added for change 2.1
                                                                  ,
                            p_receipt_method_id   =>
                                c_receipt_rec.receipt_method_id,
                            p_activity          => NULL,
                            p_comments          =>
                                SUBSTR (c_receipt_rec.envelopenotes, 1, 2000),
                            p_receipt_number    =>
                                c_receipt_rec.oracle_receipt_num,
                            p_auto_commit       => 'Y',
                            x_misc_receipt_id   => ln_cash_receipt_id,
                            x_ret_code          => ln_ret_code,
                            x_ret_message       => lv_ret_message);

                        IF ln_ret_code <> gn_success
                        THEN
                            lv_process_flag      := gv_ret_error;
                            lv_process_message   :=
                                'Receipt Creation failed ' || lv_ret_message;
                            ln_e_count           := ln_e_count + 1;
                        ELSE
                            lv_process_flag      := 'P';
                            lv_process_message   :=
                                   'Misc Receipt#'
                                || c_receipt_rec.oracle_receipt_num;
                            ln_s_count           := ln_s_count + 1;
                        END IF;                 --IF ln_ret_code <> gn_success
                    END IF;                --IF lv_customer_number IS NOT NULL
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_process_flag      := 'E';
                        lv_process_message   :=
                            'Receipt Creation failed ' || SQLERRM;
                        ln_e_count           := ln_e_count + 1;
                END;
            END IF;  --Receipt Date End If --Added if condition for change 2.1

            BEGIN
                UPDATE xxdo.xxdoar_b2b_cashapp_stg
                   SET oracleprocessflag = lv_process_flag, oracleerrormessage = lv_process_message, oracle_receipt_id = ln_cash_receipt_id
                 WHERE     1 = 1
                       AND oracle_batch_id = c_receipt_rec.oracle_batch_id
                       AND oracle_receipt_num =
                           c_receipt_rec.oracle_receipt_num
                       AND checkno = c_receipt_rec.checkno
                       AND checkamount = c_receipt_rec.checkamount
                       AND default_currency = c_receipt_rec.default_currency
                       AND NVL (grand_billto_site_use_id, -1) =
                           NVL (c_receipt_rec.grand_billto_site_use_id, -1)
                       AND grandcustno =
                           NVL (c_receipt_rec.grandcustno, grandcustno)
                       AND depositdate = c_receipt_rec.depositdate
                       AND envelopeid = c_receipt_rec.envelopeid
                       AND oraclerequestid = gn_conc_request_id
                       AND oracleprocessflag IN ('B', 'V');
            EXCEPTION
                WHEN OTHERS
                THEN
                    print_log (
                           ' Unable to update process flag for Oracle Receipt ID#'
                        || TO_CHAR (ln_cash_receipt_id)
                        || ' '
                        || SQLERRM);
            END;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code      := gn_error;
            x_ret_message   := ' Error in process_receipts - ' || SQLERRM;
            print_log (x_ret_message, 'Y', 2);
    END process_receipts;

    ----
    ----
    ---- Procedure to validate cashapp data loaded into staging
    ----
    PROCEDURE process_application (x_ret_code      OUT NUMBER,
                                   x_ret_message   OUT VARCHAR2)
    IS
        CURSOR c_app_cur IS
              SELECT *
                FROM xxdo.xxdoar_b2b_cashapp_stg
               WHERE     1 = 1
                     --AND oracleprocessflag = 'R'
                     AND oracleprocessflag IN ('R', 'V')
                     --AND org_id = NVL(p_org_id, org_id)--ou
                     -- AND jobid = NVL(p_bt_job_id, jobid)
                     --AND receivable_application_id IS NULL
                     AND oracle_batch_id IS NOT NULL
                     AND oracle_receipt_id IS NOT NULL
                     --AND oraclerequestid = NVL(p_load_request_id, oraclerequestid)
                     AND oraclerequestid = gn_conc_request_id
            ORDER BY org_id, oracle_batch_id, oracle_receipt_id,
                     invoiceamount;

        ex_receipt_creation     EXCEPTION;
        ln_ret_code             NUMBER;
        lv_ret_message          VARCHAR2 (2000);
        lv_process_flag         VARCHAR2 (1);
        lv_process_message      VARCHAR2 (2000);
        ln_count                NUMBER := 0;
        ln_s_count              NUMBER := 0;
        ln_e_count              NUMBER := 0;
        lv_batch_name           VARCHAR2 (60);
        ln_cash_receipt_id      NUMBER;
        lv_customer_number      VARCHAR2 (30);
        lv_seg_out              fnd_flex_ext.segmentarray;
        lv_delimiter            VARCHAR2 (1) := ',';
        ln_break_segs           NUMBER := 0;
        lv_bt_ded_code          VARCHAR2 (50);
        lv_bt_ded_amt           NUMBER;
        ln_reason_code_id       NUMBER;
        ln_application_ref_id   NUMBER;
        ln_app_ref_num          VARCHAR2 (240);
        ln_sec_app_ref_id       NUMBER;
        ln_receivable_app_id    NUMBER;
        ln_ret_code2            NUMBER;
        lv_ret_message2         VARCHAR2 (2000);
        ln_customer_id          NUMBER;
        lv_inv_status           VARCHAR2 (30);
        lv_proc_name            VARCHAR2 (30) := 'PROCESS_APPLICATION';
        lv_deduction_number     VARCHAR2 (240);
        ln_onaccount_amt        NUMBER;
        ln_applied_amt          NUMBER;
        ln_amt_due_remaining    NUMBER;
        lv_err_flag             VARCHAR2 (1) := 'N';    --Added for change 2.1
        ld_date                 DATE := NULL;           --Added for change 2.1
        lv_class                VARCHAR2 (10) := NULL;  --Added for change 2.2
    BEGIN
        print_log (
            '--------------------process_application--------------------');
        print_log ('Inside ' || lv_proc_name--||' - '||' p_org_id= '||TO_CHAR(p_org_id)
                                            --|| ' p_bt_job_id= '||p_bt_job_id
                                            --|| ' p_load_request_id= '||p_load_request_id
                                            );

        FOR c_app_rec IN c_app_cur
        LOOP
            print_log ('RecordID#' || c_app_rec.oraclerecordid);
            ln_count             := ln_count + 1;
            lv_process_flag      := 'P';
            lv_process_message   := NULL;
            ln_break_segs        := 0;
            lv_bt_ded_code       := NULL;
            lv_bt_ded_amt        := NULL;
            ln_reason_code_id    := NULL;
            ln_customer_id       := NULL;
            lv_inv_status        := NULL;
            ln_ret_code          := NULL;
            lv_ret_message       := NULL;
            -- Begin 2.3 Changes
            lv_err_flag          := 'N';
            ld_date              := NULL;
            -- End 2.3 Changes
            --Added for change 2.1 - START
            --If deposit date is not in open period, then get the next open period start date and use it as receipt date
            validate_receipt_date (
                p_deposit_date   => c_app_rec.depositdate + gn_grace_days,
                p_org_id         => c_app_rec.org_id,
                x_receipt_date   => ld_date,
                x_ret_code       => ln_ret_code,
                x_ret_message    => lv_ret_message);

            --Added for change 2.1 - END
            --Added below if condition for change 2.1
            IF (ln_ret_code = gn_success AND ld_date IS NOT NULL)
            THEN
                --print_log('Inside Process Application ');
                IF c_app_rec.use_brand_cust_flag = 'Y'
                THEN
                    ln_customer_id   := c_app_rec.customer_id;
                ELSE
                    ln_customer_id   := c_app_rec.parent_customer_id;
                END IF;

                BEGIN
                    print_log (
                           ' RecordID# '
                        || TO_CHAR (c_app_rec.oraclerecordid)
                        || ' Receipt# '
                        || c_app_rec.oracle_receipt_num
                        || ' Receiptamount# '
                        || c_app_rec.checkamount
                        || ' ReceiptID# '
                        || c_app_rec.oracle_receipt_id
                        || ' Invoice# '
                        || c_app_rec.invoicenumber
                        || ' Invoiceid# '
                        || c_app_rec.customer_trx_id
                        || ' InvoiceAmount# '
                        || c_app_rec.invoiceamount
                        || ' RemitIdentifier '
                        || c_app_rec.remitidentifier18
                        || ' DeductionCode '
                        || c_app_rec.deductioncode);

                    --If the application is On Account
                    IF c_app_rec.remitidentifier18 = 'O'
                    THEN
                        print_log (
                               'Before OnAccount Application - ReceiptID# '
                            || TO_CHAR (c_app_rec.oracle_receipt_id)
                            || ' Amount= '
                            || TO_CHAR (c_app_rec.invoiceamount));

                        IF TO_NUMBER (c_app_rec.invoiceamount) > 0
                        --Positive OnAccount Record - Apply on Account
                        THEN
                            IF c_app_rec.invoicenumber LIKE '%-%'
                            THEN
                                ln_customer_id   := c_app_rec.customer_id;
                            ELSE
                                ln_customer_id   :=
                                    c_app_rec.parent_customer_id;
                            END IF;

                            --Apply receipt on account
                            --Confirm if Checkamount or Invoiceamount to be used?
                            apply_on_account (
                                p_cash_receipt_id      =>
                                    c_app_rec.oracle_receipt_id,
                                p_amt_applied          =>
                                    TO_NUMBER (c_app_rec.invoiceamount),
                                p_customer_id          => ln_customer_id--,p_apply_date         => c_app_rec.depositdate + gn_grace_days --Commented for change 2.1
                                                                        ,
                                p_apply_date           => ld_date--Added for change 2.1
                                                                 ,
                                p_customer_reference   => c_app_rec.remitnotes,
                                x_ret_code             => ln_ret_code,
                                x_ret_message          => lv_ret_message);

                            IF ln_ret_code = gn_error
                            THEN
                                lv_process_flag      := 'E';
                                lv_process_message   := lv_ret_message;
                            ELSE
                                lv_process_flag        := 'P';
                                lv_process_message     := 'Applied On Account';
                                ln_receivable_app_id   := 0;
                            END IF;
                        ELSE   --Negative OnAccount Record - Create Cash claim
                            ln_application_ref_id   := NULL;
                            ln_app_ref_num          := NULL;
                            ln_sec_app_ref_id       := NULL;
                            ln_receivable_app_id    := NULL;

                            IF c_app_rec.invoicenumber LIKE '%-%'
                            THEN
                                ln_customer_id   := c_app_rec.customer_id;
                            ELSE
                                ln_customer_id   :=
                                    c_app_rec.parent_customer_id;
                            END IF;

                            --Create Cash Claim
                            apply_other_account (
                                p_reason_code                   => NULL,
                                --No deduction code
                                p_customer_id                   => ln_customer_id,
                                p_org_id                        => c_app_rec.org_id,
                                p_type                          => 'CLAIM_INVESTIGATION',
                                p_cash_receipt_id               =>
                                    c_app_rec.oracle_receipt_id,
                                p_receipt_number                =>
                                    c_app_rec.oracle_receipt_num,
                                p_amount_applied                =>
                                    TO_NUMBER (c_app_rec.invoiceamount),
                                p_applied_payment_schedule_id   => -4,
                                --p_apply_date                   => c_app_rec.depositdate+gn_grace_days, --Commented for change 2.1
                                --p_apply_gl_date                => c_app_rec.depositdate+gn_grace_days, --Commented for change 2.1
                                p_apply_date                    => ld_date,
                                --Added for change 2.1
                                p_apply_gl_date                 => ld_date,
                                --Added for change 2.1
                                p_application_ref_type          => 'CLAIM',
                                p_application_ref_id            =>
                                    ln_application_ref_id,
                                p_application_ref_num           =>
                                    ln_app_ref_num,
                                p_secondary_application_ref_id   =>
                                    ln_sec_app_ref_id,
                                p_customer_reference            =>
                                    c_app_rec.remitnotes,
                                p_called_from                   => NULL,
                                x_receivable_application_id     =>
                                    ln_receivable_app_id,
                                x_ret_code                      => ln_ret_code,
                                x_ret_message                   =>
                                    lv_ret_message);

                            IF ln_ret_code = gn_error
                            THEN
                                lv_process_flag      := 'E';
                                lv_process_message   := lv_ret_message;
                            ELSE
                                lv_process_flag   := 'P';
                                lv_process_message   :=
                                    'Cash Claim created for negative On Account';
                            END IF;
                        END IF;
                    --If the application is CashClaim
                    ELSIF c_app_rec.remitidentifier18 = 'C'
                    THEN
                        IF c_app_rec.deductioncode IS NOT NULL
                        THEN
                            ln_break_segs   :=
                                fnd_flex_ext.breakup_segments (
                                    c_app_rec.deductioncode,
                                    lv_delimiter,
                                    lv_seg_out);

                            IF ln_break_segs > 1
                            THEN
                                FOR i IN 1 .. ln_break_segs
                                LOOP
                                    IF     MOD (i, 2) = 0
                                       -- Only after the ded code and ded amount are picked
                                       AND NOT excluded_reason (
                                                   lv_seg_out (i - 1))
                                    --UPPER(lv_seg_out(i-1)) NOT IN ('ONACCOUNT','SURCHG')
                                    THEN
                                        ln_application_ref_id   := NULL;
                                        ln_app_ref_num          := NULL;
                                        ln_sec_app_ref_id       := NULL;
                                        ln_receivable_app_id    := NULL;
                                        ln_ret_code2            := NULL;
                                        lv_ret_message2         := NULL;
                                        print_log (
                                               ' p_reason_code# '
                                            || lv_seg_out (i - 1)
                                            || ' p_customer_id# '
                                            || TO_CHAR (ln_customer_id)
                                            || ' p_org_id# '
                                            || TO_CHAR (c_app_rec.org_id)
                                            || ' p_cash_receipt_id# '
                                            || TO_CHAR (
                                                   c_app_rec.oracle_receipt_id)
                                            || ' p_receipt_number# '
                                            || c_app_rec.oracle_receipt_num
                                            || ' p_amount_applied# '
                                            || TO_CHAR (
                                                     TO_NUMBER (
                                                         lv_seg_out (i))
                                                   * -1)
                                            || --' p_apply_date# '||TO_CHAR(c_app_rec.depositdate+gn_grace_days,'DD-MON-YYYY')|| --Commented for change 2.1
                                               ' p_apply_date# '
                                            || TO_CHAR (ld_date,
                                                        'DD-MON-YYYY')
                                            ||          --Added for change 2.1
                                               ' p_customer_reference# '
                                            || c_app_rec.remitnotes);

                                        IF c_app_rec.invoicenumber LIKE '%-%'
                                        THEN
                                            ln_customer_id   :=
                                                c_app_rec.customer_id;
                                        ELSE
                                            ln_customer_id   :=
                                                c_app_rec.parent_customer_id;
                                        END IF;

                                        --Create Cash Claim
                                        apply_other_account (
                                            p_reason_code     =>
                                                lv_seg_out (i - 1),
                                            p_customer_id     => ln_customer_id,
                                            p_org_id          =>
                                                c_app_rec.org_id,
                                            p_type            =>
                                                'CLAIM_INVESTIGATION',
                                            p_cash_receipt_id   =>
                                                c_app_rec.oracle_receipt_id,
                                            p_receipt_number   =>
                                                c_app_rec.oracle_receipt_num,
                                            p_amount_applied   =>
                                                  TO_NUMBER (lv_seg_out (i))
                                                * -1,
                                            p_applied_payment_schedule_id   =>
                                                -4,
                                            --p_apply_date                   => c_app_rec.depositdate+gn_grace_days, --Commented for change 2.1
                                            --p_apply_gl_date                => c_app_rec.depositdate+gn_grace_days, --Commented for change 2.1
                                            p_apply_date      => ld_date,
                                            --Added for change 2.1
                                            p_apply_gl_date   => ld_date,
                                            --Added for change 2.1
                                            p_application_ref_type   =>
                                                'CLAIM',
                                            p_application_ref_id   =>
                                                ln_application_ref_id,
                                            p_application_ref_num   =>
                                                ln_app_ref_num,
                                            p_secondary_application_ref_id   =>
                                                ln_sec_app_ref_id,
                                            p_customer_reference   =>
                                                c_app_rec.remitnotes,
                                            p_called_from     => NULL,
                                            x_receivable_application_id   =>
                                                ln_receivable_app_id,
                                            x_ret_code        => ln_ret_code2,
                                            x_ret_message     =>
                                                lv_ret_message2);

                                        IF ln_ret_code2 = gn_error
                                        THEN
                                            ln_ret_code   := gn_error;
                                            lv_ret_message   :=
                                                   lv_ret_message
                                                || lv_ret_message2;
                                        END IF;
                                    END IF;                  --IF MOD(i,2) = 0
                                END LOOP;

                                IF ln_ret_code = gn_error
                                THEN
                                    lv_process_flag   := 'E';
                                    lv_process_message   :=
                                        lv_process_message || lv_ret_message;
                                ELSE
                                    lv_process_flag   := 'P';
                                    lv_process_message   :=
                                        lv_process_message || lv_ret_message;
                                END IF;
                            ELSIF ln_break_segs = 1     --IF ln_break_segs > 1
                            THEN
                                lv_process_flag   := 'E';
                                lv_process_message   :=
                                       ' Invalid Cash Claim Ded Code:'
                                    || c_app_rec.deductioncode;
                            END IF;                     --IF ln_break_segs > 1
                        ELSE          --IF c_app_rec.deductioncode IS NOT NULL
                            --If No deduction code provided - Create a single cash claim with default
                            --deduction reason
                            ln_application_ref_id   := NULL;
                            ln_app_ref_num          := NULL;
                            ln_sec_app_ref_id       := NULL;
                            ln_receivable_app_id    := NULL;
                            ln_ret_code2            := NULL;
                            lv_ret_message2         := NULL;
                            print_log (
                                   ' p_reason_code# '
                                || 'NULL'
                                || ' p_customer_id# '
                                || TO_CHAR (ln_customer_id)
                                || ' p_org_id# '
                                || TO_CHAR (c_app_rec.org_id)
                                || ' p_cash_receipt_id# '
                                || TO_CHAR (c_app_rec.oracle_receipt_id)
                                || ' p_receipt_number# '
                                || c_app_rec.oracle_receipt_num
                                || ' p_amount_applied# '
                                || TO_CHAR (c_app_rec.deductionamt)
                                || --' p_apply_date# '||TO_CHAR(c_app_rec.depositdate+gn_grace_days,'DD-MON-YYYY') --Commented for change 2.1
                                   ' p_apply_date# '
                                || TO_CHAR (ld_date, 'DD-MON-YYYY')--Added for change 2.1
                                                                   );

                            IF c_app_rec.deductionamt IS NOT NULL
                            THEN
                                ln_ret_code      := NULL;
                                lv_ret_message   := NULL;

                                IF c_app_rec.invoicenumber LIKE '%-%'
                                THEN
                                    ln_customer_id   := c_app_rec.customer_id;
                                ELSE
                                    ln_customer_id   :=
                                        c_app_rec.parent_customer_id;
                                END IF;

                                --Create Cash Claim
                                apply_other_account (
                                    p_reason_code                   => NULL,
                                    --No deduction code
                                    p_customer_id                   => ln_customer_id,
                                    p_org_id                        => c_app_rec.org_id,
                                    p_type                          => 'CLAIM_INVESTIGATION',
                                    p_cash_receipt_id               =>
                                        c_app_rec.oracle_receipt_id,
                                    p_receipt_number                =>
                                        c_app_rec.oracle_receipt_num,
                                    p_amount_applied                =>
                                          TO_NUMBER (c_app_rec.deductionamt)
                                        * -1,
                                    p_applied_payment_schedule_id   => -4,
                                    --p_apply_date                   => c_app_rec.depositdate+gn_grace_days, --Commented for change 2.1
                                    --p_apply_gl_date                => c_app_rec.depositdate+gn_grace_days, --Commented for change 2.1
                                    p_apply_date                    => ld_date,
                                    --Added for change 2.1
                                    p_apply_gl_date                 => ld_date,
                                    --Added for change 2.1
                                    p_application_ref_type          => 'CLAIM',
                                    p_application_ref_id            =>
                                        ln_application_ref_id,
                                    p_application_ref_num           =>
                                        ln_app_ref_num,
                                    p_secondary_application_ref_id   =>
                                        ln_sec_app_ref_id,
                                    p_customer_reference            =>
                                        c_app_rec.remitnotes,
                                    p_called_from                   => NULL,
                                    x_receivable_application_id     =>
                                        ln_receivable_app_id,
                                    x_ret_code                      =>
                                        ln_ret_code,
                                    x_ret_message                   =>
                                        lv_ret_message);

                                IF ln_ret_code = gn_error
                                THEN
                                    lv_process_flag   := 'E';
                                    lv_process_message   :=
                                        lv_process_message || lv_ret_message;
                                ELSE
                                    lv_process_flag        := 'P';
                                    lv_process_message     :=
                                        'Cash Claim Created.';
                                    ln_receivable_app_id   := 0;
                                END IF;           --IF ln_ret_code2 = gn_error
                            END IF;
                        END IF;       --IF c_app_rec.deductioncode IS NOT NULL
                    --If the application is Surcharge
                    ELSIF c_app_rec.remitidentifier18 = 'S'
                    THEN
                        print_log (
                               ' p_cash_receipt_id# '
                            || TO_CHAR (c_app_rec.oracle_receipt_id)
                            || ' p_receivables_trx_id# '
                            || TO_CHAR (c_app_rec.receipt_writeoff_id)
                            || ' p_amount_applied# '
                            || TO_CHAR (c_app_rec.invoiceamount)
                            || ' p_customer_reference# '
                            || c_app_rec.remitnotes
                            || --' p_apply_date# '||TO_CHAR(c_app_rec.depositdate+gn_grace_days,'DD-MON-YYYY') --Commented for change 2.1
                               ' p_apply_date# '
                            || TO_CHAR (ld_date, 'DD-MON-YYYY')--Added for change 2.1
                                                               );
                        activity_application (
                            p_cash_receipt_id             => c_app_rec.oracle_receipt_id,
                            p_receivables_trx_id          =>
                                c_app_rec.receipt_writeoff_id,
                            p_amount_applied              => c_app_rec.invoiceamount--,p_apply_date                 => c_app_rec.depositdate+gn_grace_days --Commented for change 2.1
                                                                                    ,
                            p_apply_date                  => ld_date--Added for change 2.1
                                                                    ,
                            p_customer_reference          => c_app_rec.remitnotes,
                            x_receivable_application_id   =>
                                ln_receivable_app_id,
                            x_ret_code                    => ln_ret_code,
                            x_ret_message                 => lv_ret_message);

                        IF ln_ret_code = gn_error
                        THEN
                            lv_process_flag   := 'E';
                            lv_process_message   :=
                                   'Error in Writeoff Application for Surcharge - '
                                || lv_ret_message;
                        ELSE
                            lv_process_flag   := 'P';
                            lv_process_message   :=
                                'Writeoff for Surcharge Successful ';
                        END IF;
                    --Not On Account, Claims or Surcharge
                    ELSE
                        lv_inv_status    := NULL;
                        ln_ret_code      := NULL;
                        lv_ret_message   := NULL;

                        IF c_app_rec.customer_trx_id IS NOT NULL
                        THEN
                            print_log (
                                   'Before Apply Transaction - ReceiptID# '
                                || lv_inv_status
                                || TO_CHAR (c_app_rec.oracle_receipt_id)
                                || ' CustomerTrxID# '
                                || TO_CHAR (c_app_rec.customer_trx_id)
                                || ' Amount= '
                                || TO_CHAR (c_app_rec.invoiceamount));
                            ln_amt_due_remaining   := NULL;
                            ln_applied_amt         := NULL;
                            ln_onaccount_amt       := NULL;
                            lv_class               := NULL; --Added for change 2.2
                            get_trx_balance (
                                p_customer_trx_id     =>
                                    c_app_rec.customer_trx_id,
                                x_amt_due_remaining   => ln_amt_due_remaining,
                                x_class               => lv_class, --Added for change 2.2
                                x_ret_code            => ln_ret_code,
                                x_ret_message         => lv_ret_message);
                            print_log (
                                   ' Amount Due Remaining '
                                || ln_amt_due_remaining
                                || ' Application amount '
                                || c_app_rec.invoiceamount);

                            --Check if its overpay scenario
                            IF ln_amt_due_remaining IS NOT NULL
                            THEN
                                IF lv_class = 'CM' --Added condition for change 2.2
                                THEN
                                    --For credit memo take the amount fro staging table
                                    ln_applied_amt   :=
                                        TO_NUMBER (c_app_rec.invoiceamount);
                                ELSE
                                    IF ln_amt_due_remaining <
                                       TO_NUMBER (c_app_rec.invoiceamount)
                                    THEN
                                        ln_applied_amt   :=
                                            ln_amt_due_remaining;
                                        ln_onaccount_amt   :=
                                              TO_NUMBER (
                                                  c_app_rec.invoiceamount)
                                            - ln_applied_amt;
                                    ELSE
                                        ln_applied_amt   :=
                                            TO_NUMBER (
                                                c_app_rec.invoiceamount);
                                    END IF;
                                END IF;
                            END IF;

                            ln_ret_code            := NULL;
                            lv_ret_message         := NULL;
                            --Apply Receipt on Invoice number
                            apply_transaction (
                                p_cash_receipt_id      =>
                                    c_app_rec.oracle_receipt_id,
                                p_customer_trx_id      =>
                                    c_app_rec.customer_trx_id,
                                p_trx_number           => NULL,
                                p_applied_amt          => ln_applied_amt--TO_NUMBER(c_app_rec.invoiceamount)
                                                                        ,
                                p_discount             => NULL,
                                p_customer_reference   => c_app_rec.remitnotes,
                                p_auto_commit          => 'Y',
                                x_ret_code             => ln_ret_code,
                                x_ret_message          => lv_ret_message);
                            print_log (
                                   'After Apply Transaction - ReceiptID# '
                                || lv_inv_status
                                || TO_CHAR (c_app_rec.oracle_receipt_id)
                                || ' CustomerTrxID# '
                                || TO_CHAR (c_app_rec.customer_trx_id)
                                || ' Amount= '
                                || TO_CHAR (c_app_rec.invoiceamount)
                                || ' ln_ret_code= '
                                || TO_CHAR (ln_ret_code)
                                || ' lv_ret_message= '
                                || lv_ret_message);

                            IF ln_ret_code = gn_error
                            THEN
                                lv_process_flag      := 'E';
                                lv_process_message   :=
                                       'Error in Receipt application to Invoice '
                                    || lv_ret_message;
                                lv_err_flag          := 'Y'; --Added for change 2.1
                            ELSE
                                lv_process_flag   := 'P';
                                lv_process_message   :=
                                    'Receipt application to Invoice Successful ';
                            END IF;

                            --If OnAccount Amt
                            IF     ln_onaccount_amt IS NOT NULL
                               AND ln_ret_code <> gn_error
                            THEN
                                --APPLY ONACCOUNT
                                --Apply receipt on account
                                --Confirm if Checkamount or Invoiceamount to be used?
                                IF c_app_rec.invoicenumber LIKE '%-%'
                                THEN
                                    ln_customer_id   := c_app_rec.customer_id;
                                ELSE
                                    ln_customer_id   :=
                                        c_app_rec.parent_customer_id;
                                END IF;

                                ln_ret_code      := NULL;
                                lv_ret_message   := NULL;
                                apply_on_account (
                                    p_cash_receipt_id      =>
                                        c_app_rec.oracle_receipt_id,
                                    p_amt_applied          => ln_onaccount_amt--c_app_rec.invoiceamount
                                                                              ,
                                    p_customer_id          => ln_customer_id--,p_apply_date         => c_app_rec.depositdate + gn_grace_days  --Commented for change 2.1
                                                                            ,
                                    p_apply_date           => ld_date--Commented for change 2.1
                                                                     ,
                                    p_customer_reference   =>
                                        c_app_rec.remitnotes,
                                    x_ret_code             => ln_ret_code,
                                    x_ret_message          => lv_ret_message);

                                IF ln_ret_code = gn_error
                                THEN
                                    lv_process_flag      := 'E';
                                    lv_process_message   :=
                                           ' Error in applying balance to OnAccount '
                                        || lv_ret_message;
                                    lv_err_flag          := 'Y'; --Added for change 2.1
                                ELSE
                                    lv_process_flag   := 'P';
                                    lv_process_message   :=
                                        ' OnAccount application of the balance Successful';
                                END IF;
                            END IF;

                            ln_receivable_app_id   := NULL;
                            ln_ret_code            := NULL;
                            lv_ret_message         := NULL;

                            --Added IF Condition for change 2.1 (IF NVL(lv_err_flag, 'N') = 'N')
                            IF NVL (lv_err_flag, 'N') = 'N'
                            THEN
                                get_receivable_app_id (
                                    p_org_id              => c_app_rec.org_id,
                                    p_cash_receipt_id     =>
                                        c_app_rec.oracle_receipt_id,
                                    p_customer_trx_id     =>
                                        c_app_rec.customer_trx_id,
                                    x_receivable_app_id   =>
                                        ln_receivable_app_id,
                                    x_ret_code            => ln_ret_code,
                                    x_ret_message         => lv_ret_message);

                                IF ln_ret_code = gn_error
                                THEN
                                    lv_process_flag   := 'E';
                                    lv_process_message   :=
                                           'Unable to get receivable application id - '
                                        || lv_ret_message;
                                END IF;
                            END IF;

                            --IF NVL(lv_err_flag, 'N') = 'N' end if --Added for change 2.1

                            print_log (
                                   'After get_receivable_app_id - ReceiptID# '
                                || TO_CHAR (c_app_rec.oracle_receipt_id)
                                || ' CustomerTrxID# '
                                || TO_CHAR (c_app_rec.customer_trx_id)
                                || ' ln_receivable_app_id= '
                                || TO_CHAR (ln_receivable_app_id)
                                || ' ln_ret_code= '
                                || TO_CHAR (ln_ret_code)
                                || ' lv_ret_message= '
                                || lv_ret_message);
                        ELSIF c_app_rec.open_receipt_number IS NOT NULL
                        THEN
                            ln_ret_code      := NULL;
                            lv_ret_message   := NULL;

                            IF c_app_rec.invoiceamount < 0
                            THEN
                                apply_open_receipt (
                                    p_org_id        => c_app_rec.org_id,
                                    p_customer_id   => c_app_rec.customer_id,
                                    p_receipt_number   =>
                                        c_app_rec.oracle_receipt_num,
                                    p_cash_receipt_id   =>
                                        c_app_rec.oracle_receipt_id,
                                    p_open_receipt_number   =>
                                        c_app_rec.open_receipt_number,
                                    p_amount_applied   =>
                                        c_app_rec.invoiceamount--,p_apply_date                => c_app_rec.depositdate+gn_grace_days --Commented for change 2.1
                                                               ,
                                    p_apply_date    => ld_date--Added for change 2.1
                                                              ,
                                    p_comments      => c_app_rec.remitnotes,
                                    x_receivable_application_id   =>
                                        ln_receivable_app_id,
                                    x_ret_code      => ln_ret_code,
                                    x_ret_message   => lv_ret_message);
                            ELSE
                                --Apply On Account
                                apply_on_account (
                                    p_cash_receipt_id      =>
                                        c_app_rec.oracle_receipt_id,
                                    p_amt_applied          =>
                                        TO_NUMBER (c_app_rec.invoiceamount),
                                    p_customer_id          => c_app_rec.customer_id--ln_customer_id
                                                                                   --,p_apply_date         => c_app_rec.depositdate + gn_grace_days --Commented for change 2.1
                                                                                   ,
                                    p_apply_date           => ld_date--Added for change 2.1
                                                                     ,
                                    p_customer_reference   =>
                                        c_app_rec.remitnotes,
                                    x_ret_code             => ln_ret_code,
                                    x_ret_message          => lv_ret_message);
                            END IF;

                            IF ln_ret_code = gn_error
                            THEN
                                lv_process_flag   := 'E';
                                lv_process_message   :=
                                       ' Error in applying receipt on receipt '
                                    || lv_ret_message;
                            ELSE
                                lv_process_flag   := 'P';
                                lv_process_message   :=
                                    ' Payment Netting Successful';
                            END IF;
                        ELSE
                            lv_process_flag      := 'P';
                            lv_process_message   := ' No invoices to Apply. ';
                        END IF;

                        --END IF;

                        --Check if trx is still Open for deduction creation--Start
                        IF c_app_rec.customer_trx_id IS NOT NULL
                        THEN
                            ln_ret_code      := NULL;
                            lv_ret_message   := NULL;
                            is_open_trx (p_org_id => c_app_rec.org_id, p_customer_trx_id => c_app_rec.customer_trx_id, x_ret_code => ln_ret_code
                                         , x_ret_message => lv_ret_message);

                            IF ln_ret_code = gn_error
                            THEN
                                lv_process_flag   := 'P';
                                lv_process_message   :=
                                    'Invoice closed. Deduction application is skipped.';
                            END IF;
                        END IF;

                        --Check if trx is still Open for deduction creation--End
                        IF     c_app_rec.deductioncode IS NOT NULL
                           AND ln_receivable_app_id IS NOT NULL
                           AND ln_ret_code = gn_success       --IF trx is Open
                           AND c_app_rec.customer_trx_id IS NOT NULL
                        THEN
                            ln_break_segs   :=
                                fnd_flex_ext.breakup_segments (
                                    c_app_rec.deductioncode,
                                    lv_delimiter,
                                    lv_seg_out);
                            print_log (
                                   'Inside IF c_app_rec.deductioncode - Ded code# '
                                || c_app_rec.deductioncode
                                || ' lv_delimiter '
                                || lv_delimiter
                                || ' ln_break_segs '
                                || TO_CHAR (ln_break_segs),
                                'N',
                                1);

                            IF ln_break_segs > 1
                            THEN
                                FOR i IN 1 .. ln_break_segs
                                LOOP
                                    IF     MOD (i, 2) = 0
                                       -- Only after the ded code and ded amount are picked
                                       AND NOT excluded_reason (
                                                   lv_seg_out (i - 1))
                                    --UPPER(lv_seg_out(i-1)) NOT IN ('ONACCOUNT','SURCHG')
                                    THEN
                                        ln_ret_code2          := NULL;
                                        lv_ret_message2       := NULL;
                                        lv_deduction_number   := NULL;
                                        --Create Cash Claim
                                        create_trx_claim (
                                            p_org_id        => c_app_rec.org_id,
                                            p_receivable_app_id   =>
                                                ln_receivable_app_id,
                                            p_amount        =>
                                                TO_NUMBER (lv_seg_out (i)),
                                            p_reason        => lv_seg_out (i - 1),
                                            p_customer_reference   =>
                                                c_app_rec.remitnotes,
                                            x_deduction_number   =>
                                                lv_deduction_number,
                                            x_ret_code      => ln_ret_code2,
                                            x_ret_message   => lv_ret_message2);

                                        IF ln_ret_code2 = gn_error
                                        THEN
                                            ln_ret_code   := gn_error;
                                            lv_ret_message   :=
                                                   lv_ret_message
                                                || lv_ret_message2;
                                        END IF;
                                    END IF;                --End of if mod = 0
                                END LOOP;

                                IF ln_ret_code = gn_error
                                THEN
                                    lv_process_flag   := 'E';
                                    lv_process_message   :=
                                        lv_process_message || lv_ret_message;
                                ELSE
                                    lv_process_flag   := 'P';
                                END IF;
                            ELSIF ln_break_segs = 1
                            THEN
                                lv_process_flag   := 'E';
                                lv_process_message   :=
                                       'Invalid Deduction Code :'
                                    || c_app_rec.deductioncode;
                                print_log (
                                       'Inside IF ln_break_segs=1 - Ded code# '
                                    || c_app_rec.deductioncode
                                    || ' lv_delimiter '
                                    || lv_delimiter
                                    || ' ln_break_segs '
                                    || TO_CHAR (ln_break_segs));
                            END IF;
                        ELSIF     c_app_rec.deductioncode IS NULL
                              AND ln_receivable_app_id IS NOT NULL
                        THEN
                            lv_process_flag   := 'P';
                            lv_process_message   :=
                                'No deduction code found.';
                        END IF;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_process_flag      := 'E';
                        lv_process_message   :=
                               lv_process_message
                            || ' Invoice Application failed '
                            || SQLERRM;
                        ln_e_count           := ln_e_count + 1;
                END;

                BEGIN
                    print_log (
                           'Before Updating the record - Recordid# '
                        || TO_CHAR (c_app_rec.oraclerecordid)
                        || ' lv_process_flag '
                        || lv_process_flag
                        || ' lv_process_message '
                        || lv_process_message
                        || ' ln_receivable_app_id '
                        || TO_CHAR (ln_receivable_app_id)
                        || ' gn_conc_request_id '
                        || TO_CHAR (gn_conc_request_id));

                    UPDATE xxdo.xxdoar_b2b_cashapp_stg
                       SET oracleprocessflag = lv_process_flag, oracleerrormessage = lv_process_message, receivable_application_id = ln_receivable_app_id
                     WHERE     1 = 1
                           AND oraclerecordid = c_app_rec.oraclerecordid
                           AND oraclerequestid = gn_conc_request_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        print_log (
                               ' Error Updating RecordID#'
                            || TO_CHAR (c_app_rec.oraclerecordid)
                            || ' - '
                            || SQLERRM,
                            'N',
                            2);
                END;
            --Added for change 2.1 --START
            ELSE
                print_log (
                       ' Error in validating deposit date. Error is: '
                    || x_ret_message,
                    'N',
                    2);
            END IF;                                           --ld_date end if
        --Added for change 2.1 --END
        END LOOP;                                         --c_app_cur end loop

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code      := gn_error;
            x_ret_message   := ' Error in process_application - ' || SQLERRM;
            print_log (x_ret_message, 'Y', 2);
    END process_application;

    ----
    ----
    ---- Procedure to generate output
    ----
    PROCEDURE generate_output (x_ret_code      OUT NUMBER,
                               x_ret_message   OUT VARCHAR2)
    IS
        lv_status_meaning   VARCHAR2 (50) := NULL;
        lv_ou_name          VARCHAR2 (120) := NULL;
        lv_proc_name        VARCHAR2 (30) := 'GENERATE_OUTPUT';

        CURSOR c_error_cur IS
              SELECT *
                FROM xxdo.xxdoar_b2b_cashapp_stg
               WHERE     1 = 1
                     AND oraclerequestid = gn_conc_request_id
                     AND oracleprocessflag = 'E'
            ORDER BY oraclerecordid;

        CURSOR c_summary_cur IS
              SELECT inbound_filename--, oracleprocessflag
                                     , SUM (DECODE (oracleprocessflag, 'P', 1, 0)) processed_count, SUM (DECODE (NVL (oracleprocessflag, 'U'),  'E', 1,  'V', 1,  'N', 1,  'B', 1,  'R', 1,  'U', 1,  0)) error_count,
                     COUNT (1) record_count
                FROM xxdo.xxdoar_b2b_cashapp_stg
               WHERE 1 = 1 AND oraclerequestid = gn_conc_request_id
            GROUP BY inbound_filename                    --, oracleprocessflag
            ORDER BY inbound_filename                    --, oracleprocessflag
                                     ;

        /*
        SELECT inbound_filename
             , oracleprocessflag
             , DECODE
             , COUNT(1) record_count
          FROM xxdo.xxdoar_b2b_cashapp_stg
         WHERE 1=1
           AND oraclerequestid = gn_conc_request_id
         GROUP BY inbound_filename, oracleprocessflag
         ORDER BY inbound_filename, oracleprocessflag;
         */
        CURSOR c_details_cur IS
              SELECT                        --RemitIdentifier17 operating_unit
                     --, DECODE(use_brand_cust_flag,'Y',custno,parentcustno) customer_num
                     --,
                     grandcustno customer_num, NVL (creditidentifier3, default_payment_type) receipt_type, oracle_receipt_num,
                     checkamount, org_id, oracleprocessflag,
                     COUNT (1) record_count
                FROM xxdo.xxdoar_b2b_cashapp_stg
               WHERE 1 = 1 AND oraclerequestid = gn_conc_request_id
            GROUP BY                                       --RemitIdentifier17
                     --, DECODE(use_brand_cust_flag,'Y',custno,parentcustno)
                     --,
                     grandcustno, NVL (creditidentifier3, default_payment_type), oracle_receipt_num,
                     checkamount, org_id, oracleprocessflag
            ORDER BY 1, 2;

        ln_count            NUMBER := 0;
    BEGIN
        print_out (RPAD ('*', 98, '*'));
        print_out (
               RPAD ('FileName', 51, ' ')
            || RPAD ('Processed Count', 16, ' ')
            || RPAD ('Error Count', 16, ' ')
            || RPAD ('Record Count', 16, ' '));
        print_out (RPAD ('*', 98, '*'));

        FOR c_summary_rec IN c_summary_cur
        LOOP
            ln_count   := ln_count + 1;
            --lv_status_meaning := get_status_meaning (c_summary_rec.oracleprocessflag);
            print_out (
                   RPAD (c_summary_rec.inbound_filename, 50)
                || ' '
                || LPAD (c_summary_rec.processed_count, 15)
                || ' '
                || LPAD (c_summary_rec.error_count, 15)
                || ' '
                || LPAD (TO_CHAR (c_summary_rec.record_count), 15));
        END LOOP;

        IF ln_count = 0
        THEN
            print_out (LPAD ('***NO FILES FOUND TO PROCESS***', 49));
        END IF;

        print_out (RPAD ('*', 98, '*'));
        print_out (
            '------------------------- ------------------------------ ---------- ------------------------------ ---------- ----- -----------');
        print_out (
            'Operating Unit            Customer Number                Type       Receipt#                       Amount     Count ProcessFlag');
        print_out (RPAD ('-', 126, '-'));
        ln_count   := 0;

        FOR c_details_rec IN c_details_cur
        LOOP
            ln_count   := ln_count + 1;

            BEGIN
                SELECT NAME
                  INTO lv_ou_name
                  FROM hr_operating_units
                 WHERE 1 = 1 AND organization_id = c_details_rec.org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_ou_name   := ' - ';
            END;

            print_out (
                   RPAD (NVL (lv_ou_name, ' - '), 25)
                || ' '
                || RPAD (NVL (c_details_rec.customer_num, ' - '), 30)
                || ' '
                || RPAD (c_details_rec.receipt_type, 10)
                || ' '
                || RPAD (c_details_rec.oracle_receipt_num, 30)
                || ' '
                || LPAD (c_details_rec.checkamount, 10)
                || ' '
                || LPAD (c_details_rec.record_count, 5)
                || ' '
                || RPAD (NVL (c_details_rec.oracleprocessflag, 'U'), 11));
        END LOOP;

        IF ln_count = 0
        THEN
            print_out (LPAD ('***NO DATA FOUND***', 63));
        END IF;

        print_out (RPAD ('-', 126, '-'));
        print_log (RPAD ('-', 238, '-'), 'N', 2);
        print_log (
            '                                                                                           Error Record Details',
            'N',
            2);
        print_log (RPAD ('=', 238, '='));
        print_log (
            'RecordID   JobId Lockbox CheckNo   CheckAmount DepositDate Invoice#        InvoiceAmount DeductionCode DeductionAmt CreditIdentifier2 CreditIdentifier3 RemitIdentifier17 RemitIdentifier18 ErrorMessage',
            'N',
            2);
        print_log (RPAD ('-', 238, '-'), 'N', 2);
        ln_count   := 0;

        FOR c_error_rec IN c_error_cur
        LOOP
            ln_count   := ln_count + 1;
            print_log (
                   RPAD (TO_CHAR (c_error_rec.oraclerecordid), 10, ' ')
                || ' '
                || RPAD (c_error_rec.jobid, 5, ' ')
                || ' '
                || RPAD (SUBSTR (NVL (c_error_rec.lockbox, '-'), 1, 8),
                         8,
                         ' ')
                || ' '
                || RPAD (SUBSTR (NVL (c_error_rec.checkno, '-'), 1, 10),
                         10,
                         ' ')
                || ' '
                || LPAD (c_error_rec.checkamount, 10, ' ')
                || ' '
                || RPAD (c_error_rec.depositdate, 11, ' ')
                || ' '
                || RPAD (
                       SUBSTR (NVL (c_error_rec.invoicenumber, '-'), 1, 15),
                       15,
                       ' ')
                || ' '
                || LPAD (c_error_rec.invoiceamount, 13, ' ')
                || ' '
                || RPAD (
                       SUBSTR (NVL (c_error_rec.deductioncode, '-'), 1, 13),
                       13,
                       ' ')
                || ' '
                || LPAD (SUBSTR (c_error_rec.deductionamt, 1, 12), 12, ' ')
                || ' '
                || RPAD (
                       SUBSTR (NVL (c_error_rec.creditidentifier2, '-'),
                               1,
                               17),
                       17,
                       ' ')
                || ' '
                || RPAD (NVL (c_error_rec.creditidentifier3, '-'), 17, ' ')
                || ' '
                || RPAD (
                       SUBSTR (NVL (c_error_rec.remitidentifier17, '-'),
                               1,
                               17),
                       17,
                       ' ')
                || ' '
                || RPAD (NVL (c_error_rec.remitidentifier18, '-'), 17, ' ')
                || ' '
                || SUBSTR (c_error_rec.oracleerrormessage, 1, 50),
                'N',
                2);
        END LOOP;

        IF ln_count = 0
        THEN
            print_log (LPAD ('***NO DATA FOUND***', 119), 'N', 2);
        END IF;

        print_log (RPAD ('-', 238, '-'), 'N', 2);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code      := gn_error;
            x_ret_message   := ' Error in generate_output - ' || SQLERRM;
            print_log (x_ret_message, 'Y', 2);
    END generate_output;

    ----
    ----
    ---- Procedure to call the host program which
    ---- loads the file data into staging table using SQLLDR
    PROCEDURE load_cashapp_file (p_filepath IN VARCHAR2, x_ret_code OUT NUMBER, x_ret_message OUT VARCHAR2)
    IS
        lv_proc_name          VARCHAR2 (30) := 'LOAD_CASHAPP_FILE';
        lv_filepath           VARCHAR2 (120) := NULL;
        ln_load_req_id        NUMBER := 0;
        l_req_return_status   BOOLEAN;
        lc_phase              VARCHAR2 (30) := NULL;
        lc_status             VARCHAR2 (30) := NULL;
        lc_dev_phase          VARCHAR2 (30) := NULL;
        lc_dev_status         VARCHAR2 (30) := NULL;
        lc_message            VARCHAR2 (30) := NULL;
        lv_err_msg            VARCHAR2 (2000) := NULL;
    BEGIN
        print_log (
               'Inside '
            || lv_proc_name
            || ' - '
            || ' p_filepath= '
            || p_filepath);

        IF p_filepath IS NULL
        THEN
            BEGIN
                SELECT '/f01/' || applications_system_name || '/Inbound/Integrations/BillTrust/CashApp' file_path
                  INTO lv_filepath
                  FROM fnd_product_groups;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_filepath   := NULL;
            END;
        ELSE
            lv_filepath   := p_filepath;
        END IF;

        IF lv_filepath IS NOT NULL
        THEN
            --Submit concurrent program to send an email
            ln_load_req_id   :=
                fnd_request.submit_request (
                    application   => 'XXDO',
                    program       => 'XXDOAR_B2B_CASHAPP_FILES',
                    description   =>
                        'Program to Get Cash App Files and Load into Table',
                    start_time    => SYSDATE,
                    sub_request   => FALSE,
                    argument1     => lv_filepath);
            COMMIT;

            IF ln_load_req_id = 0
            THEN
                lv_err_msg      :=
                    SUBSTR (
                           'Get Cashapp Inbound Files concurrent request failed to submit. Please check SEND_NOTIFICATION procedure.'
                        || SQLERRM,
                        1,
                        2000);
                print_log (lv_err_msg, 'N', 1);
                x_ret_code      := gn_error;
                x_ret_message   := lv_err_msg;
            ELSE
                print_log (
                       'Successfully Submitted the Get Cashapp Inbound Files  Concurrent Request with request ID: '
                    || ln_load_req_id,
                    'N',
                    1);
            END IF;

            IF ln_load_req_id > 0
            THEN
                LOOP
                    --To make process execution to wait for 1st program to complete
                    l_req_return_status   :=
                        fnd_concurrent.wait_for_request (
                            request_id   => ln_load_req_id,
                            INTERVAL     => 5--Interval Number of seconds to wait between checks
                                             ,
                            max_wait     => 600               -- out arguments
                                               ,
                            phase        => lc_phase,
                            status       => lc_status,
                            dev_phase    => lc_dev_phase,
                            dev_status   => lc_dev_status,
                            MESSAGE      => lc_message);
                    EXIT WHEN    UPPER (lc_phase) = 'COMPLETED'
                              OR UPPER (lc_status) IN
                                     ('CANCELLED', 'ERROR', 'TERMINATED');
                END LOOP;
            END IF;
        ELSE
            --print_log('Send Email Notification concurrent request failed to submit', 'Y');
            lv_err_msg      := 'Unable to get the file path for inbound files';
            print_log (lv_err_msg, 'N', 1);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_err_msg      := ' Error in load_cashapp_file ' || SQLERRM;
            print_log (lv_err_msg, 'Y', 2);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
    END load_cashapp_file;

    ----
    ----
    ---- Procedure to validate cashapp data loaded into staging
    ----
    PROCEDURE validate_cashapp_data (p_org_id IN NUMBER, p_bt_job_id IN VARCHAR2, p_receipt_date_from IN VARCHAR2, p_receipt_date_to IN VARCHAR2, p_load_request_id IN NUMBER, p_reprocess_flag IN VARCHAR2
                                     , p_inbound_filename IN VARCHAR2, x_ret_code OUT NUMBER, x_ret_message OUT VARCHAR2)
    IS
        CURSOR c_cashapp_cur (p_ou_name IN VARCHAR2 DEFAULT NULL, p_deposit_date_from IN DATE DEFAULT NULL, p_deposit_date_to IN DATE DEFAULT NULL)
        IS
              SELECT *
                FROM xxdo.xxdoar_b2b_cashapp_stg
               WHERE     1 = 1
                     AND NVL (remitidentifier17, 'XXX') =
                         NVL (p_ou_name, NVL (remitidentifier17, 'XXX'))
                     AND jobid = NVL (p_bt_job_id, jobid)
                     --AND oraclerequestid = NVL(p_load_request_id, oraclerequestid)
                     AND oracleprocessflag =
                         DECODE (p_reprocess_flag,  'N', 'N',  'Y', 'E')
                     AND DECODE (p_reprocess_flag,
                                 'N', 'XXX',
                                 'Y', inbound_filename) =
                         DECODE (
                             p_reprocess_flag,
                             'N', 'XXX',
                             'Y', NVL (p_inbound_filename, inbound_filename))
                     AND TO_DATE (depositdate, 'DD-MON-YY') >=
                         NVL (p_deposit_date_from,
                              TO_DATE (depositdate, 'DD-MON-YY'))
                     AND TO_DATE (depositdate, 'DD-MON-YY') <=
                         NVL (p_deposit_date_to,
                              TO_DATE (depositdate, 'DD-MON-YY'))
            FOR UPDATE
            ORDER BY remitidentifier17, oraclerecordid;

        CURSOR c_customer (p_use_branded IN VARCHAR2, p_osbatchid IN VARCHAR2, p_checkno IN VARCHAR2
                           , p_depositdate IN VARCHAR2, p_checkamount IN VARCHAR2, p_envelopeid IN VARCHAR2)
        IS
              SELECT DECODE (p_use_branded, 'Y', custno, parentcustno) customer_num
                FROM xxdo.xxdoar_b2b_cashapp_stg
               WHERE     1 = 1
                     AND osbatchid = p_osbatchid
                     AND checkno = p_checkno
                     AND depositdate = p_depositdate
                     AND checkamount = p_checkamount
                     AND envelopeid = p_envelopeid
            GROUP BY DECODE (p_use_branded, 'Y', custno, parentcustno)
            ORDER BY 1;

        ln_ret_code                   NUMBER := 0;
        lv_ret_message                VARCHAR2 (2000);
        lv_process_flag               VARCHAR2 (1) := 'V';
        lv_error_message              VARCHAR2 (2000);
        ln_org_id                     NUMBER;
        ln_customer_id                NUMBER;
        ln_parent_cust_id             NUMBER;
        lv_ou_region                  VARCHAR2 (30);
        lv_use_brand_cust_flag        VARCHAR2 (1);
        lv_def_payment_type           VARCHAR2 (30);
        lv_def_curr_code              VARCHAR2 (30);
        ln_receipt_source_id          NUMBER;
        ln_receipt_method_id          NUMBER;
        ln_receipt_class_id           NUMBER;
        lv_receipt_num                VARCHAR2 (60);
        lv_err_msg                    VARCHAR2 (2000);
        ln_bank_id                    NUMBER;
        ln_bank_branch_id             NUMBER;
        ln_bank_account_id            NUMBER;
        ln_def_bank_account_id        NUMBER;
        lv_batch_type                 VARCHAR2 (60);
        ln_customer_trx_id            NUMBER;
        ln_bill_to_site_use_id        NUMBER;
        lv_ou_name                    VARCHAR2 (120);
        ln_set_of_books_id            NUMBER;
        lv_debug_step                 VARCHAR2 (10);
        lv_lockbox                    VARCHAR2 (15) := NULL;
        ln_receipt_writeoff_id        NUMBER;
        ln_def_org_id                 NUMBER;
        ln_invoice_balance            NUMBER;
        lv_open_receipt_number        VARCHAR2 (60);
        lv_proc_name                  VARCHAR2 (30) := 'VALIDATE_CASHAPP_DATA';
        lv_customer_num               VARCHAR2 (60);
        ln_x_customer_id              NUMBER;
        ln_grand_billto_site_use_id   NUMBER;
        ld_deposit_date_from          DATE;
        ld_deposit_date_to            DATE;
        ln_org_id1                    NUMBER;
        --Added for B2B Phase 2 EMEA Changes(CCR0006692)
        ln_bank_account_id1           NUMBER;
    --Added for B2B Phase 2 EMEA Changes(CCR0006692)
    BEGIN
        --validate operating unit
        --validate customer number
        --validate receipt number - customer number combo
        --

        --Print Parameters--
        /*
        p_org_id          IN  NUMBER,
        p_bt_job_id       IN  VARCHAR2,
        p_load_request_id IN  NUMBER ,
        p_reprocess_flag  IN  VARCHAR2,
        */
        print_log (
               'Inside '
            || lv_proc_name
            || ' - '
            || ' p_org_id= '
            || TO_CHAR (p_org_id)
            || ' p_bt_job_id= '
            || p_bt_job_id
            || ' p_receipt_date_from= '
            || p_receipt_date_from
            || ' p_receipt_date_to= '
            || p_receipt_date_to
            || ' p_load_request_id= '
            || p_load_request_id
            || ' p_reprocess_flag= '
            || p_reprocess_flag
            || ' p_inbound_filename='
            || p_inbound_filename);
        lv_debug_step   := '00100';

        IF p_org_id IS NOT NULL
        THEN
            SELECT NAME
              INTO lv_ou_name
              FROM hr_operating_units
             WHERE organization_id = p_org_id;
        END IF;

        lv_debug_step   := '00101';

        IF p_receipt_date_from IS NOT NULL AND p_receipt_date_to IS NOT NULL
        THEN
            ld_deposit_date_from   :=
                fnd_date.canonical_to_date (p_receipt_date_from);
            ld_deposit_date_to   :=
                fnd_date.canonical_to_date (p_receipt_date_to);
        END IF;

        --print_log('lv_debug_step='||lv_debug_step,'N',1);
        FOR c_cashapp_rec
            IN c_cashapp_cur (lv_ou_name,
                              ld_deposit_date_from,
                              ld_deposit_date_to)
        LOOP
            print_log ('==============================================',
                       'N',
                       2);
            print_log ('RecordID=' || c_cashapp_rec.oraclerecordid, 'N', 2);
            --Reset variables for the new recored
            lv_process_flag               := 'V';
            ln_bank_account_id1           := NULL;
            ln_org_id1                    := NULL;
            ln_org_id                     := NULL;
            ln_customer_id                := NULL;
            ln_parent_cust_id             := NULL;
            lv_ou_region                  := NULL;
            lv_use_brand_cust_flag        := 'Y';
            lv_def_payment_type           := NULL;
            lv_def_curr_code              := NULL;
            ln_receipt_source_id          := NULL;
            ln_receipt_method_id          := NULL;
            ln_receipt_writeoff_id        := NULL;
            ln_receipt_class_id           := NULL;
            lv_receipt_num                := NULL;
            ln_bank_id                    := NULL;
            ln_bank_branch_id             := NULL;
            ln_bank_account_id            := NULL;
            ln_def_bank_account_id        := NULL;
            lv_batch_type                 := NULL;
            ln_customer_trx_id            := NULL;
            ln_bill_to_site_use_id        := NULL;
            ln_set_of_books_id            := NULL;
            lv_lockbox                    := NULL;
            ln_def_org_id                 := NULL;
            lv_error_message              := NULL;
            ln_invoice_balance            := NULL;
            lv_open_receipt_number        := NULL;
            lv_customer_num               := NULL;
            ln_x_customer_id              := NULL;
            ln_grand_billto_site_use_id   := NULL;
            ln_ret_code                   := 0;
            lv_ret_message                := NULL;
            lv_debug_step                 := '00102';

            --print_log('lv_debug_step='||lv_debug_step,'N',1);
            BEGIN
                /*B2B Phase 2 EMEA Changes(CCR0006692) - Start*/
                IF c_cashapp_rec.lockbox IS NULL
                THEN
                    lv_process_flag   := gv_ret_error;
                    lv_error_message   :=
                        lv_error_message || ' Position5(Lockbox) Null. ';
                END IF;

                /*B2B Phase 2 EMEA Changes(CCR0006692) - End*/
                IF c_cashapp_rec.jobid IS NULL
                THEN
                    lv_process_flag    := gv_ret_error;
                    lv_error_message   := lv_error_message || ' JobID Null. ';
                END IF;

                IF c_cashapp_rec.depositdate IS NULL
                THEN
                    lv_process_flag   := gv_ret_error;
                    lv_error_message   :=
                        lv_error_message || ' DepositDate Null. ';
                END IF;

                IF c_cashapp_rec.checkamount IS NULL
                THEN
                    lv_process_flag   := gv_ret_error;
                    lv_error_message   :=
                        lv_error_message || ' CheckAmount Null. ';
                ELSIF TO_NUMBER (c_cashapp_rec.checkamount) < 0
                THEN
                    lv_process_flag   := gv_ret_error;
                    lv_error_message   :=
                        lv_error_message || ' Negative CheckAmount. ';
                END IF;

                /*
                IF c_cashapp_rec.remitidentifier18 = 'O'
                AND NVL(TO_NUMBER(c_cashapp_rec.checkamount),0) < NVL(TO_NUMBER(c_cashapp_rec.invoiceamount),0)
                THEN
                  lv_process_flag := gv_ret_error;
                  lv_error_message := lv_error_message||' OnAccount Application Amount is more than checkamount. ';
                END IF;
                */

                /*B2B Phase 2 EMEA Changes(CCR0006692) - Start*/
                ln_ret_code      := 0;
                lv_ret_message   := NULL;
                get_position5_details (
                    p_position5         => c_cashapp_rec.lockbox,
                    x_bank_account_id   => ln_bank_account_id1,
                    x_org_id            => ln_org_id1,
                    x_ret_code          => ln_ret_code,
                    x_ret_message       => lv_ret_message);
                /*B2B Phase 2 EMEA Changes(CCR0006692) - End*/
                ln_ret_code      := 0;
                lv_ret_message   := NULL;
                --Validate and get JOB ID details
                lv_debug_step    := '00107';
                get_jobid_details (
                    p_bt_job_id              => c_cashapp_rec.jobid,
                    x_default_payment_type   => lv_def_payment_type,
                    x_default_currency       => lv_def_curr_code,
                    x_default_org_id         => ln_def_org_id,
                    x_ret_code               => ln_ret_code,
                    x_ret_message            => lv_ret_message);

                --Commented by KK for change 2.1 --Remove comment later
                --                print_log(' x_default_payment_type='||lv_def_payment_type
                --                ||' x_default_currency='||lv_def_curr_code
                --                ||' x_ret_code='||ln_ret_code
                --                ||' x_ret_message='||lv_ret_message,'N',1);
                IF ln_ret_code = gn_error
                THEN
                    lv_process_flag    := gv_ret_error;
                    lv_error_message   := lv_error_message || lv_ret_message;
                END IF;

                ln_ret_code      := 0;
                lv_ret_message   := NULL;
                --Validate Operating Unit
                lv_debug_step    := '00103';
                --print_log('lv_debug_step='||lv_debug_step,'N',1);
                /*B2B Phase 2 EMEA Changes(CCR0006692) - Start*/
                --Org ID will now be picked based on Position5
                --instead of the earlier RemitIdentifier17
                /*
                IF c_cashapp_rec.RemitIdentifier17 IS NOT NULL
                THEN
                  get_org_id (p_org_name => c_cashapp_rec.RemitIdentifier17,
                              x_org_id   => ln_org_id ,
                              x_ret_code => ln_ret_code ,
                              x_ret_message => lv_ret_message);

                  IF ln_ret_code = gn_error
                  THEN
                    lv_process_flag := gv_ret_error;
                    lv_error_message := lv_error_message||lv_ret_message;
                  END IF;
                ELSE
                  ln_org_id := ln_def_org_id;
                END IF;
                */
                ln_org_id        := NVL (ln_org_id1, ln_def_org_id);
                /*B2B Phase 2 EMEA Changes(CCR0006692) - End*/
                ln_ret_code      := 0;
                lv_ret_message   := NULL;
                --Get Operating Unit region and whether branded account num to be used
                lv_debug_step    := '00104';
                --print_log('lv_debug_step='||lv_debug_step,'N',1);
                get_ou_region (p_org_id        => ln_org_id,
                               x_ou_region     => lv_ou_region,
                               x_use_branded   => lv_use_brand_cust_flag,
                               x_ret_code      => ln_ret_code,
                               x_ret_message   => lv_ret_message);

                IF ln_ret_code = gn_error
                THEN
                    lv_process_flag    := gv_ret_error;
                    lv_error_message   := lv_error_message || lv_ret_message;
                END IF;

                OPEN c_customer (p_use_branded   => lv_use_brand_cust_flag,
                                 p_osbatchid     => c_cashapp_rec.osbatchid,
                                 p_checkno       => c_cashapp_rec.checkno,
                                 p_depositdate   => c_cashapp_rec.depositdate,
                                 p_checkamount   => c_cashapp_rec.checkamount,
                                 p_envelopeid    => c_cashapp_rec.envelopeid);

                FETCH c_customer INTO lv_customer_num;

                CLOSE c_customer;

                print_log ('lv_customer_num:' || lv_customer_num);
                ln_ret_code      := NULL;
                lv_ret_message   := NULL;

                IF lv_customer_num IS NOT NULL
                THEN
                    get_customer_id (p_customer_num => lv_customer_num, x_cust_account_id => ln_x_customer_id, x_ret_code => ln_ret_code
                                     , x_ret_message => lv_ret_message);
                    print_log ('ln_x_customer_id:' || ln_x_customer_id);
                END IF;

                IF ln_ret_code = gn_error
                THEN
                    lv_process_flag    := gv_ret_error;
                    lv_error_message   := lv_error_message || lv_ret_message;
                END IF;

                ln_ret_code      := NULL;
                lv_ret_message   := NULL;

                IF c_cashapp_rec.custno IS NOT NULL
                THEN
                    get_customer_id (p_customer_num => c_cashapp_rec.custno, x_cust_account_id => ln_customer_id, x_ret_code => ln_ret_code
                                     , x_ret_message => lv_ret_message);

                    IF ln_ret_code = gn_error
                    THEN
                        lv_process_flag   := gv_ret_error;
                        lv_error_message   :=
                            lv_error_message || lv_ret_message;
                    END IF;
                END IF;

                ln_ret_code      := NULL;
                lv_ret_message   := NULL;

                IF c_cashapp_rec.parentcustno IS NOT NULL
                THEN
                    get_customer_id (p_customer_num => c_cashapp_rec.parentcustno, x_cust_account_id => ln_parent_cust_id, x_ret_code => ln_ret_code
                                     , x_ret_message => lv_ret_message);

                    IF ln_ret_code = gn_error
                    THEN
                        lv_process_flag   := gv_ret_error;
                        lv_error_message   :=
                            lv_error_message || lv_ret_message;
                    END IF;
                END IF;

                /*
                IF lv_use_brand_cust_flag = 'Y'
                THEN

                  IF ln_x_customer_id IS NOT NULL
                  THEN
                    ln_customer_id := ln_x_customer_id;
                    print_log('Ynotnullln_customer_id:'||ln_customer_id);

                  ELSE
                    ln_ret_code := NULL;
                    lv_ret_message := NULL;
                    get_customer_id( p_customer_num    => c_cashapp_rec.custno ,
                                     x_cust_account_id => ln_customer_id ,
                                     x_ret_code        => ln_ret_code ,
                                     x_ret_message     => lv_ret_message);
                    print_log('Ynullln_customer_id:'||ln_customer_id);
                    IF ln_ret_code = gn_error
                    THEN
                      lv_process_flag := gv_ret_error;
                      lv_error_message := lv_error_message||lv_ret_message;
                    END IF;

                  END IF;
                ELSE

                  IF ln_x_customer_id IS NOT NULL
                  THEN
                    ln_parent_cust_id := ln_x_customer_id;
                    print_log('Nnotnullln_customer_id:'||ln_parent_cust_id);
                  ELSE
                    ln_ret_code := NULL;
                    lv_ret_message := NULL;
                    get_customer_id( p_customer_num    => c_cashapp_rec.parentcustno ,
                                     x_cust_account_id => ln_parent_cust_id ,
                                     x_ret_code        => ln_ret_code ,
                                     x_ret_message     => lv_ret_message);
                    print_log('Nnullln_customer_id:'||ln_parent_cust_id);
                    IF ln_ret_code = gn_error
                    THEN
                      lv_process_flag := gv_ret_error;
                      lv_error_message := lv_error_message||lv_ret_message;
                    END IF;
                  END IF;
                END IF;
                */

                /*
                ln_ret_code := 0;
                lv_ret_message := NULL;

                --Validate Customer Number
                lv_debug_step := '00105';
                --print_log('lv_debug_step='||lv_debug_step,'N',1);

                IF  c_cashapp_rec.custno IS NOT NULL
                THEN
                  get_customer_id( p_customer_num    => c_cashapp_rec.custno ,
                                   x_cust_account_id => ln_customer_id ,
                                   x_ret_code        => ln_ret_code ,
                                   x_ret_message     => lv_ret_message);
                END IF;

                IF ln_ret_code = gn_error
                THEN
                  lv_process_flag := gv_ret_error;
                  lv_error_message := lv_error_message||lv_ret_message;
                END IF;

                ln_ret_code := 0;
                lv_ret_message := NULL;

                --Validate Parent Customer Number
                lv_debug_step := '00106';
                --print_log('lv_debug_step='||lv_debug_step,'N',1);

                IF  c_cashapp_rec.parentcustno IS NOT NULL
                THEN
                  get_customer_id( p_customer_num    => c_cashapp_rec.parentcustno ,
                                   x_cust_account_id => ln_parent_cust_id ,
                                   x_ret_code        => ln_ret_code ,
                                   x_ret_message     => lv_ret_message);
                END IF;

                IF ln_ret_code = gn_error
                THEN
                  lv_process_flag := gv_ret_error;
                  lv_error_message := lv_error_message||lv_ret_message;
                END IF;
                */
                ln_ret_code      := 0;
                lv_ret_message   := NULL;

                IF ln_x_customer_id IS NOT NULL
                THEN
                    get_site_use (
                        p_customer_id     => ln_x_customer_id,
                        p_org_id          => ln_org_id,
                        p_site_use_code   => 'BILL_TO',
                        x_site_use_id     => ln_grand_billto_site_use_id,
                        x_ret_code        => ln_ret_code,
                        x_ret_message     => lv_ret_message);

                    IF ln_ret_code = gn_error
                    THEN
                        lv_process_flag   := gv_ret_error;
                        lv_error_message   :=
                            lv_error_message || lv_ret_message;
                    END IF;
                END IF;

                ln_ret_code      := 0;
                lv_ret_message   := NULL;

                --Get Primary Bill TO Site use of the Customer ID
                IF NVL (lv_use_brand_cust_flag, 'Y') = 'Y'
                THEN
                    IF ln_customer_id IS NOT NULL
                    THEN
                        --Get Primary Bill to Site use for the customer
                        lv_debug_step   := '00106-1';
                        get_site_use (
                            p_customer_id     => ln_customer_id,
                            p_org_id          => ln_org_id,
                            p_site_use_code   => 'BILL_TO',
                            x_site_use_id     => ln_bill_to_site_use_id,
                            x_ret_code        => ln_ret_code,
                            x_ret_message     => lv_ret_message);
                    END IF;
                ELSE
                    IF ln_parent_cust_id IS NOT NULL
                    THEN
                        --Get Primary Bill to Site use for the customer
                        lv_debug_step   := '00106-2';
                        get_site_use (
                            p_customer_id     => ln_parent_cust_id,
                            p_org_id          => ln_org_id,
                            p_site_use_code   => 'BILL_TO',
                            x_site_use_id     => ln_bill_to_site_use_id,
                            x_ret_code        => ln_ret_code,
                            x_ret_message     => lv_ret_message);
                    END IF;
                END IF;

                IF ln_ret_code = gn_error
                THEN
                    lv_process_flag    := gv_ret_error;
                    lv_error_message   := lv_error_message || lv_ret_message;
                END IF;

                /*

                --Commenting because values in CreditIdentifier2 are Inconsistent
                --For Lockbox jobs 1,4 the value is null
                --Although, For Electronics jobs 3,6 account number is being sent
                --for jobid 3, in some cases EDI may send leading zeros and billtrust
                --doesnot have a way to fix it

                ln_ret_code := 0;
                lv_ret_message := NULL;

                --Validate and get bank account details
                lv_debug_step := '00109';
                print_log(' p_bank_account_num='||c_cashapp_rec.CreditIdentifier2
                          ||' p_bank_account_id'||ln_def_bank_account_id,'N',1);

                get_bank_details ( p_bank_account_num => c_cashapp_rec.CreditIdentifier2
                                 , p_bank_account_id  => NVL(ln_def_bank_account_id, ln_bank_account_id)
                                 , x_bank_id          => ln_bank_id
                                 , x_bank_branch_id   => ln_bank_branch_id
                                 , x_bank_account_id  => ln_bank_account_id
                                 , x_ret_code         => ln_ret_code
                                 , x_ret_message      => lv_ret_message);

                        print_log(' x_bank_id='||ln_bank_id
                        ||' x_bank_branch_id='||ln_bank_branch_id
                        ||' x_bank_account_id='||ln_bank_account_id
                        ||' x_ret_message='||lv_ret_message,'N',1);

                IF ln_ret_code = gn_error
                THEN
                  lv_process_flag := gv_ret_error;
                  lv_error_message := lv_error_message||lv_ret_message;
                END IF;
                */
                ln_ret_code      := 0;
                lv_ret_message   := NULL;
                --Validate and get receipt method details
                lv_debug_step    := '00108';
                print_log (
                       ' p_org_id='
                    || ln_org_id
                    || ' p_bank_id='
                    || ln_bank_id
                    || ' p_bank_branch_id='
                    || ln_bank_branch_id
                    || ' p_bank_account_id='
                    || ln_bank_account_id
                    || ' p_payment_type='
                    || NVL (c_cashapp_rec.creditidentifier3,
                            lv_def_payment_type)
                    || ' p_currency_code='
                    || lv_def_curr_code
                    || ' c_cashapp_rec.lockbox= '
                    || c_cashapp_rec.lockbox);
                /*
                IF c_cashapp_rec.lockbox IN ('EDI')
                THEN
                  lv_lockbox := NULL;
                ELSE
                  lv_lockbox := c_cashapp_rec.lockbox;
                END IF;
                */
                get_receipt_method (
                    p_org_id                => ln_org_id,
                    p_payment_type          =>
                        NVL (c_cashapp_rec.creditidentifier3,
                             lv_def_payment_type),
                    p_currency_code         => lv_def_curr_code,
                    p_lockbox_number        => c_cashapp_rec.lockbox,
                    x_bank_id               => ln_bank_id,
                    x_bank_branch_id        => ln_bank_branch_id,
                    x_bank_account_id       => ln_bank_account_id,
                    x_receipt_source_id     => ln_receipt_source_id,
                    x_receipt_method_id     => ln_receipt_method_id,
                    x_receipt_writeoff_id   => ln_receipt_writeoff_id,
                    x_ret_code              => ln_ret_code,
                    x_ret_message           => lv_ret_message);
                print_log (
                       ' p_org_id='
                    || ln_org_id
                    || ' p_bank_id='
                    || ln_bank_id
                    || ' p_bank_branch_id='
                    || ln_bank_branch_id
                    || ' p_bank_account_id='
                    || ln_bank_account_id
                    || ' p_payment_type='
                    || NVL (c_cashapp_rec.creditidentifier3,
                            lv_def_payment_type)
                    || ' p_currency_code='
                    || lv_def_curr_code,
                    'N',
                    1);

                IF ln_ret_code = gn_error
                THEN
                    lv_process_flag    := gv_ret_error;
                    lv_error_message   := lv_error_message || lv_ret_message;
                END IF;

                ln_ret_code      := 0;
                lv_ret_message   := NULL;
                lv_debug_step    := '00110';
                print_log (' p_batch_source_id=' || ln_receipt_source_id);
                get_batch_type (p_batch_source_id => ln_receipt_source_id, x_batch_type => lv_batch_type, x_ret_code => ln_ret_code
                                , x_ret_message => lv_ret_message);
                print_log (
                       ' x_batch_type='
                    || lv_batch_type
                    || ' x_ret_code='
                    || ln_ret_code
                    || ' x_ret_message='
                    || x_ret_message);

                IF ln_ret_code = gn_error
                THEN
                    lv_process_flag    := gv_ret_error;
                    lv_error_message   := lv_error_message || lv_ret_message;
                END IF;

                ln_ret_code      := 0;
                lv_ret_message   := NULL;
                --Validate and get receipt class details
                lv_debug_step    := '00111';
                get_receipt_class (p_receipt_method_id => ln_receipt_method_id, x_receipt_class_id => ln_receipt_class_id, x_ret_code => ln_ret_code
                                   , x_ret_message => lv_ret_message);

                IF ln_ret_code = gn_error
                THEN
                    lv_process_flag    := gv_ret_error;
                    lv_error_message   := lv_error_message || lv_ret_message;
                END IF;

                ln_ret_code      := 0;
                lv_ret_message   := NULL;
                --Validate if Receivables period is open
                lv_debug_step    := '00112';
                validate_gl_accounting_date (
                    p_accounting_date   =>
                        c_cashapp_rec.depositdate + gn_grace_days,
                    p_org_id        => ln_org_id,
                    x_sob_id        => ln_set_of_books_id,
                    x_ret_code      => ln_ret_code,
                    x_ret_message   => lv_ret_message);

                IF ln_ret_code = gn_error
                THEN
                    lv_process_flag    := gv_ret_error;
                    lv_error_message   := lv_error_message || lv_ret_message;
                END IF;

                ln_ret_code      := 0;
                lv_ret_message   := NULL;

                --Create Receipt Num based on the logic
                /*
                lv_debug_step := '00113';

                print_log(' p_org_id='||ln_org_id
                        ||' p_receipt_date='||c_cashapp_rec.DepositDate
                        ||' p_receipt_amt='||c_cashapp_rec.CheckAmount
                        ||' p_payment_type='||NVL(c_cashapp_rec.CreditIdentifier3,lv_def_payment_type)
                        );*/

                --Commented for change 2.1 - START (create_receipt_num)
                --Instead of creating receipt number (Deriving and updating) for every line, Now doing it for each envelope id
                --Moved this logic to VALIDATE_RECEIPT_NUM procedure which is called right after VALIDATE_CASHAPP_DATA procedure in PROCESS_CASHAPP_DATA procedure
                /*
                create_receipt_num (p_org_id          => ln_org_id ,
                                    p_receipt_date    => c_cashapp_rec.DepositDate+gn_grace_days , --Commented for change 2.1
                                    p_receipt_amt     => c_cashapp_rec.CheckAmount ,
                                    p_payment_type    => NVL(c_cashapp_rec.CreditIdentifier3,lv_def_payment_type) ,
                                    p_receipt_num     => c_cashapp_rec.oracle_receipt_num,
                                    p_receipt_id      => c_cashapp_rec.oracle_receipt_id,
                                    p_checkno         => c_cashapp_rec.checkno,
                                    x_receipt_num     => lv_receipt_num ,
                                    x_ret_code        => ln_ret_code ,
                                    x_ret_message     => lv_ret_message);

                print_log(' p_org_id='||ln_org_id
                        ||' p_receipt_date='||c_cashapp_rec.DepositDate
                        ||' p_receipt_amt='||c_cashapp_rec.CheckAmount
                        ||' p_payment_type='||NVL(c_cashapp_rec.CreditIdentifier3,lv_def_payment_type)
                        ||' lv_receipt_num='||lv_receipt_num
                        ||' ln_ret_code='||ln_ret_code
                        ||' lv_ret_message='||lv_ret_message);

                IF ln_ret_code = gn_error
                THEN
                  lv_process_flag := gv_ret_error;
                  lv_error_message := lv_error_message||lv_ret_message;
                END IF;
                */
                --Commented for change 2.1 - END (create_receipt_num)
                IF     UPPER (NVL (c_cashapp_rec.invoicenumber, 'XXX')) NOT IN
                           ('UNKNOWN', 'XXX')
                   AND UPPER (NVL (c_cashapp_rec.remitidentifier18, 'X')) NOT IN
                           ('O', 'S', 'C')
                THEN
                    --Validate and get invoice id
                    lv_debug_step    := '00114';
                    --print_log(' lv_debug_step='||lv_debug_step);
                    ln_ret_code      := 0;
                    lv_ret_message   := NULL;
                    get_invoice_id (p_trx_number => c_cashapp_rec.invoicenumber, p_org_id => ln_org_id, p_customer_id => ln_customer_id, x_customer_trx_id => ln_customer_trx_id, x_receipt_number => lv_open_receipt_number, x_ret_code => ln_ret_code
                                    , x_ret_message => lv_ret_message);
                    print_log (
                           'p_trx_number:'
                        || c_cashapp_rec.invoicenumber
                        || ' p_org_id:'
                        || ln_org_id
                        || ' x_customer_trx_id:'
                        || ln_customer_trx_id
                        || ' lv_open_receipt_number:'
                        || lv_open_receipt_number
                        || ' x_ret_code:'
                        || ln_ret_code
                        || ' x_ret_message:'
                        || lv_ret_message);

                    IF ln_ret_code = gn_error
                    THEN
                        lv_process_flag   := gv_ret_error;
                        lv_error_message   :=
                            lv_error_message || lv_ret_message;
                    END IF;
                END IF;

                IF     NVL (c_cashapp_rec.remitidentifier18, 'X') = 'S'
                   AND ln_receipt_writeoff_id IS NULL
                THEN
                    lv_process_flag   := gv_ret_error;
                    lv_error_message   :=
                           lv_error_message
                        || ' Surcharge Writeoff activity not found. ';
                END IF;

                print_log (
                       'Error Flag:'
                    || lv_process_flag
                    || ' Error Message:'
                    || lv_error_message);

                IF ln_customer_trx_id IS NOT NULL
                THEN
                    /*B2B Phase 2 EMEA Changes(CCR0006692) - Start*/
                    --This check will now be performed post receipt creation
                    /*
                    ln_ret_code := NULL;
                    lv_ret_message := NULL;

                    print_log('Checking if Trx is Open - '
                             ||' ln_org_id:'||ln_org_id
                             ||' ln_customer_trx_id:'||ln_customer_trx_id);

                    is_open_trx (p_org_id           => ln_org_id,
                                 p_customer_trx_id  => ln_customer_trx_id,
                                 x_ret_code         => ln_ret_code,
                                 x_ret_message      => lv_ret_message);

                    print_log('Checking if Trx is Open - '
                             ||' ln_org_id:'||ln_org_id
                             ||' ln_customer_trx_id:'||ln_customer_trx_id
                             ||' ln_ret_code:'||ln_ret_code
                             ||' lv_ret_message:'||lv_ret_message
                             );

                    IF ln_ret_code = gn_error
                    THEN
                      lv_process_flag := gv_ret_error;
                      lv_error_message := lv_error_message||lv_ret_message;
                    END IF;
                    */
                    /*B2B Phase 2 EMEA Changes(CCR0006692) - End*/
                    ln_ret_code      := NULL;
                    lv_ret_message   := NULL;
                    validate_customer_relation (
                        p_customer_id       => ln_x_customer_id,
                        p_customer_trx_id   => ln_customer_trx_id,
                        x_ret_code          => ln_ret_code,
                        x_ret_message       => lv_ret_message);

                    IF ln_ret_code = gn_error
                    THEN
                        lv_process_flag   := gv_ret_error;
                        lv_error_message   :=
                            lv_error_message || lv_ret_message;
                        print_log (lv_error_message);
                    END IF;

                    ln_ret_code      := NULL;
                    lv_ret_message   := NULL;
                    get_invoice_balance (p_customer_trx_id => ln_customer_trx_id, x_amt_due_remaining => ln_invoice_balance, x_ret_code => ln_ret_code
                                         , x_ret_message => lv_ret_message);

                    IF ln_ret_code = gn_error
                    THEN
                        lv_process_flag   := gv_ret_error;
                        lv_error_message   :=
                            lv_error_message || lv_ret_message;
                        print_log (lv_error_message);
                    END IF;
                END IF;

                /*
                print_log(' lv_open_receipt_number: '||lv_open_receipt_number||' invoiceamount:'||c_cashapp_rec.invoiceamount);

                IF lv_open_receipt_number IS NOT NULL
                AND To_NUMBER(c_cashapp_rec.invoiceamount) > 0
                THEN
                  lv_process_flag := gv_ret_error;
                  lv_error_message := lv_error_message||' For payment netting, Amount applied must be less than zero.';
                  print_log(lv_error_message);
                END IF;
                */
                print_log (
                       ' lv_open_receipt_number:'
                    || lv_open_receipt_number
                    || ' ln_customer_id:'
                    || ln_customer_id
                    || ' ln_org_id:'
                    || ln_org_id);

                IF lv_open_receipt_number IS NOT NULL
                THEN
                    ln_ret_code      := NULL;
                    lv_ret_message   := NULL;

                    IF NVL (lv_use_brand_cust_flag, 'Y') = 'Y'
                    THEN
                        --Validate customer relation with the customer
                        validate_customer_relation (
                            p_customer_id      => ln_customer_id,
                            p_receipt_number   => lv_open_receipt_number,
                            p_org_id           => ln_org_id,
                            x_ret_code         => ln_ret_code,
                            x_ret_message      => lv_ret_message);
                    ELSE
                        --Validate customer relation with the parent customer
                        validate_customer_relation (
                            p_customer_id      => ln_parent_cust_id,
                            p_receipt_number   => lv_open_receipt_number,
                            p_org_id           => ln_org_id,
                            x_ret_code         => ln_ret_code,
                            x_ret_message      => lv_ret_message);
                    END IF;

                    IF ln_ret_code = gn_error
                    THEN
                        lv_process_flag   := gv_ret_error;
                        lv_error_message   :=
                            lv_error_message || lv_ret_message;
                        print_log (lv_error_message);
                    END IF;
                END IF;

                print_log (
                       'Error Flag:'
                    || lv_process_flag
                    || ' Error Message:'
                    || lv_error_message);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_process_flag   := 'E';
                    lv_error_message   :=
                           'Error in Validation - '
                        || lv_debug_step
                        || ' '
                        || SQLERRM;
                    print_log (lv_error_message, 'Y', 1);
            END;

            --print_log('Error Flag:'||lv_process_flag||' Error Message:'||lv_error_message);
            lv_debug_step                 := '00115';

            BEGIN
                UPDATE xxdo.xxdoar_b2b_cashapp_stg
                   SET org_id = ln_org_id, customer_id = ln_customer_id, parent_customer_id = ln_parent_cust_id,
                       ou_region = lv_ou_region, use_brand_cust_flag = lv_use_brand_cust_flag, default_payment_type = lv_def_payment_type,
                       default_currency = lv_def_curr_code, receipt_source_id = ln_receipt_source_id, receipt_method_id = ln_receipt_method_id,
                       receipt_writeoff_id = ln_receipt_writeoff_id, receipt_class_id = ln_receipt_class_id, oracle_receipt_num = lv_receipt_num,
                       oracle_bank_id = ln_bank_id, oracle_bank_branch_id = ln_bank_branch_id, oracle_bank_account_id = ln_bank_account_id,
                       receipt_batch_type = lv_batch_type, customer_trx_id = ln_customer_trx_id, bill_to_site_use_id = ln_bill_to_site_use_id,
                       set_of_books_id = ln_set_of_books_id, invoice_balance = ln_invoice_balance, open_receipt_number = lv_open_receipt_number,
                       oraclerequestid = gn_conc_request_id, oracleprocessflag = lv_process_flag, oracleerrormessage = lv_error_message,
                       grand_customer_id = ln_x_customer_id, grandcustno = lv_customer_num, grand_billto_site_use_id = ln_grand_billto_site_use_id
                 WHERE     1 = 1
                       AND oraclerecordid = c_cashapp_rec.oraclerecordid;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_err_msg   :=
                           ' Error in updating recordid# '
                        || c_cashapp_rec.oraclerecordid
                        || '-'
                        || lv_debug_step
                        || ' '
                        || SQLERRM;
                    print_log (lv_err_msg);
            END;

            lv_debug_step                 := '00116';
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_err_msg      :=
                   ' Error in validate_cashapp_data '
                || lv_debug_step
                || ' '
                || SQLERRM;
            print_log (lv_err_msg, 'N', 2);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
    END validate_cashapp_data;

    ----
    ----
    ---- Procedure to process valid cashapp data in the staging
    PROCEDURE process_cashapp_data (
        errbuf                   OUT NUMBER,
        retcode                  OUT VARCHAR2,
        p_org_id              IN     NUMBER,
        p_bt_job_id           IN     NUMBER,
        p_receipt_date_from   IN     VARCHAR2,
        p_receipt_date_to     IN     VARCHAR2,
        p_load_request_id     IN     NUMBER,
        p_grace_days          IN     NUMBER DEFAULT 0,
        --p_receipt_method    IN  VARCHAR2 ,
        --p_receipt_type      IN  VARCHAR2 ,
        --p_receipt_num       IN  VARCHAR2 ,
        --p_bank_account      IN  VARCHAR2 ,
        --p_receipt_date_from IN  VARCHAR2 ,
        --p_customer          IN  VARCHAR2 ,
        --p_currency          IN  VARCHAR2 ,
        p_reprocess_flag      IN     VARCHAR2,
        p_inbound_filename    IN     VARCHAR2,
        p_debug_mode          IN     VARCHAR2--p_file_path         IN  VARCHAR2,
                                             )
    IS
        CURSOR c_b2b_orgs_curs IS
            SELECT hou.organization_id, hou.NAME
              FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values ffv, apps.hr_operating_units hou
             WHERE     1 = 1
                   AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                   AND ffvs.flex_value_set_name =
                       'XXDOAR_B2B_OPERATING_UNITS'
                   AND ffv.enabled_flag = 'Y'
                   AND ffv.flex_value = TO_CHAR (hou.organization_id)
                   AND NVL (start_date_active, SYSDATE) <= SYSDATE
                   AND NVL (end_date_active, SYSDATE) >= SYSDATE;

        lv_proc_name     VARCHAR2 (30) := 'PROCESS_CASHAPP_DATA';
        lv_err_msg       VARCHAR2 (2000) := NULL;
        ln_ret_code      NUMBER;
        lv_ret_message   VARCHAR2 (2000);
        ex_validation    EXCEPTION;
        ex_batches       EXCEPTION;
        ex_receipts      EXCEPTION;
        ex_application   EXCEPTION;
        ex_output        EXCEPTION;
    BEGIN
        print_log (
               'Inside '
            || lv_proc_name
            || ' - '
            || ' p_org_id= '
            || TO_CHAR (p_org_id)
            || ' p_bt_job_id= '
            || p_bt_job_id
            || ' p_receipt_date_from= '
            || p_receipt_date_from
            || ' p_receipt_date_to= '
            || p_receipt_date_to
            || ' p_load_request_id= '
            || p_load_request_id
            || ' p_reprocess_flag= '
            || p_reprocess_flag
            || ' p_grace_days= '
            || p_grace_days
            || ' p_debug_mode= '
            || p_debug_mode);
        mo_global.init ('AR');

        IF p_debug_mode = 'Y'
        THEN
            gn_debug_level   := 0;
        ELSE
            gn_debug_level   := 1;
        END IF;

        gn_reprocess_flag   := p_reprocess_flag;
        gn_grace_days       := p_grace_days;
        --print_log('Inside Process Cashapp - Before Validate','Y',2); --Commented for change 2.1
        print_log (
            'Inside Process Cashapp - Validate Cashapp Data(Validate_cashapp_data) - START',
            'Y',
            2);                                         --Added for change 2.1
        --Validate data
        ln_ret_code         := NULL;
        lv_ret_message      := NULL;
        validate_cashapp_data (p_org_id              => p_org_id,
                               p_bt_job_id           => p_bt_job_id,
                               p_receipt_date_from   => p_receipt_date_from,
                               p_receipt_date_to     => p_receipt_date_to,
                               p_load_request_id     => p_load_request_id,
                               p_reprocess_flag      => p_reprocess_flag,
                               p_inbound_filename    => p_inbound_filename,
                               x_ret_code            => ln_ret_code,
                               x_ret_message         => lv_ret_message);
        print_log (
            'Inside Process Cashapp - Validate Cashapp Data(Validate_cashapp_data) - END',
            'Y',
            2);                                         --Added for change 2.1

        IF ln_ret_code <> gn_success
        THEN
            RAISE ex_validation;
        END IF;

        --Validate duplicate receipt number --Added for change 2.1 --START
        print_log (
            'Inside Process Cashapp - Validate Receipt Number(Validate_receipt_num) - START',
            'Y',
            2);
        validate_receipt_num;
        print_log (
            'Inside Process Cashapp - Validate Receipt Number(Validate_receipt_num) - END',
            'Y',
            2);
        --Validate duplicate receipt number --Added for change 2.1 --END

        --print_log('Inside Process Cashapp - Before Process Batches - '||lv_ret_message,'Y',2); --Commented for change 2.1
        print_log (
               'Inside Process Cashapp - Process Batches(process_batches) - END '
            || lv_ret_message,
            'Y',
            2);                                         --Added for change 2.1
        --Process Batch data
        ln_ret_code         := NULL;
        lv_ret_message      := NULL;
        process_batches (                     --p_org_id          => p_org_id,
                                           --p_bt_job_id       => p_bt_job_id,
                                    --p_load_request_id => p_load_request_id ,
        x_ret_code => ln_ret_code, x_ret_message => lv_ret_message);
        --print_log('Inside Process Cashapp - Process Batches - '||lv_ret_message,'Y',2); --Commented for change 2.1
        print_log (
               'Inside Process Cashapp - Process Batches(process_batches) - END '
            || lv_ret_message,
            'Y',
            2);                                         --Added for change 2.1

        IF ln_ret_code <> gn_success
        THEN
            RAISE ex_batches;
        END IF;

        --Process Receipt data
        ln_ret_code         := NULL;
        lv_ret_message      := NULL;
        print_log (
               'Inside Process Cashapp - Process Receipts(process_receipts) - START - '
            || lv_ret_message,
            'Y',
            2);                                         --Added for change 2.1
        process_receipts (                    --p_org_id          => p_org_id,
                                           --p_bt_job_id       => p_bt_job_id,
                                    --p_load_request_id => p_load_request_id ,
        x_ret_code => ln_ret_code, x_ret_message => lv_ret_message);
        --print_log('Inside Process Cashapp - Process Receipts - '||lv_ret_message,'Y',2); --Commented for change 2.1
        print_log (
               'Inside Process Cashapp - Process Receipts(process_receipts) - END'
            || lv_ret_message,
            'Y',
            2);

        IF ln_ret_code <> gn_success
        THEN
            RAISE ex_receipts;
        END IF;

        --Process Receipt Application
        ln_ret_code         := NULL;
        lv_ret_message      := NULL;
        print_log (
               'Inside Process Cashapp - Process Application(process_application) - START - '
            || lv_ret_message,
            'Y',
            2);                                         --Added for change 2.1
        process_application (                 --p_org_id          => p_org_id,
                                           --p_bt_job_id       => p_bt_job_id,
                                    --p_load_request_id => p_load_request_id ,
        x_ret_code => ln_ret_code, x_ret_message => lv_ret_message);
        --print_log('Inside Process Cashapp - Process Application - '||lv_ret_message,'Y',2); --Commented for change 2.1
        print_log (
               'Inside Process Cashapp - Process Application(process_application) - END - '
            || lv_ret_message,
            'Y',
            2);                                         --Added for change 2.1

        IF ln_ret_code <> gn_success
        THEN
            RAISE ex_application;
        END IF;

        --Generate Output
        ln_ret_code         := NULL;
        lv_ret_message      := NULL;
        print_log (
               'Inside Process Cashapp - generate output - START - '
            || lv_ret_message,
            'Y',
            2);                                         --Added for change 2.1
        generate_output (x_ret_code      => ln_ret_code,
                         x_ret_message   => lv_ret_message);
        --print_log('Inside Process Cashapp - generate output - '||lv_ret_message,'Y',2); --Commented for change 2.1
        print_log (
               'Inside Process Cashapp - generate output - END - '
            || lv_ret_message,
            'Y',
            2);                                         --Added for change 2.1

        IF ln_ret_code <> gn_success
        THEN
            RAISE ex_output;
        END IF;
    EXCEPTION
        WHEN ex_validation
        THEN
            lv_err_msg   :=
                   ' Error in process_cashapp_data - Validation program failed '
                || lv_ret_message;
            print_log (lv_err_msg, 'N', 2);
            errbuf    := gn_error;
            retcode   := lv_err_msg;
        WHEN ex_batches
        THEN
            lv_err_msg   :=
                   ' Error in process_cashapp_data - Process receipt batches failed '
                || lv_ret_message;
            print_log (lv_err_msg, 'N', 2);
            errbuf    := gn_error;
            retcode   := lv_err_msg;
        WHEN ex_receipts
        THEN
            lv_err_msg   :=
                   ' Error in process_cashapp_data - Process receipts failed '
                || lv_ret_message;
            print_log (lv_err_msg, 'N', 2);
            errbuf    := gn_error;
            retcode   := lv_err_msg;
        WHEN ex_application
        THEN
            lv_err_msg   :=
                   ' Error in process_cashapp_data - Process applications failed '
                || lv_ret_message;
            print_log (lv_err_msg, 'N', 2);
            errbuf    := gn_error;
            retcode   := lv_err_msg;
        WHEN ex_output
        THEN
            lv_err_msg   :=
                   ' Error in process_cashapp_data - Process applications failed '
                || lv_ret_message;
            print_log (lv_err_msg, 'N', 2);
            errbuf    := gn_error;
            retcode   := lv_err_msg;
        WHEN OTHERS
        THEN
            lv_err_msg   := ' Error in process_cashapp_data ' || SQLERRM;
            print_log (lv_err_msg, 'Y', 2);
            errbuf       := gn_error;
            retcode      := lv_err_msg;
    END process_cashapp_data;

    ----
    ----
    ---- Procedure to call for the cashapp inbound
    ----
    PROCEDURE submit_request (
        p_app_short_name   IN     VARCHAR2,
        p_cp_short_name    IN     VARCHAR2,
        p_cp_description   IN     VARCHAR2,
        p_argument1        IN     VARCHAR2 DEFAULT CHR (0),
        p_argument2        IN     VARCHAR2 DEFAULT CHR (0),
        p_argument3        IN     VARCHAR2 DEFAULT CHR (0),
        p_argument4        IN     VARCHAR2 DEFAULT CHR (0),
        p_argument5        IN     VARCHAR2 DEFAULT CHR (0),
        p_argument6        IN     VARCHAR2 DEFAULT CHR (0),
        p_argument7        IN     VARCHAR2 DEFAULT CHR (0),
        p_argument8        IN     VARCHAR2 DEFAULT CHR (0),
        p_argument9        IN     VARCHAR2 DEFAULT CHR (0),
        p_argument10       IN     VARCHAR2 DEFAULT CHR (0),
        p_argument11       IN     VARCHAR2 DEFAULT CHR (0),
        p_argument12       IN     VARCHAR2 DEFAULT CHR (0),
        p_argument13       IN     VARCHAR2 DEFAULT CHR (0),
        p_argument14       IN     VARCHAR2 DEFAULT CHR (0),
        p_argument15       IN     VARCHAR2 DEFAULT CHR (0),
        p_argument16       IN     VARCHAR2 DEFAULT CHR (0),
        p_argument17       IN     VARCHAR2 DEFAULT CHR (0),
        p_argument18       IN     VARCHAR2 DEFAULT CHR (0),
        p_argument19       IN     VARCHAR2 DEFAULT CHR (0),
        p_argument20       IN     VARCHAR2 DEFAULT CHR (0),
        x_request_id          OUT NUMBER,
        x_ret_code            OUT NUMBER,
        x_ret_message         OUT VARCHAR2)
    IS
        ln_request_id          NUMBER;
        lb_req_return_status   BOOLEAN;
        lv_phase               VARCHAR2 (30) := NULL;
        lv_status              VARCHAR2 (30) := NULL;
        lv_dev_phase           VARCHAR2 (30) := NULL;
        lv_dev_status          VARCHAR2 (30) := NULL;
        lv_message             VARCHAR2 (360) := NULL;
        lv_proc_name           VARCHAR2 (30) := 'SUBMIT_REQUEST';
    BEGIN
        ln_request_id   :=
            fnd_request.submit_request (application => p_app_short_name, program => p_cp_short_name, description => p_cp_description, start_time => SYSDATE, sub_request => NULL, argument1 => p_argument1, argument2 => p_argument2, argument3 => p_argument3, argument4 => p_argument4, argument5 => p_argument5, argument6 => p_argument6, argument7 => p_argument7, argument8 => p_argument8, argument9 => p_argument9, argument10 => p_argument10, argument11 => p_argument11, argument12 => p_argument12, argument13 => p_argument13, argument14 => p_argument14, argument15 => p_argument15, argument16 => p_argument16, argument17 => p_argument17, argument18 => p_argument18, argument19 => p_argument19
                                        , argument20 => p_argument20);
        COMMIT;

        IF ln_request_id = 0
        THEN
            --print_log('Send Email Notification concurrent request failed to submit', 'Y');
            x_ret_message   :=
                SUBSTR (
                       p_cp_short_name
                    || '('
                    || p_cp_description
                    || ')'
                    || ' concurrent request failed to submit. Please check. '
                    || SQLERRM,
                    1,
                    2000);
            print_log (x_ret_message, 'Y', 2);
            x_ret_code   := gn_error;
        ELSE
            print_log (
                   'Successfully Submitted '
                || p_cp_short_name
                || '('
                || p_cp_description
                || ')'
                || ' Concurrent Request with request ID: '
                || ln_request_id,
                'Y',
                2);
            x_request_id   := ln_request_id;
        END IF;

        IF ln_request_id > 0
        THEN
            LOOP
                --To make process execution to wait for 1st program to complete
                lb_req_return_status   :=
                    fnd_concurrent.wait_for_request (
                        request_id   => ln_request_id,
                        INTERVAL     => 10--Interval Number of seconds to wait between checks
                                          ,
                        max_wait     => 3600,
                        phase        => lv_phase,
                        status       => lv_status,
                        dev_phase    => lv_dev_phase,
                        dev_status   => lv_dev_status,
                        MESSAGE      => lv_message);
                EXIT WHEN    UPPER (lv_phase) = 'COMPLETED'
                          OR UPPER (lv_status) IN
                                 ('CANCELLED', 'ERROR', 'TERMINATED');
            END LOOP;
        END IF;                                       --IF ln_email_req_id > 0
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_message   :=
                SUBSTR ('Error in submit_request: ' || SQLERRM, 1, 2000);
            x_ret_code   := gn_error;
            print_log (x_ret_message, 'Y', 2);
    END submit_request;

    ----
    ----
    ---- Procedure to call the cashapp shots
    ----
    PROCEDURE cashapp_main (errbuf                   OUT NUMBER,
                            retcode                  OUT VARCHAR2,
                            p_org_id              IN     NUMBER,
                            p_bt_job_id           IN     VARCHAR2,
                            p_receipt_method_id   IN     NUMBER,
                            p_receipt_type        IN     VARCHAR2,
                            p_receipt_num         IN     VARCHAR2,
                            p_bank_account_id     IN     NUMBER,
                            p_receipt_date_from   IN     VARCHAR2,
                            p_receipt_date_to     IN     VARCHAR2,
                            p_customer_id         IN     VARCHAR2,
                            p_currency            IN     VARCHAR2,
                            p_grace_days          IN     NUMBER,
                            p_reprocess_flag      IN     VARCHAR2,
                            p_inbound_filename    IN     VARCHAR2,
                            p_debug_mode          IN     VARCHAR2,
                            p_file_path           IN     VARCHAR2)
    IS
        lv_proc_name           VARCHAR2 (30) := 'CASHAPP_MAIN';
        ln_load_req_id         NUMBER;
        ln_process_req_id      NUMBER;
        ln_ret_code            NUMBER;
        lv_ret_message         VARCHAR2 (2000);
        ex_load_exception      EXCEPTION;
        ex_process_exception   EXCEPTION;
        ex_notif_exception     EXCEPTION;
    BEGIN
        --Print Parameters
        print_log ('p_org_id=' || p_org_id, 'N', 2);
        print_log ('p_bt_job_id=' || p_bt_job_id, 'N', 2);
        --print_log('p_receipt_method_id='||p_receipt_method_id,'N',2);
        --print_log('p_receipt_type='||p_receipt_type,'N',2);
        -- print_log('p_receipt_num='||p_receipt_num,'N',2);
        --print_log('p_bank_account_id='||p_bank_account_id,'N',2);
        print_log ('p_receipt_date_from=' || p_receipt_date_from, 'N', 2);
        print_log ('p_receipt_date_to=' || p_receipt_date_to, 'N', 2);
        --print_log('p_customer_id='||p_customer_id,'N',2);
        --print_log('p_currency='||p_currency,'N',2);
        print_log ('p_grace_days=' || p_grace_days, 'N', 2);
        print_log ('p_reprocess_flag=' || p_reprocess_flag, 'N', 2);
        print_log ('p_inbound_filename=' || p_inbound_filename, 'N', 2);
        print_log ('p_debug_mode=' || p_debug_mode, 'N', 2);
        print_log ('p_file_path=' || p_file_path, 'N', 2);

        IF p_debug_mode = 'Y'
        THEN
            gn_debug_level   := 0;
        ELSE
            gn_debug_level   := 1;
        END IF;

        IF p_reprocess_flag = 'N'
        --Load New files only if the request is to reprocess
        THEN
            print_log (
                'Stage 1 =' || 'Get Inbound Cash App Files for B2B - Deckers',
                'N',
                2);
            submit_request (p_app_short_name => 'XXDO', p_cp_short_name => 'XXDOAR_B2B_CASHAPP_FILES', p_cp_description => 'Get Inbound Cash App Files for B2B - Deckers', p_argument1 => p_file_path, x_request_id => ln_load_req_id, x_ret_code => ln_ret_code
                            , x_ret_message => lv_ret_message);

            IF ln_ret_code = gn_error
            THEN
                RAISE ex_load_exception;
            END IF;                               -- IF ln_ret_code = gn_error
        END IF;                                    --IF p_reprocess_flag = 'N'

        ln_ret_code      := NULL;
        lv_ret_message   := NULL;
        print_log ('Stage 2 =' || 'Process B2B Cashapp Data - Deckers',
                   'N',
                   2);
        submit_request (
            p_app_short_name   => 'XXDO',
            p_cp_short_name    => 'XXDOAR_B2B_PROCESS_CASHAPP',
            p_cp_description   => 'Process B2B Cashapp Data - Deckers',
            p_argument1        => p_org_id,
            p_argument2        => p_bt_job_id,
            p_argument3        => p_receipt_date_from,
            p_argument4        => p_receipt_date_to,
            p_argument5        => ln_load_req_id,
            p_argument6        => p_grace_days,
            p_argument7        => p_reprocess_flag,
            p_argument8        => p_inbound_filename,
            p_argument9        => p_debug_mode,
            x_request_id       => ln_process_req_id,
            x_ret_code         => ln_ret_code,
            x_ret_message      => lv_ret_message);

        IF ln_ret_code = gn_error
        THEN
            RAISE ex_process_exception;
        END IF;                                   -- IF ln_ret_code = gn_error

        IF p_reprocess_flag = 'N'
        THEN
            print_log ('Stage 3A =' || 'Send Notifications - File Load Log',
                       'N',
                       2);
            ln_ret_code      := NULL;
            lv_ret_message   := NULL;
            send_notification (
                p_program_name      => 'LOAD_CASHAPP_FILE',
                p_log_or_out        => 'LOG',
                p_conc_request_id   => ln_load_req_id,
                p_email_lkp_name    => 'XXDO_B2B_CASHAPP_EMAIL',
                x_ret_code          => ln_ret_code,
                x_ret_message       => lv_ret_message);

            IF ln_ret_code = gn_error
            THEN
                RAISE ex_notif_exception;
            END IF;                               -- IF ln_ret_code = gn_error
        END IF;

        print_log ('Stage 3B =' || 'Send Notifications - Process', 'N', 2);
        ln_ret_code      := NULL;
        lv_ret_message   := NULL;
        send_notification (p_program_name      => 'CASHAPP_INBOUND',
                           p_conc_request_id   => ln_process_req_id,
                           p_email_lkp_name    => 'XXDO_B2B_CASHAPP_EMAIL',
                           x_ret_code          => ln_ret_code,
                           x_ret_message       => lv_ret_message);

        IF ln_ret_code = gn_error
        THEN
            RAISE ex_notif_exception;
        END IF;                                   -- IF ln_ret_code = gn_error
    EXCEPTION
        WHEN ex_load_exception
        THEN
            errbuf    :=
                SUBSTR ('Load Exception in cashapp_main: ' || lv_ret_message,
                        1,
                        2000);
            retcode   := gn_error;
            print_log (errbuf, 'Y', 2);
        WHEN ex_process_exception
        THEN
            errbuf    :=
                SUBSTR (
                    'Process Exception in cashapp_main: ' || lv_ret_message,
                    1,
                    2000);
            retcode   := gn_error;
            print_log (errbuf, 'Y', 2);
        WHEN ex_notif_exception
        THEN
            errbuf    :=
                SUBSTR (
                       'Notification Exception in cashapp_main: '
                    || lv_ret_message,
                    1,
                    2000);
            retcode   := gn_error;
            print_log (errbuf, 'Y', 2);
        WHEN OTHERS
        THEN
            errbuf    :=
                SUBSTR ('Exception in cashapp_main: ' || SQLERRM, 1, 2000);
            retcode   := gn_error;
            print_log (errbuf, 'Y', 2);
    END cashapp_main;
----
----
END xxdo_ar_b2b_inbound_pkg;
/
