--
-- XXDO_SOX_ALERT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:32:14 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxdo_sox_alert_pkg
/****************************************************************************************
* Package : XXDO_SOX_ALERT_PKG
* Author : BT Technology Team
* Created : 30-OCT-2014
* Program Name : Deckers Alert For Large Unusual SOX Transactions
* Description : Package having all the functions used for the alert
*
* Modification :
*--------------------------------------------------------------------------------------
* Date Developer Version Description
*--------------------------------------------------------------------------------------
* 30-OCT-2014 BT Technology Team 1.00 Created package script
* 04-FEB-2015 BT Technology Team 1.10 Added main procedure
***********************************************************************************/
AS
    --------------------------------------------------------------------------------------
    -- Procedure to log messages
    --------------------------------------------------------------------------------------
    PROCEDURE print_log_prc (p_msg IN VARCHAR2)
    IS
    BEGIN
        IF p_msg IS NOT NULL
        THEN
            --DBMS_OUTPUT.put_line ('Msg :' || p_msg);
            fnd_file.put_line (fnd_file.LOG, p_msg);
        END IF;

        RETURN;
    END print_log_prc;

    --------------------------------------------------------------------------------------
    -- Function to check if journal has control account in any of the lines
    --------------------------------------------------------------------------------------
    FUNCTION xxd_alert_gl_header_fnc (p_gl_header_id IN NUMBER)
        RETURN VARCHAR2
    AS
        ln_count   NUMBER;
    BEGIN
        SELECT COUNT (1)
          INTO ln_count
          FROM fnd_flex_value_sets fvs, fnd_flex_values fv, fnd_flex_validation_qualifiers ffvq,
               gl_code_combinations gcc, gl_je_lines gjl
         WHERE     fv.flex_value_set_id = fvs.flex_value_set_id
               AND ffvq.flex_value_set_id = fv.flex_value_set_id
               AND flex_value_set_name = 'DO_GL_ACCOUNT'
               AND flex_value = gcc.segment6
               AND gcc.code_combination_id = gjl.code_combination_id
               AND gjl.je_header_id = p_gl_header_id
               AND SUBSTR (fv.compiled_value_attributes, 7, 1) = 'Y'
               AND fv.enabled_flag = 'Y'
               AND value_attribute_type = 'GL_ACCOUNT_TYPE';

        IF ln_count > 0
        THEN
            RETURN 'Y';
        ELSE
            RETURN 'N';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 'Y';
    END xxd_alert_gl_header_fnc;

    --------------------------------------------------------------------------------------
    -- Function to retrieve email id for primary and secondary ledger
    --------------------------------------------------------------------------------------
    FUNCTION xxd_primary_secondary_email (p_header_id IN NUMBER)
        RETURN VARCHAR2
    AS
        CURSOR c_secondary_email IS
            SELECT b.responsibility_name name1, u.user_name user1, u.email_address email1
              FROM fnd_user_resp_groups a, fnd_responsibility_vl b, fnd_user u
             WHERE     a.user_id = u.user_id
                   AND a.responsibility_id = b.responsibility_id
                   AND a.responsibility_application_id = b.application_id
                   AND SYSDATE BETWEEN a.start_date
                                   AND NVL (a.end_date, SYSDATE + 1)
                   AND b.end_date IS NULL
                   AND u.end_date IS NULL
                   AND b.responsibility_name = 'General Ledger Super User';

        lv_email_address   VARCHAR2 (4000) DEFAULT NULL;
        lv_code            VARCHAR2 (20);
        lv_variable        VARCHAR2 (10) DEFAULT NULL;
        email_exception    EXCEPTION;
    BEGIN
        SELECT gl.ledger_category_code
          INTO lv_code
          FROM gl_je_headers gjh, gl_ledgers gl
         WHERE     gjh.ledger_id = gl.ledger_id
               AND gjh.je_header_id = p_header_id;

        IF lv_code = 'PRIMARY'
        THEN
            BEGIN
                SELECT fnd_profile.VALUE ('XXDO_EMAIL_ADDR_PROFILE'), 'S'
                  INTO lv_email_address, lv_variable
                  FROM DUAL;
            EXCEPTION
                WHEN email_exception
                THEN
                    raise_application_error (
                        -20001,
                        'Email address cannot be retrieved');
                WHEN OTHERS
                THEN
                    raise_application_error (
                        -20001,
                        'Email address cannot be retrieved');
            END;
        ELSIF lv_code = 'SECONDARY' AND lv_variable IS NULL
        THEN
            BEGIN
                FOR c IN c_secondary_email
                LOOP
                    lv_email_address   := c.email1 || ',' || lv_email_address;
                END LOOP;
            EXCEPTION
                WHEN email_exception
                THEN
                    raise_application_error (
                        -20001,
                        'Email address cannot be retrieved');
                WHEN OTHERS
                THEN
                    raise_application_error (
                        -20001,
                        'Email address cannot be retrieved');
            END;
        END IF;

        RETURN lv_email_address;
    EXCEPTION
        WHEN email_exception
        THEN
            raise_application_error (-20001,
                                     'Email address cannot be retrieved');
        WHEN OTHERS
        THEN
            raise_application_error (-20001,
                                     'Email address cannot be retrieved');
    END xxd_primary_secondary_email;

    --------------------------------------------------------------------------------------
    -- Function to convert currencies to equivalent of USD
    --------------------------------------------------------------------------------------
    FUNCTION xxd_gl_conversion_rate (p_header_id IN NUMBER, p_from_currency IN VARCHAR2, p_total_amount IN FLOAT)
        RETURN FLOAT
    AS
        lv_conv_rate   FLOAT DEFAULT 0;
        lv_conv_amt    FLOAT;
    BEGIN
        IF p_from_currency <> 'USD'
        THEN
            BEGIN
                SELECT rate.conversion_rate
                  INTO lv_conv_rate
                  FROM apps.gl_daily_rates rate, apps.gl_daily_conversion_types ratetyp
                 WHERE     ratetyp.conversion_type = rate.conversion_type
                       AND UPPER (ratetyp.user_conversion_type) = 'CORPORATE'
                       AND rate.from_currency = p_from_currency
                       AND rate.to_currency = 'USD'
                       AND rate.conversion_date =
                           (SELECT TRUNC (date_created)
                              FROM apps.gl_je_headers
                             WHERE je_header_id = p_header_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_conv_rate   := 0;
            END;
        ELSE
            lv_conv_rate   := 1;
        END IF;

        lv_conv_amt   := (lv_conv_rate * p_total_amount);
        RETURN lv_conv_amt;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_conv_amt   := 0;
            RETURN lv_conv_amt;
    END xxd_gl_conversion_rate;

    --------------------------------------------------------------------------------------
    -- Function to return 'Y' or 'N' depending on the ledger type
    --------------------------------------------------------------------------------------
    FUNCTION xxd_check_gl_ledger (p_header_id IN NUMBER)
        RETURN VARCHAR2
    AS
        lv_variable    VARCHAR2 (2);
        ln_header_id   NUMBER;
        lv_code        VARCHAR2 (20);
    BEGIN
        BEGIN
            SELECT gl.ledger_category_code, gjh.parent_je_header_id
              INTO lv_code, ln_header_id
              FROM gl_je_headers gjh, gl_ledgers gl
             WHERE     gjh.ledger_id = gl.ledger_id
                   AND gjh.je_header_id = p_header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_code        := NULL;
                ln_header_id   := 0;
        END;

        IF lv_code = 'PRIMARY'
        THEN
            lv_variable   := 'Y';
        ELSIF lv_code = 'SECONDARY' AND ln_header_id IS NULL
        THEN
            lv_variable   := 'Y';
        ELSIF lv_code = 'SECONDARY' AND ln_header_id IS NOT NULL
        THEN
            lv_variable   := 'N';
        END IF;

        RETURN lv_variable;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_variable   := 'N';
            RETURN lv_variable;
    END xxd_check_gl_ledger;

    -------------------------------------------------------------------------------------
    -- Function to return last_updated_by and created_by
    --------------------------------------------------------------------------------------
    FUNCTION xxd_created_updated_by (p_name        IN VARCHAR2,
                                     p_header_id   IN NUMBER)
        RETURN VARCHAR2
    AS
        lv_person   VARCHAR2 (240);
    BEGIN
        IF p_name = 'LAST_UPDATED_BY'
        THEN
            BEGIN
                SELECT DECODE (full_name, NULL, fu.user_name, full_name)
                  INTO lv_person
                  FROM per_all_people_f papf, fnd_user fu, gl_je_headers gjh
                 WHERE     papf.person_id(+) = fu.employee_id
                       AND gjh.last_updated_by = fu.user_id
                       AND gjh.je_header_id = p_header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_person   := NULL;
            END;
        ELSIF p_name = 'CREATED_BY'
        THEN
            BEGIN
                SELECT DECODE (full_name, NULL, fu.user_name, full_name)
                  INTO lv_person
                  FROM per_all_people_f papf, fnd_user fu, gl_je_headers gjh
                 WHERE     papf.person_id(+) = fu.employee_id
                       AND gjh.created_by = fu.user_id
                       AND gjh.je_header_id = p_header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_person   := NULL;
            END;
        END IF;

        RETURN lv_person;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_person   := NULL;
    END xxd_created_updated_by;

    --------------------------------------------------------------------------------------
    -- Main Procedure to send email
    --------------------------------------------------------------------------------------
    PROCEDURE main (x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2)
    IS
        lc_db_name             VARCHAR2 (50);
        lc_override_email_id   VARCHAR2 (1996);
        lc_connection          UTL_SMTP.connection;
        lc_error_status        VARCHAR2 (1) := 'E';
        lc_success_status      VARCHAR2 (1) := 'S';
        lc_port                NUMBER := 25;
        --Smtp Domain name derived from profile
        lc_host                VARCHAR2 (256)
                                   := fnd_profile.VALUE ('FND_SMTP_HOST');
        lc_from_address        VARCHAR2 (100);
        lc_email_address       VARCHAR2 (100) := NULL;
        le_mail_exception      EXCEPTION;

        lv_je_source           VARCHAR2 (25);
        lv_je_name             VARCHAR2 (100);
        lv_email               VARCHAR2 (4000);
        lv_amount              NUMBER;
        lv_currency            VARCHAR2 (15);
        lv_batch_name          VARCHAR2 (100);
        lv_updated_by          VARCHAR2 (240);
        lv_created_by          VARCHAR2 (240);

        lv_program_run_date    VARCHAR2 (30)
            := TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS');

        lv_subject             VARCHAR2 (240);
        lv_body                VARCHAR2 (2000);

        CURSOR posted_journal_cur IS
              SELECT gjh.je_source,
                     gjh.name,
                     /*xxdo_sox_alert_pkg.xxd_primary_secondary_email (
                        gjh.je_header_id)*/
                     NULL
                         email,
                     TO_NUMBER (fnd_profile.VALUE ('XXDO_GL_AMOUNT_PROFILE'))
                         amount,
                     currency_code,
                     (SELECT gjb.name batch_name
                        FROM gl_je_batches gjb
                       WHERE gjh.je_batch_id = gjb.je_batch_id)
                         batch_name,
                     xxdo_sox_alert_pkg.xxd_created_updated_by (
                         'LAST_UPDATED_BY',
                         gjh.je_header_id)
                         last_updated_by,
                     xxdo_sox_alert_pkg.xxd_created_updated_by (
                         'CREATED_BY',
                         gjh.je_header_id)
                         created_by
                FROM gl_je_headers gjh
               WHERE     gjh.status = 'P'
                     AND xxdo_sox_alert_pkg.xxd_alert_gl_header_fnc (
                             gjh.je_header_id) =
                         'N'
                     AND je_source IN ('Manual', 'Spreadsheet')
                     AND xxdo_sox_alert_pkg.xxd_check_gl_ledger (
                             gjh.je_header_id) =
                         'Y'
                     AND EXISTS
                             (SELECT 1
                                FROM gl_je_lines gjl
                               WHERE     gjh.je_header_id = gjl.je_header_id
                                     AND (xxdo_sox_alert_pkg.xxd_gl_conversion_rate (gjh.je_header_id, gjh.currency_code, accounted_dr) >= TO_NUMBER (fnd_profile.VALUE ('XXDO_GL_AMOUNT_PROFILE')) OR xxdo_sox_alert_pkg.xxd_gl_conversion_rate (gjh.je_header_id, gjh.currency_code, accounted_cr) >= TO_NUMBER (fnd_profile.VALUE ('XXDO_GL_AMOUNT_PROFILE'))))
                     AND gjh.posted_date >
                         TO_DATE (fnd_profile.VALUE ('XXD_SOX_TXN_RUN_DATE'),
                                  'DD-MON-YYYY HH24:MI:SS')
            ORDER BY gjh.posted_date;
    BEGIN
        print_log_prc ('Begin main procedure ' || lv_program_run_date);

        BEGIN
            SELECT SYS_CONTEXT ('userenv', 'db_name')
              INTO lc_db_name
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                print_log_prc ('Error deriving DB name:' || SQLERRM);
                RAISE le_mail_exception;
        END;

        print_log_prc ('Database name: ' || lc_db_name);

        IF LOWER (lc_db_name) NOT LIKE '%prod%'
        THEN
            BEGIN
                --Fetch override email address for Non Prod Instances
                SELECT fscpv.parameter_value
                  INTO lc_override_email_id
                  FROM fnd_svc_comp_params_tl fscpt, fnd_svc_comp_param_vals fscpv, fnd_svc_components fsc
                 WHERE     fscpt.parameter_id = fscpv.parameter_id
                       AND fscpv.component_id = fsc.component_id
                       AND fscpt.display_name = 'Test Address'
                       AND fsc.component_name =
                           'Workflow Notification Mailer';

                lc_email_address   := lc_override_email_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    print_log_prc (
                        'Error deriving OVERRIDE email address:' || SQLERRM);
                    RAISE le_mail_exception;
            END;
        END IF;

        print_log_prc ('lc_override_email_id: ' || lc_override_email_id);

        --Get From Email Address
        BEGIN
            SELECT fscpv.parameter_value
              INTO lc_from_address
              FROM fnd_svc_comp_params_tl fscpt, fnd_svc_comp_param_vals fscpv, fnd_svc_components fsc
             WHERE     fscpt.parameter_id = fscpv.parameter_id
                   AND fscpv.component_id = fsc.component_id
                   AND fscpt.display_name = 'Reply-to Address'
                   AND fsc.component_name = 'Workflow Notification Mailer';
        EXCEPTION
            WHEN OTHERS
            THEN
                print_log_prc (
                    'Error deriving FROM email address:' || SQLERRM);
                RAISE le_mail_exception;
        END;

        print_log_prc ('lc_from_address: ' || lc_from_address);
        print_log_prc ('lc_email_address: ' || lc_email_address);
        print_log_prc (
            'Profile Email Address: ' || fnd_profile.VALUE ('XXDO_EMAIL_ADDR_PROFILE'));

        IF lc_email_address IS NULL
        THEN
            lc_email_address   :=
                fnd_profile.VALUE ('XXDO_EMAIL_ADDR_PROFILE');
        END IF;

        FOR posted_journal_rec IN posted_journal_cur
        LOOP
            lv_je_source    := posted_journal_rec.je_source;
            lv_je_name      := posted_journal_rec.name;
            lv_email        := posted_journal_rec.email;
            lv_amount       := posted_journal_rec.amount;
            lv_currency     := posted_journal_rec.currency_code;
            lv_batch_name   := posted_journal_rec.batch_name;
            lv_updated_by   := posted_journal_rec.last_updated_by;
            lv_created_by   := posted_journal_rec.created_by;

            lv_subject      :=
                   'Journal with batch name '
                || lv_batch_name
                || ' posted without having any control account';
            lv_body         :=
                   'The journal '
                || lv_je_name
                || ' has been posted for Debit Amount greater than '
                || lv_amount
                || ' or Credit Amount greater than '
                || lv_amount
                || ' created by '
                || lv_created_by
                || ' and last updated by '
                || lv_updated_by
                || ' without having any control account.';
            --send_email (lv_recepient, lv_subject, lv_body);
            /****Begin Send Email****/
            print_log_prc ('Send email for Journal: ' || lv_je_name);



            lc_connection   := UTL_SMTP.open_connection (lc_host, lc_port);
            UTL_SMTP.helo (lc_connection, lc_host);
            UTL_SMTP.mail (lc_connection, lc_from_address);
            UTL_SMTP.rcpt (lc_connection, lc_email_address);
            UTL_SMTP.open_data (lc_connection); /* ** Sending the header information */
            UTL_SMTP.write_data (lc_connection,
                                 'From: ' || lc_from_address || UTL_TCP.crlf);
            UTL_SMTP.write_data (lc_connection,
                                 'To: ' || lc_email_address || UTL_TCP.crlf);
            UTL_SMTP.write_data (lc_connection,
                                 'Subject: ' || lv_subject || UTL_TCP.crlf);
            UTL_SMTP.write_data (lc_connection,
                                 'MIME-Version: ' || '1.0' || UTL_TCP.crlf);
            UTL_SMTP.write_data (lc_connection,
                                 'Content-Type: ' || 'text/html;');
            UTL_SMTP.write_data (
                lc_connection,
                'Content-Transfer-Encoding: ' || '"8Bit"' || UTL_TCP.crlf);
            UTL_SMTP.write_data (lc_connection, UTL_TCP.crlf);
            UTL_SMTP.write_data (lc_connection, UTL_TCP.crlf || '');
            UTL_SMTP.write_data (lc_connection, UTL_TCP.crlf || '');
            UTL_SMTP.write_data (
                lc_connection,
                   UTL_TCP.crlf
                || '<span style="color: black; font-family: Courier New;">'
                || lv_body
                || '</span>');
            UTL_SMTP.write_data (lc_connection, UTL_TCP.crlf || '');
            UTL_SMTP.write_data (lc_connection, UTL_TCP.crlf || '');
            UTL_SMTP.close_data (lc_connection);
            UTL_SMTP.quit (lc_connection);
        /****End Send Email****/
        END LOOP;

        IF fnd_profile.save (x_name         => 'XXD_SOX_TXN_RUN_DATE',
                             x_value        => lv_program_run_date,
                             x_level_name   => 'SITE')
        THEN
            print_log_prc ('Profile updated successfully');
        END IF;
    EXCEPTION
        WHEN le_mail_exception
        THEN
            x_retcode   := '2';
            x_errbuf    := 'Program completed without sending email';
            print_log_prc ('Program completed without sending email');

            IF (posted_journal_cur%ISOPEN)
            THEN
                CLOSE posted_journal_cur;
            END IF;
        WHEN UTL_SMTP.invalid_operation
        THEN
            x_retcode   := '2';
            x_errbuf    :=
                'Invalid Operation in Mail attempt using UTL_SMTP.';
            print_log_prc (
                'Invalid Operation in Mail attempt using UTL_SMTP.');

            IF (posted_journal_cur%ISOPEN)
            THEN
                CLOSE posted_journal_cur;
            END IF;
        WHEN UTL_SMTP.transient_error
        THEN
            x_retcode   := '2';
            x_errbuf    := 'Temporary e-mail issue - try again';
            print_log_prc ('Temporary e-mail issue - try again');

            IF (posted_journal_cur%ISOPEN)
            THEN
                CLOSE posted_journal_cur;
            END IF;
        WHEN UTL_SMTP.permanent_error
        THEN
            x_retcode   := '2';
            x_errbuf    := 'Permanent Error Encountered.';
            print_log_prc ('Permanent Error Encountered.');

            IF (posted_journal_cur%ISOPEN)
            THEN
                CLOSE posted_journal_cur;
            END IF;
        WHEN OTHERS
        THEN
            x_retcode   := '2';
            x_errbuf    := 'Error: ' || SQLERRM;

            IF (posted_journal_cur%ISOPEN)
            THEN
                CLOSE posted_journal_cur;
            END IF;
    END;
END xxdo_sox_alert_pkg;
/
