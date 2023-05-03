--
-- XXDO_COMMON_DAILY_STATUS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:10 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_COMMON_DAILY_STATUS_PKG"
AS
    /*********************************************************************************************
    -- Package Name :  XXDO_COMMON_DAILY_STATUS_PKG
    --
    -- Description  :  This is package  for generating query for daily status report
    --
    -- Date          Author                     Version  Description
    -- ------------  -----------------          -------  --------------------------------
    -- 06-AUG-15     Infosys                    1.0      Created
    -- 29-Aug-2022   Viswanathan Pandian        1.1      Updated for CCR0010179
    -- ******************************************************************************************/

    PROCEDURE send_mail_header (p_in_chr_msg_from IN VARCHAR2, p_in_chr_msg_to IN VARCHAR2, p_in_chr_msg_subject IN VARCHAR2
                                , p_out_num_status OUT NUMBER)
    IS
        l_num_status              NUMBER := 0;
        l_chr_msg_to              VARCHAR2 (2000) := NULL;
        l_chr_mail_temp           VARCHAR2 (2000) := NULL;
        l_chr_mail_id             VARCHAR2 (255);
        l_num_counter             NUMBER := 0;
        l_exe_conn_already_open   EXCEPTION;
    BEGIN
        IF g_num_connection_flag <> 0
        THEN
            RAISE l_exe_conn_already_open;
        END IF;

        g_smtp_connection       := UTL_SMTP.open_connection ('127.0.0.1');
        g_num_connection_flag   := 1;
        l_num_status            := 1;
        UTL_SMTP.helo (g_smtp_connection, 'localhost');
        UTL_SMTP.mail (g_smtp_connection, p_in_chr_msg_from);
        l_chr_mail_temp         := TRIM (p_in_chr_msg_to);

        IF (INSTR (l_chr_mail_temp, ';', 1) = 0)
        THEN
            l_chr_mail_id   := l_chr_mail_temp;
            -- Commented for CCR0010179
            /*fnd_file.put_line (fnd_file.LOG,
                               CHR (10) || 'Email ID: ' || l_chr_mail_id);*/
            -- Commented for CCR0010179
            UTL_SMTP.rcpt (g_smtp_connection, TRIM (l_chr_mail_id));
        ELSE
            WHILE (LENGTH (l_chr_mail_temp) > 0)
            LOOP
                IF (INSTR (l_chr_mail_temp, ';', 1) = 0)
                THEN
                    -- Last Mail ID
                    l_chr_mail_id   := l_chr_mail_temp;
                    -- Commented for CCR0010179
                    /*fnd_file.put_line (
                        fnd_file.LOG,
                        CHR (10) || 'Email ID: ' || l_chr_mail_id);*/
                    -- Commented for CCR0010179
                    UTL_SMTP.rcpt (g_smtp_connection, TRIM (l_chr_mail_id));
                    EXIT;
                ELSE
                    -- Next Mail ID
                    l_chr_mail_id   :=
                        TRIM (
                            SUBSTR (l_chr_mail_temp,
                                    1,
                                    INSTR (l_chr_mail_temp, ';', 1) - 1));
                    -- Commented for CCR0010179
                    /*fnd_file.put_line (
                        fnd_file.LOG,
                        CHR (10) || 'Email ID: ' || l_chr_mail_id);*/
                    -- Commented for CCR0010179
                    UTL_SMTP.rcpt (g_smtp_connection, TRIM (l_chr_mail_id));
                END IF;

                l_chr_mail_temp   :=
                    TRIM (
                        SUBSTR (l_chr_mail_temp,
                                INSTR (l_chr_mail_temp, ';', 1) + 1,
                                LENGTH (l_chr_mail_temp)));
            END LOOP;
        END IF;

        l_chr_msg_to            :=
            '  ' || TRANSLATE (TRIM (p_in_chr_msg_to), ';', ' ');
        UTL_SMTP.open_data (g_smtp_connection);
        l_num_status            := 2;
        UTL_SMTP.write_data (g_smtp_connection,
                             'To: ' || l_chr_msg_to || UTL_TCP.crlf);
        UTL_SMTP.write_data (g_smtp_connection,
                             'From: ' || p_in_chr_msg_from || UTL_TCP.crlf);
        UTL_SMTP.write_data (
            g_smtp_connection,
            'Subject: ' || p_in_chr_msg_subject || UTL_TCP.crlf);
        p_out_num_status        := 0;
    EXCEPTION
        WHEN l_exe_conn_already_open
        THEN
            p_out_num_status   := -2;
        WHEN OTHERS
        THEN
            IF l_num_status = 2
            THEN
                UTL_SMTP.close_data (g_smtp_connection);
            END IF;

            IF l_num_status > 0
            THEN
                UTL_SMTP.quit (g_smtp_connection);
            END IF;

            g_num_connection_flag   := 0;
            p_out_num_status        := -255;
    END send_mail_header;

    PROCEDURE send_mail_line (p_in_chr_msg_text   IN     VARCHAR2,
                              p_out_num_status       OUT NUMBER)
    IS
        l_exe_not_connected   EXCEPTION;
    BEGIN
        IF g_num_connection_flag = 0
        THEN
            RAISE l_exe_not_connected;
        END IF;

        UTL_SMTP.write_data (g_smtp_connection,
                             p_in_chr_msg_text || UTL_TCP.crlf);
        p_out_num_status   := 0;
    EXCEPTION
        WHEN l_exe_not_connected
        THEN
            p_out_num_status   := -2;
        WHEN OTHERS
        THEN
            p_out_num_status   := -255;
    END send_mail_line;

    PROCEDURE send_mail_close (p_out_num_status OUT NUMBER)
    IS
        l_exe_not_connected   EXCEPTION;
    BEGIN
        IF g_num_connection_flag = 0
        THEN
            RAISE l_exe_not_connected;
        END IF;

        UTL_SMTP.close_data (g_smtp_connection);
        UTL_SMTP.quit (g_smtp_connection);
        g_num_connection_flag   := 0;
        p_out_num_status        := 0;
    EXCEPTION
        WHEN l_exe_not_connected
        THEN
            p_out_num_status   := 0;
        WHEN OTHERS
        THEN
            p_out_num_status        := -255;
            g_num_connection_flag   := 0;
    END send_mail_close;

    PROCEDURE main (p_error_buf OUT VARCHAR2, p_ret_code OUT NUMBER, p_track VARCHAR2
                    ,                                  -- Added for CCR0010179
                      in_query_id NUMBER)
    IS
        l_num_return_value         NUMBER;
        l_chr_instance             VARCHAR2 (60);
        l_common_rec_tab_header    VARCHAR2 (32767);
        l_chr_no_data_found        VARCHAR2 (10);
        l_exe_instance_not_known   EXCEPTION;
        l_exe_mail_error           EXCEPTION;

        TYPE l_common_rec_tab_type IS TABLE OF VARCHAR2 (32767)
            INDEX BY BINARY_INTEGER;

        l_common_rec_tab_value     l_common_rec_tab_type;
    BEGIN
        --fnd_file.put_line (fnd_file.LOG, 'Beginning of the program');-- Commented for CCR0010179

        BEGIN
            SELECT name INTO l_chr_instance FROM v$database;
        EXCEPTION
            WHEN OTHERS
            THEN
                RAISE l_exe_instance_not_known;
        END;

        FOR c_rec_data
            IN (SELECT ROWNUM, query_id, query_desc,
                       actual_query, query_column, email_address,
                       email_attachment_file_name, email_message_text
                  FROM xxdo_common_daily_status_tbl
                 WHERE     query_id = NVL (in_query_id, query_id)
                       AND enabled_flag = 'Yes'
                       AND email_address IS NOT NULL
                       AND attribute10 = p_track       -- Added for CCR0010179
                       AND SYSDATE BETWEEN NVL (effective_start_date,
                                                SYSDATE - 1)
                                       AND NVL (effective_end_date,
                                                SYSDATE + 1))
        LOOP
            -- Commented for CCR0010179
            /*fnd_file.put_line (fnd_file.LOG,
                               'Query Desc is  ' || c_rec_data.query_desc);
            fnd_file.put_line (
                fnd_file.LOG,
                '  Query Fetch is  ' || c_rec_data.actual_query);*/
            -- Commented for CCR0010179

            IF l_common_rec_tab_value.EXISTS (1)
            THEN
                l_common_rec_tab_value.delete;
            END IF;

            BEGIN
                EXECUTE IMMEDIATE c_rec_data.actual_query
                    BULK COLLECT INTO l_common_rec_tab_value;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_chr_no_data_found   := 'No Data Exists';
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'The query return  no data ' || c_rec_data.query_id);
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error during execution of ACTUAL_QUERY of QUERY_ID# '
                        || c_rec_data.query_id
                        || SQLERRM);
            END;

            IF l_common_rec_tab_value.EXISTS (1)
            THEN
                FOR i IN l_common_rec_tab_value.FIRST ..
                         l_common_rec_tab_value.LAST
                LOOP
                    IF i = l_common_rec_tab_value.FIRST
                    --IF 1 = C_REC_DATA.ROWNUM and i = l_common_rec_tab_value.FIRST
                    THEN
                        send_mail_header ('WMSInterfacesErrorReporting@deckers.com', c_rec_data.email_address, l_chr_instance || ' - ' || c_rec_data.query_desc || TO_CHAR (SYSDATE - 1, ' - dd-Mon-yyyy')
                                          , l_num_return_value);

                        send_mail_line (
                            'Content-Type: multipart/mixed; boundary=boundarystring',
                            l_num_return_value);
                        send_mail_line ('--boundarystring',
                                        l_num_return_value);
                        send_mail_line ('Content-Type: text/plain',
                                        l_num_return_value);
                        send_mail_line ('', l_num_return_value);
                        send_mail_line ('Dear Recipient,',
                                        l_num_return_value);
                        send_mail_line ('', l_num_return_value);
                        send_mail_line (c_rec_data.email_message_text,
                                        l_num_return_value);
                        /*
                        send_mail_line (
                           'Please refer the attached file for Daily Status Report from '
                           || l_chr_instance
                           || ' for the date '
                           || SYSDATE,
                           l_num_return_value);
                         */
                        send_mail_line ('', l_num_return_value);
                        send_mail_line ('Regards,', l_num_return_value);
                        send_mail_line ('IT Operation', l_num_return_value);
                        send_mail_line ('Deckers Outdoor',
                                        l_num_return_value);
                        send_mail_line ('--boundarystring',
                                        l_num_return_value);
                        send_mail_line ('Content-Type: text/xls',
                                        l_num_return_value);
                        send_mail_line (
                               'Content-Disposition: attachment; filename="'
                            || c_rec_data.email_attachment_file_name
                            || TO_CHAR (SYSDATE, ' - dd-Mon-yyyy')
                            || '.xls"',
                            l_num_return_value);
                        send_mail_line ('--boundarystring',
                                        l_num_return_value);

                        BEGIN
                            EXECUTE IMMEDIATE c_rec_data.query_column
                                INTO l_common_rec_tab_header;

                            -- Commented for CCR0010179
                            /*fnd_file.put_line (
                                fnd_file.LOG,
                                   'Print lv_chr_column_name -'
                                || l_common_rec_tab_header);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Query Desc -' || c_rec_data.query_desc);*/
                            -- Commented for CCR0010179
                            send_mail_line (l_common_rec_tab_header,
                                            l_num_return_value);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Error during execution of QUERY_COLUMN of QUERY_ID# '
                                    || c_rec_data.query_id
                                    || '-'
                                    || SQLERRM);
                        END;
                    END IF;

                    send_mail_line (l_common_rec_tab_value (i),
                                    l_num_return_value);
                END LOOP;

                --fnd_file.put_line (fnd_file.LOG, 'Send mail close ');-- Commented for CCR0010179
                send_mail_close (l_num_return_value);
            END IF;
        END LOOP;

        IF l_num_return_value <> 0
        THEN
            p_error_buf   := 'Unable to generate the attachment file';
            RAISE l_exe_mail_error;
        END IF;

        --    END IF;
        --fnd_file.put_line (fnd_file.LOG, 'Send mail close after');-- Commented for CCR0010179

        --   fnd_file.put_line (fnd_file.LOG, 'l_num_return_value'||l_num_return_value);
        IF l_num_return_value <> 0
        THEN
            p_error_buf   := 'Unable to close the mail connection';
            RAISE l_exe_mail_error;
        END IF;
    EXCEPTION
        WHEN l_exe_mail_error
        THEN
            p_error_buf   := 'Error in mail ' || p_error_buf;
            fnd_file.put_line (fnd_file.LOG, p_error_buf);
        WHEN l_exe_instance_not_known
        THEN
            p_error_buf   := SQLERRM;
            p_ret_code    := 2;
            fnd_file.put_line (
                fnd_file.LOG,
                'Instance Name couldn''t be found: ' || p_error_buf);
        WHEN OTHERS
        THEN
            p_error_buf   := SQLERRM;
            p_ret_code    := 2;
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexpected error at generating report : ' || p_error_buf);
    END main;
END xxdo_common_daily_status_pkg;
/
