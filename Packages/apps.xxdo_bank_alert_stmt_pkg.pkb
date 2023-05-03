--
-- XXDO_BANK_ALERT_STMT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:14 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_BANK_ALERT_STMT_PKG"
AS
    /*
    ********************************************************************************************************************************
    **                                                                                                                             *
    **    Author          : Infosys                                                                                                *
    **    Created         : 25-OCT-2016                                                                                            *
    **    Description     : This package is used to send notification to mailer for bank account statement not generated           *
    **                                                                                                                             *
    **History         :                                                                                                            *
    **------------------------------------------------------------------------------------------                                   *
    **Date        Author                        Version Change Notes
    **----------- --------- ------- ------------------------------------------------------------                                   */
    /*********************************************************************************************************************
    * Type                : Procedure                                                                                    *
    * Name                : send_mail                                                                                      *
    * Purpose             : To Send Mail to the Users                                          *
    *********************************************************************************************************************/
    PROCEDURE send_mail (p_i_from_email    IN     VARCHAR2,
                         p_i_to_email      IN     VARCHAR2,
                         p_i_mail_format   IN     VARCHAR2 DEFAULT 'TEXT',
                         p_i_mail_server   IN     VARCHAR2,
                         p_i_subject       IN     VARCHAR2,
                         p_i_mail_body     IN     CLOB DEFAULT NULL,
                         p_o_status           OUT VARCHAR2,
                         p_o_error_msg        OUT VARCHAR2)
    IS
        --Local variable declaration
        l_mail_conn        UTL_SMTP.connection;
        lc_chr_err_messg   VARCHAR2 (4000) := NULL;
        lc_boundary        VARCHAR2 (255);
        lp_step            PLS_INTEGER := 12000;
        ln_num_email_id    NUMBER;
        lc_to_email_id     VARCHAR2 (50);
    BEGIN
        p_o_status    := 'S';
        l_mail_conn   := UTL_SMTP.open_connection (p_i_mail_server, 25);
        UTL_SMTP.helo (l_mail_conn, p_i_mail_server);
        UTL_SMTP.mail (l_mail_conn, p_i_from_email);

        --Counting the number of email_id passed
        SELECT (LENGTH (p_i_to_email) - LENGTH (REPLACE (p_i_to_email, ',', NULL)) + 1)
          INTO ln_num_email_id
          FROM DUAL;

        FOR i IN 1 .. ln_num_email_id
        LOOP
            SELECT REGEXP_SUBSTR (p_i_to_email, '[^,]+', 1,
                                  i)
              INTO lc_to_email_id
              FROM DUAL;

            UTL_SMTP.rcpt (l_mail_conn, lc_to_email_id);
        END LOOP;

        UTL_SMTP.open_data (l_mail_conn);
        UTL_SMTP.write_data (
            l_mail_conn,
               'Date: '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
            || UTL_TCP.crlf);
        UTL_SMTP.write_data (l_mail_conn,
                             'To: ' || p_i_to_email || UTL_TCP.crlf);
        UTL_SMTP.write_data (l_mail_conn,
                             'From: ' || p_i_from_email || UTL_TCP.crlf);
        UTL_SMTP.write_data (l_mail_conn,
                             'Subject: ' || p_i_subject || UTL_TCP.crlf);
        UTL_SMTP.write_data (l_mail_conn,
                             'Reply-To: ' || p_i_from_email || UTL_TCP.crlf);

        IF p_i_mail_format = 'HTML'
        THEN
            UTL_SMTP.write_data (l_mail_conn,
                                 'MIME-Version: 1.0' || UTL_TCP.crlf);
            UTL_SMTP.write_data (
                l_mail_conn,
                   'Content-Type: multipart/alternative; boundary="'
                || lc_boundary
                || '"'
                || UTL_TCP.crlf
                || UTL_TCP.crlf);
            UTL_SMTP.write_data (l_mail_conn,
                                 '' || lc_boundary || UTL_TCP.crlf);
        /*UTL_SMTP.write_data (
           l_mail_conn,
              'Content-Type: text/html; charset="iso-8859-1"'
           || UTL_TCP.crlf
           || UTL_TCP.crlf);*/
        END IF;

        FOR i IN 0 ..
                 TRUNC ((DBMS_LOB.getlength (p_i_mail_body) - 1) / lp_step)
        LOOP
            UTL_SMTP.write_data (
                l_mail_conn,
                DBMS_LOB.SUBSTR (p_i_mail_body, lp_step, i * lp_step + 1));
        END LOOP;

        UTL_SMTP.write_data (l_mail_conn, UTL_TCP.crlf || UTL_TCP.crlf);

        IF p_i_mail_format = 'HTML'
        THEN
            UTL_SMTP.write_data (l_mail_conn,
                                 '' || lc_boundary || '' || UTL_TCP.crlf);
        END IF;

        UTL_SMTP.close_data (l_mail_conn);
        UTL_SMTP.quit (l_mail_conn);
    EXCEPTION
        WHEN OTHERS
        THEN
            p_o_status   := 'E';
            p_o_error_msg   :=
                   'Error occurred in send_mail() procedure'
                || SQLERRM
                || ' - '
                || DBMS_UTILITY.format_error_backtrace;
            fnd_file.put_line (fnd_file.LOG,
                               'Exception in send_mail - ' || p_o_error_msg);
    END send_mail;

    /*********************************************************************************************************************
    * Type                : Procedure                                                                                 *
    * Name                : create_interface_dashboard                                                                                 *
    * Purpose             : To collect data and create the dashboard in HTML                                                                 *
    *********************************************************************************************************************/
    PROCEDURE create_bank_stmt_alert (errbuf                OUT VARCHAR2,
                                      retcode               OUT VARCHAR2,
                                      p_i_from_emailid   IN     VARCHAR2,
                                      p_subject          IN     VARCHAR2,
                                      p_date             IN     VARCHAR2)
    AS
        --Variables for O2C

        lc_error              VARCHAR2 (2000) := NULL;

        lc_bank_account_num   VARCHAR2 (240) := NULL;
        l_mail_body           CLOB;
        lc_i_to_email         VARCHAR2 (4000) := NULL;
        lc_error_msg          VARCHAR2 (2000);
        lc_return_status      VARCHAR2 (10);
        lc_mail_server        VARCHAR2 (50);
        lc_subject            VARCHAR2 (240);

        CURSOR lcur_email_address IS
            SELECT ffvl.flex_value bank_account_num, ffvl.description email_address
              FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffvl
             WHERE     flex_value_set_name = 'XXDO_BANK_ACCOUNTS'
                   AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
                   AND ffvl.enabled_flag = 'Y'
                   AND ffvl.flex_value NOT IN
                           (  SELECT ffvv.flex_value
                                FROM ce_statement_lines csli,
                                     ce_statement_headers csh,
                                     ce_bank_accounts cba,
                                     (SELECT ffvl.flex_value, ffvl.description
                                        FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffvl
                                       WHERE     flex_value_set_name =
                                                 'XXDO_BANK_ACCOUNTS'
                                             AND ffvs.flex_value_set_id =
                                                 ffvl.flex_value_set_id
                                             AND ffvl.enabled_flag = 'Y') ffvv
                               WHERE     cba.bank_account_num = ffvv.flex_value
                                     AND cba.bank_Account_id =
                                         csh.bank_account_id
                                     AND csh.statement_header_id =
                                         csli.statement_header_id
                                     AND TRUNC (csli.creation_date) =
                                         TRUNC (
                                             fnd_date.canonical_to_date (
                                                 p_date))
                            GROUP BY cba.bank_account_num, ffvv.description, ffvv.flex_value,
                                     csh.statement_number);
    BEGIN
        --Get To Email IDs
        FOR lrec_email_address IN lcur_email_address
        LOOP
            lc_bank_account_num   := NULL;
            lc_i_to_email         := NULL;

            lc_bank_account_num   := lrec_email_address.bank_account_num;
            lc_i_to_email         := lrec_email_address.email_address;


            l_mail_body           :=
                   'Dear Recipient,
   
Bank account '
                || lc_bank_account_num
                || ' has not received statement from bank on '
                || TRUNC (fnd_date.canonical_to_date (p_date))
                || '
   
Regards,
IT Operation
Deckers Brands';

            IF p_subject IS NOT NULL
            THEN
                lc_subject   := p_subject;
            ELSE
                lc_subject   := 'Bank Statement not received for ';
            END IF;

            lc_mail_server        :=
                NVL (fnd_profile.VALUE ('FND_SMTP_HOST'), 'mail.deckers.com');
            send_mail (
                p_i_from_email    => p_i_from_emailid,
                p_i_to_email      => lc_i_to_email,
                p_i_mail_format   => 'HTML',
                p_i_mail_server   => lc_mail_server,
                p_i_subject       =>
                       lc_subject
                    || ' '
                    || lc_bank_account_num
                    || ' on '
                    || TRUNC (fnd_date.canonical_to_date (p_date)),
                p_i_mail_body     => l_mail_body,
                p_o_status        => lc_return_status,
                p_o_error_msg     => lc_error_msg);
            fnd_file.put_line (
                fnd_file.LOG,
                   ' After sending email to - '
                || lc_i_to_email
                || ' : Return Status - '
                || lc_return_status
                || ' :lc_error_msg -'
                || lc_error_msg);
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            lc_error   :=
                SUBSTR (
                    'Error ::' || SQLERRM || '  ::Backtace :' || DBMS_UTILITY.format_error_backtrace,
                    1,
                    2000);
            fnd_file.put_line (
                fnd_file.LOG,
                   ' Error In XXDO_BANK_ALERT_STMT_PKG.create_bank_stmt_alert - '
                || lc_error);
    END create_bank_stmt_alert;
END XXDO_BANK_ALERT_STMT_PKG;
/
